'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const {initializeTestEnvironment, assertSucceeds, assertFails} = require('@firebase/rules-unit-testing');
const enabled = Boolean(process.env.FIRESTORE_EMULATOR_HOST);
let env;
const phone = '+639170000000';

test.before(async () => {
  if (!enabled) return;
  env = await initializeTestEnvironment({
    projectId: 'demo-hominode-chat-moderation',
    firestore: {
      host: '127.0.0.1',
      port: Number(process.env.FIRESTORE_EMULATOR_HOST.split(':').pop()),
      rules: fs.readFileSync(path.join(__dirname, '../../firestore.rules'), 'utf8'),
    },
  });
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    const seed = [
      ['communities/A', {isActive: true}],
      ['communities/B', {isActive: true}],
      ['admins/adminA', {uid: 'adminA', role: 'admin', isActive: true, phoneNumber: phone, authorizedCommunityIds: ['A']}],
      ['admins/adminB', {uid: 'adminB', role: 'admin', isActive: true, phoneNumber: phone, authorizedCommunityIds: ['B']}],
      ['users/residentA', {uid: 'residentA', role: 'resident', isActive: true, approvalStatus: 'approved', communityId: 'A', residentType: 'owner', ownershipType: 'owner', phoneNumber: phone}],
      ['users/residentB', {uid: 'residentB', role: 'resident', isActive: true, approvalStatus: 'approved', communityId: 'B', residentType: 'owner', ownershipType: 'owner', phoneNumber: phone}],
      ['chats/support', {type: 'admin', communityId: 'A', participants: ['adminA', 'residentA'], adminId: 'adminA', residentId: 'residentA', status: 'open'}],
      ['chats/legacy', {communityId: 'A', participants: ['adminA', 'residentA'], adminId: 'adminA', residentId: 'residentA', status: 'open'}],
      ['chats/ordinary', {communityId: 'A', participants: ['adminA', 'residentA'], status: 'open'}],
      ['chats/support/messages/m1', {senderId: 'residentA', message: 'safe', readBy: ['residentA'], isRead: false}],
      ['chats/legacy/messages/m1', {senderId: 'residentA', message: 'safe', readBy: ['residentA'], isRead: false}],
    ];
    const batch = db.batch();
    for (const [p, value] of seed) batch.set(db.doc(p), value);
    await batch.commit();
  });
});
test.after(async () => { if (env) await env.cleanup(); });

const user = uid => env.authenticatedContext(uid, {phone_number: phone, firebase: {sign_in_provider: 'phone'}}).firestore();
const message = {senderId: 'residentA', message: 'content', isRead: false, timestamp: new Date()};

test('admin-support chats forbid direct creates, including legacy records', {skip: !enabled}, async () => {
  await assertFails(user('residentA').doc('chats/support/messages/m2').set(message));
  await assertFails(user('adminA').doc('chats/support/messages/m2').set({...message, senderId: 'adminA'}));
  await assertFails(user('residentA').doc('chats/legacy/messages/m2').set(message));
});

test('admin-support messages remain readable to members, not outsiders', {skip: !enabled}, async () => {
  await assertSucceeds(user('residentA').doc('chats/support/messages/m1').get());
  await assertSucceeds(user('adminA').doc('chats/support/messages/m1').get());
  await assertFails(user('residentB').doc('chats/support/messages/m1').get());
  await assertFails(user('adminB').doc('chats/support/messages/m1').get());
});

test('admin-support messages forbid content edits and deletes', {skip: !enabled}, async () => {
  await assertFails(user('residentA').doc('chats/support/messages/m1').update({message: 'bypass'}));
  await assertFails(user('adminA').doc('chats/support/messages/m1').delete());
  await assertFails(user('residentA').doc('chats/legacy/messages/m1').delete());
});

test('regular chat messages retain existing direct-write permission', {skip: !enabled}, async () => {
  await assertSucceeds(user('residentA').doc('chats/ordinary/messages/m2').set(message));
});

test('admin-support parent chat cannot be used to forge lastMessage', {skip: !enabled}, async () => {
  await assertFails(user('residentA').doc('chats/support').update({lastMessage: 'bypass'}));
  await assertFails(user('adminA').doc('chats/support').update({lastMessage: 'bypass'}));
});
