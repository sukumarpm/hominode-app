// Server-owned apartment gallery attachment and exact-generation retirement.
const { Timestamp, FieldPath } = require("firebase-admin/firestore");
const {
  authority,
  ownedAsset,
  validateAssetRecord,
  publicAsset,
  object,
  documentId,
  fail,
  imagePath,
  objectMetadata,
  verifyObjectMetadata,
} = require("./storage_images");

const photoOwnership = require("./photo_ownership");

const assetRef = (db, id) =>
  db.collection("storageImageUploads").doc(documentId(id));
const imageRef = (db, id, version) =>
  db
    .collection(version === 2 ? "apartmentImagesV2" : "apartmentImages")
    .doc(documentId(id));
const revision = (image) => image.revision ?? 0;
function expectedRevision(value) {
  if (!Number.isSafeInteger(value) || value < 0)
    fail("invalid-argument", "A valid image revision is required.");
}
function text(value, max, required = false) {
  if (
    typeof value !== "string" ||
    value.length > max ||
    (required && !value.trim())
  )
    fail("invalid-argument", "Check the image details and try again.");
  return value;
}
async function adminForImage(context, image) {
  const scope = await authority({
    ...context,
    feature: "apartment",
    ...photoOwnership.binding(image, true),
  });
  if (
    scope.communityId !== image.communityId ||
    (photoOwnership.versioned(image) &&
      !photoOwnership.sameBinding(scope, image))
  )
    fail("permission-denied", "The image is outside the authorized community.");
}
function boundAsset(snapshot, bucket, image, imageId) {
  const asset = validateAssetRecord(snapshot, bucket);
  if (
    asset.feature !== "apartment" ||
    !photoOwnership.sameBinding(asset, image) ||
    asset.communityId !== image.communityId ||
    asset.imageId !== imageId ||
    asset.state !== "ready" ||
    asset.storagePath !== imagePath(asset, true) ||
    image.imageAsset?.assetId !== asset.assetId ||
    image.imageAsset?.generation !== asset.generation
  )
    fail("failed-precondition", "The apartment image reference is invalid.");
  return asset;
}

async function authorizedApartmentRead({
  db,
  bucket,
  auth,
  transaction,
  nowMs,
  snapshot,
}) {
  const asset = snapshot.data();
  const id = documentId(asset.imageId);
  const image = await transaction.get(imageRef(db, id, asset.contractVersion));
  if (!image.exists)
    fail("permission-denied", "This apartment image is unavailable.");
  const value = image.data();
  const admin = await transaction.get(
    db.collection("admins").doc(auth?.uid ?? "_anonymous"),
  );
  const adminProfile = admin.data();
  if (
    admin.exists &&
    adminProfile.uid === auth?.uid &&
    adminProfile.role === "admin" &&
    adminProfile.isActive === true &&
    adminProfile.phoneNumber === auth?.token?.phone_number &&
    adminProfile.authorizedCommunityIds?.includes(value.communityId)
  ) {
    await adminForImage({ db, auth, transaction, nowMs }, value);
  } else {
    const profile = await require("./resident_images").resident({
      db,
      auth,
      transaction,
    });
    if (photoOwnership.versioned(value)) {
      await photoOwnership.residentRead(
        { db, auth, transaction },
        value,
        profile,
      );
      if (value.status !== "active")
        fail("permission-denied", "This photo is unavailable.");
      return boundAsset(snapshot, bucket, value, id);
    }
    const building = await transaction.get(
      db.collection("buildings").doc(value.buildingId),
    );
    if (
      profile.communityId !== value.communityId ||
      value.status !== "active" ||
      !building.exists ||
      building.data().communityId !== value.communityId ||
      ["deleted", "removed"].includes(building.data().status)
    )
      fail("permission-denied", "This apartment image is unavailable.");
  }
  return boundAsset(snapshot, bucket, value, id);
}

async function saveApartmentImageCore({
  db,
  bucket,
  auth,
  data,
  now = Date.now,
}) {
  object(data, [
    "assetId",
    "imageId",
    "expectedRevision",
    "title",
    "description",
    "type",
    "uploadDate",
    "uploadTime",
  ]);
  documentId(data.assetId);
  const replacing = data.imageId != null;
  const id = replacing ? documentId(data.imageId) : data.assetId;
  if (replacing) expectedRevision(data.expectedRevision);
  const result = await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(assetRef(db, data.assetId));
    const asset = ownedAsset(snapshot, auth, bucket);
    if (asset.feature !== "apartment" || asset.state !== "ready")
      fail(
        "failed-precondition",
        "Finalize the apartment image before saving it.",
      );
    const scope = await authority({
      db,
      auth,
      feature: "apartment",
      contractVersion: asset.contractVersion,
      ownershipScope: asset.ownershipScope,
      resourceId: asset.resourceId,
      transaction,
      nowMs: now(),
    });
    if (
      scope.communityId !== asset.communityId ||
      (photoOwnership.versioned(asset) &&
        !photoOwnership.sameBinding(asset, scope))
    )
      fail("permission-denied", "The upload community changed.");
    const existing = await transaction.get(
      imageRef(db, id, asset.contractVersion),
    );
    const image = existing.data();
    if (asset.imageId) {
      if (asset.imageId === id && image?.imageAsset?.assetId === asset.assetId)
        return {
          imageId: id,
          revision: revision(image),
          ...(asset.contractVersion === 2 ? { contractVersion: 2 } : {}),
        };
      fail(
        "failed-precondition",
        "This image upload has already been attached.",
      );
    }
    let old;
    if (replacing) {
      if (!existing.exists)
        fail("not-found", "The apartment image no longer exists.");
      await adminForImage({ db, auth, transaction, nowMs: now() }, image);
      if (revision(image) !== data.expectedRevision)
        fail("aborted", "The image changed. Reload before replacing it.");
      if (
        !photoOwnership.sameBinding(asset, image) ||
        image.communityId !== asset.communityId
      )
        fail(
          "permission-denied",
          "The replacement belongs to another building.",
        );
      if (image.imageAsset)
        old = boundAsset(
          await transaction.get(assetRef(db, image.imageAsset.assetId)),
          bucket,
          image,
          id,
        );
    } else if (existing.exists)
      fail("already-exists", "The image record already exists.");
    const profile = await transaction.get(
      db.collection("admins").doc(auth.uid),
    );
    const timestamp = Timestamp.fromMillis(now());
    const nextRevision = replacing ? revision(image) + 1 : 1;
    const update = {
      imageAsset: publicAsset(asset),
      revision: nextRevision,
      updatedAt: timestamp,
    };
    if (replacing)
      transaction.update(imageRef(db, id, asset.contractVersion), update);
    else
      transaction.create(imageRef(db, id, asset.contractVersion), {
        ...update,
        title: text(data.title, 200, true),
        description: text(data.description, 2000),
        type: text(data.type, 80, true),
        uploadDate: text(data.uploadDate, 40),
        uploadTime: text(data.uploadTime, 40),
        imageUrl: "",
        adminId: auth.uid,
        adminName: profile.data()?.name || "Admin",
        ...(photoOwnership.versioned(asset)
          ? photoOwnership.binding(asset)
          : { buildingId: asset.resourceId }),
        communityId: asset.communityId,
        status: "active",
        createdAt: timestamp,
      });
    transaction.update(assetRef(db, asset.assetId), {
      imageId: id,
      attachedAt: timestamp,
    });
    if (old)
      transaction.update(assetRef(db, old.assetId), {
        state: "retired",
        detachedAt: timestamp,
      });
    return {
      imageId: id,
      revision: nextRevision,
      ...(asset.contractVersion === 2 ? { contractVersion: 2 } : {}),
    };
  });
  // The reference change is committed before any destructive operation. Retired
  // assets are collected by the retryable server sweep, never by a client URL.
  return result;
}

async function deleteApartmentImageCore({
  db,
  bucket,
  auth,
  data,
  now = Date.now,
}) {
  object(data, ["imageId", "expectedRevision", "contractVersion"]);
  if (data.contractVersion !== undefined && data.contractVersion !== 2)
    fail("invalid-argument", "A supported deletion contract is required.");
  const id = documentId(data.imageId);
  expectedRevision(data.expectedRevision);
  return db.runTransaction(async (transaction) => {
    const ref = imageRef(db, id, data.contractVersion);
    const snapshot = await transaction.get(ref);
    const tombstoneRef = db
      .collection("apartmentImageDeletes")
      .doc(data.contractVersion === 2 ? `v2_${id}` : id);
    const tombstone = await transaction.get(tombstoneRef);
    const image = snapshot.exists ? snapshot.data() : tombstone.data();
    if (!image) fail("not-found", "The apartment image no longer exists.");
    await adminForImage({ db, auth, transaction, nowMs: now() }, image);
    if (revision(image) !== data.expectedRevision)
      fail("aborted", "The image changed. Reload before deleting it.");
    if (!snapshot.exists) return { imageId: id, deleted: true };
    let asset;
    if (image.imageAsset)
      asset = boundAsset(
        await transaction.get(assetRef(db, image.imageAsset.assetId)),
        bucket,
        image,
        id,
      );
    const timestamp = Timestamp.fromMillis(now());
    transaction.set(tombstoneRef, {
      communityId: image.communityId,
      ...(photoOwnership.versioned(image)
        ? photoOwnership.binding(image, true)
        : { buildingId: image.buildingId }),
      revision: revision(image),
      deletedAt: timestamp,
    });
    transaction.delete(ref);
    if (asset)
      transaction.update(assetRef(db, asset.assetId), {
        state: "retired",
        detachedAt: timestamp,
      });
    // Legacy objects are never fetched/deleted using a supplied URL.
    return { imageId: id, deleted: true };
  });
}

async function collectApartmentAsset({ db, bucket, assetId, now = Date.now }) {
  const ref = assetRef(db, assetId);
  const asset = await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(ref);
    const value = snapshot.data();
    if (
      !snapshot.exists ||
      value.feature !== "apartment" ||
      value.state === "deleted"
    )
      return null;
    // An attached ready asset is never eligible, even if its uploader is gone.
    if (
      !["retired", "deleting"].includes(value.state) &&
      (value.imageId ||
        !Number.isFinite(value.expiresAtMs) ||
        value.expiresAtMs + 3600000 > now())
    )
      return null;
    if (value.imageId) {
      const image = await transaction.get(
        imageRef(db, value.imageId, value.contractVersion),
      );
      if (image.data()?.imageAsset?.assetId === assetId) return null;
    }
    // Reject malformed server records rather than operating on arbitrary paths.
    validateAssetRecord(snapshot, bucket);
    transaction.update(ref, {
      state: "deleting",
      cleanupStartedAt: Timestamp.fromMillis(now()),
    });
    return value;
  });
  if (!asset) return false;
  for (const privateObject of [false, true]) {
    const path = imagePath(asset, privateObject);
    let metadata;
    try {
      metadata = await objectMetadata(bucket.file(path));
    } catch (error) {
      if (error.code === "not-found") continue;
      throw error;
    }
    const expected = {
      ...asset,
      storagePath: path,
      state: privateObject && asset.generation ? "verified" : "pending",
      generation: privateObject ? asset.generation : asset.uploadGeneration,
    };
    verifyObjectMetadata(metadata, expected);
    await bucket
      .file(path, { generation: String(metadata.generation) })
      .delete({
        ignoreNotFound: true,
        ifGenerationMatch: String(metadata.generation),
      });
  }
  await ref.update({
    state: "deleted",
    deletedAt: Timestamp.fromMillis(now()),
  });
  return true;
}

// Bounded pages with a persisted cursor prevent old attached assets from starving
// newer orphans. No staging namespace listing or financial evidence is touched.
async function cleanupApartmentImagesCore({ db, bucket, now = Date.now }) {
  const cursorRef = db.collection("storageImageMaintenance").doc("apartment");
  const cursor = (await cursorRef.get()).data()?.cursor;
  let query = db
    .collection("storageImageUploads")
    .where("feature", "==", "apartment")
    .orderBy(FieldPath.documentId())
    .limit(100);
  if (cursor) query = query.startAfter(cursor);
  const page = await query.get();
  let deleted = 0,
    failed = 0;
  for (const snapshot of page.docs) {
    try {
      if (
        await collectApartmentAsset({ db, bucket, assetId: snapshot.id, now })
      )
        deleted++;
    } catch (_) {
      failed++;
    } // Retain journal/state for a later sweep; no bytes/URLs in logs.
  }
  await cursorRef.set({
    cursor: page.size === 100 ? page.docs.at(-1).id : null,
    checkedAt: Timestamp.fromMillis(now()),
  });
  return { deleted, failed };
}

module.exports = {
  authorizedApartmentRead,
  saveApartmentImageCore,
  deleteApartmentImageCore,
  collectApartmentAsset,
  cleanupApartmentImagesCore,
};
