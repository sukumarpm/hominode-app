const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const {dispatchVisitorDecisionCore} = require('../src/visitor_notifications');

function fakeDb() {
  const docs = {
    users: {resident1: {uid: 'resident1', role: 'resident', communityId: 'community-a', approvalStatus: 'approved', isActive: true}},
    communities: {'community-a': {isActive: true}},
  };
  const devices = [
    {audienceKey: 'resident|resident|community-a|resident1', uid: 'resident1', communityId: 'community-a', role: 'resident', appId: 'resident', active: true, token: 'resident-token'},
    {audienceKey: 'resident|resident|community-a|resident1', uid: 'resident1', communityId: 'community-a', role: 'resident', appId: 'resident', active: true, token: 'resident-token-2'},
    {audienceKey: 'resident|resident|community-a|other', uid: 'other', communityId: 'community-a', role: 'resident', appId: 'resident', active: true, token: 'other-token'},
  ];
  const ref = (name, id) => ({
    id,
    get: async () => ({exists: docs[name]?.[id] != null, data: () => docs[name]?.[id]}),
    create: (data) => {docs[name] ??= {}; docs[name][id] = data;},
    update: (data) => Object.assign(docs[name][id], data),
    delete: async () => {delete docs[name]?.[id];},
  });
  return {
    docs,
    devices,
    collection(name) {
      return {
        doc: (id) => ref(name, id),
        where(field, operator, value) {
          return {get: async () => ({docs: devices.filter((device) => device[field] === value).map((data, i) => ({
            data: () => data,
            ref: {
              id: String(i),
              _get: async () => ({exists: true, data: () => data}),
              delete: async () => {data.active = false;},
            },
          }))})};
        },
      };
    },
    async runTransaction(callback) {
      return callback({
        get: async (documentRef) => documentRef._get ? documentRef._get() : ({
          exists: docs.visitorNotificationDeliveries?.[documentRef.id] != null,
        }),
        create: (documentRef, data) => documentRef.create(data),
        delete: (documentRef) => documentRef.delete(),
      });
    },
  };
}

test('Admin approval notification targets only the host resident and retries do not resend', async () => {
  const db = fakeDb();
  const sentTokens = [];
  const event = {
    id: 'event-1', params: {visitorId: 'visitor-1'},
    data: {
      before: {data: () => ({status: 'expected', isApproved: false})},
      after: {data: () => ({status: 'approved', isApproved: true, approvedAt: {toMillis: () => 1},
        visitorName: 'Guest One', hostUserId: 'resident1', communityId: 'community-a', approvedBy: 'admin1'})},
    },
  };
  const messaging = {sendEachForMulticast: async ({tokens, notification}) => {
    sentTokens.push(...tokens);
    assert.match(notification.body, /Guest One was approved to visit/);
    return {responses: tokens.map(() => ({success: true}))};
  }};
  const first = await dispatchVisitorDecisionCore({db, messaging, event, waitForRetry: async () => {}});
  const second = await dispatchVisitorDecisionCore({db, messaging, event, waitForRetry: async () => {}});
  assert.equal(first.deliveryStatus, 'sent');
  assert.equal(second.duplicate, true);
  assert.deepEqual(sentTokens, ['resident-token', 'resident-token-2']);
  const notification = Object.values(db.docs.notifications)[0];
  assert.equal(notification.recipientId, 'resident1');
  assert.equal(notification.communityId, 'community-a');
  assert.equal(notification.eventType, 'visitor_approved');
  assert.equal(notification.actorUid, 'admin1');
});

test('credential-verified gate entry notifies the host as checked in, without claiming Admin approval', async () => {
  const db = fakeDb();
  let title = '';
  let body = '';
  await dispatchVisitorDecisionCore({db, waitForRetry: async () => {}, messaging: {
    sendEachForMulticast: async ({tokens, notification}) => {
      title = notification.title;
      body = notification.body;
      assert.deepEqual(tokens, ['resident-token', 'resident-token-2']);
      return {responses: tokens.map(() => ({success: true}))};
    },
  }, event: {
    params: {visitorId: 'visitor-gate-entry'},
    data: {
      before: {data: () => ({status: 'expected', isApproved: false, actualArrival: null})},
      after: {data: () => ({status: 'inside', isApproved: false, actualArrival: {toMillis: () => 1},
        verificationMethod: 'manual', visitorName: 'Guest Gate', hostUserId: 'resident1',
        communityId: 'community-a', checkedInBy: 'security1'})},
    },
  }});
  assert.equal(title, 'Visitor checked in');
  assert.equal(body, 'Guest Gate checked in.');
  const notification = Object.values(db.docs.notifications)[0];
  assert.equal(notification.recipientId, 'resident1');
  assert.equal(notification.communityId, 'community-a');
});

test('rejection notification identifies rejection outcome and is host-scoped', async () => {
  const db = fakeDb();
  let body = '';
  await dispatchVisitorDecisionCore({db, waitForRetry: async () => {}, messaging: {sendEachForMulticast: async ({tokens, notification}) => {
    body = notification.body;
    assert.deepEqual(tokens, ['resident-token', 'resident-token-2']);
    return {responses: tokens.map(() => ({success: true}))};
  }}, event: {
    id: 'event-2', params: {visitorId: 'visitor-2'},
    data: {
      before: {data: () => ({status: 'expected'})},
      after: {data: () => ({status: 'rejected', rejectedAt: {toMillis: () => 2}, visitorName: 'Guest Two', hostUserId: 'resident1', communityId: 'community-a', rejectedBy: 'admin1'})},
    },
  }});
  assert.match(body, /Guest Two's visit request was rejected/);
});

test('Security Deny Entry notifies the host with a sanitized operational reason', async () => {
  const db = fakeDb();
  let pushMessage;
  await dispatchVisitorDecisionCore({db, waitForRetry: async () => {}, messaging: {
    sendEachForMulticast: async ({tokens, notification}) => {
      pushMessage = notification;
      assert.deepEqual(tokens, ['resident-token', 'resident-token-2']);
      return {responses: tokens.map(() => ({success: true}))};
    },
  }, event: {
    params: {visitorId: 'visitor-denied'},
    data: {
      before: {data: () => ({status: 'expected', gateAccessStatus: 'eligible'})},
      after: {data: () => ({status: 'expected', gateAccessStatus: 'denied',
        gateEntryDeniedAt: {toMillis: () => 2}, gateEntryDeniedBy: 'security1',
        gateEntryDenialReason: `No valid ID\n presented ${'ABCDEFGHJKLM'} ${'a'.repeat(43)}`, visitorName: 'Guest Denied',
        hostUserId: 'resident1', communityId: 'community-a'})},
    },
  }});
  assert.equal(pushMessage.title, 'Visitor entry denied');
  assert.equal(pushMessage.body, 'Guest Denied was denied entry. Reason: No valid ID presented [redacted] [redacted]');
  const notification = Object.values(db.docs.notifications)[0];
  assert.equal(notification.eventType, 'visitor_entry_denied');
  assert.equal(notification.actorUid, 'security1');
  assert.equal(notification.data.reason, 'No valid ID presented [redacted] [redacted]');
});

test('single and bulk checkout transitions each create a distinct host notification', async () => {
  const db = fakeDb();
  const eventFor = (visitorId, name) => ({
    params: {visitorId},
    data: {
      before: {data: () => ({status: 'inside', departure: null})},
      after: {data: () => ({status: 'completed', departure: {toMillis: () => 3},
        checkedOutBy: 'security1', visitorName: name, hostUserId: 'resident1', communityId: 'community-a'})},
    },
  });
  let sends = 0;
  const messaging = {sendEachForMulticast: async ({tokens}) => {
    sends++;
    return {responses: tokens.map(() => ({success: true}))};
  }};
  await dispatchVisitorDecisionCore({db, event: eventFor('visitor-out-1', 'Guest One'), messaging, waitForRetry: async () => {}});
  await dispatchVisitorDecisionCore({db, event: eventFor('visitor-out-2', 'Guest Two'), messaging, waitForRetry: async () => {}});
  assert.equal(Object.keys(db.docs.notifications).length, 2);
  assert.equal(Object.keys(db.docs.visitorNotificationDeliveries).length, 2);
  assert.equal(sends, 2);
  assert.deepEqual(Object.values(db.docs.notifications).map((item) => item.eventType), [
    'visitor_checked_out', 'visitor_checked_out',
  ]);
});

test('transient FCM failures retry only failed tokens and stop after success', async () => {
  const db = fakeDb();
  const event = {
    params: {visitorId: 'visitor-transient'},
    data: {
      before: {data: () => ({status: 'expected'})},
      after: {data: () => ({status: 'inside', actualArrival: {toMillis: () => 4}, checkedInBy: 'security1', hostUserId: 'resident1', communityId: 'community-a'})},
    },
  };
  const attempts = [];
  const result = await dispatchVisitorDecisionCore({db, event, waitForRetry: async () => {}, messaging: {
    sendEachForMulticast: async ({tokens}) => {
      attempts.push([...tokens]);
      return {responses: tokens.map((token) => token === 'resident-token' && attempts.length === 1 ?
        {success: false, error: {code: 'messaging/server-unavailable'}} : {success: true})};
    },
  }});
  assert.equal(result.deliveryStatus, 'sent');
  assert.deepEqual(attempts, [['resident-token', 'resident-token-2'], ['resident-token']]);
});

test('transient FCM failures stop at the bounded attempt limit', async () => {
  const db = fakeDb();
  const event = {
    params: {visitorId: 'visitor-bounded'},
    data: {
      before: {data: () => ({status: 'expected'})},
      after: {data: () => ({status: 'inside', actualArrival: {toMillis: () => 4}, checkedInBy: 'security1', hostUserId: 'resident1', communityId: 'community-a'})},
    },
  };
  let attempts = 0;
  const result = await dispatchVisitorDecisionCore({db, event, waitForRetry: async () => {}, messaging: {
    sendEachForMulticast: async ({tokens}) => {
      attempts++;
      return {responses: tokens.map(() => ({success: false, error: {code: 'messaging/server-unavailable'}}))};
    },
  }});
  assert.equal(result.deliveryStatus, 'failed');
  assert.equal(attempts, 3);
  assert.equal(Object.values(db.docs.visitorNotificationDeliveries)[0].attempts, 3);
});

test('permanent FCM token failures are not retried and stale device is removed', async () => {
  const db = fakeDb();
  const event = {
    params: {visitorId: 'visitor-permanent'},
    data: {
      before: {data: () => ({status: 'expected'})},
      after: {data: () => ({status: 'inside', actualArrival: {toMillis: () => 4}, checkedInBy: 'security1', hostUserId: 'resident1', communityId: 'community-a'})},
    },
  };
  let attempts = 0;
  const result = await dispatchVisitorDecisionCore({db, event, waitForRetry: async () => {}, messaging: {
    sendEachForMulticast: async ({tokens}) => {
      attempts++;
      return {responses: tokens.map(() => ({success: false, error: {code: 'messaging/registration-token-not-registered'}}))};
    },
  }});
  assert.equal(result.deliveryStatus, 'failed');
  assert.equal(attempts, 1);
  assert.equal(db.docs.notifications && Object.keys(db.docs.notifications).length, 1);
  assert.equal(db.devices[0].active, false);
});

test('duplicate event does not create a second resident record or resend a delivered push', async () => {
  const db = fakeDb();
  const event = {
    params: {visitorId: 'visitor-duplicate'},
    data: {
      before: {data: () => ({status: 'expected'})},
      after: {data: () => ({status: 'inside', actualArrival: {toMillis: () => 4}, checkedInBy: 'security1', hostUserId: 'resident1', communityId: 'community-a'})},
    },
  };
  let sends = 0;
  const messaging = {sendEachForMulticast: async ({tokens}) => {
    sends++;
    return {responses: tokens.map(() => ({success: true}))};
  }};
  const first = await dispatchVisitorDecisionCore({db, event, messaging, waitForRetry: async () => {}});
  const duplicate = await dispatchVisitorDecisionCore({db, event: {...event, id: 'duplicate-event-id'}, messaging, waitForRetry: async () => {}});
  assert.equal(first.deliveryStatus, 'sent');
  assert.equal(duplicate.duplicate, true);
  assert.equal(sends, 1);
  assert.equal(Object.keys(db.docs.notifications).length, 1);
  assert.equal(Object.keys(db.docs.visitorNotificationDeliveries).length, 1);
});

test('FCM outage leaves the in-app visitor event and visitor decision intact', async () => {
  const db = fakeDb();
  const event = {
    params: {visitorId: 'visitor-push-outage'},
    data: {
      before: {data: () => ({status: 'inside', departure: null})},
      after: {data: () => ({status: 'completed', departure: {toMillis: () => 6}, checkedOutBy: 'security1',
        visitorName: 'Guest Offline', hostUserId: 'resident1', communityId: 'community-a'})},
    },
  };
  const result = await dispatchVisitorDecisionCore({db, event, waitForRetry: async () => {}, messaging: {
    sendEachForMulticast: async () => { throw new Error('FCM unavailable'); },
  }});
  assert.equal(result.deliveryStatus, 'failed');
  assert.equal(Object.values(db.docs.notifications).length, 1);
  assert.equal(Object.values(db.docs.notifications)[0].eventType, 'visitor_checked_out');
  assert.equal(Object.values(db.docs.notifications)[0].deliveryStatus, 'failed');
});

test('visitor transition from another community cannot notify this host', async () => {
  const db = fakeDb();
  let sends = 0;
  const result = await dispatchVisitorDecisionCore({db, waitForRetry: async () => {}, messaging: {
    sendEachForMulticast: async () => { sends++; return {responses: []}; },
  }, event: {
    params: {visitorId: 'visitor-cross-community'},
    data: {
      before: {data: () => ({status: 'expected', communityId: 'community-b'})},
      after: {data: () => ({status: 'approved', isApproved: true, approvedAt: new Date(), approvedBy: 'admin2',
        visitorName: 'Guest Other', hostUserId: 'resident1', communityId: 'community-b'})},
    },
  }});
  assert.equal(result.ignored, true);
  assert.equal(sends, 0);
  assert.equal(Object.keys(db.docs.notifications || {}).length, 0);
});

test('visitor decision trigger does not enable unbounded Cloud Event retries', () => {
  const source = fs.readFileSync(require.resolve('../src/index'), 'utf8');
  const trigger = source.match(/exports\.dispatchVisitorDecisionNotification = onDocumentUpdated\(\{([\s\S]*?)\}, \(event\)/);
  assert.ok(trigger);
  assert.match(trigger[1], /retry:\s*false/);
});

test('visitor notification records and push data contain no credential material', async () => {
  const db = fakeDb();
  let push;
  await dispatchVisitorDecisionCore({db, waitForRetry: async () => {}, messaging: {
    sendEachForMulticast: async (message) => {
      push = message;
      return {responses: message.tokens.map(() => ({success: true}))};
    },
  }, event: {
    params: {visitorId: 'visitor-no-secrets'},
    data: {
      before: {data: () => ({status: 'expected'})},
      after: {data: () => ({status: 'inside', actualArrival: {toMillis: () => 5}, checkedInBy: 'security1',
        verificationMethod: 'qr', qrToken: 'must-not-escape', visitorPassCode: 'must-not-escape',
        credentialHash: 'must-not-escape', visitorName: 'Guest Safe', hostUserId: 'resident1', communityId: 'community-a'})},
    },
  }});
  const serialized = JSON.stringify({notifications: db.docs.notifications, push});
  assert.doesNotMatch(serialized, /must-not-escape/);
  const record = Object.values(db.docs.notifications)[0];
  assert.equal(record.eventType, 'visitor_checked_in');
  assert.equal(record.data.verificationMethod, 'qr');
});
