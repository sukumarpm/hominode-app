const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { getAuth } = require("firebase-admin/auth");
const { getStorage } = require("firebase-admin/storage");
const { getMessaging } = require("firebase-admin/messaging");

const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onDocumentCreated, onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { onObjectFinalized } = require("firebase-functions/v2/storage");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const logger = require("firebase-functions/logger");
const { defineSecret, defineString } = require("firebase-functions/params");
const { hasVerifiedPhoneAuth, hasCanonicalPhoneProfile } = require("./phone_auth");
const { prepareStorageImageUploadCore, completeStorageImageUploadCore, readStorageImageCore } = require("./storage_images");
const {
  saveApartmentImageCore,
  deleteApartmentImageCore,
  cleanupApartmentImagesCore,
} = require("./apartment_images");

const {
  createResidentImageDraftCore,
  commitResidentImagesCore,
  cleanupResidentImagesCore,
  cleanupUnreservedResidentStaging,
} = require("./resident_images");

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
  createProofSubmittedNotification,
  dispatchPaymentV2NotificationCore,
} = require("./payment_v2_notifications");

const {
  getBillingV2FinancialReportCore,
  getBillingV2DetailedReportCore,
} = require("./billing_v2_reports");

const {
  getResidentBillingV2StatementCore,
} = require("./billing_v2_resident_statement");

const {
  getResidentBillingV2ReceiptCore,
} = require("./billing_v2_receipt");

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
  createAdminResidentCore,
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
  submitAccountDeletionRequestCore,
  getAccountDeletionRequestStatusCore,
  listCommunityDeletionRequestsCore,
  recordDeletionFinancialReviewCore,
  reassessAccountDeletionRequestCore,
  reviewAccountDeletionEligibilityForRequestCore,
} = require("./account_deletion_requests");
const { runAccountDeletionRetryCore } = require("./account_deletion_retry");
const { createAdminAssistedDeletionRequestCore, verifyAdminAssistedDeletionRequestCore } = require("./account_deletion_assisted");
const {
  resolveResidentCommunityCore,
} = require("./resident_community_resolution");
const {
  getAmenityAvailabilityCore,
  createAmenityBookingCore,
  cancelAmenityBookingCore,
} = require("./amenity_booking");
const { resolveVisitorQrCore, transitionVisitorFromQrCore } = require("./visitor_gate");
const { createVisitorInvitationCore, getVisitorCredentialsCore } = require("./visitor_credentials");
const { dispatchVisitorDecisionCore } = require("./visitor_notifications");
const { verifyVisitorCredentialCore } = require("./visitor_verification");
const {
  checkoutVisitorsCore,
  denyVisitorEntryCore,
  listSecurityVisitorsCore,
} = require("./security_visitor_workflow");

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
const VISITOR_CREDENTIAL_HMAC_KEY = defineSecret("VISITOR_CREDENTIAL_HMAC_KEY");
// Empty means the SEC-003 legacy compatibility window has not been retired.
// Set only through an explicitly approved deployment configuration.
const VISITOR_LEGACY_CREDENTIAL_CUTOFF_UTC = defineString("VISITOR_LEGACY_CREDENTIAL_CUTOFF_UTC", { default: "DISABLED" });

function requireVisitorCredentialHmacKey() {
  let key;
  try {
    key = VISITOR_CREDENTIAL_HMAC_KEY.value();
  } catch (_) {
    throw new HttpsError("failed-precondition", "Visitor credential service is unavailable.");
  }
  if (typeof key !== "string" || Buffer.byteLength(key, "utf8") < 32) {
    throw new HttpsError("failed-precondition", "Visitor credential service is unavailable.");
  }
  return key;
}

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

const { getOrCreateResidentAdminChatCore, ChatSetupError } = require('./resident_admin_chat');
exports.getOrCreateResidentAdminChat = onCall(
  { region: REGION, enforceAppCheck: true },
  async (request) => {
    try {
      requirePhoneAuth(request.auth);
      const db = getFirestore();
      if (!await hasCanonicalPhoneProfile(db, request.auth)) {
        throw new HttpsError('permission-denied', 'An active resident profile is required.');
      }
      return await getOrCreateResidentAdminChatCore({ db, auth: request.auth });
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      if (error instanceof ChatSetupError) throw new HttpsError(error.code, error.message);
      logger.error('Resident Admin chat setup failed', { message: error?.message });
      throw new HttpsError('internal', 'Could not set up Admin chat.');
    }
  }
);

const moderation = require('./content_moderation');
exports.reportWallContent = appCheckedCallable(moderation.reportContentCore, 'Content report could not be submitted.');
exports.setWallUserBlock = appCheckedCallable(moderation.blockContentUserCore, 'User block could not be updated.');
exports.listWallUserBlocks = appCheckedCallable(moderation.listBlockedContentUsersCore, 'Blocked users could not be loaded.');
exports.listWallModerationReports = appCheckedCallable(moderation.listModerationReportsCore, 'Moderation queue could not be loaded.');
exports.resolveWallModerationReport = appCheckedCallable(moderation.resolveModerationReportCore, 'Moderation decision could not be saved.');
exports.dispatchModerationDecisionNotification = onDocumentCreated({
  region: REGION, document: 'moderationAudit/{auditId}', retry: true,
}, event => require('./moderation_notifications').dispatchModerationDecisionCore({
  db: getFirestore(), messaging: getMessaging(), auditId: event.params.auditId,
}));
exports.readVisibleWall = appCheckedCallable(moderation.readVisibleWallCore, 'Community wall could not be loaded.');

function callableHandler(
  core,
  failureMessage,
  {
    includeAppContext = false,
    includeMessaging = false,
    requirePhoneAuth: requirePhone = false,
    requireCanonicalPhoneProfile = false,
    requireRecentAuth = false,
  } = {}
) {
  return async (request) => {
    try {
      if (requirePhone) requirePhoneAuth(request.auth);
      if (requireRecentAuth) requireRecentAuthTime(request.auth);
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

function requireRecentAuthTime(auth, nowSeconds = Math.floor(Date.now() / 1000)) {
  const authTime = auth?.token?.auth_time;
  if (!auth?.uid || !Number.isInteger(authTime) || authTime <= 0 ||
    authTime > nowSeconds || nowSeconds - authTime > 300) {
    throw new HttpsError("failed-precondition", "Please reauthenticate before submitting this request.");
  }
}

function accountDeletionCallable(core, failureMessage, recentAuth = false, options = {}) {
  return onCall({ region: REGION, enforceAppCheck: true, ...options }, callableHandler(
    core, failureMessage, { includeAppContext: true, requireRecentAuth: recentAuth }
  ));
}

exports.submitAccountDeletionRequest = accountDeletionCallable(
  submitAccountDeletionRequestCore, "Account deletion request could not be submitted.", true,
  { timeoutSeconds: 540 }
);
exports.getAccountDeletionRequestStatus = accountDeletionCallable(
  getAccountDeletionRequestStatusCore, "Account deletion request status could not be loaded."
);
exports.createAdminAssistedDeletionRequest = appCheckedCallable(
  createAdminAssistedDeletionRequestCore, "Assisted deletion intake could not be recorded."
);
exports.verifyAdminAssistedDeletionRequest = appCheckedCallable(
  verifyAdminAssistedDeletionRequestCore, "Assisted deletion verification could not be recorded."
);
exports.listCommunityAccountDeletionRequests = accountDeletionCallable(
  listCommunityDeletionRequestsCore, "Community account-deletion requests could not be loaded."
);
exports.recordAccountDeletionFinancialReview = accountDeletionCallable(
  recordDeletionFinancialReviewCore, "Account-deletion review finding could not be recorded."
);
exports.reassessAccountDeletionRequest = accountDeletionCallable(
  reassessAccountDeletionRequestCore,
  "Account deletion could not be reassessed."
);
exports.reviewAccountDeletionEligibility = accountDeletionCallable(
  reviewAccountDeletionEligibilityForRequestCore,
  "Account deletion eligibility could not be reviewed."
);
exports.retryVerifiedAccountDeletions = onSchedule({
  schedule: "every 4 hours", region: REGION, timeoutSeconds: 540,
  memory: "512MiB", maxInstances: 1, concurrency: 1,
}, () => runAccountDeletionRetryCore({ db: getFirestore(), bucket: getStorage().bucket() }));
exports.prepareStorageImageUpload = appCheckedCallable(
  prepareStorageImageUploadCore, 'Image upload could not be prepared.',
);
// Image verification/read operations buffer at most 10 MiB. Limit concurrency
// independently of the existing financial/SOS callables.
function storageImageCallable(core, failureMessage) {
  return onCall({ region: REGION, enforceAppCheck: true, memory: '512MiB', concurrency: 1 },
    callableHandler(core, failureMessage, {
      includeAppContext: true,
      requirePhoneAuth: true, requireCanonicalPhoneProfile: true
    }));
}
exports.completeStorageImageUpload = storageImageCallable(
  completeStorageImageUploadCore, 'Image upload could not be verified.',
);
exports.readStorageImage = storageImageCallable(
  readStorageImageCore, 'Image could not be read.',
);

exports.saveApartmentImage = storageImageCallable(
  saveApartmentImageCore,
  "Image could not be saved.",
);
exports.deleteApartmentImage = storageImageCallable(
  deleteApartmentImageCore,
  "Image could not be deleted.",
);
exports.cleanupApartmentImages = onSchedule(
  {
    schedule: "every 15 minutes",
    region: REGION,
    timeoutSeconds: 300,
    memory: "512MiB",
    maxInstances: 1,
    concurrency: 1,
  },
  () => cleanupApartmentImagesCore({ db: getFirestore(), bucket: getStorage().bucket() }),
);

exports.createResidentImageDraft = storageImageCallable(
  createResidentImageDraftCore,
  "Image draft could not be prepared.",
);
exports.commitResidentImages = storageImageCallable(
  commitResidentImagesCore,
  "Images could not be saved.",
);
exports.cleanupResidentImages = onSchedule(
  {
    schedule: "every 15 minutes",
    region: REGION,
    timeoutSeconds: 300,
    memory: "512MiB",
    maxInstances: 1,
    concurrency: 1,
  },
  async () => {
    const db = getFirestore();
    const bucket = getStorage().bucket();
    await cleanupResidentImagesCore({ db, bucket });
    await cleanupUnreservedResidentStaging({ db, bucket });
  },
);

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
exports.dispatchBillingV2PaymentNotification = onDocumentCreated({
  region: REGION,
  document: 'billingV2PaymentNotificationEvents/{eventId}',
  // In-app notification and financial event writes are atomic. Push is
  // best-effort; retrying an accepted FCM send can duplicate the push.
  retry: false,
  timeoutSeconds: 120,
}, (event) => dispatchPaymentV2NotificationCore({
  db: getFirestore(), messaging: getMessaging(), event,
  logger: { warn: (message, context) => logger.warn(message, context) },
}));
exports.notifyResidentOfSubmittedV2PaymentProof = onObjectFinalized({
  // Storage triggers must match this bucket's location, even when a selective
  // deployment targets only the asia-southeast1 callable exports.
  region: "us-east1",
  bucket: "hominode-prod.firebasestorage.app",
  // This handler only creates deterministic Firestore records; retrying it is
  // idempotent and ensures receipt finalization eventually reaches the inbox.
  retry: true,
  timeoutSeconds: 120,
}, async (event) => {
  // Firestore notification bookkeeping is independent from proof/settlement
  // writes. Let transient storage-trigger bookkeeping errors escape so the
  // configured retry can complete the deterministic in-app notification.
  await createProofSubmittedNotification({ db: getFirestore(), object: event.data });
});
exports.getBillingV2FinancialReport = appCheckedCallable(
  getBillingV2FinancialReportCore,
  'Billing V2 financial report could not be generated.'
);
exports.getAdminBillingV2DetailedReport = appCheckedCallable(
  getBillingV2DetailedReportCore,
  'Billing V2 detailed report could not be generated.'
);
exports.getResidentBillingV2Statement = appCheckedCallable(
  getResidentBillingV2StatementCore,
  'Resident Billing V2 statement could not be generated.'
);
exports.getResidentBillingV2Receipt = appCheckedCallable(
  getResidentBillingV2ReceiptCore,
  'Billing V2 receipt could not be generated.'
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

function securityVisitorCallable(core, failureMessage, { legacyCutoff = false } = {}) {
  return onCall({ region: REGION, enforceAppCheck: true, secrets: [VISITOR_CREDENTIAL_HMAC_KEY] }, async (request) => {
    try {
      requirePhoneAuth(request.auth);
      return await core({
        db: getFirestore(), auth: request.auth, data: request.data,
        hmacKey: requireVisitorCredentialHmacKey(),
        ...(legacyCutoff ? {
          legacyCredentialCutoffUtc: VISITOR_LEGACY_CREDENTIAL_CUTOFF_UTC.value() === "DISABLED"
            ? null : VISITOR_LEGACY_CREDENTIAL_CUTOFF_UTC.value(),
        } : {}),
      });
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      if (error instanceof RegistrationError) throw new HttpsError(error.code, error.message);
      logger.error(failureMessage, { code: error?.code || "unknown" });
      throw new HttpsError("internal", failureMessage);
    }
  });
}

exports.resolveVisitorQr = securityVisitorCallable(
  resolveVisitorQrCore,
  "This visitor QR could not be verified.",
  { legacyCutoff: true }
);
exports.transitionVisitorFromQr = securityVisitorCallable(
  transitionVisitorFromQrCore,
  "This visitor request could not be processed.",
  { legacyCutoff: true }
);
exports.verifyVisitorCredential = onCall({
  region: REGION,
  enforceAppCheck: true,
  secrets: [VISITOR_CREDENTIAL_HMAC_KEY],
}, async (request) => {
  try {
    requirePhoneAuth(request.auth);
    return await verifyVisitorCredentialCore({
      db: getFirestore(), auth: request.auth, data: request.data,
      hmacKey: requireVisitorCredentialHmacKey(),
    });
  } catch (error) {
    if (error instanceof HttpsError) throw error;
    if (error instanceof RegistrationError) throw new HttpsError(error.code, error.message);
    // Do not log request data, credential values, HMAC indexes, or exception messages.
    logger.error("Visitor credential verification failed.", { code: error?.code || "unknown" });
    throw new HttpsError("internal", "Visitor credential could not be verified.");
  }
});
function securityWorkflowCallable(core, failureMessage) {
  return onCall({ region: REGION, enforceAppCheck: true }, async (request) => {
    try {
      requirePhoneAuth(request.auth);
      return await core({ db: getFirestore(), auth: request.auth, data: request.data });
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      if (error instanceof RegistrationError) throw new HttpsError(error.code, error.message);
      logger.error(failureMessage, { code: error?.code || "unknown" });
      throw new HttpsError("internal", failureMessage);
    }
  });
}
exports.listSecurityVisitors = securityWorkflowCallable(
  listSecurityVisitorsCore,
  "Security visitor records could not be loaded."
);
exports.denyVisitorEntry = securityWorkflowCallable(
  denyVisitorEntryCore,
  "Visitor entry could not be denied."
);
exports.checkoutVisitors = securityWorkflowCallable(
  checkoutVisitorsCore,
  "Visitor checkout could not be confirmed."
);
exports.dispatchVisitorDecisionNotification = onDocumentUpdated({
  region: REGION,
  document: "visitors/{visitorId}",
  // Delivery retries are bounded inside the handler. Replaying this event can
  // resend a push accepted by FCM before the Firestore delivery marker updates.
  retry: false,
  timeoutSeconds: 120,
}, (event) => dispatchVisitorDecisionCore({
  db: getFirestore(), messaging: getMessaging(), event,
}));

function residentVisitorCallable(core, failureMessage) {
  return onCall({
    region: REGION,
    enforceAppCheck: true,
    secrets: [VISITOR_CREDENTIAL_HMAC_KEY],
  }, async (request) => {
    try {
      requirePhoneAuth(request.auth);
      return await core({
        db: getFirestore(), auth: request.auth, data: request.data,
        hmacKey: requireVisitorCredentialHmacKey(),
      });
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      if (error instanceof RegistrationError) throw new HttpsError(error.code, error.message);
      logger.error(failureMessage, { code: error?.code || "unknown" });
      throw new HttpsError("internal", failureMessage);
    }
  });
}

exports.createVisitorInvitation = residentVisitorCallable(
  createVisitorInvitationCore,
  "The visitor invitation could not be created."
);
exports.getVisitorCredentials = residentVisitorCallable(
  getVisitorCredentialsCore,
  "The visitor credentials are unavailable."
);

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

// Inbox only; existing Admin notification requests retain push delivery.
exports.recordResidentBillNotification = onDocumentCreated({
  region: REGION, document: "bills/{billId}", retry: true,
}, event => require("./bill_notifications").recordCreatedBillNotificationCore({
  db: getFirestore(), billId: event.params.billId,
}));

// Creation only: no update trigger and no historical backfill on deployment.
exports.notifyResidentsOfCreatedEvent = onDocumentCreated({
  region: REGION,
  document: "events_announcements/{eventId}",
  timeoutSeconds: 540,
  memory: "512MiB",
  retry: true,
}, (event) => require("./event_notifications").notifyCreatedEventCore({
  db: getFirestore(), messaging: getMessaging(), eventId: event.params.eventId,
}));

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
}, async () => runRecurringBillingV2SchedulerCore({ db: getFirestore(), logger }));
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
exports.createAdminResident = appCheckedCallable(
  (context) => createAdminResidentCore({ ...context, authAdmin: getAuth() }),
  "Resident could not be added."
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


// PUBLIC ACCOUNT DELETION REQUEST FORM (does not delete resident accounts)
const { onRequest: deletionOnRequest } = require("firebase-functions/v2/https");
const { FieldValue: DeletionFieldValue } = require("firebase-admin/firestore");
const { handleDeletionRequest, ALLOWED_ORIGINS } = require("./public_deletion_requests");
const DELETION_TURNSTILE_SECRET = defineSecret("HOMINODE_DELETION_TURNSTILE_SECRET");
const DELETION_SMTP_PASSWORD = defineSecret("HOMINODE_DELETION_SMTP_APP_PASSWORD");
exports.submitPublicAccountDeletionRequest = deletionOnRequest(
  {
    region: "asia-southeast1",
    cors: [...ALLOWED_ORIGINS],
    secrets: [DELETION_TURNSTILE_SECRET, DELETION_SMTP_PASSWORD],
    maxInstances: 3,
    timeoutSeconds: 35,
    memory: "256MiB",
  },
  (req, res) => handleDeletionRequest(req, res, {
    db: getFirestore(),
    timestamp: () => DeletionFieldValue.serverTimestamp(),
    captchaSecret: DELETION_TURNSTILE_SECRET.value(),
    smtpPassword: DELETION_SMTP_PASSWORD.value(),
    sendMail: async (message, password) => {
      const nodemailer = require("nodemailer");
      const transport = nodemailer.createTransport({
        service: "gmail",
        auth: { user: "hominodecare@gmail.com", pass: password },
      });
      const result = await transport.sendMail(message);
      if (!result.accepted?.some(x => x.toLowerCase() === "hominodecare@gmail.com")) {
        throw new Error("SMTP recipient not accepted");
      }
    },
  })
);

// PUBLIC HOMINODE CLIENT INQUIRIES (independent of deletion requests)
const { onRequest: inquiryOnRequest } = require("firebase-functions/v2/https");
const { FieldValue: InquiryFieldValue } = require("firebase-admin/firestore");
const { handleInquiry, ALLOWED_ORIGINS: INQUIRY_ORIGINS } = require("./public_contact_inquiries");
exports.submitPublicContactInquiry = inquiryOnRequest(
  {
    region: "asia-southeast1",
    cors: [...INQUIRY_ORIGINS],
    secrets: [DELETION_TURNSTILE_SECRET, DELETION_SMTP_PASSWORD],
    maxInstances: 3,
    timeoutSeconds: 35,
    memory: "256MiB",
  },
  (req, res) => handleInquiry(req, res, {
    db: getFirestore(),
    timestamp: () => InquiryFieldValue.serverTimestamp(),
    captchaSecret: DELETION_TURNSTILE_SECRET.value(),
    smtpPassword: DELETION_SMTP_PASSWORD.value(),
    sendMail: async (message, password) => {
      const nodemailer = require("nodemailer");
      const transport = nodemailer.createTransport({
        service: "gmail",
        auth: { user: "hominodecare@gmail.com", pass: password },
      });
      const result = await transport.sendMail(message);
      if (!result.accepted?.some(x => x.toLowerCase() === "hominodecare@gmail.com")) {
        throw new Error("Support mailbox did not accept inquiry");
      }
    },
  })
);
