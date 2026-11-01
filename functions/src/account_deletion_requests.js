const { FieldValue } = require("firebase-admin/firestore");
const { getAuth } = require("firebase-admin/auth");
const { HttpsError } = require("firebase-functions/v2/https");
const { requireOperationalAdmin } = require("./resident_identity");
const { createHash } = require("node:crypto");
const { initialRetry, attemptAccountDeletionRequestCore, retryableError, retryableResult } = require("./account_deletion_retry");
const billingLedger = require("./billing_v2_ledger");
const { monthlyBillIdV2 } = require("./billing_batch");
const { APP_CONTEXTS, notificationDeviceId, notificationAudienceKey } = require("./notifications");
const { occupancyStats } = require("./unit_schema");
const { collectResidentAsset } = require("./resident_images");
const { ASSISTED_SOURCE, isAssistedIntake, hasResidentDeletionVerification, residentDeletionSourceAllowed } = require("./account_deletion_verification");

const COLLECTION = "accountDeletionRequests";
const RECENT_AUTH_SECONDS = 5 * 60;
const DELETION_ACTOR = "system:account-deletion";

function visitorTimestampMillis(value) {
  if (value && typeof value.toMillis === "function") return value.toMillis();
  if (value && typeof value.toDate === "function") return value.toDate().getTime();
  if (value instanceof Date) return value.getTime();
  return Number.isFinite(value) ? value : null;
}

function classifyVisitorForDeletion(visitor, nowMs) {
  if (typeof visitor?.communityId !== "string" || !visitor.communityId.trim()) return "ambiguous";
  const status = String(visitor?.status ?? "").trim().toLowerCase();
  const arrival = visitorTimestampMillis(visitor?.actualArrival);
  const departure = visitorTimestampMillis(visitor?.departure);
  const expected = visitorTimestampMillis(visitor?.expectedArrival ?? visitor?.expectedTime);
  const completedAliases = ["completed", "departed", "checked_out", "checked-out", "exited"];
  if (completedAliases.includes(status)) return arrival != null && departure != null && typeof visitor?.checkedOutBy === "string" && visitor.checkedOutBy
    ? "verified_completed_history" : "ambiguous";
  if (arrival != null) return departure == null ? "checked_in" : "ambiguous";
  if (["inside", "arrived", "checked_in", "entered"].includes(status)) return "ambiguous";
  if (visitor?.gateAccessStatus === "denied" || visitor?.gateEntryDeniedAt != null) return "entry_denied_history";
  if (["rejected", "cancelled", "canceled"].includes(status)) return "terminal_history";
  if (["expected", "pending"].includes(status) && visitor?.isApproved === false && arrival == null && departure == null && expected != null && expected > nowMs) return "future_expected";
  if (status === "approved" && visitor?.isApproved === true && arrival == null && departure == null && expected != null && expected > nowMs) return "future_approved";
  return "ambiguous";
}

function validateRecentAuth(auth, nowSeconds = Math.floor(Date.now() / 1000)) {
  if (!auth?.uid) throw new HttpsError("unauthenticated", "Authentication is required.");
  const time = auth.token?.auth_time;
  if (!Number.isInteger(time) || time <= 0 || time > nowSeconds || nowSeconds - time > RECENT_AUTH_SECONDS) {
    throw new HttpsError("failed-precondition", "Please reauthenticate before submitting this request.");
  }
}

// Read-only assessment of the two supported bill shapes. V2 bills persist a
// minor-unit projection and a deterministic per-community account; V1 bills
// from billing_management persist rupee `amount` and pending/paid status.
// Anything outside those contracts is UNKNOWN and must block eligibility.
async function assessResidentBillingObligations({ db, uid, communityIds, unresolved, verifiedChecks, verifiedAbsence, read = (ref) => ref.get() }) {
  const billsById = new Map();
  for (const field of ["residentId", "userId"]) {
    try {
      const result = await read(db.collection("bills").where(field, "==", uid));
      for (const doc of result.docs) billsById.set(doc.id, { id: doc.id, ...doc.data() });
    } catch (_) {
      unresolved.push({ check: `query:bills.${field}`, reason: `Could not query bills.${field}; financial obligations remain unknown.` });
    }
  }
  const bills = [...billsById.values()];
  if (!unresolved.some((item) => item.check.startsWith("query:bills."))) {
    verifiedChecks.push("bills residentId/userId references across all communities");
  }

  const accountRows = new Map();
  try {
    const result = await read(db.collection("residentFinancialAccounts").where("residentId", "==", uid));
    for (const doc of result.docs) accountRows.set(doc.id, { id: doc.id, ...doc.data() });
  } catch (_) {
    unresolved.push({ check: "query:residentFinancialAccounts.residentId", reason: "Could not query resident financial accounts; financial obligations remain unknown." });
  }
  const accountQueryOk = !unresolved.some((item) => item.check === "query:residentFinancialAccounts.residentId");
  if (accountQueryOk) verifiedChecks.push("residentFinancialAccounts residentId references across all communities");

  // Resolve deterministic V2 accounts for the canonical profile community and
  // every community discovered through a bill/account reference.
  for (const communityId of communityIds) {
    try {
      const accountId = billingLedger.residentFinancialAccountId({ communityId, residentId: uid });
      const snapshot = await read(db.collection("residentFinancialAccounts").doc(accountId));
      if (snapshot.exists) accountRows.set(accountId, { id: accountId, ...snapshot.data() });
    } catch (_) {
      unresolved.push({ check: `account:${communityId}`, reason: "Deterministic financial account could not be verified." });
    }
  }

  const obligations = [];
  const ambiguous = [];
  for (const bill of bills) {
    const validBase = typeof bill.id === "string" && bill.id.length > 0 &&
      bill.residentId === uid && typeof bill.communityId === "string" && !!bill.communityId;
    if (!validBase || (bill.userId != null && bill.userId !== uid)) {
      ambiguous.push({ id: bill.id, reason: "Bill identity or community scope is incomplete or conflicting." });
      continue;
    }
    communityIds.add(bill.communityId);
    if (bill.schemaVersion === 2) {
      let deterministicIdMatches = false;
      try { deterministicIdMatches = bill.id === monthlyBillIdV2(bill.communityId, bill.flatId, bill.billingPeriod); } catch (_) { /* unknown schema */ }
      const validV2 = bill.currency === "INR" && bill.billingKind === "recurring" &&
        typeof bill.billingPeriod === "string" && /^\d{4}-(0[1-9]|1[0-2])$/.test(bill.billingPeriod) &&
        typeof bill.flatId === "string" && !!bill.flatId && typeof bill.buildingId === "string" && !!bill.buildingId &&
        typeof bill.billingBatchId === "string" && !!bill.billingBatchId && deterministicIdMatches &&
        typeof bill.currentRevisionId === "string" && !!bill.currentRevisionId &&
        typeof bill.appliedBatchRevisionId === "string" && !!bill.appliedBatchRevisionId &&
        Number.isSafeInteger(bill.revisionNo) && bill.revisionNo > 0 &&
        bill.dueDate && typeof bill.dueDate.toMillis === "function" &&
        bill.createdAt && typeof bill.createdAt.toMillis === "function" &&
        typeof bill.dueDateKey === "string" && /^\d{4}-\d{2}-\d{2}$/.test(bill.dueDateKey) &&
        typeof bill.timeZone === "string" && !!bill.timeZone &&
        Number.isSafeInteger(bill.amountMinor) && bill.amountMinor >= 0 &&
        Number.isSafeInteger(bill.paidAmountMinor) && bill.paidAmountMinor >= 0 &&
        Number.isSafeInteger(bill.creditAppliedMinor) && bill.creditAppliedMinor >= 0 &&
        Number.isSafeInteger(bill.outstandingAmountMinor) && bill.outstandingAmountMinor >= 0 &&
        Number.isSafeInteger(bill.paidAmountMinor + bill.creditAppliedMinor + bill.outstandingAmountMinor) &&
        bill.paidAmountMinor + bill.creditAppliedMinor + bill.outstandingAmountMinor === bill.amountMinor &&
        ["pending", "partially_paid", "paid", "overdue"].includes(bill.status);
      if (!validV2 || (bill.outstandingAmountMinor === 0) !== (bill.status === "paid")) {
        ambiguous.push({ id: bill.id, communityId: bill.communityId, reason: "V2 bill fields, stored projection, or status do not satisfy the supported schema." });
      } else if (bill.outstandingAmountMinor > 0) {
        obligations.push({ id: bill.id, communityId: bill.communityId, billingPeriod: bill.billingPeriod, outstandingMinor: bill.outstandingAmountMinor, status: bill.status });
      }
      continue;
    }
    // V1 billing_management writes bills without schemaVersion, with INR `amount`
    // represented in major units and `pending`/`paid` status.
    const legacyPeriod = (typeof bill.billingPeriod === "string" && /^\d{4}-(0[1-9]|1[0-2])$/.test(bill.billingPeriod)) ||
      (Number.isInteger(bill.month) && bill.month >= 1 && bill.month <= 12 && Number.isInteger(bill.year));
    const validLegacyAmount = Number.isFinite(bill.amount) && bill.amount > 0 && bill.amount <= 100000000 &&
      Math.round(bill.amount * 100) === bill.amount * 100;
    if (bill.schemaVersion == null && bill.status === "pending" && legacyPeriod && validLegacyAmount) {
      obligations.push({ id: bill.id, communityId: bill.communityId, amount: bill.amount, status: "pending" });
    } else if (bill.schemaVersion == null && bill.status === "paid" && legacyPeriod && validLegacyAmount && bill.paidAt != null) {
      // A settled V1 bill is clear only when the writer's settlement timestamp exists.
    } else {
      ambiguous.push({ id: bill.id, communityId: bill.communityId, reason: "Legacy bill is missing a supported period, amount, status, or settlement marker." });
    }
  }

  for (const [accountDocId, account] of accountRows) {
    if (account.schemaVersion !== 2 || account.id !== accountDocId || account.residentId !== uid ||
        typeof account.communityId !== "string" || !account.communityId || account.currency !== "INR" ||
        !Number.isSafeInteger(account.version) || account.version < 0 ||
        !Number.isSafeInteger(account.availableCreditMinor) || account.availableCreditMinor < 0 ||
        !Number.isSafeInteger(account.createdAt) || account.createdAt < 0 ||
        !Number.isSafeInteger(account.updatedAt) || account.updatedAt < account.createdAt) {
      ambiguous.push({ id: account.id, communityId: account.communityId ?? null, reason: "Resident financial account does not satisfy its V2 schema." });
    }
    if (typeof account.communityId === "string") communityIds.add(account.communityId);
  }
  if (!bills.length && !ambiguous.length && !obligations.length && !unresolved.some((item) => item.check.startsWith("query:bills."))) {
    verifiedAbsence.push({ type: "billing_obligations", scope: "bills residentId/userId across all communities", result: "no matching bills" });
  }
  if (obligations.length) unresolved.push({ check: "outstandingBillingObligations", reason: "One or more supported bills have a positive outstanding amount." });
  if (ambiguous.length) unresolved.push({ check: "billingEvidenceAmbiguous", reason: "One or more bill or resident financial account records are incomplete, inconsistent, or unsupported." });
  return { bills: bills.length, accounts: accountRows.size, obligations, ambiguous,
    verifiedZero: !obligations.length && !ambiguous.length && accountQueryOk &&
      !unresolved.some((item) => item.check.startsWith("query:bills.") || item.check.startsWith("account:")) };
}

const MAX_REFERENCE_SCAN = 501;

function deletionDeviceMatches(device, id, uid, communityId) {
  const app = APP_CONTEXTS[device?.firebaseAppId];
  return typeof communityId === "string" && !!communityId && device?.uid === uid && device.communityId === communityId &&
    device.role === "resident" && device.appId === "resident" && app?.role === "resident" &&
    app.appId === device.appId && app.platform === device.platform && typeof device.active === "boolean" &&
    typeof device.installationId === "string" && /^[A-Za-z0-9_-]{16,128}$/.test(device.installationId) &&
    id === notificationDeviceId(device.appId, uid, device.installationId) &&
    device.audienceKey === notificationAudienceKey({ appId: device.appId, role: device.role, communityId, uid }) &&
    typeof device.token === "string" && device.token.length >= 20 && device.token.length <= 4096 && !/\s/.test(device.token);
}

function deletionDeviceFingerprint(device) {
  return createHash("sha256").update(JSON.stringify([
    device.uid, device.communityId, device.role, device.appId, device.firebaseAppId, device.platform,
    device.installationId, device.audienceKey, device.token, device.active, visitorTimestampMillis(device.updatedAt),
  ])).digest("hex");
}

async function assessAdditionalResidentReferences({ db, bucket, uid, requestId, communityIds, profiles, unresolved, verifiedChecks, verifiedAbsence, preserved }) {
  const classes = {};
  const retryableChecks = new Set();
  async function discover(name, queries) {
    let failed = false;
    let capped = false;
    const found = new Map();
    for (const [collection, field, operator = "=="] of queries) {
      const key = `${collection}.${field}.${operator}`;
      try {
        const query = collection === "<group>" ? db.collectionGroup(name).where(field, operator, uid) : db.collection(collection).where(field, operator, uid);
        const snapshot = await query.limit(MAX_REFERENCE_SCAN).get();
        if (snapshot.docs.length >= MAX_REFERENCE_SCAN) capped = true;
        for (const doc of snapshot.docs) found.set(doc.ref?.path ?? `${collection}/${doc.id}`, { collection, id: doc.id, field, data: doc.data(), ref: doc.ref });
      } catch (_) { failed = true; }
    }
    return { docs: [...found.values()], failed, capped };
  }
  function recordClass(name, result, { checkCommunity = true, description, preserveMatching = false }) {
    let status = result.failed || result.capped ? "UNKNOWN_OR_UNSUPPORTED" : result.docs.length ? "MATCHING_REFERENCE" : "VERIFIED_ABSENT";
    const badCommunity = checkCommunity && result.docs.some(({ data }) => typeof data.communityId !== "string" || !data.communityId);
    if (badCommunity) status = "UNKNOWN_OR_UNSUPPORTED";
    classes[name] = { status, count: result.docs.length, communities: [...new Set(result.docs.map(({ data }) => data.communityId).filter((id) => typeof id === "string"))] };
    if (result.failed && !result.capped && !badCommunity) retryableChecks.add(`reference:${name}`);
    if (status === "VERIFIED_ABSENT") verifiedAbsence.push({ type: name, scope: description, result: "no matching records" });
    else if (status === "MATCHING_REFERENCE" && preserveMatching) preserved.push({ type: name, count: result.docs.length, disposition: "preserve shared records after account closure" });
    else unresolved.push({ check: `reference:${name}`, reason: `${name} reference discovery failed, exceeded its bounded scan, or found records with unsupported community scope.` });
    if (!result.failed && !result.capped) verifiedChecks.push(`${name} supported UID fields`);
  }

  const bookingQueries = ["bookings", "amenityBookings", "amenity_bookings"].flatMap((collection) =>
    ["userId", "residentId"].map((field) => [collection, field]));
  const bookingResult = await discover("bookings", bookingQueries);
  let bookingStatus = bookingResult.failed || bookingResult.capped ? "UNKNOWN_OR_UNSUPPORTED" : bookingResult.docs.length ? "MATCHING_REFERENCE" : "VERIFIED_ABSENT";
  if (bookingStatus === "MATCHING_REFERENCE" && bookingResult.docs.some(({ data }) => typeof data.communityId !== "string" || !data.communityId)) bookingStatus = "UNKNOWN_OR_UNSUPPORTED";
  let bookingDispositionVerified = false;
  if (bookingStatus === "MATCHING_REFERENCE" && bookingResult.docs.every((record) => record.collection === "amenity_bookings")) {
    try {
      const progressSnapshot = await db.collection(COLLECTION).doc(requestId).collection("processing").doc("membershipAndBookingCleanup").get();
      const progress = progressSnapshot.data();
      const dispositions = new Map((progress?.verifiedBookingReferences ?? []).map((item) => [item.path, item]));
      const safelyDisposed = progressSnapshot.exists && progress?.status === "completed" && progress?.uid === uid && progress?.requestId === requestId && bookingResult.docs.every(({ data, ref }) => {
        const expected = dispositions.get(ref?.path);
        return expected?.uid === uid && expected.communityId === data.communityId && typeof data.communityId === "string" && data.communityId &&
          (data.userId === uid || data.residentId === uid) && data.status === expected.status;
      });
      if (safelyDisposed) bookingDispositionVerified = true;
    } catch (_) { /* no cleanup progress means matching history remains blocked */ }
  }
  classes.bookings = { status: bookingStatus, count: bookingResult.docs.length, cleanupEligible: bookingResult.docs.length > 0 && bookingResult.docs.every((record) => record.collection === "amenity_bookings"), dispositionVerified: bookingDispositionVerified, communities: [...new Set(bookingResult.docs.map(({ data }) => data.communityId).filter((id) => typeof id === "string"))] };
  if (bookingStatus === "VERIFIED_ABSENT") verifiedAbsence.push({ type: "bookings", scope: "bookings/amenityBookings/amenity_bookings userId/residentId across all communities", result: "no matching records" });
  else {
    if (bookingResult.failed && !bookingResult.capped) retryableChecks.add("reference:bookings");
    if (bookingStatus === "MATCHING_REFERENCE") preserved.push({ type: "booking_history", count: bookingResult.docs.length, disposition: bookingDispositionVerified ? "preserve booking records after verified cancellation/history disposition" : "preserve booking records; account closure remains blocked until request-scoped cleanup is verified" });
    if (!bookingDispositionVerified) unresolved.push({ check: "reference:bookings", reason: bookingStatus === "UNKNOWN_OR_UNSUPPORTED" ? "Booking reference discovery failed or exceeded its bound." : "Booking records reference this Resident UID and lack verified request-scoped cleanup disposition." });
  }
  if (!bookingResult.failed && !bookingResult.capped) verifiedChecks.push("bookings/amenityBookings/amenity_bookings userId/residentId");

  recordClass("chatRequests", await discover("chatRequests", [["chatRequests", "senderId"], ["chatRequests", "receiverId"]]),
    { description: "chatRequests senderId/receiverId across communities", preserveMatching: true });

  const chatDocs = await discover("chats", [["chats", "participantIds", "array-contains"], ["chats", "participants", "array-contains"]]);
  const messageResult = await discover("messages", [["<group>", "senderId"], ["<group>", "receiverId"]]);
  const nestedMessageDocs = messageResult.docs.filter((record) => {
    const path = record.ref?.path?.split("/") ?? [];
    return path.length === 4 && path[0] === "chats" && path[2] === "messages";
  });
  let messageUnknown = messageResult.failed || messageResult.capped;
  let messageReadFailed = messageResult.failed;
  for (const record of nestedMessageDocs) {
    try {
      const parent = record.ref?.parent?.parent;
      if (!parent) { messageUnknown = true; continue; }
      const chat = await parent.get();
      const chatData = chat.data();
      if (!chat.exists || (chatData?.communityId != null && typeof chatData.communityId !== "string")) messageUnknown = true;
      else if (typeof chatData?.communityId === "string") communityIds.add(chatData.communityId);
    } catch (_) { messageUnknown = true; messageReadFailed = true; }
  }
  const chatsStatus = chatDocs.failed || chatDocs.capped ? "UNKNOWN_OR_UNSUPPORTED" : chatDocs.docs.length ? "MATCHING_REFERENCE" : "VERIFIED_ABSENT";
  const messagesStatus = messageUnknown ? "UNKNOWN_OR_UNSUPPORTED" : messageResult.docs.length ? "MATCHING_REFERENCE" : "VERIFIED_ABSENT";
  if (chatDocs.failed && !chatDocs.capped) retryableChecks.add("reference:chats");
  if (messageReadFailed && !messageResult.capped) retryableChecks.add("reference:chatMessages");
  for (const [name, status, count, scope] of [
    ["chats", chatsStatus, chatDocs.docs.length, "chats participantIds/participants arrays"],
    ["chatMessages", messagesStatus, nestedMessageDocs.length, "chats/{chatId}/messages senderId/receiverId collection-group queries and parent chat relationship"],
  ]) {
    classes[name] = { status, count };
    if (status === "VERIFIED_ABSENT") verifiedAbsence.push({ type: name, scope, result: "no matching records" });
    else {
      if (status === "MATCHING_REFERENCE") preserved.push({ type: name, count, disposition: "preserve shared conversation history after account closure" });
      else unresolved.push({ check: `reference:${name}`, reason: `${name} discovery or parent relationship could not be fully verified.` });
    }
    if (status !== "UNKNOWN_OR_UNSUPPORTED") verifiedChecks.push(`${name} supported reference query`);
  }

  const sosResults = {};
  try {
    const active = await db.collection("sosActive").doc(uid).get();
    sosResults.sosActive = active.exists ? [{ id: uid, ...active.data() }] : [];
  } catch (_) { sosResults.sosActive = null; }
  for (const collection of ["sosAlerts", "sosRequests", "sosNotificationEvents"]) {
    try {
      const result = await db.collection(collection).where("residentUid", "==", uid).limit(MAX_REFERENCE_SCAN).get();
      sosResults[collection] = result.docs.map((doc) => ({ id: doc.id, ...doc.data() }));
      if (result.docs.length >= MAX_REFERENCE_SCAN) sosResults[collection] = null;
    } catch (_) { sosResults[collection] = null; }
  }
  const sosUnknown = Object.values(sosResults).some((rows) => rows === null);
  const sosRows = Object.entries(sosResults).flatMap(([collection, rows]) => (rows || []).map((row) => ({ collection, ...row })));
  const sosBadScope = sosRows.some((row) => typeof row.communityId !== "string" || !row.communityId);
  const sosStatus = sosUnknown || sosBadScope ? "UNKNOWN_OR_UNSUPPORTED" : sosRows.length ? "MATCHING_REFERENCE" : "VERIFIED_ABSENT";
  classes.sos = { status: sosStatus, count: sosRows.length, cleanupEligible: sosStatus === "MATCHING_REFERENCE" && sosRows.every((row) => row.collection !== "sosAlerts" || row.communityId === profiles.users?.communityId), communities: [...new Set(sosRows.map((row) => row.communityId).filter(Boolean))] };
  if (sosStatus === "VERIFIED_ABSENT") verifiedAbsence.push({ type: "sos", scope: "sosActive/{uid}, sosAlerts/sosRequests/sosNotificationEvents residentUid and linked sosDeliveries through event identity", result: "no matching records" });
  else if (sosUnknown || sosBadScope) {
    if (sosUnknown && !sosBadScope) retryableChecks.add("reference:sos");
    unresolved.push({ check: "reference:sos", reason: "SOS records could not be completely queried or have unsupported community scope." });
  } else {
    const activeSos = sosRows.some((row) => ["triggered", "acknowledged", "responding", "in_progress"].includes(String(row.status ?? "").toLowerCase()));
    if (sosResults.sosActive?.length || activeSos) unresolved.push({ check: "activeSos", reason: "An active emergency requires response and resolution before account closure." });
    if (!activeSos && sosRows.some((row) => row.collection === "sosAlerts" && Object.hasOwn(row, "location"))) {
      unresolved.push({ check: "reference:sos", reason: "Resident location data in resolved SOS alerts requires request-bound removal." });
    }
    preserved.push({ type: "sos_history", count: sosRows.length, disposition: "preserve emergency history after account closure" });
  }

  const [notificationRoots, readReceiptResult] = await Promise.all([
    discover("notifications", [["notifications", "recipientId"]]),
    discover("readBy", [["<group>", "userId"]]),
  ]);
  const notificationResult = { docs: [...notificationRoots.docs, ...readReceiptResult.docs], failed: notificationRoots.failed || readReceiptResult.failed, capped: notificationRoots.capped || readReceiptResult.capped };
  const deviceResult = await discover("notificationDevices", [["notificationDevices", "uid"]]);
  let readReceiptUnknown = readReceiptResult.docs.some(({ ref }) => {
    const path = ref?.path?.split("/");
    return path?.length !== 4 || path[0] !== "notices" || path[2] !== "readBy";
  });
  const readReceiptRows = [];
  let readReceiptReadFailed = false;
  for (const record of notificationResult.docs.filter(({ collection, ref }) => collection === "<group>" &&
    ref?.path?.split("/").length === 4 && ref.path.split("/")[0] === "notices" && ref.path.split("/")[2] === "readBy")) {
    try {
      const parent = record.ref?.parent?.parent;
      if (!parent) { readReceiptUnknown = true; continue; }
      const notice = await parent.get();
      if (!notice.exists || typeof notice.data()?.communityId !== "string" || !notice.data()?.communityId) readReceiptUnknown = true;
      else {
        communityIds.add(notice.data().communityId);
        readReceiptRows.push({ ...record, data: { ...record.data, communityId: notice.data().communityId } });
      }
    } catch (_) { readReceiptUnknown = true; readReceiptReadFailed = true; }
  }
  const notificationFailed = notificationResult.failed || notificationResult.capped || readReceiptUnknown;
  const notificationDocs = [...notificationResult.docs.filter(({ collection }) => collection !== "<group>"), ...readReceiptRows];
  const notificationBadScope = notificationDocs.some(({ data }) => typeof data.communityId !== "string" || !data.communityId);
  const notificationStatus = notificationFailed || notificationBadScope ? "UNKNOWN_OR_UNSUPPORTED" : notificationDocs.length ? "MATCHING_REFERENCE" : "VERIFIED_ABSENT";
  const notificationCleanupEligible = notificationStatus === "MATCHING_REFERENCE" && !!profiles.users?.communityId &&
    notificationDocs.every(({ collection, data, ref }) => data.communityId === profiles.users.communityId &&
      (collection === "notifications" ? data.recipientId === uid && (data.recipientRole == null || data.recipientRole === "resident") && (data.appId == null || data.appId === "resident") :
        collection === "<group>" && data.userId === uid && ref?.path?.split("/").length === 4));
  classes.notifications = { status: notificationStatus, count: notificationDocs.length,
    cleanupEligible: notificationCleanupEligible,
    records: notificationDocs.map(({ collection, id, ref, data }) => ({ collection, id, path: ref?.path ?? null, communityId: data.communityId ?? null })) };
  if (notificationStatus === "VERIFIED_ABSENT") verifiedAbsence.push({ type: "notifications", scope: "notifications.recipientId and notices/{id}/readBy/{uid} userId collection-group references", result: "no matching records" });
  else {
    if ((notificationResult.failed || readReceiptReadFailed) && !notificationResult.capped && !notificationBadScope) retryableChecks.add("reference:notifications");
    if (notificationStatus === "MATCHING_REFERENCE" && !notificationCleanupEligible) preserved.push({ type: "notifications", count: notificationDocs.length, disposition: "notification ownership or community scope is ambiguous and requires reconciliation" });
    unresolved.push({ check: "reference:notifications", reason: notificationStatus === "UNKNOWN_OR_UNSUPPORTED" ? "Notification discovery failed, exceeded its bound, or found records without community scope." : "Resident-owned notification records require request-bound cleanup." });
  }

  // Installation registrations are disposable credentials, separate from shared
  // notification/read history. Only canonical, single-community Resident devices
  // may enter the coordinator's request-bound cleanup step.
  const deviceScope = profiles.users?.uid === uid && profiles.users?.role === "resident" ? profiles.users.communityId : null;
  const deviceUnknown = deviceResult.failed || deviceResult.capped || deviceResult.docs.length >= MAX_REFERENCE_SCAN - 1 ||
    deviceResult.docs.some(({ id, data }) => !deletionDeviceMatches(data, id, uid, deviceScope));
  const deviceStatus = deviceUnknown ? "UNKNOWN_OR_UNSUPPORTED" : deviceResult.docs.length ? "MATCHING_REFERENCE" : "VERIFIED_ABSENT";
  if (deviceResult.failed && !deviceResult.capped) retryableChecks.add("reference:notificationDevices");
  classes.notificationDevices = { status: deviceStatus, count: deviceResult.docs.length, cleanupEligible: deviceStatus === "MATCHING_REFERENCE",
    records: deviceResult.docs.map(({ id, ref, data }) => ({ id, path: ref?.path ?? `notificationDevices/${id}`, communityId: data.communityId ?? null })) };
  if (deviceStatus === "VERIFIED_ABSENT") verifiedAbsence.push({ type: "notificationDevices", scope: "notificationDevices.uid across all communities", result: "no matching registrations" });
  else unresolved.push({ check: "reference:notificationDevices", reason: deviceUnknown
    ? "Notification device ownership, app identity, or community scope could not be fully verified."
    : "Owned notification device registrations require request-bound cleanup." });

  const imageQueries = [
    ["storageImageUploads", "ownerId"], ["residentImageDrafts", "ownerId"], ["residentImageCommits", "ownerId"],
    ["posts", "authorId"], ["complaints", "userId"], ["marketplaces", "sellerId"],
  ];
  const rawImageResult = await discover("images", imageQueries);
  const imageMarkers = ["imageAsset", "imageAssets", "imageUrl", "imageUrls", "profileImage", "profileImageUrl", "photoURL", "images"];
  const imageResult = {
    ...rawImageResult,
    docs: rawImageResult.docs.filter(({ collection, data }) =>
      ["storageImageUploads", "residentImageDrafts", "residentImageCommits"].includes(collection) ||
      imageMarkers.some((field) => Object.hasOwn(data, field))),
  };
  for (const { data } of imageResult.docs) if (typeof data.communityId === "string") communityIds.add(data.communityId);
  const managedAssets = profiles.users?.managedImageAssets;
  const profileImageFields = ["profileImage", "profileImageUrl", "photoURL", "photoUrl"];
  const hasProfileImageReference = (Array.isArray(managedAssets) && managedAssets.length > 0) ||
    profileImageFields.some((field) => typeof profiles.users?.[field] === "string" && profiles.users[field].trim());
  const profileAssetCollections = ["storageImageUploads", "residentImageDrafts", "residentImageCommits"];
  const profileAssets = imageResult.docs.filter(({ collection, data }) => profileAssetCollections.includes(collection) && data.feature === "profile");
  const otherOwnedImageRecords = imageResult.docs.filter(({ collection, data }) => profileAssetCollections.includes(collection) && data.feature !== "profile");
  const badProfileAssetScope = profileAssets.some(({ data }) => data.ownerId !== uid || data.resourceId !== uid || data.communityId !== profiles.users?.communityId);
  const unknownOwnedImageSchema = otherOwnedImageRecords.some(({ data }) => typeof data.feature !== "string" || typeof data.communityId !== "string" || !data.communityId);
  const profileCommunity = profiles.users?.communityId;
  let imageStatus = imageResult.failed || imageResult.capped || (managedAssets != null && !Array.isArray(managedAssets)) || badProfileAssetScope || unknownOwnedImageSchema
    ? "UNKNOWN_OR_UNSUPPORTED"
    : hasProfileImageReference || profileAssets.length ? "MATCHING_REFERENCE" : "VERIFIED_ABSENT";
  let storageCommunityDiscoveryUnknown = false;
  let storageReadFailed = false;
  const storagePrefixes = [];
  try {
    const communities = await db.collection("communities").limit(MAX_REFERENCE_SCAN).get();
    if (communities.docs.length >= MAX_REFERENCE_SCAN) storageCommunityDiscoveryUnknown = true;
    for (const community of communities.docs) storagePrefixes.push({ communityId: community.id, prefix: `resident_images/${community.id}/${uid}/profile/` }, { communityId: community.id, prefix: `private_images/${community.id}/${uid}/profile/` });
  } catch (_) { storageCommunityDiscoveryUnknown = true; storageReadFailed = true; }
  if (typeof profileCommunity === "string" && profileCommunity && !storagePrefixes.some((entry) => entry.communityId === profileCommunity)) {
    storagePrefixes.push({ communityId: profileCommunity, prefix: `resident_images/${profileCommunity}/${uid}/profile/` }, { communityId: profileCommunity, prefix: `private_images/${profileCommunity}/${uid}/profile/` });
  }
  if (!bucket?.getFiles) imageStatus = "UNKNOWN_OR_UNSUPPORTED";
  else {
    if (storageCommunityDiscoveryUnknown) imageStatus = "UNKNOWN_OR_UNSUPPORTED";
    for (const { prefix, communityId } of storagePrefixes) {
      try {
        const [files] = await bucket.getFiles({ prefix, maxResults: 1, autoPaginate: false });
        if (files.length) {
          imageStatus = "MATCHING_REFERENCE";
          if (communityId !== profileCommunity) storageCommunityDiscoveryUnknown = true;
        }
      } catch (_) { imageStatus = "UNKNOWN_OR_UNSUPPORTED"; storageReadFailed = true; }
    }
  }
  const cleanupEligible = imageStatus === "MATCHING_REFERENCE" && !badProfileAssetScope && !unknownOwnedImageSchema && !storageCommunityDiscoveryUnknown && profileAssets.every(({ data }) => data.ownerId === uid && data.resourceId === uid && data.communityId === profileCommunity);
  classes.imagesAndStorage = { status: imageStatus, cleanupEligible, firestoreReferences: imageResult.docs.length, storagePrefixesChecked: bucket?.getFiles ? storagePrefixes.length : 0, communityDiscoveryComplete: !storageCommunityDiscoveryUnknown };
  if (imageStatus === "VERIFIED_ABSENT") verifiedAbsence.push({ type: "images_and_storage", scope: "Resident profile image assets and profile Storage prefixes in the verified community", result: "no matching references or objects" });
  else {
    if ((imageResult.failed || storageReadFailed) && !imageResult.capped && !badProfileAssetScope) retryableChecks.add("reference:imagesAndStorage");
    if (otherOwnedImageRecords.length) preserved.push({ type: "shared_image_records", count: otherOwnedImageRecords.length, disposition: "preserve assets attached to shared community content" });
    unresolved.push({ check: "reference:imagesAndStorage", reason: imageStatus === "UNKNOWN_OR_UNSUPPORTED" ? "Profile image ownership or Storage discovery is incomplete." : "Resident-owned profile image data requires request-bound cleanup." });
  }

  classes.retryableChecks = [...retryableChecks];
  return classes;
}

// Only established Community Admin actions receive that label. Missing indexes,
// unsupported retention/disposition and unknown discovery require processing
// review. Derive this at read time so existing request references remain intact.
function accountDeletionReviewType(request) {
  if (request.status !== "pending_review") return null;
  const reasons = request.processingBlockers;
  return request.communityScopeVerified === true && request.financialReviewRequired === true && Array.isArray(reasons) && reasons.length > 0
    ? "community_admin" : "processing";
}

async function notifyCommunityAdminsOfDeletionRequest({ db, requestId, request }) {
  const communityId = request?.communityId;
  if (typeof communityId !== "string" || !communityId || request?.communityScopeVerified !== true) return;
  try {
    const admins = await db.collection("admins").where("authorizedCommunityIds", "array-contains", communityId).limit(100).get();
    const batch = db.batch();
    let writes = 0;
    for (const admin of admins.docs) {
      const profile = admin.data();
      if (profile.uid !== admin.id || profile.role !== "admin" || profile.isActive !== true ||
          !Array.isArray(profile.authorizedCommunityIds) || !profile.authorizedCommunityIds.includes(communityId)) continue;
      const notificationId = createHash("sha256").update(`account-deletion\n${requestId}\n${admin.id}`).digest("hex").slice(0, 48);
      batch.set(db.collection("notifications").doc(notificationId), {
        communityId, recipientId: admin.id, audience: "admin", role: "admin", appId: "admin",
        title: "Account deletion requested",
        message: "A Resident requested account deletion. Review settlement in Account Deletion Requests.",
        type: "general", priority: "medium", sourceEntityId: requestId,
        createdBy: DELETION_ACTOR, isRead: false, deliveryStatus: "sent",
        createdAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp(),
      }, { merge: true });
      writes++;
    }
    if (writes) await batch.commit();
  } catch (_) {
    // The protected community queue remains the durable delivery path.
  }
}

async function submitAccountDeletionRequestCore({ db, bucket, firebaseAuth = null, auth, data, now = Date.now() }) {
  validateRecentAuth(auth, Math.floor(now / 1000));
  const sourceApp = data?.sourceApp;
  if (!["resident", "admin", "security", "web"].includes(sourceApp)) {
    throw new HttpsError("invalid-argument", "A supported sourceApp is required.");
  }
  const collection = db.collection(COLLECTION);
  const ref = collection.doc();
  let routing = { communityId: null, communityScopeVerified: false, financialReviewStatus: "UNKNOWN_REQUIRES_REVIEW", routingStatus: "unrouted_unknown_community" };
  let requestCommunityName = null;
  if (sourceApp === "resident") {
    const profile = await db.collection("users").doc(auth.uid).get();
    const p = profile.data();
    if (profile.exists && p?.uid === auth.uid && p?.role === "resident" && typeof p.communityId === "string" && p.communityId.trim()) {
      const community = await db.collection("communities").doc(p.communityId).get();
      if (community.exists && community.data()?.isActive === true) {
        const communityData = community.data();
        routing = { communityId: p.communityId, communityScopeVerified: true, financialReviewStatus: "NOT_REQUIRED", routingStatus: "processing" };
        requestCommunityName = String(communityData.name || communityData.communityName || communityData.displayName || "").trim().slice(0, 120) || null;
      }
    }
  }
  let retainedResidentIdentity = null;
  if (sourceApp === "resident" && routing.communityScopeVerified) {
    const profile = (await db.collection("users").doc(auth.uid).get()).data();
    const residentType = String(profile?.residentType || profile?.ownershipType || "").trim().toLowerCase();
    retainedResidentIdentity = {
      name: String(profile?.fullName || profile?.name || profile?.residentName || "").trim().slice(0, 120) || null,
      phoneNumber: String(profile?.phoneNumber || profile?.phone || auth.token?.phone_number || "").trim().slice(0, 40) || null,
      unit: String(profile?.flatLabel || profile?.unitId || profile?.flatId || "").trim().slice(0, 120) || null,
      communityId: routing.communityId,
      communityName: requestCommunityName,
      residentType: ["owner", "tenant"].includes(residentType) ? residentType : null,
    };
  }
  const submitted = await db.runTransaction(async (tx) => {
    const existing = await tx.get(collection.where("uid", "==", auth.uid));
    const active = existing.docs.map((doc) => ({ id: doc.id, ...doc.data() }))
      .filter((item) => sourceApp === "resident" || !["completed", "failed"].includes(item.status))
      .sort((a, b) => (b.createdAt?.toMillis?.() ?? 0) - (a.createdAt?.toMillis?.() ?? 0))[0];
    if (active) {
      if (sourceApp === "resident" && active.sourceApp === "resident" && !active.verificationCompletedAt) {
        tx.update(collection.doc(active.id), { verificationCompletedAt: FieldValue.serverTimestamp(),
          ...(routing.communityScopeVerified === true && !active.retry ? { retry: initialRetry(now) } : {}) });
      } else if (sourceApp === "resident" && active.sourceApp === "resident" && routing.communityScopeVerified === true &&
          active.status !== "completed" && (!active.retry || active.retry.state === "blocked")) {
        tx.update(collection.doc(active.id), { retry: initialRetry(now) });
      }
      return { requestId: active.requestId ?? active.id, status: active.status, idempotent: true };
    }
    tx.set(ref, {
      uid: auth.uid,
      requestId: ref.id,
      sourceApp,
      status: "pending_verification",
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
      processing: null,
      ...(sourceApp === "resident" ? { verificationCompletedAt: FieldValue.serverTimestamp() } : {}),
      ...(sourceApp === "resident" && routing.communityScopeVerified === true ? { retry: initialRetry(now) } : {}),
      ...(retainedResidentIdentity ? { retainedResidentIdentity } : {}),
      deletionPolicyVersion: 2,
      ...routing,
      reviewStatus: routing.communityScopeVerified === true ? "processing" : "unrouted",
      reviewDueAt: FieldValue.serverTimestamp(),
    });
    return { requestId: ref.id, status: "pending_verification", idempotent: false };
  });
  if (sourceApp !== "resident") return submitted;
  const persisted = await collection.doc(submitted.requestId).get();
  const request = persisted.data();
  if (!persisted.exists || request?.uid !== auth.uid || request?.sourceApp !== "resident") return submitted;
  if (!submitted.idempotent && request.communityScopeVerified === true) {
    await notifyCommunityAdminsOfDeletionRequest({ db, requestId: submitted.requestId, request });
  }
  // Only the server-created request ID reaches fulfillment. No execution claims
  // or identity supplied by the client are forwarded to internal cleanup.
  const fulfillment = request.communityScopeVerified === true
    ? await attemptAccountDeletionRequestCore({ db, bucket, firebaseAuth, requestId: submitted.requestId, now: Date.now() })
    : { status: "blocked", blockers: ["Your community could not be verified. Contact your Community Admin to resolve the request."] };
  if (fulfillment.status === "blocked" && request.communityScopeVerified !== true) {
    // Recent authentication has passed. Eligibility blockers require review,
    // not another OTP. Preserve the same request and all coordinator evidence.
    await db.runTransaction(async (tx) => {
      const fresh = await tx.get(persisted.ref ?? collection.doc(submitted.requestId));
      const current = fresh.data();
      if (!fresh.exists || current?.uid !== auth.uid || current?.sourceApp !== "resident") throw new HttpsError("failed-precondition", "Deletion request identity changed.");
      if (["completed", "deletion_in_progress", "reconciliation_required"].includes(current.status)) return;
      tx.update(collection.doc(submitted.requestId), {
        status: "pending_review", processingBlockers: fulfillment.blockers,
        verificationCompletedAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp(),
      });
    });
  }
  const current = (await collection.doc(submitted.requestId).get()).data();
  return { ...submitted, status: current.status, reasons: current.status === "completed" ? [] : current.processingBlockers ?? [], communityScopeVerified: current.communityScopeVerified === true,
    reviewType: accountDeletionReviewType(current), verificationCompletedAt: current.verificationCompletedAt ?? null };
}

async function listCommunityDeletionRequestsCore({ db, auth, data }) {
  const communityId = String(data?.communityId ?? "").trim();
  if (!communityId || Object.keys(data ?? {}).some((key) => key !== "communityId")) throw new HttpsError("invalid-argument", "A communityId is required.");
  const { community } = await requireOperationalAdmin(db, auth, communityId);
  const communityName = String(community.name || community.communityName || community.displayName || "").trim() || communityId;
  const result = await db.collection(COLLECTION).where("communityId", "==", communityId).limit(100).get();
  const requests = [];
  for (const doc of result.docs) {
    const request = doc.data();
    if (!(request?.sourceApp === "resident" || isAssistedIntake(request, doc.id)) || request.communityScopeVerified !== true || request.communityId !== communityId) continue;
    const reviewStatus = request.reviewStatus;
    const completed = request.status === "completed";
    let resident = null;
    const unresolvedDependencies = [];
    const profileSnapshot = typeof request.uid === 'string' && request.uid
      ? await db.collection('users').doc(request.uid).get()
      : null;
    const profile = profileSnapshot?.data();
    const retainedIdentity = request.retainedResidentIdentity && typeof request.retainedResidentIdentity === "object"
      ? request.retainedResidentIdentity : null;
    if (retainedIdentity) {
      resident = {
        displayName: typeof retainedIdentity.name === "string" ? retainedIdentity.name : null,
        phoneNumber: typeof retainedIdentity.phoneNumber === "string" ? retainedIdentity.phoneNumber : null,
        unit: typeof retainedIdentity.unit === "string" ? retainedIdentity.unit : null,
        residentType: typeof retainedIdentity.residentType === "string" ? retainedIdentity.residentType : null,
      };
    } else if (profileSnapshot?.exists && profile?.uid === request.uid && profile?.role === 'resident' && profile?.communityId === communityId && !(Array.isArray(profile.communityIds) && profile.communityIds.some((id) => id !== communityId))) {
      resident = {
        displayName: String(profile.fullName || profile.name || '').trim() || null,
        phoneNumber: String(profile.phoneNumber || profile.phone || '').trim() || null,
        unit: String(profile.flatLabel || profile.unitId || profile.flatId || '').trim() || null,
        residentType: [profile.residentType, profile.ownershipType]
          .map((type) => String(type || '').trim().toLowerCase())
          .find((type) => ["owner", "tenant"].includes(type)) ?? null,
      };
    } else if (!completed) {
      unresolvedDependencies.push('Resident identity or community relationship could not be verified against the current profile.');
    }
    let financialEvidence = null;
    if (request.uid && request.verificationCompletedAt) {
      try { financialEvidence = await financialHandoverEvidence({ db, requestId: doc.id, uid: request.uid, communityId }); }
      catch (_) { /* Unknown financial evidence cannot authorize handover. */ }
    }
    requests.push({
      financialEvidence,
      sourceApp: request.sourceApp,
      ...(request.sourceApp === ASSISTED_SOURCE ? {assistedIntake: request.assistedIntake, intakeDigest: request.intakeDigest,
        assistedVerification: request.assistedVerification ?? null, verificationStatus: hasResidentDeletionVerification(request,doc.id) ? "verified" : "pending"} : {}),
      requestId: doc.id,
      communityId,
      communityName: typeof retainedIdentity?.communityName === "string" && retainedIdentity.communityName.trim()
        ? retainedIdentity.communityName : communityName,
      createdAt: request.createdAt ?? null,
      status: request.status ?? 'unknown',
      resident,
      residentProfileStatus: completed && resident ? 'retained_after_deletion' : resident ? 'verified' : 'unverified_or_missing',
      financialReviewRequired: request.financialReviewRequired === true,
      financialReviewStatus: request.financialReviewStatus ?? 'UNKNOWN_REQUIRES_REVIEW',
      reviewStatus: completed ? 'completed' : reviewStatus ?? 'unknown',
      reviewFinding: request.reviewFinding ?? null,
      reviewNote: request.reviewNote ?? null,
      reviewedAt: request.reviewedAt ?? null,
      completedAt: request.completedAt ?? null,
      reviewDueAt: request.reviewDueAt ?? null,
      unresolvedDependencies,
    });
  }
  return { requests };
}

// Snapshot binds an explicit Admin handover to the records actually reviewed.
// Financial records and their UID links are retained without changes.
async function financialHandoverEvidence({ db, requestId, uid, communityId, tx = null }) {
  const read = (ref) => tx ? tx.get(ref) : ref.get();
  const records = new Map();
  for (const [collection, fields] of [
    ["bills", ["residentId", "userId"]], ["residentFinancialAccounts", ["residentId"]],
    ["payments", ["userId"]], ["paymentProofsV2", ["residentId", "userId"]],
    ["paymentTransactions", ["residentId", "userId"]], ["paymentAllocations", ["residentId", "userId"]],
  ]) {
    for (const field of fields) {
      const rows = await read(db.collection(collection).where(field, "==", uid).limit(201));
      if (rows.docs.length > 200) throw new HttpsError("failed-precondition", "Financial review exceeds the supported bound.");
      for (const doc of rows.docs) {
        const row = doc.data();
        if (row.communityId !== communityId || ["residentId", "userId"].some((key) => row[key] != null && row[key] !== uid)) {
          throw new HttpsError("failed-precondition", "Financial ownership or community scope requires reconciliation.");
        }
        records.set(`${collection}/${doc.id}`, row);
      }
    }
  }
  const unresolved = [];
  const assessment = await assessResidentBillingObligations({ db, uid, communityIds: new Set([communityId]),
    unresolved, verifiedChecks: [], verifiedAbsence: [], read });
  if (assessment.ambiguous.length || unresolved.some((item) => item.check !== "outstandingBillingObligations")) {
    throw new HttpsError("failed-precondition", "Financial amounts or records must be reconciled before handover.");
  }
  const activeSubmission = [...records.entries()].some(([path, row]) =>
    ["payments", "paymentProofsV2", "paymentTransactions", "paymentAllocations"].includes(path.split("/")[0]) &&
    ["pending", "processing", "submitted"].includes(String(row.status ?? "").toLowerCase()));
  if (activeSubmission) throw new HttpsError("failed-precondition", "Pending financial submissions require resolution before handover.");
  const canonical = (value) => {
    if (value?.toMillis) return value.toMillis();
    if (value instanceof Date) return value.getTime();
    if (Array.isArray(value)) return value.map(canonical);
    if (value && typeof value === "object") return Object.fromEntries(Object.keys(value).sort().map((key) => [key, canonical(value[key])]));
    return value;
  };
  const digest = createHash("sha256").update(JSON.stringify(canonical({ requestId, uid, communityId,
    records: [...records.entries()].sort(([a], [b]) => a.localeCompare(b)) }))).digest("hex");
  const outstandingMinor = assessment.obligations.reduce((total, item) => total + (item.outstandingMinor ?? Math.round(item.amount * 100)), 0);
  if (!Number.isSafeInteger(outstandingMinor)) throw new HttpsError("failed-precondition", "Outstanding total requires reconciliation.");
  return { digest, recordCount: records.size, outstandingMinor, currency: "INR" };
}

async function verifyDeletionFinancialHandover({ db, bucket, firebaseAuth, auth, data }) {
  if (Object.keys(data).some((key) => !["requestId", "finding", "note", "evidenceDigest", "retainFinancialRecords"].includes(key)) ||
      data.retainFinancialRecords !== true || typeof data.evidenceDigest !== "string" || !/^[a-f0-9]{64}$/.test(data.evidenceDigest) ||
      typeof data.note !== "string" || data.note.trim().length < 10) {
    throw new HttpsError("invalid-argument", "Confirm retained obligations and provide the current financial evidence and handover note.");
  }
  const requestId = String(data.requestId ?? "").trim();
  if (!requestId) throw new HttpsError("invalid-argument", "Request reference is required.");
  const ref = db.collection(COLLECTION).doc(requestId);
  const saved = await db.runTransaction(async (tx) => {
    const snapshot = await tx.get(ref);
    const request = snapshot.data();
    if (!snapshot.exists || request.communityScopeVerified !== true || !hasResidentDeletionVerification(request,requestId) ||
        request.status !== "pending_review" || !request.verificationCompletedAt || request.retry?.state === "running") {
      throw new HttpsError("failed-precondition", "A verified Resident request awaiting review is required.");
    }
    const actor = await requireOperationalAdmin(db, auth, request.communityId, tx);
    const profile = (await tx.get(db.collection("users").doc(request.uid))).data();
    if (profile?.uid !== request.uid || profile.role !== "resident" || profile.communityId !== request.communityId ||
        (Array.isArray(profile.communityIds) && profile.communityIds.some((id) => id !== request.communityId))) {
      throw new HttpsError("failed-precondition", "Resident community identity changed.");
    }
    const evidence = await financialHandoverEvidence({ db, tx, requestId, uid: request.uid, communityId: request.communityId });
    if (evidence.digest !== data.evidenceDigest) throw new HttpsError("failed-precondition", "Financial records changed. Refresh and review again.");
    if (request.financialReviewRequired !== true) throw new HttpsError("failed-precondition", "This request does not require financial handover.");
    if (evidence.outstandingMinor !== 0) throw new HttpsError("failed-precondition", "Outstanding dues must be settled before financial handover.");
    tx.update(ref, { financialReviewStatus: "VERIFIED_HANDOVER", reviewStatus: "handover_complete_pending_eligibility",
      reviewFinding: "verified_handover", reviewNote: data.note.trim(), reviewedBy: actor.uid, reviewedAt: FieldValue.serverTimestamp(),
      financialHandover: { ...evidence, requestId, uid: request.uid, communityId: request.communityId,
        reviewedBy: actor.uid, reviewedAt: FieldValue.serverTimestamp(), retainFinancialRecords: true },
      retry: initialRetry(Date.now()), updatedAt: FieldValue.serverTimestamp() });
    return { requestId, finding: "verified_handover", deletionRejected: false };
  });
  // The verified snapshot and retry are durable. The scheduled coordinator
  // resumes independently, after the caller receives confirmation.
  return { ...saved, status: "deletion_processing", deletionPerformed: false };
}

async function recordDeletionFinancialReviewCore({ db, bucket, firebaseAuth, auth, data }) {
  if (data?.finding === "verified_handover") return verifyDeletionFinancialHandover({ db, bucket, firebaseAuth, auth, data });
  const requestId = String(data?.requestId ?? "").trim();
  throw new HttpsError("invalid-argument", "Only verified financial handover can be recorded.");
}

async function getAccountDeletionRequestStatusCore({ db, auth }) {
  if (!auth?.uid) throw new HttpsError("unauthenticated", "Authentication is required.");
  const snapshot = await db.collection(COLLECTION).where("uid", "==", auth.uid).get();
  if (snapshot.empty) return { request: null };
  const latest = snapshot.docs.map((doc) => ({ id: doc.id, ...doc.data() }))
    .sort((a, b) => (b.createdAt?.toMillis?.() ?? 0) - (a.createdAt?.toMillis?.() ?? 0))[0];
  const awaitingAssistedVerification = latest.sourceApp === ASSISTED_SOURCE &&
    !hasResidentDeletionVerification(latest, latest.requestId ?? latest.id);
  let financialStatus = null;
  if (!awaitingAssistedVerification && (accountDeletionReviewType(latest) === "community_admin" || latest.financialReviewRequired === true)) {
    try {
      const evidence = await financialHandoverEvidence({ db, requestId: latest.requestId ?? latest.id, uid: latest.uid, communityId: latest.communityId });
      financialStatus = evidence.outstandingMinor > 0 ? "awaiting_settlement" : "eligible_for_verification";
    } catch (_) {
      financialStatus = "unknown_requires_reconciliation";
    }
  } else if (!awaitingAssistedVerification && latest.communityScopeVerified === true && latest.status !== "completed") {
    financialStatus = "zero_dues_automatic_processing";
  }
  return { request: { requestId: latest.requestId ?? latest.id, status: latest.status,
    reasons: latest.status === "completed" ? [] : latest.reconciliationReason ? [latest.reconciliationReason] : latest.processingBlockers ?? [],
    communityScopeVerified: latest.communityScopeVerified === true,
    reviewType: accountDeletionReviewType(latest), financialStatus, verificationCompletedAt: latest.verificationCompletedAt ?? null,
    createdAt: latest.createdAt, updatedAt: latest.updatedAt } };
}

// Internal read-only assessment. Public access is scoped by the wrapper below.
async function reviewAccountDeletionEligibilityCore({ db, bucket, data, profileOverride = null }) {
  const reviewerUid = DELETION_ACTOR;
  const requestId = String(data?.requestId ?? "").trim();
  if (!requestId || Object.keys(data ?? {}).some((key) => key !== "requestId")) {
    throw new HttpsError("invalid-argument", "A requestId is required.");
  }
  const requestSnapshot = await db.collection(COLLECTION).doc(requestId).get();
  if (!requestSnapshot.exists) throw new HttpsError("not-found", "Deletion request was not found.");
  const request = requestSnapshot.data();
  const uid = request?.uid;
  if (typeof uid !== "string" || !uid) throw new HttpsError("failed-precondition", "Request identity is incomplete.");

  const profileCollections = ["users", "admins", "securityStaff"];
  const profiles = {};
  const unresolved = [];
  const verifiedChecks = [];
  if (!hasResidentDeletionVerification(request,requestId)) {
    unresolved.push({ check: "requestVerification", reason: "A server-verified Resident deletion request with valid initiation provenance is required." });
  }
  if (request.communityScopeVerified !== true || typeof request.communityId !== "string" || !request.communityId) {
    unresolved.push({ check: "requestReview", reason: "The request has no verified single-community scope." });
  }
  if (request.communityScopeVerified === true && typeof request.communityId === "string" && request.communityId) {
    try {
      const communitySnapshot = await db.collection("communities").doc(request.communityId).get();
      if (!communitySnapshot.exists) unresolved.push({ check: "communityIdentity", reason: "The request community no longer resolves to a current community record." });
      else verifiedChecks.push("request community ID resolves to a current community record");
    } catch (_) { unresolved.push({ check: "communityIdentity", reason: "Current community identity could not be verified." }); }
  }
  await Promise.all(profileCollections.map(async (collection) => {
    try {
      const snapshot = await db.collection(collection).doc(uid).get();
      if (snapshot.exists) profiles[collection] = snapshot.data();
      else if (collection === "users") {
        const progressSnapshot = await db.collection(COLLECTION).doc(requestId).collection("processing").doc("residentProfile").get();
        const progress = progressSnapshot.data();
        const evidence = progress?.profileEvidence;
        const candidate = profileOverride?.uid === uid ? profileOverride : evidence;
        const evidenceMatches = evidence?.uid === candidate?.uid && evidence?.role === candidate?.role && evidence?.communityId === candidate?.communityId && (evidence?.flatId ?? null) === (candidate?.flatId ?? null) && (evidence?.residentId ?? null) === (candidate?.residentId ?? null);
        if (progressSnapshot.exists && ["deleting", "completed"].includes(progress?.status) && progress?.requestId === requestId && progress?.uid === uid && candidate?.uid === uid && candidate?.role === "resident" && candidate?.communityId === request.communityId && evidenceMatches) profiles[collection] = candidate;
        else profiles[collection] = null;
      } else profiles[collection] = null;
    } catch (_) {
      profiles[collection] = null;
      unresolved.push({ check: `profile:${collection}`, reason: "Profile discovery failed; absence cannot be confirmed." });
    }
  }));
  const roles = Object.entries(profiles).filter(([, profile]) => profile != null).map(([collection]) => collection);
  const communities = [...new Set([
    profiles.users?.communityId,
    ...(Array.isArray(profiles.admins?.authorizedCommunityIds) ? profiles.admins.authorizedCommunityIds : []),
    profiles.securityStaff?.communityId,
  ].filter((value) => typeof value === "string" && value.trim()))];
  if (!roles.length) unresolved.push({ check: "identity", reason: "No canonical profile found; linked legacy identities are not ruled out." });
  if (profiles.users && (profiles.users.uid !== uid || profiles.users.role !== "resident" || typeof profiles.users.communityId !== "string" || !profiles.users.communityId.trim())) unresolved.push({ check: "residentIdentity", reason: "Canonical Resident UID, role, or community identity is incomplete." });
  if (profiles.users && request.communityId !== profiles.users.communityId) unresolved.push({ check: "residentCommunity", reason: "Request community does not match the canonical Resident profile." });
  if (profiles.users && Array.isArray(profiles.users.communityIds) && profiles.users.communityIds.some((id) => id !== profiles.users.communityId)) unresolved.push({ check: "multiCommunityResident", reason: "Resident profile lists multiple communities; single-community deletion cannot be verified." });
  if (roles.length > 1) unresolved.push({ check: "multipleRoles", reason: "UID has multiple role profiles; each role requires independent review." });
  if (profiles.admins) unresolved.push({ check: "adminResponsibilities", reason: "Admin responsibilities must be reviewed and reassigned before closure." });
  if (profiles.securityStaff) unresolved.push({ check: "securityResponsibilities", reason: "Security assignments and gate duties must be reviewed and reassigned." });
  const preserved = [];
  const activeDependencies = [];
  const verifiedAbsence = [];
  const eligiblePersonalRecords = [];
  async function queryReferences(collection, fields, valueOverrides = {}) {
    const found = new Map();
    for (const field of fields) {
      const [name, operator = "=="] = field.split(":");
      const values = valueOverrides[name] ?? [uid];
      for (const value of values) {
        try {
          const result = await db.collection(collection).where(name, operator, value).get();
          for (const doc of result.docs) found.set(doc.id, doc.data());
        } catch (_) {
          unresolved.push({ check: `query:${collection}.${field}`, reason: `Could not completely query ${collection}.${field}; references remain unknown.` });
        }
      }
    }
    return [...found.entries()].map(([id, value]) => ({ id, ...value }));
  }
  // Supported canonical visitor host fields from rules and callable schemas.
  const visitors = await queryReferences("visitors", ["hostUserId", "residentId"]);
  const indexesByOwner = await queryReferences("visitorGateCredentialIndex", ["hostUserId"]);
  if (!unresolved.some((item) => item.check.startsWith("query:visitorGateCredentialIndex."))) verifiedChecks.push("visitorGateCredentialIndex.hostUserId query for newly issued indexes");
  if (!unresolved.some((x) => x.check.startsWith("query:visitors."))) verifiedChecks.push("visitor hostUserId/residentId queries");
  const visitorLifecycle = visitors.map((visitor) => ({
    visitorId: visitor.id,
    communityId: visitor.communityId ?? null,
    classification: classifyVisitorForDeletion(visitor, Date.now()),
  }));
  const checkedInVisitors = visitorLifecycle.filter((item) => item.classification === "checked_in");
  const ambiguousVisitors = visitorLifecycle.filter((item) => item.classification === "ambiguous");
  const futureVisitors = visitorLifecycle.filter((item) => ["future_expected", "future_approved"].includes(item.classification));
  const historicalVisitors = visitorLifecycle.filter((item) => ["verified_completed_history", "terminal_history", "entry_denied_history"].includes(item.classification));
  if (checkedInVisitors.length) {
    activeDependencies.push({ type: "checked_in_visitors", records: checkedInVisitors });
    unresolved.push({ check: "checkedInVisitors", reason: "Visitors are physically checked in; Security must complete verified checkout before account closure." });
  }
  if (futureVisitors.length) {
    activeDependencies.push({ type: "future_visitors", records: futureVisitors });
    unresolved.push({ check: "futureVisitors", reason: "Future visitor invitations remain active; cancel them through the deletion request before account closure." });
  }
  if (ambiguousVisitors.length) {
    activeDependencies.push({ type: "ambiguous_visitors", records: ambiguousVisitors });
    unresolved.push({ check: "ambiguousVisitorState", reason: "Visitor ownership or lifecycle state is incomplete, unsupported, or missing required timestamps." });
  }
  if (historicalVisitors.length) preserved.push({ type: "historical_visitors", records: historicalVisitors, disposition: "preserve security history; verified completed visits are not active dependencies" });
  const visitorIds = visitors.map((visitor) => visitor.id);
  const visitorById = new Map(visitors.map((visitor) => [visitor.id, visitor]));
  const credentials = [];
  for (const visitorId of visitorIds) {
    try {
      const [credentialSnapshot, indexSnapshot] = await Promise.all([
        db.collection("visitorHostCredentials").doc(visitorId).get(),
        db.collection("visitorGateCredentialIndex").where("visitorId", "==", visitorId).get(),
      ]);
      const progressSnapshot = await db.collection(COLLECTION).doc(requestId).collection("visitorCredentialRevocations").doc(visitorId).get();
      const visitorCommunityId = visitorById.get(visitorId)?.communityId ?? null;
      const progress = progressSnapshot.data();
      const indexes = indexSnapshot.docs.map((doc) => ({ id: doc.id, communityId: doc.data()?.communityId, hostUserId: doc.data()?.hostUserId ?? null, type: doc.data()?.credentialType }));
      const progressVerified = progressSnapshot.exists && progress?.complete === true && progress?.status === "completed" && progress?.requestId === requestId && progress?.uid === uid && progress?.visitorId === visitorId && progress?.communityId === visitorCommunityId;
      if (credentialSnapshot.exists) credentials.push({ visitorId, communityId: credentialSnapshot.data()?.communityId ?? null, credentialHostUserId: credentialSnapshot.data()?.hostUserId ?? null, hasHostCredential: true, indexes, revocationCompleted: false });
      else credentials.push({ visitorId, communityId: visitorCommunityId, hasHostCredential: false, indexes, revocationCompleted: progressVerified });
    } catch (_) { unresolved.push({ check: `visitorCredential:${visitorId}`, reason: "Credential or hash-index discovery failed; credential remains unverified." }); }
  }
  if (!unresolved.some((item) => item.check.startsWith("visitorCredential:"))) verifiedChecks.push("visitorHostCredentials and visitorGateCredentialIndex by visitorId for every matched visitor");
  const activeVisitorIds = new Set(visitorLifecycle.filter((item) => !["verified_completed_history", "terminal_history", "entry_denied_history"].includes(item.classification)).map((item) => item.visitorId));
  const activeCredentialSet = credentials.filter((item) => item.hasHostCredential || item.indexes.length > 0);
  if (activeCredentialSet.length) activeDependencies.push({ type: "visitor_credentials", records: activeCredentialSet });
  if (indexesByOwner.some((index) => index.hostUserId !== uid || typeof index.communityId !== "string" || !index.communityId || (profiles.users?.communityId && index.communityId !== profiles.users.communityId))) unresolved.push({ check: "credentialOwnerMismatch", reason: "Credential index ownership or community does not match the verified Resident profile." });
  if (credentials.some((item) => item.indexes.some((index) => index.communityId !== item.communityId || (index.hostUserId != null && index.hostUserId !== uid)))) unresolved.push({ check: "credentialOwnerMismatch", reason: "A credential index has an inconsistent owner or community relationship." });
  if (credentials.some((item) => item.hasHostCredential && (item.credentialHostUserId !== uid || item.communityId !== visitorById.get(item.visitorId)?.communityId))) unresolved.push({ check: "credentialOwnerMismatch", reason: "The private visitor credential owner or community does not match its verified visitor record." });
  if (credentials.some((item) => !item.hasHostCredential && item.indexes.length > 0)) unresolved.push({ check: "orphanedCredentialIndex", reason: "Credential indexes remain after the private credential is missing; ownership and revocation cannot be considered complete." });
  if (credentials.some((item) => activeVisitorIds.has(item.visitorId) && !item.hasHostCredential && item.indexes.length === 0 && !item.revocationCompleted)) unresolved.push({ check: "missingCredentialWithoutProgress", reason: "Credential records are absent without request-scoped verified revocation progress." });
  if (credentials.some((item) => item.hasHostCredential)) unresolved.push({ check: "activeCredential", reason: "A verified host credential remains active and must be revoked before closure." });

  const legacyResidentId = typeof profiles.users?.residentId === "string" ? profiles.users.residentId.trim() : "";
  const flatResidentIdValues = [...new Set([uid, ...(legacyResidentId ? [legacyResidentId] : [])])];
  const flats = await queryReferences("flats", ["residentUserId", "residentUid", "residentId", "residentIds", "residentIds:array-contains"], { residentId: flatResidentIdValues, residentIds: [uid] });
  const memberships = flats.map((r) => ({ collection: "flats", id: r.id }));
  if (memberships.length) activeDependencies.push({ type: "unit_memberships", records: memberships });
  const flatQueryFailed = unresolved.some((x) => x.check.startsWith("query:flats."));
  if (!flatQueryFailed) verifiedChecks.push("flat residentUserId/residentUid/residentId/residentIds fields, including the profile residentId alias when present");
  if (memberships.length) unresolved.push({ check: "unitMemberships", reason: "Unit/flat assignments reference this UID and require reassignment before profile closure." });
  const currentFlatId = typeof profiles.users?.flatId === "string" ? profiles.users.flatId.trim() : "";
  let currentFlatPointerUnverified = Boolean(currentFlatId && !flats.some((flat) => flat.id === currentFlatId));
  if (currentFlatPointerUnverified) {
    try {
      const progressSnapshot = await db.collection(COLLECTION).doc(requestId).collection("processing").doc("membershipAndBookingCleanup").get();
      const progress = progressSnapshot.data();
      const flatSnapshot = await db.collection("flats").doc(currentFlatId).get();
      const flat = flatSnapshot.data();
      const uidPointersCleared = !["residentUserId", "residentUid", "residentId"].some((field) => flat?.[field] === uid) && !flat?.residentIds?.includes?.(uid);
      if (progressSnapshot.exists && progress?.status === "completed" && progress?.requestId === requestId && progress?.uid === uid && flatSnapshot.exists && flat?.communityId === profiles.users?.communityId && uidPointersCleared) currentFlatPointerUnverified = false;
    } catch (_) { /* absent progress or flat evidence leaves the pointer unresolved */ }
  }
  if (currentFlatPointerUnverified) unresolved.push({ check: "residentFlatPointerMismatch", reason: "The Resident profile names a current flatId that does not appear in the verified UID/legacy-alias flat queries; the profile and flat ownership relationship is inconsistent or incomplete." });

  const complaints = await queryReferences("complaints", ["userId", "residentId"]);
  if (complaints.length) preserved.push({ type: "complaints", count: complaints.length, ids: complaints.map((x) => x.id), disposition: "preserve operational history; attachments and identifier minimization require per-record review" });
  if (!unresolved.some((x) => x.check.startsWith("query:complaints."))) verifiedChecks.push("complaint userId/residentId fields");
  if (!complaints.length && !unresolved.some((x) => x.check.startsWith("query:complaints."))) verifiedAbsence.push({ type: "complaints", scope: "supported userId/residentId fields", result: "no matching records" });
  // Complaint records and their shared evidence remain part of community history.

  const chats = await queryReferences("chats", ["participantIds:array-contains", "participants:array-contains"]);
  const messages = await queryReferences("messages", ["senderId", "receiverId"]);
  if (chats.length || messages.length) preserved.push({ type: "chat_history", chats: chats.map((x) => x.id), messages: messages.map((x) => x.id), disposition: "preserve shared conversation history; identifier minimization requires review" });
  if (!unresolved.some((x) => x.check.startsWith("query:chats.") || x.check.startsWith("query:messages."))) verifiedChecks.push("chat participant and message sender/receiver fields");
  if (!chats.length && !messages.length && !unresolved.some((x) => x.check.startsWith("query:chats.") || x.check.startsWith("query:messages."))) verifiedAbsence.push({ type: "chat_history", scope: "supported chat participant and message sender/receiver fields", result: "no matching records" });
  // Shared chat records are preserved; account closure does not delete them.

  const bookings = await queryReferences("amenity_bookings", ["userId", "residentId"]);
  if (bookings.length) {
    const activeBookings = bookings.filter((item) => {
      const date = visitorTimestampMillis(item.date ?? item.bookingDate);
      return date != null && date > Date.now() && ["pending", "approved", "confirmed", "checked_in"].includes(String(item.status ?? "").toLowerCase());
    });
    if (activeBookings.length) activeDependencies.push({ type: "active_bookings", ids: activeBookings.map((item) => item.id) });
    if (bookings.length > activeBookings.length) preserved.push({ type: "booking_history", ids: bookings.filter((item) => !activeBookings.includes(item)).map((item) => item.id), disposition: "preserve booking history" });
    if (activeBookings.length) unresolved.push({ check: "activeBookings", reason: "Active facility bookings require cancellation or reassignment." });
  }
  if (!unresolved.some((x) => x.check.startsWith("query:amenity_bookings."))) verifiedChecks.push("amenity booking userId/residentId fields");

  const onboarding = await queryReferences("residentOnboarding", ["claimedByUid"]);
  if (onboarding.length) activeDependencies.push({ type: "resident_onboarding", ids: onboarding.map((item) => item.id) });
  const onboardingQueryFailed = unresolved.some((x) => x.check.startsWith("query:residentOnboarding."));
  if (!onboardingQueryFailed) verifiedChecks.push("resident onboarding claimedByUid field");
  if (onboarding.length) unresolved.push({ check: "residentOnboardingReferences", reason: "Resident onboarding records are still claimed by this UID and need an established terminal disposition." });
  const legacyReferenceCoverage = {
    status: flatQueryFailed || onboardingQueryFailed || currentFlatPointerUnverified ? "incomplete" : (memberships.length || onboarding.length ? "matching_references_found" : "verified_absence_in_supported_fields"),
    checked: ["flats.residentUserId", "flats.residentUid", "flats.residentIds equal to UID or array membership", "flats.residentId equal to UID or profile residentId", "residentOnboarding.claimedByUid"],
    matchingFlatIds: flats.map((item) => item.id),
    matchingOnboardingIds: onboarding.map((item) => item.id),
  };
  if (legacyReferenceCoverage.status === "verified_absence_in_supported_fields") {
    verifiedAbsence.push({ type: "legacy_resident_references", scope: legacyReferenceCoverage.checked, result: "no matching records" });
  } else if (legacyReferenceCoverage.status === "incomplete") {
    unresolved.push({ check: "legacyResidentReferences", reason: "One or more documented legacy flat/onboarding reference queries failed; absence cannot be established." });
  }

  const identityProofPath = typeof profiles.users?.identityProofStoragePath === "string" ? profiles.users.identityProofStoragePath : null;
  if (profiles.users?.identityProofStoragePath != null && typeof profiles.users.identityProofStoragePath !== "string") unresolved.push({ check: "identityProofOwnership", reason: "Resident identity-proof storage path uses an unsupported value type." });
  if (identityProofPath) {
      eligiblePersonalRecords.push({ type: "identity_proof_upload", storagePath: identityProofPath, action: "delete_unless_legal_hold" });
    const communityId = profiles.users?.communityId;
    const expectedPath = `residentIdentityProofs/${communityId}/${uid}/`;
    if (typeof communityId !== "string" || !identityProofPath.startsWith(expectedPath) || identityProofPath.slice(expectedPath.length).includes("/")) {
      unresolved.push({ check: "identityProofOwnership", reason: "Identity-proof storage path does not prove this Resident UID and community." });
    } else {
      try {
        const reviewId = createHash("sha256").update(`${requestId}\n${uid}\n${communityId}\n${identityProofPath}`).digest("hex");
        const [reviewSnapshot, metadata] = await Promise.all([
          db.collection(COLLECTION).doc(requestId).collection("identityProofReviews").doc(reviewId).get(),
          bucket?.file ? bucket.file(identityProofPath).getMetadata().then(([value]) => value).catch((error) => ({ error })) : Promise.resolve(null),
        ]);
        const review = reviewSnapshot.data();
        const legalHold = request.legalHold === true || request.legalHoldStatus === "active" || review?.decision === "LEGAL_HOLD";
        if (legalHold) unresolved.push({ check: "identityProofLegalHold", reason: "Identity proof is under a documented legal hold." });
        else if (!bucket?.file) unresolved.push({ check: "identityProofStorage", reason: "Identity-proof Storage cannot be independently verified." });
        else if (!metadata || metadata.error) {
          const progress = (await db.collection(COLLECTION).doc(requestId).collection("processing").doc("identityProof").get().catch(() => null))?.data();
          const priorGeneration = progress?.requestId === requestId && progress?.uid === uid && progress?.communityId === communityId && progress?.storagePath === identityProofPath && progress?.status === "completed";
          if (!priorGeneration) unresolved.push({ check: "identityProofStorage", retryable: retryableError(metadata?.error), reason: "Identity-proof object cannot be verified against request-scoped cleanup evidence." });
        } else if (reviewSnapshot.exists && (review?.uid !== uid || review?.communityId !== communityId || review?.storagePath !== identityProofPath)) {
          unresolved.push({ check: "identityProofReview", reason: "Existing identity-proof disposition conflicts with the current owner or community." });
        }
      } catch (_) { unresolved.push({ check: "identityProofStorage", retryable: true, reason: "Identity-proof Storage could not be verified." }); }
    }
  }
  if (profiles.users) eligiblePersonalRecords.push({ type: "resident_profile", path: `users/${uid}`, action: "delete_after_dependencies_cleared" });
  if (profiles.admins) eligiblePersonalRecords.push({ type: "admin_profile", path: `admins/${uid}`, action: "delete_after_responsibility_reassignment" });
  if (profiles.securityStaff) eligiblePersonalRecords.push({ type: "security_profile", path: `securityStaff/${uid}`, action: "delete_after_assignment_reassignment" });

  // Query known financial identifiers; preserve matching records and never mutate them.
  const financial = [];
  const activeFinancial = [];
  for (const [collection, fields] of [["payments", ["userId"]], ["paymentProofsV2", ["residentId", "userId"]], ["paymentTransactions", ["residentId", "userId"]], ["paymentAllocations", ["residentId", "userId"]]]) {
    const rows = await queryReferences(collection, fields);
    for (const row of rows) {
      const reference = { collection, id: row.id, status: row.status ?? null, communityId: row.communityId ?? null };
      financial.push(reference);
      if (["pending", "processing", "submitted"].includes(String(row.status ?? "").toLowerCase())) activeFinancial.push(reference);
    }
  }
  if (financial.length) preserved.push({ type: "financial_records", count: financial.length, references: financial, disposition: "preserve payment amounts, transactions, receipts, reconciliation links and audit trail; residentId/userId links are used by existing statement, proof and ledger readers" });
  if (activeFinancial.length) {
    activeDependencies.push({ type: "active_financial_submissions", records: activeFinancial });
    unresolved.push({ check: "activeFinancialSubmissions", reason: "Pending financial submissions require resolution before account closure." });
  }
  const financialQueryFailed = unresolved.some((item) => item.check.startsWith("query:payments.") || item.check.startsWith("query:paymentProofsV2.") || item.check.startsWith("query:paymentTransactions.") || item.check.startsWith("query:paymentAllocations."));
  if (!financialQueryFailed) verifiedChecks.push("payments.userId and financial residentId/userId reference queries");
  if (!financial.length && !financialQueryFailed) verifiedAbsence.push({ type: "financial_records", scope: "supported payments, paymentProofsV2, paymentTransactions and paymentAllocations UID fields", result: "no matching records" });

  const billingAssessment = await assessResidentBillingObligations({
    db,
    uid,
    communityIds: new Set(communities),
    unresolved,
    verifiedChecks,
    verifiedAbsence,
  });

  // Ordinary findings never authorize handover. Recheck the verified snapshot
  // on every eligibility pass; changed or unknown evidence fails closed.
  const handoverRequired = request.financialReviewRequired === true || request.financialReviewStatus === "VERIFIED_HANDOVER";
  let handoverVerified = false;
  const handover = request.financialHandover;
  if (handoverRequired && request.financialReviewStatus === "VERIFIED_HANDOVER" && handover?.requestId === requestId &&
      handover.uid === uid && handover.communityId === request.communityId && handover.retainFinancialRecords === true &&
      typeof handover.reviewedBy === "string" && handover.reviewedAt) {
    try {
      const evidence = await financialHandoverEvidence({ db, requestId, uid, communityId: request.communityId });
      handoverVerified = evidence.digest === handover.digest;
    } catch (_) { /* Missing or changed financial evidence remains blocked. */ }
  }
  if (handoverRequired && !billingAssessment.verifiedZero) {
    unresolved.push({ check: "outstandingBillingObligations", reason: "Outstanding dues are positive or cannot be verified as zero." });
  }
  if (handoverRequired && billingAssessment.verifiedZero && !handoverVerified) {
    unresolved.push({ check: "financialHandover", reason: "Community Admin financial handover must be verified against the current records." });
  }
  if (handoverVerified) {
    verifiedChecks.push("Request-bound Community Admin handover; financial records and obligations retained unchanged");
  }

  const additionalReferenceCoverage = await assessAdditionalResidentReferences({
    db, bucket, uid, requestId, communityIds: new Set(communities), profiles, unresolved, verifiedChecks, verifiedAbsence, preserved,
  });

  const auditRows = await queryReferences("auditLogs", ["actorUid", "targetId"]);
  if (auditRows.length) preserved.push({ type: "audit_history", count: auditRows.length,
    records: auditRows.map(({ id, communityId, action, targetId, actorUid }) => ({ id, communityId: communityId ?? null, action: action ?? null, targetId: targetId ?? null, actorUid: actorUid ?? null })),
    disposition: "preserve immutable actor/target/action/timestamp/summary history; do not rewrite" });
  if (!unresolved.some((item) => item.check.startsWith("query:auditLogs."))) verifiedChecks.push("auditLogs actorUid/targetId queries");
  const auditQueryFailed = unresolved.some((item) => item.check.startsWith("query:auditLogs."));
  if (!auditRows.length && !auditQueryFailed) verifiedAbsence.push({ type: "audit_history", scope: "supported auditLogs actorUid/targetId fields", result: "no matching records" });
  const visitorDiscoveryFailed = unresolved.some((item) => item.check.startsWith("query:visitors.") || item.check.startsWith("visitorCredential:") || item.check.startsWith("query:visitorGateCredentialIndex."));
  const legacyVisitorLinks = visitors.some((visitor) => visitor.hostUserId !== uid && visitor.residentId === uid);
  if (visitorDiscoveryFailed || legacyVisitorLinks || indexesByOwner.some((index) => !visitors.some((visitor) => visitor.id === index.visitorId))) unresolved.push({ check: "credentialIndexCompleteness", reason: "Legacy or indirect visitor/index ownership is not completely verified; use hostUserId ownership on new indexes and resolve legacy links before closure." });
  return {
    requestId, uid, reviewerUid, reviewedAt: FieldValue.serverTimestamp(),
    requestStatus: request.status,
    profileDiscoveryComplete: unresolved.every((item) => !item.check.startsWith("profile:")),
    linkedProfiles: Object.fromEntries(Object.entries(profiles).map(([name, profile]) => [name, profile ? { role: profile.role ?? null, communityId: profile.communityId ?? null, authorizedCommunityIds: profile.authorizedCommunityIds ?? null, isActive: profile.isActive ?? null, approvalStatus: profile.approvalStatus ?? null } : null])),
    roles, communities,
    confirmedDependencies: [
      ...(roles.length > 1 ? ["multiple_role_profiles"] : []),
      ...(profiles.admins ? ["admin_responsibilities"] : []),
      ...(profiles.securityStaff ? ["security_assignments"] : []),
    ],
    coverage: { verifiedChecks, verifiedAbsence, legacyReferenceCoverage, billingObligations: billingAssessment, additionalResidentReferences: additionalReferenceCoverage, activeDependencies, preservedHistoricalReferences: preserved, unresolvedReferenceClasses: unresolved.map((item) => item.check) },
    retryableDiscoveryChecks: additionalReferenceCoverage.retryableChecks,
    visitorLifecycle,
    visitorCredentials: credentials,
    eligiblePersonalRecords,
    unresolvedChecks: unresolved,
    eligible: unresolved.length === 0 && roles.length === 1 && roles[0] === "users" && communities.length === 1 && communities[0] === profiles.users?.communityId,
    blockers: unresolved.map((item) => item.reason),
    deletionPerformed: false,
  };
}

// Existing eligibility callable remains a read-only, request-scoped assessment.
async function reviewAccountDeletionEligibilityForRequestCore({ db, bucket, auth, data }) {
  if (!auth?.uid) throw new HttpsError("unauthenticated", "Authentication is required.");
  const requestId = String(data?.requestId ?? "").trim();
  if (!requestId || Object.keys(data ?? {}).some((key) => key !== "requestId")) throw new HttpsError("invalid-argument", "Only a deletion requestId is accepted.");
  const requestRef = db.collection(COLLECTION).doc(requestId);
  const snapshot = await requestRef.get();
  if (!snapshot.exists) throw new HttpsError("not-found", "Deletion request was not found.");
  const request = snapshot.data();
  if (request.uid !== auth.uid) {
    if (request.communityScopeVerified !== true || typeof request.communityId !== "string" || !request.communityId) throw new HttpsError("permission-denied", "Request community is not verified.");
    await requireOperationalAdmin(db, auth, request.communityId);
  }
  return reviewAccountDeletionEligibilityCore({ db, bucket, data: { requestId } });
}

// Backend-only processing/retry path. The coordinator owns eligibility preflight,
// supported cleanup, durable reconciliation and all destructive-step ordering.
async function reviewAndFulfillAccountDeletionCore({ db, bucket, data, firebaseAuth = null }) {
  return coordinateAccountDeletionFulfillmentCore({ db, bucket, firebaseAuth, data });
}

// Explicit authenticated Community Admin action to queue a fresh trusted
// assessment after record-specific blockers have been resolved. This reuses
// the existing fulfillment coordinator; status reads remain read-only.
async function reassessAccountDeletionRequestCore({ db, bucket, firebaseAuth = null, auth, data, now = Date.now() }) {
  const requestId = String(data?.requestId ?? "").trim();
  if (!requestId || Object.keys(data ?? {}).some((key) => key !== "requestId")) throw new HttpsError("invalid-argument", "Only a deletion requestId is accepted.");
  const requestRef = db.collection(COLLECTION).doc(requestId);
  await db.runTransaction(async (tx) => {
    const snapshot = await tx.get(requestRef);
    const request = snapshot.data();
    if (!snapshot.exists || request?.requestId !== requestId || !hasResidentDeletionVerification(request,requestId) ||
        request.communityScopeVerified !== true || typeof request.communityId !== "string" || !request.communityId ||
        !request.uid || request.status === "completed") {
      throw new HttpsError("failed-precondition", "A verified, incomplete Resident deletion request is required.");
    }
    await requireOperationalAdmin(db, auth, request.communityId, tx);
    if (request.retry?.state === "running" && request.retry.leaseExpiresAt > now) {
      throw new HttpsError("failed-precondition", "A trusted reassessment is already running.");
    }
    tx.update(requestRef, { retry: initialRetry(now), updatedAt: FieldValue.serverTimestamp() });
  });
  return attemptAccountDeletionRequestCore({ db, bucket, firebaseAuth, requestId, now });
}

// Internal fulfillment primitive. It deletes only the current, community-scoped
// profile proof and honors an explicitly recorded legal hold.
async function cleanupApprovedResidentIdentityProofCore({ db, bucket, requestId, eligibilityReport }) {
  if (eligibilityReport?.eligible !== true || eligibilityReport?.deletionPerformed !== false || eligibilityReport?.requestId !== requestId) throw new HttpsError("failed-precondition", "Current account-deletion eligibility gates have not passed.");
  const requestRef = db.collection(COLLECTION).doc(requestId);
  const request = await requestRef.get();
  const uid = request.data()?.uid;
  if (request.data()?.sourceApp === ASSISTED_SOURCE && !hasResidentDeletionVerification(request.data(),requestId)) throw new HttpsError("failed-precondition", "Assisted identity and consent verification are required.");
  if (!request.exists || !uid || eligibilityReport.uid !== uid) throw new HttpsError("failed-precondition", "Deletion request identity could not be verified.");
  const profileRef = db.collection("users").doc(uid);
  const profileSnapshot = await profileRef.get();
  const profile = profileSnapshot.data();
  const path = profile?.identityProofStoragePath;
  const communityId = profile?.communityId;
  const prefix = `residentIdentityProofs/${communityId}/${uid}/`;
  if (!profileSnapshot.exists || profile?.uid !== uid || profile?.role !== "resident" || !communityId || !path?.startsWith(prefix) || path.slice(prefix.length).includes("/")) throw new HttpsError("failed-precondition", "Current Resident proof path is invalid.");
  const reviewId = createHash("sha256").update(`${requestId}\n${uid}\n${communityId}\n${path}`).digest("hex");
  const reviewRef = requestRef.collection("identityProofReviews").doc(reviewId);
  const reviewSnapshot = await reviewRef.get();
  const review = reviewSnapshot.data();
  if (request.data()?.legalHold === true || request.data()?.legalHoldStatus === "active" || review?.decision === "LEGAL_HOLD") throw new HttpsError("failed-precondition", "Identity proof is under a documented legal hold.");
  if (reviewSnapshot.exists && (review?.uid !== uid || review?.communityId !== communityId || review?.storagePath !== path)) throw new HttpsError("failed-precondition", "Identity-proof disposition belongs to a different owner or community.");
  const file = bucket.file(path);
  const progressRef = requestRef.collection("processing").doc("identityProof");
  const progress = await progressRef.get();
  if (progress.exists && progress.data()?.status === "completed" && progress.data()?.requestId === requestId && progress.data()?.uid === uid && progress.data()?.communityId === communityId && progress.data()?.storagePath === path) return { deleted: true, idempotent: true, deletionPerformed: false };
  const [metadata] = await file.getMetadata().catch((error) => {
    if (Number(error?.code) === 404) return [null];
    throw error;
  });
  if (!metadata) {
    if (progress.exists && progress.data()?.status === "deleting" && progress.data()?.uid === uid && progress.data()?.communityId === communityId && progress.data()?.requestId === requestId && progress.data()?.storagePath === path && progress.data()?.storageGeneration) {
      await progressRef.set({ status: "completed", verifiedAbsent: true, reconciled: true, completedAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp() }, { merge: true });
      return { deleted: true, idempotent: true, reconciled: true, deletionPerformed: false };
    }
    if (progress.exists && progress.data()?.status === "deleting") return { deleted: false, reconciliationRequired: true, reason: "Deletion intent exists but its request, UID, community or path binding is incomplete.", deletionPerformed: false };
    throw new HttpsError("failed-precondition", "Identity-proof object is missing before a deletion intent exists.");
  }
  const storageGeneration = String(metadata.generation ?? "");
  if (!storageGeneration) throw new HttpsError("failed-precondition", "Identity-proof object generation could not be verified.");
  await db.runTransaction(async (tx) => {
    const [freshRequest, freshProfile, freshReview] = await Promise.all([tx.get(requestRef), tx.get(profileRef), tx.get(reviewRef)]);
    if (!freshRequest.exists || freshRequest.data()?.uid !== uid || freshRequest.data()?.communityId !== communityId || freshRequest.data()?.legalHold === true || freshRequest.data()?.legalHoldStatus === "active" || !freshProfile.exists || freshProfile.data()?.identityProofStoragePath !== path || freshProfile.data()?.communityId !== communityId || freshReview.exists && (freshReview.data()?.decision === "LEGAL_HOLD" || freshReview.data()?.uid !== uid || freshReview.data()?.communityId !== communityId || freshReview.data()?.storagePath !== path)) throw new HttpsError("failed-precondition", "Identity-proof cleanup state changed during preflight.");
    tx.set(progressRef, { uid, communityId, requestId, status: "deleting", storagePath: path, storageGeneration, intentAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp() });
  });
  await file.delete({ ignoreNotFound: false, ifGenerationMatch: storageGeneration });
  await progressRef.set({ requestId, uid, communityId, status: "completed", verifiedAbsent: true, storagePath: path, storageGeneration, completedAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp() }, { merge: true });
  return { deleted: true, idempotent: false, deletionPerformed: false };
}

async function cleanupResidentNotificationsCore({ db, data }) {
  const requestId = String(data?.requestId ?? "").trim();
  if (!requestId || Object.keys(data ?? {}).some((key) => key !== "requestId")) throw new HttpsError("invalid-argument", "Only a deletion requestId is accepted.");
  const requestRef = db.collection(COLLECTION).doc(requestId);
  const progressRef = requestRef.collection("processing").doc("notifications");
  const request = await requestRef.get();
  const owner = request.data();
  const uid = owner?.uid;
  const communityId = owner?.communityId;
  const blocked = (reason) => ({ requestId, complete: false, blockers: [{ reason }] });
  if (!request.exists || !residentDeletionSourceAllowed(owner, requestId) || owner?.communityScopeVerified !== true || typeof uid !== "string" || typeof communityId !== "string" || !communityId) return blocked("Verified community-scoped request is required for notification cleanup.");
  const profileRef = db.collection("users").doc(uid);
  const profile = await profileRef.get();
  if (!profile.exists || profile.data()?.uid !== uid || profile.data()?.role !== "resident" || profile.data()?.communityId !== communityId) return blocked("Canonical Resident ownership changed before notification cleanup.");
  const rootQuery = db.collection("notifications").where("recipientId", "==", uid).limit(MAX_REFERENCE_SCAN);
  const receiptsQuery = db.collectionGroup("readBy").where("userId", "==", uid).limit(MAX_REFERENCE_SCAN);
  const [roots, receipts] = await Promise.all([rootQuery.get(), receiptsQuery.get()]);
  if (roots.docs.length >= MAX_REFERENCE_SCAN || receipts.docs.length >= MAX_REFERENCE_SCAN) return blocked("Notification discovery exceeded its safe bound.");
  const noticeRefs = receipts.docs.map((doc) => doc.ref.parent.parent).filter(Boolean);
  const notices = await Promise.all(noticeRefs.map((ref) => ref.get()));
  const noticeByPath = new Map(notices.map((snapshot) => [snapshot.ref.path, snapshot]));
  const validRoot = (doc) => doc.data()?.recipientId === uid && doc.data()?.communityId === communityId &&
    (doc.data()?.recipientRole == null || doc.data()?.recipientRole === "resident") && (doc.data()?.appId == null || doc.data()?.appId === "resident");
  const validReceipt = (doc) => {
    const parts = doc.ref.path.split("/");
    const notice = noticeByPath.get(parts.slice(0, 2).join("/"));
    return parts.length === 4 && parts[0] === "notices" && parts[2] === "readBy" && doc.data()?.userId === uid && notice?.exists && notice.data()?.communityId === communityId;
  };
  if (roots.docs.some((doc) => !validRoot(doc)) || receipts.docs.some((doc) => !validReceipt(doc))) return blocked("Notification ownership or community scope is ambiguous.");
  const fingerprint = (snapshots) => snapshots.flatMap((snapshot) => snapshot.docs.map((doc) => [doc.ref.path, createHash("sha256").update(JSON.stringify(doc.data())).digest("hex")])).sort(([a], [b]) => a.localeCompare(b));
  const expectedRoots = fingerprint([roots]);
  const expectedReceipts = fingerprint([receipts]);
  const uniqueNoticeRefs = [...new Map(noticeRefs.map((ref) => [ref.path, ref])).values()];
  return db.runTransaction(async (tx) => {
    const [freshRequest, freshProfile, freshRoots, freshReceipts, prior] = await Promise.all([
      tx.get(requestRef), tx.get(profileRef), tx.get(rootQuery), tx.get(receiptsQuery), tx.get(progressRef),
    ]);
    if (!freshRequest.exists || freshRequest.data()?.uid !== uid || freshRequest.data()?.communityId !== communityId || !freshProfile.exists || freshProfile.data()?.role !== "resident" || freshProfile.data()?.communityId !== communityId) return blocked("Request or Resident identity changed during notification cleanup.");
    if (JSON.stringify(fingerprint([freshRoots])) !== JSON.stringify(expectedRoots) || JSON.stringify(fingerprint([freshReceipts])) !== JSON.stringify(expectedReceipts)) return blocked("Notification records changed after preflight; reassessment is required.");
    const evidence = prior.data();
    if (prior.exists && (evidence?.requestId !== requestId || evidence?.uid !== uid || evidence?.communityId !== communityId)) return blocked("Notification cleanup evidence belongs to a different request.");
    const freshNotices = await Promise.all(uniqueNoticeRefs.map((ref) => tx.get(ref)));
    if (freshNotices.some((notice) => !notice.exists || notice.data()?.communityId !== communityId)) return blocked("Notice community scope changed during receipt cleanup.");
    if (!freshRoots.size && !freshReceipts.size && prior.exists && evidence.status === "completed") return { requestId, complete: true, idempotent: true };
    for (const doc of freshRoots.docs) tx.delete(doc.ref);
    for (const doc of freshReceipts.docs) tx.delete(doc.ref);
    tx.set(progressRef, { requestId, uid, communityId, status: "completed", complete: true,
      removedCount: freshRoots.size + freshReceipts.size, completedAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp() });
    return { requestId, complete: true, removedCount: freshRoots.size + freshReceipts.size };
  }).catch(() => blocked("Notification cleanup could not be independently verified."));
}

async function cleanupResidentSosLocationsCore({ db, data }) {
  const requestId = String(data?.requestId ?? "").trim();
  if (!requestId || Object.keys(data ?? {}).some((key) => key !== "requestId")) throw new HttpsError("invalid-argument", "Only a deletion requestId is accepted.");
  const requestRef = db.collection(COLLECTION).doc(requestId);
  const progressRef = requestRef.collection("processing").doc("sosLocations");
  const request = await requestRef.get();
  const owner = request.data();
  const uid = owner?.uid;
  const communityId = owner?.communityId;
  const blocked = (reason) => ({ requestId, complete: false, blockers: [{ reason }] });
  if (!request.exists || !residentDeletionSourceAllowed(owner, requestId) || owner?.communityScopeVerified !== true || typeof uid !== "string" || typeof communityId !== "string" || !communityId) return blocked("Verified community-scoped request is required for SOS location cleanup.");
  const active = await db.collection("sosActive").doc(uid).get();
  if (active.exists) return blocked("An active emergency must be resolved before account closure.");
  const query = db.collection("sosAlerts").where("residentUid", "==", uid).limit(MAX_REFERENCE_SCAN);
  const alerts = await query.get();
  if (alerts.docs.length >= MAX_REFERENCE_SCAN || alerts.docs.some((doc) => doc.data()?.communityId !== communityId || ["triggered", "acknowledged", "responding", "in_progress"].includes(String(doc.data()?.status ?? "").toLowerCase()))) return blocked("SOS alert ownership is ambiguous or an emergency is still active.");
  const fingerprint = (docs) => docs.map((doc) => [doc.ref.path, createHash("sha256").update(JSON.stringify(doc.data())).digest("hex")]).sort(([a], [b]) => a.localeCompare(b));
  const expected = fingerprint(alerts.docs);
  return db.runTransaction(async (tx) => {
    const [freshRequest, freshProfile, freshActive, freshAlerts, prior] = await Promise.all([
      tx.get(requestRef), tx.get(db.collection("users").doc(uid)), tx.get(db.collection("sosActive").doc(uid)), tx.get(query), tx.get(progressRef),
    ]);
    if (!freshRequest.exists || freshRequest.data()?.uid !== uid || freshRequest.data()?.communityId !== communityId || !freshProfile.exists || freshProfile.data()?.role !== "resident" || freshProfile.data()?.communityId !== communityId || freshActive.exists) return blocked("Request, Resident ownership, or emergency state changed during SOS cleanup.");
    if (JSON.stringify(fingerprint(freshAlerts.docs)) !== JSON.stringify(expected)) return blocked("SOS history changed after preflight; reassessment is required.");
    const evidence = prior.data();
    if (prior.exists && (evidence?.requestId !== requestId || evidence?.uid !== uid || evidence?.communityId !== communityId)) return blocked("SOS cleanup evidence belongs to a different request.");
    if (!freshAlerts.docs.some((doc) => Object.hasOwn(doc.data(), "location")) && prior.exists && evidence.status === "completed") return { requestId, complete: true, idempotent: true };
    for (const doc of freshAlerts.docs) {
      if (Object.hasOwn(doc.data(), "location")) tx.update(doc.ref, { location: FieldValue.delete(), locationAvailable: false, locationRemovedAt: FieldValue.serverTimestamp() });
    }
    tx.set(progressRef, { requestId, uid, communityId, status: "completed", complete: true, cleanedAlertIds: freshAlerts.docs.map((doc) => doc.id), completedAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp() });
    return { requestId, complete: true, removedCount: freshAlerts.docs.length };
  }).catch(() => blocked("SOS location cleanup could not be independently verified."));
}

async function cleanupResidentProfileImagesCore({ db, bucket, data }) {
  const requestId = String(data?.requestId ?? "").trim();
  if (!requestId || Object.keys(data ?? {}).some((key) => key !== "requestId")) throw new HttpsError("invalid-argument", "Only a deletion requestId is accepted.");
  const requestRef = db.collection(COLLECTION).doc(requestId);
  const progressRef = requestRef.collection("processing").doc("profileImages");
  const request = await requestRef.get();
  const owner = request.data();
  const uid = owner?.uid;
  const communityId = owner?.communityId;
  const blocked = (reason) => ({ requestId, complete: false, blockers: [{ reason }] });
  if (!request.exists || !residentDeletionSourceAllowed(owner, requestId) || owner?.communityScopeVerified !== true || typeof uid !== "string" || typeof communityId !== "string" || !communityId || !bucket?.getFiles || !bucket?.file) return blocked("Verified request and Storage access are required for profile-image cleanup.");
  const profileRef = db.collection("users").doc(uid);
  const assetQuery = db.collection("storageImageUploads").where("ownerId", "==", uid).limit(MAX_REFERENCE_SCAN);
  const draftQuery = db.collection("residentImageDrafts").where("ownerId", "==", uid).limit(MAX_REFERENCE_SCAN);
  const commitQuery = db.collection("residentImageCommits").where("ownerId", "==", uid).limit(MAX_REFERENCE_SCAN);
  const [profile, assets, drafts, commits] = await Promise.all([profileRef.get(), assetQuery.get(), draftQuery.get(), commitQuery.get()]);
  if (!profile.exists || profile.data()?.uid !== uid || profile.data()?.role !== "resident" || profile.data()?.communityId !== communityId) return blocked("Canonical Resident identity changed before profile-image cleanup.");
  const ownedProfileAssets = assets.docs.filter((doc) => doc.data()?.feature === "profile");
  const personalDrafts = drafts.docs.filter((doc) => doc.data()?.feature === "profile");
  const personalCommits = commits.docs.filter((doc) => doc.data()?.feature === "profile");
  const exactScope = [...ownedProfileAssets, ...personalDrafts, ...personalCommits].every((doc) =>
    doc.data()?.ownerId === uid && doc.data()?.communityId === communityId &&
    (doc.data()?.feature !== "profile" || doc.data()?.resourceId == null || doc.data()?.resourceId === uid));
  if (!exactScope || [assets, drafts, commits].some((result) => result.docs.length >= MAX_REFERENCE_SCAN)) return blocked("Profile-image ownership or community scope is ambiguous.");
  const managedAssets = profile.data()?.managedImageAssets;
  if (managedAssets != null && (!Array.isArray(managedAssets) || managedAssets.some((asset) => !ownedProfileAssets.some((doc) => doc.id === asset?.assetId)))) return blocked("Managed profile-image attachment cannot be matched to its owner record.");
  const fingerprint = (docs) => docs.map((doc) => [doc.ref.path, createHash("sha256").update(JSON.stringify(doc.data())).digest("hex")]).sort(([a], [b]) => a.localeCompare(b));
  const expected = [fingerprint(ownedProfileAssets), fingerprint(personalDrafts), fingerprint(personalCommits)];
  const transactionResult = await db.runTransaction(async (tx) => {
    const [freshRequest, freshProfile, freshAssets, freshDrafts, freshCommits, prior] = await Promise.all([
      tx.get(requestRef), tx.get(profileRef), tx.get(assetQuery), tx.get(draftQuery), tx.get(commitQuery), tx.get(progressRef),
    ]);
    const currentProfile = freshProfile.data();
    if (!freshRequest.exists || freshRequest.data()?.uid !== uid || freshRequest.data()?.communityId !== communityId || !freshProfile.exists || currentProfile?.uid !== uid || currentProfile?.role !== "resident" || currentProfile?.communityId !== communityId) return blocked("Request or Resident identity changed during image cleanup.");
    const freshSelected = [freshAssets, freshDrafts, freshCommits].map((result, index) => result.docs.filter((doc) => doc.data()?.feature === "profile"));
    if (freshSelected.some((docs, index) => JSON.stringify(fingerprint(docs)) !== JSON.stringify(expected[index]))) return blocked("Profile-image records changed after preflight; reassessment is required.");
    const evidence = prior.data();
    if (prior.exists && (evidence?.requestId !== requestId || evidence?.uid !== uid || evidence?.communityId !== communityId)) return blocked("Profile-image cleanup evidence belongs to a different request.");
    for (const doc of freshSelected[0]) tx.update(doc.ref, { state: "retired", attachedTo: FieldValue.delete(), retiredAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp() });
    for (const doc of [...freshSelected[1], ...freshSelected[2]]) tx.delete(doc.ref);
    tx.update(profileRef, {
      managedImageAssets: [],
      profileImage: FieldValue.delete(), profileImageUrl: FieldValue.delete(), profileImageUpdatedAt: FieldValue.delete(),
      photoURL: FieldValue.delete(), photoUrl: FieldValue.delete(),
      imageRevision: Number.isSafeInteger(currentProfile.imageRevision) ? currentProfile.imageRevision + 1 : 1,
      updatedAt: FieldValue.serverTimestamp(),
    });
    tx.set(progressRef, { requestId, uid, communityId, status: "in_progress", assetIds: freshSelected[0].map((doc) => doc.id), intentAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp() });
    return { selectedAssets: freshSelected[0].map((doc) => ({ id: doc.id, ref: doc.ref })) };
  });
  if (transactionResult.complete === false) return transactionResult;
  for (const asset of transactionResult.selectedAssets) {
    let collected = false;
    try { collected = await collectResidentAsset({ db, bucket, assetId: asset.id }); } catch (_) { return blocked("A profile-image object could not be safely collected."); }
    if (!collected) return blocked("A profile-image object remains attached or is not ready for verified cleanup.");
    const latest = await asset.ref.get();
    if (latest.exists && (latest.data()?.ownerId !== uid || latest.data()?.communityId !== communityId || latest.data()?.feature !== "profile" || latest.data()?.state !== "deleted")) return blocked("Profile-image asset ownership changed after collection.");
    if (latest.exists) await asset.ref.delete();
  }
  const remaining = [];
  for (const prefix of [`resident_images/${communityId}/${uid}/profile/`, `private_images/${communityId}/${uid}/profile/`]) {
    const [files] = await bucket.getFiles({ prefix, maxResults: 201, autoPaginate: false });
    if (files.length > 200) return blocked("Profile-image Storage prefix exceeded the safe cleanup bound.");
    for (const file of files) {
      const [metadata] = await file.getMetadata();
      const binding = metadata.metadata ?? {};
      if (binding.ownerId !== uid || binding.communityId !== communityId || binding.feature !== "profile") return blocked("A remaining profile Storage object has ambiguous ownership.");
      remaining.push({ file, generation: String(metadata.generation ?? "") });
    }
  }
  for (const item of remaining) {
    if (!item.generation) return blocked("A profile Storage generation could not be verified.");
    await item.file.delete({ ignoreNotFound: false, ifGenerationMatch: item.generation });
  }
  await progressRef.set({ requestId, uid, communityId, status: "completed", complete: true,
    cleanedAssetIds: transactionResult.selectedAssets.map((asset) => asset.id), completedAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp() }, { merge: true });
  return { requestId, complete: true, cleanedAssetCount: transactionResult.selectedAssets.length };
}

// Internal only. The transaction removes verified installation credentials and
// records their request-bound disposition atomically; no FCM token is retained.
async function cleanupResidentNotificationDevicesCore({ db, data }) {
  const requestId = String(data?.requestId ?? "").trim();
  if (!requestId || Object.keys(data ?? {}).some((key) => key !== "requestId")) throw new HttpsError("invalid-argument", "Only a deletion requestId is accepted.");
  const requestRef = db.collection(COLLECTION).doc(requestId);
  const progressRef = requestRef.collection("processing").doc("notificationDevices");
  const blocked = (reason, retryable = false) => ({ requestId, complete: false, retryable, blockers: [{ reason }] });
  const request = await requestRef.get().catch(() => null);
  const owner = request?.data();
  const uid = owner?.uid;
  const communityId = owner?.communityId;
  const verifiedRequest = (value) => value?.requestId === requestId && value.uid === uid && residentDeletionSourceAllowed(value, requestId) && value.communityScopeVerified === true &&
    value.communityId === communityId && visitorTimestampMillis(value.verificationCompletedAt) > 0 &&
    visitorTimestampMillis(value.verificationCompletedAt) <= Date.now();
  if (!request?.exists || typeof uid !== "string" || !uid || typeof communityId !== "string" || !communityId || !verifiedRequest(owner)) return blocked("A verified, community-scoped Resident deletion request is required for device cleanup.");
  const profileRef = db.collection("users").doc(uid);
  const devicesQuery = db.collection("notificationDevices").where("uid", "==", uid).limit(MAX_REFERENCE_SCAN);
  const preflight = await Promise.all([profileRef.get(), devicesQuery.get()]).catch(() => null);
  if (!preflight) return blocked("Device preflight reads failed; ownership cannot be independently verified.", true);
  const [profile, devices] = preflight;
  const validProfile = (snapshot) => snapshot.exists && snapshot.data()?.uid === uid && snapshot.data()?.role === "resident" && snapshot.data()?.communityId === communityId;
  if (!validProfile(profile)) return blocked("Resident device ownership cannot be verified from the canonical profile.");
  if (devices.docs.length >= MAX_REFERENCE_SCAN - 1 || devices.docs.some((doc) => !deletionDeviceMatches(doc.data(), doc.id, uid, communityId))) return blocked("Device discovery is incomplete or a device has ambiguous ownership, app identity, or community scope.");
  const expected = new Map(devices.docs.map((doc) => [doc.id, deletionDeviceFingerprint(doc.data())]));
  return db.runTransaction(async (tx) => {
    const [freshRequest, freshProfile, freshDevices, prior] = await Promise.all([
      tx.get(requestRef), tx.get(profileRef), tx.get(devicesQuery), tx.get(progressRef),
    ]);
    if (!freshRequest.exists || !verifiedRequest(freshRequest.data()) || !validProfile(freshProfile)) return blocked("Request or Resident identity changed before device cleanup.");
    const evidence = prior.data();
    if (prior.exists && (evidence?.requestId !== requestId || evidence?.uid !== uid || evidence?.communityId !== communityId)) return blocked("Device cleanup evidence belongs to a different request or community.");
    if (freshDevices.docs.length !== expected.size || freshDevices.docs.some((doc) => !deletionDeviceMatches(doc.data(), doc.id, uid, communityId) || expected.get(doc.id) !== deletionDeviceFingerprint(doc.data()))) return blocked("Device registrations changed after preflight; reassessment is required.");
    if (freshDevices.empty && prior.exists && evidence.status === "completed") return { requestId, uid, complete: true, blockers: [], idempotent: true, removedDeviceIds: evidence.removedDeviceIds ?? [] };
    for (const doc of freshDevices.docs) tx.delete(doc.ref);
    const previousIds = prior.exists && evidence.complete === true ? evidence.removedDeviceIds ?? [] : [];
    const removedDeviceIds = [...new Set([...previousIds, ...freshDevices.docs.map((doc) => doc.id)])];
    tx.set(progressRef, {
      requestId, uid, communityId, status: "completed", complete: true, removedDeviceIds,
      dispositions: [...(evidence?.dispositions ?? []), ...freshDevices.docs.map((doc) => ({ deviceId: doc.id, fingerprint: expected.get(doc.id) }))],
      completedAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp(),
    });
    return { requestId, uid, complete: true, blockers: [], removedDeviceIds, idempotent: false };
  }).catch(() => blocked("Device cleanup could not be independently verified; retry the existing request.", true));
}

// Internal fulfillment coordinator. Only trusted backend code can invoke it;
// Resident submission supplies the persisted request ID, never deletion rights.
async function coordinateAccountDeletionFulfillmentCore({ db, firebaseAuth = null, bucket, data }) {
  const requestId = String(data?.requestId ?? "").trim();
  if (!requestId || Object.keys(data ?? {}).some((key) => key !== "requestId")) throw new HttpsError("invalid-argument", "Only a deletion requestId is accepted.");
  const requestRef = db.collection(COLLECTION).doc(requestId);
  const authService = () => firebaseAuth ?? getAuth();
  const processing = requestRef.collection("processing");
  const requestSnapshot = await requestRef.get();
  const uid = requestSnapshot.data()?.uid;
  if (!requestSnapshot.exists || typeof uid !== "string" || !uid) throw new HttpsError("failed-precondition", "Deletion request identity could not be verified.");
  if (!hasResidentDeletionVerification(requestSnapshot.data(),requestId)) return {
    requestId, uid, status: "blocked", completed: false, deletionPerformed: false, executedSteps: [],
    blockers: ["Resident ownership and deletion consent verification are required before fulfillment."],
    unresolvedChecks: [{check: "requestVerification",reason: "Resident ownership and deletion consent verification are required before fulfillment."}],
  };
  const readStep = async (name) => (await processing.doc(name).get());
  const writeStep = async (name, value) => processing.doc(name).set({ requestId, uid, updatedAt: FieldValue.serverTimestamp(), ...value }, { merge: true });
  const clearProfileEvidence = async () => processing.doc("residentProfile").update({ profileEvidence: FieldValue.delete(), updatedAt: FieldValue.serverTimestamp() });
  const setRequestStatus = async (status, extra = {}) => requestRef.set({ status, updatedAt: FieldValue.serverTimestamp(), ...extra }, { merge: true });
  const reportEligibility = (profileOverride = null) => reviewAccountDeletionEligibilityCore({ db, bucket, data: { requestId }, profileOverride });
  const reconciliation = async (step, reason, retryable = false) => {
    await writeStep(step, { status: "reconciliation_required", reason });
    await setRequestStatus("reconciliation_required", { reconciliationStep: step, reconciliationReason: reason });
    return { requestId, uid, status: "reconciliation_required", blockers: [reason], retryable, executedSteps: [], completed: false, deletionPerformed: false };
  };

  // A retry after the final Auth call must reconcile from operation evidence,
  // since the deleted profile can no longer pass ordinary eligibility queries.
  const [profileProgressAtStart, authProgressAtStart, existingProfile] = await Promise.all([
    readStep("residentProfile"), readStep("firebaseAuth"), db.collection("users").doc(uid).get(),
  ]);
  const profileIntent = profileProgressAtStart.exists && ["deleting", "completed"].includes(profileProgressAtStart.data()?.status) && profileProgressAtStart.data()?.uid === uid;
  const authIntent = authProgressAtStart.exists && authProgressAtStart.data()?.operationStarted === true && ["deleting", "reconciliation_required", "completed"].includes(authProgressAtStart.data()?.status) && authProgressAtStart.data()?.uid === uid;
  const profileOverride = !existingProfile.exists && profileIntent ? profileProgressAtStart.data()?.profileEvidence ?? null : null;
  if (!existingProfile.exists && profileIntent && authIntent) {
    let authAbsent = false;
    try { await authService().getUser(uid); } catch (error) {
      if (error?.code !== "auth/user-not-found") throw error;
      authAbsent = true;
    }
    if (authAbsent) {
      await writeStep("residentProfile", { status: "completed", completedAt: FieldValue.serverTimestamp(), verifiedAbsent: true, reconciled: true });
      await writeStep("firebaseAuth", { status: "completed", completedAt: FieldValue.serverTimestamp(), verifiedAbsent: true, reconciled: true });
      const final = await requestRef.get();
      if (final.exists && final.data()?.uid === uid) {
        await clearProfileEvidence();
        await setRequestStatus("completed", { reviewStatus: "completed", completedAt: FieldValue.serverTimestamp(), completionVerified: true, authUidDeleted: uid, residentProfilePath: `users/${uid}`, reconciled: true });
        return { requestId, uid, status: "completed", blockers: [], executedSteps: ["residentProfile", "firebaseAuth"], completed: true, deletionPerformed: true, reconciled: true };
      }
      return reconciliation("completion", "Deletion request disappeared before completion could be recorded.");
    }
    if (authProgressAtStart.data()?.status === "completed") return reconciliation("firebaseAuth", "Auth progress says completed, but the Firebase Auth user still exists.");
  }
  if (requestSnapshot.data()?.status === "completed" && profileIntent && authIntent && !existingProfile.exists) {
    try { await authService().getUser(uid); return reconciliation("completion", "Completed request has a Firebase Auth user that still exists."); }
    catch (error) {
      if (error?.code === "auth/user-not-found") return { requestId, uid, status: "completed", blockers: [], executedSteps: [], completed: true, deletionPerformed: true, idempotent: true };
      return reconciliation("completion", "Completed request Auth state could not be verified.", retryableError(error));
    }
  }

  let report = await reportEligibility(profileOverride);
  if (report.uid !== uid) throw new HttpsError("failed-precondition", "Eligibility identity does not match the server-created request.");
  const safeCleanupChecks = new Set(["futureVisitors", "activeCredential", "unitMemberships", "activeBookings"]);
  const bookingCleanupEligible = report.coverage?.additionalResidentReferences?.bookings?.cleanupEligible === true;
  const deviceCleanupEligible = report.coverage?.additionalResidentReferences?.notificationDevices?.cleanupEligible === true;
  const notificationCleanupEligible = report.coverage?.additionalResidentReferences?.notifications?.cleanupEligible === true;
  const sosLocationCleanupEligible = report.coverage?.additionalResidentReferences?.sos?.cleanupEligible === true;
  const profileImageCleanupEligible = report.coverage?.additionalResidentReferences?.imagesAndStorage?.cleanupEligible === true;
  const unexpected = report.unresolvedChecks.filter((item) => !safeCleanupChecks.has(item.check) && !(item.check === "reference:bookings" && bookingCleanupEligible) && !(item.check === "reference:notificationDevices" && deviceCleanupEligible) && !(item.check === "reference:notifications" && notificationCleanupEligible) && !(item.check === "reference:sos" && sosLocationCleanupEligible) && !(item.check === "reference:imagesAndStorage" && profileImageCleanupEligible));
  if (unexpected.length) return { requestId, uid, status: "blocked", blockers: unexpected.map((item) => item.reason), unresolvedChecks: unexpected,
    retryableDiscoveryChecks: report.retryableDiscoveryChecks, executedSteps: [], completed: false, deletionPerformed: false };

  const executedSteps = [];
  if (report.unresolvedChecks.some((item) => ["futureVisitors", "activeCredential"].includes(item.check))) {
    await writeStep("visitorCleanup", { status: "in_progress", intentAt: FieldValue.serverTimestamp() });
    const result = await revokeResidentVisitorCredentialsCore({ db, data: { requestId } });
    if (!result.complete) return reconciliation("visitorCleanup", result.blockers.map((item) => item.reason).join("; "));
    await writeStep("visitorCleanup", { status: "completed", completedAt: FieldValue.serverTimestamp(), revokedCount: result.revoked.length, cancelledVisitorIds: result.cancelledVisitorIds });
    executedSteps.push("visitorCleanup");
  } else {
    const prior = await readStep("visitorCleanup");
    if (!prior.exists || prior.data()?.status !== "completed") await writeStep("visitorCleanup", { status: "skipped_verified_absent", verifiedAt: FieldValue.serverTimestamp() });
  }
  if (report.unresolvedChecks.some((item) => ["unitMemberships", "activeBookings", "reference:bookings"].includes(item.check))) {
    await writeStep("membershipAndBookingCleanup", { status: "in_progress", intentAt: FieldValue.serverTimestamp() });
    const result = await cleanupResidentMembershipsAndBookingsCore({ db, data: { requestId } });
    if (!result.complete) return reconciliation("membershipAndBookingCleanup", result.blockers.map((item) => item.reason).join("; "),
      result.blockers.every((item) => item.type === "read" || item.reason === "Booking reference query failed."));
    await writeStep("membershipAndBookingCleanup", { status: "completed", completedAt: FieldValue.serverTimestamp(), memberships: result.cleanedMemberships, cancelledBookings: result.canceledBookings, verifiedBookingReferences: result.verifiedBookingReferences });
    executedSteps.push("membershipAndBookingCleanup");
  } else {
    const prior = await readStep("membershipAndBookingCleanup");
    if (!prior.exists || prior.data()?.status !== "completed") await writeStep("membershipAndBookingCleanup", { status: "skipped_verified_absent", verifiedAt: FieldValue.serverTimestamp() });
  }

  const deviceProgress = await readStep("notificationDevices");
  if (report.unresolvedChecks.some((item) => item.check === "reference:notificationDevices") ||
      existingProfile.exists && deviceProgress.data()?.status === "reconciliation_required") {
    const result = await cleanupResidentNotificationDevicesCore({ db, data: { requestId } });
    if (!result.complete) return reconciliation("notificationDevices", result.blockers.map((item) => item.reason).join("; "), result.retryable === true);
    executedSteps.push("notificationDevices");
  }

  const notificationProgress = await readStep("notifications");
  if (report.unresolvedChecks.some((item) => item.check === "reference:notifications") ||
      existingProfile.exists && notificationProgress.data()?.status === "reconciliation_required") {
    const result = await cleanupResidentNotificationsCore({ db, data: { requestId } });
    if (!result.complete) return reconciliation("notifications", result.blockers.map((item) => item.reason).join("; "));
    executedSteps.push("notifications");
  }

  const sosProgress = await readStep("sosLocations");
  if (report.unresolvedChecks.some((item) => item.check === "reference:sos") ||
      existingProfile.exists && sosProgress.data()?.status === "reconciliation_required") {
    const result = await cleanupResidentSosLocationsCore({ db, data: { requestId } });
    if (!result.complete) return reconciliation("sosLocations", result.blockers.map((item) => item.reason).join("; "));
    executedSteps.push("sosLocations");
  }

  const imageProgress = await readStep("profileImages");
  if (report.unresolvedChecks.some((item) => item.check === "reference:imagesAndStorage") ||
      existingProfile.exists && imageProgress.data()?.status === "reconciliation_required") {
    const result = await cleanupResidentProfileImagesCore({ db, bucket, data: { requestId } });
    if (!result.complete) return reconciliation("profileImages", result.blockers.map((item) => item.reason).join("; "));
    executedSteps.push("profileImages");
  }

  report = await reportEligibility(profileOverride);
  if (report.eligible !== true || report.deletionPerformed !== false || report.unresolvedChecks?.length || report.blockers?.length) {
    await setRequestStatus("eligibility_blocked", { lastEligibilityBlockers: report.blockers ?? [] });
    return { requestId, uid, status: "blocked", blockers: report.blockers ?? ["Eligibility revalidation is incomplete."], unresolvedChecks: report.unresolvedChecks ?? [],
      retryableDiscoveryChecks: report.retryableDiscoveryChecks, executedSteps, completed: false, deletionPerformed: false };
  }
  await setRequestStatus("deletion_in_progress", { fulfillmentStartedAt: FieldValue.serverTimestamp(), eligibilityVerifiedAt: FieldValue.serverTimestamp() });

  if (report.eligiblePersonalRecords.some((item) => item.type === "identity_proof_upload")) {
    const proofResult = await cleanupApprovedResidentIdentityProofCore({ db, bucket, requestId, eligibilityReport: report });
    if (proofResult.reconciliationRequired || proofResult.deleted !== true) return reconciliation("identityProof", proofResult.reason ?? "Identity-proof deletion could not be independently verified.");
    executedSteps.push("identityProof");
  } else {
    await writeStep("identityProof", { status: "skipped_verified_absent", verifiedAt: FieldValue.serverTimestamp() });
  }

  const profileRef = db.collection("users").doc(uid);
  const priorProfileStep = await readStep("residentProfile");
  let profileSnapshot = await profileRef.get();
  if (profileSnapshot.exists) {
    const profile = profileSnapshot.data();
    if (profile?.uid !== uid || profile?.role !== "resident" || profile?.communityId !== report.linkedProfiles.users?.communityId) return reconciliation("residentProfile", "Resident profile identity changed after eligibility verification.");
    const latest = await reportEligibility();
    if (latest.eligible !== true || latest.uid !== uid) return reconciliation("residentProfile", `Eligibility changed immediately before Resident profile removal: ${(latest.blockers ?? []).join("; ") || "identity revalidation failed"}.`,
      latest.uid === uid && retryableResult({ ...latest, status: "blocked" }));
    const profileEvidence = { uid, role: profile.role, communityId: profile.communityId, flatId: profile.flatId ?? null, residentId: profile.residentId ?? null };
    await writeStep("residentProfile", { status: "deleting", communityId: profile.communityId, profilePath: profileRef.path, profileEvidence, intentAt: FieldValue.serverTimestamp() });
    await profileRef.delete();
    profileSnapshot = await profileRef.get();
    if (profileSnapshot.exists) return reconciliation("residentProfile", "Resident profile still exists after the deletion operation.");
    await writeStep("residentProfile", { status: "completed", completedAt: FieldValue.serverTimestamp(), verifiedAbsent: true });
    executedSteps.push("residentProfile");
  } else if (priorProfileStep.exists && priorProfileStep.data()?.status === "deleting" && priorProfileStep.data()?.uid === uid && priorProfileStep.data()?.communityId === report.linkedProfiles.users?.communityId) {
    await writeStep("residentProfile", { status: "completed", completedAt: FieldValue.serverTimestamp(), verifiedAbsent: true, reconciled: true });
  } else if (!(priorProfileStep.exists && priorProfileStep.data()?.status === "completed" && priorProfileStep.data()?.uid === uid)) {
    return reconciliation("residentProfile", "Resident profile is absent without matching durable deletion intent.");
  }

  const profileEvidenceForAuth = (await readStep("residentProfile")).data()?.profileEvidence;
  const authPreflight = await reportEligibility(profileEvidenceForAuth);
  if (authPreflight.eligible !== true || authPreflight.uid !== uid || authPreflight.unresolvedChecks?.length) {
    return reconciliation("firebaseAuth", `Eligibility changed immediately before Firebase Auth deletion: ${(authPreflight.blockers ?? []).join("; ") || "identity revalidation failed"}.`,
      authPreflight.uid === uid && retryableResult({ ...authPreflight, status: "blocked" }));
  }

  const priorAuthStep = await readStep("firebaseAuth");
  if (priorAuthStep.exists && priorAuthStep.data()?.status === "completed" && priorAuthStep.data()?.uid === uid) {
    return { requestId, uid, status: requestSnapshot.data()?.status === "completed" ? "completed" : "reconciliation_required", blockers: [], executedSteps, completed: requestSnapshot.data()?.status === "completed", deletionPerformed: false };
  }
  try {
    await authService().getUser(uid);
  } catch (error) {
    if (error?.code !== "auth/user-not-found") return reconciliation("firebaseAuth", `Firebase Auth account could not be read before deletion (${error?.code ?? "unknown error"}).`, retryableError(error));
    if (!(priorAuthStep.exists && priorAuthStep.data()?.operationStarted === true && ["deleting", "reconciliation_required", "completed"].includes(priorAuthStep.data()?.status) && priorAuthStep.data()?.uid === uid)) {
      await setRequestStatus("reconciliation_required", { reconciliationStep: "firebaseAuth", reconciliationReason: "Firebase Auth user is absent without prior durable deletion intent." });
      return { requestId, uid, status: "reconciliation_required", blockers: ["Firebase Auth user is absent without prior durable deletion intent."], executedSteps, completed: false, deletionPerformed: false };
    }
  }
  if (!priorAuthStep.exists || priorAuthStep.data()?.operationStarted !== true) await writeStep("firebaseAuth", { status: "deleting", operationStarted: true, intentAt: FieldValue.serverTimestamp() });
  try { await authService().deleteUser(uid); }
  catch (error) {
    if (error?.code !== "auth/user-not-found") return reconciliation("firebaseAuth", `Firebase Auth deletion could not be verified (${error?.code ?? "unknown error"}).`, retryableError(error));
    if (!(priorAuthStep.exists && priorAuthStep.data()?.operationStarted === true && priorAuthStep.data()?.uid === uid)) return reconciliation("firebaseAuth", "Firebase Auth became absent without matching durable deletion intent.");
  }
  try {
    await authService().getUser(uid);
    return reconciliation("firebaseAuth", "Firebase Auth user still exists after the deletion operation.");
  } catch (error) {
    if (error?.code !== "auth/user-not-found") return reconciliation("firebaseAuth", "Firebase Auth absence could not be independently verified.", retryableError(error));
  }
  await writeStep("firebaseAuth", { status: "completed", completedAt: FieldValue.serverTimestamp(), verifiedAbsent: true });
  executedSteps.push("firebaseAuth");

  const finalRequest = await requestRef.get();
  const finalProfile = await profileRef.get();
  const finalProfileStep = await readStep("residentProfile");
  const finalAuthStep = await readStep("firebaseAuth");
  let authAbsent = false;
  try { await authService().getUser(uid); } catch (error) {
    if (error?.code !== "auth/user-not-found") throw error;
    authAbsent = true;
  }
  if (!finalRequest.exists || finalRequest.data()?.uid !== uid || finalProfile.exists || !authAbsent || finalProfileStep.data()?.status !== "completed" || finalAuthStep.data()?.status !== "completed") {
    return reconciliation("completion", "Final profile, Auth, request, or durable step verification failed.");
  }
  await clearProfileEvidence();
  await setRequestStatus("completed", { reviewStatus: "completed", completedAt: FieldValue.serverTimestamp(), completionVerified: true, authUidDeleted: uid, residentProfilePath: profileRef.path });
  return { requestId, uid, status: "completed", blockers: [], executedSteps, completed: true, deletionPerformed: true };
}

async function revokeResidentVisitorCredentialsCore({ db, data, now = Date.now() }) {
  const actorUid = DELETION_ACTOR;
  const requestId = String(data?.requestId ?? "").trim();
  if (!requestId || Object.keys(data ?? {}).some((key) => key !== "requestId")) throw new HttpsError("invalid-argument", "A requestId is required.");
  const request = await db.collection(COLLECTION).doc(requestId).get();
  if (!request.exists || typeof request.data()?.uid !== "string") throw new HttpsError("not-found", "Deletion request was not found.");
  const uid = request.data().uid;
  if (!hasResidentDeletionVerification(request.data(),requestId) && request.data()?.sourceApp === ASSISTED_SOURCE) throw new HttpsError("failed-precondition", "Assisted identity and consent verification are required.");
  const visitorsByHost = await db.collection("visitors").where("hostUserId", "==", uid).get();
  const visitorsByLegacyResident = await db.collection("visitors").where("residentId", "==", uid).get();
  const visitors = new Map([...visitorsByHost.docs, ...visitorsByLegacyResident.docs].map((doc) => [doc.id, doc]));
  const indexesByOwner = await db.collection("visitorGateCredentialIndex").where("hostUserId", "==", uid).get();
  const requestRef = db.collection(COLLECTION).doc(requestId);
  const revoked = [];
  const cancelledVisitorIds = [];
  const blockers = [];
  const discoveredIds = new Set(visitors.keys());
  const visitorOwnedByUid = (visitor) => (visitor?.hostUserId === uid || visitor?.residentId === uid) &&
    (!visitor?.hostUserId || visitor.hostUserId === uid) && (!visitor?.residentId || visitor.residentId === uid);
  for (const index of indexesByOwner.docs) {
    const visitorId = index.data()?.visitorId;
    if (typeof visitorId !== "string" || !visitorId) blockers.push({ visitorId: null, reason: "Owner index has no valid visitor reference." });
    else if (!discoveredIds.has(visitorId)) blockers.push({ visitorId, reason: "Owner index references a visitor record that could not be verified." });
  }
  for (const [visitorId, visitorDoc] of visitors) {
    const visitor = visitorDoc.data();
    const lifecycle = classifyVisitorForDeletion(visitor, now);
    if (lifecycle === "checked_in") blockers.push({ visitorId, communityId: visitor.communityId, reason: "Visitor remains physically checked in; only Security checkout can resolve this dependency." });
    if (lifecycle === "ambiguous") {
      blockers.push({ visitorId, communityId: visitor.communityId, reason: "Visitor lifecycle state or timestamps are unsupported or inconsistent; manual review is required." });
      continue;
    }
    const credentialRef = db.collection("visitorHostCredentials").doc(visitorId);
    const indexQuery = db.collection("visitorGateCredentialIndex").where("visitorId", "==", visitorId);
    const progressRef = requestRef.collection("visitorCredentialRevocations").doc(visitorId);
    const [credential, indexes, priorProgress] = await Promise.all([credentialRef.get(), indexQuery.get(), progressRef.get()]);
    const progress = priorProgress.data();
    const progressMatches = priorProgress.exists && progress?.status === "completed" && progress?.complete === true && progress?.requestId === requestId && progress?.uid === uid && progress?.visitorId === visitorId && progress?.communityId === visitor.communityId;
    if (!credential.exists && indexes.empty && progressMatches) {
      if (["future_expected", "future_approved"].includes(lifecycle)) {
        await db.runTransaction(async (tx) => {
          const [freshRequest, freshVisitor, freshCredential, freshIndexes, freshProgress] = await Promise.all([
            tx.get(requestRef), tx.get(visitorDoc.ref), tx.get(credentialRef), tx.get(indexQuery), tx.get(progressRef),
          ]);
          const current = freshVisitor.data();
          const prior = freshProgress.data();
          if (!freshRequest.exists || freshRequest.data()?.uid !== uid || !freshVisitor.exists ||
              current?.communityId !== visitor.communityId || !visitorOwnedByUid(current) ||
              classifyVisitorForDeletion(current, now) !== lifecycle || freshCredential.exists || !freshIndexes.empty ||
              !freshProgress.exists || prior?.requestId !== requestId || prior?.uid !== uid || prior?.visitorId !== visitorId ||
              prior?.communityId !== visitor.communityId || prior?.status !== "completed" || prior?.complete !== true) {
            throw new HttpsError("failed-precondition", "Visitor, credential, or revocation progress changed before future-visit cancellation.");
          }
          tx.update(visitorDoc.ref, { status: "cancelled", isApproved: false, cancelledAt: FieldValue.serverTimestamp(), cancelledBy: actorUid, cancellationReason: "account_deletion_request", updatedAt: FieldValue.serverTimestamp() });
          tx.set(progressRef, { ...prior, visitorDisposition: lifecycle, visitCancelledAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp() });
        });
        cancelledVisitorIds.push(visitorId);
      }
      revoked.push({ visitorId, communityId: visitor.communityId, indexCount: 0, idempotent: true });
      continue;
    }
    if (!credential.exists && indexes.empty) {
      if (["checked_in", "verified_completed_history", "terminal_history", "entry_denied_history"].includes(lifecycle)) continue;
      blockers.push({ visitorId, reason: "Credential is missing and no matching request-scoped revocation progress proves prior cleanup." });
      continue;
    }
    const details = credential.data();
    const ownerMatches = details?.hostUserId === uid && details?.communityId === visitor.communityId && visitorOwnedByUid(visitor);
    if (!ownerMatches) { blockers.push({ visitorId, reason: "Credential owner/community relationship is incomplete or mismatched." }); continue; }
    await db.runTransaction(async (tx) => {
      const [freshRequest, freshVisitor, freshCredential, freshIndexes, freshProgress] = await Promise.all([
        tx.get(requestRef), tx.get(visitorDoc.ref), tx.get(credentialRef), tx.get(indexQuery), tx.get(progressRef),
      ]);
      if (!freshRequest.exists || freshRequest.data()?.uid !== uid) throw new HttpsError("failed-precondition", "Deletion request identity changed during credential revocation.");
      if (!freshVisitor.exists) throw new HttpsError("failed-precondition", "Visitor ownership record disappeared during credential revocation.");
      const freshVisitorData = freshVisitor.data();
      const freshLifecycle = classifyVisitorForDeletion(freshVisitorData, now);
      const freshPrior = freshProgress.data();
      if (freshProgress.exists && (freshPrior?.requestId !== requestId || freshPrior?.uid !== uid || freshPrior?.visitorId !== visitorId || freshPrior?.communityId !== freshVisitorData?.communityId)) throw new HttpsError("failed-precondition", "Existing revocation progress is bound to a different identity or community.");
      if (freshProgress.exists && freshPrior?.status === "completed" && freshPrior?.complete === true && !freshCredential.exists && freshIndexes.empty) return;
      if (freshVisitorData?.communityId !== visitor.communityId || !visitorOwnedByUid(freshVisitorData) || freshLifecycle !== lifecycle) throw new HttpsError("failed-precondition", "Visitor ownership, community, or lifecycle changed during credential revocation.");
      const freshData = freshCredential.data();
      if (!freshCredential.exists || freshData?.hostUserId !== uid || freshData?.communityId !== freshVisitorData?.communityId) {
        throw new HttpsError("failed-precondition", "Credential ownership changed; manual review is required.");
      }
      tx.delete(credentialRef);
      for (const index of freshIndexes.docs) {
        if (index.data()?.visitorId !== visitorId || index.data()?.communityId !== freshVisitorData?.communityId || (index.data()?.hostUserId != null && index.data()?.hostUserId !== uid)) {
          throw new HttpsError("failed-precondition", "Credential index ownership is inconsistent.");
        }
        tx.delete(index.ref);
      }
      const visitorPatch = { credentialRevokedAt: FieldValue.serverTimestamp(), credentialRevokedBy: actorUid, updatedAt: FieldValue.serverTimestamp() };
      if (["future_expected", "future_approved"].includes(lifecycle)) {
        visitorPatch.status = "cancelled";
        visitorPatch.isApproved = false;
        visitorPatch.cancelledAt = FieldValue.serverTimestamp();
        visitorPatch.cancelledBy = actorUid;
        visitorPatch.cancellationReason = "account_deletion_request";
      }
      tx.update(visitorDoc.ref, visitorPatch);
      tx.set(progressRef, { requestId, uid, communityId: visitor.communityId, visitorId, visitorDisposition: lifecycle, status: "completed", complete: true, revokedAt: FieldValue.serverTimestamp(), completedAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp() });
    });
    if (["future_expected", "future_approved"].includes(lifecycle)) cancelledVisitorIds.push(visitorId);
    revoked.push({ visitorId, communityId: visitor.communityId, indexCount: indexes.size, idempotent: false });
  }
  return { requestId, uid, revoked, cancelledVisitorIds, blockers, complete: blockers.length === 0, processedAt: now };
}

async function cleanupResidentMembershipsAndBookingsCore({ db, data, now = Date.now() }) {
  const actorUid = DELETION_ACTOR;
  const requestId = String(data?.requestId ?? "").trim();
  if (!requestId || Object.keys(data ?? {}).some((key) => key !== "requestId")) throw new HttpsError("invalid-argument", "A requestId is required.");
  let request;
  const requestRef = db.collection(COLLECTION).doc(requestId);
  try { request = await requestRef.get(); }
  catch (_) { return { requestId, uid: null, cleanedMemberships: [], canceledBookings: [], blockers: [{ type: "read", reason: "Deletion request preflight read failed." }], complete: false, historyPreserved: true }; }
  const uid = request.data()?.uid;
  if (!request.exists || typeof uid !== "string" || !uid) throw new HttpsError("not-found", "Deletion request was not found.");
  if (request.data()?.sourceApp === ASSISTED_SOURCE && !hasResidentDeletionVerification(request.data(),requestId)) throw new HttpsError("failed-precondition", "Assisted identity and consent verification are required.");
  let profileSnapshot;
  const profileRef = db.collection("users").doc(uid);
  try { profileSnapshot = await profileRef.get(); }
  catch (_) { return { requestId, uid, cleanedMemberships: [], canceledBookings: [], blockers: [{ type: "read", reason: "Resident profile preflight read failed." }], complete: false, historyPreserved: true }; }
  if (!profileSnapshot.exists) throw new HttpsError("failed-precondition", "Resident profile is missing; membership ownership cannot be verified.");
  const profile = profileSnapshot.data();
  const flatId = profile.flatId;
  const communityId = profile.communityId;
  const legacyId = typeof profile.residentId === "string" ? profile.residentId.trim() : "";
  const ownsPointer = (field, value) => value === uid || field === "residentId" && legacyId && value === legacyId;
  const blockers = [];
  const cleanedMemberships = [];
  const canceledBookings = [];
  const cleanupProgressRef = requestRef.collection("processing").doc("membershipAndBookingCleanup");
  let cleanupWasStarted = false;
  if (!flatId) {
    const cleanupProgressSnapshot = await cleanupProgressRef.get().catch(() => null);
    cleanupWasStarted = cleanupProgressSnapshot?.exists && ["in_progress", "completed"].includes(cleanupProgressSnapshot.data()?.status) && cleanupProgressSnapshot.data()?.requestId === requestId && cleanupProgressSnapshot.data()?.uid === uid;
  }
  let flatRef;
  let flatBefore;
  if (typeof flatId === "string" && flatId && typeof communityId === "string" && communityId) {
    flatRef = db.collection("flats").doc(flatId);
    let flatSnapshot;
    try { flatSnapshot = await flatRef.get(); }
    catch (_) { blockers.push({ type: "read", reason: "Resident flat preflight read failed." }); }
    if (flatSnapshot && (!flatSnapshot.exists || flatSnapshot.data()?.communityId !== communityId)) blockers.push({ type: "flat", reason: "Resident flat/community relationship is missing or mismatched." });
    else if (flatSnapshot?.exists) {
      flatBefore = flatSnapshot.data();
      const residents = flatBefore.residentIds;
      if (residents != null && (!Array.isArray(residents) || residents.some((id) => typeof id !== "string"))) blockers.push({ type: "flat", reason: "Legacy residentIds membership is malformed." });
    }
  } else if (!cleanupWasStarted || typeof communityId !== "string" || !communityId) blockers.push({ type: "flat", reason: "Resident profile has no canonical flat/community relationship; legacy membership cannot be verified." });

  const bookingPlan = new Map();
  for (const field of ["userId", "residentId"]) {
    let query;
    try { query = await db.collection("amenity_bookings").where(field, "==", uid).get(); }
    catch (_) { blockers.push({ type: "bookings", field, reason: "Booking reference query failed." }); continue; }
    for (const doc of query.docs) {
      const key = `${doc.ref.collection}/${doc.id}`;
      if (bookingPlan.has(key)) continue;
      const booking = doc.data();
      if (booking.communityId !== communityId || booking.userId !== uid && booking.residentId !== uid) { blockers.push({ type: "booking", id: doc.id, reason: "Booking UID/community ownership is ambiguous." }); continue; }
      const date = booking.date?.toDate?.() ?? booking.bookingDate?.toDate?.();
      if (!(date instanceof Date) || !Number.isFinite(date.getTime())) { blockers.push({ type: "booking", id: doc.id, reason: "Booking date is missing or uses an unsupported legacy format." }); continue; }
      const shouldCancel = date.getTime() > now && ["pending", "confirmed", "approved"].includes(String(booking.status ?? "").toLowerCase());
      bookingPlan.set(key, { ref: doc.ref, id: doc.id, before: booking, shouldCancel });
    }
  }

  // Preflight is read-only. Any known blocker prevents all membership and booking writes.
  if (blockers.length) return { requestId, uid, cleanedMemberships, canceledBookings, blockers, complete: false, historyPreserved: true };
  await cleanupProgressRef.set({ requestId, uid, status: "in_progress", intentAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp() }, { merge: true });

  if (flatRef && flatBefore) {
    const pointers = ["residentUserId", "residentUid", "residentId"].filter((field) => ownsPointer(field, flatBefore[field]));
    const hasMembership = pointers.length || flatBefore.residentIds?.includes(uid);
    if (hasMembership) {
      await db.runTransaction(async (tx) => {
        const [freshRequest, freshProfile, fresh] = await Promise.all([tx.get(requestRef), tx.get(profileRef), tx.get(flatRef)]);
        const current = fresh.data();
        if (!freshRequest.exists || freshRequest.data()?.uid !== uid || !freshProfile.exists || freshProfile.data()?.communityId !== communityId || freshProfile.data()?.flatId !== flatId || freshProfile.data()?.residentId !== profile.residentId) throw new HttpsError("failed-precondition", "Deletion request or Resident profile changed after cleanup preflight.");
        if (!fresh.exists || current.communityId !== communityId || JSON.stringify(current) !== JSON.stringify(flatBefore)) throw new HttpsError("failed-precondition", "Flat ownership changed after cleanup preflight.");
        const patch = { updatedAt: FieldValue.serverTimestamp() };
        for (const field of ["residentUserId", "residentUid", "residentId"]) if (ownsPointer(field, current[field])) patch[field] = null;
        if (Array.isArray(current.residentIds) && current.residentIds.includes(uid)) patch.residentIds = current.residentIds.filter((id) => id !== uid);
        const remainingPointers = ["residentUserId", "residentUid", "residentId"].some((field) =>
          current[field] != null && current[field] !== "" && !ownsPointer(field, current[field]));
        const remainingResidents = current.residentIds?.some((id) => id !== uid);
        if (!remainingPointers && !remainingResidents && current.status === "occupied" && !current.reservedOnboardingId && current.isActive !== false) {
          // Check reverse assignments in the same transaction. Even an inactive
          // or ambiguous remaining profile prevents automatic vacancy release.
          const occupants = await tx.get(db.collection("users").where("flatId", "==", flatId));
          if (!occupants.docs.some((doc) => doc.id !== uid)) {
            patch.status = "vacant";
            patch.residentName = null;
          }
        }
        // Building cards read persisted counters; update them in this same transaction.
        let buildingRef;
        let buildingFlats;
        if (patch.status && typeof current.buildingId === "string" && current.buildingId) {
          buildingRef = db.collection("buildings").doc(current.buildingId);
          const building = await tx.get(buildingRef);
          if (!building.exists || building.data()?.communityId !== communityId) {
            throw new HttpsError("failed-precondition", "Unit building/community relationship cannot be verified.");
          }
          buildingFlats = await tx.get(db.collection("flats").where("buildingId", "==", current.buildingId));
        }
        tx.update(flatRef, patch);
        if (buildingRef) tx.update(buildingRef, {
          ...occupancyStats(buildingFlats.docs.filter((doc) => doc.data().communityId === communityId), new Map([[flatId, patch.status]])),
          updatedAt: FieldValue.serverTimestamp(),
        });
      });
      cleanedMemberships.push({ collection: "flats", id: flatId, communityId });
    }
  }

  for (const item of bookingPlan.values()) {
    if (!item.shouldCancel) continue;
    await db.runTransaction(async (tx) => {
      const [freshRequest, freshProfile, fresh] = await Promise.all([tx.get(requestRef), tx.get(profileRef), tx.get(item.ref)]);
      const current = fresh.data();
      const currentDate = current?.date?.toDate?.() ?? current?.bookingDate?.toDate?.();
      const previousDate = item.before.date?.toDate?.() ?? item.before.bookingDate?.toDate?.();
      if (!freshRequest.exists || freshRequest.data()?.uid !== uid || !freshProfile.exists || freshProfile.data()?.communityId !== communityId || freshProfile.data()?.flatId !== flatId || freshProfile.data()?.residentId !== profile.residentId) throw new HttpsError("failed-precondition", "Deletion request or Resident profile changed after cleanup preflight.");
      if (!fresh.exists || current.communityId !== communityId || current.userId !== item.before.userId || current.residentId !== item.before.residentId || !currentDate || currentDate.getTime() !== previousDate.getTime() || current.status !== item.before.status) throw new HttpsError("failed-precondition", "Booking ownership or status changed after cleanup preflight.");
      if (currentDate.getTime() > now && ["pending", "confirmed", "approved"].includes(String(current.status ?? "").toLowerCase())) tx.update(item.ref, { status: "cancelled", cancelledAt: FieldValue.serverTimestamp(), cancelledBy: actorUid, cancellationReason: "account_deletion_request", updatedAt: FieldValue.serverTimestamp() });
    });
    canceledBookings.push({ id: item.id, communityId });
  }
  const verifiedBookingReferences = [...bookingPlan.values()].map((item) => ({
    path: item.ref.path, id: item.id, communityId: item.before.communityId, uid,
    status: item.shouldCancel ? "cancelled" : item.before.status,
  }));
  await cleanupProgressRef.set({ requestId, uid, status: "completed", completedAt: FieldValue.serverTimestamp(), memberships: cleanedMemberships, cancelledBookings: canceledBookings, verifiedBookingReferences, updatedAt: FieldValue.serverTimestamp() }, { merge: true });
  return { requestId, uid, cleanedMemberships, canceledBookings, verifiedBookingReferences, blockers, complete: blockers.length === 0, historyPreserved: true };
}

module.exports = { financialHandoverEvidence, COLLECTION, validateRecentAuth, submitAccountDeletionRequestCore, getAccountDeletionRequestStatusCore, listCommunityDeletionRequestsCore, recordDeletionFinancialReviewCore, reviewAccountDeletionEligibilityCore, reviewAccountDeletionEligibilityForRequestCore, reviewAndFulfillAccountDeletionCore, reassessAccountDeletionRequestCore, cleanupApprovedResidentIdentityProofCore, cleanupResidentNotificationsCore, cleanupResidentSosLocationsCore, cleanupResidentProfileImagesCore, coordinateAccountDeletionFulfillmentCore, revokeResidentVisitorCredentialsCore, cleanupResidentMembershipsAndBookingsCore };
