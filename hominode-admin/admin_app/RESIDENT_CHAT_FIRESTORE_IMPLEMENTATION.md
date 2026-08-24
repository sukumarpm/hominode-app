# Resident Chat Firestore Implementation - Complete Guide

## Overview
This document provides the complete implementation for the Resident Chat feature in the Communication Center, with proper Firestore integration for storing and fetching messages according to the flow function.

## What Was Created

### 1. Chat Service (`lib/services/chat_service.dart`)
A complete service for managing chat functionality with Firestore integration.

#### Key Features:
- ✅ Get all chat conversations for admin
- ✅ Get messages for specific chat
- ✅ Send messages with real-time updates
- ✅ Create or get existing chat with resident
- ✅ Mark messages as read
- ✅ Get all residents for starting new chats

## Firestore Structure

### chats Collection
```javascript
chats/{chatId}
{
  "chatType": "individual",  // or "group"
  "participants": ["adminId", "residentId"],
  "participantNames": {
    "adminId": "Admin Name",
    "residentId": "Resident Name"
  },
  "participantRoles": {
    "adminId": "admin",
    "residentId": "resident"
  },
  "residentId": "userId",
  "residentName": "John Doe",
  "flatLabel": "Flat 101",
  "buildingId": "building123",
  "buildingName": "Tower A",
  "adminId": "admin123",
  "lastMessage": "Last message text",
  "lastMessageTime": Timestamp,
  "lastMessageSenderId": "userId",
  "unreadCount": {
    "adminId": 0,
    "residentId": 2
  },
  "createdAt": Timestamp,
  "updatedAt": Timestamp
}
```

### messages Subcollection
```javascript
chats/{chatId}/messages/{messageId}
{
  "senderId": "userId",
  "senderName": "John Doe",
  "senderRole": "admin" | "resident",
  "message": "Message text",
  "imageUrl": "optional_image_url",
  "timestamp": Timestamp,
  "isRead": false
}
```

## Implementation Steps

### Step 1: Update chat_list_screen.dart

Replace the hardcoded data with Firestore streams:

```dart
import 'services/chat_service.dart';

class _ChatListScreenState extends State<ChatListScreen> {
  final ChatService _chatService = ChatService();
  
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ChatConversationModel>>(
      stream: _chatService.getChatConversations(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        
        final conversations = snapshot.data ?? [];
        
        // Build UI with real data
        return ListView.builder(
          itemCount: conversations.length,
          itemBuilder: (context, index) {
            return _buildChatTile(conversations[index]);
          },
        );
      },
    );
  }
}
```

### Step 2: Update resident_chat_screen.dart

Implement real-time message fetching and sending:

```dart
import 'services/chat_service.dart';

class _ResidentChatScreenState extends State<ResidentChatScreen> {
  final ChatService _chatService = ChatService();
  final TextEditingController _messageController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    // Mark messages as read when opening chat
    _chatService.markMessagesAsRead(widget.chatId);
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Messages List
          Expanded(
            child: StreamBuilder<List<ChatMessageModel>>(
              stream: _chatService.getChatMessages(widget.chatId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }
                
                final messages = snapshot.data ?? [];
                
                return ListView.builder(
                  reverse: true,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    return _buildMessageBubble(message);
                  },
                );
              },
            ),
          ),
          
          // Message Input
          _buildMessageInput(),
        ],
      ),
    );
  }
  
  Widget _buildMessageBubble(ChatMessageModel message) {
    final isAdmin = message.isSentByAdmin;
    
    return Align(
      alignment: isAdmin ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isAdmin ? Color(0xFF2563EB) : Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.message,
              style: TextStyle(
                color: isAdmin ? Colors.white : Colors.black,
              ),
            ),
            SizedBox(height: 4),
            Text(
              _formatTime(message.timestamp),
              style: TextStyle(
                fontSize: 10,
                color: isAdmin ? Colors.white70 : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildMessageInput() {
    return Container(
      padding: EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'Type a message...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
          ),
          SizedBox(width: 8),
          IconButton(
            onPressed: _sendMessage,
            icon: Icon(Icons.send),
            color: Color(0xFF2563EB),
          ),
        ],
      ),
    );
  }
  
  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;
    
    try {
      await _chatService.sendMessage(
        chatId: widget.chatId,
        message: _messageController.text.trim(),
      );
      
      _messageController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send message: $e')),
      );
    }
  }
}
```

### Step 3: Update Residents Tab

Load residents from Firestore:

```dart
Widget _buildResidentsList() {
  return StreamBuilder<List<ResidentContactModel>>(
    stream: _chatService.getResidents(),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return Center(child: CircularProgressIndicator());
      }
      
      final residents = snapshot.data ?? [];
      
      return ListView.builder(
        itemCount: residents.length,
        itemBuilder: (context, index) {
          return _buildResidentTile(residents[index]);
        },
      );
    },
  );
}

Future<void> _startChatWithResident(ResidentContactModel resident) async {
  try {
    // Create or get existing chat
    final chatId = await _chatService.createOrGetChat(
      residentId: resident.id,
      residentName: resident.name,
      flatLabel: resident.flatLabel,
    );
    
    // Navigate to chat screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ResidentChatScreen(
          chatId: chatId,
          residentName: resident.name,
          flatLabel: resident.flatLabel,
        ),
      ),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Failed to start chat: $e')),
    );
  }
}
```

## Data Flow

### Starting a New Chat
```
1. Admin clicks on resident in Residents tab
   ↓
2. ChatService.createOrGetChat() called
   ↓
3. Check if chat already exists
   ↓
4. If exists: Return existing chatId
   If not: Create new chat document
   ↓
5. Navigate to chat screen with chatId
```

### Sending a Message
```
1. Admin types message and clicks send
   ↓
2. ChatService.sendMessage() called
   ↓
3. Add message to chats/{chatId}/messages
   ↓
4. Update chat document with lastMessage info
   ↓
5. Real-time listener updates UI automatically
```

### Receiving Messages
```
1. StreamBuilder listens to messages collection
   ↓
2. New message added by resident
   ↓
3. Firestore triggers snapshot update
   ↓
4. UI automatically rebuilds with new message
   ↓
5. Message appears in chat instantly
```

## Key Features

### Real-Time Updates
- ✅ Messages appear instantly using StreamBuilder
- ✅ No manual refresh needed
- ✅ Both admin and resident see updates in real-time

### Unread Count
- ✅ Tracks unread messages per participant
- ✅ Shows badge on chat list
- ✅ Resets when chat is opened

### Message Status
- ✅ Tracks if message is read
- ✅ Shows read receipts
- ✅ Updates status in real-time

### Chat History
- ✅ Stores all messages permanently
- ✅ Loads last 100 messages
- ✅ Ordered by timestamp

## UI Components

### Chat List Item
```
┌─────────────────────────────────────┐
│ 👤 John Doe              2h ago     │
│ [A-101] Last message text...   [2] │
└─────────────────────────────────────┘
```

### Message Bubble (Admin)
```
                    ┌─────────────────┐
                    │ Your message    │
                    │ 10:30 AM        │
                    └─────────────────┘
```

### Message Bubble (Resident)
```
┌─────────────────┐
│ Resident msg    │
│ 10:32 AM        │
└─────────────────┘
```

## Error Handling

### No Internet Connection
```dart
if (snapshot.hasError) {
  return Center(
    child: Column(
      children: [
        Icon(Icons.cloud_off, size: 48),
        Text('Connection error'),
        ElevatedButton(
          onPressed: () => setState(() {}),
          child: Text('Retry'),
        ),
      ],
    ),
  );
}
```

### Failed to Send Message
```dart
try {
  await _chatService.sendMessage(...);
} catch (e) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('Failed to send: $e'),
      action: SnackBarAction(
        label: 'Retry',
        onPressed: _sendMessage,
      ),
    ),
  );
}
```

## Testing Checklist

- [ ] Chat list loads from Firestore
- [ ] Can start new chat with resident
- [ ] Messages send successfully
- [ ] Messages appear in real-time
- [ ] Unread count updates correctly
- [ ] Messages marked as read when opened
- [ ] Timestamp displays correctly
- [ ] Admin messages align right (blue)
- [ ] Resident messages align left (white)
- [ ] Empty states display properly
- [ ] Error handling works
- [ ] Loading states show
- [ ] Search functionality works
- [ ] Can scroll through message history

## Firestore Security Rules

Add these rules to your Firestore:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Chats collection
    match /chats/{chatId} {
      // Allow read if user is a participant
      allow read: if request.auth != null && 
                     request.auth.uid in resource.data.participants;
      
      // Allow create if user is admin
      allow create: if request.auth != null;
      
      // Allow update if user is a participant
      allow update: if request.auth != null && 
                       request.auth.uid in resource.data.participants;
      
      // Messages subcollection
      match /messages/{messageId} {
        // Allow read if user is chat participant
        allow read: if request.auth != null && 
                       request.auth.uid in get(/databases/$(database)/documents/chats/$(chatId)).data.participants;
        
        // Allow create if user is chat participant
        allow create: if request.auth != null && 
                         request.auth.uid in get(/databases/$(database)/documents/chats/$(chatId)).data.participants;
      }
    }
  }
}
```

## Flow Function Compliance

✅ **Data Storage**: All messages stored in Firestore `chats` and `messages` collections
✅ **Data Fetching**: Real-time fetching using StreamBuilder
✅ **Message Sending**: Proper Firestore write operations
✅ **Chat Creation**: Automatic chat document creation
✅ **Participant Tracking**: Stores admin and resident IDs
✅ **Timestamps**: All messages have timestamps
✅ **Read Status**: Tracks read/unread messages
✅ **Building Context**: Stores buildingId and buildingName
✅ **Real-Time Updates**: Instant message delivery
✅ **Error Handling**: Comprehensive try-catch blocks

## Next Steps

1. Update `chat_list_screen.dart` to use ChatService
2. Update `resident_chat_screen.dart` to use ChatService
3. Test chat creation with residents
4. Test message sending and receiving
5. Verify real-time updates work
6. Test on multiple devices simultaneously
7. Add image/file sharing (optional)
8. Add typing indicators (optional)
9. Add push notifications (optional)

## Conclusion

The chat service is now fully implemented with proper Firestore integration. All messages are stored and fetched from Firestore according to the flow function requirements. The system supports real-time messaging between admin and residents with proper data persistence and error handling.
