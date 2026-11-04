'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { getOrCreateResidentAdminChatCore } = require('../src/resident_admin_chat');

function setup({ residentCommunity = 'A', activeAdmin = true, authenticated = true } = {}) {
  const docs = new Map([
    ['users/resident1', { role:'resident', name:'Test Resident', communityId:residentCommunity,
      approvalStatus:'approved', isActive:true, buildingId:'building1', flatId:'flat1' }],
    ['communities/A', { isActive:true }],
    ['communities/B', { isActive:true }],
    ['admins/adminA', { uid:'adminA', role:'admin', isActive:activeAdmin,
      authorizedCommunityIds:['A'], name:'Community Admin' }],
  ]);
  const snapshots = path => ({ exists:docs.has(path), data:()=>docs.get(path) });
  const db = {
    collection(name) { return {
      doc(id) {const path=`${name}/${id}`; return { path, get:async()=>snapshots(path) };},
      where(field,op,value) { assert.equal(name,'admins'); assert.equal(field,'authorizedCommunityIds');
        assert.equal(op,'array-contains'); return {get:async()=>({docs:[...docs.entries()]
        .filter(([p,d])=>p.startsWith('admins/') && d.authorizedCommunityIds.includes(value))
        .map(([p,d])=>({id:p.split('/')[1],data:()=>d}))})}; },
    }; },
    async runTransaction(fn) { return fn({
      get:async(ref)=>snapshots(ref.path),
      create(ref,data) { assert.equal(docs.has(ref.path),false); docs.set(ref.path,data); },
    }); },
  };
  return { db, docs, auth: authenticated ? {uid:'resident1'} : null, fieldValue:{serverTimestamp:()=> 'SERVER_TIME'} };
}

test('creates tenant-scoped chat with real admin and reuses it', async () => {
  const input=setup();
  const first=await getOrCreateResidentAdminChatCore(input);
  assert.equal(first.chatId,'admin_A_resident1');
  const data=input.docs.get('chats/admin_A_resident1');
  assert.equal(data.communityId,'A');
  assert.deepEqual(data.participants,['resident1','adminA']);
  assert.equal(data.chatType,'individual');
  assert.equal(data.type,'admin');
  const second=await getOrCreateResidentAdminChatCore(input);
  assert.equal(second.chatId,first.chatId);
  assert.equal(input.docs.size,5);
});

test('rejects residents in a different community', async () => {
  const input=setup({residentCommunity:'B'});
  await assert.rejects(getOrCreateResidentAdminChatCore(input),{code:'failed-precondition'});
  assert.equal(input.docs.has('chats/admin_B_resident1'),false);
});

test('rejects missing admin instead of making a placeholder', async () => {
  const input=setup({activeAdmin:false});
  await assert.rejects(getOrCreateResidentAdminChatCore(input),{code:'failed-precondition'});
  assert.equal(input.docs.has('chats/admin_A_resident1'),false);
});

test('requires authentication', async () => {
  await assert.rejects(getOrCreateResidentAdminChatCore(setup({authenticated:false})),
    {code:'unauthenticated'});
});
