# Chat Conversation Screen - Implementation Guide

## Overview
Generic chat conversation screen that works for person-to-person, phone number, and group chats. Fully integrated with the Messages screen.

## File Location
```
lib/src/screens/chat_conversation_screen.dart
```

## Features

### ✅ UI Components
- **Header** - Avatar, title, subtitle, action buttons (call/info), close button
- **Message List** - Incoming/outgoing bubbles with timestamps and status indicators
- **Typing Indicator** - Animated dots when other person is typing
- **Input Bar** - Text field with send button
- **Status Icons** - Sending, sent, delivered, read indicators

### ✅ Functionality
- Opens for any conversation (person, phone, group)
- Displays correct header based on conversation type
- Marks messages as read on open
- Real-time message updates via stream
- Optimistic UI for sending messages
- Retry failed messages
- Offline message queueing (stub)
- Auto-scroll to bottom on new messages

## Usage

### From Messages Screen
The integration is already complete! When users tap any message card in the Messages screen, it automatically opens the chat conversation.

### Manual Navigation
```dart
import 'src/screens/chat_conversation_screen.dart';

// Navigate to chat
Navigator.push(
  context,
  ChatConversationScreen.routeFor(
    Conversation(
      id: 'chat_123',
      title: 'Ramesh Kumar',
      subtitle: 'Plumbing Technician',
      icon: Icons.person,
      iconBg: Color(0xFF2563EB),
      isGroup: false,
      unreadCount: 2,
    ),
  ),
);
```

## Conversation Types

### 1. Person-to-Person Chat
```dart
Conversation(
  id: 'person_123',
  title: 'Ramesh Kumar',
  subtitle: 'Plumbing Technician',
  icon: Icons.person,
  iconBg: Color(0xFF2563EB),
  isGroup: false,
)
```

### 2. Phone Number Chat
```dart
Conversation(
  id: 'phone_123',
  title: '+91 98765 43210',
  subtitle: 'Last seen 2 hours ago',
  icon: Icons.phone,
  iconBg: Color(0xFF10B981),
  isGroup: false,
)
```

### 3. Group Chat
```dart
Conversation(
  id: 'group_123',
  title: 'Community Group',
  subtitle: '5 members',
  icon: Icons.groups,
  iconBg: Color(0xFF8B5CF6),
  isGroup: true,
  unreadCount: 9,
)
```

## Models

### Conversation
```dart
class Conversation {
  final String id;
  final String title;        // Name, phone, or group name
  final String? subtitle;    // Role, "5 members", or last seen
  final String? avatarUrl;
  final bool isGroup;
  final int unreadCount;
  final IconData? icon;
  final Color? iconBg;
}
```

### ChatMessage
```dart
class ChatMessage {
  final String id;
  final String senderId;
  final String text;
  final DateTime timestamp;
  final MessageStatus status;  // sending, sent, delivered, read
  final bool isMe;
  final String? imageUrl;
}
```

## Header Behavior

### Person/Phone Chat
- Shows avatar or icon
- Title: Name or phone number
- Subtitle: Role or last seen
- Actions: Call button, Close button

### Group Chat
- Shows group icon
- Title: Group name
- Subtitle: Member count (e.g., "5 members")
- Actions: Info button, Close button

## Message Status Indicators

| Status | Icon | Description |
|--------|------|-------------|
| Sending | Spinner | Message being sent |
| Sent | ✓ | Delivered to server |
| Delivered | ✓✓ | Delivered to recipient |
| Read | ✓✓ (blue) | Read by recipient |

## Real-time Features

### Message Stream
```dart
Stream<ChatEvent> chatStream(String chatId) {
  // Returns stream of:
  // - New messages
  // - Typing indicators
  // - Status updates (delivered/read)
}
```

### Typing Indicator
Shows "Typing..." with animated dots when other person is typing.

### Status Updates
Messages automatically update from sent → delivered → read.

## Backend Integration

### Replace Mock Repository
```dart
class ChatRepository {
  final String baseUrl = 'https://your-api.com/api';
  
  Future<List<ChatMessage>> fetchMessages({
    required String chatId,
    int page = 1,
  }) async {
    final response = await http.get(
      Uri.parse('$baseUrl/chats/$chatId/messages?page=$page'),
      headers: {'Authorization': 'Bearer YOUR_TOKEN'},
    );
    
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((json) => ChatMessage.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load messages');
    }
  }
  
  Future<ChatMessage> sendMessage(String chatId, ChatMessage msg) async {
    final response = await http.post(
      Uri.parse('$baseUrl/chats/$chatId/messages'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer YOUR_TOKEN',
      },
      body: jsonEncode({
        'text': msg.text,
        'timestamp': msg.timestamp.toIso8601String(),
      }),
    );
    
    if (response.statusCode == 201) {
      return ChatMessage.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to send message');
    }
  }
  
  Future<void> markAsRead(String chatId) async {
    await http.post(
      Uri.parse('$baseUrl/chats/$chatId/read'),
      headers: {'Authorization': 'Bearer YOUR_TOKEN'},
    );
  }
}
```

### WebSocket Integration
```dart
import 'package:web_socket_channel/web_socket_channel.dart';

class ChatRepository {
  late WebSocketChannel _channel;
  
  Stream<ChatEvent> chatStream(String chatId) {
    _channel = WebSocketChannel.connect(
      Uri.parse('wss://your-api.com/chats/$chatId'),
    );
    
    return _channel.stream.map((data) {
      final json = jsonDecode(data);
      
      if (json['type'] == 'message') {
        return ChatEvent.message(ChatMessage.fromJson(json['data']));
      } else if (json['type'] == 'typing') {
        return ChatEvent.typing(json['isTyping']);
      } else if (json['type'] == 'status') {
        return ChatEvent.statusUpdate(json['messageId'], json['status']);
      }
      
      throw Exception('Unknown event type');
    });
  }
}
```

## Offline Support

### Queue Messages
```dart
// Use Hive or SQLite for persistence
import 'package:hive/hive.dart';

class ChatRepository {
  late Box<ChatMessage> _queueBox;
  
  Future<void> init() async {
    _queueBox = await Hive.openBox<ChatMessage>('message_queue');
  }
  
  Future<ChatMessage> sendMessage(String chatId, ChatMessage msg) async {
    if (!isOnline) {
      // Queue message for later
      await _queueBox.add(msg);
      throw Exception('No internet. Message queued.');
    }
    
    // Send normally
    return await _sendToServer(chatId, msg);
  }
  
  Future<void> syncQueuedMessages(String chatId) async {
    if (!isOnline) return;
    
    final queued = _queueBox.values.where((m) => m.chatId == chatId).toList();
    
    for (var msg in queued) {
      try {
        await _sendToServer(chatId, msg);
        await _queueBox.delete(msg.key);
      } catch (e) {
        // Keep in queue
      }
    }
  }
}
```

## Customization

### Add Image Attachments
```dart
// Add image_picker package
import 'package:image_picker/image_picker.dart';

Future<void> _pickImage() async {
  final picker = ImagePicker();
  final image = await picker.pickImage(source: ImageSource.gallery);
  
  if (image != null) {
    // Upload image and send message with imageUrl
    final imageUrl = await _uploadImage(File(image.path));
    
    final message = ChatMessage(
      id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
      senderId: 'me',
      text: '',
      timestamp: DateTime.now(),
      status: MessageStatus.sending,
      isMe: true,
      imageUrl: imageUrl,
    );
    
    // Send message
  }
}
```

### Add Voice Messages
```dart
// Add audio_recorder package
import 'package:record/record.dart';

Future<void> _recordVoice() async {
  final recorder = Record();
  
  if (await recorder.hasPermission()) {
    await recorder.start();
    // Show recording UI
    
    // On stop
    final path = await recorder.stop();
    // Upload and send
  }
}
```

### Add @Mentions (Group Chats)
```dart
// Detect @ symbol and show member picker
TextField(
  controller: _messageController,
  onChanged: (text) {
    if (text.endsWith('@')) {
      _showMemberPicker();
    }
  },
)
```

## Testing

### Test Flow
1. Open Messages screen
2. Tap any conversation
3. ✅ Chat screen opens with correct header
4. ✅ Messages load and display
5. Type message and send
6. ✅ Message appears with "sending" status
7. ✅ Status updates to sent → delivered → read
8. Wait 5 seconds
9. ✅ Typing indicator appears
10. ✅ New message arrives
11. Tap back/close
12. ✅ Returns to Messages screen

### Test Different Types
- **Person**: Shows name, role, call button
- **Phone**: Shows number, last seen, call button
- **Group**: Shows group name, member count, info button

## Accessibility

- All tap targets meet 44×44 px minimum
- Text fields have semantic labels
- Message bubbles have proper contrast
- Screen reader support for messages

## Next Steps

1. ✅ Chat conversation screen created
2. ✅ Integrated with Messages screen
3. 🔄 Add real API integration
4. 🔄 Implement WebSocket for real-time
5. 🔄 Add offline message queueing with Hive
6. 🔄 Implement image attachments
7. 🔄 Add voice messages
8. 🔄 Implement @mentions for groups
9. 🔄 Add message search
10. 🔄 Add message deletion

---

**File**: `lib/src/screens/chat_conversation_screen.dart`  
**Assets**: None (uses Material Icons)  
**Usage**: Automatically opens when tapping messages in Messages screen
