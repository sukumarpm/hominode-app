const test = require('node:test');
const assert = require('node:assert/strict');
const {resolveVisitorQrCore, transitionVisitorFromQrCore} = require('../src/visitor_gate');

const now = Date.UTC(2026, 9, 10, 4, 0);
const qrToken = 'opaque-random-visitor-qr-token-1234567890';
const auth = {uid: 'security-1', token: {phone_number: '+639170000000', firebase: {sign_in_provider: 'phone'}}};
const visitor = () => ({communityId: 'community-a', hostUserId: 'resident-a', hostName: 'Resident A',
  visitorName: 'Guest A', flatLabel: 'A-101', phoneNumber: '+639171111111', purpose: 'Visit',
  qrToken, expectedArrival: new Date(now), status: 'expected', isApproved: false,
  actualArrival: null, departure: null});

function fakeDb(visitorData = visitor(), communityId = 'community-a') {
  const store = {visitor: visitorData, visitorHostCredentials: {}, visitorGateCredentialIndex: {}};
  const profiles = {
    securityStaff: {'security-1': {uid: 'security-1', phoneNumber: auth.token.phone_number,
      role: 'security', isActive: true, communityId}},
    communities: {[communityId]: {isActive: true}},
  };
  const document = (collection, id) => ({
    __collection: collection,
    __id: id,
    get: async () => {
      const value = collection === 'visitors' ? store[id] : profiles[collection]?.[id] ?? store[collection]?.[id];
      return {exists: value != null, data: () => value};
    },
  });
  return {
    store,
    collection(name) {
      return {
        doc: (id) => document(name, id),
        where(field, operator, value) {
          assert.equal(operator, '==');
          return {limit: () => ({get: async () => {
            const matches = Object.entries(store).filter(([, item]) => item?.[field] === value);
            return {size: matches.length, docs: matches.map(([id, data]) => ({id, data: () => data}))};
          }})};
        },
      };
    },
    async runTransaction(callback) {
      return callback({
        get: async (ref) => {
          const value = ref.__collection === 'visitors'
            ? store[refId(ref)]
            : profiles[ref.__collection]?.[refId(ref)] ?? store[ref.__collection]?.[refId(ref)];
          return {exists: value != null, data: () => value};
        },
        update: (ref, patch) => Object.assign(store[refId(ref)], patch),
      });
    },
  };
}
function refId(ref) { return ref.__id; }

test('valid QR resolves only gate details for the assigned community', async () => {
  const result = await resolveVisitorQrCore({db: fakeDb(), auth, data: {qrToken}, now: () => now});
  assert.equal(result.visitorId, 'visitor');
  assert.equal(result.visitorName, 'Guest A');
  assert.equal(result.hostName, 'Resident A');
});

test('legacy scanned document ID remains valid only for legacy records without a QR token', async () => {
  const legacy = visitor();
  delete legacy.qrToken;
  const db = fakeDb(legacy);
  const resolved = await resolveVisitorQrCore({db, auth, data: {legacyVisitorId: 'visitor'}, now: () => now});
  assert.equal(resolved.visitorId, 'visitor');
  const result = await transitionVisitorFromQrCore({db, auth,
    data: {legacyVisitorId: 'visitor', visitorId: 'visitor', action: 'approve'}, now: () => now});
  assert.equal(result.status, 'inside');
  const current = fakeDb(visitor());
  await assert.rejects(resolveVisitorQrCore({db: current, auth,
    data: {legacyVisitorId: 'visitor'}, now: () => now}));
  const versioned = fakeDb({...legacy, credentialVersion: 1});
  await assert.rejects(resolveVisitorQrCore({db: versioned, auth,
    data: {legacyVisitorId: 'visitor'}, now: () => now}));
});

test('credential migration sunsets document-ID and raw legacy QR paths while preserving stored fields', async () => {
  const migrated = {...visitor(), credentialVersion: 1};
  const db = fakeDb(migrated);
  await assert.rejects(resolveVisitorQrCore({db, auth,
    data: {legacyVisitorId: 'visitor'}, now: () => now}));
  await assert.rejects(resolveVisitorQrCore({db, auth,
    data: {qrToken}, now: () => now}));
  await assert.rejects(transitionVisitorFromQrCore({db, auth,
    data: {legacyVisitorId: 'visitor', visitorId: 'visitor', action: 'approve'}, now: () => now}));
  assert.equal(db.store.visitor.qrToken, qrToken);
});

test('legacy SEC-003 credential paths work before the UTC cutoff and fail at the boundary', async () => {
  const legacy = visitor();
  const db = fakeDb(legacy);
  const cutoff = new Date(now + 1000).toISOString();
  const beforeBoundary = () => now + 999;
  const atBoundary = () => now + 1000;

  assert.equal((await resolveVisitorQrCore({db, auth, data: {qrToken},
    legacyCredentialCutoffUtc: cutoff, now: beforeBoundary})).visitorId, 'visitor');
  await assert.rejects(resolveVisitorQrCore({db, auth, data: {qrToken},
    legacyCredentialCutoffUtc: cutoff, now: atBoundary}), /Legacy visitor verification is unavailable/);

  const idOnly = visitor();
  delete idOnly.qrToken;
  const idDb = fakeDb(idOnly);
  assert.equal((await resolveVisitorQrCore({db: idDb, auth, data: {legacyVisitorId: 'visitor'},
    legacyCredentialCutoffUtc: cutoff, now: beforeBoundary})).visitorId, 'visitor');
  await assert.rejects(resolveVisitorQrCore({db: idDb, auth, data: {legacyVisitorId: 'visitor'},
    legacyCredentialCutoffUtc: cutoff, now: atBoundary}), /Legacy visitor verification is unavailable/);

  const transitionDb = fakeDb(legacy);
  const transition = await transitionVisitorFromQrCore({db: transitionDb, auth,
    data: {visitorId: 'visitor', qrToken, action: 'approve'},
    legacyCredentialCutoffUtc: cutoff, now: beforeBoundary});
  assert.equal(transition.status, 'inside');
  await assert.rejects(transitionVisitorFromQrCore({db: fakeDb(legacy), auth,
    data: {visitorId: 'visitor', qrToken, action: 'approve'},
    legacyCredentialCutoffUtc: cutoff, now: atBoundary}), /Legacy visitor verification is unavailable/);
});

test('malformed UTC cutoff fails closed only for legacy paths, not private indexed credentials', async () => {
  const legacy = visitor();
  const legacyDb = fakeDb(legacy);
  for (const malformed of ['', '2026-10-11', '2026-02-30T00:00:00.000Z', '2026-10-11T00:00:00Z']) {
    await assert.rejects(resolveVisitorQrCore({db: legacyDb, auth, data: {qrToken},
      legacyCredentialCutoffUtc: malformed, now: () => now}));
    await assert.rejects(transitionVisitorFromQrCore({db: fakeDb(legacy), auth,
      data: {visitorId: 'visitor', qrToken, action: 'approve'},
      legacyCredentialCutoffUtc: malformed, now: () => now}));
  }

  const {credentialHash} = require('../src/visitor_credentials');
  const hmacKey = 'test-only-hmac-key-that-is-at-least-32-bytes-long';
  const privateDb = fakeDb({...visitor(), qrToken: undefined, credentialVersion: 1});
  delete privateDb.store.visitor.qrToken;
  const hash = credentialHash(hmacKey, 'qr', qrToken);
  privateDb.store.visitorGateCredentialIndex[hash] = {
    visitorId: 'visitor', communityId: 'community-a', credentialType: 'qr', credentialVersion: 1,
  };
  privateDb.store.visitorHostCredentials.visitor = {
    qrToken, manualCode: 'ABCDEFGHJKLM', communityId: 'community-a', hostUserId: 'resident-a',
  };
  const result = await resolveVisitorQrCore({db: privateDb, auth, data: {qrToken}, hmacKey,
    legacyCredentialCutoffUtc: 'not-a-valid-date', now: () => now});
  assert.equal(result.visitorId, 'visitor');
});

test('invalid, expired, and cross-community QR values are rejected', async () => {
  await assert.rejects(resolveVisitorQrCore({db: fakeDb(), auth, data: {qrToken: 'wrong'}, now: () => now}));
  await assert.rejects(resolveVisitorQrCore({db: fakeDb({...visitor(), expectedArrival: new Date(now - 25 * 60 * 60 * 1000)}), auth,
    data: {qrToken}, now: () => now}));
  await assert.rejects(resolveVisitorQrCore({db: fakeDb(visitor(), 'community-b'), auth, data: {qrToken}, now: () => now}));
});

test('valid approval atomically checks in; duplicate action is denied', async () => {
  const db = fakeDb();
  const result = await transitionVisitorFromQrCore({db, auth, data: {qrToken, visitorId: 'visitor', action: 'approve'}, now: () => now});
  assert.equal(result.status, 'inside');
  assert.equal(db.store.visitor.status, 'inside');
  assert.equal(db.store.visitor.isApproved, true);
  assert.equal(db.store.visitor.checkedInBy, auth.uid);
  await assert.rejects(transitionVisitorFromQrCore({db, auth, data: {qrToken, visitorId: 'visitor', action: 'approve'}, now: () => now}));
});

test('QR-gated Security check-in accepts an Admin-approved visitor and preserves approval attribution', async () => {
  const approvedVisitor = {
    ...visitor(), status: 'approved', isApproved: true,
    approvedBy: 'admin-1', approvedAt: new Date(now - 1000),
  };
  const db = fakeDb(approvedVisitor);
  const result = await transitionVisitorFromQrCore({db, auth,
    data: {qrToken, visitorId: 'visitor', action: 'approve'}, now: () => now});

  assert.equal(result.status, 'inside');
  assert.equal(db.store.visitor.status, 'inside');
  assert.equal(db.store.visitor.checkedInBy, auth.uid);
  assert.equal(db.store.visitor.approvedBy, 'admin-1');
  assert.equal(db.store.visitor.approvedAt, approvedVisitor.approvedAt);
});

test('valid rejection is terminal and cannot be repeated', async () => {
  const db = fakeDb();
  const result = await transitionVisitorFromQrCore({db, auth, data: {qrToken, visitorId: 'visitor', action: 'reject'}, now: () => now});
  assert.equal(result.status, 'rejected');
  assert.equal(db.store.visitor.rejectedBy, auth.uid);
  await assert.rejects(transitionVisitorFromQrCore({db, auth, data: {qrToken, visitorId: 'visitor', action: 'reject'}, now: () => now}));
});

test('a visitor assigned to another community cannot be resolved or transitioned', async () => {
  const db = fakeDb({...visitor(), communityId: 'community-b'});
  await assert.rejects(resolveVisitorQrCore({db, auth, data: {qrToken}, now: () => now}));
  await assert.rejects(transitionVisitorFromQrCore({db, auth, data: {qrToken, visitorId: 'visitor', action: 'approve'}, now: () => now}));
});

test('SEC-003 callables continue resolving and transitioning tokens moved to private storage', async () => {
  const {credentialHash} = require('../src/visitor_credentials');
  const hmacKey = 'test-only-hmac-key-that-is-at-least-32-bytes-long';
  const db = fakeDb({...visitor(), qrToken: undefined});
  delete db.store.visitor.qrToken;
  const hash = credentialHash(hmacKey, 'qr', qrToken);
  db.store.visitorGateCredentialIndex[hash] = {
    visitorId: 'visitor', communityId: 'community-a', credentialType: 'qr', credentialVersion: 1,
  };
  db.store.visitorHostCredentials.visitor = {
    qrToken, manualCode: 'ABCDEFGHJKLM', communityId: 'community-a', hostUserId: 'resident-a',
  };
  const resolved = await resolveVisitorQrCore({db, auth, data: {qrToken}, hmacKey, now: () => now});
  assert.equal(resolved.visitorId, 'visitor');
  assert.equal('qrToken' in resolved, false);
  assert.equal('visitorPassCode' in resolved, false);
  assert.equal('credentialHash' in resolved, false);
  const result = await transitionVisitorFromQrCore({db, auth,
    data: {qrToken, visitorId: 'visitor', action: 'approve'}, hmacKey, now: () => now});
  assert.equal(result.status, 'inside');
});
