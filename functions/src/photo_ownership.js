// V2 ownership is server-bound and independent of descriptive image categories.
const { RegistrationError } = require("./register_resident");
const { hasVerifiedPhoneAuth } = require("./phone_auth");
const {
  operationalAccessFailure,
  resolveFlatOccupant,
} = require("./resident_identity");
const fail = (code, message) => {
  throw new RegistrationError(code, message);
};
const SCOPES = ["COMMUNITY", "BUILDING", "UNIT"];
const FIELDS = [
  "contractVersion",
  "ownershipScope",
  "communityId",
  "resourceId",
  "buildingId",
  "unitId",
];
function id(value) {
  if (
    typeof value !== "string" ||
    !value ||
    value !== value.trim() ||
    value.length > 128 ||
    value.includes("\\") ||
    /[\/\u0000-\u001f\u007f]/.test(value) ||
    [".", ".."].includes(value)
  )
    fail("invalid-argument", "A canonical photo resource ID is required.");
  return value;
}
function versioned(value) {
  return (
    value.contractVersion !== undefined || value.ownershipScope !== undefined
  );
}
function requestScope(data) {
  if (!versioned(data)) return null;
  if (
    data.feature !== "apartment" ||
    data.contractVersion !== 2 ||
    !SCOPES.includes(data.ownershipScope)
  )
    fail(
      "invalid-argument",
      "A supported photo ownership contract is required.",
    );
  return {
    contractVersion: 2,
    ownershipScope: data.ownershipScope,
    resourceId: id(data.resourceId),
  };
}
function binding(value, legacyRecord = false) {
  if (!versioned(value))
    return {
      resourceId: id(legacyRecord ? value.buildingId : value.resourceId),
    };
  if (value.contractVersion !== 2 || !SCOPES.includes(value.ownershipScope))
    fail("failed-precondition", "The photo ownership contract is invalid.");
  id(value.resourceId);
  id(value.communityId);
  if (value.ownershipScope === "COMMUNITY") {
    if (
      value.resourceId !== value.communityId ||
      value.buildingId !== undefined ||
      value.unitId !== undefined
    )
      fail("failed-precondition", "The community photo binding is invalid.");
  } else {
    id(value.buildingId);
    if (
      value.ownershipScope === "BUILDING"
        ? value.resourceId !== value.buildingId || value.unitId !== undefined
        : value.resourceId !== id(value.unitId)
    )
      fail("failed-precondition", "The photo resource binding is invalid.");
  }
  return Object.fromEntries(
    FIELDS.filter((key) => value[key] !== undefined).map((key) => [
      key,
      value[key],
    ]),
  );
}
function sameBinding(a, b) {
  const left = binding(a),
    right = binding(b, true);
  return FIELDS.every((key) => left[key] === right[key]);
}
async function target({ db, transaction, ownershipScope, resourceId }) {
  id(resourceId);
  const get = async (collection, key) => {
    const snapshot = await transaction.get(
      db.collection(collection).doc(id(key)),
    );
    const value = snapshot.data();
    if (!snapshot.exists)
      fail("not-found", "The photo resource does not exist.");
    if (
      value.isActive === false ||
      ["deleted", "removed", "rejected"].includes(value.status)
    )
      fail("permission-denied", "The photo resource is unavailable.");
    return value;
  };
  if (!SCOPES.includes(ownershipScope))
    fail("invalid-argument", "The photo scope is unsupported.");
  let communityId, buildingId, unit;
  if (ownershipScope === "COMMUNITY") communityId = resourceId;
  else {
    if (ownershipScope === "UNIT") {
      unit = await get("flats", resourceId);
      buildingId = id(unit.buildingId);
    } else buildingId = resourceId;
    const building = await get("buildings", buildingId);
    communityId = id(building.communityId);
    if (unit && unit.communityId !== communityId)
      fail("permission-denied", "The unit community binding is invalid.");
  }
  const community = await get("communities", communityId);
  if (community.isActive !== true)
    fail("permission-denied", "The community is inactive.");
  return {
    fields: {
      contractVersion: 2,
      ownershipScope,
      communityId,
      resourceId,
      ...(buildingId ? { buildingId } : {}),
      ...(unit ? { unitId: resourceId } : {}),
    },
    community,
    unit,
  };
}
async function photoAuthority(context) {
  const { db, auth, transaction } = context;
  if (!hasVerifiedPhoneAuth(auth))
    fail("unauthenticated", "Verified phone authentication is required.");
  const snapshot = await transaction.get(db.collection("admins").doc(auth.uid));
  const admin = snapshot.data();
  if (
    !snapshot.exists ||
    admin.uid !== auth.uid ||
    admin.role !== "admin" ||
    admin.isActive !== true ||
    admin.phoneNumber !== auth.token.phone_number
  )
    fail("permission-denied", "An active matching administrator is required.");
  const { fields } = await target(context);
  if (
    !Array.isArray(admin.authorizedCommunityIds) ||
    !admin.authorizedCommunityIds.includes(fields.communityId)
  )
    fail("permission-denied", "The photo belongs to another community.");
  return { ...fields, ownerId: auth.uid };
}
async function residentRead(context, image, profile) {
  const bound = binding(image, true);
  const { fields, community, unit } = await target({ ...context, ...bound });
  if (
    !FIELDS.every((key) => fields[key] === bound[key]) ||
    operationalAccessFailure(profile, {
      ...community,
      id: fields.communityId,
    }) ||
    profile.communityId !== fields.communityId
  )
    fail("permission-denied", "Resident photo access is unavailable.");
  if (
    bound.ownershipScope !== "COMMUNITY" &&
    profile.buildingId !== fields.buildingId
  )
    fail("permission-denied", "The photo belongs to another building.");
  if (
    unit &&
    (profile.flatId !== fields.unitId ||
      unit.status !== "occupied" ||
      unit.residentUserId !== context.auth.uid ||
      resolveFlatOccupant(unit).uid !== context.auth.uid ||
      (unit.residentId != null &&
        unit.residentId !== "" &&
        unit.residentId !== context.auth.uid))
  )
    fail(
      "permission-denied",
      "The photo belongs to another unit or the assignment is ambiguous.",
    );
}
module.exports = {
  requestScope,
  versioned,
  binding,
  sameBinding,
  photoAuthority,
  residentRead,
  FIELDS,
};
