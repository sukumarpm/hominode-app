const test = require('node:test');
const assert = require('node:assert/strict');
const {readFileSync} = require('node:fs');
const {sosStore} = require('./helpers/sos_store');
const {billingV2ResidentStatementCases} = require('./helpers/billing_v2_resident_statement_cases');

billingV2ResidentStatementCases(test, async () => {
  const objects = new Map();
  const bucket = {name: 'test-bucket', file: path => ({getMetadata: async () => {
    if (!objects.has(path)) throw Object.assign(Error('Object not found'), {code: 404});
    return [objects.get(path)];
  }})};
  return {db: sosStore(), bucket, upload: async (path, metadata) => objects.set(path, {
    name: path, generation: '123', size: '10', contentType: 'image/jpeg', metadata,
  })};
});

test('resident statement callable is registered with App Check enforcement', () => {
  const source = readFileSync(require.resolve('../src/index'), 'utf8');
  assert.match(source, /exports\.getResidentBillingV2Statement = appCheckedCallable\(\s*getResidentBillingV2StatementCore,/);
  assert.match(source, /enforceAppCheck: true/);
});
