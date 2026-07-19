# Event Detail Modal

## Overview
Pixel-perfect Flutter implementation of the Event Details modal overlay matching the reference design exactly.

## Features
- ✅ Centered modal overlay with dim background
- ✅ Full-width event image header with rounded top corners
- ✅ Close (X) button in top-right with white circular background
- ✅ Event title centered below image
- ✅ Event description paragraph
- ✅ Icon rows for date/time, location, time, and attendees
- ✅ Full-width RSVP button in primary blue
- ✅ Smooth fade and scale entrance/exit animations
- ✅ RSVP state toggle with confirmation snackbar
- ✅ Scrollable content for small screens
- ✅ Responsive design for iPhone 13 (390px width)

## Components

### Main Modal
- `EventDetailModal` - Stateful widget with animation controller
- `showEventDetailModal()` - Helper function to display modal

### Reusable Widgets
- `HeaderImage` - Full-width event image with rounded top corners
- `IconMetaRow` - Row with icon and text for event metadata
- `PrimaryButton` - Large RSVP button with custom styling

### Data Model
- `EventDetail` - Complete event data model with all fields
- Includes helper methods for formatted strings

## Design Specifications

### Colors
- Primary Blue: `#2563EB` (RSVP button)
- Modal Background: `#FFFFFF`
- Overlay Dim: `rgba(0,0,0,0.36)`
- Title Text: `#111111`
- Meta Text: `#6D6D6D`

### Typography
- Modal Title: 22pt Semibold, centered
- Description: 16pt Regular
- Meta Lines: 15pt Regular
- RSVP Button: 18pt Medium, white

### Spacing
- Modal padding: 24px horizontal, 20px vertical
- Content spacing: 16px between sections
- Icon spacing: 12px from text
- Button height: 56px

### Animations
- Duration: 250ms
- Entrance: Fade + scale with easeOutCubic curve
- Exit: Reverse animation before dismiss

## Usage

### Basic Usage
```dart
import 'event_detail_modal.dart';

// Show modal with event details
showEventDetailModal(
  context,
  EventDetail.sample(),
  onRsvp: (event) {
    print('RSVP for: ${event.title}');
    // Handle RSVP logic
  },
);
```

### Integration with Event Cards
The modal is automatically shown when tapping event cards in the Events & Announcements screen:

```dart
GestureDetector(
  onTap: () {
    showEventDetailModal(
      context,
      event.toEventDetail(),
      onRsvp: (eventDetail) {
        // Handle RSVP
      },
    );
  },
  child: EventCard(event: event),
)
```

## Event Model Conversion

The `Event` class includes a `toEventDetail()` method to convert list events to detailed modal data:

```dart
EventDetail toEventDetail() {
  final timeParts = time.split(' - ');
  return EventDetail(
    id: id,
    title: title,
    description: description,
    imageUrl: imageUrl,
    date: date,
    startTime: timeParts[0],
    endTime: timeParts[1],
    location: location,
    attendees: attendingCount,
    capacity: capacity,
  );
}
```

## RSVP Functionality

### State Management
- RSVP state is tracked in `EventDetail.isRsvped`
- Tapping RSVP button toggles the state
- Button text changes: "RSVP Now" ↔ "Cancel RSVP"
- Button color changes: Blue (active) ↔ Gray (cancelled)

### Callback
The `onRsvp` callback is triggered when RSVP state changes:

```dart
void _handleRsvp() {
  setState(() {
    widget.event.isRsvped = !widget.event.isRsvped;
  });
  
  if (widget.onRsvp != null) {
    widget.onRsvp!(widget.event);
  }
  
  // Show confirmation
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('RSVP confirmed')),
  );
}
```

## Icon Assets

### Current Implementation
Uses Material Icons as placeholders:
- `Icons.calendar_today_outlined` - Date
- `Icons.location_on_outlined` - Location
- `Icons.access_time_outlined` - Time
- `Icons.people_outline` - Attendees
- `Icons.close` - Close button

### Custom Icons (Optional)
To use custom icons, export these assets:
- `assets/icons/icon-calendar.svg`
- `assets/icons/icon-location.svg`
- `assets/icons/icon-clock.svg`
- `assets/icons/icon-attendees.svg`
- `assets/icons/icon-close.svg`

Add to `pubspec.yaml`:
```yaml
dependencies:
  flutter_svg: ^2.0.9

flutter:
  assets:
    - assets/icons/
```

## Accessibility

- Close button has 44x44px tappable area
- All icons have semantic labels
- Text contrast meets WCAG standards
- Button states are clearly indicated
- Scrollable content for overflow

## Future Enhancements

Potential additions:
- Share event functionality
- Add to calendar integration
- Event reminder notifications
- Full-screen image preview on tap
- Social sharing options
- Attendee list view
- Event comments/discussion
- Map integration for location
