const test = require('node:test');
const assert = require('node:assert/strict');
const {sosStore} = require('./helpers/sos_store');
const {reportContentCore, blockContentUserCore, listBlockedContentUsersCore, listModerationReportsCore, resolveModerationReportCore, readVisibleWallCore} = require('../src/content_moderation');
const phone = '+639170000000';
const auth = uid => ({uid, token: {phone_number: phone, firebase: {sign_in_provider: 'phone'}}});
async function fixture() {
 const db = sosStore();
 for (const c of ['A','B']) await db.collection('communities').doc(c).set({isActive:true});
 for (const [uid,c] of [['resident','A'],['author','A'],['foreign','B']]) await db.collection('users').doc(uid).set({uid,phoneNumber:phone,communityId:c,buildingId:'building',role:'resident',isActive:true,approvalStatus:'approved',status:'active',residentType:'owner'});
 await db.collection('admins').doc('admin').set({uid:'admin',role:'admin',isActive:true,authorizedCommunityIds:['A']});
 await db.collection('posts').doc('post').set({communityId:'A',buildingId:'building',authorId:'author',content:'Post',status:'active',moderationVersion:1});
 await db.collection('posts/post/comments').doc('comment').set({communityId:'A',postId:'post',authorId:'author',comment:'Comment',moderationVersion:1});
 return db;
}
test('reports validate targets, enforce scope and deduplicate without hiding content', async () => {
 const db=await fixture(), args={db,auth:auth('resident'),data:{postId:'post',reason:'Inappropriate'}};
 const [a,b]=await Promise.all([reportContentCore(args),reportContentCore(args)]);
 assert.equal(a.reportId,b.reportId); assert.equal([a.duplicate,b.duplicate].filter(Boolean).length,1);
 assert.equal((await db.collection('posts').doc('post').get()).data().moderationState,undefined);
 await assert.rejects(reportContentCore({...args,auth:auth('foreign')}),{code:'not-found'});
 await assert.rejects(reportContentCore({...args,auth:auth('author')}),{code:'failed-precondition'});
 assert.notEqual((await reportContentCore({...args,data:{...args.data,commentId:'comment'}})).reportId,a.reportId);
});
test('only scoped admins hide content and append one audit record', async () => {
 const db=await fixture(), report=await reportContentCore({db,auth:auth('resident'),data:{postId:'post',commentId:'comment',reason:'Abuse'}});
 await assert.rejects(resolveModerationReportCore({db,auth:auth('resident'),data:{communityId:'A',reportId:report.reportId,action:'hide',reasonCode:'inappropriate_content'}}),{code:'permission-denied'});
 await assert.rejects(resolveModerationReportCore({db,auth:auth('admin'),data:{communityId:'B',reportId:report.reportId,action:'hide',reasonCode:'inappropriate_content'}}),{code:'permission-denied'});
 const args={db,auth:auth('admin'),data:{communityId:'A',reportId:report.reportId,action:'hide',reasonCode:'inappropriate_content'}};
 assert.equal((await resolveModerationReportCore(args)).duplicate,false); assert.equal((await resolveModerationReportCore(args)).duplicate,true);
 assert.equal((await db.collection('posts/post/comments').doc('comment').get()).data().moderationState,'hidden');
 assert.equal((await readVisibleWallCore({db,auth:auth('resident'),data:{postId:'post'}})).comments.length,0);
 const queue=await listModerationReportsCore({db,auth:auth('admin'),data:{communityId:'A'}}); assert.equal(queue.reports.length,0); assert.equal(queue.history.length,1);
});
test('blocking affects only blocker and can be reversed', async () => {
 const db=await fixture(); await blockContentUserCore({db,auth:auth('resident'),data:{userId:'author',blocked:true}});
 assert.equal((await readVisibleWallCore({db,auth:auth('resident'),data:{}})).posts.length,0);
 assert.equal((await readVisibleWallCore({db,auth:auth('author'),data:{}})).posts.length,1);
 assert.equal((await listBlockedContentUsersCore({db,auth:auth('resident'),data:{}})).users[0].userId,'author');
 await blockContentUserCore({db,auth:auth('resident'),data:{userId:'author',blocked:false}});
 assert.equal((await readVisibleWallCore({db,auth:auth('resident'),data:{}})).posts.length,1);
});
test('dismissal preserves visibility and records a single decision', async () => {
 const db=await fixture();
 const report=await reportContentCore({db,auth:auth('resident'),data:{postId:'post',reason:'Review'}});
 const args={db,auth:auth('admin'),data:{communityId:'A',reportId:report.reportId,action:'dismiss',reasonCode:'no_violation'}};
 await resolveModerationReportCore(args);
 assert.equal((await resolveModerationReportCore(args)).duplicate,true);
 assert.equal((await readVisibleWallCore({db,auth:auth('resident'),data:{}})).posts.length,1);
 const queue=await listModerationReportsCore({db,auth:auth('admin'),data:{communityId:'A'}});
 assert.equal(queue.reports.length,0); assert.equal(queue.history.length,1);
});
test('legacy building-scoped posts are included only after verifying their community', async () => {
 const db=await fixture();
 await db.collection('buildings').doc('building').set({communityId:'A'});
 await db.collection('posts').doc('legacy').set({buildingId:'building',authorId:'author',content:'Legacy'});
 const feed=await readVisibleWallCore({db,auth:auth('resident'),data:{}});
 assert(feed.posts.some(post=>post.id==='legacy'));
 await db.collection('posts/legacy/comments').doc('old').set({authorId:'author',comment:'Old comment'});
 await db.collection('posts/legacy/comments').doc('foreign').set({communityId:'B',authorId:'foreign',comment:'Foreign'});
 assert.deepEqual((await readVisibleWallCore({db,auth:auth('resident'),data:{postId:'legacy'}})).comments.map(c=>c.id),['old']);
 await assert.rejects(reportContentCore({db,auth:auth('resident'),data:{postId:'legacy',reason:'Review'}}),{code:'failed-precondition'});
 assert.equal((await db.collection('posts').doc('legacy').get()).data().moderationState,undefined);
});

test('new post/comment reports retain reasons and target fields in only the authorized Admin queue', async () => {
 const db = await fixture();
 await db.collection('admins').doc('admin-b').set({uid:'admin-b',role:'admin',isActive:true,authorizedCommunityIds:['B']});
 const reason = 'Harassment or bullying: Repeated personal attacks';
 for (const commentId of [undefined, 'comment']) {
  const result = await reportContentCore({db,auth:auth('resident'),data:{postId:'post',...(commentId ? {commentId} : {}),reason}});
  const saved = (await db.collection('moderationReports').doc(result.reportId).get()).data();
  assert.equal(saved.communityId,'A'); assert.equal(saved.reason,reason);
  assert.equal(saved.postId,'post'); assert.equal(saved.commentId,commentId || null);
  assert.equal(saved.targetType,commentId ? 'comment' : 'post');
 }
 const own = await listModerationReportsCore({db,auth:auth('admin'),data:{communityId:'A'}});
 assert.equal(own.reports.length,2); assert(own.reports.every(r=>r.reason===reason));
 const foreign = await listModerationReportsCore({db,auth:auth('admin-b'),data:{communityId:'B'}});
 assert.equal(foreign.reports.length,0);
 await assert.rejects(listModerationReportsCore({db,auth:auth('admin-b'),data:{communityId:'A'}}),{code:'permission-denied'});
});

test('unmarked historical posts/comments reject without persisting or modifying any historical content', async () => {
 const db = await fixture();
 await db.collection('posts').doc('old').set({communityId:'A',buildingId:'building',authorId:'author',content:'Historical post'});
 await db.collection('posts/post/comments').doc('old').set({communityId:'A',postId:'post',authorId:'author',comment:'Historical comment'});
 for (const data of [{postId:'old',reason:'Spam'}, {postId:'post',commentId:'old',reason:'Spam'}]) {
  await assert.rejects(reportContentCore({db,auth:auth('resident'),data}),{code:'failed-precondition',message:'Only new content can be reported.'});
 }
 assert.equal((await db.collection('moderationReports').get()).docs.length,0);
 assert.equal((await db.collection('posts').doc('old').get()).data().moderationVersion,undefined);
});

test('community feed and comments span Resident buildings without filtering author or requiring a moderation marker', async () => {
 const db = await fixture();
 await db.collection('buildings').doc('building').set({communityId:'A'});
 await db.collection('buildings').doc('other-building').set({communityId:'A'});
 await db.collection('users').doc('author').update({buildingId:'other-building'});
 await db.collection('posts').doc('post').update({buildingId:'other-building'});
 await db.collection('posts').doc('own').set({communityId:'A',buildingId:'building',authorId:'resident',content:'Own new post',moderationVersion:1});
 await db.collection('posts').doc('old').set({communityId:'A',buildingId:'other-building',authorId:'author',content:'Old unmarked post'});
 for (const uid of ['resident','author']) {
  const feed = await readVisibleWallCore({db,auth:auth(uid),data:{}});
  assert.deepEqual(new Set(feed.posts.map(p=>p.id)),new Set(['post','own','old']));
 }
 assert.equal((await readVisibleWallCore({db,auth:auth('resident'),data:{postId:'post'}})).comments[0].comment,'Comment');
 await db.collection('posts').doc('new-from-reader').set({communityId:'A',buildingId:'building',authorId:'resident',content:'New post',moderationVersion:1});
 assert((await readVisibleWallCore({db,auth:auth('author'),data:{}})).posts.some(p=>p.id==='new-from-reader'));
});

test('community feed preserves hidden/removed, per-Resident blocking and cross-community restrictions', async () => {
 const db = await fixture();
 await db.collection('posts').doc('post').update({buildingId:'other-building'});
 for (const [postId,patch] of [['hidden',{moderationState:'hidden'}],['removed',{status:'deleted'}],['foreign',{communityId:'B',buildingId:'building'}]]) {
  await db.collection('posts').doc(postId).set({communityId:'A',buildingId:'other-building',authorId:'author',content:postId,moderationVersion:1,...patch});
 }
 assert.deepEqual((await readVisibleWallCore({db,auth:auth('resident'),data:{}})).posts.map(p=>p.id),['post']);
 await blockContentUserCore({db,auth:auth('resident'),data:{userId:'author',blocked:true}});
 assert.equal((await readVisibleWallCore({db,auth:auth('resident'),data:{}})).posts.length,0);
 assert.equal((await readVisibleWallCore({db,auth:auth('author'),data:{}})).posts.length,1);
 for (const postId of ['post','hidden','removed','foreign']) {
  await assert.rejects(readVisibleWallCore({db,auth:auth('resident'),data:{postId}}),{code:'not-found'});
 }
 await assert.rejects(readVisibleWallCore({db,auth:auth('foreign'),data:{postId:'post'}}),{code:'not-found'});
});

test('legacy building-only scope stays unchanged and overlapping query results do not duplicate posts', async () => {
 const db = await fixture();
 await db.collection('buildings').doc('building').set({communityId:'A'});
 for (const [postId,buildingId] of [['legacy','building'],['other-legacy','another-building']]) {
  await db.collection('posts').doc(postId).set({buildingId,authorId:'author',content:'Historical'});
 }
 const feed = await readVisibleWallCore({db,auth:auth('resident'),data:{}});
 assert.deepEqual(feed.posts.map(p=>p.id).sort(),['legacy','post']);
 assert.equal(feed.posts.filter(p=>p.id==='post').length,1);
 await assert.rejects(readVisibleWallCore({db,auth:auth('resident'),data:{postId:'other-legacy'}}),{code:'not-found'});
});

test('query boundaries retain every supported community post and exceeding the cap fails instead of losing posts', async () => {
 const db = await fixture();
 await db.collection('buildings').doc('building').set({communityId:'A'});
 // Each canonical post is also returned by the legacy-building query.
 for (let i=0;i<999;i++) await db.collection('posts').doc(`extra-${i}`).set({communityId:'A',buildingId:'building',authorId:'author',content:'Post'});
 // The lightweight store includes nested docs in queries; remove its comment fixture.
 await db.collection('posts/post/comments').doc('comment').delete();
 const feed = await readVisibleWallCore({db,auth:auth('resident'),data:{}});
 assert.equal(feed.posts.length,1000);
 assert.equal(new Set(feed.posts.map(p=>p.id)).size,1000);
 await db.collection('posts').doc('over-bound').set({communityId:'A',buildingId:'different',authorId:'author',content:'Extra'});
 await assert.rejects(readVisibleWallCore({db,auth:auth('resident'),data:{}}),{code:'resource-exhausted'});
});
