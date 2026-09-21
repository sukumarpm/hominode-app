const crypto = require("node:crypto");
const {FieldValue} = require("firebase-admin/firestore");
const {RegistrationError} = require("./register_resident");

const NOTIFICATION_CHANNEL_ID = "hominode_high_importance";
const DEVICE_COLLECTION = "notificationDevices";
const NOTIFICATION_COLLECTION = "notifications";

const APP_CONTEXTS = Object.freeze({
  "1:551984029668:android:ef652ea4d8e070ca0db1f1": {
    appId: "resident",
    platform: "android",
    role: "resident",
  },
  "1:551984029668:ios:cb57ef578d5066b50db1f1": {
    appId: "resident",
    platform: "ios",
    role: "resident",
  },
  "1:551984029668:android:322fd085a03f0ff70db1f1": {
    appId: "admin",
    platform: "android",
    role: "admin",
  },
  "1:551984029668:ios:c385b8730137f2710db1f1": {
    appId: "admin",
    platform: "ios",
    role: "admin",
  },
  "1:551984029668:web:5845083359a375d90db1f1": {
    appId: "admin",
    platform: "web",
    role: "admin",
  },
  "1:551984029668:android:93f99854319c9f9a0db1f1": {
    appId: "security",
    platform: "android",
    role: "security",
  },
  "1:551984029668:ios:7063832b4b5d53fc0db1f1": {
    appId: "security",
    platform: "ios",
    role: "security",
  },
});

const ALLOWED_CATEGORIES = new Set([
  "visitor",
  "complaint",
  "payment",
  "maintenance",
  "announcement",
  "event",
  "security",
  "general",
]);
const ALLOWED_PRIORITIES = new Set(["low", "medium", "high", "urgent"]);
const STALE_TOKEN_CODES = new Set([
  "messaging/registration-token-not-registered",
  "messaging/invalid-registration-token",
]);

function normalizedString(value) {
  return typeof value === "string" ? value.trim() : "";
}

function requireAuthenticated(auth) {
  if (!auth?.uid) {
    throw new RegistrationError("unauthenticated", "Authentication is required.");
  }
  return auth.uid;
}

function requireAppContext(app) {
  const firebaseAppId = normalizedString(app?.appId);
  const context = Object.hasOwn(APP_CONTEXTS, firebaseAppId) ? APP_CONTEXTS[firebaseAppId] : null;
  if (!context) {
    throw new RegistrationError(
      "failed-precondition",
      "This Firebase application is not authorized for notifications.",
    );
  }
  return {...context, firebaseAppId};
}

function requireInstallationId(value) {
  const installationId = normalizedString(value);
  if (!/^[A-Za-z0-9_-]{16,128}$/.test(installationId)) {
    throw new RegistrationError("invalid-argument", "A valid installation ID is required.");
  }
  return installationId;
}

function requireToken(value) {
  const token = normalizedString(value);
  if (token.length < 20 || token.length > 4096 || /\s/.test(token)) {
    throw new RegistrationError("invalid-argument", "A valid FCM token is required.");
  }
  return token;
}

function notificationDeviceId(appId, uid, installationId) {
  return crypto
    .createHash("sha256")
    .update(`${appId}|${uid}|${installationId}`)
    .digest("hex")
    .slice(0, 48);
}

function notificationAudienceKey({appId, role, communityId, uid}) {
  return `${appId}|${role}|${communityId}|${uid}`;
}

async function requireActiveCommunity(db, communityId) {
  const snapshot = await db.collection("communities").doc(communityId).get();
  if (!snapshot.exists || snapshot.data()?.isActive !== true) {
    throw new RegistrationError(
      "failed-precondition",
      "The assigned community is unavailable.",
    );
  }
}

async function resolveDeviceAuthority({db, auth, appContext, data}) {
  const uid = requireAuthenticated(auth);
  let profile;
  let communityId;

  if (appContext.role === "resident") {
    const snapshot = await db.collection("users").doc(uid).get();
    profile = snapshot.data();
    communityId = normalizedString(profile?.communityId);
    if (!snapshot.exists || profile?.uid !== uid || profile?.role !== "resident" ||
        profile?.approvalStatus !== "approved" || profile?.isActive !== true ||
        (profile?.status != null && profile.status !== "active") || !communityId) {
      throw new RegistrationError(
        "permission-denied",
        "An active approved Resident profile is required.",
      );
    }
  } else if (appContext.role === "security") {
    const snapshot = await db.collection("securityStaff").doc(uid).get();
    profile = snapshot.data();
    communityId = normalizedString(profile?.communityId);
    if (!snapshot.exists || profile?.uid !== uid || profile?.role !== "security" ||
        profile?.isActive !== true || !communityId) {
      throw new RegistrationError(
        "permission-denied",
        "An active Security profile is required.",
      );
    }
  } else {
    const snapshot = await db.collection("admins").doc(uid).get();
    profile = snapshot.data();
    const authorized = Array.isArray(profile?.authorizedCommunityIds) ?
      profile.authorizedCommunityIds.map(normalizedString).filter(Boolean) : [];
    const selected = normalizedString(data?.selectedCommunityId);
    if (!snapshot.exists || profile?.uid !== uid || profile?.role !== "admin" ||
        profile?.isActive !== true || authorized.length === 0) {
      throw new RegistrationError(
        "permission-denied",
        "An active Admin profile is required.",
      );
    }
    if (authorized.length === 1) {
      communityId = authorized[0];
      if (selected && selected !== communityId) {
        throw new RegistrationError(
          "permission-denied",
          "The selected community is not authorized for this Admin.",
        );
      }
    } else {
      if (!selected || !authorized.includes(selected)) {
        throw new RegistrationError(
          "failed-precondition",
          "Select an authorized community before enabling notifications.",
        );
      }
      communityId = selected;
    }
  }

  await requireActiveCommunity(db, communityId);
  return {uid, communityId, role: appContext.role};
}

async function registerNotificationDeviceCore({db, auth, app, data}) {
  const appContext = requireAppContext(app);
  const installationId = requireInstallationId(data?.installationId);
  const token = requireToken(data?.token);
  const authority = await resolveDeviceAuthority({db, auth, appContext, data});
  const deviceId = notificationDeviceId(
    appContext.appId,
    authority.uid,
    installationId,
  );
  const deviceRef = db.collection(DEVICE_COLLECTION).doc(deviceId);
  const duplicates = await db
    .collection(DEVICE_COLLECTION)
    .where("token", "==", token)
    .get();
  const batch = db.batch();

  for (const duplicate of duplicates.docs) {
    if (duplicate.id !== deviceId) batch.delete(duplicate.ref);
  }
  batch.set(deviceRef, {
    uid: authority.uid,
    communityId: authority.communityId,
    role: authority.role,
    appId: appContext.appId,
    firebaseAppId: appContext.firebaseAppId,
    platform: appContext.platform,
    token,
    installationId,
    audienceKey: notificationAudienceKey({
      appId: appContext.appId,
      role: authority.role,
      communityId: authority.communityId,
      uid: authority.uid,
    }),
    active: true,
    updatedAt: FieldValue.serverTimestamp(),
  }, {merge: true});
  await batch.commit();

  return {
    deviceId,
    uid: authority.uid,
    communityId: authority.communityId,
    role: authority.role,
    appId: appContext.appId,
    platform: appContext.platform,
  };
}

async function unregisterNotificationDeviceCore({db, auth, app, data}) {
  const uid = requireAuthenticated(auth);
  const appContext = requireAppContext(app);
  const installationId = requireInstallationId(data?.installationId);
  const deviceId = notificationDeviceId(appContext.appId, uid, installationId);
  const ref = db.collection(DEVICE_COLLECTION).doc(deviceId);
  const snapshot = await ref.get();

  if (snapshot.exists) {
    const stored = snapshot.data();
    if (stored?.uid !== uid || stored?.appId !== appContext.appId ||
        stored?.firebaseAppId !== appContext.firebaseAppId) {
      throw new RegistrationError(
        "permission-denied",
        "This notification installation is not owned by the current user.",
      );
    }
    await ref.delete();
  }
  return {removed: snapshot.exists, deviceId};
}

async function requireAdminSender(db, auth, app, communityId) {
  const uid = requireAuthenticated(auth);
  const appContext = requireAppContext(app);
  if (appContext.appId !== "admin") {
    throw new RegistrationError(
      "permission-denied",
      "Only the Admin application may create Resident notifications.",
    );
  }
  const adminSnapshot = await db.collection("admins").doc(uid).get();
  const admin = adminSnapshot.data();
  const authorized = Array.isArray(admin?.authorizedCommunityIds) ?
    admin.authorizedCommunityIds : [];
  if (!adminSnapshot.exists || admin?.uid !== uid || admin?.role !== "admin" ||
      admin?.isActive !== true || !authorized.includes(communityId)) {
    throw new RegistrationError(
      "permission-denied",
      "The selected community is not authorized for this Admin.",
    );
  }
  await requireActiveCommunity(db, communityId);
  return uid;
}

async function requireResidentRecipient(db, recipientUid, communityId) {
  const snapshot = await db.collection("users").doc(recipientUid).get();
  const resident = snapshot.data();
  if (!snapshot.exists || resident?.uid !== recipientUid ||
      resident?.role !== "resident" || resident?.communityId !== communityId ||
      resident?.approvalStatus !== "approved" || resident?.isActive !== true ||
      (resident?.status != null && resident.status !== "active")) {
    throw new RegistrationError(
      "failed-precondition",
      "The notification recipient is not an active Resident in this community.",
    );
  }
  return resident;
}

async function requireCanonicalRecipient(
  db,
  {recipientUid, communityId, role, appId},
) {
  if (role === "resident" && appId === "resident") {
    return requireResidentRecipient(db, recipientUid, communityId);
  }
  if (role === "admin" && appId === "admin") {
    const snapshot = await db.collection("admins").doc(recipientUid).get();
    const profile = snapshot.data();
    const authorized = Array.isArray(profile?.authorizedCommunityIds) ?
      profile.authorizedCommunityIds : [];
    if (!snapshot.exists || profile?.uid !== recipientUid ||
        profile?.role !== "admin" || profile?.isActive !== true ||
        !authorized.includes(communityId)) {
      throw new RegistrationError(
        "failed-precondition",
        "The notification recipient is not an active Admin for this community.",
      );
    }
    await requireActiveCommunity(db, communityId);
    return profile;
  }
  if (role === "security" && appId === "security") {
    const snapshot = await db.collection("securityStaff").doc(recipientUid).get();
    const profile = snapshot.data();
    if (!snapshot.exists || profile?.uid !== recipientUid ||
        profile?.role !== "security" || profile?.isActive !== true ||
        profile?.communityId !== communityId) {
      throw new RegistrationError(
        "failed-precondition",
        "The notification recipient is not active Security staff in this community.",
      );
    }
    await requireActiveCommunity(db, communityId);
    return profile;
  }
  throw new RegistrationError(
    "invalid-argument",
    "The notification role and intended application do not match.",
  );
}

function requireMessageText(value, field, maxLength) {
  const text = normalizedString(value);
  if (!text || text.length > maxLength) {
    throw new RegistrationError("invalid-argument", `A valid ${field} is required.`);
  }
  return text;
}

function notificationIdFor(input) {
  return crypto
    .createHash("sha256")
    .update([
      input.senderUid,
      input.communityId,
      input.recipientUid,
      input.category,
      input.sourceEntityId,
      input.title,
      input.message,
    ].join("|"))
    .digest("hex")
    .slice(0, 48);
}

async function deleteStaleDevices(db, refs) {
  if (refs.length === 0) return;
  const batch = db.batch();
  for (const ref of refs) batch.delete(ref);
  await batch.commit();
}

async function sendCanonicalNotification({
  db,
  messaging,
  recipientUid,
  communityId,
  role,
  appId,
  notificationId,
  title,
  message,
}) {
  await requireCanonicalRecipient(db, {
    recipientUid,
    communityId,
    role,
    appId,
  });
  const audienceKey = notificationAudienceKey({
    appId,
    role,
    communityId,
    uid: recipientUid,
  });
  const snapshot = await db
    .collection(DEVICE_COLLECTION)
    .where("audienceKey", "==", audienceKey)
    .get();
  const devices = snapshot.docs.filter((doc) => {
    const value = doc.data();
    return value.active === true && value.uid === recipientUid &&
      value.communityId === communityId && value.role === role &&
      value.appId === appId && typeof value.token === "string";
  });
  const unique = new Map();
  for (const device of devices) {
    if (!unique.has(device.data().token)) unique.set(device.data().token, device);
  }
  const tokenDevices = [...unique.values()];
  if (tokenDevices.length === 0) {
    return {successCount: 0, failureCount: 0, staleCount: 0, noDevices: true};
  }

  let successCount = 0;
  let failureCount = 0;
  const staleRefs = [];
  for (let start = 0; start < tokenDevices.length; start += 500) {
    const chunk = tokenDevices.slice(start, start + 500);
    const response = await messaging.sendEachForMulticast({
      tokens: chunk.map((device) => device.data().token),
      notification: {title, body: message},
      data: {
        type: "notification",
        entityId: notificationId,
        communityId,
      },
      android: {
        priority: "high",
        notification: {channelId: NOTIFICATION_CHANNEL_ID},
      },
      apns: {
        headers: {"apns-priority": "10"},
        payload: {aps: {sound: "default", contentAvailable: true}},
      },
    });
    successCount += response.successCount;
    failureCount += response.failureCount;
    response.responses.forEach((result, index) => {
      if (!result.success && STALE_TOKEN_CODES.has(result.error?.code)) {
        staleRefs.push(chunk[index].ref);
      }
    });
  }
  await deleteStaleDevices(db, staleRefs);
  return {
    successCount,
    failureCount,
    staleCount: staleRefs.length,
    noDevices: false,
  };
}

async function sendNotificationCore({db, messaging, auth, app, data}) {
  const communityId = requireMessageText(data?.communityId, "community ID", 128);
  const recipientUid = requireMessageText(data?.recipientUid, "recipient UID", 128);
  const title = requireMessageText(data?.title, "notification title", 120);
  const message = requireMessageText(data?.message, "notification message", 500);
  const category = normalizedString(data?.category).toLowerCase();
  const priority = normalizedString(data?.priority).toLowerCase();
  const sourceEntityId = normalizedString(data?.sourceEntityId).slice(0, 200);
  if (!ALLOWED_CATEGORIES.has(category) || !ALLOWED_PRIORITIES.has(priority)) {
    throw new RegistrationError("invalid-argument", "Invalid notification category or priority.");
  }
  if (!messaging || typeof messaging.sendEachForMulticast !== "function") {
    throw new RegistrationError("failed-precondition", "Firebase Messaging is unavailable.");
  }

  const senderUid = await requireAdminSender(db, auth, app, communityId);
  await requireResidentRecipient(db, recipientUid, communityId);
  const notificationId = notificationIdFor({
    senderUid,
    communityId,
    recipientUid,
    category,
    sourceEntityId,
    title,
    message,
  });
  const notificationRef = db.collection(NOTIFICATION_COLLECTION).doc(notificationId);
  let duplicate = false;

  await db.runTransaction(async (transaction) => {
    const existing = await transaction.get(notificationRef);
    const existingStatus = existing.data()?.deliveryStatus;
    if (existing.exists && ["pending", "sent", "partial", "no_devices"].includes(existingStatus)) {
      duplicate = true;
      return;
    }
    transaction.set(notificationRef, {
      communityId,
      recipientId: recipientUid,
      audience: "resident",
      role: "resident",
      appId: "resident",
      title,
      message,
      type: category,
      priority,
      sourceEntityId: sourceEntityId || null,
      createdBy: senderUid,
      isRead: false,
      deliveryStatus: "pending",
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
  });

  if (duplicate) return {notificationId, duplicate: true};

  try {
    const result = await sendCanonicalNotification({
      db,
      messaging,
      recipientUid,
      communityId,
      role: "resident",
      appId: "resident",
      notificationId,
      title,
      message,
    });
    const deliveryStatus = result.noDevices ? "no_devices" :
      result.failureCount === 0 ? "sent" :
      result.successCount > 0 ? "partial" : "failed";
    await notificationRef.update({
      deliveryStatus,
      successCount: result.successCount,
      failureCount: result.failureCount,
      staleTokenCount: result.staleCount,
      sentAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    return {notificationId, duplicate: false, deliveryStatus, ...result};
  } catch (error) {
    await notificationRef.update({
      deliveryStatus: "failed",
      updatedAt: FieldValue.serverTimestamp(),
    });
    throw error;
  }
}

module.exports = {
  APP_CONTEXTS,
  DEVICE_COLLECTION,
  NOTIFICATION_CHANNEL_ID,
  notificationAudienceKey,
  notificationDeviceId,
  registerNotificationDeviceCore,
  unregisterNotificationDeviceCore,
  sendCanonicalNotification,
  requireCanonicalRecipient,
  sendNotificationCore,
};
