# Booking Modal - Complete ✓

## Overview
Pixel-perfect **Booking Modal** overlay for amenities booking with calendar, time slot selection, and confirmation. Modal appears centered over the screen with fade+scale animation.

## Features Implemented

### ✓ Modal Overlay
- Centered modal with semi-transparent scrim (rgba(0,0,0,0.35))
- Fade + scale animation on open/close
- Rounded corners (18px)
- White background with shadow
- Dismissible by tapping outside or close button
- Responsive width (92% of screen, max 500px)

### ✓ Header
- Dynamic title: "Book {AmenityName}"
- Close button (X) top-right
- Bottom border separator

### ✓ Info Card
- Light grey background (#F6F7F9)
- Timings row with clock icon
- Price row with location icon
- Dynamic data from Amenity model

### ✓ Calendar Component
- Month view with prev/next navigation
- Month header: "November 2025"
- Weekday labels (Su Mo Tu We Th Fr Sa)
- Day states:
  - Out-of-month: light grey (#D1D5DB)
  - Available: black text
  - Selected: grey background (#E5E7EB)
  - Blocked: dark navy (#0B1020) with white text
  - Past dates: disabled (light grey)
- Rounded day cells (8px radius)
- Grid layout (7 columns)

### ✓ Time Slot Selector
- 2-column grid layout
- Rounded chips (12px radius)
- Chip states:
  - Available: white with border (#E6E6E6)
  - Selected: dark navy (#0B1020) with white text
  - Disabled: grey (#F0F0F0) with muted text
- Dynamic slots based on selected date
- Validation: requires date selection first

### ✓ Confirm Button
- Full width, 56px height
- Primary blue (#2563EB)
- Disabled until date + time selected
- Loading state with spinner
- Success/error feedback via SnackBar

## Files Created

1. **lib/src/modals/booking_modal.dart**
   - Main modal widget
   - `BookingModal.show(context, amenity)` helper
   - Form state management
   - Validation logic
   - Mock booking submission

2. **lib/src/widgets/calendar_grid.dart**
   - Reusable calendar component
   - Month navigation
   - Day selection
   - Blocked dates support
   - Past date handling

3. **lib/src/widgets/time_slot_selector.dart**
   - Time slot grid
   - Selection state
   - Disabled slots support
   - 2-column layout

4. **lib/src/models/booking.dart**
   - BookingModel class
   - JSON serialization
   - Date formatting helpers

5. **lib/src/models/amenity.dart** (updated)
   - Added openTime and closeTime fields

6. **lib/src/screens/amenities_booking_screen.dart** (updated)
   - Added onTap to AmenityCard
   - Opens booking modal on tap
   - Passes amenity data to modal

## Usage

### Open Booking Modal
```dart
import 'package:resident_app/src/modals/booking_modal.dart';
import 'package:resident_app/src/models/amenity.dart';

// Create amenity object
final amenity = Amenity(
  id: 'swimming-pool',
  name: 'Swimming Pool',
  price: 'Free',
  isAvailable: true,
  iconName: 'pool',
  backgroundColor: '#D6EBFF',
  iconColor: '#0A64FF',
  openTime: '6:00 AM',
  closeTime: '8:00 PM',
);

// Show modal
BookingModal.show(context, amenity);
```

### From Amenities Screen
Tap any amenity card in the Available Amenities grid to open the booking modal automatically.

## Design Specifications

### Colors
| Element | Color | Hex |
|---------|-------|-----|
| Primary Blue | Blue | #2563EB |
| Selected Dark | Navy | #0B1020 |
| Info Card BG | Light Grey | #F6F7F9 |
| Container BG | Light Grey | #F6F8FA |
| Border | Light Grey | #E6E6E6 |
| Muted Text | Grey | #9B9B9B |
| Disabled BG | Grey | #F0F0F0 |
| Disabled Text | Grey | #BDBDBD |
| Selected Day BG | Grey | #E5E7EB |
| Out of Month | Light Grey | #D1D5DB |

### Spacing
- Modal padding: 20px
- Section spacing: 24px
- Info card padding: 14px
- Calendar padding: 16px
- Time slot padding: 16px
- Grid spacing: 8-12px
- Button height: 56px

### Typography
- Modal title: 20px, bold
- Section titles: 16px, semi-bold
- Info text: 14px, regular
- Calendar month: 16px, semi-bold
- Calendar days: 15px, medium
- Time slots: 14px, medium
- Button text: 16px, semi-bold

### Border Radius
- Modal: 18px
- Info card: 12px
- Calendar container: 16px
- Day cells: 8px
- Time slot chips: 12px
- Button: 12px

## Mock Data Structure

### Blocked Dates
```dart
final Set<DateTime> _blockedDates = {
  DateTime(2025, 11, 14),
  // Add more blocked dates
};
```

### Disabled Time Slots by Date
```dart
final Map<String, Set<String>> _disabledSlotsByDate = {
  '2025-11-15': {'8:00 AM - 9:00 AM', '5:00 PM - 6:00 PM'},
  '2025-11-16': {'6:00 AM - 7:00 AM', '7:00 PM - 8:00 PM'},
  // Add more date-specific disabled slots
};
```

## API Integration Points

### 1. Fetch Blocked Dates
```dart
// Create service: lib/src/services/booking_service.dart
class BookingService {
  static Future<Set<DateTime>> getBlockedDates(String amenityId) async {
    final response = await http.get(
      Uri.parse('https://your-api.com/amenities/$amenityId/blocked-dates'),
    );
    // Parse and return blocked dates
  }
}
```

### 2. Fetch Available Time Slots
```dart
static Future<List<String>> getAvailableSlots({
  required String amenityId,
  required DateTime date,
}) async {
  final response = await http.get(
    Uri.parse('https://your-api.com/amenities/$amenityId/slots?date=${date.toIso8601String()}'),
  );
  // Parse and return available slots
}
```

### 3. Create Booking
```dart
static Future<BookingModel> createBooking({
  required String amenityId,
  required DateTime date,
  required String timeSlot,
}) async {
  final response = await http.post(
    Uri.parse('https://your-api.com/bookings'),
    body: jsonEncode({
      'amenityId': amenityId,
      'date': date.toIso8601String(),
      'timeSlot': timeSlot,
    }),
    headers: {'Content-Type': 'application/json'},
  );
  
  if (response.statusCode != 200) {
    throw Exception('Failed to create booking');
  }
  
  return BookingModel.fromJson(jsonDecode(response.body));
}
```

### 4. Replace Mock in booking_modal.dart
```dart
Future<void> _handleConfirm() async {
  if (!_canConfirm) return;

  setState(() => _isSubmitting = true);

  try {
    final booking = await BookingService.createBooking(
      amenityId: widget.amenity.id,
      date: _selectedDate!,
      timeSlot: _selectedTimeSlot!,
    );

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${widget.amenity.name} booked successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Booking failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  } finally {
    if (mounted) {
      setState(() => _isSubmitting = false);
    }
  }
}
```

## Validation Rules

1. **Date Selection Required**: User must select a date before selecting time slot
2. **Time Slot Required**: Both date and time slot must be selected to enable Confirm button
3. **Past Dates Disabled**: Cannot select dates before today
4. **Blocked Dates**: Dates marked as blocked cannot be selected
5. **Disabled Slots**: Time slots marked as unavailable cannot be selected
6. **Date Change**: Selecting a new date resets the time slot selection

## User Flow

1. User taps amenity card in Amenities Booking screen
2. Modal opens with fade+scale animation
3. User sees amenity info (timings, price)
4. User selects a date from calendar
5. Available time slots update based on selected date
6. User selects a time slot
7. Confirm button becomes enabled
8. User taps Confirm Booking
9. Loading spinner shows during submission
10. Success: Modal closes, success SnackBar appears
11. Error: Error SnackBar appears, modal stays open

## Accessibility

- Semantic labels for all interactive elements
- Tap targets >= 44×44 px
- Calendar days have proper labels
- Time slots have proper labels
- Confirm button has semantic label
- Close button has semantic label

## Optional Enhancements

1. **Dynamic Time Slots**: Generate slots based on openTime/closeTime
2. **Slot Duration**: Allow different slot durations (30min, 1hr, 2hr)
3. **Multi-day Booking**: Allow booking multiple consecutive days
4. **Recurring Bookings**: Weekly/monthly recurring options
5. **Booking Details**: Show existing bookings on calendar
6. **Price Calculation**: Show total price for paid amenities
7. **Payment Integration**: Add payment flow for paid amenities
8. **Booking Confirmation**: Email/SMS confirmation
9. **Edit Booking**: Allow editing existing bookings
10. **Booking Rules**: Show amenity-specific rules/guidelines

## Testing Checklist

- [x] Modal opens centered with animation
- [x] Close button dismisses modal
- [x] Tap outside dismisses modal
- [x] Calendar displays current month
- [x] Prev/Next month navigation works
- [x] Date selection works
- [x] Selected date shows grey background
- [x] Blocked dates show dark navy
- [x] Past dates are disabled
- [x] Time slots display in 2 columns
- [x] Time slot selection works
- [x] Selected slot shows dark background
- [x] Disabled slots are greyed out
- [x] Confirm button disabled until date+slot selected
- [x] Confirm button shows loading state
- [x] Success SnackBar appears on success
- [x] Error SnackBar appears on failure
- [x] Modal closes after successful booking
- [ ] Real API integration (TODO)

## Summary
The Booking Modal is production-ready with pixel-perfect UI, full calendar functionality, time slot selection, validation, and mock booking submission. Ready for API integration.
