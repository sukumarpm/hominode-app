'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { sendModeratedChatMessageCore, moderateChatText } = require('../src/chat_message_moderation');

function setup() {
  const docs = new Map([
    ['chats/chat1', { type: 'admin', communityId: 'A', adminId: 'adminA', residentId: 'residentA', participants: ['adminA', 'residentA'] }],
    ['users/residentA', { name: 'Resident', isActive: true, role: 'resident', approvalStatus: 'approved', communityId: 'A' }],
    ['admins/adminA', { name: 'Admin', isActive: true, role: 'admin', authorizedCommunityIds: ['A'] }],
    ['users/outsider', { name: 'Outsider', isActive: true, role: 'resident', approvalStatus: 'approved', communityId: 'B' }],
  ]);
  const snapshot = path => ({ exists: docs.has(path), data: () => docs.get(path) });
  let writes = 0;
  const makeDoc = path => ({
    path, get: async () => snapshot(path),
    collection: name => ({ doc: id => makeDoc(path + '/' + name + '/' + id) }),
  });
  const db = {
    collection: name => ({ doc: id => makeDoc(name + '/' + id) }),
    runTransaction: async fn => fn({
      get: async ref => snapshot(ref.path),
      create: (ref, data) => { assert.equal(docs.has(ref.path), false); docs.set(ref.path, data); writes++; },
      update: (ref, patch) => { docs.set(ref.path, { ...docs.get(ref.path), ...patch }); writes++; },
    }),
  };
  return { docs, db, get writes() { return writes; }, fieldValue: { serverTimestamp: () => 'SERVER_TIME' } };
}
function args(input, auth = 'residentA', message = 'When is my bill due?', submissionId = 'fixedSubmission123') {
  return { db: input.db, fieldValue: input.fieldValue, auth: { uid: auth },
    data: { chatId: 'chat1', message, submissionId, isQuery: auth === 'residentA', queryType: 'billing' } };
}

test('allows normal messages and keeps context-sensitive reports', () => {
  assert.equal(moderateChatText('When is my bill due?').allowed, true);
  assert.equal(moderateChatText('I need to report sexual harassment').allowed, true);
  assert.equal(moderateChatText('sex').allowed, false);
  assert.equal(moderateChatText('I will kill you').allowed, false);
});
test('writes allowed resident query once with category', async () => {
  const input = setup();
  const result = await sendModeratedChatMessageCore(args(input));
  assert.equal(result.created, true);
  const saved = input.docs.get('chats/chat1/messages/fixedSubmission123');
  assert.equal(saved.message, 'When is my bill due?');
  assert.equal(saved.queryType, 'billing');
  assert.equal(saved.senderRole, 'resident');
  const again = await sendModeratedChatMessageCore(args(input));
  assert.equal(again.created, false);
  assert.equal(input.writes, 2);
});
test('allows admin replies using same policy', async () => {
  const input = setup();
  const result = await sendModeratedChatMessageCore(args(input, 'adminA'));
  assert.equal(result.created, true);
  assert.equal(input.docs.get('chats/chat1/messages/fixedSubmission123').senderRole, 'admin');
});
test('rejection does not write documents', async () => {
  const input = setup();
  await assert.rejects(sendModeratedChatMessageCore(args(input, 'residentA', 'sex')), { code: 'failed-precondition' });
  assert.equal(input.writes, 0);
});
test('rejects unauthorized and anonymous senders', async () => {
  const input = setup();
  await assert.rejects(sendModeratedChatMessageCore(args(input, 'outsider')), { code: 'permission-denied' });
  await assert.rejects(sendModeratedChatMessageCore({ ...args(input), auth: null }), { code: 'unauthenticated' });
  assert.equal(input.writes, 0);
});
test('rejects submission ID reuse with changed content', async () => {
  const input = setup();
  await sendModeratedChatMessageCore(args(input));
  await assert.rejects(sendModeratedChatMessageCore(args(input, 'residentA', 'Another message')), {code: 'already-exists'});
});
