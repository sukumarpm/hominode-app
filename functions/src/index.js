const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { getAuth } = require("firebase-admin/auth");
const { getStorage } = require("firebase-admin/storage");
const { getMessaging } = require("firebase-admin/messaging");

const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { defineSecret } = require("firebase-functions/params");

const {
  RegistrationError,
  registerResidentCore,
} = require("./register_resident");

const {
  createMaintenanceBillsCore,
} = require("./billing_management");

const {
  createCommunityCore,
} = require("./create_community");

const {
  updateCommunityCore,
  setCommunityActiveCore,
} = require("./tenant_management");

const {
  verifyPaymentProofCore,
  rejectPaymentProofCore,
} = require("./payment_verification");

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
const { updateCommunityLocationCore } = require("./community_location_management");
const {
  validateResidentBulkImportCore,
  importResidentsBulkCore,
} = require("./resident_bulk_import");
const {
  approveResidentRegistrationCore,
  rejectResidentRegistrationCore,
  deactivateResidentCore,
  reactivateResidentCore,
  reassignResidentCore,
  createResidentOnboardingCore,
  submitResidentIdentityProofCore,
  getResidentIdentityProofUrlCore,
  reviewResidentIdentityProofCore,
  moveOutResidentCore,
  auditResidentAction,
  assignResidentOnboardingToFlatCore,
  listAssignableResidentOnboardingsCore,
  cancelResidentOnboardingReservationCore,
  renameUnitCore,
} = require("./resident_identity");
const {
  registerNotificationDeviceCore,
  unregisterNotificationDeviceCore,
  sendNotificationCore,
} = require("./notifications");
const { acceptCurrentLegalTermsCore } = require("./legal_acceptance");
const { getResidentNoticeIdsCore } = require("./resident_notices");
const {
  resolveResidentCommunityCore,
} = require("./resident_community_resolution");
const {
  getAmenityAvailabilityCore,
  createAmenityBookingCore,
  cancelAmenityBookingCore,
} = require("./amenity_booking");

const {
  refreshPublicPlatformStatsCore,
} = require("./public_platform_stats");


const REGION = "asia-southeast1";
const GOOGLE_GEOCODING_API_KEY = defineSecret("GOOGLE_GEOCODING_API_KEY");

/*
 * Shared callable wrapper.
 *
 * Converts RegistrationError into Firebase HttpsError while preventing
 * unexpected server errors from leaking implementation details.
 */
function callable(core, failureMessage) {
  return onCall({ region: REGION }, callableHandler(core, failureMessage));
}

function appCheckedCallable(
  core,
  failureMessage,
  { includeMessaging = false } = {}
) {
  return onCall(
    { region: REGION, enforceAppCheck: true },
    callableHandler(core, failureMessage, {
      includeAppContext: true,
      includeMessaging,
    })
  );
}

function callableHandler(
  core,
  failureMessage,
  { includeAppContext = false, includeMessaging = false } = {}
) {
  return async (request) => {
    try {
      const context = {
        db: getFirestore(),
        bucket: getStorage().bucket(),
        auth: request.auth,
        data: request.data,
      };
      if (includeAppContext) {
        context.app = request.app;
      }
      if (includeMessaging) context.messaging = getMessaging();
      return await core(context);
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
  };
}
exports.verifyPaymentProof = appCheckedCallable(
  verifyPaymentProofCore,
  "Payment proof could not be verified."
);

const { triggerSosCore, transitionSosCore, getSosContextCore } = require('./sos');
const { dispatchSosEventCore } = require('./sos_notifications');
exports.getSosContext = appCheckedCallable(getSosContextCore, 'Emergency context is unavailable.');
exports.triggerSos = appCheckedCallable(triggerSosCore, 'The emergency alert could not be confirmed. Retry or call Security.');
exports.transitionSos = appCheckedCallable(transitionSosCore, 'The emergency action could not be confirmed. Refresh and retry.');
exports.dispatchSosNotifications = onDocumentCreated({
  region: REGION, document: 'sosNotificationEvents/{eventId}',
  retry: true, timeoutSeconds: 300
}, (event) => dispatchSosEventCore({ db: getFirestore(), messaging: getMessaging(), eventId: event.params.eventId }));

exports.rejectPaymentProof = appCheckedCallable(
  rejectPaymentProofCore,
  "Payment proof could not be rejected."
);
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

exports.registerNotificationDevice = appCheckedCallable(
  registerNotificationDeviceCore,
  "This notification device could not be registered."
);

exports.unregisterNotificationDevice = appCheckedCallable(
  unregisterNotificationDeviceCore,
  "This notification device could not be removed."
);

exports.sendNotification = appCheckedCallable(
  sendNotificationCore,
  "The notification could not be sent.",
  { includeMessaging: true }
);

exports.acceptCurrentLegalTerms = appCheckedCallable(
  acceptCurrentLegalTermsCore,
  "Legal acceptance could not be recorded."
);

exports.getResidentNoticeIds = appCheckedCallable(
  getResidentNoticeIdsCore,
  "Resident notices could not be loaded."
);

exports.resolveResidentCommunity = appCheckedCallable(
  resolveResidentCommunityCore,
  "Community hostname could not be resolved."
);

exports.getAmenityAvailability = appCheckedCallable(
  getAmenityAvailabilityCore,
  "Facility availability could not be loaded."
);

exports.createAmenityBooking = appCheckedCallable(
  createAmenityBookingCore,
  "The facility booking could not be created."
);

exports.cancelAmenityBooking = appCheckedCallable(
  cancelAmenityBookingCore,
  "The facility booking could not be cancelled."
);

exports.refreshPublicPlatformStats = callable(
  refreshPublicPlatformStatsCore,
  "Public platform statistics could not be refreshed."
);

exports.createMaintenanceBills = appCheckedCallable(
  createMaintenanceBillsCore,
  "Maintenance bills could not be created.",
);
initializeApp();

/*
 * Resident registration
 */
exports.registerResident = callable(
  registerResidentCore,
  "Registration could not be completed."
);

exports.validateResidentBulkImport = callable(
  validateResidentBulkImportCore,
  "The resident import could not be validated."
);

exports.importResidentsBulk = callable(
  importResidentsBulkCore,
  "The resident import could not be completed."
);

exports.approveResidentRegistration = callable(
  approveResidentRegistrationCore,
  "Resident approval could not be completed."
);
exports.rejectResidentRegistration = callable(
  rejectResidentRegistrationCore,
  "Resident rejection could not be completed."
);
exports.deactivateResident = callable(
  deactivateResidentCore,
  "Resident deactivation could not be completed."
);
exports.reactivateResident = callable(
  reactivateResidentCore,
  "Resident reactivation could not be completed."
);
exports.reassignResident = callable(
  reassignResidentCore,
  "Resident reassignment could not be completed."
);
exports.createResidentOnboarding = callable(
  createResidentOnboardingCore,
  "Resident onboarding could not be created."
);

exports.auditResidentAction = callable(
  auditResidentAction,
  "Resident action could not be audited."
);

exports.assignResidentOnboardingToFlat = callable(
  assignResidentOnboardingToFlatCore,
  "Resident onboarding could not be assigned to the unit.",
);
exports.cancelResidentOnboardingReservation = callable(
  cancelResidentOnboardingReservationCore,
  "Resident onboarding reservation could not be cancelled.",
);
const { reconcileBuildingCore, createBuildingCore } = require("./building_reconciliation");
const { deleteBuildingCore, validateBuildingDeletionCore } = require("./building_deletion");
exports.validateBuildingDeletion = appCheckedCallable(validateBuildingDeletionCore, "Unable to check building deletion.");
exports.deleteBuilding = appCheckedCallable(deleteBuildingCore, "Unable to delete building.");
exports.createBuilding = appCheckedCallable(createBuildingCore, "Unable to create building.");
exports.reconcileBuilding = appCheckedCallable(
  reconcileBuildingCore,
  "Unable to update building."
);
exports.renameUnit = appCheckedCallable(
  renameUnitCore,
  "Unable to rename unit."
);

exports.listAssignableResidentOnboardings = callable(
  listAssignableResidentOnboardingsCore,
  "Assignable resident onboardings could not be loaded.",
);
exports.submitResidentIdentityProof = callable(
  submitResidentIdentityProofCore,
  "Identity proof could not be submitted."
);
exports.getResidentIdentityProofUrl = callable(
  getResidentIdentityProofUrlCore,
  "Identity proof could not be opened."
);
exports.reviewResidentIdentityProof = callable(
  reviewResidentIdentityProofCore,
  "Identity proof review could not be completed."
);
exports.moveOutResident = callable(
  moveOutResidentCore,
  "Resident move-out could not be completed."
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
  { region: REGION, secrets: [GOOGLE_GEOCODING_API_KEY] },
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
  { region: REGION, secrets: [GOOGLE_GEOCODING_API_KEY] },
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
  { region: REGION, secrets: [GOOGLE_GEOCODING_API_KEY] },
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
