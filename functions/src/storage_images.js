// Private staging/finalization foundation. Domain image fields are deliberately
// not changed here: Phase 2 attaches ready references through feature services.
const { randomUUID, createHash } = require("node:crypto");
const sharp = require("sharp");
// One image decode per callable instance; bound libvips' retained cache/workers.
sharp.cache({ memory: 16, files: 0, items: 16 });
sharp.concurrency(1);
const { Timestamp } = require("firebase-admin/firestore");
const { RegistrationError } = require("./register_resident");
const { hasVerifiedPhoneAuth } = require("./phone_auth");
const { operationalAccessFailure } = require("./resident_identity");
const {
  resolveCommunitySubscriptionCore,
  subscriptionCanUseFeature,
} = require("./subscription_management");

const photoOwnership = require("./photo_ownership");

const MAX_IMAGE_BYTES = 10 * 1024 * 1024;
const UPLOAD_LIFETIME_MS = 15 * 60 * 1000;
const FEATURES = Object.freeze({
  apartment: { role: "admin", collection: "buildings" },
  profile: { role: "resident", collection: "users", owner: "uid" },
  community_wall: {
    role: "resident",
    collection: "posts",
    owner: "authorId",
    entitlement: "communityWall",
  },
  complaints: { role: "resident", collection: "complaints", owner: "userId" },
  marketplace: {
    role: "resident",
    collection: "marketplaces",
    owner: "sellerId",
    entitlement: "marketplace",
  },
});
const EXTENSIONS = Object.freeze({
  "image/jpeg": "jpg",
  "image/png": "png",
  "image/webp": "webp",
  "image/gif": "gif",
});
const UUID =
  /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/;

function fail(code, message) {
  throw new RegistrationError(code, message);
}
function object(data, keys) {
  if (
    !data ||
    typeof data !== "object" ||
    Array.isArray(data) ||
    Object.keys(data).some((key) => !keys.includes(key))
  ) {
    fail(
      "invalid-argument",
      "Only the documented image upload fields are accepted.",
    );
  }
}
function documentId(value) {
  if (
    typeof value !== "string" ||
    !value ||
    value !== value.trim() ||
    value.length > 128 ||
    /[\/\u0000-\u001f\u007f]/.test(value) ||
    [".", ".."].includes(value)
  ) {
    fail("invalid-argument", "A valid image resource ID is required.");
  }
  return value;
}
function imageType(feature, contentType, size) {
  if (
    !Object.hasOwn(FEATURES, feature) ||
    !Object.hasOwn(EXTENSIONS, contentType) ||
    (contentType === "image/gif" &&
      !["profile", "community_wall"].includes(feature)) ||
    !Number.isSafeInteger(size) ||
    size < 1 ||
    size > MAX_IMAGE_BYTES
  ) {
    fail("invalid-argument", "Choose a supported image no larger than 10 MB.");
  }
}
function imagePath(asset, privateObject = asset.state !== "pending") {
  const file = `${asset.assetId}.${EXTENSIONS[asset.contentType]}`;
  if (privateObject)
    return `private_images/${asset.communityId}/${asset.ownerId}/${asset.feature}/${file}`;
  return asset.feature === "apartment"
    ? `apartment_images/${asset.communityId}/${asset.ownerId}/${file}`
    : `resident_images/${asset.communityId}/${asset.ownerId}/${asset.feature}/${file}`;
}
function publicAsset(asset) {
  return Object.fromEntries(
    [
      "assetId",
      "contractVersion",
      "ownershipScope",
      "buildingId",
      "unitId",
      "provider",
      "bucket",
      "storagePath",
      "communityId",
      "ownerId",
      "feature",
      "resourceId",
      "contentType",
      "size",
      "state",
      "expiresAtMs",
      "generation",
      "sha256",
    ]
      .filter((key) => asset[key] !== undefined)
      .map((key) => [key, asset[key]]),
  );
}

async function authority({
  db,
  auth,
  feature,
  resourceId,
  contractVersion,
  ownershipScope,
  transaction,
  nowMs,
}) {
  if (!hasVerifiedPhoneAuth(auth))
    fail("unauthenticated", "Verified phone authentication is required.");
  if (!Object.hasOwn(FEATURES, feature))
    fail("invalid-argument", "This image feature is not supported.");
  if (contractVersion !== undefined || ownershipScope !== undefined) {
    photoOwnership.requestScope({
      feature,
      resourceId,
      contractVersion,
      ownershipScope,
    });
    return photoOwnership.photoAuthority({
      db,
      auth,
      transaction,
      ownershipScope,
      resourceId,
    });
  }
  const policy = FEATURES[feature];
  const read = (ref) => transaction.get(ref);
  const profileRef = db
    .collection(policy.role === "admin" ? "admins" : "users")
    .doc(auth.uid);
  const profileSnapshot = await read(profileRef);
  const profile = profileSnapshot.data();
  if (
    !profileSnapshot.exists ||
    profile?.uid !== auth.uid ||
    profile.role !== policy.role ||
    profile.phoneNumber !== auth.token.phone_number ||
    profile.isActive !== true
  ) {
    fail("permission-denied", "An active matching image uploader is required.");
  }
  const targetSnapshot = await read(
    db.collection(policy.collection).doc(documentId(resourceId)),
  );
  const target = targetSnapshot.data();
  if (!targetSnapshot.exists) {
    if (["community_wall", "marketplace"].includes(feature))
      return require("./resident_images").draftAuthority({
        db,
        auth,
        transaction,
        feature,
        resourceId,
        nowMs,
      });
    fail("not-found", "The image target does not exist.");
  }
  if (policy.owner) {
    // Reject conflicting legacy ownership aliases rather than choosing one.
    const owners = [
      "uid",
      "authorId",
      "userId",
      "residentId",
      "ownerId",
      "sellerId",
      "firebaseAuthUid",
      "createdBy",
    ];
    if (
      target[policy.owner] !== auth.uid ||
      (feature !== "profile" &&
        owners.some(
          (key) =>
            target[key] != null &&
            target[key] !== "" &&
            target[key] !== auth.uid,
        ))
    ) {
      fail(
        "permission-denied",
        "The image target belongs to another resident.",
      );
    }
  }
  if (["deleted", "removed", "rejected"].includes(target.status))
    fail("failed-precondition", "The image target is unavailable.");
  let communityId = target.communityId;
  // Existing wall/marketplace records may carry only a building ID.
  if (
    !communityId &&
    target.buildingId &&
    ["community_wall", "marketplace"].includes(feature)
  ) {
    const building = await read(
      db.collection("buildings").doc(documentId(target.buildingId)),
    );
    communityId = building.data()?.communityId;
  }
  documentId(communityId);
  const communitySnapshot = await read(
    db.collection("communities").doc(communityId),
  );
  const community = { ...communitySnapshot.data(), id: communityId };
  if (!communitySnapshot.exists || community.isActive !== true)
    fail("permission-denied", "The community is inactive.");
  if (policy.role === "admin") {
    if (
      !Array.isArray(profile.authorizedCommunityIds) ||
      !profile.authorizedCommunityIds.includes(communityId)
    ) {
      fail(
        "permission-denied",
        "The image target is outside the authorized community.",
      );
    }
  } else if (operationalAccessFailure(profile, community)) {
    fail(
      "permission-denied",
      "Resident access to this community is unavailable.",
    );
  }
  if (policy.entitlement) {
    const entitlement = await resolveCommunitySubscriptionCore({
      db,
      communityId,
      transaction,
    });
    if (!subscriptionCanUseFeature(entitlement, policy.entitlement, nowMs)) {
      fail(
        "permission-denied",
        "The image feature is unavailable for this community.",
      );
    }
  }
  return { communityId, ownerId: auth.uid };
}

async function prepareStorageImageUploadCore({
  db,
  bucket,
  auth,
  data,
  now = Date.now,
}) {
  object(data, [
    "feature",
    "resourceId",
    "contentType",
    "size",
    "contractVersion",
    "ownershipScope",
  ]);
  const ownership = photoOwnership.requestScope(data);
  imageType(data.feature, data.contentType, data.size);
  if (!bucket?.name)
    fail("failed-precondition", "Image storage is unavailable.");
  const assetId = randomUUID();
  const nowMs = now();
  return db.runTransaction(async (transaction) => {
    const scope = await authority({
      db,
      auth,
      feature: data.feature,
      ...ownership,
      resourceId: data.resourceId,
      transaction,
      nowMs,
    });
    let quotaRef, quota;
    if (data.feature !== "apartment") {
      quotaRef = db.collection("storageImageQuotas").doc(auth.uid);
      const snapshot = await transaction.get(quotaRef);
      quota = snapshot.data();
      quota =
        quota && nowMs - quota.windowStartMs < 15 * 60 * 1000
          ? quota
          : { windowStartMs: nowMs, count: 0 };
      if (quota.count >= 30)
        fail(
          "resource-exhausted",
          "Too many image upload attempts. Try again later.",
        );
    }
    const asset = {
      assetId,
      provider: "firebase",
      bucket: bucket.name,
      ...scope,
      feature: data.feature,
      resourceId: data.resourceId,
      contentType: data.contentType,
      size: data.size,
      state: "pending",
      createdAt: Timestamp.fromMillis(nowMs),
      expiresAtMs: nowMs + UPLOAD_LIFETIME_MS,
    };
    asset.storagePath = imagePath(asset);
    transaction.create(
      db.collection("storageImageUploads").doc(assetId),
      asset,
    );
    if (quotaRef)
      transaction.set(quotaRef, { ...quota, count: quota.count + 1 });
    return publicAsset(asset);
  });
}

function validateAssetRecord(snapshot, bucket) {
  const asset = snapshot.data();
  if (!snapshot.exists)
    fail("permission-denied", "This image upload is unavailable.");
  imageType(asset.feature, asset.contentType, asset.size);
  if (photoOwnership.versioned(asset)) {
    if (asset.feature !== "apartment")
      fail("failed-precondition", "Invalid scoped image feature.");
    photoOwnership.binding(asset);
  }
  if (
    !UUID.test(asset.assetId) ||
    asset.assetId !== snapshot.id ||
    asset.bucket !== bucket.name ||
    ![imagePath(asset, false), imagePath(asset, true)].includes(
      asset.storagePath,
    )
  )
    fail("failed-precondition", "The image upload record is invalid.");
  return asset;
}
function ownedAsset(snapshot, auth, bucket) {
  if (!hasVerifiedPhoneAuth(auth))
    fail("unauthenticated", "Verified phone authentication is required.");
  const asset = validateAssetRecord(snapshot, bucket);
  if (asset.ownerId !== auth.uid)
    fail("permission-denied", "This image upload is unavailable.");
  if (asset.storagePath !== imagePath(asset))
    fail("failed-precondition", "The image upload record is invalid.");
  return asset;
}

// Validate a fully decodable image, not just a plausible header. Sharp/libvips
// applies input-pixel limits before decoding; animated assets are rejected.
const MAX_IMAGE_PIXELS = 40_000_000;
async function validateImageBytes(bytes, contentType) {
  const formats = {
    "image/jpeg": "jpeg",
    "image/png": "png",
    "image/gif": "gif",
    "image/webp": "webp",
  };
  if (
    !Buffer.isBuffer(bytes) ||
    bytes.length < 1 ||
    bytes.length > MAX_IMAGE_BYTES ||
    !Object.hasOwn(formats, contentType)
  ) {
    fail("invalid-argument", "Choose a supported image no larger than 10 MB.");
  }
  // Reject non-image parsers (notably SVG/PDF) before handing untrusted bytes
  // to libvips. The decoder still verifies the actual format and pixel data.
  const signature = {
    "image/jpeg":
      bytes.length >= 3 &&
      bytes[0] === 255 &&
      bytes[1] === 216 &&
      bytes[2] === 255,
    "image/png":
      bytes
        .subarray(0, 8)
        .equals(Buffer.from([137, 80, 78, 71, 13, 10, 26, 10])) &&
      bytes
        .subarray(-12)
        .equals(Buffer.from("0000000049454e44ae426082", "hex")),
    "image/gif": ["GIF87a", "GIF89a"].includes(bytes.toString("ascii", 0, 6)),
    "image/webp":
      bytes.toString("ascii", 0, 4) === "RIFF" &&
      bytes.toString("ascii", 8, 12) === "WEBP",
  };
  if (!signature[contentType])
    fail("invalid-argument", "The image content does not match its type.");
  try {
    const options = {
      failOn: "warning",
      limitInputPixels: MAX_IMAGE_PIXELS,
      animated: false,
      pages: 1,
    };
    const metadata = await sharp(bytes, options).metadata();
    const width = metadata.width;
    const height = metadata.height;
    if (
      metadata.format !== formats[contentType] ||
      !Number.isSafeInteger(width) ||
      !Number.isSafeInteger(height) ||
      width < 1 ||
      height < 1 ||
      width * height > MAX_IMAGE_PIXELS ||
      (metadata.pages || 1) !== 1 ||
      (metadata.pageHeight && metadata.pageHeight !== height)
    ) {
      fail("invalid-argument", "The image content does not match its type.");
    }
    // Metadata is not proof of a valid image. Force a decode and reject
    // truncated/corrupt data without materializing a full-resolution bitmap.
    await sharp(bytes, options)
      .timeout({ seconds: 10 })
      .resize(1, 1, { fit: "inside", withoutEnlargement: true })
      .raw()
      .toBuffer();
  } catch (error) {
    if (error?.code === "invalid-argument") throw error;
    fail("invalid-argument", "The image is invalid or cannot be decoded.");
  }
}

async function authorizedAsset({
  db,
  bucket,
  auth,
  assetId,
  nowMs,
  transaction,
}) {
  const asset = ownedAsset(
    await transaction.get(db.collection("storageImageUploads").doc(assetId)),
    auth,
    bucket,
  );
  const scope = await authority({
    db,
    auth,
    feature: asset.feature,
    contractVersion: asset.contractVersion,
    ownershipScope: asset.ownershipScope,
    resourceId: asset.resourceId,
    transaction,
    nowMs,
  });
  if (
    scope.communityId !== asset.communityId ||
    (photoOwnership.versioned(asset) &&
      !photoOwnership.sameBinding(asset, scope)) ||
    !["pending", "verified", "ready"].includes(asset.state) ||
    (asset.state === "pending" && asset.expiresAtMs <= nowMs)
  ) {
    fail(
      "permission-denied",
      "This image upload authorization has expired or changed.",
    );
  }
  return asset;
}
function binding(asset) {
  return {
    ...(photoOwnership.versioned(asset) &&
    asset.storagePath === imagePath(asset, true)
      ? { contractVersion: "2", ownershipScope: asset.ownershipScope }
      : {}),
    assetId: asset.assetId,
    ownerId: asset.ownerId,
    communityId: asset.communityId,
    feature: asset.feature,
    resourceId: asset.resourceId,
  };
}
async function objectMetadata(file) {
  try {
    return (await file.getMetadata())[0];
  } catch (error) {
    if (Number(error.code) === 404)
      fail("not-found", "The uploaded image is missing.");
    throw error;
  }
}
function verifyObjectMetadata(metadata, asset) {
  if (
    metadata.name !== asset.storagePath ||
    !metadata.generation ||
    metadata.contentEncoding ||
    Number(metadata.size) !== asset.size ||
    metadata.contentType !== asset.contentType ||
    Object.entries(binding(asset)).some(
      ([key, value]) => metadata.metadata?.[key] !== value,
    ) ||
    (asset.generation && asset.generation !== String(metadata.generation))
  ) {
    fail(
      "failed-precondition",
      "The uploaded image does not match its reservation.",
    );
  }
  if (
    asset.state !== "pending" &&
    (metadata.metadata?.sha256 !== asset.sha256 ||
      metadata.metadata?.firebaseStorageDownloadTokens)
  ) {
    fail("failed-precondition", "The private image metadata is invalid.");
  }
}
async function downloadBounded(bucket, asset, generation) {
  const [bytes] = await bucket
    .file(asset.storagePath, { generation })
    .download({ start: 0, end: MAX_IMAGE_BYTES, decompress: false });
  if (bytes.length !== asset.size)
    fail("failed-precondition", "The uploaded image has an invalid size.");
  return bytes;
}

async function completeStorageImageUploadCore({
  db,
  bucket,
  auth,
  data,
  now = Date.now,
}) {
  object(data, ["assetId"]);
  if (!UUID.test(data.assetId))
    fail("invalid-argument", "A valid image upload ID is required.");
  const context = { db, bucket, auth, assetId: data.assetId };
  const ref = db.collection("storageImageUploads").doc(data.assetId);
  let asset = await db.runTransaction((transaction) =>
    authorizedAsset({ ...context, transaction, nowMs: now() }),
  );
  const sourceMetadata = await objectMetadata(bucket.file(asset.storagePath));
  verifyObjectMetadata(sourceMetadata, asset);
  if (asset.state === "pending") {
    const bytes = await downloadBounded(
      bucket,
      asset,
      sourceMetadata.generation,
    );
    await validateImageBytes(bytes, asset.contentType);
    const privateAsset = {
      ...asset,
      state: "verified",
      storagePath: imagePath(asset, true),
      sha256: createHash("sha256").update(bytes).digest("hex"),
      uploadPath: asset.storagePath,
      uploadGeneration: String(sourceMetadata.generation),
    };
    const privateFile = bucket.file(privateAsset.storagePath);
    try {
      // GCS/Admin API save does not mint a Firebase download token. Clients have
      // no access to this prefix, including metadata/getDownloadURL requests.
      await privateFile.save(bytes, {
        resumable: false,
        preconditionOpts: { ifGenerationMatch: 0 },
        metadata: {
          contentType: asset.contentType,
          cacheControl: "private, no-store",
          metadata: { ...binding(privateAsset), sha256: privateAsset.sha256 },
        },
      });
    } catch (error) {
      // Concurrent/retried verification may already have created this exact
      // immutable object. Verify its binding and hash instead of overwriting it.
      if (![409, 412].includes(Number(error.code))) throw error;
    }
    const privateMetadata = await objectMetadata(privateFile);
    verifyObjectMetadata(privateMetadata, privateAsset);
    privateAsset.generation = String(privateMetadata.generation);
    asset = await db.runTransaction(async (transaction) => {
      const current = await authorizedAsset({
        ...context,
        transaction,
        nowMs: now(),
      });
      if (current.state !== "pending") {
        if (
          current.generation !== privateAsset.generation ||
          current.sha256 !== privateAsset.sha256
        ) {
          fail(
            "failed-precondition",
            "Image verification changed concurrently.",
          );
        }
        return current;
      }
      transaction.update(ref, {
        ...privateAsset,
        verifiedAt: Timestamp.fromMillis(now()),
      });
      return privateAsset;
    });
  }
  if (asset.state === "ready") return publicAsset(asset);
  // No ready reference is returned while an SDK-created, token-bearing staging
  // copy remains. A failed delete leaves a retryable server-owned verified state.
  if (asset.uploadPath !== imagePath(asset, false) || !asset.uploadGeneration) {
    fail("failed-precondition", "The image staging reference is invalid.");
  }
  await bucket
    .file(asset.uploadPath, { generation: asset.uploadGeneration })
    .delete({
      ignoreNotFound: true,
      ifGenerationMatch: asset.uploadGeneration,
    });
  return db.runTransaction(async (transaction) => {
    const current = await authorizedAsset({
      ...context,
      transaction,
      nowMs: now(),
    });
    if (
      current.generation !== asset.generation ||
      current.sha256 !== asset.sha256 ||
      current.state === "pending"
    ) {
      fail("failed-precondition", "Image verification changed concurrently.");
    }
    transaction.update(ref, {
      state: "ready",
      readyAt: Timestamp.fromMillis(now()),
    });
    return publicAsset({ ...current, state: "ready" });
  });
}

async function readStorageImageCore({
  db,
  bucket,
  auth,
  data,
  now = Date.now,
}) {
  object(data, ["assetId", "knownGeneration", "knownAssetId"]);
  if (
    data.knownGeneration !== undefined &&
    (typeof data.knownGeneration !== "string" ||
      !/^[0-9]+$/.test(data.knownGeneration))
  )
    fail("invalid-argument", "A valid cached image generation is required.");
  if (!UUID.test(data.assetId))
    fail("invalid-argument", "A valid image upload ID is required.");
  if (data.knownAssetId !== undefined && !UUID.test(data.knownAssetId))
    fail("invalid-argument", "A valid cached image ID is required.");
  const context = { db, bucket, auth, assetId: data.assetId };
  const authorizeRead = async (transaction) => {
    const snapshot = await transaction.get(
      db.collection("storageImageUploads").doc(data.assetId),
    );
    if (snapshot.data()?.feature === "apartment" && snapshot.data()?.imageId) {
      return require("./apartment_images").authorizedApartmentRead({
        ...context,
        transaction,
        nowMs: now(),
        snapshot,
      });
    }
    if (
      snapshot.data()?.feature !== "apartment" &&
      snapshot.data()?.attachedTo
    ) {
      return require("./resident_images").authorizedResidentRead({
        ...context,
        transaction,
        nowMs: now(),
        snapshot,
      });
    }
    return authorizedAsset({ ...context, transaction, nowMs: now() });
  };
  const asset = await db.runTransaction(authorizeRead);
  if (asset.state !== "ready")
    fail("failed-precondition", "The image is not ready.");
  const metadata = await objectMetadata(bucket.file(asset.storagePath));
  verifyObjectMetadata(metadata, asset);
  let bytes;
  if (
    data.knownGeneration !== asset.generation ||
    (data.knownAssetId && data.knownAssetId !== asset.assetId)
  ) {
    bytes = await downloadBounded(bucket, asset, asset.generation);
    if (createHash("sha256").update(bytes).digest("hex") !== asset.sha256)
      fail("failed-precondition", "Image integrity verification failed.");
  }
  // Recheck access after I/O; no read URL, file path override or bearer token.
  const current = await db.runTransaction(authorizeRead);
  if (
    current.state !== "ready" ||
    current.assetId !== asset.assetId ||
    current.generation !== asset.generation ||
    current.sha256 !== asset.sha256
  ) {
    fail("permission-denied", "Image access changed during the read.");
  }
  return {
    assetId: asset.assetId,
    contentType: asset.contentType,
    size: asset.size,
    generation: asset.generation,
    asset: publicAsset(asset),
    ...(asset.assetId !== data.assetId ? { redirectedFrom: data.assetId } : {}),
    ...(bytes ? { base64: bytes.toString("base64") } : { notModified: true }),
  };
}

module.exports = {
  MAX_IMAGE_BYTES,
  FEATURES,
  imagePath,
  validateImageBytes,
  prepareStorageImageUploadCore,
  completeStorageImageUploadCore,
  readStorageImageCore,
  authority,
  authorizedAsset,
  ownedAsset,
  validateAssetRecord,
  publicAsset,
  object,
  documentId,
  fail,
  objectMetadata,
  verifyObjectMetadata,
  downloadBounded,
};
