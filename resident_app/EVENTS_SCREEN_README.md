# Events & Announcements Screen

## Overview
Pixel-perfect Flutter implementation of the Events & Announcements screen matching the reference design exactly.

## Features
- ✅ Blue gradient header with back navigation
- ✅ Three-tab switcher (Events | Notices | Polls) with active state
- ✅ Upcoming Events section with large event cards
- ✅ Past Events section with compact horizontal cards
- ✅ Bottom navigation bar with Events tab highlighted
- ✅ Fully scrollable content
- ✅ Responsive design for iPhone 13 (390px width)

## Components

### Main Screen
- `EventsAnnouncementsScreen` - Main stateful widget with tab and navigation state

### Reusable Widgets
- `EventCard` - Large event card with full-width image, title, date/time, attending count, location
- `PastEventCard` - Compact horizontal card with left image and right text section

### Data Model
- `Event` class with sample mock data for upcoming and past events

## Design Specifications

### Colors
- Primary Blue: `#2563EB`
- Section Title: `#111111`
- Subtitle/Icons: `#8C8C8C`
- Light Gray Background: `#F5F5F5`
- Card Background: `#FFFFFF`
- Dividers: `#E6E6E6`

### Typography
- Header Title: 20-22pt Semibold
- Tab Text: 15-16pt Medium
- Section Heading: 17-18pt Semibold
- Event Title: 16-18pt Semibold
- Date/Time/Location: 13-14pt Regular

### Spacing
- Card padding: 16px
- Card spacing: 16px vertical
- Section spacing: 24-32px
- Icon spacing: 8px from text

## Navigation

### From Dashboard
- Tap "Events" in Quick Access section
- Tap "Events" in bottom navigation bar

### Integration
The screen is integrated into the dashboard navigation:
```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => const EventsAnnouncementsScreen(),
  ),
);
```

## Image Assets

### Placeholder URLs Used
The screen uses placeholder images from Unsplash:
- Holi celebration: Festival/celebration images
- Yoga session: Yoga/meditation images
- DJ celebration: Party/music images
- Diwali celebration: Festival lights images

### To Use Custom Images
Replace the `imageUrl` in the `Event` model with your own image URLs or local assets:

```dart
Event(
  title: 'Your Event',
  imageUrl: 'assets/images/your_event.jpg',
  // ... other properties
)
```

Don't forget to add assets to `pubspec.yaml`:
```yaml
flutter:
  assets:
    - assets/images/
```

## Mock Data

The screen includes sample data for:
- 3 upcoming events (Holi, Yoga, DJ Celebration)
- 1 past event (Diwali)

To add more events, extend the `Event.upcomingEvents()` or `Event.pastEvents()` methods.

## Tab Functionality

Currently, the tab bar switches between:
- **Events** (implemented with full UI)
- **Notices** (placeholder - can be implemented similarly)
- **Polls** (placeholder - can be implemented similarly)

The active tab state is managed with `_selectedTab` in the widget state.

## Responsive Design

The screen is designed for iPhone 13 (390px width) but scales responsively:
- Uses `MediaQuery` for dynamic sizing
- `SingleChildScrollView` for content overflow
- Flexible layouts with `Expanded` and `Flexible` widgets
- Maintains aspect ratios for images

## Future Enhancements

Potential additions:
- Event detail screen on card tap
- RSVP/attending functionality
- Calendar integration
- Event search and filters
- Notices and Polls tab content
- Pull-to-refresh
- Skeleton loading states
