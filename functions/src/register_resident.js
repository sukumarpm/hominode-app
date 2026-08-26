const {FieldValue} = require("firebase-admin/firestore");
const {residentOnboardingId} = require("./resident_import_ids");

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
  const declaredResidentType = String(data?.residentType ?? "").trim().toLowerCase();
  const email = data?.email == null || String(data.email).trim() === "" ? null : String(data.email).trim().toLowerCase();
  if (fullName.length < 2 || fullName.length > 120) throw new RegistrationError("invalid-argument", "Enter a valid full name.");
  if (!buildingReference || buildingReference.length > 120) throw new RegistrationError("invalid-argument", "Building reference is required.");
  if (!unitReference || unitReference.length > 120) throw new RegistrationError("invalid-argument", "Unit reference is required.");
  if (!["owner", "tenant"].includes(declaredResidentType)) throw new RegistrationError("invalid-argument", "Resident type must be owner or tenant.");
  if (email && (email.length > 254 || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email))) throw new RegistrationError("invalid-argument", "Enter a valid email address.");
  return {inviteCode, fullName, buildingReference, unitReference, email, declaredResidentType};
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
    existing.declaredResidentType === expected.declaredResidentType &&
    (existing.email ?? null) === expected.email;
}

function validateImportedOnboarding(onboarding, identity) {
  const communityId = typeof onboarding?.communityId === "string" ? onboarding.communityId.trim() : "";
  const fullName = typeof onboarding?.residentName === "string" ? onboarding.residentName.trim() : "";
  const buildingId = typeof onboarding?.buildingId === "string" ? onboarding.buildingId.trim() : "";
  const buildingName = typeof onboarding?.buildingName === "string" ? onboarding.buildingName.trim() : "";
  const flatId = typeof onboarding?.flatId === "string" ? onboarding.flatId.trim() : "";
  const flatLabel = typeof onboarding?.flatLabel === "string" ? onboarding.flatLabel.trim() : "";
  const unitId = typeof onboarding?.unitId === "string" ? onboarding.unitId.trim() : "";
  const residentType = typeof onboarding?.residentType === "string" ? onboarding.residentType.trim().toLowerCase() : "";
  if (!communityId || onboarding?.phoneNumber !== identity.phoneNumber ||
      fullName.length < 2 || fullName.length > 120 || !buildingId || !buildingName ||
      !flatId || !flatLabel || !unitId || !["owner", "tenant"].includes(residentType)) {
    throw new RegistrationError("failed-precondition", "Imported resident onboarding data is incomplete or invalid.");
  }
  return {
    communityId,
    fullName,
    buildingId,
    buildingName,
    flatId,
    flatLabel,
    unitId,
    residentType,
    buildingReference: typeof onboarding.buildingReference === "string" && onboarding.buildingReference.trim() ? onboarding.buildingReference.trim() : buildingName,
    unitReference: typeof onboarding.unitReference === "string" && onboarding.unitReference.trim() ? onboarding.unitReference.trim() : flatLabel,
    email: typeof onboarding.email === "string" && onboarding.email.trim() ? onboarding.email.trim().toLowerCase() : null,
    importJobId: typeof onboarding.importJobId === "string" ? onboarding.importJobId : null,
  };
}

async function claimImportedOnboardingCore({db, identity}) {
  const result = await db.collection("residentOnboarding")
    .where("phoneNumber", "==", identity.phoneNumber).get();
  const candidates = result.docs.filter((doc) => {
    const value = doc.data();
    return (value?.status === "pending_registration" && value?.claimedByUid == null) ||
      (value?.status === "claimed" && value?.claimedByUid === identity.uid);
  });
  if (candidates.length === 0) {
    throw new RegistrationError("not-found", "No imported resident onboarding was found for this verified phone number.");
  }
  const claimed = candidates.filter((doc) => doc.data()?.claimedByUid === identity.uid);
  const selected = claimed.length === 1 ? claimed[0] : candidates.length === 1 ? candidates[0] : null;
  if (!selected) {
    throw new RegistrationError("failed-precondition", "Multiple imported resident onboardings use this phone number. Contact an administrator.");
  }
  const onboardingRef = db.collection("residentOnboarding").doc(selected.id);
  const userRef = db.collection("users").doc(identity.uid);
  return db.runTransaction(async (transaction) => {
    const onboardingSnapshot = await transaction.get(onboardingRef);
    const onboarding = onboardingSnapshot.data();
    const imported = validateImportedOnboarding(onboarding, identity);
    const communityRef = db.collection("communities").doc(imported.communityId);
    const [userSnapshot, communitySnapshot] = await Promise.all([
      transaction.get(userRef),
      transaction.get(communityRef),
    ]);
    if (!communitySnapshot.exists || communitySnapshot.data()?.isActive !== true) {
      throw new RegistrationError("failed-precondition", "Community is inactive or unavailable.");
    }
    if (userSnapshot.exists) {
      const user = userSnapshot.data();
      if (user?.uid === identity.uid && user?.phoneNumber === identity.phoneNumber &&
          user?.role === "resident" && user?.communityId === imported.communityId &&
          onboarding?.status === "claimed" && onboarding?.claimedByUid === identity.uid) {
        return {status: user.approvalStatus ?? "pending", communityId: imported.communityId, idempotent: true, imported: true};
      }
      throw new RegistrationError("already-exists", "A resident profile already exists for this account.");
    }
    if (onboarding?.status !== "pending_registration" || onboarding?.claimedByUid != null) {
      throw new RegistrationError("failed-precondition", "Imported resident onboarding has already been claimed.");
    }
    transaction.set(userRef, {
      uid: identity.uid,
      phoneNumber: identity.phoneNumber,
      phone: identity.phoneNumber,
      name: imported.fullName,
      fullName: imported.fullName,
      email: imported.email,
      communityId: imported.communityId,
      communityInviteCode: null,
      role: "resident",
      isActive: false,
      approvalStatus: "pending",
      identityVerified: false,
      identityVerificationStatus: "verification_required",
      buildingReference: imported.buildingReference,
      unitReference: imported.unitReference,
      buildingId: imported.buildingId,
      buildingName: imported.buildingName,
      unitId: imported.unitId,
      flatId: imported.flatId,
      flatLabel: imported.flatLabel,
      ownershipType: imported.residentType,
      residentType: imported.residentType,
      importJobId: imported.importJobId,
      creationSource: "admin_bulk_import_claim",
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    transaction.update(onboardingRef, {
      status: "claimed",
      claimedByUid: identity.uid,
      claimedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    return {status: "pending", communityId: imported.communityId, idempotent: false, imported: true};
  });
}

async function registerResidentCore({db, auth, data, now = Date.now()}) {
  const identity = verifiedPhoneAuth(auth);
  if (data?.claimImportedOnboarding === true) {
    if (!data || typeof data !== "object" || Array.isArray(data) ||
        Object.keys(data).some((key) => key !== "claimImportedOnboarding")) {
      throw new RegistrationError("invalid-argument", "Only the imported onboarding claim flag is accepted.");
    }
    return claimImportedOnboardingCore({db, identity});
  }
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

    // A trusted bulk import creates onboarding data, never an Auth account.
    // Bind that data only after this resident proves ownership of the same
    // phone number through the existing OTP registration flow.
    const onboardingRef = db.collection("residentOnboarding")
      .doc(residentOnboardingId(communityId, identity.phoneNumber));
    const onboardingSnapshot = await transaction.get(onboardingRef);
    const onboarding = onboardingSnapshot.exists ? onboardingSnapshot.data() : null;
    const imported = onboarding &&
      onboarding.communityId === communityId &&
      onboarding.phoneNumber === identity.phoneNumber &&
      onboarding.status === "pending_registration" &&
      onboarding.claimedByUid == null;

    transaction.set(userRef, {
      uid: identity.uid, phoneNumber: identity.phoneNumber, phone: identity.phoneNumber,
      name: input.fullName, fullName: input.fullName, email: input.email,
      communityId, communityInviteCode: input.inviteCode,
      role: "resident", isActive: false, approvalStatus: "pending", identityVerified: false,
      identityVerificationStatus: "verification_required",
      declaredResidentType: input.declaredResidentType,
      buildingReference: imported ? onboarding.buildingReference : input.buildingReference,
      unitReference: imported ? onboarding.unitReference : input.unitReference,
      buildingId: imported ? onboarding.buildingId : null,
      buildingName: imported ? onboarding.buildingName : null,
      unitId: imported ? onboarding.unitId : null,
      flatId: imported ? onboarding.flatId : null,
      flatLabel: imported ? onboarding.flatLabel : null,
      ownershipType: imported ? onboarding.residentType : null,
      residentType: imported ? onboarding.residentType : null,
      importJobId: imported ? onboarding.importJobId : null,
      creationSource: imported ? "admin_bulk_import_claim" : "resident_registration",
      createdAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp(),
    });
    if (imported) {
      transaction.update(onboardingRef, {
        status: "claimed",
        claimedByUid: identity.uid,
        claimedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
    }
    transaction.update(inviteRef, {
      useCount: useCount + 1, usedCount: useCount + 1, updatedAt: FieldValue.serverTimestamp(),
    });
    return {status: "pending", communityId, idempotent: false};
  });
}

module.exports = {RegistrationError, normalizeInviteCode, validateInput, verifiedPhoneAuth, isIdempotentExisting, validateImportedOnboarding, claimImportedOnboardingCore, registerResidentCore};
