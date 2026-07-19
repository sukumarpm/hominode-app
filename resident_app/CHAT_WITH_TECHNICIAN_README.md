# Chat with Technician - Implementation Guide

## Overview
Pixel-perfect chat UI matching the design screenshot with production-ready features: real-time messaging, optimistic UI, read receipts, typing indicators, offline queueing, and retry logic.

## File Location
```
lib/src/screens/chat_with_technician_screen.dart
```

## Usage Example

### Basic Integration (from Complaint Detail Modal)
```dart
import 'package:flutter/material.dart';
import 'src/screens/chat_with_technician_screen.dart';

// Inside your complaint detail modal or screen
ElevatedButton(
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatWithTechnicianScreen(
          chatId: 'complaint_${complaint.id}',
          technicianName: 'Ramesh Kumar',
          technicianRole: 'Plumbing Technician',
        ),
      ),
    );
  },
  child: const Text('Chat with Technician'),
)
```

### Full-Screen Modal (Recommended)
```dart
Navigator.push(
  context,
  MaterialPageRoute(
    fullscreenDialog: true,
    builder: (_) => ChatWithTechnicianScreen(
      chatId: complaint.chatId,
      technicianName: complaint.assignedTechnician.name,
      technicianRole: complaint.assignedTechnician.role,
      technicianAvatar: complaint.assignedTechnician.avatarUrl,
    ),
  ),
);
```

## Features Implemented

### ✅ UI Components
- **Header**: Avatar, technician name/role, close button
- **Message Bubbles**: Incoming (white) and outgoing (blue) with proper alignment
- **Timestamps**: Formatted as "10:30 AM" below each message
- **Status Icons**: Sending (spinner), sent (✓), delivered (✓✓), read (✓✓ blue)
- **Input Bar**: Text field with send button, keyboard-safe
- **Typing Indicator**: Animated dots when technician is typing

### ✅ Functionality
- **Optimistic UI**: Messages appear instantly, update on server response
- **Real-time Stream**: Mock WebSocket via `chatStream()` for incoming messages
- **Read Receipts**: Auto-update message status (sent → delivered → read)
- **Offline Queue**: Messages queued when offline, synced when online
- **Retry Logic**: Failed messages show retry option via SnackBar
- **Auto-scroll**: Scrolls to bottom on new messages
- **Keyboard Handling**: Safe area and resize handling

## Mock Data
The screen includes sample conversation matching the screenshot:
1. Incoming: "Hello! I have checked the issue..." (10:30 AM)
2. Outgoing: "Thank you! Please bring..." (10:35 AM)
3. Incoming: "Sure, I have all the required..." (10:36 AM)

## Integration with Real Backend

### Replace Mock Repository
```dart
// Current: lib/src/screens/chat_with_technician_screen.dart (line ~80)
class ChatRepository {
  // TODO: Replace with your API service
  final ApiService _api = ApiService();
  final WebSocketService _ws = WebSocketService();
  
  Future<List<ChatMessage>> fetchMessages({required String chatId, int page = 1}) async {
    final response = await _api.get('/chats/$chatId/messages?page=$page');
    return (response.data as List)
        .map((json) => ChatMessage.fromJson(json))
        .toList();
  }
  
  Future<ChatMessage> sendMessage(String chatId, ChatMessage msg) async {
    final response = await _api.post('/chats/$chatId/messages', {
      'text': msg.text,
      'timestamp': msg.timestamp.toIso8601String(),
    });
    return ChatMessage.fromJson(response.data);
  }
  
  Stream<ChatEvent> chatStream(String chatId) {
    return _ws.connect('/chats/$chatId').map((event) {
      // Parse WebSocket events into ChatEvent objects
      if (event['type'] == 'message') {
        return ChatEvent.message(ChatMessage.fromJson(event['data']));
      } else if (event['type'] == 'typing') {
        return ChatEvent.typing(event['isTyping']);
      } else if (event['type'] == 'status') {
        return ChatEvent.statusUpdate(event['messageId'], event['status']);
      }
      throw Exception('Unknown event type');
    });
  }
}
```

### Add Persistence (Offline Queue)
```dart
// Use Hive or SQLite for local storage
import 'package:hive/hive.dart';

class ChatRepository {
  late Box<ChatMessage> _queueBox;
  
  Future<void> init() async {
    _queueBox = await Hive.openBox<ChatMessage>('chat_queue');
  }
  
  Future<void> syncQueuedMessages(String chatId) async {
    final queued = _queueBox.values.where((m) => m.chatId == chatId).toList();
    
    for (var msg in queued) {
      try {
        await sendMessage(chatId, msg);
        await _queueBox.delete(msg.id);
      } catch (e) {
        // Keep in queue, retry later
      }
    }
  }
}
```

### Push Notifications
```dart
// Handle incoming messages when app is in background
// In your Firebase messaging handler:
FirebaseMessaging.onMessage.listen((RemoteMessage message) {
  if (message.data['type'] == 'chat_message') {
    // Update local chat state or show notification
    final chatId = message.data['chatId'];
    final newMessage = ChatMessage.fromJson(message.data['message']);
    
    // If chat screen is open, stream will handle it
    // Otherwise, show local notification
  }
});
```

## Required Assets
No external assets required. Uses Material Icons:
- `Icons.close` (header close button)
- `Icons.send` (send button)
- `Icons.check` (sent status)
- `Icons.done_all` (delivered/read status)
- `Icons.attach_file` (optional attachment - currently commented out)

## Customization

### Colors
Edit constants at top of file (line 8-17):
```dart
const Color kPrimary = Color(0xFF2563EB);  // Change primary blue
const Color kIncomingBubbleBg = Color(0xFFFFFFFF);
const Color kOutgoingBubbleBg = Color(0xFF2563EB);
```

### Bubble Styling
```dart
const double kBubbleRadius = 16.0;  // Corner radius
const double kBubbleMaxWidth = 0.72;  // 72% of screen width
```

### Enable Attachments
Uncomment lines 450-463 in `_buildMessageInput()` to add attachment button.

## Testing

### Manual Test Flow
1. Open chat screen
2. Type message and send → should appear instantly with "sending" status
3. Wait 1 second → status changes to "delivered"
4. Wait 3 seconds → status changes to "read"
5. Wait 5 seconds → typing indicator appears
6. Wait 7 seconds → new incoming message arrives

### Unit Tests (Optional)
```dart
// test/chat_utils_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:resident_app/src/screens/chat_with_technician_screen.dart';

void main() {
  test('formatTimestamp returns correct format', () {
    final dt = DateTime(2024, 1, 1, 14, 30);
    expect(formatTimestamp(dt), '2:30 PM');
  });
  
  test('formatTimestamp handles AM correctly', () {
    final dt = DateTime(2024, 1, 1, 10, 5);
    expect(formatTimestamp(dt), '10:05 AM');
  });
}
```

## Performance Notes
- Uses `ListView.builder` for efficient rendering of large message lists
- Stream subscription properly disposed in `dispose()`
- Optimistic UI prevents blocking on network calls
- Auto-scroll only triggers when new messages arrive

## Accessibility
- All interactive elements have minimum 44×44 tap targets
- Text fields have semantic labels (handled by Material TextField)
- Color contrast meets WCAG AA standards (blue #2563EB on white)

## Next Steps
1. ✅ Drop file into `lib/src/screens/`
2. ✅ Import and navigate from complaint detail modal
3. 🔄 Replace `ChatRepository` mock with real API calls
4. 🔄 Add Hive/SQLite for offline persistence
5. 🔄 Integrate WebSocket or Firebase for real-time updates
6. 🔄 Add push notification handling
7. 🔄 (Optional) Enable image attachments

---

**File**: `lib/src/screens/chat_with_technician_screen.dart`  
**Assets**: None (uses Material Icons)  
**Usage**: `Navigator.push(context, MaterialPageRoute(builder: (_) => ChatWithTechnicianScreen(chatId: 'complaint_123')));`
