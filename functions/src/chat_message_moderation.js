'use strict';

// Moderation of Resident <-> Admin chat messages. This is a deliberately
// conservative deterministic policy, not an AI content classifier.
const { FieldValue } = require('firebase-admin/firestore');

class ChatSendError extends Error {
  constructor(code, message) { super(message); this.code = code; }
}

const categories = new Set(['billing', 'maintenance', 'amenities', 'complaints', 'building', 'other']);

// Community safety reports must remain possible. Do not censor ordinary
// references to harassment, medical concerns, weapons or alleged crimes.
function moderateChatText(value) {
  const text = value.normalize('NFKC').toLowerCase().replace(/\s+/g, ' ').trim();
  const report = /\b(report|reported|harass(?:ment|ed)?|assault|threat(?:ened)?|complain(?:t)?|incident|victim|police|safety|abuse|education|medical|health)\b/.test(text);
  const explicit = /\b(porn(?:ography)?|xxx|send nudes?|buy sex|selling sex|sexual services?)\b/.test(text);
  const targetedAbuse = /\b(fuck you|kill yourself|you (?:are|re) (?:an? )?(?:idiot|moron))\b/.test(text);
  const standaloneSex = /^sex[.!?\s]*$/.test(text);
  const threats = /\b(i(?:'| a)?m going to|i will|i'll) (?:kill|hurt|attack) you\b/.test(text);
  if (targetedAbuse || threats || (explicit && !report) || (standaloneSex && !report)) {
    return { allowed: false, reason: 'Please revise your message to follow community chat guidelines.' };
  }
  return { allowed: true };
}

async function sendModeratedChatMessageCore({ db, auth, data, fieldValue = FieldValue }) {
  const uid = auth?.uid;
  if (!uid) throw new ChatSendError('unauthenticated', 'Please sign in again.');
  if (!data || typeof data !== 'object' || Array.isArray(data) ||
      Object.keys(data).some(k => !['chatId','message','submissionId','isQuery','queryType'].includes(k))) {
    throw new ChatSendError('invalid-argument', 'Invalid chat submission.');
  }
  const { chatId, submissionId } = data;
  if (typeof chatId !== 'string' || !/^[a-zA-Z0-9_-]{1,180}$/.test(chatId) ||
      typeof submissionId !== 'string' || !/^[a-zA-Z0-9_-]{8,100}$/.test(submissionId)) {
    throw new ChatSendError('invalid-argument', 'Invalid chat or submission ID.');
  }
  const message = typeof data.message === 'string' ? data.message.trim() : '';
  if (!message || message.length > 2000) {
    throw new ChatSendError('invalid-argument', 'Message must contain 1–2000 characters.');
  }
  if (data.isQuery != null && typeof data.isQuery !== 'boolean') {
    throw new ChatSendError('invalid-argument', 'Invalid query flag.');
  }
  if (data.queryType != null && !categories.has(data.queryType)) {
    throw new ChatSendError('invalid-argument', 'Invalid query category.');
  }
  const moderation = moderateChatText(message);
  if (!moderation.allowed) throw new ChatSendError('failed-precondition', moderation.reason);

  const chatRef = db.collection('chats').doc(chatId);
  const chatSnap = await chatRef.get();
  if (!chatSnap.exists) throw new ChatSendError('not-found', 'Conversation not found.');
  const chat = chatSnap.data();
  const communityId = chat.communityId;
  if (!communityId || !Array.isArray(chat.participants) || !chat.participants.includes(uid)) {
    throw new ChatSendError('permission-denied', 'Not a member of this conversation.');
  }
  const isResident = chat.residentId === uid;
  const isAdmin = chat.adminId === uid;
  if (!isResident && !isAdmin) throw new ChatSendError('permission-denied', 'Not authorized for this conversation.');

  const profileSnap = await db.collection(isResident ? 'users' : 'admins').doc(uid).get();
  const profile = profileSnap.data();
  if (!profileSnap.exists || profile.isActive !== true ||
      (isResident
        ? (profile.role !== 'resident' || profile.approvalStatus !== 'approved' ||
           (profile.status && profile.status !== 'active') || profile.communityId !== communityId)
        : (profile.role !== 'admin' || !Array.isArray(profile.authorizedCommunityIds) ||
           !profile.authorizedCommunityIds.includes(communityId)))) {
    throw new ChatSendError('permission-denied', 'An active community membership is required.');
  }
  if (data.isQuery && !isResident) throw new ChatSendError('permission-denied', 'Only residents may submit queries.');
  const isQuery = data.isQuery === true;
  const messageRef = chatRef.collection('messages').doc(submissionId);
  let created = false;
  await db.runTransaction(async (tx) => {
    const currentChat = await tx.get(chatRef);
    const currentMessage = await tx.get(messageRef);
    if (!currentChat.exists || currentChat.data().communityId !== communityId ||
        !currentChat.data().participants?.includes(uid)) {
      throw new ChatSendError('permission-denied', 'Conversation access changed.');
    }
    if (currentMessage.exists) {
      if (currentMessage.data().senderId !== uid || currentMessage.data().message !== message) {
        throw new ChatSendError('already-exists', 'Submission ID was already used.');
      }
      return;
    }
    const now = fieldValue.serverTimestamp();
    tx.create(messageRef, {
      senderId: uid,
      senderName: profile.name || profile.fullName || (isAdmin ? 'Admin' : 'Resident'),
      senderRole: isAdmin ? 'admin' : 'resident',
      communityId, message, imageUrl: null, isQuery,
      queryType: isQuery ? (data.queryType || 'other') : null,
      timestamp: now, isRead: false, readBy: [uid],
      moderationVersion: 1,
    });
    tx.update(chatRef, {
      lastMessage: message,
      lastMessageTime: now,
      lastMessageSenderId: uid,
      lastMessageBy: isAdmin ? 'admin' : 'resident',
      updatedAt: now,
    });
    created = true;
  });
  return { messageId: submissionId, created };
}

module.exports = { sendModeratedChatMessageCore, moderateChatText, ChatSendError };
