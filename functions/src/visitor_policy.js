// Shared, server-only visitor authorization. No credential material belongs here.
const { RegistrationError } = require("./register_resident");
const {
  trustedResidentType,
  identityVerificationRequired,
  identityIsVerified,
  resolveFlatOccupant,
} = require("./resident_identity");
const { normalizeIanaTimeZone } = require("./tenant_management");

const WINDOW_MS = 24 * 60 * 60 * 1000;
const APPROVAL_MODES = [
  "resident_authorized",
  "tenant_approval_required",
  "all_approval_required",
];
const PET_MODES = ["allowed", "not_allowed", "temporarily_restricted"];
const PET_MESSAGE =
  "Pets are not permitted for this visit. You may continue without a pet.";
const fail = (code, message) => {
  throw new RegistrationError(code, message);
};
function millis(value) {
  if (typeof value?.toMillis === "function") return value.toMillis();
  if (value instanceof Date) return value.getTime();
  return Number.isSafeInteger(value) ? value : null;
}
function keys(value, allowed) {
  if (
    !value ||
    typeof value !== "object" ||
    Array.isArray(value) ||
    Object.keys(value).some((key) => !allowed.includes(key))
  ) {
    fail("invalid-argument", "Unsupported visitor policy field.");
  }
}
function interval(value) {
  if (value == null) return null;
  keys(value, ["startAt", "endAt"]);
  const startAt = millis(value.startAt),
    endAt = millis(value.endAt);
  if (
    startAt == null ||
    endAt == null ||
    startAt < 0 ||
    endAt <= startAt ||
    endAt > 8640000000000000
  ) {
    fail("invalid-argument", "A valid start and end instant is required.");
  }
  return { startAt, endAt };
}
function validatePolicy(value) {
  keys(value, [
    "schemaVersion",
    "enabled",
    "timeZone",
    "approvalMode",
    "emergency",
    "pets",
  ]);
  if (
    value.schemaVersion !== 1 ||
    typeof value.enabled !== "boolean" ||
    !APPROVAL_MODES.includes(value.approvalMode) ||
    typeof value.timeZone !== "string"
  ) {
    fail("invalid-argument", "Invalid visitor policy configuration.");
  }
  const timeZone = normalizeIanaTimeZone(value.timeZone);
  keys(value.pets, ["mode", "normalMode", "restriction"]);
  if (
    !PET_MODES.includes(value.pets.mode) ||
    !["allowed", "not_allowed"].includes(value.pets.normalMode)
  ) {
    fail("invalid-argument", "Invalid pet policy.");
  }
  const restriction = interval(value.pets.restriction);
  if (
    (value.pets.mode === "temporarily_restricted") !== (restriction != null) ||
    (value.pets.mode !== "temporarily_restricted" &&
      value.pets.normalMode !== value.pets.mode)
  ) {
    fail(
      "invalid-argument",
      "Pet restriction and normal policy are inconsistent.",
    );
  }
  return {
    schemaVersion: 1,
    enabled: value.enabled,
    timeZone,
    approvalMode: value.approvalMode,
    emergency: interval(value.emergency),
    pets: {
      mode: value.pets.mode,
      normalMode: value.pets.normalMode,
      restriction,
    },
  };
}
function communityPolicy(community) {
  if (community?.visitorPolicy == null)
    return {
      schemaVersion: 1,
      enabled: false,
      timeZone: community?.timeZone || null,
      approvalMode: "resident_authorized",
      emergency: null,
      pets: { mode: "allowed", normalMode: "allowed", restriction: null },
      revision: 0,
    };
  const { revision, updatedAt, updatedBy, enforcementStartedAt, ...input } =
    community.visitorPolicy;
  // Corrupt server configuration fails closed, rather than silently weakening it.
  return {
    ...validatePolicy(input),
    revision,
    updatedAt,
    updatedBy,
    enforcementStartedAt,
  };
}
function residentIdentity(profile, community) {
  const role = trustedResidentType(profile);
  const verified = identityIsVerified(profile);
  const required = identityVerificationRequired(role, community);
  if (!role || (required && !verified)) {
    fail(
      "permission-denied",
      "Resident identity authorization is unavailable.",
    );
  }
  return {
    residentType: role,
    identityVerified: verified,
    identityBasis: verified ? "verified" : "community_owner_exemption",
  };
}
function bringingPet(value) {
  if (value === undefined) return false;
  if (typeof value !== "boolean")
    fail("invalid-argument", "bringingPet must be a boolean.");
  return value;
}
function activeAt(range, now) {
  return range != null && now >= range.startAt && now < range.endAt;
}
function assertPets(policy, pet, arrival) {
  if (!pet || !policy.enabled) return;
  const pets = policy.pets;
  const overlap =
    pets.restriction != null &&
    arrival - WINDOW_MS < pets.restriction.endAt &&
    arrival + WINDOW_MS >= pets.restriction.startAt;
  if (
    pets.normalMode === "not_allowed" ||
    (pets.mode === "temporarily_restricted" && overlap)
  ) {
    fail("failed-precondition", PET_MESSAGE);
  }
}
function invitationDecision({ community, profile, arrival, pet, now }) {
  const identity = residentIdentity(profile, community);
  const policy = require("./visitor_policy_resolver").resolveEffectiveVisitorPolicy(community, now);
  assertPets(policy, pet, arrival);
  const emergency = policy.enabled && activeAt(policy.emergency, now);
  const mode = policy.enabled ? policy.approvalMode : "resident_authorized";
  const pending =
    emergency ||
    mode === "all_approval_required" ||
    (mode === "tenant_approval_required" && identity.residentType === "tenant");
  return {
    authorizationState: pending ? "pending_admin" : "auto_authorized",
    snapshot: {
      schemaVersion: 1,
      revision: policy.revision || 0,
      enforced: policy.enabled,
      approvalMode: mode,
      emergency,
      ...identity,
      evaluatedAt: now,
    },
  };
}
function assertVisitorAuthorized(visitor, community, { now = Date.now(), profile } = {}) {
  const policy = require("./visitor_policy_resolver").resolveEffectiveVisitorPolicy(community, now);
  if (["rejected", "revoked"].includes(visitor.authorizationState) ||
      ["rejected", "cancelled"].includes(visitor.status) ||
      visitor.gateAccessStatus === "denied" || visitor.gateEntryDeniedAt != null) {
    fail("failed-precondition", "This invitation is not authorized for entry.");
  }
  const pet = bringingPet(visitor.bringingPet);
  const arrival = millis(visitor.expectedArrival ?? visitor.expectedTime);
  if (arrival == null) fail("failed-precondition", "This invitation has no valid arrival time.");
  assertPets(policy, pet, arrival);
  // Unmanaged legacy invitations issued after enforcement began
  // must not bypass server-managed authorization.
  if (policy.enabled && visitor.authorizationManaged !== true) {
    const created = millis(visitor.createdAt);
    const cutover = millis(policy.enforcementStartedAt);
    const compatibilityIssued =
      visitor.visitorPolicySnapshot?.schemaVersion === 1 &&
      visitor.visitorPolicySnapshot?.enforced === false;

    if (!compatibilityIssued &&
        (created == null || cutover == null || created >= cutover)) {
      fail(
        "failed-precondition",
        "This invitation requires authorization review.",
      );
    }
  }

  if (!policy.enabled) return;
  // An old automatic authorization is not evidence of Admin approval.
  if (!profile) fail("permission-denied", "Trusted visitor host identity is required.");
  const identity = residentIdentity(profile, community);
  const needsApproval = activeAt(policy.emergency, now) ||
    policy.approvalMode === "all_approval_required" ||
    (policy.approvalMode === "tenant_approval_required" && identity.residentType === "tenant");
  if (needsApproval && !(visitor.authorizationState === "admin_authorized" &&
      typeof visitor.authorizationActorUid === "string" &&
      visitor.authorizationActorUid.length > 0 &&
      visitor.approvedBy === visitor.authorizationActorUid)) {
    fail("failed-precondition", "This invitation requires Admin approval under the current policy.");
  }
}

async function assertVisitorHost({ db, read, visitor, community, now = Date.now() }) {
  if (
    visitor.authorizationManaged !== true &&
    !require("./visitor_policy_resolver")
      .resolveEffectiveVisitorPolicy(community, now).enabled
  )
    return;
  const uid = visitor.hostUserId;
  if (
    typeof uid !== "string" ||
    !uid ||
    uid.includes("/") ||
    (visitor.residentId != null && visitor.residentId !== uid) ||
    typeof visitor.flatId !== "string" ||
    !visitor.flatId ||
    visitor.flatId.includes("/")
  ) {
    fail("permission-denied", "Visitor host assignment is inconsistent.");
  }
  const [profileSnapshot, flatSnapshot] = await Promise.all([
    read(db.collection("users").doc(uid)),
    read(db.collection("flats").doc(visitor.flatId)),
  ]);
  const profile = profileSnapshot.data(),
    flat = flatSnapshot.data();
  let occupant;
  try {
    occupant = resolveFlatOccupant(flat);
  } catch (_) {
    fail("permission-denied", "Visitor host assignment is inconsistent.");
  }
  if (
    !profileSnapshot.exists ||
    profile.uid !== uid ||
    profile.role !== "resident" ||
    profile.approvalStatus !== "approved" ||
    profile.isActive !== true ||
    (profile.status != null && profile.status !== "active") ||
    profile.communityId !== visitor.communityId ||
    profile.flatId !== visitor.flatId ||
    !flatSnapshot.exists ||
    flat.communityId !== visitor.communityId ||
    flat.status !== "occupied" ||
    occupant?.uid !== uid
  ) {
    fail(
      "permission-denied",
      "Visitor host is no longer eligible in this community.",
    );
  }
  residentIdentity(profile, community);
  return profile;
}

module.exports = {
  WINDOW_MS,
  APPROVAL_MODES,
  PET_MODES,
  PET_MESSAGE,
  millis,
  keys,
  validatePolicy,
  communityPolicy,
  residentIdentity,
  bringingPet,
  activeAt,
  assertPets,
  invitationDecision,
  assertVisitorAuthorized,
  assertVisitorHost,
};
