const test = require("node:test");
const assert = require("node:assert/strict");
const { randomUUID } = require("node:crypto");
const { initializeApp, deleteApp } = require("firebase-admin/app");
const { getFirestore, Timestamp } = require("firebase-admin/firestore");
const { getAuth } = require("firebase-admin/auth");
const { getStorage } = require("firebase-admin/storage");
const {
  revokeResidentVisitorCredentialsCore,
  cleanupResidentMembershipsAndBookingsCore,
  reviewAccountDeletionEligibilityCore,
  reviewResidentIdentityProofForDeletionCore,
  coordinateAccountDeletionFulfillmentCore,
  submitAccountDeletionRequestCore,
  reviewAndFulfillAccountDeletionCore,
} = require("../src/account_deletion_requests");

if (!process.env.FIRESTORE_EMULATOR_HOST) throw new Error("FIRESTORE_EMULATOR_HOST is required.");
if (process.env.GCLOUD_PROJECT !== "demo-hominode-deletion") throw new Error("GCLOUD_PROJECT must be demo-hominode-deletion.");

const app = initializeApp({ projectId: "demo-hominode-deletion" }, `deletion-cleanup-${randomUUID()}`);
const db = getFirestore(app);
const firebaseAuth = getAuth(app);
const bucket = getStorage(app).bucket("demo-hominode-deletion.appspot.com");
const suite = test; // Emulator transaction tests run serially within this file.
suite.after(async () => deleteApp(app));

async function requestAndResident({ communityId, flatId }) {
  const uid = `resident-${randomUUID()}`;
  const requestId = `request-${randomUUID()}`;
  await db.collection("communities").doc(communityId).set({ communityName: "Deletion emulator fixture", isActive: true });
  await db.collection("accountDeletionRequests").doc(requestId).set({ uid, communityId, communityScopeVerified: true, reviewStatus: "handover_complete_pending_eligibility", reviewFinding: "handover_complete" });
  await db.collection("users").doc(uid).set({ uid, role: "resident", communityId, flatId });
  return { uid, requestId };
}
async function deleteFixture(collection, id) { await db.collection(collection).doc(id).delete(); }

async function cleanDeletionRequestFixture() {
  const communityId = `C-${randomUUID()}`;
  const uid = `resident-${randomUUID()}`;
  const requestId = `request-${randomUUID()}`;
  const flatId = `flat-${randomUUID()}`;
  await db.collection("communities").doc(communityId).set({ communityName: "Deletion emulator fixture", isActive: true });
  await db.collection("users").doc(uid).set({ uid, role: "resident", communityId, flatId });
  await db.collection("flats").doc(flatId).set({ communityId, residentUserId: uid });
  await db.collection("accountDeletionRequests").doc(requestId).set({
    uid, communityId, communityScopeVerified: true, status: "approved",
    reviewStatus: "handover_complete_pending_eligibility", reviewFinding: "handover_complete",
  });
  await firebaseAuth.createUser({ uid, email: `${uid}@example.invalid`, password: "Deletion-test-only-123!" });
  return { uid, requestId, communityId, flatId };
}

async function cleanupDeletionRequestFixture(fixture) {
  const { uid, requestId, communityId } = fixture;
  const requestRef = db.collection("accountDeletionRequests").doc(requestId);
  const processing = await requestRef.collection("processing").get();
  for (const doc of processing.docs) await doc.ref.delete();
  await deleteFixture("users", uid);
  const relatedFlats = await db.collection("flats").where("residentUserId", "==", uid).get();
  for (const doc of relatedFlats.docs) await doc.ref.delete();
  await deleteFixture("flats", fixture.flatId);
  if (fixture.identityProofPath) await bucket.file(fixture.identityProofPath).delete({ ignoreNotFound: true }).catch(() => {});
  for (const collection of ["visitors", "visitorHostCredentials", "visitorGateCredentialIndex", "amenity_bookings", "bookings"]) {
    for (const field of ["hostUserId", "userId", "residentId"]) {
      const result = await db.collection(collection).where(field, "==", uid).get();
      for (const doc of result.docs) await doc.ref.delete();
    }
  }
  await deleteFixture("accountDeletionRequests", requestId);
  await deleteFixture("communities", communityId);
  try { await firebaseAuth.deleteUser(uid); } catch (error) { if (error.code !== "auth/user-not-found") throw error; }
}

suite("Resident submission automatically deletes profile and Auth without Super Admin", async () => {
  if (!process.env.FIREBASE_AUTH_EMULATOR_HOST || !process.env.FIREBASE_STORAGE_EMULATOR_HOST) {
    throw new Error("Auth and Storage emulators are required for the fulfillment wiring test.");
  }
  const uid = `resident-${randomUUID()}`;
  const communityId = `C-${randomUUID()}`;
  let requestId;
  try {
    await db.collection("communities").doc(communityId).set({ isActive: true });
    await db.collection("users").doc(uid).set({ uid, role: "resident", communityId });
    await firebaseAuth.createUser({ uid, email: `${uid}@example.invalid`, password: "Deletion-test-only-123!" });
    let authDeleteCalls = 0;
    const authLast = {
      getUser: (targetUid) => firebaseAuth.getUser(targetUid),
      async deleteUser(targetUid) {
        assert.equal((await db.collection("users").doc(targetUid).get()).exists, false);
        const requests = await db.collection("accountDeletionRequests").where("uid", "==", targetUid).get();
        assert.equal(requests.size, 1);
        requestId = requests.docs[0].id;
        const profileStep = await requests.docs[0].ref.collection("processing").doc("residentProfile").get();
        assert.equal(profileStep.data().status, "completed");
        authDeleteCalls++;
        await firebaseAuth.deleteUser(targetUid);
      },
    };
    const submitted = await submitAccountDeletionRequestCore({ db, bucket, firebaseAuth: authLast,
      auth: { uid, token: { auth_time: Math.floor(Date.now() / 1000) } }, data: { sourceApp: "resident", requestId: "client-spoof", uid: "other" } });
    requestId = submitted.requestId;
    assert.equal(submitted.status, "completed", JSON.stringify(submitted));
    assert.equal((await db.collection("users").doc(uid).get()).exists, false);
    await assert.rejects(firebaseAuth.getUser(uid), (error) => error.code === "auth/user-not-found");
    const request = (await db.collection("accountDeletionRequests").doc(requestId).get()).data();
    assert.equal(request.completionVerified, true);
    assert.equal((await reviewAndFulfillAccountDeletionCore({ db, bucket, firebaseAuth: authLast, data: { requestId } })).status, "completed");
    assert.equal(authDeleteCalls, 1);
  } finally {
    if (requestId) {
      const requestRef = db.collection("accountDeletionRequests").doc(requestId);
      const progress = await requestRef.collection("processing").get();
      for (const step of progress.docs) await step.ref.delete();
      await requestRef.delete();
    }
    await db.collection("users").doc(uid).delete();
    await db.collection("communities").doc(communityId).delete();
    try { await firebaseAuth.deleteUser(uid); } catch (error) { if (error.code !== "auth/user-not-found") throw error; }
  }
});

suite("internal fulfillment deletes a clean emulator Resident and reconciles partial Auth failure", async () => {
  const fixture = await cleanDeletionRequestFixture();
  fixture.identityProofPath = `residentIdentityProofs/${fixture.communityId}/${fixture.uid}/proof.jpg`;
  const visitorId = `visitor-${randomUUID()}`;
  const visitorCredentialRef = db.collection("visitorHostCredentials").doc(visitorId);
  const visitorIndexRef = db.collection("visitorGateCredentialIndex").doc(`hash-${randomUUID()}`);
  const futureBookingRef = db.collection("amenity_bookings").doc(`booking-${randomUUID()}`);
  const historicBookingRef = db.collection("amenity_bookings").doc(`booking-${randomUUID()}`);
  const historicVisitorId = `visitor-${randomUUID()}`;
  try {
    await db.collection("users").doc(fixture.uid).update({ identityProofStoragePath: fixture.identityProofPath });
    await bucket.file(fixture.identityProofPath).save(Buffer.from("synthetic identity proof"), { contentType: "image/jpeg" });
    const proofReview = await reviewResidentIdentityProofForDeletionCore({
      db, bucket,
      data: { requestId: fixture.requestId, decision: "APPROVED_FOR_DELETION", justification: "Synthetic emulator-only proof cleanup.", legalRetentionReviewed: true, legalReviewReference: "synthetic-emulator-review", reviewCondition: "No legal hold applies to synthetic data." },
    });
    assert.equal(proofReview.deletionPerformed, false);
    await db.collection("visitors").doc(visitorId).set({ hostUserId: fixture.uid, communityId: fixture.communityId, status: "expected", isApproved: false, expectedArrival: Timestamp.fromMillis(Date.now() + 86400000), visitorName: "Synthetic visitor history" });
    await visitorCredentialRef.set({ hostUserId: fixture.uid, communityId: fixture.communityId });
    await visitorIndexRef.set({ visitorId, hostUserId: fixture.uid, communityId: fixture.communityId, credentialType: "qr" });
    await futureBookingRef.set({ userId: fixture.uid, communityId: fixture.communityId, date: Timestamp.fromMillis(Date.now() + 86400000), status: "confirmed" });
    await historicBookingRef.set({ userId: fixture.uid, communityId: fixture.communityId, date: Timestamp.fromMillis(Date.now() - 86400000), status: "confirmed" });
    await db.collection("visitors").doc(historicVisitorId).set({ hostUserId: fixture.uid, communityId: fixture.communityId, status: "departed", actualArrival: Timestamp.fromMillis(Date.now() - 7200000), departure: Timestamp.fromMillis(Date.now() - 3600000), checkedOutBy: "security-emulator" });
    const eligibility = await reviewAccountDeletionEligibilityCore({ db, bucket, data: { requestId: fixture.requestId } });
    assert.equal(eligibility.eligible, false);
    assert.ok(eligibility.unresolvedChecks.some((item) => item.check === "futureVisitors"));
    assert.ok(eligibility.unresolvedChecks.some((item) => item.check === "unitMemberships"));
    assert.ok(eligibility.unresolvedChecks.some((item) => item.check === "activeBookings"));

    const authFailureAfterDelete = {
      getUser: (uid) => firebaseAuth.getUser(uid),
      async deleteUser(uid) {
        await firebaseAuth.deleteUser(uid);
        const error = new Error("Simulated process interruption after Auth delete.");
        error.code = "auth/internal-error";
        throw error;
      },
    };
    const partial = await coordinateAccountDeletionFulfillmentCore({ db, firebaseAuth: authFailureAfterDelete, bucket, data: { requestId: fixture.requestId } });
    assert.equal(partial.status, "reconciliation_required", JSON.stringify({ blockers: partial.blockers, bookingStatus: (await futureBookingRef.get()).data()?.status, cleanupStatus: (await db.collection("accountDeletionRequests").doc(fixture.requestId).collection("processing").doc("membershipAndBookingCleanup").get()).data()?.status }));
    assert.equal((await db.collection("users").doc(fixture.uid).get()).exists, false, JSON.stringify({ blockers: partial.blockers, steps: partial.executedSteps }));
    assert.equal((await db.collection("flats").doc(fixture.flatId).get()).data().residentUserId, null);
    assert.equal((await futureBookingRef.get()).data().status, "cancelled");
    assert.equal((await historicBookingRef.get()).data().status, "confirmed");
    assert.equal((await db.collection("visitors").doc(visitorId).get()).data().status, "cancelled");
    assert.equal((await visitorCredentialRef.get()).exists, false);
    assert.equal((await visitorIndexRef.get()).exists, false);
    assert.equal((await db.collection("visitors").doc(historicVisitorId).get()).exists, true);
    assert.notEqual((await db.collection("accountDeletionRequests").doc(fixture.requestId).get()).data().status, "completed");
    await assert.rejects(firebaseAuth.getUser(fixture.uid), (error) => error.code === "auth/user-not-found");

    const completed = await coordinateAccountDeletionFulfillmentCore({ db, firebaseAuth, bucket, data: { requestId: fixture.requestId } });
    assert.equal(completed.status, "completed", JSON.stringify(completed.blockers));
    assert.equal(completed.completed, true);
    assert.equal((await db.collection("users").doc(fixture.uid).get()).exists, false);
    await assert.rejects(firebaseAuth.getUser(fixture.uid), (error) => error.code === "auth/user-not-found");
    const request = (await db.collection("accountDeletionRequests").doc(fixture.requestId).get()).data();
    assert.equal(request.status, "completed");
    assert.equal(request.completionVerified, true);
    const profileStep = (await db.collection("accountDeletionRequests").doc(fixture.requestId).collection("processing").doc("residentProfile").get()).data();
    const authStep = (await db.collection("accountDeletionRequests").doc(fixture.requestId).collection("processing").doc("firebaseAuth").get()).data();
    assert.equal(profileStep.status, "completed");
    assert.equal(authStep.status, "completed");
    assert.equal((await bucket.file(fixture.identityProofPath).exists())[0], false);
    assert.equal((await db.collection("accountDeletionRequests").doc(fixture.requestId).collection("processing").doc("identityProof").get()).data().status, "completed");
    const repeated = await coordinateAccountDeletionFulfillmentCore({ db, firebaseAuth, bucket, data: { requestId: fixture.requestId } });
    assert.equal(repeated.status, "completed");
    assert.equal(repeated.completed, true);
  } finally {
    await cleanupDeletionRequestFixture(fixture);
  }
});

suite("matching unsupported booking references block internal fulfillment", async () => {
  const fixture = await cleanDeletionRequestFixture();
  try {
    await db.collection("bookings").doc(`booking-${randomUUID()}`).set({ userId: fixture.uid, communityId: fixture.communityId, status: "cancelled" });
    const result = await coordinateAccountDeletionFulfillmentCore({ db, firebaseAuth, bucket, data: { requestId: fixture.requestId } });
    assert.equal(result.status, "blocked");
    assert.ok(result.blockers.some((reason) => /Booking records reference/.test(reason)));
    assert.equal((await db.collection("users").doc(fixture.uid).get()).exists, true);
    assert.equal((await db.collection("accountDeletionRequests").doc(fixture.requestId).get()).data().status, "approved");
    assert.equal((await firebaseAuth.getUser(fixture.uid)).uid, fixture.uid);
  } finally { await cleanupDeletionRequestFixture(fixture); }
});

suite("unknown Storage evidence blocks internal fulfillment without deleting identity", async () => {
  const fixture = await cleanDeletionRequestFixture();
  try {
    const result = await coordinateAccountDeletionFulfillmentCore({ db, firebaseAuth, bucket: null, data: { requestId: fixture.requestId } });
    assert.equal(result.status, "blocked");
    assert.ok(result.blockers.some((reason) => /Image metadata or Storage prefix discovery is unavailable/.test(reason)));
    assert.equal((await db.collection("users").doc(fixture.uid).get()).exists, true);
    assert.equal((await firebaseAuth.getUser(fixture.uid)).uid, fixture.uid);
  } finally { await cleanupDeletionRequestFixture(fixture); }
});

suite("profile deletion interruption revalidates from request-bound identity evidence before Auth deletion", async () => {
  const fixture = await cleanDeletionRequestFixture();
  try {
    const cleanup = await cleanupResidentMembershipsAndBookingsCore({ db, data: { requestId: fixture.requestId } });
    assert.equal(cleanup.complete, true);
    const profileEvidence = { uid: fixture.uid, role: "resident", communityId: fixture.communityId, flatId: fixture.flatId, residentId: null };
    await db.collection("accountDeletionRequests").doc(fixture.requestId).collection("processing").doc("residentProfile").set({
      requestId: fixture.requestId, uid: fixture.uid, status: "deleting", communityId: fixture.communityId,
      profilePath: `users/${fixture.uid}`, profileEvidence,
    });
    await deleteFixture("users", fixture.uid);
    const savedProfileStep = (await db.collection("accountDeletionRequests").doc(fixture.requestId).collection("processing").doc("residentProfile").get()).data();
    const afterProfileDeletionEligibility = await reviewAccountDeletionEligibilityCore({ db, bucket, data: { requestId: fixture.requestId }, profileOverride: savedProfileStep.profileEvidence });
    assert.equal(afterProfileDeletionEligibility.roles.includes("users"), true, JSON.stringify({ step: savedProfileStep, unresolved: afterProfileDeletionEligibility.unresolvedChecks }));
    const membershipStep = (await db.collection("accountDeletionRequests").doc(fixture.requestId).collection("processing").doc("membershipAndBookingCleanup").get()).data();
    const flatAfterCleanup = (await db.collection("flats").doc(fixture.flatId).get()).data();
    assert.equal(afterProfileDeletionEligibility.eligible, true, JSON.stringify({ blockers: afterProfileDeletionEligibility.blockers, savedProfileStep, membershipProgress: { status: membershipStep?.status, requestId: membershipStep?.requestId, uid: membershipStep?.uid }, flat: { communityId: flatAfterCleanup?.communityId, residentUserId: flatAfterCleanup?.residentUserId, residentUid: flatAfterCleanup?.residentUid, residentId: flatAfterCleanup?.residentId, residentIds: flatAfterCleanup?.residentIds } }));
    const completed = await coordinateAccountDeletionFulfillmentCore({ db, firebaseAuth, bucket, data: { requestId: fixture.requestId } });
    assert.equal(completed.status, "completed", JSON.stringify({ blockers: completed.blockers, checks: completed.unresolvedChecks }));
    assert.equal((await db.collection("users").doc(fixture.uid).get()).exists, false);
    await assert.rejects(firebaseAuth.getUser(fixture.uid), (error) => error.code === "auth/user-not-found");
    assert.equal((await db.collection("accountDeletionRequests").doc(fixture.requestId).get()).data().completionVerified, true);
  } finally { await cleanupDeletionRequestFixture(fixture); }
});

suite("documented identity-proof legal hold blocks account deletion", async () => {
  const fixture = await cleanDeletionRequestFixture();
  fixture.identityProofPath = `residentIdentityProofs/${fixture.communityId}/${fixture.uid}/held-proof.jpg`;
  try {
    await db.collection("users").doc(fixture.uid).update({ identityProofStoragePath: fixture.identityProofPath });
    await bucket.file(fixture.identityProofPath).save(Buffer.from("synthetic held proof"), { contentType: "image/jpeg" });
    await reviewResidentIdentityProofForDeletionCore({
      db, bucket,
      data: { requestId: fixture.requestId, decision: "LEGAL_HOLD", justification: "Synthetic test verifies legal hold enforcement.", reviewCondition: "Retain until case closure." },
    });
    const result = await coordinateAccountDeletionFulfillmentCore({ db, firebaseAuth, bucket, data: { requestId: fixture.requestId } });
    assert.equal(result.status, "blocked");
    assert.ok(result.blockers.some((reason) => /documented legal hold/.test(reason)));
    assert.equal((await db.collection("users").doc(fixture.uid).get()).exists, true);
    assert.equal((await firebaseAuth.getUser(fixture.uid)).uid, fixture.uid);
    assert.equal((await bucket.file(fixture.identityProofPath).exists())[0], true);
  } finally { await cleanupDeletionRequestFixture(fixture); }
});

suite("Firestore emulator confirms clean Resident absence across added reference classes", async () => {
  const communityId = `C-${randomUUID()}`;
  const { uid, requestId } = await requestAndResident({ communityId, flatId: null });
  const report = await reviewAccountDeletionEligibilityCore({
    db,
    bucket: { async getFiles() { return [[], null]; } },
    data: { requestId },
  });
  for (const [name, coverage] of Object.entries(report.coverage.additionalResidentReferences)) {
    assert.equal(coverage.status, "VERIFIED_ABSENT", name);
  }
  assert.equal(report.eligible, true, JSON.stringify(report.unresolvedChecks));
  assert.ok(!report.unresolvedChecks.some((item) => item.check === "otherReferences"));
  await deleteFixture("accountDeletionRequests", requestId);
  await deleteFixture("users", uid);
});

suite("visitor cleanup commits credential and index deletion while preserving history", async () => {
  const communityId = `C-${randomUUID()}`;
  const { uid, requestId } = await requestAndResident({ communityId, flatId: "unused" });
  const visitorId = `V-${randomUUID()}`;
  const visitorRef = db.collection("visitors").doc(visitorId);
  const credentialRef = db.collection("visitorHostCredentials").doc(visitorId);
  const indexRef = db.collection("visitorGateCredentialIndex").doc(`hash-${randomUUID()}`);
  await visitorRef.set({ hostUserId: uid, communityId, status: "expected", isApproved: false, expectedArrival: Timestamp.fromMillis(Date.now() + 60 * 60 * 1000), visitorName: "Guest" });
  await credentialRef.set({ hostUserId: uid, communityId });
  await indexRef.set({ visitorId, hostUserId: uid, communityId, credentialType: "qr" });
  const beforeVisitor = (await visitorRef.get()).data();
  await revokeResidentVisitorCredentialsCore({ db, data: { requestId } });
  assert.equal((await credentialRef.get()).exists, false);
  assert.equal((await indexRef.get()).exists, false);
  assert.deepEqual((await visitorRef.get()).data().visitorName, beforeVisitor.visitorName);
  await deleteFixture("visitors", visitorId); await deleteFixture("accountDeletionRequests", requestId); await deleteFixture("users", uid);
});

suite("visitor ownership mismatch and repeated revocation are safe", async () => {
  const communityId = `C-${randomUUID()}`;
  const { uid, requestId } = await requestAndResident({ communityId, flatId: "unused" });
  const visitorId = `V-${randomUUID()}`;
  const visitorRef = db.collection("visitors").doc(visitorId);
  const credentialRef = db.collection("visitorHostCredentials").doc(visitorId);
  const indexRef = db.collection("visitorGateCredentialIndex").doc(`hash-${randomUUID()}`);
  await visitorRef.set({ hostUserId: uid, communityId, status: "expected", isApproved: false, expectedArrival: Timestamp.fromMillis(Date.now() + 60 * 60 * 1000) });
  await credentialRef.set({ hostUserId: "other-user", communityId });
  await indexRef.set({ visitorId, hostUserId: uid, communityId });
  const mismatch = await revokeResidentVisitorCredentialsCore({ db, data: { requestId } });
  assert.equal(mismatch.complete, false);
  assert.equal(mismatch.blockers.length, 1);
  assert.equal((await credentialRef.get()).exists, true);
  assert.equal((await indexRef.get()).exists, true);
  await credentialRef.set({ hostUserId: uid, communityId });
  await revokeResidentVisitorCredentialsCore({ db, data: { requestId } });
  await revokeResidentVisitorCredentialsCore({ db, data: { requestId } });
  assert.equal((await credentialRef.get()).exists, false);
  assert.equal((await indexRef.get()).exists, false);
  await deleteFixture("visitors", visitorId); await deleteFixture("accountDeletionRequests", requestId); await deleteFixture("users", uid);
});

suite("membership cleanup cancels future booking, preserves history and unrelated resident", async () => {
  const communityId = `C-${randomUUID()}`;
  const flatId = `F-${randomUUID()}`;
  const { uid, requestId } = await requestAndResident({ communityId, flatId });
  const otherUid = `other-${randomUUID()}`;
  await db.collection("users").doc(otherUid).set({ uid: otherUid, communityId, flatId: `other-flat-${randomUUID()}` });
  const flatRef = db.collection("flats").doc(flatId);
  const futureRef = db.collection("amenity_bookings").doc(`B-${randomUUID()}`);
  const pastRef = db.collection("amenity_bookings").doc(`B-${randomUUID()}`);
  const otherFlatRef = db.collection("flats").doc(`other-flat-${randomUUID()}`);
  await flatRef.set({ communityId, residentUserId: uid });
  await otherFlatRef.set({ communityId, residentUserId: otherUid });
  await futureRef.set({ userId: uid, communityId, date: Timestamp.fromMillis(Date.now() + 86400000), status: "confirmed" });
  await pastRef.set({ userId: uid, communityId, date: Timestamp.fromMillis(Date.now() - 86400000), status: "confirmed" });
  await cleanupResidentMembershipsAndBookingsCore({ db, data: { requestId } });
  assert.equal((await flatRef.get()).data().residentUserId, null);
  assert.equal((await futureRef.get()).data().status, "cancelled");
  assert.equal((await pastRef.get()).data().status, "confirmed");
  assert.equal((await otherFlatRef.get()).data().residentUserId, otherUid);
  await deleteFixture("flats", flatId); await deleteFixture("flats", otherFlatRef.id);
  await deleteFixture("amenity_bookings", futureRef.id); await deleteFixture("amenity_bookings", pastRef.id);
  await deleteFixture("accountDeletionRequests", requestId); await deleteFixture("users", uid); await deleteFixture("users", otherUid);
});

suite("ambiguous booking preflight leaves membership and booking unchanged", async () => {
  const communityId = `C-${randomUUID()}`;
  const flatId = `F-${randomUUID()}`;
  const { uid, requestId } = await requestAndResident({ communityId, flatId });
  const flatRef = db.collection("flats").doc(flatId);
  const bookingRef = db.collection("amenity_bookings").doc(`B-${randomUUID()}`);
  await flatRef.set({ communityId, residentUserId: uid });
  await bookingRef.set({ userId: uid, communityId: "wrong-community", date: Timestamp.fromMillis(Date.now() + 86400000), status: "confirmed" });
  const result = await cleanupResidentMembershipsAndBookingsCore({ db, data: { requestId } });
  assert.equal(result.complete, false);
  assert.equal((await flatRef.get()).data().residentUserId, uid);
  assert.equal((await bookingRef.get()).data().status, "confirmed");
  await deleteFixture("flats", flatId); await deleteFixture("amenity_bookings", bookingRef.id);
  await deleteFixture("accountDeletionRequests", requestId); await deleteFixture("users", uid);
});

suite("allocation release keeps canonical unit/building and clears legacy occupant links", async () => {
  const fixture = await cleanDeletionRequestFixture();
  const buildingId = `building-${randomUUID()}`;
  try {
    await db.collection("buildings").doc(buildingId).set({communityId: fixture.communityId, name: "Retained", occupied: 1, vacant: 0});
    await db.collection("users").doc(fixture.uid).update({residentId: "legacy-resident"});
    await db.collection("flats").doc(fixture.flatId).update({buildingId, status: "occupied", residentId: "legacy-resident"});
    const result = await coordinateAccountDeletionFulfillmentCore({db, bucket, firebaseAuth, data: {requestId: fixture.requestId}});
    assert.equal(result.status, "completed", JSON.stringify(result));
    const flat = (await db.collection("flats").doc(fixture.flatId).get()).data();
    assert.equal(flat.status, "vacant");
    assert.equal(flat.residentId, null);
    assert.equal(flat.buildingId, buildingId);
    const building = (await db.collection("buildings").doc(buildingId).get()).data();
    assert.equal(building.occupied, 0);
    assert.equal(building.vacant, 1);
    assert.equal(building.name, "Retained");
    assert.equal((await coordinateAccountDeletionFulfillmentCore({db, bucket, firebaseAuth, data: {requestId: fixture.requestId}})).status, "completed");
  } finally {
    await cleanupDeletionRequestFixture(fixture);
    await deleteFixture("buildings", buildingId);
  }
});

suite("registration rejection releases only its claimed reservation with real transactions", async () => {
  const {rejectResidentRegistrationCore} = require("../src/resident_identity");
  const {residentOnboardingId} = require("../src/resident_import_ids");
  const communityId = `C-${randomUUID()}`;
  const uid = `resident-${randomUUID()}`;
  const adminId = `admin-${randomUUID()}`;
  const buildingId = `building-${randomUUID()}`;
  const flatId = `flat-${randomUUID()}`;
  const phone = "+639171100000";
  const onboardingId = residentOnboardingId(communityId, phone);
  try {
    await db.collection("communities").doc(communityId).set({isActive: true});
    await db.collection("admins").doc(adminId).set({uid: adminId, role: "admin", isActive: true, authorizedCommunityIds: [communityId]});
    await db.collection("buildings").doc(buildingId).set({communityId, reserved: 1, vacant: 0});
    await db.collection("flats").doc(flatId).set({communityId, buildingId, status: "reserved", reservedOnboardingId: onboardingId});
    await db.collection("users").doc(uid).set({uid, role: "resident", communityId, buildingId, flatId, phoneNumber: phone, approvalStatus: "pending", isActive: false});
    await db.collection("residentOnboarding").doc(onboardingId).set({communityId, buildingId, flatId, claimedByUid: uid, status: "claimed"});
    const context = {db, auth: {uid: adminId, token: {phone_number: phone, firebase: {sign_in_provider: "phone"}}}, data: {communityId, userId: uid}};
    assert.equal((await rejectResidentRegistrationCore(context)).status, "rejected");
    assert.equal((await db.collection("flats").doc(flatId).get()).data().status, "vacant");
    assert.equal((await db.collection("buildings").doc(buildingId).get()).data().reserved, 0);
    assert.equal((await db.collection("residentOnboarding").doc(onboardingId).get()).data().flatId, undefined);
    await db.collection("flats").doc(flatId).update({status: "occupied", residentUserId: "other"});
    assert.equal((await rejectResidentRegistrationCore(context)).idempotent, true);
    assert.equal((await db.collection("flats").doc(flatId).get()).data().residentUserId, "other");
  } finally {
    for (const [collection, id] of [["communities", communityId], ["admins", adminId], ["buildings", buildingId], ["flats", flatId], ["users", uid], ["residentOnboarding", onboardingId]]) await deleteFixture(collection, id);
  }
});
