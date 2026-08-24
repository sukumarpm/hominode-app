const {FieldValue} = require("firebase-admin/firestore");
const {RegistrationError, verifiedPhoneAuth} = require("./register_resident");

const LOCATION_NOT_CONFIGURED =
  "Community attendance location has not been configured. Please contact your administrator.";
const MAX_ACCEPTED_ACCURACY_METERS = 100;

function requireCoordinate(value, name, min, max) {
  if (typeof value !== "number" || !Number.isFinite(value) || value < min || value > max) {
    throw new RegistrationError("invalid-argument", `Enter a valid ${name}.`);
  }
  return value;
}

function validateGps(data, {required = true} = {}) {
  const supplied = data?.latitude != null || data?.longitude != null || data?.accuracyMeters != null;
  if (!supplied && !required) return null;
  const latitude = requireCoordinate(data?.latitude, "latitude", -90, 90);
  const longitude = requireCoordinate(data?.longitude, "longitude", -180, 180);
  const accuracyMeters = data?.accuracyMeters;
  if (typeof accuracyMeters !== "number" || !Number.isFinite(accuracyMeters) || accuracyMeters <= 0) {
    throw new RegistrationError("invalid-argument", "GPS accuracy is invalid.");
  }
  if (required && accuracyMeters > MAX_ACCEPTED_ACCURACY_METERS) {
    throw new RegistrationError(
      "failed-precondition",
      "GPS accuracy is too low. Move to an open area and try again.",
    );
  }
  return {latitude, longitude, accuracyMeters};
}

function haversineMeters(a, b) {
  const radians = (degrees) => degrees * Math.PI / 180;
  const dLat = radians(b.latitude - a.latitude);
  const dLon = radians(b.longitude - a.longitude);
  const lat1 = radians(a.latitude);
  const lat2 = radians(b.latitude);
  const value = Math.sin(dLat / 2) ** 2 +
    Math.cos(lat1) * Math.cos(lat2) * Math.sin(dLon / 2) ** 2;
  return 6371000 * 2 * Math.atan2(Math.sqrt(value), Math.sqrt(1 - value));
}

async function loadAttendanceAuthority(db, auth) {
  const {uid} = verifiedPhoneAuth(auth);
  const staffSnapshot = await db.collection("securityStaff").doc(uid).get();
  const staff = staffSnapshot.data();
  if (!staffSnapshot.exists || staff?.uid !== uid || staff?.role !== "security" || staff?.isActive !== true) {
    throw new RegistrationError("permission-denied", "An active Security profile is required.");
  }
  const communityId = typeof staff.communityId === "string" ? staff.communityId.trim() : "";
  if (!communityId) throw new RegistrationError("failed-precondition", "Security community is not assigned.");
  const communitySnapshot = await db.collection("communities").doc(communityId).get();
  const community = communitySnapshot.data();
  if (!communitySnapshot.exists || community?.isActive !== true) {
    throw new RegistrationError("failed-precondition", "The assigned community is inactive.");
  }
  return {uid, staff, communityId, community};
}

function validatedCommunityLocation(community) {
  const location = community?.location;
  if (community?.locationConfigured !== true || !location || typeof location !== "object") {
    throw new RegistrationError("failed-precondition", LOCATION_NOT_CONFIGURED);
  }
  const latitude = requireCoordinate(location.latitude, "community latitude", -90, 90);
  const longitude = requireCoordinate(location.longitude, "community longitude", -180, 180);
  const allowedRadiusMeters = location.attendanceRadiusMeters;
  if (!Number.isInteger(allowedRadiusMeters) || allowedRadiusMeters < 25 || allowedRadiusMeters > 5000) {
    throw new RegistrationError("failed-precondition", LOCATION_NOT_CONFIGURED);
  }
  return {latitude, longitude, allowedRadiusMeters};
}

function locationAudit(gps, communityLocation) {
  if (!gps) return {locationCaptured: false};
  const distanceMeters = haversineMeters(gps, communityLocation);
  return {
    latitude: gps.latitude,
    longitude: gps.longitude,
    accuracyMeters: gps.accuracyMeters,
    distanceMeters: Math.round(distanceMeters * 100) / 100,
    allowedRadiusMeters: communityLocation.allowedRadiusMeters,
    locationValidated: distanceMeters <= communityLocation.allowedRadiusMeters,
  };
}

function requireInsideGeofence(audit) {
  if (!audit?.locationValidated) {
    throw new RegistrationError(
      "failed-precondition",
      `You are outside the attendance area (${Math.round(audit?.distanceMeters || 0)}m away; ${audit?.allowedRadiusMeters || 0}m allowed).`,
    );
  }
}

async function securityCheckInCore({db, auth, data}) {
  const gps = validateGps(data);
  const {uid, staff, communityId, community} = await loadAttendanceAuthority(db, auth);
  const canonicalLocation = validatedCommunityLocation(community);
  const checkInLocation = locationAudit(gps, canonicalLocation);
  requireInsideGeofence(checkInLocation);

  const openRef = db.collection("securityAttendanceOpen").doc(uid);
  const attendanceRef = db.collection("staffAttendance").doc();
  const legacyOpen = await db.collection("staffAttendance")
    .where("communityId", "==", communityId)
    .where("staffId", "==", uid)
    .where("status", "==", "checked_in")
    .limit(1)
    .get();
  if (!legacyOpen.empty) {
    throw new RegistrationError("already-exists", "You are already checked in.");
  }
  await db.runTransaction(async (transaction) => {
    const open = await transaction.get(openRef);
    if (open.exists) throw new RegistrationError("already-exists", "You are already checked in.");
    transaction.create(attendanceRef, {
      communityId,
      staffId: uid,
      staffName: staff.name || "",
      gateName: staff.gateAssignment || "Not assigned",
      checkInTime: FieldValue.serverTimestamp(),
      checkOutTime: null,
      status: "checked_in",
      checkInLocation,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    transaction.create(openRef, {attendanceId: attendanceRef.id, communityId, staffId: uid});
  });
  return {success: true, attendanceId: attendanceRef.id};
}

async function securityCheckOutCore({db, auth, data}) {
  const gps = validateGps(data, {required: false});
  const {uid, communityId, community} = await loadAttendanceAuthority(db, auth);
  let audit = {locationCaptured: false};
  try {
    audit = locationAudit(gps, validatedCommunityLocation(community));
  } catch (error) {
    if (gps && error?.message !== LOCATION_NOT_CONFIGURED) throw error;
  }
  const openRef = db.collection("securityAttendanceOpen").doc(uid);
  const legacyOpen = await db.collection("staffAttendance")
    .where("communityId", "==", communityId)
    .where("staffId", "==", uid)
    .where("status", "==", "checked_in")
    .limit(1)
    .get();
  await db.runTransaction(async (transaction) => {
    const open = await transaction.get(openRef);
    const legacyRecord = legacyOpen.docs?.[0];
    if (!open.exists && !legacyRecord) {
      throw new RegistrationError("not-found", "No active check-in found.");
    }
    const openData = open.exists
      ? open.data()
      : {attendanceId: legacyRecord.id, communityId, staffId: uid};
    if (openData?.staffId !== uid || openData?.communityId !== communityId) {
      throw new RegistrationError("permission-denied", "Attendance ownership could not be verified.");
    }
    const attendanceRef = db.collection("staffAttendance").doc(openData.attendanceId);
    const attendance = await transaction.get(attendanceRef);
    const record = attendance.data();
    if (!attendance.exists || record?.staffId !== uid || record?.communityId !== communityId || record?.checkOutTime != null) {
      throw new RegistrationError("failed-precondition", "Active attendance record is invalid.");
    }
    transaction.update(attendanceRef, {
      checkOutTime: FieldValue.serverTimestamp(),
      status: "completed",
      checkOutLocation: audit,
      updatedAt: FieldValue.serverTimestamp(),
    });
    if (open.exists) transaction.delete(openRef);
  });
  return {success: true, locationCaptured: audit.locationCaptured !== false};
}

module.exports = {
  LOCATION_NOT_CONFIGURED,
  MAX_ACCEPTED_ACCURACY_METERS,
  validateGps,
  haversineMeters,
  validatedCommunityLocation,
  locationAudit,
  requireInsideGeofence,
  loadAttendanceAuthority,
  securityCheckInCore,
  securityCheckOutCore,
};
