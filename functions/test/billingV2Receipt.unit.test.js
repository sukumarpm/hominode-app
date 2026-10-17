const test = require('node:test');
const assert = require('node:assert/strict');
const {readFileSync} = require('node:fs');
const {sosStore} = require('./helpers/sos_store');
const {receiptCases} = require('./helpers/billing_v2_receipt_cases');

receiptCases(test, async () => {
  const objects = new Map();
  const bucket = {name: 'test-bucket', file: path => ({getMetadata: async () => {
    if (!objects.has(path)) throw Object.assign(Error('Object not found'), {code: 404});
    return [objects.get(path)];
  }})};
  return {db: sosStore(), bucket, upload: async (path, metadata) => objects.set(path, {
    name: path, generation: '123', size: '10', contentType: 'image/jpeg', metadata,
  })};
});

test('resident Billing V2 receipt callable uses the App Check wrapper', () => {
  const source = readFileSync(require.resolve('../src/index'), 'utf8');
  assert.match(source, /exports\.getResidentBillingV2Receipt = appCheckedCallable\(\s*getResidentBillingV2ReceiptCore,/);
  assert.match(source, /getResidentBillingV2ReceiptCore,\s*\}\s*=\s*require\(["']\.\/billing_v2_receipt["']\)/);
});
