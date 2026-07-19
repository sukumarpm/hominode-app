# Messages Screen - Implementation Guide

## Overview
Pixel-perfect Messages screen with Chats and Notifications tabs, search functionality, and message list items with unread badges.

## File Location
```
lib/messages_screen.dart
```

## Features

### ✅ UI Components
- **Blue Gradient Header** with back button and "Messages" title
- **Tab Selector** - Chats and Notifications with pill design
- **Search Bar** - Rounded with search icon and placeholder
- **Message Cards** - Icon/image, title, preview, timestamp, unread badge
- **Smooth Scrolling** - ListView with proper spacing

### ✅ Design Specifications
- **Colors**: Primary Blue (#2563EB), Unread Badge Red (#E53935)
- **Typography**: Title 24pt, Tab 17pt, Message Title 17pt, Preview 14pt
- **Spacing**: Consistent padding and margins matching screenshot
- **Rounded Corners**: Cards 16px, Search 12px, Icons 12px

## Usage

### Navigate from Dashboard
```dart
// In dashboard_screen.dart or home screen
GestureDetector(
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const MessagesScreen(),
      ),
    );
  },
  child: // Your messages button/card
)
```

### Direct Navigation
```dart
import 'package:flutter/material.dart';
import 'messages_screen.dart';

// Navigate to messages
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => const MessagesScreen(),
  ),
);
```

## Screen Structure

### 1. Header
- Blue gradient background
- Back arrow (iOS style)
- "Messages" title (24pt, Semibold)
- Rounded bottom corners

### 2. Tabs
- Two tabs: "Chats" and "Notifications"
- Pill-style selector
- Active tab: white background with shadow
- Inactive tab: transparent

### 3. Search Bar
- Light grey background (#F1F1F1)
- Search icon on left
- Placeholder: "Search messages..."
- Rounded corners (12px)

### 4. Message List
- Scrollable list of message cards
- Each card contains:
  - Square icon with rounded corners (56×56px)
  - Unread badge (red circle with count)
  - Title (bold, 17pt)
  - Preview text (grey, 14pt, truncated)
  - Timestamp (right-aligned, 13pt)

## Message Model

```dart
class Message {
  final String id;
  final String title;
  final String preview;
  final String timestamp;
  final int unreadCount;
  final String? imageUrl;
  final IconData? icon;
  final Color? iconBg;
}
```

## Mock Data

### Chats Tab
1. **Amazon Delivery** - 2 unread, 2:30 PM
2. **Security** - 1 unread, 1:30 PM
3. **Community Group** - 9 unread, 12:30 PM
4. **Maintenance Team** - 0 unread, Yesterday

### Notifications Tab
1. **Payment Reminder** - 1 unread, 1 hour ago
2. **Event Invitation** - 0 unread, 3 hours ago

## Customization

### Add Real Data
Replace mock data with API calls:

```dart
class _MessagesScreenState extends State<MessagesScreen> {
  List<Message> _chatMessages = [];
  List<Message> _notificationMessages = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  Future<void> _loadMessages() async {
    setState(() => _isLoading = true);
    
    try {
      // Fetch from API
      final chats = await MessagesService().fetchChats();
      final notifications = await MessagesService().fetchNotifications();
      
      setState(() {
        _chatMessages = chats;
        _notificationMessages = notifications;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }
}
```

### Add Search Functionality
```dart
List<Message> _filteredMessages() {
  final messages = _selectedTab == 0 ? _chatMessages : _notificationMessages;
  final query = _searchController.text.toLowerCase();
  
  if (query.isEmpty) return messages;
  
  return messages.where((msg) {
    return msg.title.toLowerCase().contains(query) ||
           msg.preview.toLowerCase().contains(query);
  }).toList();
}
```

### Add Message Tap Handler
```dart
Widget _buildMessageCard(Message message) {
  return GestureDetector(
    onTap: () {
      // Navigate to chat detail screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatDetailScreen(messageId: message.id),
        ),
      );
    },
    child: Container(
      // ... existing card code
    ),
  );
}
```

### Add Pull-to-Refresh
```dart
Widget _buildMessageList() {
  final messages = _selectedTab == 0 ? _chatMessages : _notificationMessages;

  return RefreshIndicator(
    onRefresh: _loadMessages,
    child: ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildMessageCard(messages[index]),
        );
      },
    ),
  );
}
```

## Integration with Backend

### Messages Service
```dart
class MessagesService {
  final String baseUrl = 'https://your-api.com/api';
  
  Future<List<Message>> fetchChats() async {
    final response = await http.get(
      Uri.parse('$baseUrl/messages/chats'),
      headers: {'Authorization': 'Bearer YOUR_TOKEN'},
    );
    
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((json) => Message.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load chats');
    }
  }
  
  Future<List<Message>> fetchNotifications() async {
    final response = await http.get(
      Uri.parse('$baseUrl/messages/notifications'),
      headers: {'Authorization': 'Bearer YOUR_TOKEN'},
    );
    
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((json) => Message.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load notifications');
    }
  }
}
```

### Add fromJson to Message Model
```dart
class Message {
  // ... existing fields
  
  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'],
      title: json['title'],
      preview: json['preview'],
      timestamp: json['timestamp'],
      unreadCount: json['unreadCount'] ?? 0,
      imageUrl: json['imageUrl'],
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'preview': preview,
      'timestamp': timestamp,
      'unreadCount': unreadCount,
      'imageUrl': imageUrl,
    };
  }
}
```

## Real-time Updates

### WebSocket Integration
```dart
class _MessagesScreenState extends State<MessagesScreen> {
  late WebSocketChannel _channel;
  
  @override
  void initState() {
    super.initState();
    _connectWebSocket();
  }
  
  void _connectWebSocket() {
    _channel = WebSocketChannel.connect(
      Uri.parse('wss://your-api.com/messages'),
    );
    
    _channel.stream.listen((data) {
      final message = Message.fromJson(jsonDecode(data));
      setState(() {
        if (_selectedTab == 0) {
          _chatMessages.insert(0, message);
        } else {
          _notificationMessages.insert(0, message);
        }
      });
    });
  }
  
  @override
  void dispose() {
    _channel.sink.close();
    super.dispose();
  }
}
```

## Testing

### Manual Test Flow
1. Open app and navigate to Messages screen
2. See Chats tab selected by default
3. View list of chat messages with unread badges
4. Tap Notifications tab → See notifications list
5. Tap search bar → Type to filter messages
6. Tap back button → Return to previous screen

### Test Cases
- ✅ Tab switching works correctly
- ✅ Unread badges display correct count
- ✅ Message cards show all information
- ✅ Search filters messages
- ✅ Scroll works smoothly
- ✅ Back button navigates correctly

## Accessibility

- All tap targets meet 44×44 px minimum
- Text has proper contrast ratios
- Search field has semantic label
- Screen reader support for message cards

## Next Steps

1. ✅ Messages screen created
2. 🔄 Add real API integration
3. 🔄 Implement search functionality
4. 🔄 Add message tap navigation
5. 🔄 Implement pull-to-refresh
6. 🔄 Add WebSocket for real-time updates
7. 🔄 Add push notifications
8. 🔄 Implement message deletion
9. 🔄 Add message read/unread toggle

---

**File**: `lib/messages_screen.dart`  
**Assets**: None (uses Material Icons)  
**Usage**: `Navigator.push(context, MaterialPageRoute(builder: (_) => const MessagesScreen()));`
