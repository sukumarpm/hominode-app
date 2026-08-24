const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { getAuth } = require("firebase-admin/auth");

const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");

const {
  RegistrationError,
  registerResidentCore,
} = require("./register_resident");

const {
  createCommunityCore,
} = require("./create_community");

const {
  updateCommunityCore,
  setCommunityActiveCore,
} = require("./tenant_management");

const {
  createAdminCore,
  updateAdminAssignmentsCore,
  setAdminActiveCore,
} = require("./admin_management");

const {
  listCommunityInvitesCore,
  createCommunityInviteCore,
  revokeCommunityInviteCore,
} = require("./community_invites");

const {
  createSecurityStaffCore,
  assignSecurityWorkCore,
  deleteSecurityPlaceCore,
  removeSecurityAssignmentCore,
} = require("./security_management");
const {
  securityCheckInCore,
  securityCheckOutCore,
} = require("./security_attendance");
const {
  communityLocationSearchCore,
  resolveCommunityLocationPlaceCore,
  reverseGeocodeCommunityLocationCore,
} = require("./community_geocoding");
const {updateCommunityLocationCore} = require("./community_location_management");


const REGION = "asia-southeast1";
const GOOGLE_GEOCODING_API_KEY = defineSecret("GOOGLE_GEOCODING_API_KEY");

/*
 * Shared callable wrapper.
 *
 * Converts RegistrationError into Firebase HttpsError while preventing
 * unexpected server errors from leaking implementation details.
 */
function callable(core, failureMessage) {
  return onCall({ region: REGION }, async (request) => {
    try {
      return await core({
        db: getFirestore(),
        auth: request.auth,
        data: request.data,
      });
    } catch (error) {
      if (error instanceof RegistrationError) {
        throw new HttpsError(error.code, error.message);
      }

      console.error(failureMessage, error);

      throw new HttpsError(
        "internal",
        failureMessage
      );
    }
  });
}

exports.assignSecurityWork = callable(
  assignSecurityWorkCore,
  "Security work could not be assigned."
);

exports.deleteSecurityPlace = callable(
  deleteSecurityPlaceCore,
  "Security place could not be removed."
);
exports.removeSecurityAssignment = callable(
  removeSecurityAssignmentCore,
  "Security assignment could not be removed."
);
initializeApp();

/*
 * Resident registration
 */
exports.registerResident = callable(
  registerResidentCore,
  "Registration could not be completed."
);

/*
 * Community management
 */
exports.createCommunity = callable(
  createCommunityCore,
  "Community could not be created."
);

exports.updateCommunity = callable(
  updateCommunityCore,
  "Community could not be updated."
);

exports.setCommunityActive = callable(
  setCommunityActiveCore,
  "Community status could not be updated."
);

exports.searchCommunityLocations = onCall(
  {region: REGION, secrets: [GOOGLE_GEOCODING_API_KEY]},
  async (request) => {
    try {
      return await communityLocationSearchCore({
        db: getFirestore(),
        auth: request.auth,
        data: request.data,
        apiKey: GOOGLE_GEOCODING_API_KEY.value(),
      });
    } catch (error) {
      if (error instanceof RegistrationError) {
        throw new HttpsError(error.code, error.message);
      }
      console.error("Community location search failed.", error);
      throw new HttpsError("internal", "Location search is temporarily unavailable.");
    }
  },
);

exports.resolveCommunityLocationPlace = onCall(
  {region: REGION, secrets: [GOOGLE_GEOCODING_API_KEY]},
  async (request) => {
    try {
      return await resolveCommunityLocationPlaceCore({
        db: getFirestore(),
        auth: request.auth,
        data: request.data,
        apiKey: GOOGLE_GEOCODING_API_KEY.value(),
      });
    } catch (error) {
      if (error instanceof RegistrationError) {
        throw new HttpsError(error.code, error.message);
      }
      console.error("Community place resolution failed.", error);
      throw new HttpsError("internal", "The selected place could not be loaded.");
    }
  },
);

exports.reverseGeocodeCommunityLocation = onCall(
  {region: REGION, secrets: [GOOGLE_GEOCODING_API_KEY]},
  async (request) => {
    try {
      return await reverseGeocodeCommunityLocationCore({
        db: getFirestore(),
        auth: request.auth,
        data: request.data,
        apiKey: GOOGLE_GEOCODING_API_KEY.value(),
      });
    } catch (error) {
      if (error instanceof RegistrationError) {
        throw new HttpsError(error.code, error.message);
      }
      console.error("Community reverse geocoding failed.", error);
      throw new HttpsError(
        "internal",
        "The address could not be determined. Enter the property address manually.",
      );
    }
  },
);

exports.updateCommunityLocation = callable(
  updateCommunityLocationCore,
  "Community location could not be updated."
);

/*
 * Admin management
 */
exports.createAdmin = callable(
  (args) =>
    createAdminCore({
      ...args,
      authAdmin: getAuth(),
    }),
  "Admin could not be created."
);

exports.updateAdminAssignments = callable(
  updateAdminAssignmentsCore,
  "Admin assignments could not be updated."
);

exports.setAdminActive = callable(
  setAdminActiveCore,
  "Admin status could not be updated."
);

/*
 * Security staff management
 */
exports.createSecurityStaff = callable(
  (args) =>
    createSecurityStaffCore({
      ...args,
      authAdmin: getAuth(),
    }),
  "Security staff could not be created."
);

exports.securityCheckIn = callable(
  securityCheckInCore,
  "Security check-in could not be completed."
);

exports.securityCheckOut = callable(
  securityCheckOutCore,
  "Security check-out could not be completed."
);

/*
 * Community invite management
 */
exports.listCommunityInvites = callable(
  listCommunityInvitesCore,
  "Invites could not be loaded."
);

exports.createCommunityInvite = callable(
  createCommunityInviteCore,
  "Invite could not be created."
);

exports.revokeCommunityInvite = callable(
  revokeCommunityInviteCore,
  "Invite could not be revoked."
);
