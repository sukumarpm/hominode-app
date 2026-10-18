const assert = require("node:assert/strict");
const { Timestamp } = require("firebase-admin/firestore");
const { sosStore: memoryStore } = require("./sos_store");
const {
  prepareStorageImageUploadCore: prepare,
  completeStorageImageUploadCore: complete,
  MAX_IMAGE_BYTES,
} = require("../../src/storage_images");
const phone = "+639170000000";
const auth = (uid) => ({
  uid,
  token: { phone_number: phone, firebase: { sign_in_provider: "phone" } },
});
const nowMs = 1_800_000_000_000;
// Genuine 2x2 JPEG fixture; four-byte JPEG markers are deliberately rejected.
const jpeg = Buffer.from(
  "/9j/2wBDAAYEBQYFBAYGBQYHBwYIChAKCgkJChQODwwQFxQYGBcUFhYaHSUfGhsjHBYWICwgIyYnKSopGR8tMC0oMCUoKSj/2wBDAQcHBwoIChMKChMoGhYaKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCj/wAARCAACAAIDASIAAhEBAxEB/8QAFQABAQAAAAAAAAAAAAAAAAAAAAj/xAAUEAEAAAAAAAAAAAAAAAAAAAAA/8QAFAEBAAAAAAAAAAAAAAAAAAAAAP/EABQRAQAAAAAAAAAAAAAAAAAAAAD/2gAMAwEAAhEDEQA/AKpAB//Z",
  "base64",
);
const targets = {
  apartment: ["a", "b"],
  profile: ["r", "r"],
  community_wall: ["r", "p"],
  complaints: ["r", "c"],
  marketplace: ["r", "m"],
};

function setup() {
  const db = memoryStore();
  const resident = {
    uid: "r",
    phoneNumber: phone,
    role: "resident",
    isActive: true,
    communityId: "A",
    buildingId: "b",
    approvalStatus: "approved",
    status: "active",
    residentType: "owner",
    ownershipType: "owner",
    identityVerificationStatus: "not_required",
    profileImage: "https://example.invalid/existing-profile.jpg",
    createdBy: "a",
  };
  const seed = {
    "communities/A": { isActive: true },
    "communities/B": { isActive: true },
    "admins/a": {
      uid: "a",
      phoneNumber: phone,
      role: "admin",
      isActive: true,
      authorizedCommunityIds: ["A"],
    },
    "users/r": resident,
    "users/other": { ...resident, uid: "other" },
    "buildings/b": { communityId: "A" },
    "posts/p": { communityId: "A", authorId: "r", status: "active" },
    "complaints/c": {
      communityId: "A",
      userId: "r",
      imageUrl: "https://example.invalid/existing.jpg",
    },
    "marketplaces/m": {
      communityId: "A",
      sellerId: "r",
      status: "active",
      images: ["existing"],
    },
    "subscriptions/A": {
      planId: "plus",
      status: "active",
      startsAt: Timestamp.fromMillis(0),
    },
  };
  for (const [path, value] of Object.entries(seed)) db.values.set(path, value);
  const files = new Map();
  let reads = 0;
  const bucket = {
    name: "demo-images.appspot.com",
    file(path, options) {
      return {
        async getMetadata() {
          reads++;
          if (!files.has(path))
            throw Object.assign(new Error("missing"), { code: 404 });
          return [files.get(path).metadata];
        },
        async download(range) {
          reads++;
          assert.equal(options.generation, files.get(path).metadata.generation);
          assert.equal(range.end, MAX_IMAGE_BYTES);
          assert.equal(range.decompress, false);
          return [files.get(path).bytes];
        },
        async save(bytes, options) {
          assert.equal(options.preconditionOpts.ifGenerationMatch, 0);
          if (files.has(path))
            throw Object.assign(new Error("already exists"), { code: 412 });
          files.set(path, {
            bytes: Buffer.from(bytes),
            metadata: {
              name: path,
              size: bytes.length,
              generation: "9",
              metageneration: "1",
              ...options.metadata,
            },
          });
        },
        async delete(precondition) {
          if (!files.has(path) && precondition.ignoreNotFound) return;
          assert.equal(
            precondition.ifGenerationMatch,
            files.get(path).metadata.generation,
          );
          files.delete(path);
        },
      };
    },
  };
  const context = { db, bucket, now: () => nowMs };
  const reserve = (feature = "profile", overrides = {}) =>
    prepare({
      ...context,
      auth: auth(targets[feature][0]),
      data: {
        feature,
        resourceId: targets[feature][1],
        contentType: "image/jpeg",
        size: jpeg.length,
      },
      ...overrides,
    });
  function upload(asset, options = {}) {
    files.set(asset.storagePath, {
      bytes: jpeg,
      metadata: {
        name: asset.storagePath,
        generation: "7",
        metageneration: "1",
        size: jpeg.length,
        contentType: "image/jpeg",
        metadata: {
          assetId: asset.assetId,
          ownerId: asset.ownerId,
          communityId: asset.communityId,
          feature: asset.feature,
          resourceId: asset.resourceId,
          firebaseStorageDownloadTokens: "synthetic-only",
        },
        ...options,
      },
    });
  }
  const finish = (asset, overrides = {}) =>
    complete({
      ...context,
      auth: auth(asset.ownerId),
      data: { assetId: asset.assetId },
      ...overrides,
    });
  return {
    db,
    files,
    bucket,
    reserve,
    upload,
    finish,
    context,
    reads: () => reads,
  };
}

module.exports = { setup, auth, nowMs, jpeg, targets, phone };
