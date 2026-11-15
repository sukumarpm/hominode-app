const test = require('node:test');
const fs = require('node:fs');
const {initializeTestEnvironment, assertFails, assertSucceeds} = require('@firebase/rules-unit-testing');
const {doc, collection, query, where, getDoc, getDocs, setDoc, updateDoc, writeBatch, increment, serverTimestamp} = require('firebase/firestore');
const phone = '+639170000000';
let env;
test.before(async () => {
  env = await initializeTestEnvironment({projectId:'demo-hominode-moderation',firestore:{rules:fs.readFileSync('../firestore.rules','utf8')}});
});
test.after(async () => env.cleanup());
test.beforeEach(async () => {
 await env.clearFirestore();
 await env.withSecurityRulesDisabled(async ctx => {
  const db=ctx.firestore();
  for (const uid of ['author','reader']) await setDoc(doc(db,'users',uid),{uid,phoneNumber:phone,communityId:'A',buildingId:'b',role:'resident',approvalStatus:'approved',isActive:true,status:'active',residentType:'owner',ownershipType:'owner',identityVerificationStatus:'not_required',name:uid});
  await setDoc(doc(db,'communities','A'),{isActive:true});
  await setDoc(doc(db,'buildings','b'),{communityId:'A'});
  await setDoc(doc(db,'posts','p'),{communityId:'A',buildingId:'b',authorId:'author',content:'Hi',status:'active',likes:0,likedBy:[],comments:0});
  await setDoc(doc(db,'posts','p','comments','c'),{communityId:'A',postId:'p',authorId:'author',comment:'hello'});
 });
});
const db = uid => env.authenticatedContext(uid,{phone_number:phone,firebase:{sign_in_provider:'phone'}}).firestore();
test('resident cannot forge moderation or write audit/report records', async () => {
 const store=db('author');
 await assertFails(updateDoc(doc(store,'posts','p'),{moderationState:'hidden'}));
 await assertFails(updateDoc(doc(store,'posts','p'),{moderationVersion:1}));
 await assertFails(setDoc(doc(store,'moderationAudit','fake'),{communityId:'A'}));
 await assertFails(setDoc(doc(store,'moderationReports','fake'),{communityId:'A'}));
});
test('older building-only feed queries cannot safely read moderated content', async () => {
 await env.withSecurityRulesDisabled(async ctx => updateDoc(doc(ctx.firestore(),'posts','p'),{moderationState:'hidden'}));
 await assertFails(getDocs(query(collection(db('reader'),'posts'),where('buildingId','==','b'))));
});
test('hidden post and comments are unreadable to residents', async () => {
 await env.withSecurityRulesDisabled(async ctx => updateDoc(doc(ctx.firestore(),'posts','p'),{moderationState:'hidden'}));
 await assertFails(getDoc(doc(db('reader'),'posts','p')));
 await assertFails(getDoc(doc(db('reader'),'posts','p','comments','c')));
});
test('hidden comments are unreadable while visible post remains readable', async () => {
 await env.withSecurityRulesDisabled(async ctx => updateDoc(doc(ctx.firestore(),'posts','p','comments','c'),{moderationState:'hidden'}));
 await assertSucceeds(getDoc(doc(db('reader'),'posts','p')));
 await assertFails(getDoc(doc(db('reader'),'posts','p','comments','c')));
 await assertFails(getDocs(collection(db('reader'),'posts','p','comments')));
});
function comment(store,text) {
 const batch=writeBatch(store);batch.set(doc(store,'posts','p','comments','new'),{postId:'p',communityId:'A',authorId:'reader',authorName:'reader',profileImage:'',comment:text,createdAt:serverTimestamp(),moderationVersion:1});
 batch.update(doc(store,'posts','p'),{comments:increment(1),lastCommentId:'new',updatedAt:serverTimestamp()});return batch.commit();
}
test('whole-word text filtering allows harmless substrings and rejects banned words',async()=>{
 await assertSucceeds(comment(db('reader'),'The white Essex sign is bright.'));
 await assertFails(comment(db('reader'),'I have a gun'));
 await assertFails(comment(db('reader'),'Hello\n gun\n'));
});
test('direct post writes cannot bypass server text filtering', async () => {
 const store = db('author');
 await assertSucceeds(updateDoc(doc(store,'posts','p'),{content:'The white Essex sign'}));
 await assertFails(updateDoc(doc(store,'posts','p'),{content:'I have a gun'}));
});
