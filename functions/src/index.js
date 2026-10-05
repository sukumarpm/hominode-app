const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { getAuth } = require("firebase-admin/auth");
const { getStorage } = require("firebase-admin/storage");
const { getMessaging } = require("firebase-admin/messaging");

const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const logger = require("firebase-functions/logger");
const { defineSecret } = require("firebase-functions/params");
const { hasVerifiedPhoneAuth, hasCanonicalPhoneProfile } = require("./phone_auth");

const {
  RegistrationError,
  registerResidentCore,
} = require("./register_resident");

const {
  createMaintenanceBillsCore,
} = require("./billing_management");

const { createMonthlyBillingBatchV2Core } = require("./billing_batch");
const { resolveBillingReconciliationV2Core } = require("./billing_reconciliation");
const { runRecurringBillingV2SchedulerCore } = require("./billing_recurring_scheduler");
const { reviseMonthlyBillingBatchV2Core } = require("./billing_revision");
const {
  createBillingScheduleV2Core,
  reviseBillingScheduleV2Core,
  reserveBillingSchedulePeriodV2Core,
  executeBillingSchedulePeriodV2Core,
  pauseBillingScheduleV2Core,
  resumeBillingScheduleV2Core,
  stopBillingScheduleV2Core,
} = require("./billing_schedule");

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
  recordManualPaymentCore,
} = require("./payment_verification");

const {
  preparePaymentProofV2Core,
  verifyPaymentProofV2Core,
  rejectPaymentProofV2Core,
  recordOfflinePaymentV2Core,
} = require("./payment_v2");

const {
  getBillingV2FinancialReportCore,
} = require("./billing_v2_reports");

const {
  getResidentBillingV2StatementCore,
} = require("./billing_v2_resident_statement");

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
const { updateCommunityPaymentConfigCore } = require("./community_payment_config");
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
  APP_CONTEXTS,
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

const {
  seedSubscriptionPlansCore,
  getCommunitySubscriptionCore,
  getCurrentCommunityEntitlementCore,
  createCommunitySubscriptionCore,
  changeCommunitySubscriptionPlanCore,
  extendCommunitySubscriptionCore,
  setCommunitySubscriptionStatusCore,
} = require("./subscription_management");


const REGION = "asia-southeast1";
const GOOGLE_GEOCODING_API_KEY = defineSecret("GOOGLE_GEOCODING_API_KEY");

function requireAdminAppContext(app) {
  const context = APP_CONTEXTS[app?.appId];
  if (!context || context.role !== "admin" || context.appId !== "admin") {
    throw new HttpsError("failed-precondition", "This app cannot perform this operation.");
  }
  return context;
}

function requirePhoneAuth(auth) {
  if (!hasVerifiedPhoneAuth(auth)) {
    throw new HttpsError("unauthenticated", "Verified phone authentication is required.");
  }
  return auth.uid;
}

function appCheckedCallable(
  core,
  failureMessage,
  {
    includeMessaging = false,
    allowUnauthenticated = false,
    allowProfilelessPhoneAuth = false,
  } = {}
) {
  return onCall(
    { region: REGION, enforceAppCheck: true },
    callableHandler(core, failureMessage, {
      includeAppContext: true,
      includeMessaging,
      requirePhoneAuth: !allowUnauthenticated,
      requireCanonicalPhoneProfile: !allowUnauthenticated && !allowProfilelessPhoneAuth,
    })
  );
}

function callableHandler(
  core,
  failureMessage,
  {
    includeAppContext = false,
    includeMessaging = false,
    requirePhoneAuth: requirePhone = false,
    requireCanonicalPhoneProfile = false,
  } = {}
) {
  return async (request) => {
    try {
      if (requirePhone) requirePhoneAuth(request.auth);
      const db = getFirestore();
      if (requireCanonicalPhoneProfile &&
        !await hasCanonicalPhoneProfile(db, request.auth)) {
        throw new HttpsError("permission-denied", "A matching active Hominode profile is required.");
      }
      const context = {
        db,
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
      if (error instanceof HttpsError) throw error;
      if (error instanceof RegistrationError) {
        throw new HttpsError(error.code, error.message);
      }

      console.error(failureMessage);

      throw new HttpsError(
        "internal",
        failureMessage
      );
    }
  };
}
exports.recordManualPayment = appCheckedCallable(
  recordManualPaymentCore,
  'Manual payment could not be recorded.'
);

exports.verifyPaymentProof = appCheckedCallable(
  verifyPaymentProofCore,
  "Payment proof could not be verified."
);

exports.preparePaymentProofV2 = appCheckedCallable(preparePaymentProofV2Core, 'V2 payment proof could not be prepared.');
exports.verifyPaymentProofV2 = appCheckedCallable(verifyPaymentProofV2Core, 'V2 payment proof could not be verified.');
exports.rejectPaymentProofV2 = appCheckedCallable(rejectPaymentProofV2Core, 'V2 payment proof could not be rejected.');
exports.recordOfflinePaymentV2 = appCheckedCallable(recordOfflinePaymentV2Core, 'V2 offline payment could not be recorded.');
exports.getBillingV2FinancialReport = appCheckedCallable(
  getBillingV2FinancialReportCore,
  'Billing V2 financial report could not be generated.'
);
exports.getResidentBillingV2Statement = appCheckedCallable(
  getResidentBillingV2StatementCore,
  'Resident Billing V2 statement could not be generated.'
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
exports.assignSecurityWork = appCheckedCallable(
  assignSecurityWorkCore,
  "Security work could not be assigned."
);

exports.deleteSecurityPlace = appCheckedCallable(
  deleteSecurityPlaceCore,
  "Security place could not be removed."
);
exports.removeSecurityAssignment = appCheckedCallable(
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
  "Community hostname could not be resolved.",
  { allowUnauthenticated: true }
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

exports.refreshPublicPlatformStats = appCheckedCallable(
  refreshPublicPlatformStatsCore,
  "Public platform statistics could not be refreshed."
);

exports.seedSubscriptionPlans = appCheckedCallable(
  seedSubscriptionPlansCore,
  "Subscription plans could not be seeded."
);

exports.getCommunitySubscription = appCheckedCallable(
  getCommunitySubscriptionCore,
  "Community subscription could not be loaded."
);

exports.getCurrentCommunityEntitlement = appCheckedCallable(
  getCurrentCommunityEntitlementCore,
  "Community entitlement could not be loaded."
);

exports.createCommunitySubscription = appCheckedCallable(
  createCommunitySubscriptionCore,
  "Community subscription could not be created."
);

exports.changeCommunitySubscriptionPlan = appCheckedCallable(
  changeCommunitySubscriptionPlanCore,
  "Community subscription plan could not be changed."
);

exports.extendCommunitySubscription = appCheckedCallable(
  extendCommunitySubscriptionCore,
  "Community subscription could not be extended."
);

exports.setCommunitySubscriptionStatus = appCheckedCallable(
  setCommunitySubscriptionStatusCore,
  "Community subscription status could not be changed."
);

exports.createMaintenanceBills = appCheckedCallable(
  createMaintenanceBillsCore,
  "Maintenance bills could not be created.",
);
exports.createMonthlyBillingBatchV2 = appCheckedCallable(
  createMonthlyBillingBatchV2Core,
  "Monthly billing batch could not be generated.",
);
exports.resolveBillingReconciliationV2 = appCheckedCallable(
  resolveBillingReconciliationV2Core,
  "Billing reconciliation could not be resolved.",
);
exports.reviseMonthlyBillingBatchV2 = appCheckedCallable(
  reviseMonthlyBillingBatchV2Core,
  "Monthly billing batch could not be revised.",
);
exports.createBillingScheduleV2 = appCheckedCallable(
  createBillingScheduleV2Core,
  "Billing schedule could not be created.",
);
exports.reviseBillingScheduleV2 = appCheckedCallable(
  reviseBillingScheduleV2Core,
  "Billing schedule could not be revised.",
);
exports.reserveBillingSchedulePeriodV2 = appCheckedCallable(
  reserveBillingSchedulePeriodV2Core,
  "Billing schedule period could not be reserved.",
);
exports.executeBillingSchedulePeriodV2 = appCheckedCallable(
  executeBillingSchedulePeriodV2Core,
  "Billing schedule period could not be executed.",
);
exports.pauseBillingScheduleV2 = appCheckedCallable(
  pauseBillingScheduleV2Core,
  "Billing schedule could not be paused.",
);
exports.resumeBillingScheduleV2 = appCheckedCallable(
  resumeBillingScheduleV2Core,
  "Billing schedule could not be resumed.",
);
exports.stopBillingScheduleV2 = appCheckedCallable(
  stopBillingScheduleV2Core,
  "Billing schedule could not be stopped.",
);
exports.runRecurringBillingV2Scheduler = onSchedule({
  schedule: "every 60 minutes",
  timeZone: "Etc/UTC",
  maxInstances: 1,
  concurrency: 1,
  timeoutSeconds: 540,
}, async () => runRecurringBillingV2SchedulerCore({db: getFirestore(), logger}));
initializeApp();

/*
 * Resident registration
 */
exports.registerResident = appCheckedCallable(
  registerResidentCore,
  "Registration could not be completed.",
  { allowProfilelessPhoneAuth: true }
);

exports.validateResidentBulkImport = appCheckedCallable(
  validateResidentBulkImportCore,
  "The resident import could not be validated."
);

exports.importResidentsBulk = appCheckedCallable(
  importResidentsBulkCore,
  "The resident import could not be completed."
);

exports.approveResidentRegistration = appCheckedCallable(
  approveResidentRegistrationCore,
  "Resident approval could not be completed."
);
exports.rejectResidentRegistration = appCheckedCallable(
  rejectResidentRegistrationCore,
  "Resident rejection could not be completed."
);
exports.deactivateResident = appCheckedCallable(
  deactivateResidentCore,
  "Resident deactivation could not be completed."
);
exports.reactivateResident = appCheckedCallable(
  reactivateResidentCore,
  "Resident reactivation could not be completed."
);
exports.reassignResident = appCheckedCallable(
  reassignResidentCore,
  "Resident reassignment could not be completed."
);
exports.createResidentOnboarding = appCheckedCallable(
  createResidentOnboardingCore,
  "Resident onboarding could not be created."
);

exports.auditResidentAction = appCheckedCallable(
  auditResidentAction,
  "Resident action could not be audited."
);

exports.assignResidentOnboardingToFlat = appCheckedCallable(
  assignResidentOnboardingToFlatCore,
  "Resident onboarding could not be assigned to the unit.",
);
exports.cancelResidentOnboardingReservation = appCheckedCallable(
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

exports.listAssignableResidentOnboardings = appCheckedCallable(
  listAssignableResidentOnboardingsCore,
  "Assignable resident onboardings could not be loaded.",
);
exports.submitResidentIdentityProof = appCheckedCallable(
  submitResidentIdentityProofCore,
  "Identity proof could not be submitted."
);
exports.getResidentIdentityProofUrl = appCheckedCallable(
  getResidentIdentityProofUrlCore,
  "Identity proof could not be opened."
);
exports.reviewResidentIdentityProof = appCheckedCallable(
  reviewResidentIdentityProofCore,
  "Identity proof review could not be completed."
);
exports.moveOutResident = appCheckedCallable(
  moveOutResidentCore,
  "Resident move-out could not be completed."
);

/*
 * Community management
 */
exports.createCommunity = appCheckedCallable(
  createCommunityCore,
  "Community could not be created."
);

exports.updateCommunity = appCheckedCallable(
  updateCommunityCore,
  "Community could not be updated."
);

exports.setCommunityActive = appCheckedCallable(
  setCommunityActiveCore,
  "Community status could not be updated."
);

exports.searchCommunityLocations = onCall(
  { region: REGION, secrets: [GOOGLE_GEOCODING_API_KEY], enforceAppCheck: true },
  async (request) => {
    const appContext = requireAdminAppContext(request.app);
    try {
      requirePhoneAuth(request.auth);
      const db = getFirestore();
      if (!await hasCanonicalPhoneProfile(db, request.auth)) {
        throw new HttpsError("permission-denied", "A matching Hominode profile is required.");
      }
      return await communityLocationSearchCore({
        db,
        auth: request.auth,
        data: request.data,
        app: request.app,
        appContext,
        apiKey: GOOGLE_GEOCODING_API_KEY.value(),
      });
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      if (error instanceof RegistrationError) {
        throw new HttpsError(error.code, error.message);
      }
      console.error("Community location search failed.");
      throw new HttpsError("internal", "Location search is temporarily unavailable.");
    }
  },
);

exports.resolveCommunityLocationPlace = onCall(
  { region: REGION, secrets: [GOOGLE_GEOCODING_API_KEY], enforceAppCheck: true },
  async (request) => {
    const appContext = requireAdminAppContext(request.app);
    try {
      requirePhoneAuth(request.auth);
      const db = getFirestore();
      if (!await hasCanonicalPhoneProfile(db, request.auth)) {
        throw new HttpsError("permission-denied", "A matching Hominode profile is required.");
      }
      return await resolveCommunityLocationPlaceCore({
        db,
        auth: request.auth,
        data: request.data,
        app: request.app,
        appContext,
        apiKey: GOOGLE_GEOCODING_API_KEY.value(),
      });
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      if (error instanceof RegistrationError) {
        throw new HttpsError(error.code, error.message);
      }
      console.error("Community place resolution failed.");
      throw new HttpsError("internal", "The selected place could not be loaded.");
    }
  },
);

exports.reverseGeocodeCommunityLocation = onCall(
  { region: REGION, secrets: [GOOGLE_GEOCODING_API_KEY], enforceAppCheck: true },
  async (request) => {
    const appContext = requireAdminAppContext(request.app);
    try {
      requirePhoneAuth(request.auth);
      const db = getFirestore();
      if (!await hasCanonicalPhoneProfile(db, request.auth)) {
        throw new HttpsError("permission-denied", "A matching Hominode profile is required.");
      }
      return await reverseGeocodeCommunityLocationCore({
        db,
        auth: request.auth,
        data: request.data,
        app: request.app,
        appContext,
        apiKey: GOOGLE_GEOCODING_API_KEY.value(),
      });
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      if (error instanceof RegistrationError) {
        throw new HttpsError(error.code, error.message);
      }
      console.error("Community reverse geocoding failed.");
      throw new HttpsError(
        "internal",
        "The address could not be determined. Enter the property address manually.",
      );
    }
  },
);

exports.updateCommunityLocation = appCheckedCallable(
  updateCommunityLocationCore,
  "Community location could not be updated."
);
exports.updateCommunityPaymentConfig = appCheckedCallable(
  updateCommunityPaymentConfigCore,
  "Community payment configuration could not be updated."
);

/*
 * Admin management
 */
exports.createAdmin = appCheckedCallable(
  (args) =>
    createAdminCore({
      ...args,
      authAdmin: getAuth(),
    }),
  "Admin could not be created."
);

exports.updateAdminAssignments = appCheckedCallable(
  updateAdminAssignmentsCore,
  "Admin assignments could not be updated."
);

exports.setAdminActive = appCheckedCallable(
  setAdminActiveCore,
  "Admin status could not be updated."
);

/*
 * Security staff management
 */
exports.createSecurityStaff = appCheckedCallable(
  (args) =>
    createSecurityStaffCore({
      ...args,
      authAdmin: getAuth(),
    }),
  "Security staff could not be created."
);

exports.securityCheckIn = appCheckedCallable(
  securityCheckInCore,
  "Security check-in could not be completed."
);

exports.securityCheckOut = appCheckedCallable(
  securityCheckOutCore,
  "Security check-out could not be completed."
);

/*
 * Community invite management
 */
exports.listCommunityInvites = appCheckedCallable(
  listCommunityInvitesCore,
  "Invites could not be loaded."
);

exports.createCommunityInvite = appCheckedCallable(
  createCommunityInviteCore,
  "Invite could not be created."
);

exports.revokeCommunityInvite = appCheckedCallable(
  revokeCommunityInviteCore,
  "Invite could not be revoked."
);
