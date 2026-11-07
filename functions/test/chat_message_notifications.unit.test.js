'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const {chatNotificationTarget} = require('../src/chat_message_notifications');

const chat = {
  type:'admin', communityId:'TEST-A',
  residentId:'resident-1', adminId:'admin-1',
  participants:['resident-1','admin-1'],
};
const msg = (senderId, senderRole) =>
  ({senderId,senderRole,communityId:'TEST-A',moderationVersion:1});

test('moderated Resident message targets only its Admin', () => {
  assert.deepEqual(chatNotificationTarget(chat,msg('resident-1','resident')),
    {recipientUid:'admin-1',role:'admin',appId:'admin'});
});
test('moderated Admin reply targets only its Resident', () => {
  assert.deepEqual(chatNotificationTarget(chat,msg('admin-1','admin')),
    {recipientUid:'resident-1',role:'resident',appId:'resident'});
});
test('unmoderated or unrelated chat messages generate no notification', () => {
  assert.equal(chatNotificationTarget(chat,{...msg('resident-1','resident'),moderationVersion:undefined}),null);
  assert.equal(chatNotificationTarget(chat,{...msg('resident-1','resident'),communityId:'OTHER'}),null);
  assert.equal(chatNotificationTarget(chat,msg('other','resident')),null);
  assert.equal(chatNotificationTarget({...chat,type:'group',adminId:null},msg('resident-1','resident')),null);
  assert.equal(chatNotificationTarget({...chat,participants:['resident-1']},msg('resident-1','resident')),null);
});
