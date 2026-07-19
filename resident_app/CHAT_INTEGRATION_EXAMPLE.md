# Chat with Technician - Integration Example

## Quick Start

The chat feature is now fully integrated with the complaints system. When a user taps "Chat With Technician" in the complaint detail modal, they'll be taken to a full-screen chat interface.

## How It Works

### 1. From Complaints Screen
```dart
// In complaints_screen.dart - when user taps a complaint card
onTap: () {
  showComplaintDetailModal(
    context,
    complaint,
    onChat: () {
      // Optional: Track analytics, refresh data, etc.
      print('User opened chat for complaint ${complaint.id}');
    },
  );
}
```

### 2. Complaint Detail Modal Opens
The modal shows complaint details with a "Chat With Technician" button at the bottom.

### 3. Chat Screen Opens
When the button is tapped:
- Modal closes
- Full-screen chat opens with technician details
- Chat ID is automatically set to `complaint_${complaint.id}`
- Technician role is determined from complaint category

## Technician Role Mapping

The system automatically assigns the correct technician role based on complaint category:

| Complaint Category | Technician Role |
|-------------------|-----------------|
| Plumbing | Plumbing Technician |
| Electrical | Electrical Technician |
| Maintenance | Maintenance Technician |
| Cleaning | Cleaning Staff |
| Security | Security Personnel |
| Other | Support Staff |

## Testing the Flow

1. Open the app and navigate to Complaints screen
2. Tap any complaint card
3. Complaint detail modal appears
4. Scroll to bottom and tap "Chat With Technician"
5. Chat screen opens with sample conversation
6. Type a message and tap send
7. Watch the message status change: sending → sent → delivered → read
8. After 5 seconds, typing indicator appears
9. After 7 seconds, new message from technician arrives

## Customization

### Change Technician Name/Avatar
Edit the `_handleChatPressed()` method in `complaint_detail_modal.dart`:

```dart
ChatWithTechnicianScreen(
  chatId: 'complaint_${widget.complaint.id}',
  technicianName: widget.complaint.assignedTechnician?.name ?? 'Ramesh Kumar',
  technicianRole: _getTechnicianRole(widget.complaint.category),
  technicianAvatar: widget.complaint.assignedTechnician?.avatarUrl,
)
```

### Add Real-time Data
If your `Complaint` model has assigned technician info:

```dart
class Complaint {
  final String id;
  final String title;
  final AssignedTechnician? assignedTechnician;
  // ... other fields
}

class AssignedTechnician {
  final String id;
  final String name;
  final String role;
  final String? avatarUrl;
  final String? phoneNumber;
}
```

Then update the navigation:

```dart
final tech = widget.complaint.assignedTechnician;
if (tech == null) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('No technician assigned yet')),
  );
  return;
}

Navigator.push(
  context,
  MaterialPageRoute(
    fullscreenDialog: true,
    builder: (_) => ChatWithTechnicianScreen(
      chatId: 'complaint_${widget.complaint.id}',
      technicianName: tech.name,
      technicianRole: tech.role,
      technicianAvatar: tech.avatarUrl,
    ),
  ),
);
```

## Backend Integration Checklist

- [ ] Create chat API endpoints:
  - `GET /api/chats/{chatId}/messages` - Fetch message history
  - `POST /api/chats/{chatId}/messages` - Send new message
  - `WS /api/chats/{chatId}/stream` - WebSocket for real-time updates

- [ ] Update Complaint model to include:
  - `assignedTechnician` field
  - `chatId` field (if different from `complaint_${id}`)

- [ ] Add push notifications for:
  - New messages when app is in background
  - Technician typing indicators
  - Message read receipts

- [ ] Implement offline storage:
  - Use Hive or SQLite to queue messages when offline
  - Sync when connection restored

- [ ] Add image/file attachments:
  - Uncomment attachment button in chat screen
  - Implement file picker and upload logic
  - Display image previews in message bubbles

## Files Modified

1. ✅ `lib/src/screens/chat_with_technician_screen.dart` - New chat UI
2. ✅ `lib/src/modals/complaint_detail_modal.dart` - Added chat navigation
3. ✅ `CHAT_WITH_TECHNICIAN_README.md` - Full documentation
4. ✅ `CHAT_INTEGRATION_EXAMPLE.md` - This file

## Next Steps

1. Test the flow end-to-end
2. Replace mock `ChatRepository` with real API calls
3. Add WebSocket connection for real-time messaging
4. Implement push notifications
5. Add offline message queueing with Hive
6. (Optional) Enable image attachments
7. (Optional) Add voice message support
8. (Optional) Add message search functionality

---

**Status**: ✅ Ready to use with mock data  
**Production Ready**: 🔄 Requires backend integration
