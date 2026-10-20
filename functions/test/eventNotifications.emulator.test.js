const test = require("node:test");
const assert = require("node:assert/strict");
const { initializeApp, deleteApp } = require("firebase-admin/app");
const { getFirestore, Timestamp } = require("firebase-admin/firestore");
const {
  notifyCreatedEventCore: notify,
  eventNotificationId,
} = require("../src/event_notifications");
const { registerNotificationDeviceCore } = require("../src/notifications");
const enabled = !!process.env.FIRESTORE_EMULATOR_HOST;
let app, db, sends;
const resident = (uid, changes = {}) => ({
  uid,
  communityId: "EVENT_A",
  role: "resident",
  approvalStatus: "approved",
  isActive: true,
  status: "active",
  residentType: "owner",
  ...changes,
});
async function seed() {
  const values = {
    "communities/EVENT_A": { isActive: true },
    "communities/EVENT_B": { isActive: true },
    "admins/event-admin": {
      uid: "event-admin",
      role: "admin",
      isActive: true,
      authorizedCommunityIds: ["EVENT_A"],
    },
    "subscriptions/EVENT_A": {
      planId: "plus",
      status: "active",
      startsAt: null,
      endsAt: null,
    },
    "events_announcements/new-event": {
      communityId: "EVENT_A",
      adminId: "event-admin",
      type: "event",
      title: "Synthetic event",
      status: "upcoming",
    },
    "users/event-one": resident("event-one"),
    "users/event-two": resident("event-two"),
    "users/event-other": resident("event-other", { communityId: "EVENT_B" }),
    "users/event-inactive": resident("event-inactive", { isActive: false }),
    "users/event-pending": resident("event-pending", {
      approvalStatus: "pending",
    }),
    "users/event-unverified": resident("event-unverified", {
      residentType: "tenant",
    }),
    "users/event-forged": resident("someone-else"),
  };
  for (const name of [
    "notifications",
    "notificationDevices",
    "users",
    "events_announcements",
  ]) {
    const docs = await db.collection(name).get();
    for (const doc of docs.docs) await doc.ref.delete();
  }
  for (const [path, data] of Object.entries(values))
    await db.doc(path).set(data);
  for (const uid of [
    "event-one",
    "event-two",
    "event-other",
    "event-inactive",
  ]) {
    const cid = uid === "event-other" ? "EVENT_B" : "EVENT_A";
    await db.doc(`notificationDevices/${uid}`).set({
      uid,
      communityId: cid,
      role: "resident",
      appId: "resident",
      audienceKey: `resident|resident|${cid}|${uid}`,
      token: `synthetic-${uid}`,
      active: true,
    });
  }
  sends = [];
}
const messaging = {
  sendEachForMulticast: async (message) => {
    sends.push(message);
    return {
      successCount: message.tokens.length,
      failureCount: 0,
      responses: message.tokens.map(() => ({ success: true })),
    };
  },
};
const run = (name, fn) =>
  test(name, { skip: !enabled }, async () => {
    await seed();
    await fn();
  });
test.before(() => {
  if (enabled) {
    app = initializeApp(
      { projectId: "demo-hominode-storage-images" },
      "event-notifications",
    );
    db = getFirestore(app);
  }
});
test.after(async () => {
  if (app) await deleteApp(app);
});
run(
  "only eligible same-community residents receive inbox records and correctly targeted event pushes",
  async () => {
    assert.deepEqual(await notify({ db, messaging, eventId: "new-event" }), {
      created: 2,
      attempted: 2,
    });
    const docs = await db.collection("notifications").get();
    assert.deepEqual(docs.docs.map((d) => d.data().recipientId).sort(), [
      "event-one",
      "event-two",
    ]);
    assert.deepEqual(sends.flatMap((s) => s.tokens).sort(), [
      "synthetic-event-one",
      "synthetic-event-two",
    ]);
    for (const doc of docs.docs) {
      assert.equal(doc.data().title, "Synthetic event");
      assert.equal(doc.data().data.eventId, "new-event");
      assert.equal(doc.data().data.route, "events");
      assert.equal(doc.data().communityId, "EVENT_A");
      assert.equal(doc.data().isRead, false);
    }
    assert.equal(sends[0].data.route, "events");
    assert.equal(
      sends[0].data.entityId,
      eventNotificationId("EVENT_A", "new-event", "event-one"),
    );
  },
);
run(
  "re-execution, concurrent delivery, and edits do not duplicate records or pushes",
  async () => {
    await Promise.all([
      notify({ db, messaging, eventId: "new-event" }),
      notify({ db, messaging, eventId: "new-event" }),
    ]);
    await db
      .doc("events_announcements/new-event")
      .update({ title: "Edited event" });
    await notify({ db, messaging, eventId: "new-event" });
    assert.equal((await db.collection("notifications").get()).size, 2);
    assert.equal(sends.length, 2);
  },
);
run(
  "push opt-out and DND preserve the in-app inbox without sending FCM",
  async () => {
    await db
      .doc("notificationDevices/event-one")
      .update({ eventPreferences: { push_notifications: false } });
    await db.doc("notificationDevices/event-two").update({
      eventPreferences: {
        dnd_enabled: true,
        dnd_start_hour: 0,
        dnd_end_hour: 0,
      },
    });
    await notify({ db, messaging, eventId: "new-event" });
    assert.equal(sends.length, 0);
    assert.equal((await db.collection("notifications").get()).size, 2);
  },
);
run(
  "registration validates and preserves event preferences across older-client refreshes",
  async () => {
    const args = {
      db,
      auth: {
        uid: "event-one",
        token: {
          phone_number: "+639170000000",
          firebase: { sign_in_provider: "phone" },
        },
      },
      app: { appId: "1:551984029668:android:ef652ea4d8e070ca0db1f1" },
      data: {
        installationId: "synthetic-installation",
        token: "synthetic-token-1234567890",
        eventPreferences: { event_reminders: false },
      },
    };
    const result = await registerNotificationDeviceCore(args);
    assert.equal(
      (await db.doc(`notificationDevices/${result.deviceId}`).get()).data()
        .eventPreferences.event_reminders,
      false,
    );
    delete args.data.eventPreferences;
    await registerNotificationDeviceCore(args);
    assert.equal(
      (await db.doc(`notificationDevices/${result.deviceId}`).get()).data()
        .eventPreferences.event_reminders,
      false,
    );
    await assert.rejects(
      registerNotificationDeviceCore({
        ...args,
        data: { ...args.data, eventPreferences: { dnd_start_hour: 99 } },
      }),
      { code: "invalid-argument" },
    );
  },
);
run(
  "Essential and expired subscriptions never send restricted event notifications",
  async () => {
    for (const state of [
      { planId: "essential", status: "active", endsAt: null },
      { planId: "pro", status: "active", endsAt: Timestamp.fromMillis(1) },
    ]) {
      await db.doc("subscriptions/EVENT_A").set(state);
      assert.deepEqual(await notify({ db, messaging, eventId: "new-event" }), {
        skipped: true,
      });
    }
    assert.equal((await db.collection("notifications").get()).size, 0);
  },
);
run(
  "announcements, unauthorized authors and missing events cannot emit event notifications",
  async () => {
    assert.deepEqual(
      await notify({ db, messaging, eventId: "missing-event" }),
      { skipped: true },
    );
    await db
      .doc("events_announcements/new-event")
      .update({ type: "announcement" });
    assert.deepEqual(await notify({ db, messaging, eventId: "new-event" }), {
      skipped: true,
    });
    await db
      .doc("events_announcements/new-event")
      .update({ type: "event", communityId: "EVENT_B" });
    assert.deepEqual(await notify({ db, messaging, eventId: "new-event" }), {
      skipped: true,
    });
    assert.equal(sends.length, 0);
  },
);
run(
  "ambiguous FCM failure keeps the inbox and is not replayed on retry",
  async () => {
    let attempts = 0;
    const failed = {
      sendEachForMulticast: async () => {
        attempts++;
        throw Error("synthetic delivery failure");
      },
    };
    await notify({ db, messaging: failed, eventId: "new-event" });
    await notify({ db, messaging: failed, eventId: "new-event" });
    assert.equal(attempts, 2);
    assert.equal((await db.collection("notifications").get()).size, 2);
    assert.ok(
      (await db.collection("notifications").get()).docs.every(
        (d) => d.data().deliveryStatus === "failed",
      ),
    );
  },
);
run(
  "existing inbox Rules allow only the intended resident to query/read and mark the event notification read",
  async () => {
    const {
      initializeTestEnvironment,
      assertFails,
      assertSucceeds,
    } = require("@firebase/rules-unit-testing");
    const {
      doc,
      getDoc,
      getDocs,
      collection,
      query,
      where,
      updateDoc,
      serverTimestamp,
    } = require("firebase/firestore");
    const fs = require("node:fs");
    const env = await initializeTestEnvironment({
      projectId: "demo-hominode-storage-images",
      firestore: {
        rules: fs.readFileSync(
          "deployment/storage-minimal/firestore.rules",
          "utf8",
        ),
      },
    });
    try {
      await notify({ db, messaging, eventId: "new-event" });
      const id = eventNotificationId("EVENT_A", "new-event", "event-one");
      const client = env.authenticatedContext("event-one").firestore();
      const ref = doc(client, "notifications", id);
      await assertSucceeds(getDoc(ref));
      await assertSucceeds(
        getDocs(
          query(
            collection(client, "notifications"),
            where("recipientId", "==", "event-one"),
            where("communityId", "==", "EVENT_A"),
            where("audience", "==", "resident"),
            where("role", "==", "resident"),
            where("appId", "==", "resident"),
          ),
        ),
      );
      await assertSucceeds(
        updateDoc(ref, { isRead: true, readAt: serverTimestamp() }),
      );
      await assertFails(updateDoc(ref, { title: "tampered event" }));
      await assertFails(
        getDoc(
          doc(
            env.authenticatedContext("event-two").firestore(),
            "notifications",
            id,
          ),
        ),
      );
      await assertFails(
        getDoc(
          doc(
            env.authenticatedContext("event-other").firestore(),
            "notifications",
            id,
          ),
        ),
      );
      await assertFails(
        getDoc(
          doc(env.unauthenticatedContext().firestore(), "notifications", id),
        ),
      );
    } finally {
      await env.cleanup();
    }
  },
);
