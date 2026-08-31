const test = require("node:test");
const assert = require("node:assert/strict");
const {
  APP_CONTEXTS,
  registerNotificationDeviceCore,
  sendCanonicalNotification,
  sendNotificationCore,
  unregisterNotificationDeviceCore,
} = require("../src/notifications");

const RESIDENT_ANDROID = "1:551984029668:android:ef652ea4d8e070ca0db1f1";
const ADMIN_ANDROID = "1:551984029668:android:322fd085a03f0ff70db1f1";
const phoneAuth = (uid) => ({
  uid,
  token: {
    phone_number: "+639171234567",
    firebase: {sign_in_provider: "phone"},
  },
});

function fakeDb(seed = {}) {
  const values = new Map(Object.entries(seed));
  const snapshotFor = (ref) => ({
    id: ref.id,
    ref,
    exists: values.has(ref.path),
    data: () => values.get(ref.path),
  });
  const makeRef = (collectionName, id) => ({
    id,
    path: `${collectionName}/${id}`,
    get: async function() {
      return snapshotFor(this);
    },
    delete: async function() {
      values.delete(this.path);
    },
    update: async function(data) {
      values.set(this.path, {...values.get(this.path), ...data});
    },
  });
  const collection = (name) => ({
    doc: (id) => makeRef(name, id),
    where: (field, operator, expected) => {
      assert.equal(operator, "==");
      return {
        get: async () => ({
          docs: [...values.entries()]
            .filter(([path, data]) => path.startsWith(`${name}/`) && data[field] === expected)
            .map(([path]) => snapshotFor(makeRef(name, path.split("/")[1]))),
        }),
      };
    },
  });
  return {
    values,
    collection,
    batch() {
      const operations = [];
      return {
        delete: (ref) => operations.push(() => values.delete(ref.path)),
        set: (ref, data, options) => operations.push(() => {
          const previous = options?.merge ? values.get(ref.path) ?? {} : {};
          values.set(ref.path, {...previous, ...data});
        }),
        commit: async () => operations.forEach((operation) => operation()),
      };
    },
    runTransaction: async (callback) => callback({
      get: async (ref) => snapshotFor(ref),
      set: (ref, data, options) => {
        const previous = options?.merge ? values.get(ref.path) ?? {} : {};
        values.set(ref.path, {...previous, ...data});
      },
    }),
  };
}

const activeCommunity = {isActive: true};
const activeResident = {
  uid: "resident-a",
  role: "resident",
  communityId: "COMMUNITY_A",
  approvalStatus: "approved",
  isActive: true,
  status: "active",
};
const activeAdmin = {
  uid: "admin-a",
  role: "admin",
  isActive: true,
  authorizedCommunityIds: ["COMMUNITY_A", "COMMUNITY_B"],
};

test("all configured Firebase app IDs have a single trusted role and platform", () => {
  assert.equal(Object.keys(APP_CONTEXTS).length, 6);
  assert.deepEqual(APP_CONTEXTS[RESIDENT_ANDROID], {
    appId: "resident",
    platform: "android",
    role: "resident",
  });
});

test("unknown App Check app IDs are rejected", async () => {
  const db = fakeDb();
  await assert.rejects(
    registerNotificationDeviceCore({
      db,
      auth: phoneAuth("resident-a"),
      app: {appId: "forged-app"},
      data: {installationId: "installation_123456", token: "token_12345678901234567890"},
    }),
    {code: "failed-precondition"},
  );
});

test("Resident registration ignores a forged community and uses the profile", async () => {
  const db = fakeDb({
    "users/resident-a": activeResident,
    "communities/COMMUNITY_A": activeCommunity,
  });
  const result = await registerNotificationDeviceCore({
    db,
    auth: phoneAuth("resident-a"),
    app: {appId: RESIDENT_ANDROID},
    data: {
      installationId: "installation_123456",
      token: "token_12345678901234567890",
      selectedCommunityId: "COMMUNITY_B",
      role: "admin",
    },
  });
  assert.equal(result.communityId, "COMMUNITY_A");
  assert.equal(result.role, "resident");
  const stored = db.values.get(`notificationDevices/${result.deviceId}`);
  assert.equal(stored.communityId, "COMMUNITY_A");
  assert.equal(stored.appId, "resident");
  assert.equal(stored.platform, "android");
  assert.equal(stored.audienceKey, "resident|resident|COMMUNITY_A|resident-a");
});

test("multi-community Admin registration requires an authorized selected tenant", async () => {
  const db = fakeDb({
    "admins/admin-a": activeAdmin,
    "communities/COMMUNITY_A": activeCommunity,
  });
  await assert.rejects(
    registerNotificationDeviceCore({
      db,
      auth: phoneAuth("admin-a"),
      app: {appId: ADMIN_ANDROID},
      data: {
        installationId: "installation_123456",
        token: "token_12345678901234567890",
        selectedCommunityId: "COMMUNITY_X",
      },
    }),
    {code: "failed-precondition"},
  );
});

test("logout removes only the authenticated installation record", async () => {
  const db = fakeDb({
    "users/resident-a": activeResident,
    "communities/COMMUNITY_A": activeCommunity,
  });
  const registered = await registerNotificationDeviceCore({
    db,
    auth: phoneAuth("resident-a"),
    app: {appId: RESIDENT_ANDROID},
    data: {
      installationId: "installation_123456",
      token: "token_12345678901234567890",
    },
  });
  const removed = await unregisterNotificationDeviceCore({
    db,
    auth: phoneAuth("resident-a"),
    app: {appId: RESIDENT_ANDROID},
    data: {installationId: "installation_123456"},
  });

  assert.equal(removed.removed, true);
  assert.equal(db.values.has(`notificationDevices/${registered.deviceId}`), false);
});

test("sender rejects a Resident from another community", async () => {
  const db = fakeDb({
    "admins/admin-a": activeAdmin,
    "users/resident-a": {...activeResident, communityId: "COMMUNITY_B"},
    "communities/COMMUNITY_A": activeCommunity,
  });
  await assert.rejects(
    sendNotificationCore({
      db,
      messaging: {sendEachForMulticast: async () => assert.fail("must not send")},
      auth: phoneAuth("admin-a"),
      app: {appId: ADMIN_ANDROID},
      data: {
        communityId: "COMMUNITY_A",
        recipientUid: "resident-a",
        title: "Visitor approved",
        message: "Your visitor was approved.",
        category: "visitor",
        priority: "high",
        sourceEntityId: "visitor-1",
      },
    }),
    {code: "failed-precondition"},
  );
});

test("sender uses only canonical app/tenant tokens, removes stale tokens, and deduplicates", async () => {
  const db = fakeDb({
    "admins/admin-a": activeAdmin,
    "users/resident-a": activeResident,
    "communities/COMMUNITY_A": activeCommunity,
    "notificationDevices/device-valid": {
      uid: "resident-a",
      communityId: "COMMUNITY_A",
      role: "resident",
      appId: "resident",
      token: "token_valid_123456789012345",
      audienceKey: "resident|resident|COMMUNITY_A|resident-a",
      active: true,
    },
    "notificationDevices/device-stale": {
      uid: "resident-a",
      communityId: "COMMUNITY_A",
      role: "resident",
      appId: "resident",
      token: "token_stale_123456789012345",
      audienceKey: "resident|resident|COMMUNITY_A|resident-a",
      active: true,
    },
    "notificationDevices/device-wrong-app": {
      uid: "resident-a",
      communityId: "COMMUNITY_A",
      role: "resident",
      appId: "admin",
      token: "token_wrong_1234567890123456",
      audienceKey: "admin|resident|COMMUNITY_A|resident-a",
      active: true,
    },
  });
  const messages = [];
  const messaging = {
    sendEachForMulticast: async (message) => {
      messages.push(message);
      return {
        successCount: 1,
        failureCount: 1,
        responses: [
          {success: true},
          {
            success: false,
            error: {code: "messaging/registration-token-not-registered"},
          },
        ],
      };
    },
  };
  const args = {
    db,
    messaging,
    auth: phoneAuth("admin-a"),
    app: {appId: ADMIN_ANDROID},
    data: {
      communityId: "COMMUNITY_A",
      recipientUid: "resident-a",
      title: "Visitor approved",
      message: "Your visitor was approved.",
      category: "visitor",
      priority: "high",
      sourceEntityId: "visitor-1",
    },
  };
  const first = await sendNotificationCore(args);
  assert.equal(first.deliveryStatus, "partial");
  assert.equal(messages.length, 1);
  assert.deepEqual(messages[0].data, {
    type: "notification",
    entityId: first.notificationId,
    communityId: "COMMUNITY_A",
  });
  assert.deepEqual(messages[0].tokens, [
    "token_valid_123456789012345",
    "token_stale_123456789012345",
  ]);
  assert.equal(db.values.has("notificationDevices/device-stale"), false);
  assert.equal(db.values.has("notificationDevices/device-wrong-app"), true);

  const second = await sendNotificationCore(args);
  assert.equal(second.duplicate, true);
  assert.equal(messages.length, 1);
});

test("reusable sender resolves Security recipients and uses only Security app tokens", async () => {
  const db = fakeDb({
    "communities/COMMUNITY_A": activeCommunity,
    "securityStaff/security-a": {
      uid: "security-a",
      role: "security",
      communityId: "COMMUNITY_A",
      isActive: true,
    },
    "notificationDevices/security-device": {
      uid: "security-a",
      communityId: "COMMUNITY_A",
      role: "security",
      appId: "security",
      token: "security_token_123456789012345",
      audienceKey: "security|security|COMMUNITY_A|security-a",
      active: true,
    },
    "notificationDevices/resident-device": {
      uid: "security-a",
      communityId: "COMMUNITY_A",
      role: "security",
      appId: "resident",
      token: "resident_token_123456789012345",
      audienceKey: "resident|security|COMMUNITY_A|security-a",
      active: true,
    },
  });
  let sent;
  const result = await sendCanonicalNotification({
    db,
    messaging: {
      sendEachForMulticast: async (message) => {
        sent = message;
        return {
          successCount: 1,
          failureCount: 0,
          responses: [{success: true}],
        };
      },
    },
    recipientUid: "security-a",
    communityId: "COMMUNITY_A",
    role: "security",
    appId: "security",
    notificationId: "notification-security-a",
    title: "Gate updated",
    message: "Your gate assignment changed.",
  });

  assert.equal(result.successCount, 1);
  assert.deepEqual(sent.tokens, ["security_token_123456789012345"]);
});
