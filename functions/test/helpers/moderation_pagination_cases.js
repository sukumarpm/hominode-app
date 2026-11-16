const assert = require('node:assert/strict');
const {Timestamp} = require('firebase-admin/firestore');
const {listModerationReportsCore} = require('../../src/content_moderation');
const auth = uid => ({uid,token:{phone_number:'+639170000000',firebase:{sign_in_provider:'phone'}}});
async function fixture(db, count=0) {
  for (const c of ['A','B']) await db.collection('communities').doc(c).set({isActive:true});
  await db.collection('admins').doc('admin').set({uid:'admin',role:'admin',isActive:true,authorizedCommunityIds:['A']});
  await db.collection('admins').doc('admin-b').set({uid:'admin-b',role:'admin',isActive:true,authorizedCommunityIds:['B']});
  for(let start=0;start<count;start+=100) await Promise.all(Array.from({length:Math.min(100,count-start)},async(_,offset)=>{
    const i=start+offset, id=`record-${String(i).padStart(5,'0')}`;
    // Identical timestamps exercise deterministic document-ID ordering.
    const data={communityId:'A',createdAt:new Timestamp(1700000000+Math.floor(i/4),123456789),postId:'post',reportId:id,action:i%2?'hide':'dismiss',reasonCode:i%2?'spam':'no_violation',internalNote:'Admin only',contentSnapshot:'Content',status:'open',reporterId:'secret-reporter',notificationRecipientId:'private-recipient'};
    await Promise.all(['moderationAudit','moderationReports'].map(c=>db.collection(c).doc(id).set(data)));
  }));
  for(const c of ['moderationAudit','moderationReports']) await db.collection(c).doc('foreign').set({communityId:'B',createdAt:Timestamp.now(),status:'open',internalNote:'Foreign note'});
  const list = data => listModerationReportsCore({db,auth:auth('admin'),data:{communityId:'A',...data}});
  return {db,list};
}
function registerCases(test, makeDb) {
  for (const count of [0,3,10,100,1001]) test(`bounded summary and complete stable traversal for ${count} records`,async()=>{
    const {db,list}=await fixture(await makeDb(),count);
    const summary=await list({view:'summary'});
    assert.equal(summary.reports.length,Math.min(3,count)); assert.equal(summary.history.length,Math.min(3,count));
    assert.equal(summary.reportsPage.total,count); assert.equal(summary.historyPage.total,count);
    for (const view of ['history','reports']) {
      let result=await list({view}), seen=[], first=result;
      while(true) {
        const rows=result[view], page=result[`${view}Page`];
        assert(rows.length<=10); assert.equal(page.total,count);
        assert(!JSON.stringify(rows).includes('secret-reporter')); assert(!JSON.stringify(rows).includes('private-recipient'));
        seen.push(...rows.map(r=>r.id));
        if (!page.nextCursor) break;
        result=await list({view,cursor:page.nextCursor});
      }
      assert.equal(seen.length,count);assert.equal(new Set(seen).size,count);
      assert.deepEqual(seen,[...seen].sort().reverse());
      assert.deepEqual((await list({view,cursor:first[`${view}Page`].pageCursor}))[view],first[view]);
    }
    if(db.reads) assert(db.reads.every(r=>r.cap<=11 && r.size<=11));
  });
  test('cursor keeps sub-millisecond precision and works when its source document leaves the queue',async()=>{
    const {db,list}=await fixture(await makeDb(),11);
    for(let i=0;i<11;i++) {
      const row=`record-${String(i).padStart(5,'0')}`;
      for(const collection of ['moderationAudit','moderationReports']) await db.collection(collection).doc(row).update({createdAt:new Timestamp(1700000000,100000-i*1000)});
    }
    const first=await list({view:'history'});
    assert.equal(first.history[0].id,'record-00000');
    assert.equal(first.history[9].id,'record-00009');
    const next=await list({view:'history',cursor:first.historyPage.nextCursor});
    assert.deepEqual(next.history.map(r=>r.id),['record-00010']);
    const reports=await list({view:'reports'});
    await db.collection('moderationReports').doc('record-00009').update({status:'hidden'});
    assert.deepEqual((await list({view:'reports',cursor:reports.reportsPage.nextCursor})).reports.map(r=>r.id),['record-00010']);
  });
  test('search is exact, scoped and cursor-bound; invalid arguments fail',async()=>{
    const {list}=await fixture(await makeDb(),100);
    for(const [searchField,search,total] of [['action','hide',50],['reasonCode','spam',50],['postId','post',100],['reportId','record-00000',1],['postId','pos',0]]) {
      const result=await list({view:'history',searchField,search});assert.equal(result.historyPage.total,total);
      if(result.historyPage.nextCursor) {
        await assert.rejects(list({view:'history',cursor:result.historyPage.nextCursor}),{code:'invalid-argument'});
        assert.equal((await list({view:'history',searchField,search,cursor:result.historyPage.nextCursor})).history.length,10);
      }
    }
    for(const data of [{view:'history',pageSize:1000},{view:'history',cursor:'bad'},{view:'history',searchField:'internalNote',search:'Admin'},{view:'history',search:'hid'},{view:'reports',search:'hide'},{view:'summary',cursor:'bad'}]) await assert.rejects(list(data),{code:'invalid-argument'});
  });
  test('concurrent inserts do not shift history, and resolved reports leave the queue',async()=>{
    const {db,list}=await fixture(await makeDb(),11);
    const first=await list({view:'history'});
    await new Promise(resolve=>setTimeout(resolve,5));
    await db.collection('moderationAudit').doc('new').set({communityId:'A',createdAt:Timestamp.now(),action:'hide'});
    const next=await list({view:'history',cursor:first.historyPage.nextCursor});
    assert.equal(next.historyPage.total,11); assert.equal(next.historyPage.totalCurrent,12);assert.equal(next.history.length,1);
    assert.deepEqual((await list({view:'history',cursor:first.historyPage.pageCursor})).history,first.history);
    assert.equal((await list({view:'history'})).history[0].id,'new');
    const reports=await list({view:'reports'});
    await db.collection('moderationReports').doc('record-00000').update({status:'dismissed'});
    const empty=await list({view:'reports',cursor:reports.reportsPage.nextCursor});
    assert.equal(empty.reports.length,0);assert.equal(empty.reportsPage.total,10);assert.equal(empty.reportsPage.nextCursor,null);
    assert.equal((await list({view:'reports'})).reports.length,10);
  });
  test('authorization cannot be bypassed by a cursor or search; undated legacy counts stay explicit',async()=>{
    const {db,list}=await fixture(await makeDb(),11);
    await db.collection('moderationAudit').doc('undated').set({communityId:'A',internalNote:'Old note'});
    const page=await list({view:'history'});
    assert.equal(page.historyPage.total,11);assert.equal(page.historyPage.totalCurrent,12);
    for(const uid of ['resident','admin-b']) await assert.rejects(listModerationReportsCore({db,auth:auth(uid),data:{communityId:'A',view:'history',cursor:page.historyPage.nextCursor}}),{code:'permission-denied'});
    const foreign=await listModerationReportsCore({db,auth:auth('admin-b'),data:{communityId:'B',view:'history'}});
    assert.equal(foreign.history.length,1);assert.equal(foreign.history[0].internalNote,'Foreign note');
    await assert.rejects(listModerationReportsCore({db,auth:auth('admin-b'),data:{communityId:'B',view:'history',cursor:page.historyPage.nextCursor}}),{code:'invalid-argument'});
  });
}
module.exports={registerCases};
