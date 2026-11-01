const { randomUUID } = require("node:crypto");
const { FieldValue } = require("firebase-admin/firestore");
const { hasResidentDeletionVerification } = require("./account_deletion_verification");

const MAX_ATTEMPTS = 8;
const BASE_DELAY_MS = 5 * 60 * 1000;
const MAX_DELAY_MS = 6 * 60 * 60 * 1000;
const LEASE_MS = 15 * 60 * 1000;
const REQUESTS_PER_RUN = 10;
const LEGACY_SCAN_SIZE = 25;
const RESUMABLE_STATUSES = new Set(["pending_verification", "pending_review", "eligibility_blocked", "deletion_in_progress", "reconciliation_required", "failed"]);

function retryDelay(attempts) {
  return Math.min(MAX_DELAY_MS, BASE_DELAY_MS * 2 ** Math.max(0, attempts - 1));
}

function verifiedResidentRequest(request, requestId, now) {
  return hasResidentDeletionVerification(request, requestId, Math.max(now, Date.now())) && RESUMABLE_STATUSES.has(request.status);
}

function retryableError(error) {
  const code = String(error?.code ?? "").toLowerCase();
  return ["unavailable", "deadline-exceeded", "aborted", "resource-exhausted", "internal", "unknown",
    "auth/internal-error", "auth/network-request-failed", "auth/too-many-requests", "app/network-error", "app/network-timeout",
    "econnreset", "econnrefused", "enetunreach", "epipe", "etimedout", "eai_again"].includes(code) ||
    /^5\d\d$/.test(code) || ["429", "2", "4", "8", "10", "13", "14"].includes(code) ||
    (["failed-precondition", "9"].includes(code) && /index/i.test(String(error?.message ?? "")));
}

// An unknown discovery result stays a blocker. This only decides whether the
// trusted coordinator should reassess it later; it never makes it eligible.
function retryableResult(result) {
  if (result?.status === "completed") return false;
  if (result?.retryable === true) return true;
  if (result?.status !== "blocked") return false;
  const checks = result.unresolvedChecks;
  if (!Array.isArray(checks) || !checks.length) return false;
  const technical = new Set(result.retryableDiscoveryChecks ?? []);
  const hasProfileReadFailure = checks.some(({ check }) => check.startsWith("profile:"));
  const hasVisitorReadFailure = checks.some(({ check }) => check.startsWith("query:visitors.") || check.startsWith("query:visitorGateCredentialIndex.") || check.startsWith("visitorCredential:"));
  const hasLegacyQueryFailure = checks.some(({ check }) => check.startsWith("query:flats.") || check.startsWith("query:residentOnboarding."));
  return checks.every(({ check, reason, retryable }) => retryable === true || check.startsWith("query:") || check.startsWith("profile:") || check.startsWith("visitorCredential:") ||
    check.startsWith("account:") || technical.has(check) ||
    (check === "communityIdentity" && /could not be verified/i.test(reason)) ||
    (check === "identity" && hasProfileReadFailure) ||
    (check === "credentialIndexCompleteness" && hasVisitorReadFailure) ||
    (check === "legacyResidentReferences" && hasLegacyQueryFailure));
}

function initialRetry(now) {
  return { state: "queued", attempts: 0, nextAttemptAt: now, leaseToken: null, leaseExpiresAt: null,
    lastAttemptAt: null, lastOutcome: null };
}

async function attemptAccountDeletionRequestCore({ db, bucket, firebaseAuth = null, requestId, now = Date.now(), coordinate = null }) {
  const startedAt = Date.now();
  const ref = db.collection("accountDeletionRequests").doc(requestId);
  const token = randomUUID();
  const claim = await db.runTransaction(async (tx) => {
    const snapshot = await tx.get(ref);
    const request = snapshot.data();
    const retry = request?.retry;
    if (!snapshot.exists || !retry || !["queued", "running"].includes(retry.state) ||
        !Number.isFinite(retry.nextAttemptAt) || retry.nextAttemptAt > now ||
        (retry.state === "running" && retry.leaseExpiresAt > now)) return null;
    // A process may have died after completion or on its final attempt. Remove
    // those due entries as well, so they cannot starve the bounded worker batch.
    const terminal = request.status === "completed" ? "completed" :
      !verifiedResidentRequest(request, requestId, now) || !Number.isInteger(retry.attempts) || retry.attempts < 0 ? "blocked" :
        retry.attempts >= MAX_ATTEMPTS ? "exhausted" : null;
    if (terminal) {
      tx.update(ref, { retry: { ...retry, state: terminal, nextAttemptAt: null, leaseToken: null, leaseExpiresAt: null, lastOutcome: terminal } });
      return null;
    }
    tx.update(ref, { retry: { ...retry, state: "running", attempts: retry.attempts + 1,
      leaseToken: token, leaseExpiresAt: now + LEASE_MS, nextAttemptAt: now + LEASE_MS,
      lastAttemptAt: now, lastOutcome: "running" }, updatedAt: FieldValue.serverTimestamp() });
    return { attempts: retry.attempts + 1, uid: request.uid };
  });
  if (!claim) return { requestId, status: "not_due", completed: false };

  let result;
  let failure;
  try {
    const coordinator = coordinate ?? require("./account_deletion_requests").reviewAndFulfillAccountDeletionCore;
    result = await coordinator({ db, bucket, firebaseAuth, data: { requestId } });
  } catch (error) {
    failure = error;
  }
  const retryable = failure ? retryableError(failure) : retryableResult(result);
  const financialReviewRequired = !failure && result?.unresolvedChecks?.some(({ check }) =>
    ["outstandingBillingObligations", "billingEvidenceAmbiguous", "activeFinancialSubmissions"].includes(check) ||
    check.startsWith("query:bills.") || check.startsWith("query:residentFinancialAccounts.") || check.startsWith("query:payments.") ||
    check.startsWith("query:paymentProofsV2.") || check.startsWith("query:paymentTransactions.") || check.startsWith("query:paymentAllocations."));
  const exhausted = retryable && claim.attempts >= MAX_ATTEMPTS;
  const finishedAt = now + Math.max(0, Date.now() - startedAt);
  const outcome = failure ? (retryable ? "transient_error" : "blocked") : result.status === "completed" ? "completed" : retryable ? "transient_blocker" : "blocked";
  await db.runTransaction(async (tx) => {
    const snapshot = await tx.get(ref);
    const request = snapshot.data();
    if (!snapshot.exists || request?.uid !== claim.uid || request.retry?.leaseToken !== token) return;
    const pendingReview = request.status !== "completed" && !["deletion_in_progress", "reconciliation_required"].includes(request.status) &&
      (failure || result?.status === "blocked");
    tx.update(ref, { retry: { ...request.retry, state: outcome === "completed" ? "completed" :
      retryable ? (exhausted ? "exhausted" : "queued") : "blocked",
      nextAttemptAt: retryable && !exhausted ? finishedAt + retryDelay(claim.attempts) : null,
      leaseToken: null, leaseExpiresAt: null, lastOutcome: exhausted ? "exhausted" : outcome,
      lastErrorCode: failure ? String(failure.code ?? "unknown") : null,
      lastBlockers: (result?.blockers ?? []).slice(0, 20), updatedAt: finishedAt },
      ...(pendingReview ? { status: "pending_review", processingBlockers: failure ?
        [exhausted ? "Automatic retry limit reached. Processing requires review." : retryable ? "Processing was interrupted and will be retried automatically." : "Processing failed and requires review."] : result.blockers } : {}),
      ...(pendingReview && financialReviewRequired ? { financialReviewRequired: true, financialReviewStatus: "UNKNOWN_REQUIRES_REVIEW", reviewStatus: "pending_admin_review" } : {}),
      updatedAt: FieldValue.serverTimestamp() });
  });
  if (failure && !retryable) throw failure;
  return failure ? { requestId, status: exhausted ? "retry_exhausted" : "retry_scheduled", completed: false, retryable: !exhausted } : result;
}

// Old verified requests are enrolled in small, paginated batches. The cursor
// is durable, so an unchanged legacy request is eventually reached after a
// release without requiring a script, OTP, or status read to trigger work.
async function enrollLegacyRequests({ db, now }) {
  const stateRef = db.collection("accountDeletionRetryControl").doc("legacyScan");
  const state = (await stateRef.get()).data();
  let query = db.collection("accountDeletionRequests").orderBy("__name__");
  if (state?.cursor) query = query.startAfter(state.cursor);
  const page = await query.limit(LEGACY_SCAN_SIZE).get();
  for (const doc of page.docs) {
    const request = doc.data();
    const policyUpgrade = request?.deletionPolicyVersion !== 2;
    if (verifiedResidentRequest(request, doc.id, now) && request.status !== "completed" &&
        (policyUpgrade || !request.retry)) {
      await db.runTransaction(async (tx) => {
        const fresh = await tx.get(doc.ref);
        const current = fresh.data();
        const canUpgrade = !current?.retry || (current?.deletionPolicyVersion !== 2 && ["blocked", "exhausted", "completed"].includes(current.retry.state));
        if (fresh.exists && verifiedResidentRequest(current, doc.id, now) && current.status !== "completed" && canUpgrade) {
          tx.update(doc.ref, { deletionPolicyVersion: 2, retry: initialRetry(now), updatedAt: FieldValue.serverTimestamp() });
        }
      });
    }
  }
  await stateRef.set({ cursor: page.docs.length === LEGACY_SCAN_SIZE ? page.docs.at(-1).id : null,
    scannedAt: FieldValue.serverTimestamp() }, { merge: true });
}

async function runAccountDeletionRetryCore({ db, bucket, firebaseAuth = null, now = Date.now(), coordinate = null }) {
  const startedAt = Date.now();
  await enrollLegacyRequests({ db, now });
  const due = await db.collection("accountDeletionRequests").where("retry.nextAttemptAt", "<=", now)
    .orderBy("retry.nextAttemptAt").limit(REQUESTS_PER_RUN).get();
  const results = [];
  for (const doc of due.docs) {
    try { results.push(await attemptAccountDeletionRequestCore({ db, bucket, firebaseAuth, requestId: doc.id,
      now: now + Math.max(0, Date.now() - startedAt), coordinate })); }
    catch (error) { results.push({ requestId: doc.id, status: "blocked", errorCode: String(error?.code ?? "unknown") }); }
  }
  return results;
}

module.exports = { initialRetry, retryableError, retryableResult, attemptAccountDeletionRequestCore,
  runAccountDeletionRetryCore, MAX_ATTEMPTS, retryDelay };
