const test = require("node:test");
const assert = require("node:assert/strict");
const {randomUUID} = require("node:crypto");
const {initializeApp} = require("firebase-admin/app");
const {Timestamp, getFirestore} = require("firebase-admin/firestore");

const projectId = "demo-hominode-sec006";
const authHost = process.env.FIREBASE_AUTH_EMULATOR_HOST;
const firestoreHost = process.env.FIRESTORE_EMULATOR_HOST;
const functionsHost = process.env.FUNCTIONS_EMULATOR_HOST || "127.0.0.1:5001";
const enabled = Boolean(authHost && firestoreHost && process.env.SEC006_CALLABLE_EMULATOR === "1");
const secretFailureMode = process.env.SEC006_EXPECT_SECRET_FAILURE === "1";
const appCheckToken = "synthetic-sec006-emulator-app-check-token";
let app;
let db;

test.before(() => {
  if (!enabled) return;
  app = initializeApp({projectId}, `sec006-callables-${randomUUID()}`);
  db = getFirestore(app);
});

test.after(async () => {
  if (app) await app.delete();
});

async function requestJson(url, options = {}) {
  const response = await fetch(url, {
    ...options,
    headers: {"content-type": "application/json", ...(options.headers || {})},
  });
  const body = await response.json();
  return {response, body};
}

async function phoneAuth(phoneNumber) {
  const base = `http://${authHost}/identitytoolkit.googleapis.com/v1`;
  const sent = await requestJson(`${base}/accounts:sendVerificationCode?key=fake-api-key`, {
    method: "POST", body: JSON.stringify({phoneNumber, recaptchaToken: "synthetic-emulator-recaptcha"}),
  });
  assert.equal(sent.response.ok, true, JSON.stringify(sent.body));
  const codesResponse = await requestJson(`http://${authHost}/emulator/v1/projects/${projectId}/verificationCodes`);
  const verification = codesResponse.body.verificationCodes
    ?.filter((entry) => entry.phoneNumber === phoneNumber)
    .sort((left, right) => Number(right.createdAt) - Number(left.createdAt))[0];
  assert.ok(verification?.code, `No emulator verification code returned for ${phoneNumber}`);
  const signedIn = await requestJson(`${base}/accounts:signInWithPhoneNumber?key=fake-api-key`, {
    method: "POST",
    body: JSON.stringify({sessionInfo: sent.body.sessionInfo, code: verification.code}),
  });
  assert.equal(signedIn.response.ok, true, JSON.stringify(signedIn.body));
  return {...signedIn.body, phoneNumber};
}

async function callable(name, data, idToken, {includeAppCheck = true} = {}) {
  const headers = {};
  if (idToken) headers.authorization = `Bearer ${idToken}`;
  if (includeAppCheck) headers["x-firebase-appcheck"] = appCheckToken;
  return requestJson(`http://${functionsHost}/${projectId}/asia-southeast1/${name}`, {
    method: "POST", headers, body: JSON.stringify({data}),
  });
}

function unwrap(result, label) {
  assert.equal(result.response.ok, true, `${label}: ${JSON.stringify(result.body)}`);
  assert.ok(result.body.result, `${label} returned no callable result`);
  return result.body.result;
}

test("visitor callable wrappers enforce request contracts through Auth, Functions and Firestore Emulators", {
  skip: !enabled || secretFailureMode,
}, async (t) => {
  const suffix = randomUUID();
  const communityId = `community-${suffix}`;
  const foreignCommunityId = `foreign-${suffix}`;
  const resident = await phoneAuth("+639171234567");
  const foreignResident = await phoneAuth("+639181234567");
  const security = await phoneAuth("+639191234567");
  const residentUid = resident.localId;
  const foreignResidentUid = foreignResident.localId;
  const securityUid = security.localId;
  const flatId = `flat-${suffix}`;
  const foreignFlatId = `foreign-flat-${suffix}`;

  await Promise.all([
    db.collection("communities").doc(communityId).set({isActive: true}),
    db.collection("communities").doc(foreignCommunityId).set({isActive: true}),
    db.collection("users").doc(residentUid).set({
      uid: residentUid, role: "resident", phoneNumber: resident.phoneNumber, approvalStatus: "approved",
      status: "active", isActive: true, residentType: "owner", communityId, flatId, name: "Synthetic Host",
    }),
    db.collection("users").doc(foreignResidentUid).set({
      uid: foreignResidentUid, role: "resident", phoneNumber: foreignResident.phoneNumber,
      approvalStatus: "approved", status: "active", isActive: true, residentType: "owner",
      communityId: foreignCommunityId, flatId: foreignFlatId, name: "Foreign Synthetic Host",
    }),
    db.collection("flats").doc(flatId).set({
      communityId, status: "occupied", residentUserId: residentUid, flatLabel: "A-101",
    }),
    db.collection("flats").doc(foreignFlatId).set({
      communityId: foreignCommunityId, status: "occupied", residentUserId: foreignResidentUid,
      flatLabel: "B-204",
    }),
    db.collection("securityStaff").doc(securityUid).set({
      uid: securityUid, role: "security", phoneNumber: security.phoneNumber,
      communityId, isActive: true,
    }),
  ]);

  const unauthenticated = await callable("createVisitorInvitation", {
    visitorName: "Unauthenticated Guest", purpose: "Test", expectedArrival: Date.now() + 60_000,
  }, null);
  assert.equal(unauthenticated.response.ok, false);

  const appCheckProbe = await callable("createVisitorInvitation", {
    visitorName: "App Check Probe", purpose: "Test", expectedArrival: Date.now() + 60_000,
  }, resident.idToken, {includeAppCheck: false});
  assert.equal(appCheckProbe.response.ok, false,
    `Functions Emulator accepted a callable without App Check: ${JSON.stringify(appCheckProbe.body)}`);
  const appCheckStatus = appCheckProbe.body?.error?.status || "unknown";
  t.diagnostic(`Functions Emulator response without App Check header: ${appCheckStatus}; this does not verify production attestation.`);

  const create = unwrap(await callable("createVisitorInvitation", {
    visitorName: "Synthetic Visitor", purpose: "Callable integration", expectedArrival: Date.now() + 60_000,
  }, resident.idToken), "Resident invitation creation");
  assert.ok(create.visitorId && create.qrToken && create.visitorPassCode);
  const visitorRef = db.collection("visitors").doc(create.visitorId);
  const createdVisitor = (await visitorRef.get()).data();
  assert.equal(createdVisitor.hostUserId, residentUid);
  assert.equal(createdVisitor.communityId, communityId);
  assert.equal(createdVisitor.status, "expected");
  assert.equal(createdVisitor.isApproved, false);
  assert.equal("qrToken" in createdVisitor, false);
  assert.equal("visitorPassCode" in createdVisitor, false);

  const forged = await callable("createVisitorInvitation", {
    visitorName: "Forged Scope", purpose: "Test", expectedArrival: Date.now() + 60_000,
    hostUserId: foreignResidentUid, communityId: foreignCommunityId, flatId: foreignFlatId,
  }, resident.idToken);
  assert.equal(forged.response.ok, false);

  const retrieved = unwrap(await callable("getVisitorCredentials", {visitorId: create.visitorId}, resident.idToken),
    "Host credential retrieval");
  assert.equal(retrieved.qrToken, create.qrToken);
  assert.equal(retrieved.visitorPassCode, create.visitorPassCode.replaceAll("-", ""));
  const foreignRetrieval = await callable("getVisitorCredentials", {visitorId: create.visitorId}, foreignResident.idToken);
  assert.equal(foreignRetrieval.response.ok, false);
  const securityRetrieval = await callable("getVisitorCredentials", {visitorId: create.visitorId}, security.idToken);
  assert.equal(securityRetrieval.response.ok, false);

  const verified = unwrap(await callable("verifyVisitorCredential", {
    qrToken: create.qrToken, operationId: `callable-qr-${suffix}`,
  }, security.idToken), "Security QR verification");
  assert.equal(verified.status, "inside");
  const serialized = JSON.stringify(verified);
  for (const secret of [create.qrToken, create.visitorPassCode.replaceAll("-", "")]) {
    assert.equal(serialized.includes(secret), false);
  }
  assert.equal(/credentialHash|manualCode|qrToken|visitorPassCode/.test(serialized), false);
  const repeated = unwrap(await callable("verifyVisitorCredential", {
    qrToken: create.qrToken, operationId: `callable-qr-${suffix}`,
  }, security.idToken), "Idempotent QR retry");
  assert.equal(repeated.idempotent, true);
  assert.equal((await db.collection("visitorGateEvents").where("visitorId", "==", create.visitorId).get()).size, 1);

  const manualInvite = unwrap(await callable("createVisitorInvitation", {
    visitorName: "Manual Visitor", purpose: "Manual-code test", expectedArrival: Date.now() + 60_000,
  }, resident.idToken), "Manual-code invitation");
  const manualVerified = unwrap(await callable("verifyVisitorCredential", {
    manualCode: manualInvite.visitorPassCode, operationId: `callable-manual-${suffix}`,
  }, security.idToken), "Security manual-code verification");
  assert.equal(manualVerified.status, "inside");
  assert.equal(/credentialHash|manualCode|qrToken|visitorPassCode/.test(JSON.stringify(manualVerified)), false);

  const deniedInvite = unwrap(await callable("createVisitorInvitation", {
    visitorName: "Denied Visitor", purpose: "Deny path", expectedArrival: Date.now() + 60_000,
  }, resident.idToken), "Deny-entry invitation");
  const denied = unwrap(await callable("denyVisitorEntry", {
    visitorId: deniedInvite.visitorId, reason: "Synthetic test reason", operationId: `callable-deny-${suffix}`,
  }, security.idToken), "Security Deny Entry");
  assert.equal(denied.status, "denied");
  assert.equal((await visitorRef.get()).data().status, "inside");
  const deniedVisitor = (await db.collection("visitors").doc(deniedInvite.visitorId).get()).data();
  assert.equal(deniedVisitor.status, "expected");
  assert.equal(deniedVisitor.gateAccessStatus, "denied");

  const disabledInvite = unwrap(await callable("createVisitorInvitation", {
    visitorName: "Disabled Security Test", purpose: "Disabled actor", expectedArrival: Date.now() + 60_000,
  }, resident.idToken), "Disabled-account invitation");
  await db.collection("securityStaff").doc(securityUid).update({isActive: false});
  const disabled = await callable("verifyVisitorCredential", {
    qrToken: disabledInvite.qrToken, operationId: `callable-disabled-${suffix}`,
  }, security.idToken);
  assert.equal(disabled.response.ok, false);
  await db.collection("securityStaff").doc(securityUid).update({isActive: true});

  const foreignInvite = unwrap(await callable("createVisitorInvitation", {
    visitorName: "Foreign Visitor", purpose: "Wrong community", expectedArrival: Date.now() + 60_000,
  }, foreignResident.idToken), "Foreign-community invitation");
  const wrongCommunity = await callable("verifyVisitorCredential", {
    qrToken: foreignInvite.qrToken, operationId: `callable-foreign-${suffix}`,
  }, security.idToken);
  assert.equal(wrongCommunity.response.ok, false);

  const checkoutInvite = unwrap(await callable("createVisitorInvitation", {
    visitorName: "Checkout Visitor", purpose: "Checkout path", expectedArrival: Date.now() + 60_000,
  }, resident.idToken), "Checkout invitation");
  await callable("verifyVisitorCredential", {
    qrToken: checkoutInvite.qrToken, operationId: `callable-checkin-${suffix}`,
  }, security.idToken).then((result) => unwrap(result, "Checkout visitor check-in"));
  const checkout = unwrap(await callable("checkoutVisitors", {
    visitorIds: [checkoutInvite.visitorId, "missing-visitor"], operationId: `callable-checkout-${suffix}`,
  }, security.idToken), "Single/bulk checkout");
  assert.equal(checkout.succeeded, 1);
  assert.equal(checkout.failed, 1);
  assert.equal(checkout.results[0].success, true);
  assert.equal(checkout.results[1].success, false);
});

test("invalid HMAC secret produces a controlled callable failure without creating an invitation", {
  skip: !enabled || !secretFailureMode,
}, async () => {
  const suffix = randomUUID();
  const communityId = `secret-community-${suffix}`;
  const resident = await phoneAuth("+639171234567");
  const flatId = `secret-flat-${suffix}`;
  await Promise.all([
    db.collection("communities").doc(communityId).set({isActive: true}),
    db.collection("users").doc(resident.localId).set({
      uid: resident.localId, role: "resident", phoneNumber: resident.phoneNumber,
      approvalStatus: "approved", status: "active", isActive: true, residentType: "owner",
      communityId, flatId,
    }),
    db.collection("flats").doc(flatId).set({
      communityId, status: "occupied", residentUserId: resident.localId,
    }),
  ]);
  const before = await db.collection("visitors").where("communityId", "==", communityId).get();
  const result = await callable("createVisitorInvitation", {
    visitorName: "Secret Failure Guest", purpose: "Invalid secret", expectedArrival: Date.now() + 60_000,
  }, resident.idToken);
  assert.equal(result.response.ok, false);
  assert.equal(result.body?.error?.status, "FAILED_PRECONDITION", JSON.stringify(result.body));
  const after = await db.collection("visitors").where("communityId", "==", communityId).get();
  assert.equal(after.size, before.size);

  const security = await phoneAuth("+639191234567");
  const legacyVisitorId = `legacy-${suffix}`;
  await Promise.all([
    db.collection("securityStaff").doc(security.localId).set({
      uid: security.localId, role: "security", phoneNumber: security.phoneNumber,
      communityId, isActive: true,
    }),
    db.collection("visitors").doc(legacyVisitorId).set({
      communityId, hostUserId: resident.localId, visitorName: "Legacy Synthetic Visitor",
      status: "expected", isApproved: false, expectedArrival: Timestamp.fromMillis(Date.now()),
      actualArrival: null, departure: null,
    }),
  ]);
  const legacyResolve = await callable("resolveVisitorQr", {legacyVisitorId}, security.idToken);
  assert.equal(legacyResolve.response.ok, false);
  assert.equal(legacyResolve.body?.error?.status, "FAILED_PRECONDITION", JSON.stringify(legacyResolve.body));
  const legacyTransition = await callable("transitionVisitorFromQr", {
    visitorId: legacyVisitorId, legacyVisitorId, action: "approve",
  }, security.idToken);
  assert.equal(legacyTransition.response.ok, false);
  assert.equal(legacyTransition.body?.error?.status, "FAILED_PRECONDITION", JSON.stringify(legacyTransition.body));
});
