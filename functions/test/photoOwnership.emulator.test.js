const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const { randomUUID } = require("node:crypto");
const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require("@firebase/rules-unit-testing");
const { initializeApp, deleteApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { getStorage } = require("firebase-admin/storage");
const {
  doc,
  getDoc,
  setDoc,
  updateDoc,
  deleteDoc,
  collection,
  query,
  where,
  getDocs,
} = require("firebase/firestore");
const {
  ref,
  uploadBytes,
  getMetadata,
  deleteObject,
} = require("firebase/storage");
const { storageRulesDirectory } = require("./helpers/storage_rules_variant");
const { jpeg, auth, phone } = require("./helpers/storage_images_fixture");
const {
  prepareStorageImageUploadCore: prepare,
  completeStorageImageUploadCore: complete,
  readStorageImageCore: read,
} = require("../src/storage_images");
const {
  saveApartmentImageCore: save,
  deleteApartmentImageCore: remove,
} = require("../src/apartment_images");
const enabled =
  !!process.env.FIRESTORE_EMULATOR_HOST &&
  !!process.env.FIREBASE_STORAGE_EMULATOR_HOST;
const projectId = "demo-hominode-storage-images",
  bucketName = projectId + ".appspot.com";
let env, app, db, bucket;
const run = (name, fn) => test(name, { skip: !enabled }, fn);
const ctx = (uid) =>
  uid
    ? env.authenticatedContext(uid, auth(uid).token)
    : env.unauthenticatedContext();
const invoke = (data, uid = "a") => ({
  db,
  bucket,
  auth: uid ? auth(uid) : null,
  data,
});
const details = {
  title: "Courtyard",
  description: "",
  type: "Common Area",
  uploadDate: "2026-10-21",
  uploadTime: "10:00",
};
const resources = { COMMUNITY: "A", BUILDING: "b", UNIT: "canonical-unit" };
async function image(scope) {
  const asset = await prepare(
    invoke({
      feature: "apartment",
      contractVersion: 2,
      ownershipScope: scope,
      resourceId: resources[scope],
      contentType: "image/jpeg",
      size: jpeg.length,
    }),
  );
  await uploadBytes(
    ref(ctx("a").storage(bucketName), asset.storagePath),
    new Uint8Array(jpeg),
    {
      contentType: "image/jpeg",
      cacheControl: "private, no-store",
      customMetadata: {
        assetId: asset.assetId,
        ownerId: "a",
        communityId: "A",
        feature: "apartment",
        resourceId: asset.resourceId,
      },
    },
  );
  const ready = await complete(invoke({ assetId: asset.assetId }));
  await save(invoke({ assetId: asset.assetId, ...details }));
  return ready;
}
test.before(async () => {
  if (!enabled) return;
  for (const address of [
    process.env.FIRESTORE_EMULATOR_HOST,
    process.env.FIREBASE_STORAGE_EMULATOR_HOST,
  ])
    assert.match(
      address,
      /^(?:127\.0\.0\.1|localhost):\d+$/,
      "Synthetic localhost tests only",
    );
  const [host, port] = process.env.FIRESTORE_EMULATOR_HOST.split(":"),
    [sh, sp] = process.env.FIREBASE_STORAGE_EMULATOR_HOST.split(":");
  const directory = storageRulesDirectory();
  env = await initializeTestEnvironment({
    projectId,
    firestore: {
      host,
      port: Number(port),
      rules: fs.readFileSync(directory + "/firestore.rules", "utf8"),
    },
    storage: {
      host: sh,
      port: Number(sp),
      rules: fs.readFileSync(directory + "/storage.rules", "utf8"),
    },
  });
  app = initializeApp(
    { projectId, storageBucket: bucketName },
    "photo-ownership-v2",
  );
  db = getFirestore(app);
  bucket = getStorage(app).bucket();
});
test.beforeEach(async () => {
  if (!enabled) return;
  await env.clearFirestore();
  const resident = {
    role: "resident",
    phoneNumber: phone,
    isActive: true,
    approvalStatus: "approved",
    status: "active",
    residentType: "owner",
    communityId: "A",
    buildingId: "b",
    flatId: "canonical-unit",
  };
  const entries = {
    "communities/A": { isActive: true },
    "communities/B": { isActive: true },
    "admins/a": {
      uid: "a",
      role: "admin",
      phoneNumber: phone,
      isActive: true,
      authorizedCommunityIds: ["A"],
    },
    "admins/foreign": {
      uid: "foreign",
      role: "admin",
      phoneNumber: phone,
      isActive: true,
      authorizedCommunityIds: ["B"],
    },
    "users/r": { ...resident, uid: "r" },
    "users/peer": { ...resident, uid: "peer", flatId: "other-unit" },
    "users/other-building": {
      ...resident,
      uid: "other-building",
      buildingId: "b2",
      flatId: "other",
    },
    "users/foreign": { ...resident, uid: "foreign", communityId: "B" },
    "buildings/b": { communityId: "A" },
    "buildings/b2": { communityId: "A" },
    "flats/canonical-unit": {
      communityId: "A",
      buildingId: "b",
      flatId: "101",
      status: "occupied",
      residentUserId: "r",
    },
    "flats/other-unit": {
      communityId: "A",
      buildingId: "b",
      status: "occupied",
      residentUserId: "peer",
    },
    "apartmentImages/legacy": {
      communityId: "A",
      buildingId: "b",
      status: "active",
      type: "Common Area",
      imageUrl: "https://example.invalid/not-fetched.jpg",
    },
  };
  for (const [path, data] of Object.entries(entries))
    await db.doc(path).set(data);
});
test.after(async () => {
  if (env) {
    await env.withSecurityRulesDisabled(async (c) => {
      async function clear(reference) {
        const { items, prefixes } = await reference.listAll();
        for (const item of items) await item.delete();
        for (const prefix of prefixes) await clear(prefix);
      }
      await clear(c.storage(bucketName).ref());
    });
    await env.cleanup();
  }
  if (app) await deleteApp(app);
});
for (const scope of Object.keys(resources))
  run(
    `${scope}: real staging/finalization, protected references and scoped private reads`,
    async () => {
      const asset = await image(scope);
      const path = "apartmentImagesV2/" + asset.assetId;
      await assertSucceeds(getDoc(doc(ctx("r").firestore(), path)));
      await assertSucceeds(getDoc(doc(ctx("a").firestore(), path)));
      assert.equal(
        (await read(invoke({ assetId: asset.assetId }, "r"))).size,
        jpeg.length,
      );
      await assertFails(getDoc(doc(ctx("foreign").firestore(), path)));
      await assertFails(getDoc(doc(ctx(null).firestore(), path)));
      await assertFails(getDoc(doc(ctx("foreign").firestore(), path)));
      for (const uid of ["peer", "other-building"]) {
        const allowed =
          scope === "COMMUNITY" || (scope === "BUILDING" && uid === "peer");
        if (allowed)
          await assertSucceeds(getDoc(doc(ctx(uid).firestore(), path)));
        else {
          await assertFails(getDoc(doc(ctx(uid).firestore(), path)));
          await assert.rejects(read(invoke({ assetId: asset.assetId }, uid)));
        }
      }
      await assertFails(
        updateDoc(doc(ctx("a").firestore(), path), {
          ownershipScope: "COMMUNITY",
        }),
      );
      await assertFails(deleteDoc(doc(ctx("a").firestore(), path)));
      await assertFails(
        getMetadata(ref(ctx("a").storage(bucketName), asset.storagePath)),
      );
      await assertFails(
        getMetadata(ref(ctx("r").storage(bucketName), asset.storagePath)),
      );
      await assertFails(
        deleteObject(ref(ctx("a").storage(bucketName), asset.storagePath)),
      );
      await assert.rejects(
        remove(
          invoke({
            imageId: asset.assetId,
            contractVersion: 2,
            expectedRevision: 0,
          }),
        ),
        (e) => e.code === "aborted",
      );
      await remove(
        invoke({
          imageId: asset.assetId,
          contractVersion: 2,
          expectedRevision: 1,
        }),
      );
      await assert.rejects(read(invoke({ assetId: asset.assetId }, "r")));
    },
  );
run(
  "community-only upload has no building dependency and legacy query remains valid",
  async () => {
    await db.doc("buildings/b").delete();
    await db.doc("buildings/b2").delete();
    await image("COMMUNITY");
    const result = await assertSucceeds(
      getDocs(
        query(
          collection(ctx("r").firestore(), "apartmentImages"),
          where("communityId", "==", "A"),
          where("status", "==", "active"),
        ),
      ),
    );
    assert.equal(result.size, 1);
    assert.equal(result.docs[0].id, "legacy");
  },
);
run(
  "mixed V2 scopes never contaminate old queries; scoped queries enforce recipient assignment",
  async () => {
    for (const scope of Object.keys(resources)) await image(scope);
    const legacy = await assertSucceeds(
      getDocs(
        query(
          collection(ctx("r").firestore(), "apartmentImages"),
          where("communityId", "==", "A"),
          where("status", "==", "active"),
        ),
      ),
    );
    assert.equal(legacy.size, 1);
    const scoped = (uid, scope, extra = []) =>
      getDocs(
        query(
          collection(ctx(uid).firestore(), "apartmentImagesV2"),
          where("communityId", "==", "A"),
          where("status", "==", "active"),
          where("contractVersion", "==", 2),
          where("ownershipScope", "==", scope),
          where("resourceId", "==", resources[scope]),
          ...extra,
        ),
      );
    assert.equal((await assertSucceeds(scoped("r", "COMMUNITY"))).size, 1);
    assert.equal(
      (
        await assertSucceeds(
          scoped("r", "BUILDING", [where("buildingId", "==", "b")]),
        )
      ).size,
      1,
    );
    assert.equal(
      (
        await assertSucceeds(
          scoped("r", "UNIT", [
            where("buildingId", "==", "b"),
            where("unitId", "==", "canonical-unit"),
          ]),
        )
      ).size,
      1,
    );
    await assertFails(
      scoped("peer", "UNIT", [
        where("buildingId", "==", "b"),
        where("unitId", "==", "canonical-unit"),
      ]),
    );
    await assertFails(
      scoped("other-building", "BUILDING", [where("buildingId", "==", "b")]),
    );
  },
);
run(
  "canonical UNIT assignment changes and conflicting occupancy deny metadata and cached reads",
  async () => {
    const asset = await image("UNIT");
    await db.doc("flats/canonical-unit").update({ residentUid: "peer" });
    await assertFails(
      getDoc(doc(ctx("r").firestore(), "apartmentImagesV2/" + asset.assetId)),
    );
    await assert.rejects(
      read(
        invoke(
          { assetId: asset.assetId, knownGeneration: asset.generation },
          "r",
        ),
      ),
    );
  },
);
run(
  "client-forged scopes and foreign/unauthenticated reservations are rejected",
  async () => {
    const data = {
      feature: "apartment",
      contractVersion: 2,
      ownershipScope: "COMMUNITY",
      resourceId: "A",
      contentType: "image/jpeg",
      size: jpeg.length,
    };
    for (const uid of [null, "r", "foreign"])
      await assert.rejects(prepare(invoke(data, uid)));
    await assert.rejects(prepare(invoke({ ...data, resourceId: "missing" })));
    await assertFails(
      setDoc(doc(ctx("a").firestore(), "apartmentImagesV2/" + randomUUID()), {
        contractVersion: 2,
        ownershipScope: "COMMUNITY",
        communityId: "A",
        resourceId: "A",
        status: "active",
      }),
    );
  },
);
