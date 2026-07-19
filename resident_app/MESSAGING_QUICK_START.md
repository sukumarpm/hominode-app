# Messaging System - Quick Start Guide

## 🚀 Quick Test

Run the test app to verify everything works:
```bash
flutter run lib/test_messaging_system.dart
```

## 📱 User Flow

### 1. View Messages
- Navigate to Messages screen
- See two tabs: **Chats** and **Requests**
- Admin chat always visible at top

### 2. Start New Chat
1. Tap **+** button (floating action button)
2. See list of flat members (same flat only)
3. Tap a member to send chat request
4. Request sent with status "pending"

### 3. Receive Chat Request
1. Go to **Requests** tab
2. See pending requests from flat members
3. Tap **Accept** to create chat
4. Tap **Reject** to decline

### 4. Chat Conversation
1. Tap any chat to open conversation
2. Messages load in real-time
3. Type message and tap send
4. Messages sync instantly

### 5. Admin Chat
1. Always visible at top of Chats tab
2. Tap to open conversation with building admin
3. No request needed - instant access

## 🔧 Key Functions

### Get Flat Members
```dart
final members = await ChatFirestoreService.instance.getFlatMembers();
// Returns list of users in same flat (excluding current user)
```

### Send Chat Request
```dart
final requestId = await ChatFirestoreService.instance.sendChatRequest(
  toUserId: 'user123',
  toUserName: 'John Doe',
);
```

### Accept Chat Request
```dart
final chatId = await ChatFirestoreService.instance.acceptChatRequest(requestId);
// Creates chat and returns chatId
```

### Stream Chats
```dart
ChatFirestoreService.instance.streamUserChats().listen((chats) {
  print('Received ${chats.length} chats');
});
```

### Stream Messages
```dart
ChatFirestoreService.instance.streamChatMessages(chatId).listen((messages) {
  print('Received ${messages.length} messages');
});
```

### Send Message
```dart
await ChatFirestoreService.instance.sendMessage(
  chatId: chatId,
  text: 'Hello!',
);
```

### Get/Create Admin Chat
```dart
final chatId = await ChatFirestoreService.instance.getOrCreateAdminChat();
// Returns existing or creates new admin chat
```

## 📊 Firestore Structure

### Collections
```
chats/
  {chatId}/
    - participants: [uid1, uid2]
    - flatId: "flat123"
    - type: "resident" | "admin"
    - lastMessage: "Hello"
    - lastMessageTime: timestamp
    
    messages/
      {messageId}/
        - senderId: "uid1"
        - text: "Hello"
        - timestamp: timestamp
        - readBy: ["uid1"]

chatRequests/
  {requestId}/
    - senderId: "uid1"
    - receiverId: "uid2"
    - flatId: "flat123"
    - status: "pending" | "accepted" | "rejected"
```

## 🔒 Security Rules

### Key Points
- Users can only see chats they're part of
- Only same-flat members can chat
- No cross-flat communication
- Admin chat based on buildingId

### Query Filters
```dart
// Flat members - same flat only
.where('flatId', isEqualTo: currentUser.flatId)
.where('uid', isNotEqualTo: currentUser.uid)

// User chats - participant check
.where('participantIds', arrayContains: currentUser.uid)

// Chat requests - receiver check
.where('receiverId', isEqualTo: currentUser.uid)
.where('status', isEqualTo: 'pending')
```

## 🎯 Testing Checklist

- [ ] Login as resident user
- [ ] View Messages screen
- [ ] See admin chat at top
- [ ] Tap + button to see flat members
- [ ] Send chat request to flat member
- [ ] Login as receiver
- [ ] See request in Requests tab
- [ ] Accept request
- [ ] Send messages back and forth
- [ ] Verify real-time updates
- [ ] Test admin chat
- [ ] Verify no cross-flat access

## 🐛 Troubleshooting

### No flat members showing
- Check user has `flatId` in Firestore
- Verify other users exist with same `flatId`
- Check Firestore security rules

### Chat request not appearing
- Verify receiver's `flatId` matches sender
- Check `chatRequests` collection in Firestore
- Ensure status is "pending"

### Messages not updating
- Check internet connection
- Verify Firestore rules allow read access
- Check console for errors

### Admin chat not working
- Verify user has `buildingId`
- Check if admin user exists for building
- Look for admin chat in Firestore

## 📝 Notes

- All data is real-time via Firestore streams
- No demo/mock data used
- Chat IDs are sorted participant IDs for consistency
- Admin chat uses special type "admin"
- Flat-based access enforced at service level
- Security rules provide additional protection

## 🎉 Success Indicators

✅ Flat members list shows only same-flat users
✅ Chat requests appear in Requests tab
✅ Accepted requests create chats
✅ Messages sync in real-time
✅ Admin chat always visible
✅ No cross-flat communication possible
✅ Unread counts update automatically
✅ Read receipts work correctly
