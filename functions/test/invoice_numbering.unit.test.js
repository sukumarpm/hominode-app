'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const {invoiceNumber, invoiceCounterId, reserveInvoiceNumber} =
  require('../src/invoice_numbering');

test('formats unique immutable-looking scoped display numbers', () => {
  assert.equal(invoiceNumber({communityCode: 'GW', year: 2026, sequence: 1}), 'HN-GW-2026-000001');
  assert.equal(invoiceNumber({communityCode: 'BLUE-VALLEY', year: 2027, sequence: 123}), 'HN-BLUE-VALLEY-2027-000123');
  assert.notEqual(invoiceCounterId('GREEN-WAVE', 2026), invoiceCounterId('GREEN-WAVE', 2027));
  assert.notEqual(invoiceCounterId('GREEN-WAVE', 2026), invoiceCounterId('BLUE-VALLEY', 2026));
});
test('rejects guessed/invalid scope and unsafe sequences', () => {
  for (const code of ['', 'gw', 'G', 'GW SPACE', '../GW']) {
    assert.throws(() => invoiceNumber({communityCode: code, year: 2026, sequence: 1}));
  }
  for (const n of [0, -1, 1.3, 1000000, Number.MAX_SAFE_INTEGER]) {
    assert.throws(() => invoiceNumber({communityCode: 'GW', year: 2026, sequence: n}));
  }
});
test('reserves next number inside caller transaction', async () => {
  let changes = [];
  const db = {collection: name => ({doc: id => ({name, id})})};
  const transaction = {
    get: async ref => ({exists: true, data: () => ({
      communityId: 'GREEN-WAVE', communityCode: 'GW', year: 2026, lastSequence: 8,
    })}),
    set: (ref, payload) => changes.push({ref, payload}),
  };
  const result = await reserveInvoiceNumber({db, transaction, communityId: 'GREEN-WAVE', communityCode: 'GW', year: 2026});
  assert.deepEqual(result, {number: 'HN-GW-2026-000009', sequence: 9});
  assert.equal(changes.length, 1);
  assert.equal(changes[0].payload.lastSequence, 9);
});
test('rejects counter scope mismatch without a write', async () => {
  let wrote = false;
  const db = {collection: name => ({doc: id => ({name, id})})};
  const transaction = {
    get: async () => ({exists: true, data: () => ({
      communityId: 'ANOTHER', communityCode: 'GW', year: 2026, lastSequence: 8,
    })}),
    set: () => {wrote = true;},
  };
  await assert.rejects(
    reserveInvoiceNumber({db, transaction, communityId: 'GREEN-WAVE', communityCode: 'GW', year: 2026}),
  );
  assert.equal(wrote, false);
});
