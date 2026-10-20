const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require("@firebase/rules-unit-testing");
const {
  ref,
  uploadBytes,
  getBytes,
  getDownloadURL,
  deleteObject,
} = require("firebase/storage");
const {
  doc,
  setDoc,
  getDoc,
  getDocs,
  query,
  collection,
  where,
  serverTimestamp,
} = require("firebase/firestore");
const { storageRulesDirectory } = require("./helpers/storage_rules_variant");
const enabled =
  !!process.env.FIRESTORE_EMULATOR_HOST &&
  !!process.env.FIREBASE_STORAGE_EMULATOR_HOST;
const projectId = "demo-hominode-storage-images";
const bucket = `${projectId}.appspot.com`;
const phone = "+639170000000";
let env;
const run = (name, fn) => test(name, { skip: !enabled }, fn);
const context = (uid) =>
  uid
    ? env.authenticatedContext(uid, {
        phone_number: phone,
        firebase: { sign_in_provider: "phone" },
      })
    : env.unauthenticatedContext();
const image = (uid, community = "A", event = "event") =>
  ref(
    context(uid).storage(bucket),
    `event_images/${community}/${event}/photo.jpg`,
  );
const bytes = new Uint8Array([255, 216, 255, 217]);
const upload = (object) =>
  uploadBytes(object, bytes, { contentType: "image/jpeg" });
test.before(async () => {
  if (!enabled) return;
  env = await initializeTestEnvironment({
    projectId,
    firestore: {
      rules: fs.readFileSync(
        path.join(storageRulesDirectory(), "firestore.rules"),
        "utf8",
      ),
    },
    storage: {
      rules: fs.readFileSync(
        path.join(storageRulesDirectory(), "storage.rules"),
        "utf8",
      ),
    },
  });
});
test.after(async () => {
  if (env) await env.cleanup();
});
test.beforeEach(async () => {
  if (!enabled) return;
  await env.clearFirestore();
  await env.clearStorage();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const store = ctx.firestore();
    await setDoc(doc(store, "subscriptionPlans/plus"), {
      features: { events: true },
    });
    for (const id of ["A", "B"]) {
      await setDoc(doc(store, "communities", id), { isActive: true });
      await setDoc(doc(store, "subscriptions", id), {
        planId: "plus",
        status: "active",
      });
    }
    for (const [uid, community] of [
      ["admin", "A"],
      ["foreign-admin", "B"],
    ])
      await setDoc(doc(store, "admins", uid), {
        uid,
        phoneNumber: phone,
        role: "admin",
        isActive: true,
        authorizedCommunityIds: [community],
      });
    await setDoc(doc(store, "admins/inactive"), {
      uid: "inactive",
      phoneNumber: phone,
      role: "admin",
      isActive: false,
      authorizedCommunityIds: ["A"],
    });
    for (const [uid, communityId] of [
      ["resident", "A"],
      ["foreign-resident", "B"],
    ])
      await setDoc(doc(store, "users", uid), {
        uid,
        phoneNumber: phone,
        communityId,
        role: "resident",
        isActive: true,
        approvalStatus: "approved",
        status: "active",
        residentType: "owner",
        ownershipType: "owner",
        identityVerificationStatus: "not_required",
      });
  });
});
run(
  "authorized Admin publishes event metadata consumed by a second same-community reader",
  async () => {
    await assertSucceeds(upload(image("admin")));
    const url = await getDownloadURL(image("admin"));
    assert.ok(url.startsWith("http")); // Local emulator URL only; never print a bearer link.
    const store = context("admin").firestore();
    const recovery = () =>
      getDocs(
        query(
          collection(store, "events_announcements"),
          where("communityId", "==", "A"),
          where("type", "==", "event"),
        ),
      );
    assert.equal((await assertSucceeds(recovery())).size, 0);
    await assertSucceeds(
      setDoc(doc(store, "events_announcements/event"), {
        communityId: "A",
        type: "event",
        adminId: "admin",
        title: "Gathering",
        imageUrl: url,
        imageUrls: [url],
        images: [
          {
            url,
            storagePath: "event_images/A/event/photo.jpg",
            name: "photo.jpg",
          },
        ],
        createdAt: serverTimestamp(),
      }),
    );
    assert.equal((await assertSucceeds(recovery())).size, 1);
    const data = (
      await assertSucceeds(
        getDoc(
          doc(context("resident").firestore(), "events_announcements/event"),
        ),
      )
    ).data();
    assert.equal(data.imageUrl, url);
    assert.equal(data.localImagePath, undefined);
    await assertSucceeds(getBytes(image("resident")));
  },
);
run(
  "foreign-community Admin and Resident cannot upload, read via SDK or delete event objects",
  async () => {
    await upload(image("admin"));
    for (const uid of ["foreign-admin", "foreign-resident"]) {
      await assertFails(upload(image(uid)));
      await assertFails(getBytes(image(uid)));
      await assertFails(deleteObject(image(uid)));
    }
  },
);
run(
  "unauthenticated callers cannot upload, SDK-read or delete event objects",
  async () => {
    await upload(image("admin"));
    await assertFails(upload(image(null)));
    await assertFails(getBytes(image(null)));
    await assertFails(deleteObject(image(null)));
  },
);
run(
  "same-community resident may read but cannot upload or delete",
  async () => {
    await upload(image("admin"));
    await assertSucceeds(getBytes(image("resident")));
    await assertFails(upload(image("resident")));
    await assertFails(deleteObject(image("resident")));
  },
);
run("inactive Admin cannot upload or delete", async () => {
  await upload(image("admin"));
  await assertFails(upload(image("inactive")));
  await assertFails(deleteObject(image("inactive")));
});
run(
  "authorized Admin may delete only their authorized community event objects",
  async () => {
    await upload(image("admin"));
    await upload(image("foreign-admin", "B"));
    await assertSucceeds(deleteObject(image("admin")));
    await assertFails(deleteObject(image("admin", "B")));
  },
);
run("event uploads enforce existing MIME and size limits", async () => {
  await assertFails(
    uploadBytes(image("admin"), bytes, { contentType: "image/gif" }),
  );
  await assertFails(
    uploadBytes(image("admin"), new Uint8Array(5 * 1024 * 1024 + 1), {
      contentType: "image/jpeg",
    }),
  );
});
run(
  "foreign community event metadata cannot be created or read by an unrelated Admin",
  async () => {
    const store = context("admin").firestore();
    await assertFails(
      setDoc(doc(store, "events_announcements/foreign"), {
        communityId: "B",
        type: "event",
        adminId: "admin",
        title: "Foreign",
      }),
    );
    await setDoc(
      doc(context("foreign-admin").firestore(), "events_announcements/foreign"),
      {
        communityId: "B",
        type: "event",
        adminId: "foreign-admin",
        title: "Foreign",
      },
    );
    await assertFails(getDoc(doc(store, "events_announcements/foreign")));
  },
);
