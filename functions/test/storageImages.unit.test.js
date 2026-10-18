const test = require("node:test");
const assert = require("node:assert/strict");
const {
  prepareStorageImageUploadCore: prepare,
  completeStorageImageUploadCore: complete,
  validateImageBytes,
  MAX_IMAGE_BYTES,
  readStorageImageCore: readImage,
} = require("../src/storage_images");

const {
  setup,
  auth,
  nowMs,
  jpeg,
  targets,
  phone,
} = require("./helpers/storage_images_fixture");
const denied = (operation, code = "permission-denied") =>
  assert.rejects(operation, (error) => error.code === code);

for (const feature of Object.keys(targets)) {
  test(`${feature}: trusted reservation and private finalization preserve domain URLs`, async () => {
    const s = setup();
    const before = new Map(
      [...s.db.values].map(([key, value]) => [key, JSON.stringify(value)]),
    );
    const asset = await s.reserve(feature);
    assert.equal(asset.ownerId, targets[feature][0]);
    assert.equal(asset.communityId, "A");
    assert.equal(asset.provider, "firebase");
    assert.equal(asset.state, "pending");
    assert.ok(
      asset.storagePath.startsWith(
        feature === "apartment"
          ? "apartment_images/A/a/"
          : `resident_images/A/r/${feature}/`,
      ),
    );
    s.upload(asset);
    const ready = await s.finish(asset);
    assert.equal(ready.state, "ready");
    assert.equal(ready.generation, "9");
    assert.match(ready.sha256, /^[a-f0-9]{64}$/);
    assert.equal(s.files.has(asset.storagePath), false);
    assert.equal(
      s.files.get(ready.storagePath).metadata.metadata
        .firebaseStorageDownloadTokens,
      undefined,
    );
    assert.ok(ready.storagePath.startsWith("private_images/"));
    assert.equal(ready.imageUrl, undefined);
    assert.deepEqual(
      await s.finish(asset),
      ready,
      "finalization retry is idempotent",
    );
    for (const [path, data] of before)
      assert.equal(JSON.stringify(s.db.values.get(path)), data);
  });
}

test("unauthenticated, password-provider and mismatched phone callers fail closed", async () => {
  for (const invalid of [
    null,
    {
      uid: "r",
      token: {
        phone_number: phone,
        firebase: { sign_in_provider: "password" },
      },
    },
  ]) {
    await denied(
      setup().reserve("profile", { auth: invalid }),
      "unauthenticated",
    );
  }
  const wrong = auth("r");
  wrong.token.phone_number = "+639170000001";
  await denied(setup().reserve("profile", { auth: wrong }));
});

test("client role, community, owner, paths and URL inputs are rejected", async () => {
  for (const key of [
    "role",
    "communityId",
    "ownerId",
    "storagePath",
    "bucket",
    "imageUrl",
  ]) {
    const s = setup();
    await denied(
      s.reserve("profile", {
        data: {
          feature: "profile",
          resourceId: "r",
          contentType: "image/jpeg",
          size: 4,
          [key]: "forged",
        },
      }),
      "invalid-argument",
    );
    assert.equal(s.db.values.size, 10);
  }
});

test("unsupported type, oversized/empty file, traversal and missing target fail", async () => {
  for (const change of [
    { contentType: "image/svg+xml" },
    { contentType: "text/html" },
    { size: 0 },
    { size: MAX_IMAGE_BYTES + 1 },
    { feature: "__proto__" },
    { resourceId: "../r" },
  ]) {
    await denied(
      setup().reserve("profile", {
        data: {
          feature: "profile",
          resourceId: "r",
          contentType: "image/jpeg",
          size: 4,
          ...change,
        },
      }),
      "invalid-argument",
    );
  }
  await denied(
    setup().reserve("profile", {
      data: {
        feature: "profile",
        resourceId: "missing",
        contentType: "image/jpeg",
        size: 4,
      },
    }),
    "not-found",
  );
});

test("other resident resources, conflicting owners and wrong tenant fail", async () => {
  for (const path of ["posts/p", "complaints/c", "marketplaces/m"]) {
    const s = setup();
    const target = s.db.values.get(path);
    const feature = path.startsWith("posts")
      ? "community_wall"
      : path.startsWith("complaints")
        ? "complaints"
        : "marketplace";
    s.db.values.set(path, { ...target, communityId: "B" });
    await denied(s.reserve(feature));
    s.db.values.set(path, { ...target, ownerId: "other" });
    await denied(s.reserve(feature));
  }
  await denied(
    setup().reserve("profile", {
      data: {
        feature: "profile",
        resourceId: "other",
        contentType: "image/jpeg",
        size: 4,
      },
    }),
  );
  const s = setup();
  s.db.values.get("admins/a").authorizedCommunityIds = ["B"];
  await denied(s.reserve("apartment"));
});

test("inactive/pending/moved/unverified profiles and inactive communities fail", async () => {
  for (const change of [
    { isActive: false },
    { approvalStatus: "pending" },
    { status: "moved_out" },
    { role: "security" },
    { uid: "other" },
    {
      residentType: "tenant",
      ownershipType: "tenant",
      identityVerified: false,
    },
  ]) {
    const s = setup();
    Object.assign(s.db.values.get("users/r"), change);
    await denied(s.reserve());
  }
  const s = setup();
  s.db.values.get("communities/A").isActive = false;
  await denied(s.reserve());
  await denied(s.reserve("apartment"));
});

test("wall/marketplace subscription verification fails closed and legacy building scope is derived", async () => {
  for (const feature of ["community_wall", "marketplace"]) {
    const s = setup();
    s.db.values.delete("subscriptions/A");
    await denied(s.reserve(feature));
  }
  const s = setup();
  delete s.db.values.get("marketplaces/m").communityId;
  s.db.values.get("marketplaces/m").buildingId = "b";
  assert.equal((await s.reserve("marketplace")).communityId, "A");
});

test("finalization checks owner, current membership and target before reading bytes", async () => {
  for (const mutate of [
    (s) => {
      s.db.values.get("users/r").isActive = false;
    },
    (s) => {
      s.db.values.get("communities/A").isActive = false;
    },
    (s) => {
      s.db.values.get("complaints/c").userId = "other";
    },
  ]) {
    const s = setup();
    const asset = await s.reserve("complaints");
    s.upload(asset);
    mutate(s);
    await denied(s.finish(asset));
    assert.equal(s.reads(), 0);
    assert.equal(
      s.db.values.get(`storageImageUploads/${asset.assetId}`).state,
      "pending",
    );
  }
  const s = setup();
  const asset = await s.reserve();
  s.upload(asset);
  await denied(s.finish(asset, { auth: auth("other") }));
  assert.equal(s.reads(), 0);
});

test("expiry, missing object, mismatched metadata and spoofed content do not become ready", async () => {
  let s = setup();
  let asset = await s.reserve();
  await denied(s.finish(asset), "not-found");
  await denied(
    s.finish(asset, { now: () => asset.expiresAtMs }),
    "permission-denied",
  );
  for (const change of [
    { name: "other" },
    { contentType: "text/html" },
    { size: 5 },
    { contentEncoding: "gzip" },
    { metadata: { ownerId: "other" } },
  ]) {
    s = setup();
    asset = await s.reserve();
    s.upload(asset, change);
    await denied(s.finish(asset), "failed-precondition");
  }
  s = setup();
  asset = await s.reserve();
  s.upload(asset);
  // Preserve the expected byte length so image decoding,
  // rather than the earlier size check, rejects spoofed content.
  const uploaded = s.files.get(asset.storagePath);
  uploaded.bytes = Buffer.alloc(uploaded.bytes.length, 0x68);
  await denied(s.finish(asset), "invalid-argument");
});

test("generation cannot change on retry", async () => {
  const s = setup();
  const asset = await s.reserve();
  s.upload(asset);
  const ready = await s.finish(asset);
  s.files.get(ready.storagePath).metadata.generation = "8";
  await denied(s.finish(asset), "failed-precondition");
});

test("late revocation is rechecked in the final transaction", async () => {
  const t = setup();
  const pending = await t.reserve();
  t.upload(pending);
  const original = t.bucket.file.bind(t.bucket);
  t.bucket.file = (path, options) => {
    const file = original(path, options);
    return {
      ...file,
      async save(...args) {
        const result = await file.save(...args);
        t.db.values.get("users/r").isActive = false;
        return result;
      },
    };
  };
  await denied(t.finish(pending));
  assert.equal(
    t.db.values.get(`storageImageUploads/${pending.assetId}`).state,
    "pending",
  );
});

test("decoded image validation rejects malformed bytes, MIME mismatches and animation", async () => {
  const sharp = require("sharp");
  const types = ["image/jpeg", "image/png", "image/gif", "image/webp"];
  const invalid = (bytes, type) =>
    assert.rejects(
      validateImageBytes(bytes, type),
      (error) => error.code === "invalid-argument",
    );
  for (const type of types) {
    await invalid(Buffer.from("<svg>bad</svg>"), type);
    await invalid(Buffer.from([0xff, 0xd8, 0xff, 0xd9]), type);
  }
  await validateImageBytes(jpeg, "image/jpeg");
  await invalid(jpeg, "image/png");
  await invalid(jpeg.subarray(0, 90), "image/jpeg");

  const png = await sharp(jpeg).png().toBuffer();
  const webp = await sharp(jpeg).webp().toBuffer();
  const gif = await sharp(jpeg).gif().toBuffer();
  await validateImageBytes(png, "image/png");
  await validateImageBytes(webp, "image/webp");
  await validateImageBytes(gif, "image/gif");
  await invalid(png.subarray(0, 24), "image/png");
  await invalid(webp.subarray(0, 20), "image/webp");
  await invalid(gif.subarray(0, 14), "image/gif");
  await invalid(Buffer.alloc(MAX_IMAGE_BYTES + 1), "image/jpeg");

  const animatedGif = await sharp(
    Buffer.from([255, 0, 0, 255, 0, 0, 0, 255, 0, 0, 255, 0]),
    { raw: { width: 2, height: 2, channels: 3, pageHeight: 1 } },
  )
    .gif()
    .toBuffer();
  // Decoder metadata identifies multi-frame animation regardless of its header.
  assert.equal((await sharp(animatedGif).metadata()).pages, 2);
  await invalid(animatedGif, "image/gif");
  const oversized = Buffer.from(jpeg);
  const frame = oversized.indexOf(Buffer.from([255, 192]));
  assert.ok(frame > 0);
  oversized.writeUInt16BE(5000, frame + 5);
  oversized.writeUInt16BE(10000, frame + 7);
  const dimensions = await sharp(oversized, {
    limitInputPixels: false,
  }).metadata();
  assert.equal(dimensions.width * dimensions.height, 50_000_000);
  await invalid(oversized, "image/jpeg");
});

test("failed staging deletion remains verified and retries without overwriting the private file", async () => {
  const s = setup();
  const pending = await s.reserve();
  s.upload(pending);
  const original = s.bucket.file.bind(s.bucket);
  let blocked = true;
  s.bucket.file = (path, options) => {
    const file = original(path, options);
    return {
      ...file,
      async delete(...args) {
        if (blocked) throw Object.assign(new Error("transient"), { code: 503 });
        return file.delete(...args);
      },
    };
  };
  await assert.rejects(s.finish(pending));
  assert.equal(
    s.db.values.get(`storageImageUploads/${pending.assetId}`).state,
    "verified",
  );
  blocked = false;
  const ready = await s.finish(pending);
  assert.equal(ready.state, "ready");
  assert.equal(s.files.has(pending.storagePath), false);
});

test("private reads require current owner/tenant/target authority and verify integrity", async () => {
  const s = setup();
  const pending = await s.reserve();
  s.upload(pending);
  const ready = await s.finish(pending);
  const input = {
    ...s.context,
    auth: auth("r"),
    data: { assetId: ready.assetId },
  };
  const result = await readImage(input);
  assert.equal(result.base64, jpeg.toString("base64"));
  assert.equal(result.url, undefined);
  await denied(readImage({ ...input, auth: auth("other") }));
  s.files.get(ready.storagePath).bytes = Buffer.from("fake");
  await denied(readImage(input), "failed-precondition");
  s.db.values.get("users/r").communityId = "B";
  await denied(readImage(input));
});

test("decodable PNG pixels do not excuse a missing or truncated IEND trailer", async () => {
  const png = await require("sharp")(jpeg).png().toBuffer();
  await validateImageBytes(png, "image/png");
  for (let removed = 1; removed <= 12; removed++) {
    await assert.rejects(
      validateImageBytes(png.subarray(0, png.length - removed), "image/png"),
      (error) => error.code === "invalid-argument",
    );
  }
});
