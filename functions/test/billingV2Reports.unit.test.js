const test = require('node:test');
const assert = require('node:assert/strict');
const {readFileSync} = require('node:fs');
const {sosStore} = require('./helpers/sos_store');
const {billingV2ReportCases, detailedReportCases} = require('./helpers/billing_v2_reports_cases');
const {getBillingV2FinancialReportCore} = require('../src/billing_v2_reports');
const {getBillingV2DetailedReportCore} = require('../src/billing_v2_reports');
const {fixture, now, auth} = require('./helpers/payment_v2_cases');

detailedReportCases(test, async () => ({db: sosStore(), bucket: {file: () => ({})}, upload: async () => {}}), getBillingV2DetailedReportCore);

billingV2ReportCases(test, async () => {
  const objects = new Map();
  const bucket = {
    name: 'test-bucket',
    file: path => ({
      getMetadata: async () => {
        if (!objects.has(path)) throw Object.assign(Error('Object not found'), {code: 404});
        return [objects.get(path)];
      },
    }),
  };
  return {
    db: sosStore(),
    bucket,
    upload: async (path, metadata) => objects.set(path, {
      name: path,
      generation: '123',
      size: '10',
      contentType: 'image/jpeg',
      metadata,
    }),
  };
}, getBillingV2FinancialReportCore);

test('Billing V2 financial report callable is wired with app check enforcement', () => {
  const source = readFileSync(require.resolve('../src/index'), 'utf8');
  assert.match(source, /exports\.getBillingV2FinancialReport = appCheckedCallable\(\s*getBillingV2FinancialReportCore,/);
  assert.match(source, /enforceAppCheck: true/);
});

test('detailed report includes net ledger totals and retained deleted-resident identity', async () => {
  const f = await fixture(async () => ({db: sosStore(), bucket: {file: () => ({})}, upload: async () => {}}));
  await f.pay({amountMinor: 500, idempotencyKey: 'partial'});
  const financialBefore = await f.financialState();
  await f.ref('users/r').delete();
  await f.ref('accountDeletionRequests/deleted-r').set({
    uid: 'r', sourceApp: 'resident', status: 'completed', communityId: 'C',
    communityScopeVerified: true,
    retainedResidentIdentity: {name: 'Former Resident', phoneNumber: '+639171234567', unit: 'A-101', residentType: 'tenant'},
  });
  const report = await getBillingV2DetailedReportCore({
    db: f.db, auth, now,
    data: {communityId: 'C', fromMs: Date.parse('2030-01-01T00:00:00Z'), toMs: Date.parse('2030-01-31T23:59:59Z')},
  });
  assert.equal(report.rows.length, 1);
  assert.equal(report.rows[0].identity.name, 'Former Resident');
  assert.equal(report.rows[0].identity.deleted, true);
  assert.equal(report.rows[0].billedMinor, 1000);
  assert.equal(report.rows[0].paidMinor, 500);
  assert.equal(report.rows[0].outstandingMinor, 500);
  assert.equal(report.rows[0].payments[0].receivedAtMs, now());
  assert.deepEqual(await f.financialState(), financialBefore);
  const individual = await getBillingV2DetailedReportCore({db: f.db, auth, now,
    data: {communityId: 'C', residentId: 'r', fromMs: report.reportingPeriod.fromMs,
      toMs: report.reportingPeriod.toMs}});
  assert.deepEqual(individual.rows, report.rows);
});

test('detailed report rejects cross-community selection and invalid ranges', async () => {
  const f = await fixture(async () => ({db: sosStore(), bucket: {file: () => ({})}, upload: async () => {}}));
  const base = {communityId: 'C', fromMs: 1, toMs: 2};
  const requireAuthority = async (_db, _auth, communityId) => {
    if (communityId !== 'C') throw Object.assign(Error('cross community'), {code: 'permission-denied'});
    return {community: {timeZone: 'Asia/Manila'}};
  };
  await assert.rejects(getBillingV2DetailedReportCore({db: f.db, auth: {uid: 'a'}, data: {...base, communityId: 'D'}, requireAuthority}), /cross community/);
  await assert.rejects(getBillingV2DetailedReportCore({db: f.db, auth: {uid: 'a'}, data: {...base, toMs: 0}, requireAuthority}), {code: 'invalid-argument'});
});
