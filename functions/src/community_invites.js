const crypto = require("node:crypto");
const {FieldValue, Timestamp} = require("firebase-admin/firestore");
const {RegistrationError, normalizeInviteCode, verifiedPhoneAuth} = require("./register_resident");

const INVITE_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
const MAX_CODE_ATTEMPTS = 5;

function validateCommunityId(data, allowedKeys) {
  if (!data || typeof data !== "object" || Object.keys(data).some((key) => !allowedKeys.has(key))) {
    throw new RegistrationError("invalid-argument", "Unexpected invite request fields.");
  }
  const communityId = String(data.communityId ?? "").trim();
  if (!communityId || communityId.length > 80) {
    throw new RegistrationError("invalid-argument", "A valid community ID is required.");
  }
  return communityId;
}

function generateInviteCode(length = 24) {
  return Array.from({length}, () => INVITE_ALPHABET[crypto.randomInt(INVITE_ALPHABET.length)]).join("");
}

async function requireAuthorizedAdmin({db, auth, communityId}) {
  const {uid} = verifiedPhoneAuth(auth);
  const snapshot = await db.collection("admins").doc(uid).get();
  const admin = snapshot.data();
  if (!snapshot.exists || admin?.uid !== uid || admin?.role !== "admin" || admin?.isActive !== true) {
    throw new RegistrationError("permission-denied", "An active admin profile is required.");
  }
  if (!Array.isArray(admin.authorizedCommunityIds) || !admin.authorizedCommunityIds.includes(communityId)) {
    throw new RegistrationError("permission-denied", "The admin is not authorized for this community.");
  }
  const community = await db.collection("communities").doc(communityId).get();
  if (!community.exists || community.data()?.isActive !== true) {
    throw new RegistrationError("failed-precondition", "The selected community is inactive or unavailable.");
  }
  return uid;
}

function serializeInvite(doc) {
  const data = doc.data();
  const millis = (value) => value && typeof value.toMillis === "function" ? value.toMillis() : null;
  return {
    code: String(data.code ?? doc.id),
    communityId: String(data.communityId ?? ""),
    isActive: data.isActive === true,
    createdBy: data.createdBy ?? null,
    createdAt: millis(data.createdAt),
    updatedAt: millis(data.updatedAt),
    expiresAt: millis(data.expiresAt),
    maxUses: data.maxUses ?? null,
    useCount: data.useCount ?? 0,
    usedCount: data.usedCount ?? 0,
  };
}

async function listCommunityInvitesCore({db, auth, data}) {
  const communityId = validateCommunityId(data, new Set(["communityId"]));
  await requireAuthorizedAdmin({db, auth, communityId});
  const snapshot = await db.collection("communityInvites").where("communityId", "==", communityId).get();
  return {
    invites: snapshot.docs.map(serializeInvite).sort((a, b) => (b.createdAt ?? 0) - (a.createdAt ?? 0)),
  };
}

function validateCreateInput(data) {
  const communityId = validateCommunityId(data, new Set(["communityId", "expiresAt", "maxUses"]));
  const expiresAt = data.expiresAt == null ? null : Number(data.expiresAt);
  const maxUses = data.maxUses == null ? null : Number(data.maxUses);
  if (expiresAt != null && (!Number.isFinite(expiresAt) || expiresAt <= Date.now())) {
    throw new RegistrationError("invalid-argument", "Expiry must be in the future.");
  }
  if (maxUses != null && (!Number.isInteger(maxUses) || maxUses < 1)) {
    throw new RegistrationError("invalid-argument", "Usage limit must be at least 1.");
  }
  return {communityId, expiresAt, maxUses};
}

async function createCommunityInviteCore({db, auth, data, codeGenerator = generateInviteCode}) {
  const input = validateCreateInput(data);
  const uid = await requireAuthorizedAdmin({db, auth, communityId: input.communityId});
  for (let attempt = 0; attempt < MAX_CODE_ATTEMPTS; attempt += 1) {
    const code = normalizeInviteCode(codeGenerator());
    if (code.length < 16) throw new RegistrationError("internal", "Invite code generation failed.");
    try {
      await db.collection("communityInvites").doc(code).create({
        code,
        communityId: input.communityId,
        isActive: true,
        createdBy: uid,
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
        expiresAt: input.expiresAt == null ? null : Timestamp.fromMillis(input.expiresAt),
        maxUses: input.maxUses,
        useCount: 0,
        usedCount: 0,
      });
      return {code};
    } catch (error) {
      if (error?.code !== 6 && error?.code !== "already-exists") throw error;
    }
  }
  throw new RegistrationError("resource-exhausted", "Could not allocate a unique invite code. Try again.");
}

async function revokeCommunityInviteCore({db, auth, data}) {
  const communityId = validateCommunityId(data, new Set(["communityId", "inviteCode"]));
  const inviteCode = normalizeInviteCode(data.inviteCode);
  if (!inviteCode || inviteCode !== data.inviteCode) {
    throw new RegistrationError("invalid-argument", "A normalized invite code is required.");
  }
  const uid = await requireAuthorizedAdmin({db, auth, communityId});
  const ref = db.collection("communityInvites").doc(inviteCode);
  await db.runTransaction(async (transaction) => {
    const invite = await transaction.get(ref);
    if (!invite.exists) throw new RegistrationError("not-found", "Community invite was not found.");
    if (invite.data()?.communityId !== communityId) {
      throw new RegistrationError("permission-denied", "Invite does not belong to the selected community.");
    }
    transaction.update(ref, {
      isActive: false,
      revokedAt: FieldValue.serverTimestamp(),
      revokedBy: uid,
      updatedAt: FieldValue.serverTimestamp(),
    });
  });
  return {code: inviteCode, isActive: false};
}

module.exports = {
  generateInviteCode,
  requireAuthorizedAdmin,
  listCommunityInvitesCore,
  createCommunityInviteCore,
  revokeCommunityInviteCore,
};
