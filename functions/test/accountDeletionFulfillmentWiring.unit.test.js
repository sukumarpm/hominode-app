const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const { createHash } = require("node:crypto");
const { FieldValue } = require("firebase-admin/firestore");
const { notificationDeviceId, notificationAudienceKey } = require("../src/notifications");
const { runAccountDeletionRetryCore, attemptAccountDeletionRequestCore, initialRetry, retryDelay, MAX_ATTEMPTS } = require("../src/account_deletion_retry");
const {
  reviewAndFulfillAccountDeletionCore,
  reviewAccountDeletionEligibilityCore,
  reviewAccountDeletionEligibilityForRequestCore,
  submitAccountDeletionRequestCore,
  recordDeletionFinancialReviewCore,
  reassessAccountDeletionRequestCore,
  listCommunityDeletionRequestsCore,
  getAccountDeletionRequestStatusCore,
} = require("../src/account_deletion_requests");

function fixture({ failCollection, interruptAuth = false } = {}) {
  const records = new Map(Object.entries({
    "admins/admin": { uid: "admin", role: "admin", isActive: true, authorizedCommunityIds: ["C1"] },
    "communities/C1": { isActive: true },
    "users/resident": { uid: "resident", role: "resident", communityId: "C1" },
    "accountDeletionRequests/request": { uid: "resident", requestId: "request", sourceApp: "resident", communityId: "C1", communityScopeVerified: true,
      status: "pending_verification", verificationCompletedAt: new Date(1), reviewStatus: "pending_admin_review", financialReviewStatus: "UNKNOWN_REQUIRES_REVIEW" },
  }));
  const writes = [];
  const snapshot = (path) => ({ id: path.split("/").at(-1), ref: ref(path), exists: records.has(path), data: () => records.get(path) });
  function ref(path) {
    return {
      path, id: path.split("/").at(-1), get: async () => snapshot(path),
      collection: (name) => collection(`${path}/${name}`),
      async set(value, options) {
        writes.push(path);
        const next = options?.merge ? { ...records.get(path), ...value } : { ...value };
        for (const [key, item] of Object.entries(next)) {
          if (item?.isEqual?.(FieldValue.delete())) delete next[key];
          else if (item?.isEqual?.(FieldValue.serverTimestamp())) next[key] = new Date();
        }
        records.set(path, next);
      },
      async update(value) { return this.set(value, { merge: true }); },
      async delete() { writes.push(path); records.delete(path); },
    };
  }
  function collection(name, group = false, filters = [], max = Infinity, orderField = null, cursor = null) {
    return {
      doc: (id = "request") => ref(`${name}/${id}`),
      where: (field, op, value) => collection(name, group, [...filters, [field, op, value]], max, orderField, cursor),
      limit: (value) => collection(name, group, filters, value, orderField, cursor),
      orderBy: (field) => collection(name, group, filters, max, field, cursor),
      startAfter: (value) => collection(name, group, filters, max, orderField, value),
      async get() {
        if (name === failCollection || typeof failCollection === "function" && failCollection(name)) throw Error("Unavailable reference query");
        const fieldValue = (row, field) => field.split(".").reduce((value, key) => value?.[key], row);
        const docs = [...records].filter(([path, row]) => {
          const parts = path.split("/");
          return (group ? parts.at(-2) === name : parts.slice(0, -1).join("/") === name) &&
            filters.every(([field, op, value]) => op === "array-contains" ? fieldValue(row, field)?.includes?.(value) :
              op === "<=" ? fieldValue(row, field) != null && fieldValue(row, field) <= value : fieldValue(row, field) === value);
        }).filter(([path]) => !cursor || path.split("/").at(-1) > cursor)
          .sort(([a, av], [b, bv]) => orderField === "__name__" ? a.localeCompare(b) :
            orderField ? fieldValue(av, orderField) - fieldValue(bv, orderField) : 0)
          .slice(0, max).map(([path]) => snapshot(path));
        return { docs, empty: !docs.length };
      },
    };
  }
  const db = { collection, collectionGroup: (name) => collection(name, true),
    runTransaction: async (fn) => fn({ get: (item) => item.get(), set: (item, value) => item.set(value), update: (item, value) => item.update(value), delete: (item) => item.delete() }) };
  let authExists = true;
  const firebaseAuth = {
    async getUser(uid) {
      assert.equal(uid, "resident");
      if (!authExists) throw Object.assign(Error("Absent"), { code: "auth/user-not-found" });
      return { uid };
    },
    async deleteUser(uid) {
      assert.equal(uid, "resident");
      assert.equal(records.has("users/resident"), false, "Auth must be last");
      assert.equal(records.get("accountDeletionRequests/request/processing/residentProfile").status, "completed");
      writes.push("auth/resident");
      authExists = false;
      if (interruptAuth) { interruptAuth = false; throw Object.assign(Error("Interrupted after Auth deletion"), { code: "auth/internal-error" }); }
    },
  };
  const residentAuth = { uid: "resident", token: { auth_time: Math.floor(Date.now() / 1000), phone_number: "+15555550123", firebase: { sign_in_provider: "phone" } } };
  const adminAuth = { uid: "admin", token: { auth_time: Math.floor(Date.now() / 1000), phone_number: "+15555550124", firebase: { sign_in_provider: "phone" } } };
  const context = { db, firebaseAuth, bucket: { getFiles: async () => [[], null] }, data: { requestId: "request" } };
  return { records, writes, context, residentAuth, adminAuth, run: () => reviewAndFulfillAccountDeletionCore(context),
    submit: () => submitAccountDeletionRequestCore({ ...context, auth: residentAuth, data: { sourceApp: "resident", uid: "other", requestId: "other", eligible: true } }) };
}

test("moderation records do not block account deletion and remain retained", async () => {
  const f = fixture();
  for (const [path, value] of Object.entries({
    "moderationReports/report": {communityId: "C1", reporterId: "resident"},
    "moderationBlocks/block": {communityId: "C1", blockerId: "resident", blockedId: "other"},
    "moderationAudit/audit": {communityId: "C1", actorId: "resident"},
  })) f.records.set(path, value);
  assert.equal((await f.submit()).status, "completed");
  for (const path of ["moderationReports/report", "moderationBlocks/block", "moderationAudit/audit"]) assert.equal(f.records.has(path), true);
});

test("automatic deletion retry: transient discovery failure resumes the verified request and deletes Auth last", async () => {
  let unavailable = true;
  const f = fixture({ failCollection: (name) => unavailable && name === "messages" });
  const submitted = await f.submit();
  assert.equal(submitted.requestId, "request");
  assert.equal(submitted.status, "pending_review");
  assert.equal(f.records.get("accountDeletionRequests/request").retry.state, "queued");
  assert.equal(f.records.has("users/resident"), true);
  unavailable = false;
  const results = await runAccountDeletionRetryCore({ ...f.context, now: Date.now() + retryDelay(1) + 1000 });
  assert.equal(results.find((item) => item.requestId === "request")?.status, "completed");
  assert.equal(f.records.get("accountDeletionRequests/request").retry.state, "completed");
  assert.equal(f.records.has("users/resident"), false);
  assert.equal(f.writes.filter((path) => path === "auth/resident").length, 1);
  assert.equal([...f.records.keys()].filter((path) => /^accountDeletionRequests\/[^/]+$/.test(path)).length, 1);
});

test("authorized Community Admin can queue trusted reassessment; Resident auth cannot", async () => {
  const f = fixture();
  f.records.set("accountDeletionRequests/request", {
    ...f.records.get("accountDeletionRequests/request"),
    status: "eligibility_blocked",
    verificationCompletedAt: new Date(),
    retry: { state: "blocked", attempts: 1, nextAttemptAt: null, leaseToken: null, leaseExpiresAt: null },
  });
  await assert.rejects(
    reassessAccountDeletionRequestCore({ ...f.context, auth: f.residentAuth }),
    { code: "permission-denied" },
  );
  const staleAdminAuth = { ...f.adminAuth, token: { ...f.adminAuth.token, auth_time: Math.floor(Date.now() / 1000) - 301 } };
  const result = await reassessAccountDeletionRequestCore({ ...f.context, auth: staleAdminAuth });
  assert.equal(result.status, "completed");
  assert.equal(f.records.get("accountDeletionRequests/request").retry.state, "completed");
  assert.equal(f.writes.filter((path) => path === "auth/resident").length, 1);
});

test("reassessment still rejects an Admin outside the request community", async () => {
  const f = fixture();
  f.records.set("accountDeletionRequests/request", {
    ...f.records.get("accountDeletionRequests/request"),
    communityId: "C2",
    status: "eligibility_blocked",
    verificationCompletedAt: new Date(),
    retry: { state: "blocked", attempts: 1, nextAttemptAt: null, leaseToken: null, leaseExpiresAt: null },
  });
  await assert.rejects(
    reassessAccountDeletionRequestCore({ ...f.context, auth: f.adminAuth }),
    { code: "permission-denied" },
  );
  assert.equal(f.records.get("accountDeletionRequests/request").retry.state, "blocked");
  assert.deepEqual(f.writes, []);
});

test("automatic deletion retry: interrupted Auth removal uses durable intent without a second Auth deletion", async () => {
  const f = fixture({ interruptAuth: true });
  const device = ownedDevice(f);
  assert.equal((await f.submit()).status, "reconciliation_required");
  const request = f.records.get("accountDeletionRequests/request");
  assert.equal(request.retry.state, "queued");
  assert.equal(f.records.get("accountDeletionRequests/request/processing/residentProfile").status, "completed");
  const results = await runAccountDeletionRetryCore({ ...f.context, now: Date.now() + retryDelay(1) + 1000 });
  assert.equal(results.find((item) => item.requestId === "request")?.status, "completed");
  assert.equal(f.writes.filter((path) => path === "auth/resident").length, 1);
  assert.equal(f.writes.filter((path) => path === device.path).length, 1, "completed device removal is not repeated");
  assert.deepEqual(f.records.get("accountDeletionRequests/request/processing/notificationDevices").removedDeviceIds, [device.id]);
  assert.equal(f.records.get("accountDeletionRequests/request/processing/firebaseAuth").status, "completed");
});

test("automatic deletion retry: real legal, ownership and financial blockers remain active", async () => {
  for (const kind of ["legal", "security", "financial", "unknownBill", "outstandingBill", "ambiguousDevice", "community"]) {
  const f = fixture();
  if (kind === "security") f.records.set("securityStaff/resident", { uid: "resident", role: "security", communityId: "C1", isActive: true });
  if (kind === "legal") {
    const path = "residentIdentityProofs/C1/resident/proof.jpg";
    f.records.get("users/resident").identityProofStoragePath = path;
    const id = createHash("sha256").update(`request\nresident\nC1\n${path}`).digest("hex");
    f.records.set(`accountDeletionRequests/request/identityProofReviews/${id}`, { decision: "LEGAL_HOLD" });
  }
  if (kind === "financial") f.records.set("payments/pending", { userId: "resident", communityId: "C1", status: "pending" });
  if (kind === "unknownBill") f.records.set("bills/unknown", { residentId: "resident", communityId: "C1" });
  if (kind === "outstandingBill") f.records.set("bills/due", { residentId: "resident", communityId: "C1", amount: 125, month: 1, year: 2026, status: "pending" });
  if (kind === "ambiguousDevice") ownedDevice(f).device.communityId = "OTHER";
  if (kind === "sharedChat") f.records.set("chats/shared", { participantIds: ["resident", "other"], communityId: "C1" });
  if (kind === "community") f.records.get("accountDeletionRequests/request").communityId = "OTHER";
  const submitted = await f.submit();
  assert.equal(submitted.status, "pending_review");
  assert.equal(f.records.get("accountDeletionRequests/request").retry.state, "blocked");
  const results = await runAccountDeletionRetryCore({ ...f.context, now: Date.now() + 3600000 });
  assert.ok(results.some((item) => item.requestId === "request" && item.status !== "completed"));
  assert.equal(f.records.has("users/resident"), true);
  assert.equal(f.writes.includes("auth/resident"), false);
  assert.equal(f.records.get("accountDeletionRequests/request").retry.state, "blocked");
  }
});

test("automatic deletion retry: network failure persists bounded backoff on one verified request", async () => {
  const f = fixture();
  const request = f.records.get("accountDeletionRequests/request");
  request.verificationCompletedAt = new Date(1);
  request.retry = initialRetry(1000);
  let calls = 0;
  const failure = async () => { calls++; throw Object.assign(Error("network unavailable"), { code: calls % 2 ? 14 : "ECONNRESET" }); };
  let due = 1000;
  for (let attempt = 1; attempt <= MAX_ATTEMPTS; attempt++) {
    const result = await attemptAccountDeletionRequestCore({ ...f.context, requestId: "request", now: due, coordinate: failure });
    assert.equal(result.status, attempt === MAX_ATTEMPTS ? "retry_exhausted" : "retry_scheduled");
    const retry = f.records.get("accountDeletionRequests/request").retry;
    assert.equal(retry.attempts, attempt);
    assert.equal(retry.state, attempt === MAX_ATTEMPTS ? "exhausted" : "queued");
    if (attempt < MAX_ATTEMPTS) {
      assert.ok(retry.nextAttemptAt >= due + retryDelay(attempt));
      due = retry.nextAttemptAt;
    } else assert.equal(retry.nextAttemptAt, null);
  }
  assert.equal(calls, MAX_ATTEMPTS);
  assert.equal((await attemptAccountDeletionRequestCore({ ...f.context, requestId: "request", now: due + 36000000, coordinate: failure })).status, "not_due");
  assert.equal(calls, MAX_ATTEMPTS);
  assert.equal(f.records.has("users/resident"), true);
  assert.equal(f.writes.includes("auth/resident"), false);
});

test("automatic deletion retry: legacy verified request is enrolled without OTP and status reads stay read-only", async () => {
  const f = fixture();
  const request = f.records.get("accountDeletionRequests/request");
  request.verificationCompletedAt = new Date(1);
  request.status = "pending_review";
  await getAccountDeletionRequestStatusCore({ ...f.context, auth: f.residentAuth });
  assert.deepEqual(f.writes, []);
  const results = await runAccountDeletionRetryCore(f.context);
  assert.equal(results[0].status, "completed");
  assert.equal(f.records.get("accountDeletionRequests/request").requestId, "request");
  assert.equal([...f.records.keys()].filter((path) => /^accountDeletionRequests\/[^/]+$/.test(path)).length, 1);
});

test("automatic deletion retry: active leases prevent overlap and expired final leases stop at the attempt bound", async () => {
  const f = fixture();
  const request = f.records.get("accountDeletionRequests/request");
  request.verificationCompletedAt = new Date(1);
  request.retry = { ...initialRetry(1000), state: "running", attempts: 1, leaseExpiresAt: 2000, nextAttemptAt: 2000, leaseToken: "interrupted" };
  assert.equal((await attemptAccountDeletionRequestCore({ ...f.context, requestId: "request", now: 1999 })).status, "not_due");
  assert.deepEqual(f.writes, []);
  assert.equal((await attemptAccountDeletionRequestCore({ ...f.context, requestId: "request", now: 2001 })).status, "completed");
  const stopped = fixture();
  Object.assign(stopped.records.get("accountDeletionRequests/request"), { verificationCompletedAt: new Date(1),
    retry: { ...initialRetry(1000), state: "running", attempts: MAX_ATTEMPTS, leaseExpiresAt: 2000, nextAttemptAt: 2000 } });
  await attemptAccountDeletionRequestCore({ ...stopped.context, requestId: "request", now: 2001 });
  assert.equal(stopped.records.get("accountDeletionRequests/request").retry.state, "exhausted");
  assert.equal(stopped.records.get("accountDeletionRequests/request").retry.nextAttemptAt, null);
  assert.equal(stopped.records.has("users/resident"), true);
});

test("automatic deletion retry: unverified and cancelled requests are never enrolled", async () => {
  for (const cancelled of [false, true]) {
    const f = fixture();
    if (!cancelled) delete f.records.get("accountDeletionRequests/request").verificationCompletedAt;
    if (cancelled) Object.assign(f.records.get("accountDeletionRequests/request"), { verificationCompletedAt: new Date(1), status: "cancelled" });
    assert.deepEqual(await runAccountDeletionRetryCore(f.context), []);
    assert.equal(f.records.get("accountDeletionRequests/request").retry, undefined);
    assert.equal(f.records.has("users/resident"), true);
    assert.equal(f.writes.includes("auth/resident"), false);
  }
});

test("automatic deletion retry: temporary Storage metadata failure retains the proof until verified cleanup", async () => {
  const f = fixture();
  const path = "residentIdentityProofs/C1/resident/proof.jpg";
  f.records.get("users/resident").identityProofStoragePath = path;
  const id = createHash("sha256").update(`request\nresident\nC1\n${path}`).digest("hex");
  f.records.set(`accountDeletionRequests/request/identityProofReviews/${id}`, {
    requestId: "request", uid: "resident", communityId: "C1", storagePath: path, storageGeneration: "1",
    decision: "APPROVED_FOR_DELETION", legalRetentionReviewed: true, legalReviewReference: "retention-review-2026-04",
  });
  let unavailable = true;
  let exists = true;
  let removals = 0;
  f.context.bucket.file = () => ({
    getMetadata: async () => {
      if (unavailable) throw Object.assign(Error("unavailable"), { code: 503 });
      if (!exists) throw Object.assign(Error("missing"), { code: 404 });
      return [{ generation: "1" }];
    },
    delete: async () => { exists = false; removals++; },
  });
  assert.equal((await f.submit()).status, "pending_review");
  assert.equal(exists, true);
  assert.equal(f.records.get("accountDeletionRequests/request").retry.state, "queued");
  unavailable = false;
  const result = await runAccountDeletionRetryCore({ ...f.context, now: Date.now() + retryDelay(1) + 1000 });
  assert.equal(result[0].status, "completed");
  assert.equal(removals, 1);
  assert.equal(f.writes.filter((path) => path === "auth/resident").length, 1);
});

test("submission is App Check protected and destructive cleanup has no public callable or Super Admin dependency", () => {
  const source = fs.readFileSync(require.resolve("../src/index"), "utf8");
  const core = fs.readFileSync(require.resolve("../src/account_deletion_requests"), "utf8");
  assert.match(source, /exports\.submitAccountDeletionRequest = accountDeletionCallable\(\s*submitAccountDeletionRequestCore,[\s\S]*?true,\s*\{ timeoutSeconds: 540 \}\s*\)/);
  assert.match(source, /exports\.reviewAccountDeletionEligibility = accountDeletionCallable\(\s*reviewAccountDeletionEligibilityForRequestCore/);
  assert.match(source, /onCall\(\{ region: REGION, enforceAppCheck: true, \.\.\.options \}/);
  assert.doesNotMatch(source, /exports\.\w+\s*=\s*[^;]*coordinateAccountDeletionFulfillmentCore/);
  assert.doesNotMatch(source, /exports\.(reviewResidentIdentityProofForDeletion|revokeResidentVisitorCredentialsForDeletion|cleanupResidentMembershipsAndBookingsForDeletion)\s*=/);
  assert.doesNotMatch(core, /requireActiveSuperAdmin|[Ss]uper\s*[Aa]dmin/);
});

test("clean Resident submission automatically fulfills without Super Admin, with Auth last and repeatable completion", async () => {
  const f = fixture();
  const assessment = await reviewAccountDeletionEligibilityCore(f.context);
  assert.equal(assessment.eligible, true);
  assert.deepEqual(f.writes, [], "assessment stays read-only");
  f.records.delete("accountDeletionRequests/request");
  const submitted = await f.submit();
  assert.equal(submitted.requestId, "request", "client request ID is ignored");
  assert.equal(submitted.status, "completed");
  assert.equal(f.records.has("users/resident"), false);
  assert.equal(f.records.get("accountDeletionRequests/request").completionVerified, true);
  assert.equal((await f.run()).status, "completed");
  assert.equal(f.writes.filter((path) => path === "auth/resident").length, 1);
});

test("workflow retries a partial Auth failure using the coordinator's durable evidence", async () => {
  const f = fixture({ interruptAuth: true });
  assert.equal((await f.submit()).status, "reconciliation_required");
  assert.equal((await f.run()).status, "completed");
  assert.equal(f.writes.filter((path) => path === "auth/resident").length, 1);
});

test("verified request advances to review and retries the same reference through completion", async () => {
  const f = fixture();
  f.records.set("securityStaff/resident", { uid: "resident", role: "security", communityId: "C1", isActive: true });
  const stale = { ...f.residentAuth, token: { ...f.residentAuth.token, auth_time: Math.floor(Date.now() / 1000) - 301 } };
  await assert.rejects(submitAccountDeletionRequestCore({ ...f.context, auth: stale, data: { sourceApp: "resident" } }));
  assert.deepEqual(f.writes, []);

  const verified = await f.submit();
  assert.equal(verified.requestId, "request");
  assert.equal(verified.status, "pending_review");
  assert.ok(verified.reasons.length > 0);
  const status = await getAccountDeletionRequestStatusCore({ ...f.context, auth: f.residentAuth });
  assert.equal(status.request.status, "pending_review");
  assert.deepEqual(status.request.reasons, verified.reasons);
  assert.equal(status.request.communityScopeVerified, true);
  assert.equal(f.records.has("users/resident"), true);
  assert.equal(f.writes.includes("auth/resident"), false);

  // Even a failed attempt must resume this reference rather than create anew.
  f.records.get("accountDeletionRequests/request").status = "failed";
  const retry = await f.submit();
  assert.equal(retry.requestId, "request");
  assert.equal(retry.idempotent, true);
  assert.equal(retry.status, "pending_review");
  assert.equal([...f.records.keys()].filter((path) => /^accountDeletionRequests\/[^/]+$/.test(path)).length, 1);

  f.records.delete("securityStaff/resident");
  const completed = await f.submit();
  assert.equal(completed.requestId, "request");
  assert.equal(completed.status, "completed");
  assert.deepEqual(completed.reasons, []);
  const receiptRetry = await f.submit();
  assert.equal(receiptRetry.requestId, "request");
  assert.equal(receiptRetry.status, "completed");
  assert.equal(receiptRetry.idempotent, true);
  assert.equal([...f.records.keys()].filter((path) => /^accountDeletionRequests\/[^/]+$/.test(path)).length, 1);
  assert.equal(f.records.has("users/resident"), false);
  assert.equal(f.writes.filter((path) => path === "auth/resident").length, 1);
});

test("Resident submission rejects missing or stale verification; internal processing rejects client execution claims", async () => {
  const f = fixture();
  for (const auth of [null, { uid: "resident", token: {} },
    { ...f.residentAuth, token: { ...f.residentAuth.token, auth_time: Math.floor(Date.now() / 1000) - 301 } }]) {
    await assert.rejects(submitAccountDeletionRequestCore({ ...f.context, auth, data: { sourceApp: "resident" } }));
  }
  for (const data of [{}, { requestId: "missing" }, { requestId: "request", uid: "other" }, { requestId: "request", eligible: true }]) {
    await assert.rejects(reviewAndFulfillAccountDeletionCore({ ...f.context, data }));
  }
  assert.deepEqual(f.writes, []);
});

test("zero dues auto-delete without Admin handover; positive dues stay blocked", async () => {
  const f = fixture();
  const bill = { residentId: "resident", communityId: "C1", amount: 125, month: 1, year: 2026, status: "paid", paidAt: 1 };
  f.records.set("bills/settled", bill);
  assert.equal((await f.submit()).status, "completed");
  assert.deepEqual(f.records.get("bills/settled"), bill);
  assert.ok(f.writes.includes("auth/resident"));
  const pending = fixture();
  const dueBill = { residentId: "resident", communityId: "C1", amount: 125, month: 1, year: 2026, status: "pending" };
  pending.records.set("bills/due", dueBill);
  assert.equal((await pending.submit()).status, "pending_review");
  assert.equal((await pending.run()).status, "blocked");
  const outstanding = await reviewAccountDeletionEligibilityCore(pending.context);
  assert.equal(outstanding.eligible, false);
  assert.ok(outstanding.unresolvedChecks.some((item) => item.check === "outstandingBillingObligations"));
  assert.deepEqual(pending.writes.filter((path) => path === "bills/due"), []);
});

test("future request captures restricted resident identity and completion metadata before cleanup", async () => {
  const f = fixture();
  Object.assign(f.records.get("users/resident"), {
    fullName: "Resident Full Name",
    phoneNumber: "+15550000011",
    flatLabel: "Tower 4 / 1202",
    residentType: "tenant",
    ownershipType: "tenant",
  });
  f.records.set("communities/C1", { isActive: true, name: "Green Wave" });
  f.records.delete("accountDeletionRequests/request");
  const result = await f.submit();
  const request = f.records.get("accountDeletionRequests/request");
  assert.equal(result.status, "completed");
  assert.deepEqual(request.retainedResidentIdentity, {
    name: "Resident Full Name",
    phoneNumber: "+15550000011",
    unit: "Tower 4 / 1202",
    communityId: "C1",
    communityName: "Green Wave",
    residentType: "tenant",
  });
  assert.equal(request.status, "completed");
  assert.equal(request.reviewStatus, "completed");
  assert.ok(request.completedAt instanceof Date);
});

test("verified handover cannot bypass outstanding dues and is bound to current financial records", async () => {
  const f = fixture();
  const bill = { residentId: "resident", communityId: "C1", amount: 125, month: 1, year: 2026, status: "pending" };
  f.records.set("bills/due", bill);
  await f.submit();
  const adminAuth = { ...f.residentAuth, uid: "admin" };
  const listing = await listCommunityDeletionRequestsCore({ ...f.context, auth: adminAuth, data: { communityId: "C1" } });
  const evidenceDigest = listing.requests[0].financialEvidence.digest;
  await assert.rejects(recordDeletionFinancialReviewCore({ ...f.context, auth: adminAuth,
    data: { requestId: "request", finding: "verified_handover", note: "Outstanding bill retained for settlement before closure.", evidenceDigest, retainFinancialRecords: true } }));
  assert.notEqual(f.records.get("accountDeletionRequests/request").financialReviewStatus, "VERIFIED_HANDOVER");
  const blocked = await reviewAccountDeletionEligibilityCore(f.context);
  assert.equal(blocked.eligible, false);
  assert.ok(blocked.unresolvedChecks.some((item) => item.check === "outstandingBillingObligations"));

  // A changed bill invalidates the evidence captured at review time, including a
  // change that settles the due; Admin must refresh the evidence and verify again.
  f.records.set("bills/due", { ...bill, status: "paid", paidAt: 1 });
  const refreshed = await listCommunityDeletionRequestsCore({ ...f.context, auth: adminAuth, data: { communityId: "C1" } });
  assert.notEqual(refreshed.requests[0].financialEvidence.digest, evidenceDigest);
  await assert.rejects(recordDeletionFinancialReviewCore({ ...f.context, auth: adminAuth,
    data: { requestId: "request", finding: "verified_handover", note: "Reject the stale financial snapshot after settlement.", evidenceDigest, retainFinancialRecords: true } }));
  assert.notEqual(f.records.get("accountDeletionRequests/request").financialReviewStatus, "VERIFIED_HANDOVER");
  assert.deepEqual(f.records.get("bills/due"), { ...bill, status: "paid", paidAt: 1 });
});

test("verified handover rejects unknown billing evidence", async () => {
  const f = fixture({ failCollection: "bills" });
  await f.submit();
  const adminAuth = { ...f.residentAuth, uid: "admin" };
  await assert.rejects(recordDeletionFinancialReviewCore({ ...f.context, auth: adminAuth,
    data: { requestId: "request", finding: "verified_handover", note: "Billing evidence is unavailable, so defer deletion.",
      evidenceDigest: "a".repeat(64), retainFinancialRecords: true } }));
  assert.notEqual(f.records.get("accountDeletionRequests/request").financialReviewStatus, "VERIFIED_HANDOVER");
  assert.equal(f.records.has("users/resident"), true);

  const active = fixture();
  active.records.set("payments/pending", { userId: "resident", communityId: "C1", status: "pending" });
  await active.submit();
  const activeAdminAuth = { ...active.residentAuth, uid: "admin" };
  const listing = await listCommunityDeletionRequestsCore({ ...active.context, auth: activeAdminAuth, data: { communityId: "C1" } });
  assert.equal(listing.requests[0].financialEvidence, null);
  await assert.rejects(recordDeletionFinancialReviewCore({ ...active.context, auth: activeAdminAuth,
    data: { requestId: "request", finding: "verified_handover", note: "Pending payment submission still requires resolution.",
      evidenceDigest: "a".repeat(64), retainFinancialRecords: true } }), /Pending financial submissions require resolution/);
  assert.notEqual(active.records.get("accountDeletionRequests/request").financialReviewStatus, "VERIFIED_HANDOVER");
});

test("verified handover returns after durable save and the worker completes deletion independently", async () => {
  const f = fixture();
  f.records.set("bills/due", {residentId: "resident", communityId: "C1", amount: 125, month: 1, year: 2026, status: "pending"});
  await f.submit();
  f.records.set("bills/due", {...f.records.get("bills/due"), status: "paid", paidAt: 1});
  const listing = await listCommunityDeletionRequestsCore({...f.context, auth: f.adminAuth, data: {communityId: "C1"}});
  const result = await recordDeletionFinancialReviewCore({...f.context, auth: f.adminAuth,
    data: {requestId: "request", finding: "verified_handover", note: "Settlement evidence has been reviewed.",
      evidenceDigest: listing.requests[0].financialEvidence.digest, retainFinancialRecords: true}});
  assert.equal(result.status, "deletion_processing");
  assert.equal(result.deletionPerformed, false);
  assert.equal(f.records.get("accountDeletionRequests/request").financialReviewStatus, "VERIFIED_HANDOVER");
  assert.equal(f.records.get("accountDeletionRequests/request").retry.state, "queued");
  assert.equal(f.records.has("users/resident"), true);
  assert.equal(f.writes.includes("auth/resident"), false);
  const retried = await runAccountDeletionRetryCore({...f.context, now: Date.now() + 1000});
  assert.equal(retried[0].status, "completed");
  assert.equal(f.records.get("accountDeletionRequests/request").status, "completed");
  assert.equal(f.writes.filter(path => path === "auth/resident").length, 1);
  assert.deepEqual(await runAccountDeletionRetryCore({...f.context, now: Date.now() + 10000}), []);
});

test("verified policy-v2 request without retry metadata is enrolled automatically", async () => {
  const f = fixture();
  Object.assign(f.records.get("accountDeletionRequests/request"), {verificationCompletedAt: new Date(1), status: "pending_review", deletionPolicyVersion: 2});
  assert.equal((await runAccountDeletionRetryCore(f.context))[0].status, "completed");
});

test("resident status exposes only a sanitized financial state for settlement review", async () => {
  const due = fixture();
  due.records.set("bills/due", { residentId: "resident", communityId: "C1", amount: 125,
    month: 1, year: 2026, status: "pending" });
  await due.submit();
  const dueStatus = await getAccountDeletionRequestStatusCore({ ...due.context, auth: due.residentAuth });
  assert.equal(dueStatus.request.financialStatus, "awaiting_settlement");
  assert.ok(!Object.keys(dueStatus.request).includes("evidenceDigest"));

  const unknown = fixture({ failCollection: "bills" });
  await unknown.submit();
  const unknownStatus = await getAccountDeletionRequestStatusCore({ ...unknown.context, auth: unknown.residentAuth });
  assert.equal(unknownStatus.request.financialStatus, "unknown_requires_reconciliation");
});

test("legacy findings and retained history do not block; unknown financial queries remain blocked", async () => {
  for (const kind of ["finding", "query", "history"]) {
    const f = fixture(kind === "query" ? { failCollection: "payments" } : {});
    if (kind === "finding") f.records.get("accountDeletionRequests/request").reviewFinding = "dependency_unresolved";
    if (kind === "history") f.records.set("payments/p1", { userId: "resident", communityId: "C1", status: "paid" });
    const submitted = await f.submit();
    if (kind === "query") {
      assert.equal(submitted.status, "pending_review", kind);
      assert.equal((await f.run()).status, "blocked", kind);
    } else {
      assert.equal(submitted.status, "completed", kind);
      assert.equal((await f.run()).status, "completed", kind);
    }
    if (kind === "query") assert.ok(f.writes.every((path) => path === "accountDeletionRequests/request"), kind);
    else assert.ok(f.writes.includes("auth/resident"), kind);
  }
});

test("generic Admin findings are rejected; list and status reads remain read-only", async () => {
  const f = fixture();
  const adminAuth = { ...f.residentAuth, uid: "admin" };
  await assert.rejects(recordDeletionFinancialReviewCore({ ...f.context, auth: adminAuth,
    data: { requestId: "request", finding: "handover_complete", note: "Reviewed without executing account deletion." } }), { code: "invalid-argument" });
  assert.deepEqual(f.writes, []);
  await listCommunityDeletionRequestsCore({ ...f.context, auth: adminAuth, data: { communityId: "C1" } });
  await getAccountDeletionRequestStatusCore({ ...f.context, auth: f.residentAuth });
  assert.equal((await reviewAccountDeletionEligibilityForRequestCore({ ...f.context, auth: adminAuth })).eligible, true);
  assert.equal((await reviewAccountDeletionEligibilityForRequestCore({ ...f.context, auth: f.residentAuth })).eligible, true);
  assert.deepEqual(f.writes, []);
  assert.equal(f.records.has("users/resident"), true);
  assert.equal((await f.context.firebaseAuth.getUser("resident")).uid, "resident");
});

test("cross-community Admin cannot record handover or inspect eligibility", async () => {
  const f = fixture();
  const foreignAuth = { ...f.residentAuth, uid: "foreign" };
  f.records.set("admins/foreign", { uid: "foreign", role: "admin", isActive: true, authorizedCommunityIds: ["C2"] });
  await assert.rejects(recordDeletionFinancialReviewCore({ ...f.context, auth: foreignAuth,
    data: { requestId: "request", finding: "handover_complete", note: "Cross-community handover must be rejected." } }));
  for (const auth of [foreignAuth, null, { ...f.residentAuth, uid: "other" }]) {
    await assert.rejects(reviewAccountDeletionEligibilityForRequestCore({ ...f.context, auth }));
  }
  assert.deepEqual(f.writes, []);
});

test("legal holds, checked-in visitors and additional security roles block automatic deletion", async () => {
  for (const kind of ["legalHold", "checkedInVisitor", "securityRole"]) {
    const f = fixture();
    if (kind === "legalHold") {
      const storagePath = "residentIdentityProofs/C1/resident/proof.jpg";
      f.records.get("users/resident").identityProofStoragePath = storagePath;
      const reviewId = createHash("sha256").update(`request\nresident\nC1\n${storagePath}`).digest("hex");
      f.records.set(`accountDeletionRequests/request/identityProofReviews/${reviewId}`, { decision: "LEGAL_HOLD" });
    }
    if (kind === "checkedInVisitor") f.records.set("visitors/v1", { hostUserId: "resident", communityId: "C1", status: "inside", actualArrival: Date.now() - 1000 });
    if (kind === "securityRole") f.records.set("securityStaff/resident", { uid: "resident", role: "security", communityId: "C1", isActive: true });
    assert.equal((await f.submit()).status, "pending_review", kind);
    const result = await f.run();
    assert.equal(result.status, "blocked", kind);
    assert.equal(f.records.has("users/resident"), true, kind);
    assert.equal((await f.context.firebaseAuth.getUser("resident")).uid, "resident");
    assert.ok(f.writes.every((path) => path === "accountDeletionRequests/request"), kind);
  }
});

test("resolved SOS coordinates are removed while the emergency history is retained", async () => {
  const f = fixture();
  f.records.set("sosAlerts/resolved", { residentUid: "resident", communityId: "C1", status: "resolved", location: { latitude: 1, longitude: 2, accuracy: 10 } });
  const result = await f.submit();
  assert.equal(result.status, "completed");
  const alert = f.records.get("sosAlerts/resolved");
  assert.equal(alert.location, undefined);
  assert.equal(alert.locationAvailable, false);
  assert.equal(alert.status, "resolved");
  assert.ok(f.records.has("sosAlerts/resolved"));
});

test("verified profile Storage objects are deleted without touching shared images", async () => {
  const f = fixture();
  let present = true;
  let deletedGeneration;
  const path = "resident_images/C1/resident/profile/photo.jpg";
  const profileFile = {
    name: path,
    getMetadata: async () => [{ generation: "g-profile", metadata: { ownerId: "resident", communityId: "C1", feature: "profile" } }],
    delete: async ({ ifGenerationMatch }) => { deletedGeneration = ifGenerationMatch; present = false; },
  };
  f.records.get("users/resident").profileImageUrl = "https://storage.invalid/profile/photo.jpg";
  f.context.bucket = {
    getFiles: async ({ prefix }) => [present && prefix === "resident_images/C1/resident/profile/" ? [profileFile] : [], null],
    file: () => profileFile,
  };
  const result = await f.submit();
  assert.equal(result.status, "completed");
  assert.equal(present, false);
  assert.equal(deletedGeneration, "g-profile");
  assert.equal(f.records.has("users/resident"), false);
});

function ownedDevice(f) {
  const device = {
    uid: 'resident', communityId: 'C1', role: 'resident', appId: 'resident', platform: 'android',
    firebaseAppId: '1:551984029668:android:ef652ea4d8e070ca0db1f1',
    installationId: 'installation_resident_001', token: 'test_token_with_more_than_twenty_characters', active: true,
  };
  device.audienceKey = notificationAudienceKey(device);
  const id = notificationDeviceId(device.appId, device.uid, device.installationId);
  const path = `notificationDevices/${id}`;
  f.records.set(path, device);
  const request = f.records.get('accountDeletionRequests/request');
  request.status = 'pending_review';
  request.verificationCompletedAt = new Date(1);
  return {id, path, device};
}

test('notification-device deletion: verified existing request completes with atomic device evidence and Auth last', async () => {
  const f = fixture();
  const d = ownedDevice(f);
  f.records.get('users/resident').flatId = 'flat-a';
  f.records.set('flats/flat-a', {communityId:'C1', residentUserId:'resident', residentId:null, residentIds:['resident']});
  const assessed = await reviewAccountDeletionEligibilityCore(f.context);
  assert.equal(assessed.coverage.additionalResidentReferences.notificationDevices.cleanupEligible, true);
  assert.equal(assessed.coverage.additionalResidentReferences.notifications.status, 'VERIFIED_ABSENT');
  assert.deepEqual(f.writes, []);
  const result = await f.run();
  assert.equal(result.requestId, 'request');
  assert.equal(result.status, 'completed');
  assert.equal(f.records.has(d.path), false);
  assert.equal(f.records.get('flats/flat-a').residentUserId, null);
  assert.deepEqual(f.records.get('flats/flat-a').residentIds, []);
  const evidence = f.records.get('accountDeletionRequests/request/processing/notificationDevices');
  assert.equal(evidence.status, 'completed');
  assert.equal(evidence.requestId, 'request');
  assert.equal(evidence.uid, 'resident');
  assert.equal(evidence.communityId, 'C1');
  assert.deepEqual(evidence.removedDeviceIds, [d.id]);
  assert.equal(JSON.stringify(evidence).includes(d.device.token), false);
  assert.ok(f.writes.indexOf(d.path) < f.writes.indexOf('users/resident'));
  assert.ok(f.writes.indexOf('users/resident') < f.writes.indexOf('auth/resident'));
  assert.equal((await f.run()).status, 'completed');
  assert.equal(f.writes.filter(path => path === d.path).length, 1);
  assert.equal([...f.records.keys()].filter(path => /^accountDeletionRequests\/[^/]+$/.test(path)).length, 1);
});

test('notification-device deletion: missing verification, ambiguous scope, invalid app and malformed device stay blocked', async () => {
  for (const kind of ['unverified', 'foreignCommunity', 'foreignApp', 'wrongId', 'queryFailure', 'profileMissing', 'conflictingEvidence']) {
    const f = fixture(kind === 'queryFailure' ? {failCollection: 'notificationDevices'} : {});
    const d = ownedDevice(f);
    if (kind === 'unverified') delete f.records.get('accountDeletionRequests/request').verificationCompletedAt;
    if (kind === 'foreignCommunity') d.device.communityId = 'C2';
    if (kind === 'foreignApp') d.device.appId = 'admin';
    if (kind === 'wrongId') { f.records.delete(d.path); f.records.set('notificationDevices/wrong-id', d.device); }
    if (kind === 'profileMissing') f.records.delete('users/resident');
    if (kind === 'conflictingEvidence') f.records.set('accountDeletionRequests/request/processing/notificationDevices', {requestId:'other', uid:'other', communityId:'C2', status:'completed'});
    const result = await f.run();
    assert.notEqual(result.status, 'completed', kind);
    assert.equal(f.writes.some(path => path.startsWith('notificationDevices/')), false, kind);
    assert.equal(f.writes.includes('auth/resident'), false, kind);
    if (kind !== 'profileMissing') assert.equal(f.records.has('users/resident'), true, kind);
  }
});

test('notification-device deletion cleans Resident inbox data while financial and legal blockers still block', async () => {
  for (const kind of ['notificationHistory', 'chatHistory', 'financial', 'legalHold']) {
    const f = fixture();
    const d = ownedDevice(f);
    if (kind === 'notificationHistory') f.records.set('notifications/retained', {recipientId:'resident', communityId:'C1'});
    if (kind === 'chatHistory') f.records.set('chats/shared', {participantIds:['resident','other'], communityId:'C1'});
    if (kind === 'financial') f.records.set('payments/retained', {userId:'resident', communityId:'C1', status:'pending'});
    if (kind === 'legalHold') {
      const path = 'residentIdentityProofs/C1/resident/proof.jpg';
      f.records.get('users/resident').identityProofStoragePath = path;
      const id = createHash('sha256').update(`request\nresident\nC1\n${path}`).digest('hex');
      f.records.set(`accountDeletionRequests/request/identityProofReviews/${id}`, {decision:'LEGAL_HOLD'});
    }
    const result = await f.run();
    assert.equal(result.status, ['notificationHistory', 'chatHistory'].includes(kind) ? 'completed' : 'blocked', kind);
    assert.equal(f.records.has(d.path), ['notificationHistory', 'chatHistory'].includes(kind) ? false : true, kind);
    if (kind === 'notificationHistory') assert.equal(f.records.has('notifications/retained'), false);
  }
});

test('notification-device deletion: ownership changes or a missing device during cleanup stop the transaction', async () => {
  for (const kind of ['ownershipChanged', 'missing', 'newDevice']) {
    const f = fixture();
    const d = ownedDevice(f);
    const transact = f.context.db.runTransaction;
    f.context.db.runTransaction = async (fn) => {
      if (kind === 'ownershipChanged') d.device.uid = 'other';
      if (kind === 'missing') f.records.delete(d.path);
      if (kind === 'newDevice') f.records.set('notificationDevices/ambiguous-new', {uid:'resident', communityId:'C1'});
      return transact(fn);
    };
    assert.equal((await f.run()).status, 'reconciliation_required', kind);
    assert.equal(f.writes.some(path => path.startsWith('notificationDevices/')), false, kind);
    assert.equal(f.records.has('users/resident'), true, kind);
    assert.equal(f.writes.includes('auth/resident'), false, kind);
  }
});

test('notification-device deletion: retry after interrupted Auth deletion preserves the same cleanup evidence', async () => {
  const f = fixture({interruptAuth:true});
  const d = ownedDevice(f);
  assert.equal((await f.run()).status, 'reconciliation_required');
  const evidence = f.records.get('accountDeletionRequests/request/processing/notificationDevices');
  assert.equal(evidence.status, 'completed');
  assert.equal((await f.run()).status, 'completed');
  assert.equal(f.records.get('accountDeletionRequests/request/processing/notificationDevices'), evidence);
  assert.equal(f.writes.filter(path => path === d.path).length, 1);
  assert.equal(f.writes.filter(path => path === 'auth/resident').length, 1);
});

test('notification-device deletion: fresh submission records verification; status refresh never performs cleanup', async () => {
  const f = fixture();
  const d = ownedDevice(f);
  f.records.delete('accountDeletionRequests/request');
  assert.equal((await f.submit()).status, 'completed');
  assert.equal(f.records.has(d.path), false);
  const g = fixture();
  const saved = ownedDevice(g);
  const response = await getAccountDeletionRequestStatusCore({...g.context, auth:g.residentAuth});
  assert.equal(response.request.requestId, 'request');
  assert.equal(response.request.status, 'pending_review');
  assert.equal(g.records.has(saved.path), true);
  assert.deepEqual(g.writes, []);
});

test('notification-device deletion: retry reconciles an interrupted cleanup acknowledgement without losing evidence', async () => {
  const f = fixture();
  const d = ownedDevice(f);
  const transact = f.context.db.runTransaction;
  let interrupted = false;
  f.context.db.runTransaction = async (fn) => {
    const result = await transact(fn);
    if (!interrupted) { interrupted = true; throw Error('Response interrupted after device cleanup committed'); }
    return result;
  };
  assert.equal((await f.run()).status, 'reconciliation_required');
  assert.equal(f.records.has(d.path), false);
  assert.equal(f.records.has('users/resident'), true);
  assert.equal((await f.run()).status, 'completed');
  const evidence = f.records.get('accountDeletionRequests/request/processing/notificationDevices');
  assert.equal(evidence.status, 'completed');
  assert.deepEqual(evidence.removedDeviceIds, [d.id]);
  assert.equal(evidence.dispositions.length, 1);
  assert.equal(f.writes.filter(path => path === d.path).length, 1);
  assert.equal(f.writes.filter(path => path === 'auth/resident').length, 1);
});

test("unit allocation: pending financial review and outstanding dues retain every assignment", async () => {
  for (const financial of ["pending", "dues"]) {
    const f = fixture();
    f.records.get("users/resident").flatId = "F1";
    const flat = {communityId: "C1", status: "occupied", residentUserId: "resident", residentIds: ["resident", "other"]};
    f.records.set("flats/F1", {...flat});
    if (financial === "dues") f.records.set("bills/due", {residentId: "resident", communityId: "C1", flatId: "F1", amount: 125, month: 1, year: 2026, status: "pending"});
    else f.records.set("payments/pending", {userId: "resident", communityId: "C1", flatId: "F1", status: "pending"});
    const result = await f.submit();
    assert.equal(result.status, "pending_review");
    assert.deepEqual(f.records.get("flats/F1"), flat);
    assert.equal(f.records.has("users/resident"), true);
    assert.equal(f.writes.includes("auth/resident"), false);
  }
});

test("unit allocation: completed deletion removes only its own shared membership and retries preserve reassignment", async () => {
  const f = fixture();
  f.records.get("users/resident").flatId = "F1";
  f.records.set("flats/F1", {communityId: "C1", status: "occupied", residentUserId: "resident", residentIds: ["resident", "other"]});
  f.records.set("users/other", {uid: "other", role: "resident", communityId: "C1", flatId: "F1"});
  assert.equal((await f.submit()).status, "completed");
  assert.deepEqual(f.records.get("flats/F1").residentIds, ["other"]);
  assert.equal(f.records.get("flats/F1").residentUserId, null);
  assert.equal(f.records.get("flats/F1").status, "occupied");
  assert.equal(f.records.get("users/other").flatId, "F1");
  f.records.get("flats/F1").residentUserId = "other";
  assert.equal((await f.run()).status, "completed");
  assert.equal(f.records.get("flats/F1").residentUserId, "other");
});
