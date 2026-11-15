const test = require('node:test');
const assert = require('node:assert/strict');
const {randomUUID} = require('node:crypto');
const {initializeApp, deleteApp} = require('firebase-admin/app');
const {getFirestore} = require('firebase-admin/firestore');
const {readVisibleWallCore, reportContentCore, resolveModerationReportCore, blockContentUserCore} = require('../src/content_moderation');

const enabled = Boolean(process.env.FIRESTORE_EMULATOR_HOST);
const suite = (name, fn) => test(name, {skip: !enabled}, fn);
const phone = '+639170000000';
const auth = uid => ({uid, token: {phone_number: phone, firebase: {sign_in_provider: 'phone'}}});
let app, db;
test.before(() => {
  if (!enabled) return;
  app = initializeApp({projectId: 'demo-hominode-wall'}, 'wall-visibility-tests');
  db = getFirestore(app);
});
test.after(async () => {if (app) await deleteApp(app);});

async function fixture() {
  const suffix = randomUUID(), communityId = `A-${suffix}`;
  const reader = `reader-${suffix}`, author = `author-${suffix}`, admin = `admin-${suffix}`;
  const pulse = `pulse-${suffix}`, nova = `nova-${suffix}`;
  const own = `own-${suffix}`, other = `other-${suffix}`, old = `old-${suffix}`, legacy = `legacy-${suffix}`;
  const batch = db.batch();
  const set = (collection, id, data) => batch.set(db.collection(collection).doc(id), data);
  set('communities', communityId, {isActive:true});
  set('buildings', pulse, {communityId}); set('buildings', nova, {communityId});
  for (const [uid, buildingId] of [[reader,pulse],[author,nova]]) set('users',uid,{
    uid,phoneNumber:phone,communityId,buildingId,role:'resident',approvalStatus:'approved',isActive:true,
    status:'active',residentType:'owner',ownershipType:'owner',identityVerificationStatus:'not_required',
  });
  set('admins',admin,{uid:admin,role:'admin',isActive:true,authorizedCommunityIds:[communityId]});
  set('posts',own,{communityId,buildingId:pulse,authorId:reader,content:'Own new post',moderationVersion:1});
  set('posts',other,{communityId,buildingId:nova,authorId:author,content:'Other new post',moderationVersion:1});
  set('posts',old,{communityId,buildingId:nova,authorId:author,content:'Other historical post'});
  set('posts',legacy,{buildingId:pulse,authorId:author,content:'Permitted building-only legacy post'});
  set(`posts/${other}/comments`,'comment',{communityId,authorId:author,comment:'Cross-building comment'});
  await batch.commit();
  return {communityId,reader,author,admin,pulse,nova,own,other,old,legacy,
    feed: uid => readVisibleWallCore({db,auth:auth(uid),data:{}}),
    comments: (uid,postId) => readVisibleWallCore({db,auth:auth(uid),data:{postId}})};
}

suite('real queries return own and other-building posts, historical content, comments, and no duplicate rows', async () => {
  const f = await fixture();
  const readerFeed = await f.feed(f.reader);
  assert.deepEqual(new Set(readerFeed.posts.map(p=>p.id)),new Set([f.own,f.other,f.old,f.legacy]));
  assert.equal(readerFeed.posts.length,4);
  const authorFeed = await f.feed(f.author);
  assert.deepEqual(new Set(authorFeed.posts.map(p=>p.id)),new Set([f.own,f.other,f.old]));
  assert.equal((await f.comments(f.reader,f.other)).comments[0].comment,'Cross-building comment');
  await db.collection('posts').doc(`new-${f.reader}`).set({communityId:f.communityId,buildingId:f.pulse,authorId:f.reader,content:'Just published',moderationVersion:1});
  assert((await f.feed(f.author)).posts.some(p=>p.content==='Just published'));
});

suite('Admin hiding still removes cross-building posts and denies their comments', async () => {
  const f = await fixture();
  const report = await reportContentCore({db,auth:auth(f.reader),data:{postId:f.other,reason:'Spam'}});
  await resolveModerationReportCore({db,auth:auth(f.admin),data:{communityId:f.communityId,reportId:report.reportId,action:'hide',reasonCode:'inappropriate_content'}});
  for (const uid of [f.reader,f.author]) {
    assert(!(await f.feed(uid)).posts.some(p=>p.id===f.other));
    await assert.rejects(f.comments(uid,f.other),{code:'not-found'});
  }
  // The forward-only marker remains irrelevant to ordinary historical reads.
  assert((await f.feed(f.reader)).posts.some(p=>p.id===f.old));
});

suite('blocking stays per Resident; canonical foreign posts never inherit legacy building access', async () => {
  const f = await fixture();
  const foreign = `foreign-${f.reader}`;
  await db.collection('posts').doc(foreign).set({communityId:'another-community',buildingId:f.pulse,authorId:f.author,content:'Foreign'});
  await blockContentUserCore({db,auth:auth(f.reader),data:{userId:f.author,blocked:true}});
  assert.deepEqual((await f.feed(f.reader)).posts.map(p=>p.id),[f.own]);
  assert((await f.feed(f.author)).posts.some(p=>p.id===f.other));
  await assert.rejects(f.comments(f.reader,f.other),{code:'not-found'});
  await blockContentUserCore({db,auth:auth(f.reader),data:{userId:f.author,blocked:false}});
  assert(!(await f.feed(f.reader)).posts.some(p=>p.id===foreign));
  await assert.rejects(f.comments(f.reader,foreign),{code:'not-found'});
});
