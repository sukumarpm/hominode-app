const test = require('node:test');
const assert = require('node:assert/strict');
const {initializeApp, deleteApp} = require('firebase-admin/app');
const {getFirestore} = require('firebase-admin/firestore');
const {getStorage} = require('firebase-admin/storage');
const {billingV2ReportCases} = require('./helpers/billing_v2_reports_cases');
const {getBillingV2FinancialReportCore} = require('../src/billing_v2_reports');

const enabled = !!process.env.FIRESTORE_EMULATOR_HOST && !!process.env.STORAGE_EMULATOR_HOST;
const projectId = 'demo-hominode-billing-v2-reports';
let app;
let db;
let bucket;

test.before(() => {
  if (!enabled) return;
  app = initializeApp({projectId, storageBucket: `${projectId}.appspot.com`}, 'billing-v2-reports-tests');
  db = getFirestore(app);
  bucket = getStorage(app).bucket();
});

test.after(async () => {
  if (app) await deleteApp(app);
});

test.beforeEach(async () => {
  if (!enabled) return;
  const result = await fetch(
    `http://${process.env.FIRESTORE_EMULATOR_HOST}/emulator/v1/projects/${projectId}/databases/(default)/documents`,
    {method: 'DELETE'}
  );
  assert.equal(result.ok, true);
});

billingV2ReportCases((name, fn) => test(name, {skip: !enabled}, fn), async () => ({
  db,
  bucket,
  upload: (path, metadata) => bucket.file(path).save(Buffer.from('test image evidence'), {
    resumable: false,
    metadata: {contentType: 'image/jpeg', metadata},
  }),
}), getBillingV2FinancialReportCore);
