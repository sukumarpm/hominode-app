const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const { storageRulesDirectory } = require("./helpers/storage_rules_variant");
const rulesDirectory = storageRulesDirectory();
const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require("@firebase/rules-unit-testing");
const { initializeApp, deleteApp } = require("firebase-admin/app");
const { getFirestore: adminFirestore } = require("firebase-admin/firestore");
const { getStorage: adminStorage } = require("firebase-admin/storage");
const {
  ref,
  uploadBytes,
  getMetadata,
  getDownloadURL,
  updateMetadata,
  deleteObject,
  listAll,
} = require("firebase/storage");
const { doc, setDoc, getDoc } = require("firebase/firestore");
const {
  prepareStorageImageUploadCore: prepare,
  completeStorageImageUploadCore: complete,
  readStorageImageCore: readImage,
} = require("../src/storage_images");

const storageHost =
  process.env.FIREBASE_STORAGE_EMULATOR_HOST ||
  process.env.STORAGE_EMULATOR_HOST;
const enabled = !!process.env.FIRESTORE_EMULATOR_HOST && !!storageHost;
const projectId = "demo-hominode-storage-images";
const bucketName = `${projectId}.appspot.com`;
const phone = "+639170000000";
const id = "a1111111-1111-4111-8111-111111111111";
const { jpeg } = require("./helpers/storage_images_fixture");
const bytes = new Uint8Array(jpeg);
const features = [
  "apartment",
  "profile",
  "community_wall",
  "complaints",
  "marketplace",
];
let env, app, db, bucket;
const run = (name, action) => test(name, { skip: !enabled }, action);
const claims = { phone_number: phone, firebase: { sign_in_provider: "phone" } };
const context = (uid) =>
  uid ? env.authenticatedContext(uid, claims) : env.unauthenticatedContext();
function path(
  feature,
  uid = feature === "apartment" ? "a" : "r",
  community = "A",
  assetId = id,
) {
  return feature === "apartment"
    ? `apartment_images/${community}/${uid}/${assetId}.jpg`
    : `resident_images/${community}/${uid}/${feature}/${assetId}.jpg`;
}
function metadata(feature, overrides = {}) {
  return {
    contentType: "image/jpeg",
    cacheControl: "private, no-store",
    customMetadata: {
      assetId: id,
      communityId: "A",
      ownerId: feature === "apartment" ? "a" : "r",
      feature,
      resourceId: feature === "profile" ? "r" : "target",
    },
    ...overrides,
  };
}
const object = (feature, uid, community = "A") =>
  ref(
    context(uid).storage(bucketName),
    path(feature, feature === "apartment" ? "a" : "r", community),
  );

test.before(async () => {
  if (!enabled) return;
  for (const address of [process.env.FIRESTORE_EMULATOR_HOST, storageHost]) {
    assert.match(
      address,
      /^(?:http:\/\/)?(?:127\.0\.0\.1|localhost):\d+$/,
      "tests only contact local emulators",
    );
  }
  const [firestoreHost, firestorePort] =
    process.env.FIRESTORE_EMULATOR_HOST.split(":");
  const [localStorageHost, storagePort] = storageHost
    .replace("http://", "")
    .split(":");
  env = await initializeTestEnvironment({
    projectId,
    firestore: {
      host: firestoreHost,
      port: Number(firestorePort),
      rules: fs.readFileSync(`${rulesDirectory}/firestore.rules`, "utf8"),
    },
    storage: {
      host: localStorageHost,
      port: Number(storagePort),
      rules: fs.readFileSync(`${rulesDirectory}/storage.rules`, "utf8"),
    },
  });
  app = initializeApp(
    { projectId, storageBucket: bucketName },
    "storage-image-tests",
  );
  db = adminFirestore(app);
  bucket = adminStorage(app).bucket();
});
test.beforeEach(async () => {
  if (!enabled) return;
  // rules-unit-testing.clearStorage only deletes root items, not objects under
  // prefixes. Traverse this synthetic demo bucket to isolate create-only cases.
  await env.withSecurityRulesDisabled(async (context) => {
    async function clear(reference) {
      const { items, prefixes } = await reference.listAll();
      await Promise.all(items.map((item) => item.delete()));
      for (const prefix of prefixes) await clear(prefix);
    }
    await clear(context.storage(bucketName).ref());
  });
  await env.clearFirestore();
  const resident = {
    uid: "r",
    phoneNumber: phone,
    role: "resident",
    isActive: true,
    approvalStatus: "approved",
    status: "active",
    communityId: "A",
    residentType: "owner",
    ownershipType: "owner",
  };
  const entries = {
    "communities/A": { isActive: true },
    "communities/B": { isActive: true },
    "admins/a": {
      uid: "a",
      phoneNumber: phone,
      role: "admin",
      isActive: true,
      authorizedCommunityIds: ["A"],
    },
    "admins/foreign-admin": {
      uid: "foreign-admin",
      phoneNumber: phone,
      role: "admin",
      isActive: true,
      authorizedCommunityIds: ["B"],
    },
    "users/r": resident,
    "users/other": { ...resident, uid: "other" },
    "users/foreign": { ...resident, uid: "foreign", communityId: "B" },
    "users/inactive": { ...resident, uid: "inactive", isActive: false },
    "users/pending": { ...resident, uid: "pending", approvalStatus: "pending" },
    "users/tenant": {
      ...resident,
      uid: "tenant",
      residentType: "tenant",
      ownershipType: "tenant",
      identityVerified: false,
    },
    "buildings/target": { communityId: "A" },
    "complaints/target": {
      communityId: "A",
      userId: "r",
      imageUrl: "https://example.invalid/legacy.jpg",
    },
  };
  await Promise.all(
    Object.entries(entries).map(([path, data]) => db.doc(path).set(data)),
  );
});
test.after(async () => {
  if (env) await env.cleanup();
  if (app) await deleteApp(app);
});

for (const feature of features) {
  run(
    `${feature}: authorized create and private owner get; anonymous and other users denied`,
    async () => {
      const owner = feature === "apartment" ? "a" : "r";
      await assertSucceeds(
        uploadBytes(object(feature, owner), bytes, metadata(feature)),
      );
      await assertSucceeds(getMetadata(object(feature, owner)));
      for (const uid of [null, "other", "foreign", "foreign-admin"]) {
        await assertFails(getMetadata(object(feature, uid)));
      }
    },
  );
  run(
    `${feature}: wrong owner, wrong community, wrong role and anonymous upload denied`,
    async () => {
      const owner = feature === "apartment" ? "a" : "r";
      for (const uid of [
        null,
        "other",
        "foreign",
        feature === "apartment" ? "r" : "a",
      ]) {
        await assertFails(
          uploadBytes(object(feature, uid), bytes, metadata(feature)),
        );
      }
      await assertFails(
        uploadBytes(
          object(feature, owner, "B"),
          bytes,
          metadata(feature, {
            customMetadata: {
              ...metadata(feature).customMetadata,
              communityId: "B",
            },
          }),
        ),
      );
    },
  );
  run(
    `${feature}: replace, metadata mutation, delete and namespace list denied`,
    async () => {
      const owner = feature === "apartment" ? "a" : "r";
      const target = object(feature, owner);
      await assertSucceeds(uploadBytes(target, bytes, metadata(feature)));
      await assertFails(uploadBytes(target, bytes, metadata(feature)));
      await assertFails(updateMetadata(target, { contentType: "image/png" }));
      await assertFails(deleteObject(target));
      await assertFails(deleteObject(object(feature, "other")));
      await assertFails(
        listAll(
          ref(context(owner).storage(bucketName), target.parent.fullPath),
        ),
      );
    },
  );
}

run(
  "oversized, empty, unsupported MIME, mismatched filename and public metadata denied",
  async () => {
    const target = object("profile", "r");
    await assertFails(
      uploadBytes(
        target,
        new Uint8Array(10 * 1024 * 1024 + 1),
        metadata("profile"),
      ),
    );
    await assertFails(
      uploadBytes(target, new Uint8Array(), metadata("profile")),
    );
    for (const contentType of [
      "image/svg+xml",
      "text/html",
      "application/pdf",
      "image/gif",
      "image/png",
    ]) {
      await assertFails(
        uploadBytes(target, bytes, metadata("profile", { contentType })),
      );
    }
    await assertFails(
      uploadBytes(
        target,
        bytes,
        metadata("profile", {
          customMetadata: {
            ...metadata("profile").customMetadata,
            imageUrl: "https://example.invalid/public.jpg",
          },
        }),
      ),
    );
    await assertFails(
      uploadBytes(
        target,
        bytes,
        metadata("profile", {
          customMetadata: {
            ...metadata("profile").customMetadata,
            resourceId: "other",
          },
        }),
      ),
    );
  },
);

run(
  "inactive, pending, unverified tenant, mismatched phone and inactive community denied",
  async () => {
    for (const uid of ["inactive", "pending", "tenant"]) {
      await assertFails(
        uploadBytes(
          ref(context(uid).storage(bucketName), path("profile", uid)),
          bytes,
          metadata("profile", {
            customMetadata: {
              ...metadata("profile").customMetadata,
              ownerId: uid,
              resourceId: uid,
            },
          }),
        ),
      );
    }
    const wrongPhone = env.authenticatedContext("r", {
      ...claims,
      phone_number: "+639170000001",
    });
    await assertFails(
      uploadBytes(
        ref(wrongPhone.storage(bucketName), path("profile")),
        bytes,
        metadata("profile"),
      ),
    );
    await db.doc("communities/A").update({ isActive: false });
    await assertFails(
      uploadBytes(object("profile", "r"), bytes, metadata("profile")),
    );
    await assertFails(
      uploadBytes(object("apartment", "a"), bytes, metadata("apartment")),
    );
  },
);

run("membership revocation immediately denies private read", async () => {
  await uploadBytes(object("profile", "r"), bytes, metadata("profile"));
  await db.doc("users/r").update({ communityId: "B" });
  await assertFails(getMetadata(object("profile", "r")));
});

run(
  "supported MIME extensions and the 10 MiB boundary are enforced per feature",
  async () => {
    const types = {
      "image/jpeg": "jpg",
      "image/png": "png",
      "image/webp": "webp",
      "image/gif": "gif",
    };
    for (const feature of features) {
      const owner = feature === "apartment" ? "a" : "r";
      for (const [contentType, extension] of Object.entries(types)) {
        const target = ref(
          context(owner).storage(bucketName),
          path(feature).replace(/\.jpg$/, `.${extension}`),
        );
        const operation = uploadBytes(
          target,
          bytes,
          metadata(feature, { contentType }),
        );
        if (
          contentType === "image/gif" &&
          !["profile", "community_wall"].includes(feature)
        ) {
          await assertFails(operation);
        } else {
          await assertSucceeds(operation);
        }
      }
    }
    const boundaryId = "b1111111-1111-4111-8111-111111111111";
    const boundary = ref(
      context("r").storage(bucketName),
      path("profile", "r", "A", boundaryId),
    );
    await assertSucceeds(
      uploadBytes(
        boundary,
        new Uint8Array(10 * 1024 * 1024),
        metadata("profile", {
          customMetadata: {
            ...metadata("profile").customMetadata,
            assetId: boundaryId,
          },
        }),
      ),
    );
  },
);

run("server reservations are unreadable and immutable to clients", async () => {
  await db
    .doc(`storageImageUploads/${id}`)
    .set({ ownerId: "r", state: "pending" });
  for (const uid of ["r", "a", null]) {
    const document = doc(context(uid).firestore(), "storageImageUploads", id);
    await assertFails(getDoc(document));
    await assertFails(setDoc(document, { ownerId: "r", state: "ready" }));
  }
});

run(
  "an unreserved upload cannot finalize or authorize another resident's resource",
  async () => {
    await uploadBytes(object("complaints", "r"), bytes, metadata("complaints"));
    const auth = { uid: "r", token: claims };
    await assert.rejects(
      complete({ db, bucket, auth, data: { assetId: id } }),
      (error) => error.code === "permission-denied",
    );
    await db
      .doc("complaints/other-resource")
      .set({ communityId: "A", userId: "other" });
    await assert.rejects(
      prepare({
        db,
        bucket,
        auth,
        data: {
          feature: "complaints",
          resourceId: "other-resource",
          contentType: "image/jpeg",
          size: 4,
        },
      }),
      (error) => error.code === "permission-denied",
    );
  },
);

run(
  "real emulator reserve/upload/finalize returns private reference and preserves legacy metadata",
  async () => {
    const auth = { uid: "r", token: claims };
    const context = { db, bucket, auth };
    const asset = await prepare({
      ...context,
      data: {
        feature: "complaints",
        resourceId: "target",
        contentType: "image/jpeg",
        size: bytes.length,
      },
    });
    const storage = env.authenticatedContext("r", claims).storage(bucketName);
    await assertSucceeds(
      uploadBytes(
        ref(storage, asset.storagePath),
        bytes,
        metadata("complaints", {
          customMetadata: {
            assetId: asset.assetId,
            ownerId: "r",
            communityId: "A",
            feature: "complaints",
            resourceId: "target",
          },
        }),
      ),
    );
    const stagingUrl = await getDownloadURL(ref(storage, asset.storagePath));
    const ready = await complete({
      ...context,
      data: { assetId: asset.assetId },
    });
    assert.equal(ready.state, "ready");
    assert.equal(ready.provider, "firebase");
    assert.ok(ready.generation);
    assert.match(ready.sha256, /^[a-f0-9]{64}$/);
    assert.equal(
      (await db.doc("complaints/target").get()).data().imageUrl,
      "https://example.invalid/legacy.jpg",
    );
    const [storedMetadata] = await bucket.file(ready.storagePath).getMetadata();
    assert.ok(
      !storedMetadata.metadata.firebaseStorageDownloadTokens,
      "ready assets have no persistent download token",
    );
    assert.ok(ready.storagePath.startsWith("private_images/A/r/complaints/"));
    await assertFails(getMetadata(ref(storage, ready.storagePath)));
    await assertFails(getDownloadURL(ref(storage, ready.storagePath)));
    await assertFails(
      uploadBytes(
        ref(storage, ready.storagePath),
        bytes,
        metadata("complaints"),
      ),
    );
    assert.equal((await bucket.file(asset.storagePath).exists())[0], false);
    assert.ok(
      [403, 404].includes((await fetch(stagingUrl)).status),
      "staging bearer URL no longer serves the file",
    );
    const result = await readImage({
      ...context,
      data: { assetId: ready.assetId },
    });
    assert.equal(result.base64, Buffer.from(bytes).toString("base64"));
    await assert.rejects(
      readImage({
        ...context,
        auth: { uid: "other", token: claims },
        data: { assetId: ready.assetId },
      }),
      (error) => error.code === "permission-denied",
    );
  },
);

const {
  saveApartmentImageCore: saveApartment,
  deleteApartmentImageCore: deleteApartment,
  collectApartmentAsset,
  cleanupApartmentImagesCore,
} = require("../src/apartment_images");
const { updateDoc, deleteDoc } = require("firebase/firestore");
function apartmentCall(data, uid = "a") {
  return { db, bucket, auth: { uid, token: claims }, data };
}
async function apartmentAsset() {
  const pending = await prepare(
    apartmentCall({
      feature: "apartment",
      resourceId: "target",
      contentType: "image/jpeg",
      size: bytes.length,
    }),
  );
  await uploadBytes(
    ref(context("a").storage(bucketName), pending.storagePath),
    bytes,
    {
      contentType: pending.contentType,
      customMetadata: {
        assetId: pending.assetId,
        communityId: pending.communityId,
        ownerId: pending.ownerId,
        feature: pending.feature,
        resourceId: pending.resourceId,
      },
    },
  );
  return complete(apartmentCall({ assetId: pending.assetId }));
}
const apartmentDetails = {
  title: "Courtyard",
  description: "Garden",
  type: "Common Area",
  uploadDate: "17-10-2026",
  uploadTime: "10:00",
};
run(
  "apartment end-to-end upload/attach/read/replace/delete with consistent server metadata",
  async () => {
    const old = await apartmentAsset();
    const saved = await saveApartment(
      apartmentCall({ assetId: old.assetId, ...apartmentDetails }),
    );
    const ref = db.doc(`apartmentImages/${saved.imageId}`);
    const before = (await ref.get()).data();
    assert.equal(before.imageUrl, "");
    assert.equal(before.imageAsset.assetId, old.assetId);
    const cached = await readImage(
      apartmentCall({ assetId: old.assetId, knownGeneration: old.generation }),
    );
    assert.equal(cached.notModified, true);
    assert.equal(cached.base64, undefined);
    const peer = { ...(await db.doc("admins/a").get()).data(), uid: "peer" };
    await db.doc("admins/peer").set(peer);
    assert.equal(
      (await readImage(apartmentCall({ assetId: old.assetId }, "peer"))).base64,
      Buffer.from(bytes).toString("base64"),
    );
    await assert.rejects(
      readImage(apartmentCall({ assetId: old.assetId }, "foreign-admin")),
      (e) => e.code === "permission-denied",
    );
    const next = await apartmentAsset();
    const replace = {
      assetId: next.assetId,
      imageId: saved.imageId,
      expectedRevision: 1,
    };
    await assert.rejects(
      saveApartment(apartmentCall({ ...replace, expectedRevision: 0 })),
      (e) => e.code === "aborted",
    );
    await saveApartment(apartmentCall(replace));
    assert.deepEqual(await saveApartment(apartmentCall(replace)), {
      imageId: saved.imageId,
      revision: 2,
    });
    const after = (await ref.get()).data();
    assert.ok(after.createdAt.isEqual(before.createdAt));
    for (const [key, value] of Object.entries(apartmentDetails))
      assert.equal(after[key], value);
    assert.equal((await bucket.file(old.storagePath).exists())[0], true);
    await collectApartmentAsset({ db, bucket, assetId: old.assetId });
    assert.equal((await bucket.file(old.storagePath).exists())[0], false);
    await deleteApartment(
      apartmentCall({ imageId: saved.imageId, expectedRevision: 2 }),
    );
    assert.equal((await ref.get()).exists, false);
    await deleteApartment(
      apartmentCall({ imageId: saved.imageId, expectedRevision: 2 }),
    );
    const cleanup = await cleanupApartmentImagesCore({ db, bucket });
    assert.equal(cleanup.failed, 0);
    assert.equal((await bucket.file(next.storagePath).exists())[0], false);
  },
);
run(
  "managed gallery references cannot be forged, overwritten or deleted via client Firestore",
  async () => {
    const asset = await apartmentAsset();
    await saveApartment(
      apartmentCall({ assetId: asset.assetId, ...apartmentDetails }),
    );
    const firestore = context("a").firestore();
    const image = doc(firestore, "apartmentImages", asset.assetId);
    await assertSucceeds(getDoc(image));
    await assertFails(
      updateDoc(image, { imageUrl: "https://example.invalid/forged.jpg" }),
    );
    await assertFails(updateDoc(image, { imageAsset: { assetId: "forged" } }));
    await assertFails(deleteDoc(image));
    await assertFails(
      setDoc(doc(firestore, "apartmentImages", "forged"), {
        communityId: "A",
        buildingId: "target",
        imageAsset: asset,
      }),
    );
    await assertFails(
      getDoc(
        doc(
          context("foreign-admin").firestore(),
          "apartmentImages",
          asset.assetId,
        ),
      ),
    );
    await assertFails(
      setDoc(doc(firestore, "storageImageMaintenance", "apartment"), {
        cursor: "forged",
      }),
    );
    await assertFails(
      setDoc(doc(firestore, "apartmentImageDeletes", asset.assetId), {
        communityId: "A",
      }),
    );
  },
);
run(
  "failed metadata attachment and expired abandoned reservation are collected without gallery references",
  async () => {
    const asset = await apartmentAsset();
    await assert.rejects(
      saveApartment(
        apartmentCall({
          assetId: asset.assetId,
          ...apartmentDetails,
          title: "",
        }),
      ),
      (e) => e.code === "invalid-argument",
    );
    assert.equal((await db.collection("apartmentImages").get()).empty, true);
    const result = await cleanupApartmentImagesCore({
      db,
      bucket,
      now: () => asset.expiresAtMs + 3600001,
    });
    assert.equal(result.deleted, 1);
    assert.equal(result.failed, 0);
    assert.equal((await bucket.file(asset.storagePath).exists())[0], false);
    assert.equal(
      (await db.doc(`storageImageUploads/${asset.assetId}`).get()).data().state,
      "deleted",
    );
  },
);
run(
  "legacy gallery deletion and replacement leave external URLs untouched; wrong-building replacement fails",
  async () => {
    const legacy = {
      ...apartmentDetails,
      buildingId: "target",
      communityId: "A",
      imageUrl: "https://example.invalid/legacy.jpg",
      customOrder: 4,
    };
    await db.doc("apartmentImages/legacy").set(legacy);
    await db.doc("buildings/another").set({ communityId: "A" });
    await db
      .doc("apartmentImages/wrong")
      .set({ ...legacy, buildingId: "another" });
    const asset = await apartmentAsset();
    await assert.rejects(
      saveApartment(
        apartmentCall({
          assetId: asset.assetId,
          imageId: "wrong",
          expectedRevision: 0,
        }),
      ),
      (e) => e.code === "permission-denied",
    );
    await saveApartment(
      apartmentCall({
        assetId: asset.assetId,
        imageId: "legacy",
        expectedRevision: 0,
      }),
    );
    const value = (await db.doc("apartmentImages/legacy").get()).data();
    assert.equal(value.imageUrl, legacy.imageUrl);
    assert.equal(value.customOrder, 4);
    await assert.rejects(
      deleteApartment(
        apartmentCall(
          { imageId: "legacy", expectedRevision: 1 },
          "foreign-admin",
        ),
      ),
      (e) => e.code === "permission-denied",
    );
    await deleteApartment(
      apartmentCall({ imageId: "wrong", expectedRevision: 0 }),
    );
    assert.equal((await db.doc("apartmentImages/wrong").get()).exists, false);
  },
);

run(
  "concurrent apartment replacements accept one revision; losing asset is collected safely",
  async () => {
    const old = await apartmentAsset();
    const saved = await saveApartment(
      apartmentCall({ assetId: old.assetId, ...apartmentDetails }),
    );
    const first = await apartmentAsset(),
      second = await apartmentAsset();
    const results = await Promise.allSettled(
      [first, second].map((asset) =>
        saveApartment(
          apartmentCall({
            assetId: asset.assetId,
            imageId: saved.imageId,
            expectedRevision: 1,
          }),
        ),
      ),
    );
    assert.equal(
      results.filter((result) => result.status === "fulfilled").length,
      1,
    );
    assert.equal(
      results.find((result) => result.status === "rejected").reason.code,
      "aborted",
    );
    const image = (
      await db.doc(`apartmentImages/${saved.imageId}`).get()
    ).data();
    const winner = image.imageAsset.assetId === first.assetId ? first : second;
    const loser = winner === first ? second : first;
    assert.equal(image.revision, 2);
    await collectApartmentAsset({
      db,
      bucket,
      assetId: loser.assetId,
      now: () => loser.expiresAtMs + 3600001,
    });
    assert.equal((await bucket.file(loser.storagePath).exists())[0], false);
    assert.equal((await bucket.file(winner.storagePath).exists())[0], true);
    assert.equal(
      await collectApartmentAsset({
        db,
        bucket,
        assetId: winner.assetId,
        now: () => winner.expiresAtMs + 3600001,
      }),
      false,
    );
  },
);

const {
  createResidentImageDraftCore: residentDraft,
  commitResidentImagesCore: residentCommit,
  cleanupResidentImagesCore,
  cleanupUnreservedResidentStaging,
} = require("../src/resident_images");
const residentCall = (data, uid = "r") => ({
  db,
  bucket,
  auth: { uid, token: claims },
  data,
});
async function residentAsset(feature, resourceId) {
  const pending = await prepare(
    residentCall({
      feature,
      resourceId,
      contentType: "image/jpeg",
      size: bytes.length,
    }),
  );
  await uploadBytes(
    ref(context("r").storage(bucketName), pending.storagePath),
    bytes,
    {
      contentType: pending.contentType,
      customMetadata: {
        assetId: pending.assetId,
        ownerId: pending.ownerId,
        communityId: pending.communityId,
        feature: pending.feature,
        resourceId: pending.resourceId,
      },
    },
  );
  return complete(residentCall({ assetId: pending.assetId }));
}
run(
  "Resident apartment reader enforces exact building, active membership and community",
  async () => {
    await db.doc("users/r").update({ buildingId: "target" });
    const asset = await apartmentAsset();
    await saveApartment(
      apartmentCall({ assetId: asset.assetId, ...apartmentDetails }),
    );
    assert.equal(
      (await readImage(residentCall({ assetId: asset.assetId }))).size,
      bytes.length,
    );
    await db.doc("users/r").update({ buildingId: "another" });
    await assert.rejects(
      readImage(residentCall({ assetId: asset.assetId })),
      (e) => e.code === "permission-denied",
    );
    await db.doc("users/r").update({ buildingId: "target", isActive: false });
    await assert.rejects(
      readImage(residentCall({ assetId: asset.assetId })),
      (e) => e.code === "permission-denied",
    );
    await assert.rejects(
      readImage(residentCall({ assetId: asset.assetId }, "foreign")),
      (e) => e.code === "permission-denied",
    );
  },
);
run(
  "Resident profile/complaint upload attach/read/replace/delete with no public tokens",
  async () => {
    for (const feature of ["profile", "complaints"]) {
      const resourceId = feature === "profile" ? "r" : "target";
      const first = await residentAsset(feature, resourceId);
      const input = {
        feature,
        resourceId,
        operationId: `save-${feature}`,
        expectedRevision: 0,
        references: [`hominode-image:${first.assetId}`],
      };
      await residentCommit(residentCall(input));
      await residentCommit(residentCall(input));
      const result = await readImage(residentCall({ assetId: first.assetId }));
      assert.equal(result.asset.assetId, first.assetId);
      assert.equal(result.base64, Buffer.from(bytes).toString("base64"));
      assert.equal(
        (await bucket.file(first.storagePath).getMetadata())[0].metadata
          .firebaseStorageDownloadTokens,
        undefined,
      );
      if (feature === "complaints")
        await assert.rejects(
          readImage(residentCall({ assetId: first.assetId }, "other")),
          (e) => e.code === "permission-denied",
        );
      await assert.rejects(
        readImage(residentCall({ assetId: first.assetId }, "foreign")),
        (e) => e.code === "permission-denied",
      );
      const next = await residentAsset(feature, resourceId);
      await residentCommit(
        residentCall({
          ...input,
          operationId: `replace-${feature}`,
          expectedRevision: 1,
          references: [`hominode-image:${next.assetId}`],
        }),
      );
      await cleanupResidentImagesCore({ db, bucket });
      assert.equal((await bucket.file(first.storagePath).exists())[0], false);
      await residentCommit(
        residentCall({
          ...input,
          operationId: `remove-${feature}`,
          expectedRevision: 2,
          references: [],
        }),
      );
      await cleanupResidentImagesCore({ db, bucket });
      assert.equal((await bucket.file(next.storagePath).exists())[0], false);
    }
  },
);
run(
  "owned Wall/Marketplace drafts publish atomically, retain order and reject unauthorized references",
  async () => {
    await db.doc("users/r").update({ buildingId: "target" });
    await db.doc("users/other").update({ buildingId: "target" });
    const { Timestamp } = require("firebase-admin/firestore");
    await db.doc("subscriptions/A").set({
      planId: "plus",
      status: "active",
      startsAt: Timestamp.fromMillis(0),
    });
    for (const feature of ["community_wall", "marketplace"]) {
      const ticket = await residentDraft(residentCall({ feature }));
      await assert.rejects(
        prepare(
          residentCall(
            {
              feature,
              resourceId: ticket.resourceId,
              contentType: "image/jpeg",
              size: 4,
            },
            "other",
          ),
        ),
        (e) => e.code === "permission-denied",
      );
      const first = await residentAsset(feature, ticket.resourceId),
        second = await residentAsset(feature, ticket.resourceId);
      const content =
        feature === "community_wall"
          ? { content: "Community garden" }
          : {
              title: "Chair",
              price: 100,
              category: "Furniture",
              condition: "Like New",
              description: "Garden chair",
            };
      const input = {
        feature,
        resourceId: ticket.resourceId,
        operationId: `publish-${feature}`,
        expectedRevision: 0,
        references: [second, first].map((a) => `hominode-image:${a.assetId}`),
        content,
      };
      await residentCommit(residentCall(input));
      const collection =
        feature === "community_wall" ? "posts" : "marketplaces";
      const record = (
        await db.doc(`${collection}/${ticket.resourceId}`).get()
      ).data();
      assert.deepEqual(
        record.managedImageAssets.map((a) => a.assetId),
        [second.assetId, first.assetId],
      );
      assert.equal(record.communityId, "A");
      assert.equal(
        (await readImage(residentCall({ assetId: first.assetId }, "other")))
          .size,
        bytes.length,
      );
      const forged = { ...input, operationId: "forged", expectedRevision: 1 };
      await assert.rejects(
        residentCommit(residentCall(forged, "other")),
        (e) => e.code === "permission-denied",
      );
      await assertFails(
        updateDoc(
          doc(context("r").firestore(), collection, ticket.resourceId),
          { managedImageAssets: [] },
        ),
      );
      await assertFails(
        updateDoc(
          doc(context("r").firestore(), collection, ticket.resourceId),
          { [feature === "marketplace" ? "images" : "imageUrls"]: [] },
        ),
      );
      await assertFails(
        deleteDoc(doc(context("r").firestore(), collection, ticket.resourceId)),
      );
      await residentCommit(
        residentCall({
          ...input,
          operationId: `delete-${feature}`,
          expectedRevision: 1,
          references: [],
          deleteResource: true,
          content: undefined,
        }),
      );
      await cleanupResidentImagesCore({ db, bucket });
      assert.equal((await bucket.file(first.storagePath).exists())[0], false);
    }
  },
);
run(
  "managed fields, another owner asset and forged private references cannot be written through client rules",
  async () => {
    const first = await residentAsset("profile", "r");
    await residentCommit(
      residentCall({
        feature: "profile",
        resourceId: "r",
        operationId: "save",
        expectedRevision: 0,
        references: [`hominode-image:${first.assetId}`],
      }),
    );
    const user = doc(context("r").firestore(), "users", "r");
    await assertFails(updateDoc(user, { managedImageAssets: [] }));
    await assertFails(
      updateDoc(user, { profileImage: "https://example.invalid/forged.jpg" }),
    );
    await assertSucceeds(updateDoc(user, { name: "Updated resident name" }));
    await assertFails(
      setDoc(doc(context("r").firestore(), "posts", "forged"), {
        authorId: "r",
        communityId: "A",
        buildingId: "target",
        imageUrl: `hominode-image:${first.assetId}`,
      }),
    );
    for (const collection of [
      "residentImageDrafts",
      "residentImageCommits",
      "storageImageQuotas",
    ])
      await assertFails(
        setDoc(doc(context("r").firestore(), collection, "forged"), {
          ownerId: "r",
        }),
      );
  },
);
run(
  "legacy attachment lists retain all entries while private references at any index are denied",
  async () => {
    const legacy = Array.from(
      { length: 8 },
      (_, index) => `https://example.invalid/document-${index}.pdf`,
    );
    const complaint = doc(context("a").firestore(), "complaints", "target");
    await assertSucceeds(updateDoc(complaint, { attachments: legacy }));
    assert.deepEqual(
      (await db.doc("complaints/target").get()).data().attachments,
      legacy,
    );
    for (const injected of [`hominode-image:${id}`, `hominode-image:${id}\n`]) {
      await assertFails(
        updateDoc(complaint, { attachments: [...legacy, injected] }),
      );
    }
  },
);
run(
  "expired drafts, abandoned final assets and unreserved staging files are reclaimed safely",
  async () => {
    await db.doc("users/r").update({ buildingId: "target" });
    const { Timestamp } = require("firebase-admin/firestore");
    await db.doc("subscriptions/A").set({
      planId: "plus",
      status: "active",
      startsAt: Timestamp.fromMillis(0),
    });
    const ticket = await residentDraft(
      residentCall({ feature: "community_wall" }),
    );
    await db
      .doc(`residentImageDrafts/${ticket.resourceId}`)
      .update({ expiresAtMs: 0 });
    await assert.rejects(
      prepare(
        residentCall({
          feature: "community_wall",
          resourceId: ticket.resourceId,
          contentType: "image/jpeg",
          size: 4,
        }),
      ),
      (e) => e.code === "permission-denied",
    );
    const asset = await residentAsset("profile", "r");
    await cleanupResidentImagesCore({
      db,
      bucket,
      now: () => asset.expiresAtMs + 3600001,
    });
    assert.equal((await bucket.file(asset.storagePath).exists())[0], false);
    const unreserved = object("profile", "r");
    await uploadBytes(unreserved, bytes, metadata("profile"));
    const before = await cleanupUnreservedResidentStaging({ db, bucket });
    assert.equal(before.deleted, 0);
    const after = await cleanupUnreservedResidentStaging({
      db,
      bucket,
      now: () => Date.now() + 25 * 3600000,
    });
    assert.equal(after.deleted, 1);
    assert.equal(after.failed, 0);
  },
);

run(
  "late staging replicas cannot republish an attached asset and expire without deleting the private file",
  async () => {
    const asset = await residentAsset("profile", "r");
    await residentCommit(
      residentCall({
        feature: "profile",
        resourceId: "r",
        operationId: "attach",
        expectedRevision: 0,
        references: [`hominode-image:${asset.assetId}`],
      }),
    );
    const staging = `resident_images/A/r/profile/${asset.assetId}.jpg`;
    await uploadBytes(ref(context("r").storage(bucketName), staging), bytes, {
      contentType: "image/jpeg",
      customMetadata: {
        assetId: asset.assetId,
        ownerId: "r",
        communityId: "A",
        feature: "profile",
        resourceId: "r",
      },
    });
    const cleanup = await cleanupUnreservedResidentStaging({
      db,
      bucket,
      now: () => Date.now() + 25 * 3600000,
    });
    assert.equal(cleanup.deleted, 1);
    assert.equal(cleanup.failed, 0);
    assert.equal((await bucket.file(staging).exists())[0], false);
    assert.equal((await bucket.file(asset.storagePath).exists())[0], true);
    assert.equal(
      (await readImage(residentCall({ assetId: asset.assetId }))).size,
      bytes.length,
    );
  },
);

run(
  "Essential Wall private publication permits current members and denies premium/foreign/revoked reads",
  async () => {
    await db.doc("users/r").update({ buildingId: "target" });
    await db
      .doc("subscriptions/A")
      .set({ planId: "essential", status: "active" });
    const ticket = await residentDraft(
      residentCall({ feature: "community_wall" }),
    );
    const image = await residentAsset("community_wall", ticket.resourceId);
    await residentCommit(
      residentCall({
        feature: "community_wall",
        resourceId: ticket.resourceId,
        expectedRevision: 0,
        operationId: "essential-wall",
        references: [`hominode-image:${image.assetId}`],
        content: { content: "Community garden" },
      }),
    );
    assert.equal(
      (await readImage(residentCall({ assetId: image.assetId }, "other"))).size,
      bytes.length,
    );
    await assert.rejects(
      residentDraft(residentCall({ feature: "marketplace" })),
      (e) => e.code === "permission-denied",
    );
    await assert.rejects(
      readImage(residentCall({ assetId: image.assetId }, "foreign")),
      (e) => e.code === "permission-denied",
    );
    await db.doc("subscriptions/A").update({ status: "suspended" });
    await assert.rejects(
      readImage(residentCall({ assetId: image.assetId }, "other")),
      (e) => e.code === "permission-denied",
    );
  },
);
