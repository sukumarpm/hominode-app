'use strict';

// Resident-to-admin chat creation. Never accept adminId or communityId from the client.
class ChatSetupError extends Error {
  constructor(code, message) { super(message); this.code = code; }
}

async function getOrCreateResidentAdminChatCore({ db, auth, fieldValue }) {
  const uid = auth?.uid;
  if (!uid) throw new ChatSetupError('unauthenticated', 'Please sign in again.');
  const residentRef = db.collection('users').doc(uid);
  const residentSnap = await residentRef.get();
  const resident = residentSnap.data();
  if (!residentSnap.exists || resident.role !== 'resident' ||
      resident.approvalStatus !== 'approved' || resident.isActive !== true ||
      (resident.status && resident.status !== 'active') ||
      typeof resident.communityId !== 'string' || !resident.communityId) {
    throw new ChatSetupError('permission-denied', 'An approved resident profile is required.');
  }
  const communityId = resident.communityId;
  const community = await db.collection('communities').doc(communityId).get();
  if (!community.exists || community.data().isActive !== true) {
    throw new ChatSetupError('failed-precondition', 'The community is not active.');
  }

  // Admins live in /admins, not /users. Query in trusted code only.
  const adminsSnap = await db.collection('admins')
    .where('authorizedCommunityIds', 'array-contains', communityId).get();
  const admins = adminsSnap.docs.filter((doc) => {
    const data = doc.data();
    return data.role === 'admin' && data.isActive === true &&
      Array.isArray(data.authorizedCommunityIds) &&
      data.authorizedCommunityIds.includes(communityId) &&
      (!data.uid || data.uid === doc.id);
  }).sort((a, b) => a.id.localeCompare(b.id));
  if (!admins.length) {
    throw new ChatSetupError('failed-precondition', 'No active community administrator is available.');
  }
  const admin = admins[0];
  const adminData = admin.data();
  const chatId = `admin_${communityId}_${uid}`;
  const chatRef = db.collection('chats').doc(chatId);
  const FieldValue = fieldValue || require('firebase-admin/firestore').FieldValue;

  await db.runTransaction(async (tx) => {
    const existing = await tx.get(chatRef);
    if (existing.exists) {
      const data = existing.data();
      if (data.communityId !== communityId || data.residentId !== uid ||
          !Array.isArray(data.participants) || !data.participants.includes(uid) ||
          !data.participants.includes(data.adminId)) {
        throw new ChatSetupError('failed-precondition', 'Existing chat needs administrator review.');
      }
      return;
    }
    const residentName = resident.name || resident.fullName || 'Resident';
    const adminName = adminData.name || 'Community Admin';
    tx.create(chatRef, {
      chatType: 'individual', type: 'admin',
      communityId, buildingId: resident.buildingId || '',
      flatId: resident.flatId || '', flatLabel: resident.flatLabel || resident.flatNumber || '',
      residentId: uid, residentName, adminId: admin.id, adminName,
      participants: [uid, admin.id], participantIds: [uid, admin.id],
      participantNames: { [uid]: residentName, [admin.id]: adminName },
      participantRoles: { [uid]: 'resident', [admin.id]: 'admin' },
      title: adminName, subtitle: 'Support & Assistance', isGroup: false,
      status: 'open', category: 'other',
      lastMessage: '', lastMessageTime: FieldValue.serverTimestamp(),
      lastMessageSenderId: '', unreadCount: { [uid]: 0, [admin.id]: 0 },
      createdAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp(),
    });
  });
  return { chatId };
}

module.exports = { getOrCreateResidentAdminChatCore, ChatSetupError };
