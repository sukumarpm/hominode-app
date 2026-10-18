const { randomUUID, createHash } = require("node:crypto");
const { Timestamp, FieldPath } = require("firebase-admin/firestore");
const { hasVerifiedPhoneAuth } = require("./phone_auth");
const { operationalAccessFailure } = require("./resident_identity");
const {
  resolveCommunitySubscriptionCore,
  subscriptionCanUseFeature,
} = require("./subscription_management");
const {
  authority,
  ownedAsset,
  validateAssetRecord,
  publicAsset,
  imagePath,
  verifyObjectMetadata,
  objectMetadata,
  object,
  documentId,
  fail,
} = require("./storage_images");
const policy = {
  profile: { collection: "users", owner: "uid" },
  community_wall: {
    collection: "posts",
    owner: "authorId",
    entitlement: "communityWall",
  },
  complaints: { collection: "complaints", owner: "userId" },
  marketplace: {
    collection: "marketplaces",
    owner: "sellerId",
    entitlement: "marketplace",
  },
};
const reference = (id) => `hominode-image:${id}`;
const assetRef = (db, id) =>
  db.collection("storageImageUploads").doc(documentId(id));
const targetRef = (db, feature, id) => {
  if (!Object.hasOwn(policy, feature))
    fail("invalid-argument", "Unsupported resident image feature.");
  return db.collection(policy[feature].collection).doc(documentId(id));
};
async function resident({ db, auth, transaction }) {
  if (!hasVerifiedPhoneAuth(auth))
    fail("unauthenticated", "Verified phone authentication is required.");
  const snapshot = await transaction.get(db.collection("users").doc(auth.uid));
  const profile = snapshot.data();
  if (
    !snapshot.exists ||
    profile.uid !== auth.uid ||
    profile.phoneNumber !== auth.token.phone_number
  )
    fail("permission-denied", "An active matching resident is required.");
  const community = await transaction.get(
    db.collection("communities").doc(documentId(profile.communityId)),
  );
  if (
    !community.exists ||
    operationalAccessFailure(profile, {
      ...community.data(),
      id: profile.communityId,
    })
  )
    fail("permission-denied", "Resident access is unavailable.");
  return profile;
}
async function entitlement({ db, transaction, feature, communityId, nowMs }) {
  const featureName = policy[feature]?.entitlement;
  if (
    featureName &&
    !subscriptionCanUseFeature(
      await resolveCommunitySubscriptionCore({ db, transaction, communityId }),
      featureName,
      nowMs,
    )
  )
    fail("permission-denied", "This community feature is unavailable.");
}
async function draftAuthority({
  db,
  auth,
  transaction,
  feature,
  resourceId,
  nowMs,
}) {
  const profile = await resident({ db, auth, transaction });
  const snapshot = await transaction.get(
    db.collection("residentImageDrafts").doc(resourceId),
  );
  const draft = snapshot.data();
  if (
    !snapshot.exists ||
    draft.feature !== feature ||
    draft.ownerId !== auth.uid ||
    draft.communityId !== profile.communityId ||
    draft.buildingId !== profile.buildingId ||
    draft.state !== "draft" ||
    draft.expiresAtMs <= nowMs
  )
    fail("permission-denied", "This image draft is unavailable or expired.");
  await entitlement({
    db,
    transaction,
    feature,
    communityId: profile.communityId,
    nowMs,
  });
  return { communityId: profile.communityId, ownerId: auth.uid };
}
async function createResidentImageDraftCore({
  db,
  auth,
  data,
  now = Date.now,
}) {
  object(data, ["feature"]);
  if (!["community_wall", "marketplace"].includes(data.feature))
    fail("invalid-argument", "This feature does not use image drafts.");
  const resourceId = randomUUID();
  return db.runTransaction(async (transaction) => {
    const profile = await resident({ db, auth, transaction });
    const building = await transaction.get(
      db.collection("buildings").doc(documentId(profile.buildingId)),
    );
    if (!building.exists || building.data().communityId !== profile.communityId)
      fail("permission-denied", "The resident building is unavailable.");
    await entitlement({
      db,
      transaction,
      feature: data.feature,
      communityId: profile.communityId,
      nowMs: now(),
    });
    transaction.create(db.collection("residentImageDrafts").doc(resourceId), {
      feature: data.feature,
      ownerId: auth.uid,
      communityId: profile.communityId,
      buildingId: profile.buildingId,
      state: "draft",
      expiresAtMs: now() + 24 * 3600000,
      createdAt: Timestamp.fromMillis(now()),
    });
    return { resourceId };
  });
}
function strings(image, feature) {
  if (feature === "profile")
    return [image.profileImage ?? image.profileImageUrl ?? ""].filter(Boolean);
  if (feature === "marketplace")
    return Array.isArray(image.images) ? image.images : [];
  const list = Array.isArray(image.imageUrls) ? image.imageUrls : [];
  return [
    ...new Set(
      [image.imageUrl, ...list].filter(
        (value) => typeof value === "string" && value,
      ),
    ),
  ];
}
function fields(feature, refs) {
  if (feature === "profile")
    return {
      profileImage: refs[0] ?? "",
      profileImageUrl: refs[0] ?? "",
      photoURL: refs[0] ?? "",
    };
  if (feature === "marketplace") return { images: refs };
  return {
    imageUrl: refs[0] ?? "",
    imageUrls: refs,
  };
}
const bannedKeywords = [
  "sex",
  "porn",
  "escort",
  "xxx",
  "nude",
  "naked",
  "sexual",
  "illegal",
  "crime",
  "criminal",
  "steal",
  "robbery",
  "fraud",
  "drug",
  "cocaine",
  "heroin",
  "meth",
  "weed",
  "marijuana",
  "cannabis",
  "gun",
  "weapon",
  "bomb",
  "explosive",
  "rifle",
  "pistol",
  "knife",
  "kill",
  "murder",
  "violence",
  "violent",
  "assault",
  "attack",
  "hit",
  "scam",
  "fake",
  "fraud",
  "fake id",
  "counterfeit",
  "phishing",
  "hack",
  "hacker",
  "malware",
  "virus",
  "ransomware",
];
function content(data, feature) {
  if (data == null) return {};
  const keys =
    feature === "community_wall"
      ? ["content"]
      : feature === "marketplace"
        ? ["title", "description", "price", "category", "condition"]
        : [];
  object(data, keys);
  for (const [key, value] of Object.entries(data)) {
    if (key === "price") {
      if (!Number.isSafeInteger(value) || value < 0)
        fail("invalid-argument", "Enter a valid price.");
    } else if (
      typeof value !== "string" ||
      value.length > (key === "content" || key === "description" ? 10000 : 200)
    )
      fail("invalid-argument", "Check the content details.");
  }
  const text =
    feature === "community_wall"
      ? (data.content ?? "")
      : `${data.title ?? ""} ${data.description ?? ""}`;
  if (bannedKeywords.some((word) => text.toLowerCase().includes(word)))
    fail(
      "invalid-argument",
      "Your post contains banned keywords or inappropriate language.",
    );
  return data;
}
async function commitResidentImagesCore({
  db,
  bucket,
  auth,
  data,
  now = Date.now,
}) {
  object(data, [
    "feature",
    "resourceId",
    "expectedRevision",
    "operationId",
    "references",
    "content",
    "deleteResource",
  ]);
  const ref = targetRef(db, data.feature, data.resourceId);
  if (
    data.deleteResource !== undefined &&
    typeof data.deleteResource !== "boolean"
  )
    fail("invalid-argument", "A valid deletion operation is required.");
  documentId(data.operationId);
  if (
    !Number.isSafeInteger(data.expectedRevision) ||
    data.expectedRevision < 0 ||
    !Array.isArray(data.references) ||
    data.references.length > 5 ||
    new Set(data.references).size !== data.references.length ||
    data.references.some((v) => typeof v !== "string" || v.length > 2048)
  )
    fail(
      "invalid-argument",
      "A valid image revision and ordered image list are required.",
    );
  if (data.feature === "profile" && data.references.length > 1)
    fail("invalid-argument", "A profile has one image.");
  if (
    data.deleteResource &&
    !["community_wall", "marketplace"].includes(data.feature)
  )
    fail(
      "invalid-argument",
      "This image operation cannot delete the resource.",
    );
  const details = content(data.content, data.feature);
  const fingerprint = createHash("sha256")
    .update(
      JSON.stringify([
        data.feature,
        data.resourceId,
        data.expectedRevision,
        data.references,
        Object.fromEntries(
          Object.keys(details)
            .sort()
            .map((key) => [key, details[key]]),
        ),
        !!data.deleteResource,
      ]),
    )
    .digest("hex");
  return db.runTransaction(async (transaction) => {
    const profile = await resident({ db, auth, transaction });
    const previous = await transaction.get(ref);
    const old = previous.data();
    const operationRef = db
      .collection("residentImageCommits")
      .doc(`${auth.uid}_${data.operationId}`);
    const operation = await transaction.get(operationRef);
    if (operation.exists) {
      const receipt = operation.data();
      if (
        receipt.communityId !== profile.communityId ||
        receipt.fingerprint !== fingerprint
      )
        fail(
          "failed-precondition",
          "The save attempt changed. Reload before trying again.",
        );
      await entitlement({
        db,
        transaction,
        feature: data.feature,
        communityId: profile.communityId,
        nowMs: now(),
      });
      return receipt.result;
    }
    await authority({
      db,
      auth,
      transaction,
      feature: data.feature,
      resourceId: data.resourceId,
      nowMs: now(),
    });
    if ((old?.imageRevision ?? 0) !== data.expectedRevision)
      fail("aborted", "The images changed. Reload before saving.");
    const draftRef = db.collection("residentImageDrafts").doc(data.resourceId);
    await transaction.get(draftRef);
    if (
      !previous.exists &&
      !["community_wall", "marketplace"].includes(data.feature)
    )
      fail("not-found", "The image target is unavailable.");
    if (
      !previous.exists &&
      data.feature === "community_wall" &&
      !details.content?.trim() &&
      !data.references.length
    )
      fail("invalid-argument", "Enter content or add an image.");
    if (
      !previous.exists &&
      data.feature === "marketplace" &&
      (!details.title?.trim() ||
        !Number.isSafeInteger(details.price) ||
        !details.category ||
        !details.condition ||
        details.description == null)
    )
      fail("invalid-argument", "Complete the listing details.");
    const oldAssets = old?.managedImageAssets ?? [];
    const existingRefs = strings(old ?? {}, data.feature);
    const nextAssets = [];
    for (const value of data.references) {
      if (value.startsWith("hominode-image:")) {
        const id = value.slice("hominode-image:".length);
        const asset = ownedAsset(
          await transaction.get(assetRef(db, id)),
          auth,
          bucket,
        );
        if (
          asset.feature !== data.feature ||
          asset.resourceId !== data.resourceId ||
          asset.communityId !== profile.communityId ||
          asset.state !== "ready" ||
          (asset.attachedTo &&
            (asset.attachedTo !== ref.path ||
              !oldAssets.some((a) => a.assetId === id)))
        )
          fail(
            "permission-denied",
            "This image does not belong to this resource.",
          );
        nextAssets.push(asset);
      } else if (!existingRefs.includes(value))
        fail("invalid-argument", "New external image URLs are not accepted.");
    }
    const retired = [];
    for (const value of oldAssets) {
      if (!nextAssets.some((asset) => asset.assetId === value.assetId)) {
        const asset = validateAssetRecord(
          await transaction.get(assetRef(db, value.assetId)),
          bucket,
        );
        if (
          asset.attachedTo !== ref.path ||
          asset.communityId !== profile.communityId ||
          asset.generation !== value.generation
        )
          fail("failed-precondition", "The image attachment is invalid.");
        retired.push(asset);
      }
    }
    const timestamp = Timestamp.fromMillis(now());
    const update = {
      ...fields(data.feature, data.deleteResource ? [] : data.references),
      managedImageAssets: data.deleteResource
        ? []
        : nextAssets.map(publicAsset),
      imageRevision: data.expectedRevision + 1,
      updatedAt: timestamp,
      ...details,
    };
    if (data.feature === "profile") update.profileImageUpdatedAt = timestamp;
    if (data.feature === "complaints") {
      if (old?.attachments != null && !Array.isArray(old.attachments))
        fail(
          "failed-precondition",
          "The existing complaint attachments need review.",
        );
      const legacyAttachments = (old?.attachments ?? []).filter(
        (value) =>
          !oldAssets.some((asset) => reference(asset.assetId) === value),
      );
      Object.assign(update, {
        imageUploadedAt: timestamp,
        imageUploadedBy: auth.uid,
        attachments: [...new Set([...legacyAttachments, ...data.references])],
      });
    }
    if (data.deleteResource) {
      // Keep the minimal ownership record as a deletion tombstone. It is excluded
      // from normal feeds by status and cannot be used to authorize a file read.
      if (data.feature === "community_wall") transaction.delete(ref);
      else transaction.update(ref, { ...update, status: "deleted" });
    } else if (previous.exists) transaction.update(ref, update);
    else {
      const common = {
        ...update,
        communityId: profile.communityId,
        buildingId: profile.buildingId,
        status: "active",
        createdAt: timestamp,
      };
      transaction.create(
        ref,
        data.feature === "community_wall"
          ? {
              ...common,
              authorId: auth.uid,
              authorName: profile.name ?? "Unknown User",
              profileImage: profile.profileImage ?? "",
              flat:
                profile.flatLabel ??
                profile.flatNumber ??
                profile.flatId ??
                "N/A",
              flatId: profile.flatId ?? null,
              flatLabel:
                profile.flatLabel ??
                profile.flatNumber ??
                profile.flatId ??
                "N/A",
              buildingName: profile.buildingName ?? "Unknown Building",
              likes: 0,
              comments: 0,
              likedBy: [],
            }
          : {
              ...common,
              sellerId: auth.uid,
              sellerName: profile.name ?? "Unknown Seller",
              phoneRequestCount: 0,
              phoneRequestIds: [],
            },
      );
      transaction.update(draftRef, {
        state: "published",
        publishedAt: timestamp,
      });
    }
    for (const asset of nextAssets)
      transaction.update(assetRef(db, asset.assetId), {
        attachedTo: ref.path,
        attachedAt: timestamp,
      });
    for (const asset of [
      ...retired,
      ...(data.deleteResource ? nextAssets : []),
    ])
      transaction.update(assetRef(db, asset.assetId), {
        state: "retired",
        detachedAt: timestamp,
      });
    const result = {
      resourceId: data.resourceId,
      imageRevision: update.imageRevision,
      references: data.deleteResource ? [] : data.references,
    };
    transaction.create(operationRef, {
      fingerprint,
      communityId: profile.communityId,
      ownerId: auth.uid,
      result,
      createdAt: timestamp,
    });
    return result;
  });
}
async function authorizedResidentRead({
  db,
  bucket,
  auth,
  transaction,
  nowMs,
  snapshot,
}) {
  let asset = validateAssetRecord(snapshot, bucket);
  // Copied author avatars resolve to the current profile image, rather than
  // retaining obsolete files or exposing a deleted historical profile photo.
  if (asset.feature === "profile" && asset.attachedTo) {
    const owner = await transaction.get(
      db.collection("users").doc(asset.ownerId),
    );
    const pointer = owner.data()?.managedImageAssets?.[0];
    if (!pointer) fail("not-found", "This profile image is unavailable.");
    asset = validateAssetRecord(
      await transaction.get(assetRef(db, pointer.assetId)),
      bucket,
    );
  }
  if (!asset.attachedTo)
    return require("./storage_images").authorizedAsset({
      db,
      bucket,
      auth,
      transaction,
      nowMs,
      assetId: asset.assetId,
    });
  const ref = targetRef(db, asset.feature, asset.resourceId);
  const target = await transaction.get(ref);
  const image = target.data();
  if (
    !target.exists ||
    image.status === "deleted" ||
    asset.state !== "ready" ||
    asset.storagePath !== imagePath(asset, true) ||
    asset.attachedTo !== ref.path ||
    !image.managedImageAssets?.some(
      (a) => a.assetId === asset.assetId && a.generation === asset.generation,
    )
  )
    fail("permission-denied", "This private image is unavailable.");
  let communityId = image.communityId;
  if (!communityId && image.buildingId)
    communityId = (
      await transaction.get(db.collection("buildings").doc(image.buildingId))
    ).data()?.communityId;
  if (image[policy[asset.feature].owner] !== asset.ownerId)
    fail("permission-denied", "The image owner changed.");
  if (communityId !== asset.communityId)
    fail("permission-denied", "The image community changed.");
  const admin = await transaction.get(
    db.collection("admins").doc(auth?.uid ?? "_anonymous"),
  );
  if (
    hasVerifiedPhoneAuth(auth) &&
    admin.exists &&
    admin.data().uid === auth.uid &&
    admin.data().role === "admin" &&
    admin.data().isActive === true &&
    admin.data().phoneNumber === auth.token.phone_number &&
    admin.data().authorizedCommunityIds?.includes(communityId)
  ) {
    const profile = admin.data();
    const community = await transaction.get(
      db.collection("communities").doc(communityId),
    );
    if (
      profile.uid !== auth.uid ||
      profile.phoneNumber !== auth.token.phone_number ||
      profile.role !== "admin" ||
      profile.isActive !== true ||
      !profile.authorizedCommunityIds?.includes(communityId) ||
      community.data()?.isActive !== true
    )
      fail("permission-denied", "Private image access is unavailable.");
  } else {
    const profile = await resident({ db, auth, transaction });
    if (
      profile.communityId !== communityId ||
      (["marketplace"].includes(asset.feature) &&
        asset.ownerId !== auth.uid &&
        profile.buildingId !== image.buildingId) ||
      (asset.feature === "complaints" && image.userId !== auth.uid)
    )
      fail("permission-denied", "Private image access is unavailable.");
    if (asset.feature === "profile") {
      const community = await transaction.get(
        db.collection("communities").doc(communityId),
      );
      if (
        image.communityId !== profile.communityId ||
        operationalAccessFailure(image, {
          ...community.data(),
          id: communityId,
        })
      )
        fail("permission-denied", "This profile image is unavailable.");
    }
  }
  await entitlement({
    db,
    transaction,
    feature: asset.feature,
    communityId,
    nowMs,
  });
  return asset;
}
async function collectResidentAsset({ db, bucket, assetId, now = Date.now }) {
  const ref = assetRef(db, assetId);
  const asset = await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(ref);
    if (!snapshot.exists) return null;
    const value = validateAssetRecord(snapshot, bucket);
    if (!Object.hasOwn(policy, value.feature) || value.state === "deleted")
      return null;
    if (value.attachedTo) {
      const target = await transaction.get(
        targetRef(db, value.feature, value.resourceId),
      );
      if (
        target.data()?.status !== "deleted" &&
        target.data()?.managedImageAssets?.some((a) => a.assetId === assetId)
      )
        return null;
    }
    if (
      !["retired", "deleting"].includes(value.state) &&
      value.expiresAtMs + 3600000 > now()
    )
      return null;
    transaction.update(ref, { state: "deleting" });
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
    if (privateObject) {
      verifyObjectMetadata(metadata, {
        ...asset,
        storagePath: path,
        state: asset.generation ? "verified" : "pending",
        generation: asset.generation,
      });
    } else {
      // Invalid/partial staging content must still be reclaimable. Its private
      // owner namespace and UUID binding, not a valid image payload, authorize
      // quarantine cleanup. Never delete a replacement generation here.
      if (
        metadata.name !== path ||
        !metadata.generation ||
        metadata.metadata?.assetId !== asset.assetId ||
        metadata.metadata?.ownerId !== asset.ownerId ||
        metadata.metadata?.communityId !== asset.communityId
      )
        fail("failed-precondition", "The staging binding is invalid.");
      if (
        asset.uploadGeneration &&
        String(metadata.generation) !== asset.uploadGeneration
      )
        continue;
    }
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
async function cleanupResidentImagesCore({ db, bucket, now = Date.now }) {
  const cursorRef = db.collection("storageImageMaintenance").doc("resident");
  const cursor = (await cursorRef.get()).data()?.cursor;
  let query = db
    .collection("storageImageUploads")
    .orderBy(FieldPath.documentId())
    .limit(100);
  if (cursor) query = query.startAfter(cursor);
  const page = await query.get();
  let deleted = 0,
    failed = 0;
  for (const record of page.docs) {
    try {
      if (
        Object.hasOwn(policy, record.data().feature) &&
        (await collectResidentAsset({ db, bucket, assetId: record.id, now }))
      )
        deleted++;
    } catch (_) {
      failed++;
    }
  }
  await cursorRef.set({
    cursor: page.size === 100 ? page.docs.at(-1).id : null,
    checkedAt: Timestamp.fromMillis(now()),
    deleted,
    failed,
  });
  return { deleted, failed };
}
module.exports = {
  resident,
  draftAuthority,
  createResidentImageDraftCore,
  commitResidentImagesCore,
  authorizedResidentRead,
  collectResidentAsset,
  cleanupResidentImagesCore,
  reference,
};

// Quarantine cleanup covers direct SDK staging writes which have no server
// reservation. Only old canonical resident-image objects are considered; no
// legacy URLs, other prefixes, or financial evidence are listed or touched.
async function cleanupUnreservedResidentStaging({
  db,
  bucket,
  now = Date.now,
}) {
  const cursorRef = db
    .collection("storageImageMaintenance")
    .doc("resident-staging");
  const pageToken = (await cursorRef.get()).data()?.pageToken;
  const [files, next] = await bucket.getFiles({
    prefix: "resident_images/",
    maxResults: 100,
    autoPaginate: false,
    ...(pageToken ? { pageToken } : {}),
  });
  let deleted = 0,
    failed = 0;
  for (const file of files) {
    try {
      const metadata = await objectMetadata(file);
      if (
        !Number.isFinite(Date.parse(metadata.timeCreated)) ||
        Date.parse(metadata.timeCreated) + 24 * 3600000 > now()
      )
        continue;
      const binding = metadata.metadata ?? {};
      const snapshot = await assetRef(db, binding.assetId).get();
      if (
        snapshot.exists &&
        snapshot.data().state === "pending" &&
        snapshot.data().expiresAtMs > now()
      )
        continue;
      const candidate = {
        ...binding,
        assetId: snapshot.id,
        provider: "firebase",
        bucket: bucket.name,
        contentType: metadata.contentType,
        size: Number(metadata.size),
        state: "pending",
        storagePath: metadata.name,
      };
      if (!Object.hasOwn(policy, candidate.feature)) continue;
      validateAssetRecord(
        { exists: true, id: candidate.assetId, data: () => candidate },
        bucket,
      );
      if (candidate.storagePath !== imagePath(candidate, false)) continue;
      if (metadata.name !== imagePath(candidate, false) || !metadata.generation)
        continue;
      await bucket
        .file(metadata.name, { generation: String(metadata.generation) })
        .delete({
          ignoreNotFound: true,
          ifGenerationMatch: String(metadata.generation),
        });
      deleted++;
    } catch (_) {
      failed++;
    }
  }
  await cursorRef.set({
    pageToken: next?.pageToken ?? null,
    checkedAt: Timestamp.fromMillis(now()),
    deleted,
    failed,
  });
  return { deleted, failed };
}
module.exports.cleanupUnreservedResidentStaging =
  cleanupUnreservedResidentStaging;
