# Chat Requests Complete Flow ✅

## 🎯 Overview

Complete implementation of chat request system where users can:
1. Send chat requests to building members
2. Receive and view incoming requests
3. Accept requests to create chat conversations
4. Start chatting after acceptance

---

## 📊 Flow Function

### Send Chat Request Flow
```
Step 1: User taps building member
  ↓
Step 2: Get current user data
  ↓ FirebaseAuth.instance.currentUser.uid
  ↓ Query users by authUid
  ↓ Get: userId, name, photo, flatId
  ↓
Step 3: Check if request already exists
  ↓ Query: chatRequests
  ↓   .where("senderId", isEqualTo: currentUserId)
  ↓   .where("receiverId", isEqualTo: targetUserId)
  ↓   .where("status", isEqualTo: "pending")
  ↓
Step 4: Check if chat already exists
  ↓ Query: chats
  ↓   .where("participants", arrayContains: currentUserId)
  ↓   .where("isGroup", isEqualTo: false)
  ↓ Filter: participantIds contains both users
  ↓
Step 5: Create chat request document
  ↓ Collection: chatRequests
  ↓ Data: {
  ↓   senderId: currentUserId,
  ↓   senderName: currentUserName,
  ↓   senderPhoto: currentUserPhoto,
  ↓   receiverId: targetUserId,
  ↓   receiverName: targetUserName,
  ↓   flatId: currentUserFlatId,
  ↓   status: "pending",
  ↓   createdAt: serverTimestamp
  ↓ }
  ↓
Result: Request sent ✅
```

### Fetch Requests Flow
```
Step 1: Get current user ID
  ↓ FirebaseAuth.instance.currentUser.uid
  ↓ Query users by authUid
  ↓ Get: userId
  ↓
Step 2: Stream chat requests
  ↓ Collection: chatRequests
  ↓ Query: .where("receiverId", isEqualTo: userId)
  ↓        .where("status", isEqualTo: "pending")
  ↓        .orderBy("createdAt", descending: true)
  ↓
Step 3: Listen to realtime updates
  ↓ .snapshots()
  ↓ Parse each document to ChatRequestModel
  ↓
Result: List of pending requests ✅
```

### Accept Request Flow
```
Step 1: Get request document
  ↓ Collection: chatRequests
  ↓ Document ID: requestId
  ↓
Step 2: Extract request data
  ↓ senderId, senderName, flatId
  ↓
Step 3: Update request status
  ↓ Update: {
  ↓   status: "accepted",
  ↓   respondedAt: serverTimestamp
  ↓ }
  ↓
Step 4: Create chat document
  ↓ Collection: chats
  ↓ Document ID: sorted participant IDs (e.g., "userId1_userId2")
  ↓ Data: {
  ↓   chatId: documentId,
  ↓   participants: [senderId, receiverId],
  ↓   participantIds: [senderId, receiverId],
  ↓   flatId: flatId,
  ↓   type: "resident",
  ↓   isGroup: false,
  ↓   title: senderName,
  ↓   lastMessage: null,
  ↓   lastMessageTime: null,
  ↓   unreadCount: 0,
  ↓   createdAt: serverTimestamp,
  ↓   updatedAt: serverTimestamp
  ↓ }
  ↓
Step 5: Navigate to chat conversation
  ↓ Screen: ChatConversationScreen
  ↓ Params: chatId, chatTitle
  ↓
Result: Chat created and opened ✅
```

---

## 🗂️ Firestore Structure

### Collection: `chatRequests`

**Document Structure**:
```javascript
{
  senderId: "IPHzK5B5DTTT#8gn31",           // User who sent request
  senderName: "Sibiyon",                     // Sender's name
  senderPhoto: "https://...",                // Sender's photo URL (optional)
  receiverId: "Qy5GmvF8PVhOr9QuJID",        // User who receives request
  receiverName: "Preetham",                  // Receiver's name
  flatId: "WDxpsEh6DlqdeN9WsYZ",            // Sender's flat ID
  status: "pending",                         // pending | accepted | rejected
  createdAt: Timestamp,                      // When request was sent
  respondedAt: Timestamp                     // When request was accepted/rejected (optional)
}
```

**Example Document** (from your screenshot):
```javascript
{
  createdAt: "11 March 2026 at 22:22:00 UTC+5:30",
  flatId: "WDxpsEh6DlqdeN9WsYZ",
  receiverId: "Qy5GmvF8PVhOr9QuJID",
  receiverName: "Preetham",
  senderId: "IPHzK5B5DTTT#8gn31",
  senderName: "Sibiyon",
  senderPhoto: null,
  status: "pending"
}
```

### Collection: `chats`

**Document Structure** (created after acceptance):
```javascript
{
  chatId: "IPHzK5B5DTTT#8gn31_Qy5GmvF8PVhOr9QuJID",  // Sorted participant IDs
  participants: ["IPHzK5B5DTTT#8gn31", "Qy5GmvF8PVhOr9QuJID"],  // Array for queries
  participantIds: ["IPHzK5B5DTTT#8gn31", "Qy5GmvF8PVhOr9QuJID"],  // Compatibility
  flatId: "WDxpsEh6DlqdeN9WsYZ",
  type: "resident",
  isGroup: false,
  title: "Sibiyon",                          // Other user's name
  lastMessage: null,                         // Last message text
  lastMessageTime: null,                     // Last message timestamp
  unreadCount: 0,                            // Unread message count
  createdAt: Timestamp,
  updatedAt: Timestamp
}
```

### Subcollection: `chats/{chatId}/messages`

**Message Structure**:
```javascript
{
  chatId: "IPHzK5B5DTTT#8gn31_Qy5GmvF8PVhOr9QuJID",
  senderId: "IPHzK5B5DTTT#8gn31",
  senderName: "Sibiyon",
  senderPhotoUrl: "https://...",
  text: "Hello!",
  timestamp: Timestamp,
  status: "sent",                            // sending | sent | delivered | read
  readBy: ["IPHzK5B5DTTT#8gn31"],           // Array of user IDs who read
  imageUrl: null,                            // Optional image
  fileUrl: null,                             // Optional file
  fileName: null                             // Optional file name
}
```

---

## 🎨 UI Flow

### 1. Messages Screen - Chats Tab
```
┌─────────────────────────────────────┐
│ ← Messages                          │
├─────────────────────────────────────┤
│ [Chats]    Requests                 │
├─────────────────────────────────────┤
│                                     │
│ ┌─────────────────────────────────┐│
│ │ 🎯 Building Admin               ││
│ │    Get help and support    →   ││
│ └─────────────────────────────────┘│
│                                     │
│         💬                          │
│      No chats yet                   │
│  Start a conversation with          │
│  building members                   │
│                                     │
│                              [+]    │  ← Tap to see members
└─────────────────────────────────────┘
```

### 2. Building Members Dialog
```
┌─────────────────────────────────────┐
│ 👥 Building Members            [X]  │
├─────────────────────────────────────┤
│ 1 member in your building           │
│                                     │
│ ┌─────────────────────────────────┐│
│ │ 👤 Preetham                     ││
│ │    Flat Unknown                 ││
│ │    Building: Tower A            ││
│ │                          💬     ││  ← Tap to send request
│ └─────────────────────────────────┘│
└─────────────────────────────────────┘
```

### 3. Request Sent
```
┌─────────────────────────────────────┐
│  ✅ Chat request sent!              │
└─────────────────────────────────────┘
```

### 4. Messages Screen - Requests Tab (Receiver's View)
```
┌─────────────────────────────────────┐
│ ← Messages                          │
├─────────────────────────────────────┤
│ Chats    [Requests]                 │
├─────────────────────────────────────┤
│                                     │
│ ┌─────────────────────────────────┐│
│ │ 👤 Sibiyon                      ││
│ │    Wants to chat with you       ││
│ │                                 ││
│ │  [Accept]        [Reject]       ││  ← Tap Accept
│ └─────────────────────────────────┘│
└─────────────────────────────────────┘
```

### 5. Request Accepted
```
┌─────────────────────────────────────┐
│  ✅ Request accepted!               │
└─────────────────────────────────────┘

Navigates to Chat Conversation Screen
```

### 6. Chat Conversation Screen
```
┌─────────────────────────────────────┐
│ ← Sibiyon                           │
├─────────────────────────────────────┤
│                                     │
│         💬                          │
│      No messages yet                │
│  Start the conversation             │
│                                     │
├─────────────────────────────────────┤
│ [Type a message...]          [Send] │
└─────────────────────────────────────┘
```

### 7. After Sending Messages
```
┌─────────────────────────────────────┐
│ ← Sibiyon                           │
├─────────────────────────────────────┤
│                                     │
│ ┌─────────────────────────────────┐│
│ │ Hello!                          ││  ← Sender's message
│ │                         10:30 AM││
│ └─────────────────────────────────┘│
│                                     │
│ ┌─────────────────────────────────┐│
│ │ Hi there!                       ││  ← Receiver's message
│ │ 10:31 AM                        ││
│ └─────────────────────────────────┘│
│                                     │
├─────────────────────────────────────┤
│ [Type a message...]          [Send] │
└─────────────────────────────────────┘
```

---

## 🧪 Testing

### Test Script
```bash
cd resident_app
flutter run -d ZA222LQT6V lib/test_chat_requests_flow.dart
```

### Test Steps

**Test 1: Fetch Chat Requests**
- Queries Firestore for pending requests
- Shows all requests for current user
- Displays request details

**Test 2: Stream Chat Requests**
- Tests realtime streaming
- Listens for new requests
- Updates UI automatically

**Test 3: Accept Request**
- Accepts first pending request
- Creates chat document
- Verifies chat creation

**Test 4: Direct Firestore Query**
- Runs raw Firestore queries
- Shows all requests (pending and accepted)
- Useful for debugging

---

## 📝 Code Implementation

### Service Method: `sendChatRequest()`

**Location**: `lib/src/services/chat_firestore_service.dart`

```dart
Future<String?> sendChatRequest({
  required String toUserId,
  required String toUserName,
  String? message,
}) async {
  // Step 1: Get current user data
  final userId = await _getCurrentUserId();
  final userData = await _getCurrentUserData();
  
  // Step 2: Check if request already exists
  final existingRequest = await _firestore
      .collection(chatRequestsCollection)
      .where('senderId', isEqualTo: userId)
      .where('receiverId', isEqualTo: toUserId)
      .where('status', isEqualTo: 'pending')
      .get();
  
  if (existingRequest.docs.isNotEmpty) {
    return existingRequest.docs.first.id;
  }
  
  // Step 3: Check if chat already exists
  final existingChat = await _findExistingDirectChat(userId, toUserId);
  if (existingChat != null) {
    return null; // Chat exists
  }
  
  // Step 4: Create request
  final requestData = {
    'senderId': userId,
    'senderName': userData['name'] ?? 'Unknown',
    'senderPhoto': userData['photoUrl'] ?? userData['profileImage'],
    'receiverId': toUserId,
    'receiverName': toUserName,
    'flatId': userFlatId,
    'status': 'pending',
    'createdAt': FieldValue.serverTimestamp(),
  };
  
  final docRef = await _firestore
      .collection(chatRequestsCollection)
      .add(requestData);
  
  return docRef.id;
}
```

### Service Method: `streamIncomingChatRequests()`

**Location**: `lib/src/services/chat_firestore_service.dart`

```dart
Stream<List<ChatRequestModel>> streamIncomingChatRequests() async* {
  // Step 1: Get current user ID
  final userId = await _getCurrentUserId();
  
  if (userId == null) {
    yield [];
    return;
  }
  
  // Step 2: Stream requests
  yield* _firestore
      .collection(chatRequestsCollection)
      .where('receiverId', isEqualTo: userId)
      .where('status', isEqualTo: 'pending')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .handleError((error) {
        // Handle Firestore index errors
        if (error.toString().contains('index')) {
          print('⚠️  Missing Firestore index');
        }
      })
      .map((snapshot) {
        return snapshot.docs
            .map((doc) => ChatRequestModel.fromFirestore(doc))
            .toList();
      });
}
```

### Service Method: `acceptChatRequest()`

**Location**: `lib/src/services/chat_firestore_service.dart`

```dart
Future<String?> acceptChatRequest(String requestId) async {
  // Step 1: Get request
  final requestDoc = await _firestore
      .collection(chatRequestsCollection)
      .doc(requestId)
      .get();
  
  if (!requestDoc.exists) {
    return null;
  }
  
  final requestData = requestDoc.data() as Map<String, dynamic>;
  final senderId = requestData['senderId'];
  final senderName = requestData['senderName'];
  final flatId = requestData['flatId'];
  
  // Step 2: Update request status
  await _firestore
      .collection(chatRequestsCollection)
      .doc(requestId)
      .update({
        'status': 'accepted',
        'respondedAt': FieldValue.serverTimestamp(),
      });
  
  // Step 3: Create chat
  final userId = await _getCurrentUserId();
  if (userId == null) return null;
  
  final participantIds = [senderId, userId]..sort();
  final chatId = '${participantIds[0]}_${participantIds[1]}';
  
  // Check if chat already exists
  final existingChat = await _firestore
      .collection(chatsCollection)
      .doc(chatId)
      .get();
  
  if (!existingChat.exists) {
    final now = FieldValue.serverTimestamp();
    
    await _firestore.collection(chatsCollection).doc(chatId).set({
      'chatId': chatId,
      'participants': participantIds,
      'participantIds': participantIds,
      'flatId': flatId,
      'type': 'resident',
      'isGroup': false,
      'title': senderName,
      'lastMessage': null,
      'lastMessageTime': null,
      'unreadCount': 0,
      'createdAt': now,
      'updatedAt': now,
    });
  }
  
  return chatId;
}
```

---

## 🔍 Console Output

### Sending Request:
```
📝 ChatService: Creating new chat request
✅ ChatService: Chat request sent: 1WHI32XhbwlWe8ymIIeXs
```

### Fetching Requests:
```
📡 ChatService: Streaming incoming chat requests for user: Qy5GmvF8PVhOr9QuJID
📊 ChatService: Received 1 chat requests
```

### Accepting Request:
```
✅ ChatService: Chat request accepted
✅ ChatService: Chat created: IPHzK5B5DTTT#8gn31_Qy5GmvF8PVhOr9QuJID
```

---

## ✅ Verification Checklist

- [x] Chat requests stored in Firestore
- [x] Requests fetched correctly by receiverId
- [x] Realtime streaming works
- [x] Accept creates chat document
- [x] Chat conversation opens after acceptance
- [x] Messages can be sent and received
- [x] UI shows requests in Requests tab
- [x] Error handling for missing index
- [x] Duplicate request prevention
- [x] Existing chat detection

---

## 🐛 Troubleshooting

### Issue: Requests not showing

**Check**:
1. Is receiverId correct in Firestore?
2. Is status "pending"?
3. Check console for errors

**Solution**: Run test script to diagnose

### Issue: Firestore index error

**Error**: "The query requires an index"

**Solution**: Create composite index
- Collection: `chatRequests`
- Fields: `receiverId` (Asc), `status` (Asc), `createdAt` (Desc)

### Issue: Chat not created after acceptance

**Check**:
1. Check console for errors
2. Verify chat document in Firestore
3. Check participantIds are correct

**Solution**: Run Test 3 in test script

---

## 📚 Related Files

- `lib/src/services/chat_firestore_service.dart` - Service implementation
- `lib/src/screens/messages_screen_enhanced.dart` - UI implementation
- `lib/src/screens/chat_conversation_screen.dart` - Chat UI
- `lib/src/models/chat_model.dart` - Data models
- `lib/test_chat_requests_flow.dart` - Test script

---

**Status**: ✅ Complete and Working  
**Firestore**: Data stored correctly  
**UI**: Requests showing in Requests tab  
**Flow**: Send → Fetch → Accept → Chat working
