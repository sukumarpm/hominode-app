const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const { HttpsError } = require("firebase-functions/v2/https");
const { reviewAccountDeletionEligibilityCore, reviewAccountDeletionEligibilityForRequestCore, coordinateAccountDeletionFulfillmentCore, getAccountDeletionRequestStatusCore } = require("../src/account_deletion_requests");
const billingLedger = require("../src/billing_v2_ledger");
const { monthlyBillIdV2 } = require("../src/billing_batch");

function mockDb(data, { failRead } = {}) {
  const writes = [];
  return {
    writes,
    collection(name) {
      return { doc(id) { return { async get() {
        if (failRead === `${name}/${id}`) throw new Error("read failed");
        const value = data[`${name}/${id}`];
        return { exists: value !== undefined, data: () => value };
      }, collection(child) { return { doc(childId) { const path = `${name}/${id}/${child}/${childId}`; return {
        async get() { const value = data[path]; return { exists: value !== undefined, data: () => value }; },
        set() { writes.push("set"); },
      }; } }; }, set() { writes.push("set"); }, update() { writes.push("update"); }, delete() { writes.push("delete"); } }; } };
    },
  };
}
const auth = { uid: "target", token: { phone_number: "+15555550123", firebase: { sign_in_provider: "phone" } } };
const seed = (profiles = {}) => ({
  "accountDeletionRequests/req-1": { uid: "target", status: "pending_review" },
  ...profiles,
});

test("internal backend assessment returns a conservative read-only dependency report", async () => {
  const db = mockDb(seed({
    "users/target": { uid: "target", role: "resident", communityId: "C1", approvalStatus: "approved" },
    "admins/target": { uid: "target", role: "admin", authorizedCommunityIds: ["C1", "C2"], isActive: true },
    "securityStaff/target": { uid: "target", role: "security", communityId: "C3", isActive: true },
  }));
  const report = await reviewAccountDeletionEligibilityCore({ db, auth, data: { requestId: "req-1" } });
  assert.deepEqual(report.roles.sort(), ["admins", "securityStaff", "users"]);
  assert.deepEqual(report.communities.sort(), ["C1", "C2", "C3"]);
  assert.ok(report.confirmedDependencies.includes("multiple_role_profiles"));
  assert.ok(report.unresolvedChecks.some((item) => item.check === "adminResponsibilities"));
  assert.ok(report.unresolvedChecks.some((item) => item.check === "securityResponsibilities"));
  assert.ok(report.unresolvedChecks.some((item) => item.check.startsWith("query:payments.")));
  assert.ok(report.unresolvedChecks.some((item) => item.check === "credentialIndexCompleteness"));
  assert.equal(report.eligible, false);
  assert.equal(report.deletionPerformed, false);
  assert.deepEqual(db.writes, []);
});

test("visitor and financial references are reported as active or preserved, never mutated", async () => {
  const data = seed({
    "users/target": { uid: "target", role: "resident", communityId: "C1" },
  });
  const db = mockDb(data);
  // This mock intentionally lacks query support: incomplete collection discovery
  // must produce explicit query blockers rather than clearance.
  const report = await reviewAccountDeletionEligibilityCore({ db, auth, data: { requestId: "req-1" } });
  assert.equal(report.eligible, false);
  assert.ok(report.coverage.unresolvedReferenceClasses.some((name) => name.startsWith("query:")));
  assert.deepEqual(db.writes, []);
});

test("unauthenticated or unauthorized reviewer is rejected", async () => {
  const db = mockDb(seed());
  await assert.rejects(reviewAccountDeletionEligibilityForRequestCore({ db, auth: null, data: { requestId: "req-1" } }), HttpsError);
  await assert.rejects(reviewAccountDeletionEligibilityForRequestCore({ db, auth: { ...auth, uid: "ordinary" }, data: { requestId: "req-1" } }), HttpsError);
});

test("callable export remains App Check enforced", () => {
  const source = fs.readFileSync(require.resolve("../src/index"), "utf8");
  assert.match(source, /exports\.reviewAccountDeletionEligibility = accountDeletionCallable/);
  assert.match(source, /onCall\(\{ region: REGION, enforceAppCheck: true \}/);
});

test("invalid, missing and nonexistent requests fail closed", async () => {
  const db = mockDb(seed());
  await assert.rejects(reviewAccountDeletionEligibilityCore({ db, auth, data: {} }), HttpsError);
  await assert.rejects(reviewAccountDeletionEligibilityCore({ db, auth, data: { requestId: "missing" } }), HttpsError);
  await assert.rejects(reviewAccountDeletionEligibilityCore({ db, auth, data: { requestId: "req-1", uid: "spoof" } }), HttpsError);
});

test("missing profiles and read failures never grant eligibility", async () => {
  const empty = await reviewAccountDeletionEligibilityCore({ db: mockDb(seed()), auth, data: { requestId: "req-1" } });
  assert.equal(empty.eligible, false);
  assert.ok(empty.unresolvedChecks.some((item) => item.check === "identity"));
  const broken = await reviewAccountDeletionEligibilityCore({ db: mockDb(seed(), { failRead: "users/target" }), auth, data: { requestId: "req-1" } });
  assert.equal(broken.eligible, false);
  assert.equal(broken.profileDiscoveryComplete, false);
  assert.ok(broken.unresolvedChecks.some((item) => item.check === "profile:users"));
  assert.equal(broken.deletionPerformed, false);
});

test("internal fulfillment coordinator derives UID, recomputes eligibility and performs zero writes while blocked", async () => {
  const db = mockDb(seed({ "users/target": { uid: "target", role: "resident", communityId: "C1" } }));
  const result = await coordinateAccountDeletionFulfillmentCore({ db, auth, data: { requestId: "req-1" } });
  assert.equal(result.uid, "target");
  assert.equal(result.status, "blocked");
  assert.equal(result.completed, false);
  assert.equal(result.deletionPerformed, false);
  assert.ok(result.blockers.length > 0);
  assert.deepEqual(db.writes, []);
});

test("coordinator rejects client eligibility, UID, role, or extra execution claims", async () => {
  const db = mockDb(seed());
  for (const data of [
    { requestId: "req-1", eligible: true },
    { requestId: "req-1", uid: "attacker" },
    { requestId: "req-1", role: "superAdmin" },
    { requestId: "req-1", confirm: true },
  ]) await assert.rejects(coordinateAccountDeletionFulfillmentCore({ db, auth, data }), HttpsError);
  assert.deepEqual(db.writes, []);
});

test("single-role Resident with verified empty financial/audit queries resolves only those reference classes", async () => {
  const db = financialDb({ "users/target": { uid: "target", role: "resident", communityId: "C1", identityProofStoragePath: null } });
  const report = await reviewAccountDeletionEligibilityCore({ db, auth, data: { requestId: "req-1" } });
  assert.equal(report.roles.length, 1);
  assert.equal(report.communities.includes("C1"), true);
  assert.equal(report.eligible, false);
  assert.ok(report.coverage.verifiedAbsence.some((item) => item.type === "financial_records"));
  assert.ok(report.coverage.verifiedAbsence.some((item) => item.type === "audit_history"));
  assert.ok(!report.unresolvedChecks.some((item) => item.check === "financialRetentionCondition"));
  assert.ok(!report.unresolvedChecks.some((item) => item.check === "auditRetentionCondition"));
  assert.ok(!report.unresolvedChecks.some((item) => item.check === "otherReferences"));
  assert.deepEqual(db.writes, []);
});

function financialDb(rows, failCollection) {
  const data = seed({ "users/target": { uid: "target", role: "resident", communityId: "C1" }, ...rows });
  const writes = [];
  const getRef = (path) => ({ path, async get() { const v = data[path]; return { exists: v !== undefined, data: () => v }; } });
  const makeRef = (path) => ({ ...getRef(path), parent: { parent: path.split("/").length >= 4 ? getRef(path.split("/").slice(0, 2).join("/")) : null } });
  const makeQuery = (name, group = false) => {
    const filters = [];
    let max = Infinity;
    const query = {
      where(field, op, value) { filters.push({ field, op, value }); return query; },
      limit(value) { max = value; return query; },
      async get() {
        const failureKey = group ? `collectionGroup:${name}` : name;
        if (failCollection === name || failCollection === failureKey) throw Error("read failed");
        const docs = Object.entries(data).filter(([path, row]) => {
          const parts = path.split("/");
          const inCollection = group ? parts.length >= 4 && parts[parts.length - 2] === name : parts.length === 2 && parts[0] === name;
          return inCollection && filters.every(({ field, op, value }) => op === "array-contains" ? Array.isArray(row[field]) && row[field].includes(value) : row[field] === value);
        }).slice(0, max).map(([path, row]) => ({ id: path.split("/").at(-1), ref: makeRef(path), data: () => row }));
        return { docs };
      },
    };
    return query;
  };
  return {
    writes,
    collection(name) { return { doc(id) { const ref = makeRef(`${name}/${id}`); ref.set = () => writes.push("set"); ref.update = () => writes.push("update"); ref.delete = () => writes.push("delete"); return ref; }, where: (field, op, value) => makeQuery(name).where(field, op, value), limit: (value) => makeQuery(name).limit(value), get: () => makeQuery(name).get() }; },
    collectionGroup(name) { return makeQuery(name, true); },
  };
}

function v2Bill({ id, communityId = "C1", period = "2026-01", outstanding = 0, status = "paid" }) {
  const amountMinor = 10000;
  const creditAppliedMinor = 0;
  const paidAmountMinor = amountMinor - outstanding;
  const flatId = `flat-${communityId}`;
  const billId = monthlyBillIdV2(communityId, flatId, period);
  return { id: billId, schemaVersion: 2, billingKind: "recurring", currency: "INR", communityId, residentId: "target",
    userId: "target", billingPeriod: period, flatId: `flat-${communityId}`, buildingId: `building-${communityId}`,
    billingBatchId: `batch-${communityId}-${period}`, amountMinor, paidAmountMinor, creditAppliedMinor,
    currentRevisionId: "revision-1", appliedBatchRevisionId: "revision-1", revisionNo: 1,
    dueDate: { toMillis: () => 1 }, createdAt: { toMillis: () => 1 }, dueDateKey: `${period}-28`, timeZone: "Asia/Manila",
    outstandingAmountMinor: outstanding, status, };
}

function v2Account(communityId) {
  const id = billingLedger.residentFinancialAccountId({ communityId, residentId: "target" });
  return { id, schemaVersion: 2, communityId, residentId: "target", currency: "INR", version: 0,
    availableCreditMinor: 0, createdAt: 1, updatedAt: 1 };
}

const emptyImageBucket = { async getFiles() { return [[], null]; } };
const deletionReport = (db, bucket = emptyImageBucket) => reviewAccountDeletionEligibilityCore({ db, bucket, auth, data: { requestId: "req-1" } });

test("clean Resident has verified absence for all newly covered reference classes", async () => {
  const db = financialDb({});
  const report = await deletionReport(db);
  const classes = report.coverage.additionalResidentReferences;
  assert.deepEqual(Object.values(classes).filter((item) => item && typeof item === "object" && "status" in item).map((item) => item.status), Array(8).fill("VERIFIED_ABSENT"));
  assert.deepEqual(classes.retryableChecks, []);
  assert.ok(!report.unresolvedChecks.some((item) => item.check === "otherReferences"));
  assert.ok(!report.unresolvedChecks.some((item) => item.check.startsWith("reference:")));
  assert.deepEqual(db.writes, []);
});

test("shared chat and resolved SOS history are preserved; owned dependencies remain visible", async () => {
  const db = financialDb({
    "bookings/b1": { userId: "target", communityId: "C1", status: "cancelled" },
    "chatRequests/cr1": { senderId: "target", receiverId: "other", communityId: "C1", status: "accepted" },
    "sosAlerts/s1": { residentUid: "target", communityId: "C1", status: "resolved" },
    "sosNotificationEvents/se1": { residentUid: "target", communityId: "C1", status: "resolved" },
    "notifications/n1": { recipientId: "target", communityId: "C1", audience: "resident" },
    "notificationDevices/d1": { uid: "target", communityId: "C1", active: true },
    "residentImageDrafts/i1": { ownerId: "target", communityId: "C1", state: "draft" },
  });
  const report = await deletionReport(db);
  const classes = report.coverage.additionalResidentReferences;
  for (const name of ["bookings", "chatRequests", "sos", "notifications", "imagesAndStorage"]) {
    assert.equal(classes[name].status, name === "imagesAndStorage" ? "UNKNOWN_OR_UNSUPPORTED" : "MATCHING_REFERENCE", name);
    if (["bookings", "notifications", "imagesAndStorage"].includes(name)) {
      assert.ok(report.unresolvedChecks.some((item) => item.check === `reference:${name}`), name);
    } else if (name === "sos") {
      assert.ok(!report.unresolvedChecks.some((item) => item.check === "reference:sos" || item.check === "activeSos"));
    } else {
      assert.ok(!report.unresolvedChecks.some((item) => item.check === "reference:chatRequests"));
    }
  }
  assert.deepEqual(db.writes, []);
});

test("cross-community booking reference is found and reported with its community", async () => {
  const db = financialDb({ "amenityBookings/b-cross": { userId: "target", communityId: "C2", status: "completed" } });
  const report = await deletionReport(db);
  assert.equal(report.coverage.additionalResidentReferences.bookings.status, "MATCHING_REFERENCE");
  assert.ok(report.coverage.additionalResidentReferences.bookings.communities.includes("C2"));
  assert.deepEqual(db.writes, []);
});

test("failed collection and nested-message discovery are UNKNOWN_OR_UNSUPPORTED", async () => {
  for (const [failure, className] of [["bookings", "bookings"], ["collectionGroup:messages", "chatMessages"]]) {
    const report = await deletionReport(financialDb({}, failure));
    assert.equal(report.coverage.additionalResidentReferences[className].status, "UNKNOWN_OR_UNSUPPORTED", failure);
  }
});

test("legacy missing community and orphan nested chat messages stay blocked", async () => {
  const db = financialDb({
    "amenityBookings/legacy": { userId: "target", status: "pending" },
    "chats/c1": { participantIds: ["target"] },
    "chats/c1/messages/m1": { senderId: "target", body: "preserved" },
  });
  const report = await deletionReport(db);
  assert.equal(report.coverage.additionalResidentReferences.bookings.status, "UNKNOWN_OR_UNSUPPORTED");
  assert.equal(report.coverage.additionalResidentReferences.chats.status, "MATCHING_REFERENCE");
  assert.equal(report.coverage.additionalResidentReferences.chatMessages.status, "MATCHING_REFERENCE");
  assert.deepEqual(db.writes, []);
});

test("known Resident Storage prefixes are checked and matching objects block", async () => {
  const bucket = { async getFiles({ prefix }) { return prefix === "resident_images/C1/target/profile/" ? [[{ name: `${prefix}image.jpg` }], null] : [[], null]; } };
  const report = await deletionReport(financialDb({}), bucket);
  assert.equal(report.coverage.additionalResidentReferences.imagesAndStorage.status, "MATCHING_REFERENCE");
  assert.ok(report.unresolvedChecks.some((item) => item.check === "reference:imagesAndStorage"));
});

test("community enumeration checks image prefixes outside the profile community", async () => {
  const bucket = { async getFiles({ prefix }) { return prefix === "private_images/C2/target/profile/" ? [[{ name: `${prefix}image.jpg` }], null] : [[], null]; } };
  const report = await deletionReport(financialDb({ "communities/C2": { isActive: true } }), bucket);
  assert.equal(report.coverage.additionalResidentReferences.imagesAndStorage.status, "MATCHING_REFERENCE");
});

test("legacy notice read receipts are covered through their parent notice community", async () => {
  const db = financialDb({
    "notices/n1": { communityId: "C1", targetFlats: [] },
    "notices/n1/readBy/target": { userId: "target", readAt: new Date() },
  });
  const report = await deletionReport(db);
  assert.equal(report.coverage.additionalResidentReferences.notifications.status, "MATCHING_REFERENCE");
  assert.deepEqual(report.coverage.additionalResidentReferences.notifications.records.map((item) => item.path), ["notices/n1/readBy/target"]);
  assert.ok(report.unresolvedChecks.some((item) => item.check === "reference:notifications"));
  assert.deepEqual(db.writes, []);
});

test("incomplete community discovery keeps storage reference coverage UNKNOWN", async () => {
  const report = await deletionReport(financialDb({}, "communities"));
  assert.equal(report.coverage.additionalResidentReferences.imagesAndStorage.status, "UNKNOWN_OR_UNSUPPORTED");
  assert.equal(report.coverage.additionalResidentReferences.imagesAndStorage.communityDiscoveryComplete, false);
});

test("billing assessment verifies zero dues across multiple periods and communities", async () => {
  const bill1 = v2Bill({ period: "2025-12" });
  const bill2 = v2Bill({ period: "2026-01" });
  const bill3 = v2Bill({ communityId: "C2", period: "2026-01" });
  const db = financialDb({
    "users/target": { uid: "target", role: "resident", communityId: "C1" },
    [`bills/${bill1.id}`]: bill1,
    [`bills/${bill2.id}`]: bill2,
    [`bills/${bill3.id}`]: bill3,
    [`residentFinancialAccounts/${v2Account("C1").id}`]: v2Account("C1"),
    [`residentFinancialAccounts/${v2Account("C2").id}`]: v2Account("C2"),
  });
  const report = await reviewAccountDeletionEligibilityCore({ db, auth, data: { requestId: "req-1" } });
  assert.equal(report.coverage.billingObligations.verifiedZero, true);
  assert.deepEqual(report.coverage.billingObligations.obligations, []);
  assert.equal(report.coverage.billingObligations.bills, 3);
  assert.equal(report.coverage.billingObligations.accounts, 2);
  assert.deepEqual(db.writes, []);
});

test("positive V2 balances in separate billing periods are outstanding obligations", async () => {
  const bill1 = v2Bill({ period: "2026-01", outstanding: 4200, status: "pending" });
  const bill2 = v2Bill({ period: "2026-02", outstanding: 1800, status: "partially_paid" });
  const db = financialDb({
    [`bills/${bill1.id}`]: bill1,
    [`bills/${bill2.id}`]: bill2,
    [`residentFinancialAccounts/${v2Account("C1").id}`]: v2Account("C1"),
  });
  const report = await reviewAccountDeletionEligibilityCore({ db, auth, data: { requestId: "req-1" } });
  assert.deepEqual(report.coverage.billingObligations.obligations.map((item) => [item.billingPeriod, item.outstandingMinor]), [["2026-01", 4200], ["2026-02", 1800]]);
  assert.ok(report.unresolvedChecks.some((item) => item.check === "outstandingBillingObligations"));
  assert.equal(report.coverage.billingObligations.verifiedZero, false);
  assert.deepEqual(db.writes, []);
});

test("legacy V1 pending bill blocks while a fully marked paid bill is zero", async () => {
  const pending = financialDb({ "bills/legacy-due": { id: "legacy-due", communityId: "C1", residentId: "target", flatId: "f1", amount: 125.5, status: "pending", month: 1, year: 2026 } });
  const pendingReport = await reviewAccountDeletionEligibilityCore({ db: pending, auth, data: { requestId: "req-1" } });
  assert.equal(pendingReport.coverage.billingObligations.obligations[0].amount, 125.5);
  assert.ok(pendingReport.unresolvedChecks.some((item) => item.check === "outstandingBillingObligations"));

  const paid = financialDb({ "bills/legacy-paid": { id: "legacy-paid", communityId: "C1", residentId: "target", flatId: "f1", amount: 125.5, status: "paid", paidAt: new Date(), month: 1, year: 2026 } });
  const paidReport = await reviewAccountDeletionEligibilityCore({ db: paid, auth, data: { requestId: "req-1" } });
  assert.equal(paidReport.coverage.billingObligations.verifiedZero, true);
  assert.deepEqual(paidReport.coverage.billingObligations.obligations, []);
});

test("missing or inconsistent bill evidence is UNKNOWN and remains blocked", async () => {
  const db = financialDb({
    "bills/unknown": { id: "unknown", communityId: "C1", residentId: "target", schemaVersion: 2,
      billingKind: "recurring", currency: "INR", billingPeriod: "2026-01", amountMinor: 1000,
      paidAmountMinor: 0, creditAppliedMinor: 0, outstandingAmountMinor: 0, status: "pending" },
  });
  const report = await reviewAccountDeletionEligibilityCore({ db, auth, data: { requestId: "req-1" } });
  assert.equal(report.coverage.billingObligations.verifiedZero, false);
  assert.ok(report.unresolvedChecks.some((item) => item.check === "billingEvidenceAmbiguous"));
  assert.deepEqual(db.writes, []);
});

test("malformed resident financial account evidence is UNKNOWN", async () => {
  const account = v2Account("C1");
  account.availableCreditMinor = "0";
  const db = financialDb({ [`residentFinancialAccounts/${account.id}`]: account });
  const report = await reviewAccountDeletionEligibilityCore({ db, auth, data: { requestId: "req-1" } });
  assert.equal(report.coverage.billingObligations.verifiedZero, false);
  assert.ok(report.unresolvedChecks.some((item) => item.check === "billingEvidenceAmbiguous"));
  assert.deepEqual(db.writes, []);
});

test("billing query failures remain UNKNOWN and do not become zero", async () => {
  for (const collection of ["bills", "residentFinancialAccounts"]) {
    const db = financialDb({}, collection);
    const report = await reviewAccountDeletionEligibilityCore({ db, auth, data: { requestId: "req-1" } });
    assert.equal(report.coverage.billingObligations.verifiedZero, false, collection);
    assert.ok(report.unresolvedChecks.some((item) => item.check.startsWith(`query:${collection}.`)), collection);
    assert.deepEqual(db.writes, []);
  }
});

test("historical financial and immutable audit records are classified for preservation without mutation", async () => {
  const db = financialDb({
    "paymentTransactions/t1": { residentId: "target", communityId: "C1", status: "completed", amountMinor: 500 },
    "paymentAllocations/a1": { residentId: "target", communityId: "C1", status: "posted" },
    "auditLogs/l1": { actorUid: "target", targetId: "bill1", action: "payment.verify", communityId: "C1" },
  });
  const report = await reviewAccountDeletionEligibilityCore({ db, auth, data: { requestId: "req-1" } });
  assert.ok(report.coverage.preservedHistoricalReferences.some((item) => item.type === "financial_records"));
  assert.ok(report.coverage.preservedHistoricalReferences.some((item) => item.type === "audit_history"));
  assert.ok(!report.unresolvedChecks.some((item) => ["financialRetentionCondition", "auditRetentionCondition"].includes(item.check)));
  assert.equal(report.eligible, false); assert.equal(report.deletionPerformed, false); assert.deepEqual(db.writes, []);
});

test("pending financial submissions are active blockers and failed financial reads remain unresolved", async () => {
  const pending = financialDb({ "paymentProofsV2/p1": { userId: "target", communityId: "C1", status: "pending" } });
  const report = await reviewAccountDeletionEligibilityCore({ db: pending, auth, data: { requestId: "req-1" } });
  assert.ok(report.unresolvedChecks.some((item) => item.check === "activeFinancialSubmissions"));
  assert.equal(report.eligible, false); assert.deepEqual(pending.writes, []);
  const failed = financialDb({}, "paymentTransactions");
  const failedReport = await reviewAccountDeletionEligibilityCore({ db: failed, auth, data: { requestId: "req-1" } });
  assert.ok(failedReport.unresolvedChecks.some((item) => item.check === "query:paymentTransactions.residentId"));
  assert.ok(!failedReport.coverage.verifiedAbsence.some((item) => item.type === "financial_records"));
  assert.equal(failedReport.eligible, false); assert.deepEqual(failed.writes, []);
  const failedAudit = financialDb({}, "auditLogs");
  const failedAuditReport = await reviewAccountDeletionEligibilityCore({ db: failedAudit, auth, data: { requestId: "req-1" } });
  assert.ok(failedAuditReport.unresolvedChecks.some((item) => item.check === "query:auditLogs.actorUid"));
  assert.ok(!failedAuditReport.coverage.verifiedAbsence.some((item) => item.type === "audit_history"));
  assert.equal(failedAuditReport.eligible, false);
  assert.deepEqual(failedAudit.writes, []);
});

test("verified absence of complaints and chats is reported only after supported reads succeed", async () => {
  const db = financialDb({});
  const report = await reviewAccountDeletionEligibilityCore({ db, auth, data: { requestId: "req-1" } });
  assert.ok(report.coverage.verifiedAbsence.some((item) => item.type === "complaints"));
  assert.ok(report.coverage.verifiedAbsence.some((item) => item.type === "chat_history"));
  assert.ok(!report.unresolvedChecks.some((item) => ["complaintAttachments", "chatIdentityDisposition"].includes(item.check)));
  assert.equal(report.eligible, false);
  assert.deepEqual(db.writes, []);
});

test("verified empty supported flat aliases and onboarding links resolve the bounded legacy blocker", async () => {
  const db = financialDb({ "users/target": { uid: "target", role: "resident", communityId: "C1", residentId: "legacy-resident-7" } });
  const report = await reviewAccountDeletionEligibilityCore({ db, auth, data: { requestId: "req-1" } });
  assert.equal(report.coverage.legacyReferenceCoverage.status, "verified_absence_in_supported_fields");
  assert.ok(report.coverage.verifiedAbsence.some((item) => item.type === "legacy_resident_references"));
  assert.ok(!report.unresolvedChecks.some((item) => item.check === "legacyResidentReferences"));
  assert.ok(!report.unresolvedChecks.some((item) => item.check === "otherReferences"));
  assert.equal(report.eligible, false);
  assert.deepEqual(db.writes, []);
});

test("matching UID, legacy flat aliases and claimed onboarding are reported and remain blocked", async () => {
  const db = financialDb({
    "users/target": { uid: "target", role: "resident", communityId: "C1", residentId: "legacy-resident-7" },
    "flats/flat-uid": { communityId: "C1", residentUid: "target" },
    "flats/flat-array": { communityId: "C1", residentIds: ["target"] },
    "flats/flat-legacy-scalar": { communityId: "C1", residentIds: "target" },
    "flats/flat-legacy": { communityId: "C1", residentId: "legacy-resident-7" },
    "residentOnboarding/on-1": { communityId: "C1", claimedByUid: "target" },
  });
  const report = await reviewAccountDeletionEligibilityCore({ db, auth, data: { requestId: "req-1" } });
  assert.equal(report.coverage.legacyReferenceCoverage.status, "matching_references_found");
  assert.deepEqual(report.coverage.legacyReferenceCoverage.matchingFlatIds.sort(), ["flat-array", "flat-legacy", "flat-legacy-scalar", "flat-uid"]);
  assert.deepEqual(report.coverage.legacyReferenceCoverage.matchingOnboardingIds, ["on-1"]);
  assert.ok(report.unresolvedChecks.some((item) => item.check === "unitMemberships"));
  assert.ok(report.unresolvedChecks.some((item) => item.check === "residentOnboardingReferences"));
  assert.ok(!report.coverage.verifiedAbsence.some((item) => item.type === "legacy_resident_references"));
  assert.equal(report.eligible, false);
  assert.deepEqual(db.writes, []);
});

test("ambiguous multi-resident and conflicting legacy unit links remain blocked", async () => {
  const db = financialDb({
    "users/target": { uid: "target", role: "resident", communityId: "C1" },
    "flats/ambiguous": { communityId: "C1", residentUid: "target", residentIds: ["target", "other-resident"] },
    "flats/conflict": { communityId: "C1", residentUserId: "other-resident", residentUid: "target" },
  });
  const report = await reviewAccountDeletionEligibilityCore({ db, auth, data: { requestId: "req-1" } });
  assert.equal(report.coverage.legacyReferenceCoverage.status, "matching_references_found");
  assert.ok(report.unresolvedChecks.some((item) => item.check === "unitMemberships"));
  assert.equal(report.eligible, false);
  assert.deepEqual(db.writes, []);
});

test("old flat records with only names and unit labels are not attributed to a UID", async () => {
  const db = financialDb({
    "users/target": { uid: "target", role: "resident", communityId: "C1", name: "Resident Example", flatId: null },
    "flats/old-label-only": { communityId: "C1", residentName: "Resident Example", flatLabel: "A-101", status: "occupied" },
  });
  const report = await reviewAccountDeletionEligibilityCore({ db, auth, data: { requestId: "req-1" } });
  assert.equal(report.coverage.legacyReferenceCoverage.status, "verified_absence_in_supported_fields");
  assert.ok(!report.unresolvedChecks.some((item) => item.check === "unitMemberships"));
  assert.ok(!report.unresolvedChecks.some((item) => item.check === "otherReferences"));
  assert.equal(report.eligible, false);
  assert.deepEqual(db.writes, []);
});

test("flat query failure and stale current flat pointer keep legacy coverage incomplete", async () => {
  const failed = financialDb({ "users/target": { uid: "target", role: "resident", communityId: "C1" } }, "flats");
  const failedReport = await reviewAccountDeletionEligibilityCore({ db: failed, auth, data: { requestId: "req-1" } });
  assert.equal(failedReport.coverage.legacyReferenceCoverage.status, "incomplete");
  assert.ok(failedReport.unresolvedChecks.some((item) => item.check === "legacyResidentReferences"));
  assert.ok(!failedReport.coverage.verifiedAbsence.some((item) => item.type === "legacy_resident_references"));
  assert.deepEqual(failed.writes, []);

  const stale = financialDb({ "users/target": { uid: "target", role: "resident", communityId: "C1", flatId: "flat-current" } });
  const staleReport = await reviewAccountDeletionEligibilityCore({ db: stale, auth, data: { requestId: "req-1" } });
  assert.ok(staleReport.unresolvedChecks.some((item) => item.check === "residentFlatPointerMismatch"));
  assert.equal(staleReport.coverage.legacyReferenceCoverage.status, "incomplete");
  assert.ok(!staleReport.coverage.verifiedAbsence.some((item) => item.type === "legacy_resident_references"));
  assert.deepEqual(stale.writes, []);
});

test("cross-community flat references and unknown collection coverage never clear eligibility", async () => {
  const db = financialDb({
    "users/target": { uid: "target", role: "resident", communityId: "C1" },
    "flats/foreign-flat": { communityId: "C2", residentUserId: "target" },
  });
  const report = await reviewAccountDeletionEligibilityCore({ db, auth, data: { requestId: "req-1" } });
  assert.ok(report.unresolvedChecks.some((item) => item.check === "unitMemberships"));
  assert.ok(!report.unresolvedChecks.some((item) => item.check === "otherReferences"));
  assert.equal(report.eligible, false);
  assert.deepEqual(db.writes, []);
});

test("matching historical financial and immutable audit rows stay preserved and blocked without disposition", async () => {
  const original = {
    "paymentTransactions/t1": { residentId: "target", communityId: "C1", status: "completed", amountMinor: 1250 },
    "auditLogs/a1": { actorUid: "target", targetId: "bill-1", action: "payment.posted", immutable: true },
  };
  const db = financialDb(original);
  const report = await reviewAccountDeletionEligibilityCore({ db, auth, data: { requestId: "req-1" } });
  assert.ok(!report.unresolvedChecks.some((item) => ["financialRetentionCondition", "auditRetentionCondition"].includes(item.check)));
  assert.ok(!report.coverage.verifiedAbsence.some((item) => item.type === "financial_records" || item.type === "audit_history"));
  const auditRetention = report.coverage.preservedHistoricalReferences.find((item) => item.type === "audit_history");
  assert.deepEqual(auditRetention.records.map((item) => item.id), ["a1"]);
  assert.deepEqual(db.writes, []);
  assert.deepEqual(original["paymentTransactions/t1"], { residentId: "target", communityId: "C1", status: "completed", amountMinor: 1250 });
  assert.deepEqual(original["auditLogs/a1"], { actorUid: "target", targetId: "bill-1", action: "payment.posted", immutable: true });
  assert.equal(report.eligible, false);
  assert.equal(report.deletionPerformed, false);
});

function assertDiscoveryIndex(collectionGroup, fieldPath) {
  const config = JSON.parse(fs.readFileSync(require.resolve('../../firestore.indexes.json'), 'utf8'));
  const field = config.fieldOverrides.find((item) => item.collectionGroup === collectionGroup && item.fieldPath === fieldPath);
  assert.ok(field, `${collectionGroup}.${fieldPath} must declare its missing group index`);
  assert.ok(field.indexes.some((index) => index.queryScope === 'COLLECTION_GROUP' && index.order === 'ASCENDING'));
  // Preserve the existing automatic collection indexes while enabling the group query.
  for (const order of ['ASCENDING', 'DESCENDING']) {
    assert.ok(field.indexes.some((index) => index.queryScope === 'COLLECTION' && index.order === order));
  }
  assert.ok(field.indexes.some((index) => index.queryScope === 'COLLECTION' && index.arrayConfig === 'CONTAINS'));
}

test('reported chat discovery: missing group indexes block while verified shared history is retained', async () => {
  assertDiscoveryIndex('messages', 'senderId');
  assertDiscoveryIndex('messages', 'receiverId');
  const missingIndex = await deletionReport(financialDb({}, 'collectionGroup:messages'));
  assert.equal(missingIndex.coverage.additionalResidentReferences.chatMessages.status, 'UNKNOWN_OR_UNSUPPORTED');
  assert.equal(missingIndex.eligible, false);
  const orphan = await deletionReport(financialDb({'chats/missing/messages/m1': {senderId: 'target'}}));
  assert.equal(orphan.coverage.additionalResidentReferences.chatMessages.status, 'UNKNOWN_OR_UNSUPPORTED');
  const supported = financialDb({
    'chats/cross': {communityId: 'C2', participantIds: ['target']},
    'chats/cross/messages/m1': {senderId: 'target', text: 'Retained history'},
  });
  const report = await deletionReport(supported);
  assert.equal(report.coverage.additionalResidentReferences.chatMessages.status, 'MATCHING_REFERENCE');
  assert.ok(!report.unresolvedChecks.some((item) => item.check === 'reference:chatMessages'));
  assert.deepEqual(supported.writes, []);
});

test('reported notification discovery: declare readBy index; retain parent and device scope checks', async () => {
  assertDiscoveryIndex('readBy', 'userId');
  const device = {'notificationDevices/device': {uid: 'target', communityId: 'C1'}};
  const missingIndex = await deletionReport(financialDb(device, 'collectionGroup:readBy'));
  assert.equal(missingIndex.coverage.additionalResidentReferences.notifications.status, 'UNKNOWN_OR_UNSUPPORTED');
  const orphan = await deletionReport(financialDb({'notices/missing/readBy/target': {userId: 'target'}}));
  assert.equal(orphan.coverage.additionalResidentReferences.notifications.status, 'UNKNOWN_OR_UNSUPPORTED');
  const badScope = await deletionReport(financialDb({'notificationDevices/device': {uid: 'target'}}));
  assert.equal(badScope.coverage.additionalResidentReferences.notificationDevices.status, 'UNKNOWN_OR_UNSUPPORTED');
  const supported = financialDb({
    ...device, 'notices/n1': {communityId: 'C1'},
    'notices/n1/readBy/target': {userId: 'target', readAt: new Date()},
  });
  const report = await deletionReport(supported);
  assert.equal(report.coverage.additionalResidentReferences.notifications.status, 'MATCHING_REFERENCE');
  assert.equal(report.coverage.additionalResidentReferences.notifications.count, 1);
  assert.equal(report.coverage.additionalResidentReferences.notificationDevices.status, 'UNKNOWN_OR_UNSUPPORTED');
  const unsupportedParent = await deletionReport(financialDb({'otherParent/n1/readBy/target': {userId:'target'}}));
  assert.equal(unsupportedParent.coverage.additionalResidentReferences.notifications.status, 'UNKNOWN_OR_UNSUPPORTED');
  assert.equal(report.eligible, false, 'Known notification references still need a safe disposition');
  assert.deepEqual(supported.writes, []);
});

test('reported review status: classify existing technical blockers without resubmission or writes', async () => {
  const verificationCompletedAt = new Date('2026-10-27T07:11:10.414Z');
  for (const [reasons, expected] of [
    [['chatMessages discovery or parent relationship could not be fully verified.', 'Notification discovery failed, exceeded its bound, or found records without community scope.'], 'processing'],
    [['One or more supported bills have a positive outstanding amount.'], 'community_admin'],
    [['Verified financial handover is not supported by the existing Admin finding workflow; this request remains pending.'], 'processing'],
  ]) {
    const db = financialDb({'accountDeletionRequests/req-1': {
      uid: 'target', requestId: 'req-1', status: 'pending_review', communityScopeVerified: true,
      processingBlockers: reasons, verificationCompletedAt,
      ...(expected === 'community_admin' ? { financialReviewRequired: true } : {}),
    }});
    const {request} = await getAccountDeletionRequestStatusCore({db, auth});
    assert.equal(request.requestId, 'req-1');
    assert.equal(request.status, 'pending_review');
    assert.equal(request.reviewType, expected);
    assert.equal(request.verificationCompletedAt, verificationCompletedAt);
    assert.deepEqual(request.reasons, reasons);
    assert.deepEqual(db.writes, [], 'Status refresh must not process or modify a request');
  }
});
