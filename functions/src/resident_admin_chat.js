// Canonical Resident -> community Admin chat creation.
// Uses the same chats/{chatId}/messages schema as the Admin application.
// Never resolves Admin membership through Resident-readable Firestore queries.
const {createHash} = require("node:crypto");
const {FieldValue} = require("firebase-admin/firestore");
const {RegistrationError, verifiedPhoneAuth} = require("./register_resident");
const {operationalAccessFailure} = require("./resident_identity");
const {APP_CONTEXTS} = require("./notifications");

const CATEGORIES = new Set(["billing", "maintenance", "amenities", "complaints", "building", "other"]);
const clean = (value) => typeof value === "string" ? value.trim() : "";
const hash = (value) => createHash("sha256").update(value).digest("hex");

function validateRequest(data, app) {
  const appId = clean(app?.appId);
  if (!Object.prototype.hasOwnProperty.call(APP_CONTEXTS, appId) ||
      APP_CONTEXTS[appId].role !== "resident") {
    throw new RegistrationError("failed-precondition", "Use the Hominode Resident application.");
  }
  if (!data || typeof data !== "object" || Array.isArray(data) ||
      Object.keys(data).some((key) => !["action", "category", "message", "requestId", "isQuery"].includes(key))) {
    throw new RegistrationError("invalid-argument", "Invalid Admin chat request.");
  }
  const action = clean(data.action);
  if (action === "lookup") {
    if (Object.keys(data).some((key) => key !== "action")) {
      throw new RegistrationError("invalid-argument", "Invalid chat lookup request.");
    }
    return {action};
  }
  const category = clean(data.category);
  const message = clean(data.message);
  const requestId = clean(data.requestId);
  const isQuery = data.isQuery;
  if (action !== "send" || !CATEGORIES.has(category) || message.length === 0 ||
      message.length > 2000 || (isQuery != null && typeof isQuery !== "boolean") ||
      !/^[A-Za-z0-9_-]{16,100}$/.test(requestId)) {
    throw new RegistrationError("invalid-argument", "A category, message and unique request ID are required.");
  }
  return {action, category, message, requestId, isQuery: isQuery ?? false};
}

async function residentContext(db, auth) {
  const {uid} = verifiedPhoneAuth(auth);
  const profileSnap = await db.collection("users").doc(uid).get();
  const profile = profileSnap.data();
  const communityId = clean(profile?.communityId);
  if (!profileSnap.exists || profile?.uid !== uid ||
      !/^[A-Za-z0-9_-]{1,128}$/.test(communityId)) {
    throw new RegistrationError("permission-denied", "An approved Resident community is required.");
  }
  const communitySnap = await db.collection("communities").doc(communityId).get();
  const community = communitySnap.data();
  if (!communitySnap.exists || operationalAccessFailure(profile, {id: communityId, ...community})) {
    throw new RegistrationError("permission-denied", "Approved Resident access is required to message Admin.");
  }
  const flatId = clean(profile.flatId);
  if (!/^[A-Za-z0-9_-]{1,128}$/.test(flatId)) {
    throw new RegistrationError("failed-precondition", "Your assigned flat is missing. Contact your community Admin.");
  }
  const flatSnap = await db.collection("flats").doc(flatId).get();
  const flat = flatSnap.data();
  const buildingId = clean(profile.buildingId) || clean(flat?.buildingId);
  if (!flatSnap.exists || flat?.communityId !== communityId ||
      flat?.buildingId !== buildingId || !/^[A-Za-z0-9_-]{1,128}$/.test(buildingId)) {
    throw new RegistrationError("failed-precondition", "Your building and flat assignment needs review.");
  }
  const buildingSnap = await db.collection("buildings").doc(buildingId).get();
  const building = buildingSnap.data();
  if (!buildingSnap.exists || building?.communityId !== communityId) {
    throw new RegistrationError("failed-precondition", "Your building is unavailable.");
  }
  return {
    uid, communityId, buildingId, flatId,
    buildingName: clean(building.buildingName || building.name),
    flatLabel: clean(profile.flatLabel || profile.flatNumber || flat.flatLabel || flat.label) || flatId,
    residentName: clean(profile.name || profile.fullName) || "Resident",
  };
}

async function activeAdmins(db, communityId) {
  const result = await db.collection("admins")
    .where("authorizedCommunityIds", "array-contains", communityId).get();
  return result.docs
    .filter((doc) => {
      const admin = doc.data();
      return admin?.uid === doc.id && admin?.role === "admin" && admin?.isActive === true &&
        Array.isArray(admin.authorizedCommunityIds) && admin.authorizedCommunityIds.includes(communityId);
    })
    .map((doc) => ({id: doc.id, name: clean(doc.data().name) || "Community Admin"}))
    .sort((a, b) => a.id.localeCompare(b.id));
}

function existingChat(docs, resident, admins) {
  const activeById = new Set(admins.map((admin) => admin.id));
  return docs
    .filter((doc) => {
      const chat = doc.data();
      const members = Array.isArray(chat?.participants) ? chat.participants : [];
      return chat?.communityId === resident.communityId &&
        chat?.chatType === "individual" && chat?.residentId === resident.uid &&
        activeById.has(chat.adminId) && members.includes(resident.uid) &&
        members.includes(chat.adminId);
    })
    .sort((a, b) => a.id.localeCompare(b.id))[0] ?? null;
}

async function createResidentAdminChatCore({db, auth, app, data}) {
  const input = validateRequest(data, app);
  const resident = await residentContext(db, auth);
  const admins = await activeAdmins(db, resident.communityId);
  const existing = await db.collection("chats").where("residentId", "==", resident.uid).get();
  const reusable = existingChat(existing.docs, resident, admins);
  if (input.action === "lookup") return {chatId: reusable?.id ?? null};
  if (admins.length === 0) {
    throw new RegistrationError("failed-precondition", "No active community Admin is assigned yet.");
  }
  const admin = admins.find((entry) => entry.id === reusable?.data().adminId) || admins[0];
  const chatId = reusable?.id || ("admin_" + hash(resident.communityId + "|" + resident.uid).slice(0, 40));
  const chatRef = db.collection("chats").doc(chatId);
  const messageRef = chatRef.collection("messages").doc(hash(resident.uid + "|" + input.requestId));
  return db.runTransaction(async (tx) => {
    const [chatSnapshot, messageSnapshot] = await Promise.all([
      tx.get(chatRef), tx.get(messageRef),
    ]);
    const current = chatSnapshot.data();
    if (current && (current.communityId !== resident.communityId ||
        current.residentId !== resident.uid ||
        current.adminId !== admin.id ||
        !Array.isArray(current.participants) ||
        !current.participants.includes(resident.uid) ||
        !current.participants.includes(admin.id))) {
      throw new RegistrationError("failed-precondition", "This conversation needs review by your community Admin.");
    }
    if (messageSnapshot.exists) return {chatId, duplicate: true};
    const now = FieldValue.serverTimestamp();
    if (!chatSnapshot.exists) {
      tx.create(chatRef, {
        chatType: "individual",
        type: "admin",
        isAdminChat: true,
        communityId: resident.communityId,
        buildingId: resident.buildingId,
        buildingName: resident.buildingName,
        flatId: resident.flatId,
        flatLabel: resident.flatLabel,
        flatNumber: resident.flatLabel,
        participants: [admin.id, resident.uid],
        participantIds: [admin.id, resident.uid],
        participantNames: {[admin.id]: admin.name, [resident.uid]: resident.residentName},
        participantRoles: {[admin.id]: "admin", [resident.uid]: "resident"},
        adminId: admin.id,
        adminName: admin.name,
        residentId: resident.uid,
        residentName: resident.residentName,
        status: "open",
        category: input.category,
        lastMessage: input.message,
        lastMessageTime: now,
        lastMessageBy: "resident",
        lastMessageSenderId: resident.uid,
        unreadCount: {[admin.id]: 1, [resident.uid]: 0},
        createdAt: now,
        updatedAt: now,
      });
    } else {
      tx.update(chatRef, {
        lastMessage: input.message,
        lastMessageTime: now,
        lastMessageBy: "resident",
        lastMessageSenderId: resident.uid,
        category: input.category,
        updatedAt: now,
      });
    }
    tx.create(messageRef, {
      senderId: resident.uid,
      senderName: resident.residentName,
      senderRole: "resident",
      communityId: resident.communityId,
      message: input.message,
      text: input.message, // Resident legacy renderer compatibility.
      isQuery: input.isQuery,
      queryType: input.isQuery ? input.category : null,
      timestamp: now,
      isRead: false,
      readBy: [resident.uid],
    });
    return {chatId, duplicate: false};
  });
}

module.exports = {createResidentAdminChatCore, validateRequest, existingChat};
