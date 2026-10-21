const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const { sosStore } = require("./helpers/sos_store");
const {
  recordCreatedBillNotificationCore: record,
  billNotificationId,
} = require("../src/bill_notifications");
const { sendNotificationCore: send } = require("../src/notifications");
const { Timestamp } = require("firebase-admin/firestore");
async function fixture() {
  const db = sosStore();
  const seed = {
    "communities/C": { isActive: true },
    "users/r": {
      uid: "r",
      role: "resident",
      communityId: "C",
      isActive: true,
      approvalStatus: "approved",
      status: "active",
    },
    "admins/a": {
      uid: "a",
      role: "admin",
      isActive: true,
      authorizedCommunityIds: ["C"],
    },
    "bills/b": {
      schemaVersion: 2,
      currency: "INR",
      communityId: "C",
      residentId: "r",
      userId: "r",
      amountMinor: 1000,
    },
  };
  for (const [path, value] of Object.entries(seed))
    await db.collection(path.split("/")[0]).doc(path.split("/")[1]).set(value);
  let pushes = 0;
  await db.collection("notificationDevices").doc("device").set({
    uid: "r",
    communityId: "C",
    role: "resident",
    appId: "resident",
    active: true,
    token: "synthetic-token",
    audienceKey: "resident|resident|C|r",
  });
  const args = {
    db,
    auth: {
      uid: "a",
      token: {
        phone_number: "+639170000000",
        firebase: { sign_in_provider: "phone" },
      },
    },
    app: { appId: "1:551984029668:android:322fd085a03f0ff70db1f1" },
    messaging: {
      sendEachForMulticast: async () => {
        pushes++;
        return {
          responses: [{ success: true }],
          successCount: 1,
          failureCount: 0,
        };
      },
    },
    data: {
      communityId: "C",
      recipientUid: "r",
      category: "payment",
      priority: "high",
      sourceEntityId: "b",
      title: "New Bill Created",
      message: "New synthetic bill",
    },
  };
  return { db, args, pushes: () => pushes };
}
test("new V2 bill is persisted once with correct resident and bill target without changing financial records or sending another push", async () => {
  const { db } = await fixture();
  const before = await db.collection("bills").doc("b").get();
  await Promise.all([record({ db, billId: "b" }), record({ db, billId: "b" })]);
  const docs = await db.collection("notifications").get();
  assert.equal(docs.size, 1);
  assert.equal(docs.docs[0].data().data.billId, "b");
  assert.equal(docs.docs[0].data().recipientId, "r");
  assert.deepEqual(
    (await db.collection("bills").doc("b").get()).data(),
    before.data(),
  );
});
for (const first of ["trigger", "admin"])
  test(`${first} first: existing Admin push and creation-trigger retry share one inbox identity`, async () => {
    const f = await fixture();
    if (first === "trigger") await record({ db: f.db, billId: "b" });
    else await send(f.args);
    await send(f.args);
    await record({ db: f.db, billId: "b" });
    await send(f.args);
    assert.equal((await f.db.collection("notifications").get()).size, 1);
    assert.equal(f.pushes(), 1);
  });
test("dismissed or read notifications are not resurrected by a billing retry", async () => {
  const f = await fixture();
  await record({ db: f.db, billId: "b" });
  const ref = f.db
    .collection("notifications")
    .doc(billNotificationId("C", "r", "b"));
  await ref.update({ isRead: true, deletedAt: Timestamp.now() });
  await send(f.args);
  await record({ db: f.db, billId: "b" });
  assert.equal(f.pushes(), 0);
  assert.equal((await ref.get()).data().isRead, true);
  assert.ok((await ref.get()).data().deletedAt);
});
test("foreign, inactive and mismatched bill ownership cannot receive a V2 inbox record", async () => {
  for (const update of [
    { communityId: "OTHER" },
    { isActive: false },
    { approvalStatus: "pending" },
  ]) {
    const f = await fixture();
    await f.db.collection("users").doc("r").update(update);
    assert.equal((await record({ db: f.db, billId: "b" })).created, false);
    assert.equal((await f.db.collection("notifications").get()).size, 0);
  }
  const f = await fixture();
  await f.db.collection("bills").doc("b").update({ userId: "other" });
  assert.equal((await record({ db: f.db, billId: "b" })).created, false);
});
test("creation-only export has no historical backfill or financial update trigger", () => {
  const source = fs.readFileSync(require.resolve("../src/index"), "utf8");
  assert.match(
    source,
    /exports\.recordResidentBillNotification = onDocumentCreated/,
  );
  assert.match(source, /document: "bills\/\{billId\}"/);
});

test("historical generic bill notification identity is reused rather than duplicated on retries", async () => {
  const f = await fixture();
  await f.db.collection("notifications").doc("historical-id").set({
    communityId: "C",
    recipientId: "r",
    audience: "resident",
    role: "resident",
    appId: "resident",
    sourceEntityId: "b",
    type: "payment",
    title: "New Bill Created",
    isRead: true,
    deliveryStatus: "sent",
  });
  await record({ db: f.db, billId: "b" });
  const result = await send(f.args);
  assert.equal(result.notificationId, "historical-id");
  assert.equal(result.duplicate, true);
  assert.equal((await f.db.collection("notifications").get()).size, 1);
  assert.equal(f.pushes(), 0);
});

for (const [name, preferences, expected] of [
  ["global push opt-out", { push_notifications: false }, 0],
  ["DND", { dnd_enabled: true, dnd_start_hour: 0, dnd_end_hour: 0 }, 0],
  ["event-only opt-out", { event_reminders: false }, 1],
])
  test(`bill push respects ${name} while retaining its inbox item`, async () => {
    const f = await fixture();
    await f.db
      .collection("notificationDevices")
      .doc("device")
      .update({ eventPreferences: preferences });
    await send(f.args);
    assert.equal(f.pushes(), expected);
    assert.equal((await f.db.collection("notifications").get()).size, 1);
  });
