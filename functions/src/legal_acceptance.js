const {FieldValue} = require("firebase-admin/firestore");
const {RegistrationError} = require("./register_resident");
const {APP_CONTEXTS} = require("./notifications");

const CURRENT_LEGAL_VERSIONS = Object.freeze({
  termsVersion: "2026-08-28.v1",
  privacyVersion: "2026-08-28.v1",
});

const PROFILE_COLLECTIONS = Object.freeze({
  resident: "users",
  admin: "admins",
  security: "securityStaff",
});

function normalizedString(value) {
  return typeof value === "string" ? value.trim() : "";
}

function requireAuthenticated(auth) {
  if (!auth?.uid) {
    throw new RegistrationError("unauthenticated", "Authentication is required.");
  }
  return auth.uid;
}

function requireAppContext(app) {
  const firebaseAppId = normalizedString(app?.appId);
  const context = APP_CONTEXTS[firebaseAppId];
  if (!context) {
    throw new RegistrationError(
      "failed-precondition",
      "This Firebase application is not authorized for legal acceptance.",
    );
  }
  return context;
}

function requireDisplayedVersions(data) {
  if (data?.termsVersion !== CURRENT_LEGAL_VERSIONS.termsVersion ||
      data?.privacyVersion !== CURRENT_LEGAL_VERSIONS.privacyVersion) {
    throw new RegistrationError(
      "failed-precondition",
      "The Terms or Privacy Policy changed. Refresh the app and review the current versions.",
    );
  }
}

function requireCanonicalProfile(uid, role, snapshot) {
  const profile = snapshot.data();
  const roleValid = role === "admin" ?
    ["admin", "superAdmin"].includes(profile?.role) : profile?.role === role;
  const commonValid = snapshot.exists && profile?.uid === uid &&
    roleValid && profile?.isActive === true;
  const residentValid = role !== "resident" ||
    (profile?.approvalStatus === "approved" &&
      (profile?.status == null || profile.status === "active"));
  if (!commonValid || !residentValid) {
    throw new RegistrationError(
      "permission-denied",
      `An active canonical ${role} profile is required.`,
    );
  }
}

function legalAcceptanceIsCurrent(value) {
  return value?.termsVersion === CURRENT_LEGAL_VERSIONS.termsVersion &&
    value?.privacyVersion === CURRENT_LEGAL_VERSIONS.privacyVersion &&
    value?.acceptedAt != null;
}

async function acceptCurrentLegalTermsCore({db, auth, app, data}) {
  const uid = requireAuthenticated(auth);
  const appContext = requireAppContext(app);
  requireDisplayedVersions(data);

  const collection = PROFILE_COLLECTIONS[appContext.role];
  const profileRef = db.collection(collection).doc(uid);
  const snapshot = await profileRef.get();
  requireCanonicalProfile(uid, appContext.role, snapshot);

  const legalAcceptance = {
    termsVersion: CURRENT_LEGAL_VERSIONS.termsVersion,
    privacyVersion: CURRENT_LEGAL_VERSIONS.privacyVersion,
    acceptedAt: FieldValue.serverTimestamp(),
  };
  await profileRef.update({legalAcceptance});

  return {
    accepted: true,
    termsVersion: legalAcceptance.termsVersion,
    privacyVersion: legalAcceptance.privacyVersion,
  };
}

module.exports = {
  CURRENT_LEGAL_VERSIONS,
  acceptCurrentLegalTermsCore,
  legalAcceptanceIsCurrent,
};
