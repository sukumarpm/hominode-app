const test = require("node:test");
const assert = require("node:assert/strict");
const { setup, auth, jpeg } = require("./helpers/storage_images_fixture");
const { readStorageImageCore: read } = require("../src/storage_images");
const {
  saveApartmentImageCore: save,
  deleteApartmentImageCore: remove,
  collectApartmentAsset: collect,
} = require("../src/apartment_images");
const { binding, requestScope } = require("../src/photo_ownership");
const details = {
  title: "Shared space",
  description: "",
  type: "Common Area",
  uploadDate: "2026-10-21",
  uploadTime: "10:00",
};
const invoke = (s, data, uid = "a") => ({
  ...s.context,
  auth: uid ? auth(uid) : null,
  data,
});
const deny = (operation, code = "permission-denied") =>
  assert.rejects(operation, (e) => e.code === code);
function fixture() {
  const s = setup();
  s.db.values.set("buildings/second", { communityId: "A" });
  s.db.values.set("buildings/foreign", { communityId: "B" });
  s.db.values.set("flats/unit-canonical", {
    communityId: "A",
    buildingId: "b",
    flatId: "101",
    status: "occupied",
    residentUserId: "r",
  });
  s.db.values.set("flats/second-unit", {
    communityId: "A",
    buildingId: "b",
    status: "occupied",
    residentUserId: "other",
  });
  Object.assign(s.db.values.get("users/r"), { flatId: "unit-canonical" });
  Object.assign(s.db.values.get("users/other"), { flatId: "second-unit" });
  return s;
}
const resource = { COMMUNITY: "A", BUILDING: "b", UNIT: "unit-canonical" };
async function reserve(s, scope, overrides = {}) {
  return s.reserve("apartment", {
    data: {
      feature: "apartment",
      contractVersion: 2,
      ownershipScope: scope,
      resourceId: resource[scope],
      contentType: "image/jpeg",
      size: jpeg.length,
      ...overrides,
    },
  });
}
async function ready(s, scope) {
  const pending = await reserve(s, scope);
  s.upload(pending);
  return s.finish(pending);
}
async function attach(s, asset) {
  return save(invoke(s, { assetId: asset.assetId, ...details }));
}
for (const scope of Object.keys(resource)) {
  test(`${scope}: full lifecycle, immutable attachment and idempotent revision-checked deletion`, async () => {
    const s = fixture(),
      asset = await ready(s, scope);
    assert.equal(asset.contractVersion, 2);
    assert.equal(asset.ownershipScope, scope);
    assert.equal(asset.buildingId, scope === "COMMUNITY" ? undefined : "b");
    assert.equal(asset.unitId, scope === "UNIT" ? "unit-canonical" : undefined);
    const result = await attach(s, asset);
    assert.deepEqual(await attach(s, asset), result);
    const image = s.db.values.get(`apartmentImagesV2/${asset.assetId}`);
    assert.deepEqual(binding(image), binding(asset));
    assert.equal(image.type, "Common Area");
    assert.equal(
      (await read(invoke(s, { assetId: asset.assetId }, "r"))).size,
      jpeg.length,
    );
    await deny(
      remove(
        invoke(s, {
          imageId: asset.assetId,
          contractVersion: 2,
          expectedRevision: 0,
        }),
      ),
      "aborted",
    );
    await deny(
      remove(
        invoke(
          s,
          { imageId: asset.assetId, contractVersion: 2, expectedRevision: 1 },
          "r",
        ),
      ),
    );
    assert.deepEqual(
      await remove(
        invoke(s, {
          imageId: asset.assetId,
          contractVersion: 2,
          expectedRevision: 1,
        }),
      ),
      { imageId: asset.assetId, deleted: true },
    );
    assert.deepEqual(
      await remove(
        invoke(s, {
          imageId: asset.assetId,
          contractVersion: 2,
          expectedRevision: 1,
        }),
      ),
      { imageId: asset.assetId, deleted: true },
    );
    await deny(read(invoke(s, { assetId: asset.assetId }, "r")));
    assert.ok(s.files.has(asset.storagePath));
    assert.equal(await collect({ ...s.context, assetId: asset.assetId }), true);
    assert.equal(s.files.size, 0);
  });
}
test("community-only upload works with zero building documents", async () => {
  const s = fixture();
  for (const key of s.db.values.keys())
    if (key.startsWith("buildings/")) s.db.values.delete(key);
  const asset = await ready(s, "COMMUNITY");
  await attach(s, asset);
  assert.equal(
    (await read(invoke(s, { assetId: asset.assetId }, "r"))).size,
    jpeg.length,
  );
});
test("scoped read enforces building and unit rather than the descriptive category", async () => {
  const s = fixture();
  const community = await ready(s, "COMMUNITY"),
    building = await ready(s, "BUILDING"),
    unit = await ready(s, "UNIT");
  for (const asset of [community, building, unit]) await attach(s, asset);
  assert.equal(
    (await read(invoke(s, { assetId: building.assetId }, "other"))).size,
    jpeg.length,
  );
  await deny(read(invoke(s, { assetId: unit.assetId }, "other")));
  s.db.values.get("users/other").buildingId = "second";
  await deny(read(invoke(s, { assetId: building.assetId }, "other")));
  assert.equal(
    (await read(invoke(s, { assetId: community.assetId }, "other"))).size,
    jpeg.length,
  );
  for (const scope of ["BUILDING", "UNIT"]) {
    const a = scope === "BUILDING" ? building : unit;
    s.db.values.get(`apartmentImagesV2/${a.assetId}`).type = "COMMUNITY";
    await deny(read(invoke(s, { assetId: a.assetId }, "other")));
  }
});
test("scope cannot be changed during replacement, including legacy-to-V2 conversion", async () => {
  const s = fixture();
  const original = await ready(s, "BUILDING");
  await attach(s, original);
  for (const other of [await ready(s, "COMMUNITY"), await ready(s, "UNIT")])
    await deny(
      save(
        invoke(s, {
          assetId: other.assetId,
          imageId: original.assetId,
          expectedRevision: 1,
        }),
      ),
    );
  const legacy = await s.reserve("apartment");
  s.upload(legacy);
  const old = await s.finish(legacy);
  await attach(s, old);
  await deny(
    save(
      invoke(s, {
        assetId: original.assetId,
        imageId: old.assetId,
        expectedRevision: 1,
      }),
    ),
    "failed-precondition",
  );
  const next = await ready(s, "BUILDING");
  await save(
    invoke(s, {
      assetId: next.assetId,
      imageId: original.assetId,
      expectedRevision: 1,
    }),
  );
  assert.equal(
    s.db.values.get(`apartmentImagesV2/${original.assetId}`).revision,
    2,
  );
  assert.equal(
    s.db.values.get(`storageImageUploads/${original.assetId}`).state,
    "retired",
  );
});
test("missing, forged and conflicting canonical resources are denied", async () => {
  for (const [scope, patch, code] of [
    ["COMMUNITY", { resourceId: "missing" }, "not-found"],
    ["COMMUNITY", { resourceId: "B" }, "permission-denied"],
    ["BUILDING", { resourceId: "foreign" }, "permission-denied"],
    ["UNIT", { resourceId: "101" }, "not-found"],
    ["UNIT", { resourceId: "../unit" }, "invalid-argument"],
    ["UNIT", { resourceId: "" }, "invalid-argument"],
  ])
    await deny(reserve(fixture(), scope, patch), code);
  const s = fixture();
  s.db.values.get("flats/unit-canonical").communityId = "B";
  await deny(reserve(s, "UNIT"));
});
test("unsupported versions and caller-controlled binding fields never enter reservations", async () => {
  for (const patch of [
    { contractVersion: 1 },
    { contractVersion: undefined },
    { ownershipScope: "ALL" },
    { ownershipScope: undefined },
    { buildingId: "forged" },
    { unitId: "other" },
    { communityId: "B" },
    { ownerId: "other" },
  ])
    await deny(reserve(fixture(), "COMMUNITY", patch), "invalid-argument");
  for (const value of ["a/b", "a\\b", "..", "\u0000"])
    assert.throws(() =>
      requestScope({
        feature: "apartment",
        contractVersion: 2,
        ownershipScope: "COMMUNITY",
        resourceId: value,
      }),
    );
});
test("completion and attachment recheck membership and resource association", async () => {
  const s = fixture(),
    pending = await reserve(s, "BUILDING");
  s.upload(pending);
  s.db.values.get("buildings/b").communityId = "B";
  await deny(s.finish(pending));
  const other = fixture(),
    asset = await ready(other, "UNIT");
  other.db.values.get("flats/unit-canonical").buildingId = "second";
  await deny(attach(other, asset));
  assert.equal(
    [...other.db.values.keys()].filter((k) => k.startsWith("apartmentImages/"))
      .length,
    0,
  );
});
test("UNIT reads reject missing/conflicting reciprocal occupancy, profile moves and revoked sessions", async () => {
  for (const patch of [
    { residentUserId: null },
    { residentUid: "other" },
    { residentIds: ["r", "other"] },
    { residentId: "other" },
    { status: "reserved" },
  ]) {
    const s = fixture(),
      asset = await ready(s, "UNIT");
    await attach(s, asset);
    Object.assign(s.db.values.get("flats/unit-canonical"), patch);
    await assert.rejects(read(invoke(s, { assetId: asset.assetId }, "r")));
  }
  const s = fixture(),
    asset = await ready(s, "UNIT");
  await attach(s, asset);
  s.db.values.get("users/r").flatId = "second-unit";
  await deny(read(invoke(s, { assetId: asset.assetId }, "r")));
  await deny(
    read(invoke(s, { assetId: asset.assetId }, null)),
    "unauthenticated",
  );
  s.db.values.get("users/r").communityId = "B";
  await deny(read(invoke(s, { assetId: asset.assetId }, "r")));
});
test("old requests preserve unclassified building links and legacy resident read behavior", async () => {
  const s = fixture(),
    pending = await s.reserve("apartment");
  assert.equal(pending.contractVersion, undefined);
  s.upload(pending);
  const asset = await s.finish(pending);
  await attach(s, asset);
  const image = s.db.values.get(`apartmentImages/${asset.assetId}`);
  assert.equal(image.ownershipScope, undefined);
  assert.equal(image.resourceId, undefined);
  assert.equal(image.buildingId, "b");
  s.db.values.get("users/other").buildingId = "second";
  assert.equal(
    (await read(invoke(s, { assetId: asset.assetId }, "other"))).size,
    jpeg.length,
  );
  await remove(invoke(s, { imageId: asset.assetId, expectedRevision: 1 }));
  s.db.values.set("apartmentImages/old-url", {
    communityId: "A",
    buildingId: "b",
    status: "active",
    imageUrl: "https://example.invalid/legacy.jpg",
    type: "Common Area",
  });
  await remove(invoke(s, { imageId: "old-url", expectedRevision: 0 }));
  assert.equal(
    s.files.size,
    1,
    "legacy URL deletion never touches unrelated objects",
  );
});
test("V2 attachment rejects client scope edits and preserves old asset on failed replace", async () => {
  const s = fixture(),
    asset = await ready(s, "COMMUNITY");
  await deny(
    save(
      invoke(s, { assetId: asset.assetId, ...details, ownershipScope: "UNIT" }),
    ),
    "invalid-argument",
  );
  await attach(s, asset);
  const next = await ready(s, "COMMUNITY");
  await deny(
    save(
      invoke(s, {
        assetId: next.assetId,
        imageId: asset.assetId,
        expectedRevision: 7,
      }),
    ),
    "aborted",
  );
  assert.ok(s.files.has(asset.storagePath));
});

test("V2 deletion never falls back to the legacy namespace", async () => {
  const s = fixture(),
    asset = await ready(s, "COMMUNITY");
  await attach(s, asset);
  await deny(
    remove(invoke(s, { imageId: asset.assetId, expectedRevision: 1 })),
    "not-found",
  );
  s.db.values.set(`apartmentImages/${asset.assetId}`, {
    communityId: "A",
    buildingId: "b",
    status: "active",
    imageUrl: "https://example.invalid/not-fetched.jpg",
  });
  await remove(
    invoke(s, {
      imageId: asset.assetId,
      contractVersion: 2,
      expectedRevision: 1,
    }),
  );
  assert.ok(s.db.values.has(`apartmentImages/${asset.assetId}`));
  await deny(
    remove(
      invoke(s, {
        imageId: asset.assetId,
        contractVersion: 3,
        expectedRevision: 1,
      }),
    ),
    "invalid-argument",
  );
});

test("UNIT reauthorization after download rejects an occupant change without delivering bytes", async () => {
  const s = fixture(),
    asset = await ready(s, "UNIT");
  await attach(s, asset);
  const original = s.bucket.file.bind(s.bucket);
  s.bucket.file = (...args) => {
    const file = original(...args);
    return {
      ...file,
      download: async (...params) => {
        const result = await file.download(...params);
        s.db.values.get("flats/unit-canonical").residentUserId = "other";
        return result;
      },
    };
  };
  await deny(read(invoke(s, { assetId: asset.assetId }, "r")));
});
