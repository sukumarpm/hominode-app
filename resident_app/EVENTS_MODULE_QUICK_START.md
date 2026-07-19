# Events Module - Quick Start Guide

## What's Been Built

✅ **Complete Events Module** with 3 tabs:
- **Events Tab**: Upcoming & past events with detail modals
- **Notices Tab**: Priority-based notices with detail modals  
- **Polls Tab**: Full voting functionality with realtime updates

## File Structure

```
lib/src/
├── models/
│   ├── event.dart
│   ├── notice.dart
│   ├── poll.dart (updated)
│   └── poll_option.dart
├── services/
│   ├── events_repository.dart
│   ├── notices_repository.dart
│   └── poll_repository.dart (existing)
├── components/
│   ├── primary_header.dart
│   ├── pill_tabs.dart
│   ├── event_card.dart
│   ├── notice_card.dart
│   └── poll_card.dart (existing)
├── screens/
│   ├── events_module_screen.dart ← MAIN ENTRY
│   ├── events_tab.dart
│   ├── notices_tab.dart
│   └── polls_tab.dart
└── modals/
    ├── event_detail_modal.dart
    └── notice_detail_modal.dart
```

## How to Use

### 1. Navigate to Events Module

```dart
import 'package:resident_app/src/screens/events_module_screen.dart';

// Open Events Module (default: Events tab)
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => const EventsModuleScreen(),
  ),
);

// Open specific tab (0=Events, 1=Notices, 2=Polls)
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => const EventsModuleScreen(initialTab: 2),
  ),
);
```

### 2. Test Features

**Events Tab:**
- Tap event card → Opens detail modal
- Tap RSVP → Toggles attendance (optimistic update)
- Pull down → Refreshes events

**Notices Tab:**
- Tap notice card → Opens detail modal with full content
- Color-coded by priority (High=Orange, Medium=Blue)

**Polls Tab:**
- Select option → Tap "Vote Now"
- See results with progress bars
- Green "Voted" badge appears

## Key Features

### Tab Switching
- Smooth animated transitions
- Active tab highlighted with white pill
- State preserved per tab

### Modals
- Centered overlay dialogs
- Event modal: Image, details, RSVP button
- Notice modal: Color-coded header, full content

### Voting System
- Optimistic UI updates
- Rollback on error
- Offline queue support
- Realtime updates stream

### Data Flow
```
Repository (mock data) 
    ↓
Tab Screen (state management)
    ↓
Card Component (UI)
    ↓
Modal (detail view)
```

## Mock Data Included

- 3 upcoming events
- 1 past event
- 3 notices (High/Medium priority)
- 2 polls (one votable, one voted)

## Next Steps

Replace mock repositories with real API calls:

```dart
// Example: events_repository.dart
import 'package:http/http.dart' as http;

Future<List<Event>> fetchUpcomingEvents() async {
  final response = await http.get(Uri.parse('$apiUrl/events?tab=upcoming'));
  // Parse and return events
}
```

## Design Specs

- Primary color: #2563EB
- Spacing: Multiples of 4px (4, 8, 12, 16, 24)
- Card radius: 16px
- Tab radius: 24px
- Touch targets: ≥44x44px

## Ready to Use! 🚀

The module works immediately with mock data. Just navigate to `EventsModuleScreen` and start testing!
