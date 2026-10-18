const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { initializeTestEnvironment } = require("@firebase/rules-unit-testing");
const { doc, getDoc, setDoc, updateDoc, serverTimestamp } = require("firebase/firestore");
const { ref, uploadBytes } = require("firebase/storage");
const { jpeg } = require("./helpers/storage_images_fixture");

const firestoreHost = process.env.FIRESTORE_EMULATOR_HOST;
const storageHost = process.env.FIREBASE_STORAGE_EMULATOR_HOST || process.env.STORAGE_EMULATOR_HOST;
const enabled = !!firestoreHost && !!storageHost;
const projectId = "demo-hominode-storage-images";
const bucket = `${projectId}.appspot.com`;
const directory = path.resolve(__dirname, "../../deployment/storage-minimal");
const phone = "+639170000000";
const resident = {
  uid: "r", role: "resident", phoneNumber: phone, isActive: true,
  approvalStatus: "approved", status: "active", communityId: "A",
  buildingId: "b", flatId: "f", residentType: "owner", ownershipType: "owner",
};
const invitation = {
  communityId: "A", buildingId: "b", flatId: "f", hostUserId: "r", residentId: "r",
  status: "expected", isApproved: false, approvedBy: null, approvedAt: null,
  actualArrival: null, departure: null,
};

const cases = [
  ["legacy signed-in own-profile read", true, (c) => c.get("legacy", "users/legacy", "password")],
  ["legacy profile name update without canonical phone", true, (c) => c.update("legacy", "users/legacy", { name: "Synthetic name" })],
  ["Admin auth remains independent of phone claim", true, (c) => c.get("a", "communities/A", "password")],
  ["cross-community Admin read denied", false, (c) => c.get("a", "communities/B")],
  ["Resident bill read", true, (c) => c.get("r", "bills/bill")],
  ["client bill amount mutation denied", false, (c) => c.update("a", "bills/bill", { amount: 43 })],
  ["financial ledger client creation denied", false, (c) => c.set("a", "paymentTransactions/forged", { communityId: "A", residentId: "r" })],
  ["legacy payment receipt upload without canonical phone", true, (c) => c.upload("legacy", `payment_receipts/A/bill/legacy/${c.variant}.jpg`)],
  ["foreign payment receipt upload denied", false, (c) => c.upload("other", `payment_receipts/A/bill/legacy/${c.variant}-foreign.jpg`)],
  ["facility upload preserves production Admin auth", true, (c) => c.upload("a", `facility_images/A/facility/${c.variant}.jpg`, "password")],
  ["event upload preserves production Admin auth", true, (c) => c.upload("a", `event_images/A/event/${c.variant}.jpg`, "password")],
  ["Resident direct visitor creation remains available", true, (c) => c.set("r", "visitors/new-visitor", invitation)],
  ["Security direct visitor read remains available", true, (c) => c.get("s", "visitors/visitor")],
  ["Security direct check-in remains available", true, (c) => c.update("s", "visitors/visitor", {
    status: "inside", isApproved: true, approvedBy: "s", approvedAt: serverTimestamp(),
    actualArrival: serverTimestamp(), checkedInBy: "s", updatedAt: serverTimestamp(),
  })],
  ["foreign visitor creation denied", false, (c) => c.set("foreign", "visitors/foreign-visitor", invitation)],
  ["Essential event access remains as production", true, (c) => c.get("r", "events_announcements/event")],
  ["Essential announcement access remains available", true, (c) => c.get("r", "events_announcements/announcement")],
  ["Resident SOS read remains available", true, (c) => c.get("r", "sosAlerts/sos")],
  ["cross-community SOS read denied", false, (c) => c.get("foreign", "sosAlerts/sos")],
  ["direct SOS alert creation denied", false, (c) => c.set("r", "sosAlerts/forged", { residentUid: "r", communityId: "A" })],
];

for (const variant of ["baseline", "minimal"]) {
  test.describe(`${variant}: unchanged production compatibility`, { skip: !enabled }, () => {
    let env;
    test.before(async () => {
      for (const host of [firestoreHost, storageHost]) {
        assert.match(host, /^(?:http:\/\/)?(?:127\.0\.0\.1|localhost):\d+$/, "localhost emulators only");
      }
      const [host, port] = firestoreHost.split(":");
      const [storageAddress, storagePort] = storageHost.replace("http://", "").split(":");
      const source = variant === "baseline" ? path.join(directory, "baseline") : directory;
      env = await initializeTestEnvironment({
        projectId,
        firestore: { host, port: Number(port), rules: fs.readFileSync(path.join(source, "firestore.rules"), "utf8") },
        storage: { host: storageAddress, port: Number(storagePort), rules: fs.readFileSync(path.join(source, "storage.rules"), "utf8") },
      });
    });
    test.beforeEach(async () => {
      await env.clearFirestore();
      const legacy = { ...resident, uid: "legacy", phone: phone };
      delete legacy.phoneNumber;
      const seed = {
        "communities/A": { isActive: true }, "communities/B": { isActive: true },
        "admins/a": { uid: "a", role: "admin", isActive: true, authorizedCommunityIds: ["A"], phoneNumber: "+639170000001" },
        "users/r": resident, "users/legacy": legacy,
        "users/other": { ...resident, uid: "other", communityId: "B", flatId: "other-flat" },
        "users/foreign": { ...resident, uid: "foreign", communityId: "B", flatId: "other-flat" },
        "securityStaff/s": { uid: "s", role: "security", isActive: true, communityId: "A" },
        "buildings/b": { communityId: "A" }, "flats/f": { communityId: "A", buildingId: "b" },
        "bills/bill": { communityId: "A", flatId: "f", residentId: "r", status: "pending", amount: 42 },
        "amenities/facility": { communityId: "A" },
        "events_announcements/event": { communityId: "A", type: "event" },
        "events_announcements/announcement": { communityId: "A", type: "announcement" },
        "subscriptions/A": { planId: "essential", status: "active" },
        "subscriptionPlans/essential": { features: { events: false } },
        "visitors/visitor": invitation,
        "sosAlerts/sos": { communityId: "A", residentUid: "r" },
      };
      await env.withSecurityRulesDisabled(async (context) => {
        await Promise.all(Object.entries(seed).map(([key, value]) => setDoc(doc(context.firestore(), key), value)));
      });
    });
    test.after(async () => { if (env) await env.cleanup(); });
    function context(uid, provider = "phone") {
      return env.authenticatedContext(uid, { phone_number: phone, firebase: { sign_in_provider: provider } });
    }
    for (const [name, allowed, action] of cases) {
      test(name, async () => {
        const client = {
          variant,
          get: (uid, key, provider) => getDoc(doc(context(uid, provider).firestore(), key)),
          set: (uid, key, value) => setDoc(doc(context(uid).firestore(), key), value),
          update: (uid, key, value) => updateDoc(doc(context(uid).firestore(), key), value),
          upload: (uid, key, provider) => uploadBytes(ref(context(uid, provider).storage(bucket), key), jpeg, { contentType: "image/jpeg" }),
        };
        let error;
        try { await action(client); } catch (failure) { error = failure; }
        if (allowed) assert.equal(error, undefined, `${name}: expected production operation to succeed`);
        else {
          assert.ok(error, `${name}: expected denial`);
          assert.match(error.code, /^(?:permission-denied|storage\/unauthorized)$/);
        }
      });
    }
  });
}
