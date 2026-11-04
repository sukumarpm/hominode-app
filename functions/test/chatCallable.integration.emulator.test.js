'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { initializeApp, deleteApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');

const projectId = 'demo-hominode-chat-moderation';
const base = 'http://127.0.0.1:9099';
const fnUrl = `http://127.0.0.1:5001/${projectId}/asia-southeast1/sendModeratedAdminChatMessage`;
const enabled = process.env.FIREBASE_AUTH_EMULATOR_HOST === '127.0.0.1:9099'
  && process.env.FIRESTORE_EMULATOR_HOST === '127.0.0.1:8080'
  && process.env.FIREBASE_FUNCTIONS_EMULATOR_HOST === '127.0.0.1:5001'
  && process.env.GCLOUD_PROJECT === projectId;

async function json(url, options = {}) {
  const response = await fetch(url, options);
  const body = await response.json();
  return { status: response.status, body };
}
async function post(url, body, headers = {}) {
  return json(url, {
    method: 'POST',
    headers: { 'content-type': 'application/json', ...headers },
    body: JSON.stringify(body),
  });
}
async function signInPhone(phoneNumber) {
  const start = await post(`${base}/identitytoolkit.googleapis.com/v1/accounts:sendVerificationCode?key=demo-key`, {
    phoneNumber, recaptchaToken: 'test-recaptcha-token',
  });
  assert.equal(start.status, 200, JSON.stringify(start.body));
  const codes = await json(`${base}/emulator/v1/projects/${projectId}/verificationCodes`);
  assert.equal(codes.status, 200);
  const code = codes.body.verificationCodes.find(c => c.phoneNumber === phoneNumber)?.sessionCode;
  assert.ok(code, 'Auth emulator should generate SMS code');
  const result = await post(`${base}/identitytoolkit.googleapis.com/v1/accounts:signInWithPhoneNumber?key=demo-key`, {
    sessionInfo: start.body.sessionInfo,
    code,
  });
  assert.equal(result.status, 200, JSON.stringify(result.body));
  assert.ok(result.body.idToken);
  return { uid: result.body.localId, token: result.body.idToken, phoneNumber };
}
async function call(token, data) {
  return post(fnUrl, { data }, token ? { Authorization: `Bearer ${token}` } : {});
}

test('real callable: phone auth, moderation, authorization, persistence and dedup', {skip: !enabled}, async () => {
  const app = initializeApp({projectId}, 'chat-callable-integration');
  try {
    const db = getFirestore(app);
    // A demo project and all three emulator variables are mandatory above.
    const resident = await signInPhone('+639178880001');
    const admin = await signInPhone('+639178880002');
    const outsider = await signInPhone('+639178880003');
    const chatId = 'chatCallableIntegration';
    await db.collection('communities').doc('TEST-A').set({isActive:true});
    await db.collection('users').doc(resident.uid).set({
      uid: resident.uid, phoneNumber: resident.phoneNumber, name:'Test Resident',
      role:'resident', communityId:'TEST-A', approvalStatus:'approved', isActive:true,
    });
    await db.collection('admins').doc(admin.uid).set({
      uid: admin.uid, phoneNumber: admin.phoneNumber, name:'Test Admin',
      role:'admin', authorizedCommunityIds:['TEST-A'], isActive:true,
    });
    await db.collection('users').doc(outsider.uid).set({
      uid: outsider.uid, phoneNumber: outsider.phoneNumber, name:'Outsider',
      role:'resident', communityId:'OTHER', approvalStatus:'approved', isActive:true,
    });
    await db.collection('chats').doc(chatId).set({
      type:'admin', communityId:'TEST-A', residentId:resident.uid, adminId:admin.uid,
      participants:[resident.uid,admin.uid], participantIds:[resident.uid,admin.uid],
      status:'open',
    });
    const input = (submissionId, message, isQuery=true) => ({
      chatId, submissionId, message, isQuery, ...(isQuery ? {queryType:'billing'} : {}),
    });
    const accepted = await call(resident.token, input('callable-accepted-001','When is my next bill due?'));
    assert.equal(accepted.status, 200, JSON.stringify(accepted.body));
    assert.equal(accepted.body.result?.created, true);
    assert.equal((await db.doc(`chats/${chatId}/messages/callable-accepted-001`).get()).data().queryType,'billing');

    const repeat = await call(resident.token, input('callable-accepted-001','When is my next bill due?'));
    assert.equal(repeat.status, 200, JSON.stringify(repeat.body));
    assert.equal(repeat.body.result?.created, false);

    const rejected = await call(resident.token, input('callable-rejected-001','sex'));
    assert.notEqual(rejected.status, 200);
    assert.equal((await db.doc(`chats/${chatId}/messages/callable-rejected-001`).get()).exists, false);

    const report = await call(resident.token, input('callable-report-001','I need to report sexual harassment'));
    assert.equal(report.status, 200, JSON.stringify(report.body));

    const reply = await call(admin.token, input('callable-admin-001','We are reviewing your request',false));
    assert.equal(reply.status, 200, JSON.stringify(reply.body));
    assert.equal((await db.doc(`chats/${chatId}/messages/callable-admin-001`).get()).data().senderRole,'admin');

    const other = await call(outsider.token, input('callable-outsider-001','Hello'));
    assert.notEqual(other.status, 200);
    assert.equal((await db.doc(`chats/${chatId}/messages/callable-outsider-001`).get()).exists, false);

    const unauth = await call(null, input('callable-unauth-001','Hello'));
    assert.equal(unauth.status,401);
  } finally {
    await deleteApp(app);
  }
});
