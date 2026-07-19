# Events Module - Complete Implementation

## Created Files

### Models (`lib/src/models/`)
- `event.dart` - Event model with JSON serialization
- `notice.dart` - Notice model with priority levels
- `poll_option.dart` - Poll option model (updated)
- `poll.dart` - Poll model (already exists, updated import)

### Services (`lib/src/services/`)
- `events_repository.dart` - Events API with mock data (GET /events?tab=upcoming|past, POST /events/{id}/rsvp)
- `notices_repository.dart` - Notices API with mock data (GET /notices)
- `poll_repository.dart` - Polls API (already exists)

### Components (`lib/src/components/`)
- `primary_header.dart` - Reusable gradient header with back button
- `pill_tabs.dart` - Animated pill-style tab bar
- `event_card.dart` - Event card (large & small variants)
- `notice_card.dart` - Notice card with priority badges
- `poll_card.dart` - Poll card (already exists)

### Screens (`lib/src/screens/`)
- `events_module_screen.dart` - Main screen with tab switching logic
- `events_tab.dart` - Events tab (upcoming & past events)
- `notices_tab.dart` - Notices tab
- `polls_tab.dart` - Polls tab with voting

### Modals (`lib/src/modals/`)
- `event_detail_modal.dart` - Centered event detail overlay with RSVP
- `notice_detail_modal.dart` - Centered notice detail overlay

## Usage Example

```dart
import 'package:resident_app/src/screens/events_module_screen.dart';

// Navigate to Events Module (default: Events tab)
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => const EventsModuleScreen(),
  ),
);

// Navigate to specific tab (0=Events, 1=Notices, 2=Polls)
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => const EventsModuleScreen(initialTab: 2),
  ),
);
```

## Features Implemented

### Tab Switching
- Animated pill tabs with active state
- Smooth content transitions
- State preservation per tab

### Events Tab
- Upcoming events list with full-width cards
- Past events list with compact cards
- Pull-to-refresh
- Event detail modal with RSVP toggle
- Optimistic UI updates

### Notices Tab
- Notice cards with priority badges (High/Medium/Low)
- Color-coded icons and badges
- Notice detail modal with full content
- Pull-to-refresh

### Polls Tab
- Vote view with radio buttons
- Results view with progress bars
- Optimistic voting with rollback
- Realtime updates stream
- Offline queue support
- "Voted" badge display

## API Endpoints

```dart
// Events
GET /events?tab=upcoming -> List<Event>
GET /events?tab=past -> List<Event>
POST /events/{id}/rsvp -> void

// Notices
GET /notices -> List<Notice>

// Polls
GET /polls?page=1 -> List<Poll>
POST /polls/{id}/vote body: { "optionId": "opt_123" } -> Poll
WebSocket /ws/polls -> PollEvent stream
```

## Dependencies

No additional dependencies required beyond standard Flutter SDK.

Optional for production:
```yaml
dependencies:
  http: ^1.1.0  # For API calls
  hive: ^2.2.3  # For offline storage
  connectivity_plus: ^5.0.0  # For connectivity checking
```

## Replacing Mock Data

### Events Repository
```dart
// In lib/src/services/events_repository.dart
import 'package:http/http.dart' as http;
import 'dart:convert';

Future<List<Event>> fetchUpcomingEvents() async {
  final response = await http.get(
    Uri.parse('$baseUrl/events?tab=upcoming'),
    headers: {'Authorization': 'Bearer $token'},
  );
  if (response.statusCode == 200) {
    final List data = json.decode(response.body);
    return data.map((json) => Event.fromJson(json)).toList();
  }
  throw Exception('Failed to load events');
}
```

### Notices Repository
```dart
Future<List<Notice>> fetchNotices() async {
  final response = await http.get(
    Uri.parse('$baseUrl/notices'),
    headers: {'Authorization': 'Bearer $token'},
  );
  if (response.statusCode == 200) {
    final List data = json.decode(response.body);
    return data.map((json) => Notice.fromJson(json)).toList();
  }
  throw Exception('Failed to load notices');
}
```

## Design Tokens

```dart
// Colors
const kPrimaryBlue = Color(0xFF2563EB);
const kBackground = Color(0xFFFFFFFF);
const kSectionTitle = Color(0xFF111111);
const kSubtitle = Color(0xFF8C8C8C);
const kCardBorder = Color(0xFFE6E6E6);

// Spacing (multiples of 4)
const kSpacing4 = 4.0;
const kSpacing8 = 8.0;
const kSpacing12 = 12.0;
const kSpacing16 = 16.0;
const kSpacing24 = 24.0;

// Radii
const kCardRadius = 16.0;
const kTabRadius = 24.0;
```

## Summary

Complete Events Module with 3 tabs (Events/Notices/Polls), working tab switching, modal overlays, optimistic updates, and production-ready code structure. All components are modular and reusable. Mock data included for immediate testing.
