'use strict';

const {FieldValue} = require('firebase-admin/firestore');
const {sendCanonicalNotification, requireCanonicalRecipient} = require('./notifications');

function chatNotificationTarget(chat, message) {
  if (!chat || !message || message.moderationVersion !== 1 ||
      !chat.communityId || message.communityId !== chat.communityId ||
      (chat.type !== 'admin' && !(chat.adminId && chat.residentId)) ||
      !chat.adminId || !chat.residentId ||
      !Array.isArray(chat.participants) ||
      !chat.participants.includes(chat.adminId) ||
      !chat.participants.includes(chat.residentId)) return null;

  if (message.senderId === chat.residentId && message.senderRole === 'resident') {
    return {recipientUid: chat.adminId, role:'admin', appId:'admin'};
  }
  if (message.senderId === chat.adminId && message.senderRole === 'admin') {
    return {recipientUid: chat.residentId, role:'resident', appId:'resident'};
  }
  return null;
}

async function dispatchChatMessageNotificationCore({db, messaging, chatId, messageId}) {
  const chatRef = db.collection('chats').doc(chatId);
  const [chatSnap, messageSnap] = await Promise.all([
    chatRef.get(), chatRef.collection('messages').doc(messageId).get(),
  ]);
  if (!chatSnap.exists || !messageSnap.exists) return {ignored:true};
  const chat = chatSnap.data();
  const message = messageSnap.data();
  const target = chatNotificationTarget(chat, message);
  if (!target) return {ignored:true};

  try {
    await requireCanonicalRecipient(db, {
      recipientUid:target.recipientUid, communityId:chat.communityId,
      role:target.role, appId:target.appId,
    });
  } catch (error) {
    if (['failed-precondition','permission-denied','not-found'].includes(error.code)) {
      return {ignored:true, recipientUnavailable:true};
    }
    throw error;
  }

  const notificationId = 'chat_' + chatId + '_' + messageId;
  const notificationRef = db.collection('notifications').doc(notificationId);
  const title = target.role === 'admin' ? 'New resident message' : 'New message from Admin';
  // Do not expose the message text in lock-screen notifications.
  const body = 'Open Hominode to view the conversation.';
  const created = await db.runTransaction(async tx => {
    const existing = await tx.get(notificationRef);
    if (existing.exists) return false;
    tx.create(notificationRef, {
      communityId:chat.communityId,
      recipientId:target.recipientUid,
      audience:target.role, role:target.role, appId:target.appId,
      title, message:body, type:'general', eventType:'admin_chat_message',
      priority:'normal', sourceEntityId:chatId,
      createdBy:message.senderId, isRead:false, deliveryStatus:'pending',
      data:{route:'notifications', chatId, messageId, eventType:'admin_chat_message'},
      createdAt:FieldValue.serverTimestamp(), updatedAt:FieldValue.serverTimestamp(),
    });
    return true;
  });
  if (!created) return {duplicate:true, notificationId};

  try {
    const outcome = await sendCanonicalNotification({
      db, messaging, recipientUid:target.recipientUid,
      communityId:chat.communityId, role:target.role, appId:target.appId,
      notificationId, title, message:body,
      notificationData:{route:'notifications',eventType:'admin_chat_message'},
    });
    const deliveryStatus = outcome.noDevices ? 'no_devices' :
      outcome.failureCount === 0 ? 'sent' : outcome.successCount > 0 ? 'partial' : 'failed';
    await notificationRef.update({
      deliveryStatus, successCount:outcome.successCount, failureCount:outcome.failureCount,
      updatedAt:FieldValue.serverTimestamp(),
    });
    return {notificationId, deliveryStatus};
  } catch (_) {
    await notificationRef.update({deliveryStatus:'failed', updatedAt:FieldValue.serverTimestamp()}).catch(() => {});
    return {notificationId, deliveryStatus:'failed'};
  }
}

module.exports = {chatNotificationTarget, dispatchChatMessageNotificationCore};
