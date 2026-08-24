const {FieldValue} = require("firebase-admin/firestore");

class RegistrationError extends Error {
  constructor(code, message) {
    super(message);
    this.code = code;
  }
}

const normalizeInviteCode = (value) =>
  String(value ?? "").trim().toUpperCase().replace(/[^A-Z0-9_-]/g, "");

function validateInput(data) {
  const inviteCode = normalizeInviteCode(data?.inviteCode);
  if (inviteCode.length < 4 || inviteCode !== data?.inviteCode) {
    throw new RegistrationError("invalid-argument", "A normalized invite code is required.");
  }
  const fullName = String(data?.fullName ?? "").trim();
  const buildingReference = String(data?.buildingReference ?? "").trim();
  const unitReference = String(data?.unitReference ?? "").trim();
  const email = data?.email == null || String(data.email).trim() === "" ? null : String(data.email).trim().toLowerCase();
  if (fullName.length < 2 || fullName.length > 120) throw new RegistrationError("invalid-argument", "Enter a valid full name.");
  if (!buildingReference || buildingReference.length > 120) throw new RegistrationError("invalid-argument", "Building reference is required.");
  if (!unitReference || unitReference.length > 120) throw new RegistrationError("invalid-argument", "Unit reference is required.");
  if (email && (email.length > 254 || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email))) throw new RegistrationError("invalid-argument", "Enter a valid email address.");
  return {inviteCode, fullName, buildingReference, unitReference, email};
}

function verifiedPhoneAuth(auth) {
  const phoneNumber = auth?.token?.phone_number;
  const provider = auth?.token?.firebase?.sign_in_provider;
  if (!auth?.uid || typeof phoneNumber !== "string" || provider !== "phone") {
    throw new RegistrationError("unauthenticated", "A verified Firebase Phone Auth session is required.");
  }
  return {uid: auth.uid, phoneNumber};
}

function timestampMillis(value) {
  if (value == null) return null;
  if (typeof value.toMillis === "function") return value.toMillis();
  if (value instanceof Date) return value.getTime();
  return null;
}

function isIdempotentExisting(existing, expected) {
  return existing.uid === expected.uid &&
    existing.phoneNumber === expected.phoneNumber &&
    existing.communityInviteCode === expected.inviteCode &&
    existing.communityId === expected.communityId &&
    existing.role === "resident" &&
    existing.name === expected.fullName &&
    existing.buildingReference === expected.buildingReference &&
    existing.unitReference === expected.unitReference &&
    (existing.email ?? null) === expected.email;
}

async function registerResidentCore({db, auth, data, now = Date.now()}) {
  const identity = verifiedPhoneAuth(auth);
  const input = validateInput(data);
  const inviteRef = db.collection("communityInvites").doc(input.inviteCode);
  const userRef = db.collection("users").doc(identity.uid);

  return db.runTransaction(async (transaction) => {
    const invite = await transaction.get(inviteRef);
    if (!invite.exists) throw new RegistrationError("not-found", "Community invite was not found.");
    const inviteData = invite.data();
    const communityId = typeof inviteData.communityId === "string" ? inviteData.communityId : "";
    const existing = await transaction.get(userRef);
    const expected = {...identity, ...input, communityId};
    if (existing.exists) {
      if (isIdempotentExisting(existing.data(), expected)) {
        return {status: existing.data().approvalStatus ?? "pending", communityId, idempotent: true};
      }
      throw new RegistrationError("already-exists", "A resident profile already exists for this account.");
    }
    if (!inviteData.isActive || !communityId) throw new RegistrationError("failed-precondition", "Community invite is inactive or invalid.");
    const expiresAt = timestampMillis(inviteData.expiresAt);
    if (expiresAt != null && expiresAt < now) throw new RegistrationError("failed-precondition", "Community invite has expired.");
    const useCount = Math.max(Number(inviteData.useCount ?? 0), Number(inviteData.usedCount ?? 0));
    const maxUses = inviteData.maxUses == null ? null : Number(inviteData.maxUses);
    if (!Number.isInteger(useCount) || useCount < 0 || (maxUses != null && (!Number.isInteger(maxUses) || maxUses < 1))) {
      throw new RegistrationError("failed-precondition", "Community invite counters are invalid.");
    }
    if (maxUses != null && useCount >= maxUses) throw new RegistrationError("resource-exhausted", "Community invite has reached its usage limit.");

    const communityRef = db.collection("communities").doc(communityId);
    const community = await transaction.get(communityRef);
    if (!community.exists || community.data().isActive !== true) throw new RegistrationError("failed-precondition", "Community is inactive or unavailable.");

    transaction.set(userRef, {
      uid: identity.uid, phoneNumber: identity.phoneNumber, phone: identity.phoneNumber,
      name: input.fullName, fullName: input.fullName, email: input.email,
      communityId, communityInviteCode: input.inviteCode,
      role: "resident", isActive: false, approvalStatus: "pending",
      buildingReference: input.buildingReference, unitReference: input.unitReference,
      buildingId: null, unitId: null, flatId: null,
      createdAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp(),
    });
    transaction.update(inviteRef, {
      useCount: useCount + 1, usedCount: useCount + 1, updatedAt: FieldValue.serverTimestamp(),
    });
    return {status: "pending", communityId, idempotent: false};
  });
}

module.exports = {RegistrationError, normalizeInviteCode, validateInput, verifiedPhoneAuth, isIdempotentExisting, registerResidentCore};
