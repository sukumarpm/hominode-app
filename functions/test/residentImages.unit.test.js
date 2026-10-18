const test = require("node:test");
const assert = require("node:assert/strict");
const {
  setup,
  auth,
  jpeg,
  nowMs,
} = require("./helpers/storage_images_fixture");
const {
  prepareStorageImageUploadCore: prepare,
  readStorageImageCore: read,
} = require("../src/storage_images");
const {
  createResidentImageDraftCore: draft,
  commitResidentImagesCore: commit,
  collectResidentAsset: collect,
  reference,
} = require("../src/resident_images");

test("missing subscription rejects Marketplace/Wall drafts without writing a draft or listing", async () => {
  const s = setup();
  s.db.values.delete("subscriptions/A");
  const before = [...s.db.values.keys()];
  for (const feature of ["marketplace", "community_wall"])
    await assert.rejects(draft(call(s, { feature })), {
      code: "failed-precondition",
      message: "This community does not have a subscription.",
    });
  assert.deepEqual([...s.db.values.keys()], before);
  assert.equal(s.files.size, 0);
});

test("subscription lookup failure leaves no draft, upload or partial listing", async () => {
  const s = setup();
  const transaction = s.db.runTransaction.bind(s.db);
  s.db.runTransaction = (fn) =>
    transaction((tx) =>
      fn({
        ...tx,
        get: (ref) => {
          if (ref.path === "subscriptions/A")
            throw new Error("Synthetic unavailable");
          return tx.get(ref);
        },
      }),
    );
  const before = [...s.db.values.keys()];
  await assert.rejects(
    draft(call(s, { feature: "marketplace" })),
    /Synthetic unavailable/,
  );
  assert.deepEqual([...s.db.values.keys()], before);
  assert.equal(s.files.size, 0);
});
const call = (s, data, uid = "r") => ({ ...s.context, auth: auth(uid), data });
const deny = (promise, code = "permission-denied") =>
  assert.rejects(promise, (e) => e.code === code);
const target = {
  profile: "r",
  community_wall: "p",
  complaints: "c",
  marketplace: "m",
};
async function ready(s, feature, resourceId = target[feature]) {
  const pending = await prepare(
    call(s, {
      feature,
      resourceId,
      contentType: "image/jpeg",
      size: jpeg.length,
    }),
  );
  s.upload(pending);
  return s.finish(pending);
}
function save(s, feature, asset, extra = {}) {
  return commit(
    call(s, {
      feature,
      resourceId: target[feature],
      operationId: `operation-${asset.assetId}`,
      expectedRevision: 0,
      references: [reference(asset.assetId)],
      ...extra,
    }),
  );
}
for (const feature of Object.keys(target))
  test(`${feature}: owner attach/read/replace/remove preserves identity and legacy fields`, async () => {
    const s = setup(),
      asset = await ready(s, feature);
    const result = await save(s, feature, asset);
    assert.equal(result.imageRevision, 1);
    assert.equal(
      (await read(call(s, { assetId: asset.assetId }))).base64,
      jpeg.toString("base64"),
    );
    assert.deepEqual(await save(s, feature, asset), result);
    const next = await ready(s, feature);
    await save(s, feature, next, { expectedRevision: 1 });
    assert.equal(s.files.has(asset.storagePath), true);
    await collect({ ...s.context, assetId: asset.assetId });
    assert.equal(s.files.has(asset.storagePath), false);
    await commit(
      call(s, {
        feature,
        resourceId: target[feature],
        operationId: "remove",
        expectedRevision: 2,
        references: [],
      }),
    );
    await collect({ ...s.context, assetId: next.assetId });
    assert.equal(s.files.has(next.storagePath), false);
  });
test("owned drafts publish Wall/Marketplace content and images atomically with canonical identity", async () => {
  for (const feature of ["community_wall", "marketplace"]) {
    const s = setup(),
      ticket = await draft(call(s, { feature })),
      asset = await ready(s, feature, ticket.resourceId);
    s.db.values.get("users/r").flatNumber = "Garden-07";
    const content =
      feature === "community_wall"
        ? { content: "Community garden" }
        : {
            title: "Chair",
            description: "Good condition",
            price: 500,
            category: "Furniture",
            condition: "Like New",
          };
    const request = {
      feature,
      resourceId: ticket.resourceId,
      operationId: "publish",
      expectedRevision: 0,
      references: [reference(asset.assetId)],
      content,
    };
    const result = await commit(call(s, request));
    assert.deepEqual(await commit(call(s, request)), result);
    const record = s.db.values.get(
      `${feature === "community_wall" ? "posts" : "marketplaces"}/${ticket.resourceId}`,
    );
    assert.equal(record.communityId, "A");
    assert.equal(record.buildingId, "b");
    assert.equal(
      record[feature === "community_wall" ? "authorId" : "sellerId"],
      "r",
    );
    assert.equal(record.managedImageAssets[0].assetId, asset.assetId);
    if (feature === "community_wall") {
      assert.equal(record.flat, "Garden-07");
      assert.equal(record.flatLabel, "Garden-07");
      assert.equal(record.flatId, null);
    }
    assert.equal(
      s.db.values.get(`residentImageDrafts/${ticket.resourceId}`).state,
      "published",
    );
  }
});
test("foreign resident, tenant and inactive/expired identities cannot use drafts or assets", async () => {
  const s = setup(),
    ticket = await draft(call(s, { feature: "marketplace" }));
  await deny(
    prepare(
      call(
        s,
        {
          feature: "marketplace",
          resourceId: ticket.resourceId,
          contentType: "image/jpeg",
          size: 4,
        },
        "other",
      ),
    ),
  );
  s.db.values.get("users/r").communityId = "B";
  await deny(
    prepare(
      call(s, {
        feature: "marketplace",
        resourceId: ticket.resourceId,
        contentType: "image/jpeg",
        size: 4,
      }),
    ),
  );
  s.db.values.get("users/r").communityId = "A";
  s.db.values.get(`residentImageDrafts/${ticket.resourceId}`).expiresAtMs =
    nowMs;
  await deny(ready(s, "marketplace", ticket.resourceId));
  await deny(
    draft({ ...call(s, { feature: "marketplace" }), auth: null }),
    "unauthenticated",
  );
});
test("other resident asset, wrong resource, supplied authority and new external URLs fail closed", async () => {
  const s = setup(),
    asset = await ready(s, "complaints");
  s.db.values.set("complaints/other", { communityId: "A", userId: "other" });
  await deny(
    commit(
      call(
        s,
        {
          feature: "complaints",
          resourceId: "other",
          operationId: "x",
          expectedRevision: 0,
          references: [reference(asset.assetId)],
        },
        "other",
      ),
    ),
  );
  await deny(save(s, "profile", asset));
  await deny(
    save(s, "complaints", asset, {
      references: ["https://example.invalid/new.jpg"],
    }),
    "invalid-argument",
  );
  for (const key of ["communityId", "ownerId", "storagePath", "role"])
    await deny(
      save(s, "complaints", asset, { [key]: "forged" }),
      "invalid-argument",
    );
});
test("private readers enforce complaint privacy, same-building marketplace and community wall entitlement", async () => {
  for (const feature of [
    "complaints",
    "marketplace",
    "community_wall",
    "profile",
  ]) {
    const s = setup();
    if (feature === "marketplace")
      s.db.values.get("marketplaces/m").buildingId = "b";
    const asset = await ready(s, feature);
    await save(s, feature, asset);
    if (feature === "complaints")
      await deny(read(call(s, { assetId: asset.assetId }, "other")));
    else
      assert.equal(
        (await read(call(s, { assetId: asset.assetId }, "other"))).size,
        jpeg.length,
      );
    s.db.values.get("users/other").communityId = "B";
    await deny(read(call(s, { assetId: asset.assetId }, "other")));
    if (feature === "marketplace") {
      s.db.values.get("users/other").communityId = "A";
      s.db.values.get("users/other").buildingId = "different";
      await deny(read(call(s, { assetId: asset.assetId }, "other")));
    }
    if (["marketplace", "community_wall"].includes(feature)) {
      s.db.values.delete("subscriptions/A");
      await deny(read(call(s, { assetId: asset.assetId })));
    }
  }
});
test("apartment bytes allow only active residents of the exact building/community", async () => {
  const s = setup();
  const pending = await s.reserve("apartment");
  s.upload(pending);
  const asset = await s.finish(pending);
  await require("../src/apartment_images").saveApartmentImageCore({
    ...s.context,
    auth: auth("a"),
    data: {
      assetId: asset.assetId,
      title: "Garden",
      description: "",
      type: "Common Area",
      uploadDate: "",
      uploadTime: "",
    },
  });
  assert.equal(
    (await read(call(s, { assetId: asset.assetId }))).size,
    jpeg.length,
  );
  for (const change of [
    { buildingId: "wrong" },
    { communityId: "B" },
    { isActive: false },
    { approvalStatus: "pending" },
    {
      residentType: "tenant",
      ownershipType: "tenant",
      identityVerified: false,
    },
  ]) {
    const original = { ...s.db.values.get("users/r") };
    Object.assign(s.db.values.get("users/r"), change);
    await deny(read(call(s, { assetId: asset.assetId })));
    s.db.values.set("users/r", original);
  }
});
test("stale revisions, entitlement verification failure and failed publish leave no broken pointer", async () => {
  const s = setup(),
    asset = await ready(s, "marketplace");
  await save(s, "marketplace", asset);
  const next = await ready(s, "marketplace");
  await deny(save(s, "marketplace", next), "aborted");
  assert.equal(
    s.db.values.get("marketplaces/m").managedImageAssets[0].assetId,
    asset.assetId,
  );
  s.db.values.delete("subscriptions/A");
  await deny(save(s, "marketplace", next, { expectedRevision: 1 }));
  assert.equal(
    await collect({
      ...s.context,
      assetId: next.assetId,
      now: () => next.expiresAtMs + 3600001,
    }),
    true,
  );
  assert.equal(s.files.has(asset.storagePath), true);
});
test("delete resource detaches before generation-safe cleanup and is idempotent", async () => {
  for (const feature of ["marketplace", "community_wall"]) {
    const s = setup(),
      asset = await ready(s, feature);
    await save(s, feature, asset);
    const data = {
      feature,
      resourceId: target[feature],
      operationId: "delete",
      expectedRevision: 1,
      references: [],
      deleteResource: true,
    };
    await commit(call(s, data));
    await commit(call(s, data));
    assert.equal(s.files.has(asset.storagePath), true);
    await deny(read(call(s, { assetId: asset.assetId })));
    await collect({ ...s.context, assetId: asset.assetId });
    assert.equal(s.files.has(asset.storagePath), false);
  }
});
test("profile copies resolve current image, never deleted historical bytes", async () => {
  const s = setup(),
    old = await ready(s, "profile");
  await save(s, "profile", old);
  const next = await ready(s, "profile");
  await save(s, "profile", next, { expectedRevision: 1 });
  await collect({ ...s.context, assetId: old.assetId });
  const result = await read(call(s, { assetId: old.assetId }, "other"));
  assert.equal(result.assetId, next.assetId);
  assert.equal(result.redirectedFrom, old.assetId);
  await commit(
    call(s, {
      feature: "profile",
      resourceId: "r",
      operationId: "remove",
      expectedRevision: 2,
      references: [],
    }),
  );
  await deny(read(call(s, { assetId: old.assetId }, "other")), "not-found");
});
test("late read revocation and cached authorization checks never deliver stale bytes", async () => {
  const s = setup(),
    asset = await ready(s, "complaints");
  await save(s, "complaints", asset);
  const before = s.reads();
  const cached = await read(
    call(s, {
      assetId: asset.assetId,
      knownAssetId: asset.assetId,
      knownGeneration: asset.generation,
    }),
  );
  assert.equal(cached.notModified, true);
  assert.equal(s.reads() - before, 1);
  const original = s.bucket.file.bind(s.bucket);
  s.bucket.file = (...args) => {
    const file = original(...args);
    return {
      ...file,
      download: async (...a) => {
        const bytes = await file.download(...a);
        s.db.values.get("users/r").isActive = false;
        return bytes;
      },
    };
  };
  await deny(read(call(s, { assetId: asset.assetId })));
});
test("cleanup survives partial private creation and refuses changed generations", async () => {
  const s = setup(),
    asset = await ready(s, "profile");
  assert.equal(
    await collect({
      ...s.context,
      assetId: asset.assetId,
      now: () => asset.expiresAtMs + 3600001,
    }),
    true,
  );
  const pending = await s.reserve("complaints");
  s.upload(pending);
  const original = s.bucket.file.bind(s.bucket);
  s.bucket.file = (...args) => {
    const file = original(...args);
    return {
      ...file,
      save: async (...a) => {
        await file.save(...a);
        s.db.values.get("users/r").isActive = false;
      },
    };
  };
  await deny(s.finish(pending));
  await collect({
    ...s.context,
    assetId: pending.assetId,
    now: () => pending.expiresAtMs + 3600001,
  });
  assert.equal(s.files.size, 0);
});
test("server reservation rate limit bounds repeated authenticated attempts", async () => {
  const s = setup();
  for (let i = 0; i < 30; i++) await s.reserve("profile");
  await deny(s.reserve("profile"), "resource-exhausted");
});

test("replacement keeps unrelated complaint documents and removes only replaced managed images", async () => {
  const s = setup();
  s.db.values.get("complaints/c").attachments = [
    "https://example.invalid/existing-document.pdf",
  ];
  const asset = await ready(s, "complaints");
  await save(s, "complaints", asset);
  assert.deepEqual(s.db.values.get("complaints/c").attachments, [
    "https://example.invalid/existing-document.pdf",
    reference(asset.assetId),
  ]);
  await commit(
    call(s, {
      feature: "complaints",
      resourceId: "c",
      operationId: "remove-photo",
      expectedRevision: 1,
      references: [],
    }),
  );
  assert.deepEqual(s.db.values.get("complaints/c").attachments, [
    "https://example.invalid/existing-document.pdf",
  ]);
});
test("late profile pointer change cannot return the previous bytes even with identical generation/hash", async () => {
  const s = setup(),
    old = await ready(s, "profile");
  await save(s, "profile", old);
  const next = await ready(s, "profile");
  const original = s.bucket.file.bind(s.bucket);
  s.bucket.file = (...args) => {
    const file = original(...args);
    return {
      ...file,
      download: async (...a) => {
        const bytes = await file.download(...a);
        await save(s, "profile", next, { expectedRevision: 1 });
        return bytes;
      },
    };
  };
  await deny(read(call(s, { assetId: old.assetId }, "other")));
});
test("existing Admin apartment access is preserved for a dual-role UID", async () => {
  const s = setup();
  s.db.values.set("users/a", {
    ...s.db.values.get("users/r"),
    uid: "a",
    buildingId: "different",
  });
  const pending = await s.reserve("apartment");
  s.upload(pending);
  const asset = await s.finish(pending);
  await require("../src/apartment_images").saveApartmentImageCore({
    ...s.context,
    auth: auth("a"),
    data: {
      assetId: asset.assetId,
      title: "Garden",
      description: "",
      type: "Common Area",
      uploadDate: "",
      uploadTime: "",
    },
  });
  assert.equal(
    (await read(call(s, { assetId: asset.assetId }, "a"))).size,
    jpeg.length,
  );
});
test("content moderation blocks a draft publication without creating a partial record", async () => {
  const s = setup(),
    ticket = await draft(call(s, { feature: "community_wall" })),
    asset = await ready(s, "community_wall", ticket.resourceId);
  await deny(
    commit(
      call(s, {
        feature: "community_wall",
        resourceId: ticket.resourceId,
        operationId: "blocked",
        expectedRevision: 0,
        references: [reference(asset.assetId)],
        content: { content: "illegal content" },
      }),
    ),
    "invalid-argument",
  );
  assert.equal(s.db.values.has(`posts/${ticket.resourceId}`), false);
});
test("transient retirement failure retries safely without touching an attached replacement", async () => {
  const s = setup(),
    old = await ready(s, "profile");
  await save(s, "profile", old);
  const next = await ready(s, "profile");
  await save(s, "profile", next, { expectedRevision: 1 });
  const original = s.bucket.file.bind(s.bucket);
  let fail = true;
  s.bucket.file = (...args) => {
    const file = original(...args);
    return {
      ...file,
      delete: async (...a) => {
        if (fail) throw Error("Synthetic failure");
        return file.delete(...a);
      },
    };
  };
  await assert.rejects(collect({ ...s.context, assetId: old.assetId }));
  fail = false;
  await collect({ ...s.context, assetId: old.assetId });
  assert.ok(s.files.has(next.storagePath));
  assert.equal(
    await collect({
      ...s.context,
      assetId: next.assetId,
      now: () => next.expiresAtMs + 3600001,
    }),
    false,
  );
});

test("invalid staging payload size cannot finalize but is still reclaimed after expiry", async () => {
  const s = setup(),
    pending = await s.reserve("profile");
  s.upload(pending, { size: 5 });
  await deny(s.finish(pending), "failed-precondition");
  await collect({
    ...s.context,
    assetId: pending.assetId,
    now: () => pending.expiresAtMs + 3600001,
  });
  assert.equal(s.files.size, 0);
});

test("Essential Wall draft/private image works while premium Marketplace and foreign reads stay denied", async () => {
  const s = setup();
  s.db.values.set("subscriptions/A", { planId: "essential", status: "active" });
  const ticket = await draft(call(s, { feature: "community_wall" }));
  const image = await ready(s, "community_wall", ticket.resourceId);
  await commit(
    call(s, {
      feature: "community_wall",
      resourceId: ticket.resourceId,
      expectedRevision: 0,
      operationId: "essential-wall",
      references: [reference(image.assetId)],
      content: { content: "Community garden" },
    }),
  );
  assert.equal(
    (await read(call(s, { assetId: image.assetId }, "other"))).size,
    jpeg.length,
  );
  await deny(ready(s, "marketplace"));
  s.db.values.get("users/other").communityId = "B";
  await deny(read(call(s, { assetId: image.assetId }, "other")));
});
