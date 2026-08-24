const {FieldValue} = require("firebase-admin/firestore");
const {RegistrationError} = require("./register_resident");
const {requireActiveSuperAdmin} = require("./tenant_management");

function validateAssignments(value) {
  if (!Array.isArray(value) || value.length === 0 || value.length > 100) {
    throw new RegistrationError("invalid-argument", "Assign at least one community.");
  }
  const ids = value.map((id) => typeof id === "string" ? id.trim() : "");
  if (ids.some((id) => !id || id.length > 80) || new Set(ids).size !== ids.length) {
    throw new RegistrationError("invalid-argument", "Community assignments must be unique valid IDs.");
  }
  return ids;
}

async function requireActiveCommunities(db, communityIds) {
  const snapshots = await Promise.all(communityIds.map((id) => db.collection("communities").doc(id).get()));
  for (let index = 0; index < snapshots.length; index++) {
    if (!snapshots[index].exists || snapshots[index].data()?.isActive !== true) {
      throw new RegistrationError("failed-precondition", `Community ${communityIds[index]} is inactive or unavailable.`);
    }
  }
}

function validateCreateAdminInput(data) {
  const allowed = new Set(["phoneNumber", "authorizedCommunityIds", "isActive"]);
  if (!data || typeof data !== "object" || Object.keys(data).some((key) => !allowed.has(key))) {
    throw new RegistrationError("invalid-argument", "Only phoneNumber, authorizedCommunityIds, and isActive are accepted.");
  }
  const phoneNumber = String(data.phoneNumber ?? "").trim();
  if (!/^\+[1-9]\d{7,14}$/.test(phoneNumber)) throw new RegistrationError("invalid-argument", "Use an E.164 phone number.");
  if (data.isActive != null && typeof data.isActive !== "boolean") throw new RegistrationError("invalid-argument", "isActive must be boolean.");
  return {phoneNumber, authorizedCommunityIds: validateAssignments(data.authorizedCommunityIds), isActive: data.isActive ?? true};
}

async function createAdminCore({db, authAdmin, auth, data}) {
  await requireActiveSuperAdmin(db, auth);
  const input = validateCreateAdminInput(data);
  await requireActiveCommunities(db, input.authorizedCommunityIds);
  let user;
  let createdAuthUser = false;
  try {
    user = await authAdmin.getUserByPhoneNumber(input.phoneNumber);
  } catch (error) {
    if (error?.code !== "auth/user-not-found") throw error;
    user = await authAdmin.createUser({phoneNumber: input.phoneNumber, disabled: false});
    createdAuthUser = true;
  }
  const ref = db.collection("admins").doc(user.uid);
  try {
    if ((await db.collection("users").doc(user.uid).get()).exists) {
      throw new RegistrationError("failed-precondition", "This phone account already belongs to a resident.");
    }
    if ((await ref.get()).exists) throw new RegistrationError("already-exists", "An admin profile already exists for this phone number.");
    await ref.create({uid: user.uid, phoneNumber: input.phoneNumber, role: "admin", isActive: input.isActive, authorizedCommunityIds: input.authorizedCommunityIds, createdAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp(), createdBy: auth.uid});
    return {uid: user.uid, role: "admin"};
  } catch (error) {
    if (createdAuthUser) await authAdmin.deleteUser(user.uid).catch(() => {});
    throw error;
  }
}

async function requireOrdinaryAdmin(db, uid) {
  // TODO: Provisioning additional superAdmins requires a separate, stronger
  // privileged workflow; this management surface intentionally excludes them.
  const ref = db.collection("admins").doc(uid);
  const snapshot = await ref.get();
  if (!snapshot.exists || snapshot.data()?.role !== "admin") throw new RegistrationError("failed-precondition", "Only ordinary admin accounts can be managed here.");
  return ref;
}

async function updateAdminAssignmentsCore({db, auth, data}) {
  const actorUid = await requireActiveSuperAdmin(db, auth);
  const uid = String(data?.uid ?? "").trim();
  if (!uid || Object.keys(data ?? {}).some((key) => !["uid", "authorizedCommunityIds"].includes(key))) throw new RegistrationError("invalid-argument", "UID and assignments are required.");
  if (uid === actorUid) throw new RegistrationError("permission-denied", "A superAdmin cannot modify its own assignments here.");
  const ids = validateAssignments(data.authorizedCommunityIds);
  await requireActiveCommunities(db, ids);
  const ref = await requireOrdinaryAdmin(db, uid);
  await ref.update({authorizedCommunityIds: ids, updatedAt: FieldValue.serverTimestamp(), updatedBy: actorUid});
  return {uid, authorizedCommunityIds: ids};
}

async function setAdminActiveCore({db, auth, data}) {
  const actorUid = await requireActiveSuperAdmin(db, auth);
  const uid = String(data?.uid ?? "").trim();
  if (!uid || typeof data?.isActive !== "boolean" || Object.keys(data ?? {}).some((key) => !["uid", "isActive"].includes(key))) throw new RegistrationError("invalid-argument", "UID and active status are required.");
  if (uid === actorUid) throw new RegistrationError("permission-denied", "The current superAdmin cannot be changed here.");
  const ref = await requireOrdinaryAdmin(db, uid);
  await ref.update({isActive: data.isActive, updatedAt: FieldValue.serverTimestamp(), updatedBy: actorUid});
  return {uid, isActive: data.isActive};
}

module.exports = {validateAssignments, requireActiveCommunities, validateCreateAdminInput, createAdminCore, updateAdminAssignmentsCore, setAdminActiveCore};
