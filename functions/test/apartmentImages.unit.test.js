const test = require("node:test");
const assert = require("node:assert/strict");
const {
  setup,
  auth,
  nowMs,
  jpeg,
} = require("./helpers/storage_images_fixture");
const { readStorageImageCore: read } = require("../src/storage_images");
const {
  saveApartmentImageCore: save,
  deleteApartmentImageCore: remove,
  collectApartmentAsset: collect,
} = require("../src/apartment_images");
const details = {
  title: "Courtyard",
  description: "Garden",
  type: "Common Area",
  uploadDate: "17-10-2026",
  uploadTime: "10:00",
};
const deny = (promise, code = "permission-denied") =>
  assert.rejects(promise, (e) => e.code === code);
async function ready(s) {
  const pending = await s.reserve("apartment");
  s.upload(pending);
  return s.finish(pending);
}
const invoke = (s, data, uid = "a") => ({
  ...s.context,
  auth: auth(uid),
  data,
});
const attach = (s, asset) =>
  save(invoke(s, { assetId: asset.assetId, ...details }));
function gallery(s, id) {
  return s.db.values.get(`apartmentImages/${id}`);
}

test("upload, atomic attachment and private display; lost save response retries exactly once", async () => {
  const s = setup(),
    asset = await ready(s);
  const result = await attach(s, asset);
  assert.equal(result.imageId, asset.assetId);
  const image = gallery(s, result.imageId);
  assert.equal(image.communityId, "A");
  assert.equal(image.buildingId, "b");
  assert.equal(image.imageUrl, "");
  assert.deepEqual(image.imageAsset, asset);
  for (const [key, value] of Object.entries(details))
    assert.equal(image[key], value);
  assert.deepEqual(await attach(s, asset), result);
  assert.equal(
    [...s.db.values.keys()].filter((p) => p.startsWith("apartmentImages/"))
      .length,
    1,
  );
  assert.equal(
    (await read(invoke(s, { assetId: asset.assetId }))).base64,
    jpeg.toString("base64"),
  );
});

test("assigned peer admin can display and replace; anonymous and foreign admin cannot", async () => {
  const s = setup(),
    asset = await ready(s);
  await attach(s, asset);
  const admin = s.db.values.get("admins/a");
  s.db.values.set("admins/peer", { ...admin, uid: "peer" });
  s.db.values.set("admins/foreign", {
    ...admin,
    uid: "foreign",
    authorizedCommunityIds: ["B"],
  });
  assert.equal(
    (await read(invoke(s, { assetId: asset.assetId }, "peer"))).size,
    jpeg.length,
  );
  await deny(
    remove(invoke(s, { imageId: asset.assetId, expectedRevision: 1 }, "r")),
  );
  for (const uid of ["foreign", "missing"]) {
    const before = s.reads();
    await deny(read(invoke(s, { assetId: asset.assetId }, uid)));
    assert.equal(s.reads(), before);
    await deny(
      remove(invoke(s, { imageId: asset.assetId, expectedRevision: 1 }, uid)),
    );
  }
  await deny(
    read({ ...invoke(s, { assetId: asset.assetId }), auth: null }),
    "unauthenticated",
  );
});

test("only an owned ready asset in the current building/community can attach", async () => {
  const s = setup(),
    pending = await s.reserve("apartment");
  await deny(attach(s, pending), "failed-precondition");
  s.upload(pending);
  const asset = await s.finish(pending);
  await deny(save(invoke(s, { assetId: asset.assetId, ...details }, "r")));
  s.db.values.get("buildings/b").communityId = "B";
  s.db.values.get("admins/a").authorizedCommunityIds = ["A", "B"];
  await deny(attach(s, asset));
  assert.equal(gallery(s, asset.assetId), undefined);
});

test("replacement preserves metadata, order and old bytes until commit; stale writes fail", async () => {
  const s = setup(),
    old = await ready(s);
  const first = await attach(s, old);
  const before = gallery(s, first.imageId);
  const replacement = await ready(s);
  assert.ok(s.files.has(old.storagePath));
  const args = {
    assetId: replacement.assetId,
    imageId: first.imageId,
    expectedRevision: 1,
  };
  await deny(save(invoke(s, { ...args, expectedRevision: 0 })), "aborted");
  assert.equal(gallery(s, first.imageId).imageAsset.assetId, old.assetId);
  await save(invoke(s, args));
  const after = gallery(s, first.imageId);
  for (const key of [
    "title",
    "description",
    "type",
    "uploadDate",
    "uploadTime",
    "adminId",
    "adminName",
    "buildingId",
    "communityId",
    "status",
  ])
    assert.deepEqual(after[key], before[key]);
  assert.deepEqual(after.createdAt, before.createdAt);
  assert.equal(after.revision, 2);
  assert.ok(s.files.has(old.storagePath));
  assert.equal(await collect({ ...s.context, assetId: old.assetId }), true);
  assert.equal(s.files.has(old.storagePath), false);
  assert.ok(s.files.has(replacement.storagePath));
  await deny(read(invoke(s, { assetId: old.assetId })), "failed-precondition");
  assert.deepEqual(await save(invoke(s, args)), {
    imageId: first.imageId,
    revision: 2,
  });
});

test("delete removes metadata before cleanup, retries safely and never follows legacy URLs", async () => {
  const s = setup(),
    asset = await ready(s);
  await attach(s, asset);
  const args = { imageId: asset.assetId, expectedRevision: 1 };
  await deny(remove(invoke(s, { ...args, expectedRevision: 0 })), "aborted");
  await remove(invoke(s, args));
  assert.equal(gallery(s, asset.assetId), undefined);
  assert.ok(s.files.has(asset.storagePath));
  assert.deepEqual(await remove(invoke(s, args)), {
    imageId: asset.assetId,
    deleted: true,
  });
  await collect({ ...s.context, assetId: asset.assetId });
  assert.equal(s.files.size, 0);
  s.db.values.set("apartmentImages/legacy", {
    ...details,
    buildingId: "b",
    communityId: "A",
    imageUrl: "https://example.invalid/legacy.jpg",
  });
  const reads = s.reads();
  await remove(invoke(s, { imageId: "legacy", expectedRevision: 0 }));
  assert.equal(s.reads(), reads);
});

test("legacy replacement retains original URL and timestamps but private asset wins", async () => {
  const s = setup();
  const original = {
    ...details,
    buildingId: "b",
    communityId: "A",
    imageUrl: "https://example.invalid/old.jpg",
    createdAt: "original",
    customOrder: 7,
  };
  s.db.values.set("apartmentImages/legacy", original);
  const asset = await ready(s);
  await save(
    invoke(s, {
      assetId: asset.assetId,
      imageId: "legacy",
      expectedRevision: 0,
    }),
  );
  const value = gallery(s, "legacy");
  for (const [key, field] of Object.entries(original))
    assert.equal(value[key], field);
  assert.equal(value.imageAsset.assetId, asset.assetId);
});

test("wrong resource replacement and client path/role inputs cannot alter gallery", async () => {
  const s = setup(),
    asset = await ready(s);
  await attach(s, asset);
  s.db.values.set("buildings/second", { communityId: "A" });
  s.db.values.set("apartmentImages/second", {
    buildingId: "second",
    communityId: "A",
  });
  const next = await ready(s);
  await deny(
    save(
      invoke(s, {
        assetId: next.assetId,
        imageId: "second",
        expectedRevision: 0,
      }),
    ),
  );
  for (const key of [
    "communityId",
    "ownerId",
    "storagePath",
    "imageUrl",
    "role",
  ])
    await deny(
      save(invoke(s, { assetId: next.assetId, ...details, [key]: "forged" })),
      "invalid-argument",
    );
});

test("failed attachment leaves no broken gallery reference; expiry collects private orphan", async () => {
  const s = setup(),
    asset = await ready(s);
  await deny(
    save(invoke(s, { assetId: asset.assetId, ...details, title: "" })),
    "invalid-argument",
  );
  assert.equal(gallery(s, asset.assetId), undefined);
  assert.equal(await collect({ ...s.context, assetId: asset.assetId }), false);
  assert.equal(
    await collect({
      ...s.context,
      assetId: asset.assetId,
      now: () => asset.expiresAtMs + 3600001,
    }),
    true,
  );
  assert.equal(s.files.size, 0);
});

test("cleanup retries storage failure and refuses attached assets or forged paths", async () => {
  const s = setup(),
    asset = await ready(s);
  await attach(s, asset);
  assert.equal(
    await collect({
      ...s.context,
      assetId: asset.assetId,
      now: () => nowMs + 999999999,
    }),
    false,
  );
  await remove(invoke(s, { imageId: asset.assetId, expectedRevision: 1 }));
  const original = s.bucket.file.bind(s.bucket);
  let block = true;
  s.bucket.file = (...args) => {
    const file = original(...args);
    return {
      ...file,
      delete: async (...a) => {
        if (block) throw new Error("transient");
        return file.delete(...a);
      },
    };
  };
  await assert.rejects(collect({ ...s.context, assetId: asset.assetId }));
  assert.equal(
    s.db.values.get(`storageImageUploads/${asset.assetId}`).state,
    "deleting",
  );
  block = false;
  await collect({ ...s.context, assetId: asset.assetId });
  assert.equal(s.files.size, 0);
  const second = await ready(s);
  s.db.values.get(`storageImageUploads/${second.assetId}`).storagePath =
    "payment_receipts/private";
  await deny(
    collect({
      ...s.context,
      assetId: second.assetId,
      now: () => nowMs + 999999999,
    }),
    "failed-precondition",
  );
});

test("pending orphan, including a private copy created before journal failure, is recoverable", async () => {
  const s = setup(),
    pending = await s.reserve("apartment");
  s.upload(pending);
  const original = s.bucket.file.bind(s.bucket);
  s.bucket.file = (...args) => {
    const file = original(...args);
    return {
      ...file,
      save: async (...a) => {
        await file.save(...a);
        s.db.values.get("admins/a").isActive = false;
      },
    };
  };
  await deny(s.finish(pending));
  assert.equal(s.files.size, 2);
  await collect({
    ...s.context,
    assetId: pending.assetId,
    now: () => pending.expiresAtMs + 3600001,
  });
  assert.equal(s.files.size, 0);
});

test("read revocation after byte download denies delivery", async () => {
  const s = setup(),
    asset = await ready(s);
  await attach(s, asset);
  const original = s.bucket.file.bind(s.bucket);
  s.bucket.file = (...args) => {
    const file = original(...args);
    return {
      ...file,
      download: async (...a) => {
        const value = await file.download(...a);
        s.db.values.get("admins/a").isActive = false;
        return value;
      },
    };
  };
  await deny(read(invoke(s, { assetId: asset.assetId })));
});

test("assigned peer replacement uses its own upload while preserving the original record metadata", async () => {
  const s = setup(),
    original = await ready(s);
  await attach(s, original);
  s.db.values.set("admins/peer", {
    ...s.db.values.get("admins/a"),
    uid: "peer",
  });
  const pending = await s.reserve("apartment", { auth: auth("peer") });
  s.upload(pending);
  const next = await s.finish(pending);
  await save(
    invoke(
      s,
      { assetId: next.assetId, imageId: original.assetId, expectedRevision: 1 },
      "peer",
    ),
  );
  const image = gallery(s, original.assetId);
  assert.equal(image.adminId, "a");
  assert.equal(image.imageAsset.ownerId, "peer");
  assert.equal(
    (await read(invoke(s, { assetId: next.assetId }))).size,
    jpeg.length,
  );
});

test("transient Firestore failure preserves old asset and retry commits once", async () => {
  const s = setup(),
    original = await ready(s);
  await attach(s, original);
  const next = await ready(s),
    transaction = s.db.runTransaction;
  const args = invoke(s, {
    assetId: next.assetId,
    imageId: original.assetId,
    expectedRevision: 1,
  });
  s.db.runTransaction = async () => {
    throw new Error("Synthetic Firestore outage");
  };
  await assert.rejects(save(args));
  assert.equal(
    gallery(s, original.assetId).imageAsset.assetId,
    original.assetId,
  );
  assert.ok(s.files.has(original.storagePath));
  s.db.runTransaction = transaction;
  await save(args);
  await save(args);
  assert.equal(gallery(s, original.assetId).revision, 2);
});

test("cleanup refuses a changed private generation instead of deleting a different object", async () => {
  const s = setup(),
    asset = await ready(s);
  await attach(s, asset);
  await remove(invoke(s, { imageId: asset.assetId, expectedRevision: 1 }));
  s.files.get(asset.storagePath).metadata.generation = "999";
  await deny(
    collect({ ...s.context, assetId: asset.assetId }),
    "failed-precondition",
  );
  assert.ok(s.files.has(asset.storagePath));
});

test("cached private read rechecks authority and metadata without downloading bytes again", async () => {
  const s = setup(),
    asset = await ready(s);
  await attach(s, asset);
  const before = s.reads();
  const result = await read(
    invoke(s, { assetId: asset.assetId, knownGeneration: asset.generation }),
  );
  assert.equal(result.notModified, true);
  assert.equal(result.base64, undefined);
  assert.equal(s.reads() - before, 1, "only the object metadata is read");
  s.db.values.get("admins/a").authorizedCommunityIds = ["B"];
  await deny(
    read(
      invoke(s, { assetId: asset.assetId, knownGeneration: asset.generation }),
    ),
  );
});
