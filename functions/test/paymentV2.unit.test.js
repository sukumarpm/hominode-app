const test = require('node:test');
const assert = require('node:assert/strict');
const {readFileSync} = require('node:fs');
const {sosStore} = require('./helpers/sos_store');
const {paymentCases} = require('./helpers/payment_v2_cases');
paymentCases(test, async () => {
  const objects = new Map();
  const bucket = {name: 'test-bucket', file: path => ({getMetadata: async () => {
    if (!objects.has(path)) throw Object.assign(Error('Object not found'), {code: 404});
    return [objects.get(path)];
  }})};
  return {db: sosStore(), bucket, upload: async (path, metadata) => objects.set(path, {
    name: path, generation: '123', size: '10', contentType: 'image/jpeg', metadata,
  })};
});
test('all four V2 callables use the App Check wrapper alongside unchanged V1 exports', () => {
  const source = readFileSync(require.resolve('../src/index'), 'utf8');
  for (const name of ['preparePaymentProofV2', 'verifyPaymentProofV2', 'rejectPaymentProofV2', 'recordOfflinePaymentV2',
    'verifyPaymentProof', 'rejectPaymentProof', 'recordManualPayment']) {
    assert.match(source, new RegExp(`exports\\.${name} = appCheckedCallable\\(\\s*${name}Core,`));
  }
  assert.match(source, /enforceAppCheck: true/);
});
