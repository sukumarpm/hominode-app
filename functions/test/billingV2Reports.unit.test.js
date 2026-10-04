const test = require('node:test');
const assert = require('node:assert/strict');
const {readFileSync} = require('node:fs');
const {sosStore} = require('./helpers/sos_store');
const {billingV2ReportCases} = require('./helpers/billing_v2_reports_cases');
const {getBillingV2FinancialReportCore} = require('../src/billing_v2_reports');

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
