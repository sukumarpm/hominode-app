const test = require('node:test');
const {initializeApp,deleteApp} = require('firebase-admin/app');
const {getFirestore} = require('firebase-admin/firestore');
const enabled=Boolean(process.env.FIRESTORE_EMULATOR_HOST);
let app,db;
test.before(()=>{if(enabled){app=initializeApp({projectId:'demo-hominode-moderation-pagination'},'moderation-pagination');db=getFirestore(app);}});
test.after(async()=>{if(app)await deleteApp(app);});
require('./helpers/moderation_pagination_cases').registerCases((name,run)=>test(name,{skip:!enabled},run),async()=>{
  for(const collection of ['moderationAudit','moderationReports','communities','admins']) await db.recursiveDelete(db.collection(collection));
  return db;
});
