const { FieldValue } = require("firebase-admin/firestore");
const { RegistrationError, verifiedPhoneAuth } = require("./register_resident");

const normalizeSlug = (value) => String(value ?? "").trim().toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "");
const normalizeCommunityId = (value) => String(value ?? "").trim().toUpperCase().replace(/[^A-Z0-9_-]+/g, "-").replace(/-+/g, "-").replace(/^[-_]+|[-_]+$/g, "");
const optionalString = (value, max = 500) => {
  const result = String(value ?? "").trim();
  if (result.length > max) throw new RegistrationError("invalid-argument", "Tenant metadata is too long.");
  return result || null;
};

function validateCommunityLocationMetadata(data) {
  const hasLocationConfigured = hasOwn(
    data,
    "locationConfigured",
  );

  const hasLocation = hasOwn(
    data,
    "location",
  );

  if (
    !hasLocationConfigured &&
    !hasLocation
  ) {
    return {};
  }

  if (
    !hasLocationConfigured ||
    typeof data.locationConfigured !== "boolean"
  ) {
    throw new RegistrationError(
      "invalid-argument",
      "locationConfigured must be true or false.",
    );
  }

  if (data.locationConfigured === false) {
    if (
      hasLocation &&
      data.location != null
    ) {
      throw new RegistrationError(
        "invalid-argument",
        "Location must be omitted when locationConfigured is false.",
      );
    }

    return {
      locationConfigured: false,
      location: null,
    };
  }

  const location = data.location;

  if (
    !location ||
    typeof location !== "object" ||
    Array.isArray(location)
  ) {
    throw new RegistrationError(
      "invalid-argument",
      "A valid community location is required.",
    );
  }

  const allowedLocationKeys =
    new Set([
      "latitude",
      "longitude",
      "formattedAddress",
      "placeId",
      "attendanceRadiusMeters",
    ]);

  if (
    Object.keys(location).some(
      (key) =>
        !allowedLocationKeys.has(key),
    )
  ) {
    throw new RegistrationError(
      "invalid-argument",
      "Unsupported community location field.",
    );
  }

  const latitude =
    location.latitude;

  const longitude =
    location.longitude;

  const radius =
    location.attendanceRadiusMeters;

  if (
    typeof latitude !== "number" ||
    !Number.isFinite(latitude) ||
    latitude < -90 ||
    latitude > 90
  ) {
    throw new RegistrationError(
      "invalid-argument",
      "Enter a valid community latitude.",
    );
  }

  if (
    typeof longitude !== "number" ||
    !Number.isFinite(longitude) ||
    longitude < -180 ||
    longitude > 180
  ) {
    throw new RegistrationError(
      "invalid-argument",
      "Enter a valid community longitude.",
    );
  }

  const formattedAddress =
    String(
      location.formattedAddress ?? "",
    ).trim();

  if (
    !formattedAddress ||
    formattedAddress.length > 500
  ) {
    throw new RegistrationError(
      "invalid-argument",
      "Enter a valid community address.",
    );
  }

  if (
    !Number.isInteger(radius) ||
    radius < 25 ||
    radius > 5000
  ) {
    throw new RegistrationError(
      "invalid-argument",
      "Attendance radius must be between 25 and 5000 metres.",
    );
  }

  const placeId =
    optionalString(
      location.placeId,
      500,
    );

  return {
    locationConfigured: true,
    location: {
      latitude,
      longitude,
      formattedAddress,
      placeId,
      attendanceRadiusMeters:
        radius,
    },
  };
}

function validateTenantMetadata(data) {
  const allowedKeys = new Set([
    "communityId",
    "name",
    "slug",
    "websitePath",
    "databaseId",
    "brandName",
    "logoUrl",
    "primaryColor",
    "locationConfigured",
    "location",
  ]);
  if (!data || typeof data !== "object" || Object.keys(data).some((key) => !allowedKeys.has(key))) {
    throw new RegistrationError("invalid-argument", "Unsupported tenant metadata field.");
  }
  const name = String(data?.name ?? "").trim();
  const suppliedSlug = String(data?.slug || normalizeSlug(name)).trim();
  const suppliedPath = String(data?.websitePath || suppliedSlug).trim();
  const slug = normalizeSlug(suppliedSlug);
  const websitePath = normalizeSlug(suppliedPath);
  const communityId = normalizeCommunityId(data?.communityId || slug);
  const databaseId = String(data?.databaseId ?? "(default)").trim() || "(default)";
  if (!communityId || communityId.length > 80) throw new RegistrationError("invalid-argument", "Enter a valid community ID.");
  if (!name || name.length > 120) throw new RegistrationError("invalid-argument", "Enter a valid community name.");
  if (!slug || suppliedSlug !== slug || slug.length > 120) throw new RegistrationError("invalid-argument", "Slug must be lowercase kebab-case.");
  if (!websitePath || suppliedPath !== websitePath || websitePath.length > 120) throw new RegistrationError("invalid-argument", "Website path must be lowercase kebab-case.");
  if (databaseId.length > 120) {
    throw new RegistrationError(
      "invalid-argument",
      "Database ID is too long.",
    );
  }

  const locationMetadata =
    validateCommunityLocationMetadata(data);

  return {
    communityId,
    name,
    slug,
    websitePath,
    databaseId,
    brandName:
      optionalString(data?.brandName, 120) || name,
    logoUrl:
      optionalString(data?.logoUrl, 1000),
    primaryColor:
      optionalString(data?.primaryColor, 32),
    ...locationMetadata,
  };
}

async function requireActiveSuperAdmin(db, auth) {
  const { uid } = verifiedPhoneAuth(auth);
  const snapshot = await db.collection("admins").doc(uid).get();
  const admin = snapshot.data();
  if (!snapshot.exists || admin?.uid !== uid || admin?.role !== "superAdmin" || admin?.isActive !== true) throw new RegistrationError("permission-denied", "An active superAdmin profile is required.");
  return uid;
}

async function rejectLegacyDuplicate(db, field, value, communityId) {
  const result = await db.collection("communities").where(field, "==", value).limit(2).get();
  if (result.docs.some((doc) => doc.id !== communityId)) throw new RegistrationError("already-exists", `Another community already uses this ${field}.`);
}

const reservationRef = (db, type, value) => db.collection(`tenant_${type}`).doc(value);

async function updateCommunityCore({ db, auth, data }) {
  const uid = await requireActiveSuperAdmin(db, auth);
  const input = validateTenantMetadata(data);
  await rejectLegacyDuplicate(db, "slug", input.slug, input.communityId);
  await rejectLegacyDuplicate(db, "websitePath", input.websitePath, input.communityId);
  const communityRef = db.collection("communities").doc(input.communityId);
  return db.runTransaction(async (transaction) => {
    const currentSnapshot = await transaction.get(communityRef);
    if (!currentSnapshot.exists) throw new RegistrationError("not-found", "Community was not found.");
    const current = currentSnapshot.data();
    const slugRef = reservationRef(db, "slugs", input.slug);
    const pathRef = reservationRef(db, "websitePaths", input.websitePath);
    const slugReservation = await transaction.get(slugRef);
    const pathReservation = await transaction.get(pathRef);
    const oldSlugRef = current.slug && current.slug !== input.slug ? reservationRef(db, "slugs", current.slug) : null;
    const oldPathRef = current.websitePath && current.websitePath !== input.websitePath ? reservationRef(db, "websitePaths", current.websitePath) : null;
    const oldSlugReservation = oldSlugRef ? await transaction.get(oldSlugRef) : null;
    const oldPathReservation = oldPathRef ? await transaction.get(oldPathRef) : null;
    if (slugReservation.exists && slugReservation.data()?.communityId !== input.communityId) throw new RegistrationError("already-exists", "Another community already uses this slug.");
    if (pathReservation.exists && pathReservation.data()?.communityId !== input.communityId) throw new RegistrationError("already-exists", "Another community already uses this websitePath.");
    transaction.set(slugRef, { communityId: input.communityId });
    transaction.set(pathRef, { communityId: input.communityId });
    if (oldSlugRef && oldSlugReservation?.data()?.communityId === input.communityId) transaction.delete(oldSlugRef);
    if (oldPathRef && oldPathReservation?.data()?.communityId === input.communityId) transaction.delete(oldPathRef);
    const { communityId, ...metadata } = input;

    const updateData = {
      ...metadata,
      updatedAt: FieldValue.serverTimestamp(),
      updatedBy: uid,
    };

    if (metadata.location) {
      updateData.location = {
        ...metadata.location,
        updatedAt: FieldValue.serverTimestamp(),
      };
    }

    transaction.update(
      communityRef,
      updateData,
    );

    return { communityId };
  });
}
const hasOwn = (object, key) =>
  Object.prototype.hasOwnProperty.call(object, key);

async function setCommunityActiveCore({ db, auth, data }) {
  const uid = await requireActiveSuperAdmin(db, auth);
  const communityId = normalizeCommunityId(data?.communityId);
  if (!communityId || typeof data?.isActive !== "boolean") throw new RegistrationError("invalid-argument", "Community ID and active status are required.");

  const ref = db.collection("communities").doc(communityId);
  const snapshot = await ref.get();
  if (!snapshot.exists) throw new RegistrationError("not-found", "Community was not found.");
  await ref.update({ isActive: data.isActive, updatedAt: FieldValue.serverTimestamp(), updatedBy: uid });
  return { communityId, isActive: data.isActive };
}

module.exports = {
  normalizeSlug,
  normalizeCommunityId,
  validateTenantMetadata,
  validateCommunityLocationMetadata,
  requireActiveSuperAdmin,
  rejectLegacyDuplicate,
  reservationRef,
  updateCommunityCore,
  setCommunityActiveCore,
};