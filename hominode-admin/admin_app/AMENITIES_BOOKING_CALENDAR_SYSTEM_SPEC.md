# Amenities Booking Calendar System - Specification

## Overview
Implement a comprehensive booking system for amenities with calendar view, time slot selection, and booking management according to the flow UI requirements.

## Features Required

### 1. Calendar View for Booking
- Display monthly calendar with selectable dates
- Show current date highlighted
- Allow date selection for booking
- Navigate between months
- Disable past dates

### 2. Time Slot Display Format
Time slots should be displayed in the format:
```
6:00 AM - 7:00 AM
7:00 AM - 8:00 AM
8:00 AM - 9:00 AM
5:00 PM - 6:00 PM
6:00 PM - 7:00 PM
7:00 PM - 8:00 PM
```

### 3. Booking Flow
```
1. User selects amenity (e.g., "Swimming Pool")
   ↓
2. Calendar appears showing available dates
   ↓
3. User selects date
   ↓
4. Time slots appear for selected date
   ↓
5. User selects time slot
   ↓
6. User clicks "Confirm Booking"
   ↓
7. Booking saved to Firestore
   ↓
8. Confirmation shown
```

### 4. Booking Data Structure

#### Firestore Collection: `amenity_bookings`
```
amenity_bookings/
  {bookingId}/
    amenityId: "amenity123"
    amenityName: "Swimming Pool"
    buildingId: "building123"
    buildingName: "Sunrise Apartments"
    
    // Date and Time
    bookingDate: "2024-01-26" (YYYY-MM-DD format)
    timeSlot: "6:00 AM - 7:00 AM"
    startTime: "06:00"
    endTime: "07:00"
    
    // User Information
    userId: "user123"
    residentId: "RES1234"
    residentName: "John Doe"
    flatId: "flat123"
    flatLabel: "A-101"
    phone: "+91 9876543210"
    
    // Status
    status: "confirmed" | "cancelled" | "completed"
    
    // Timestamps
    createdAt: Timestamp
    updatedAt: Timestamp
    bookedAt: Timestamp
```

### 5. Admin View - Bookings Screen

#### Features:
- View all bookings by date
- Filter by amenity
- Filter by status
- View resident details
- Cancel bookings
- Export booking reports

#### UI Layout:
```
┌─────────────────────────────────────┐
│  Amenity Bookings                   │
├─────────────────────────────────────┤
│  [Calendar View]                    │
│  Selected Date: Jan 26, 2024        │
├─────────────────────────────────────┤
│  Filters:                           │
│  [All Amenities ▼] [All Status ▼]  │
├─────────────────────────────────────┤
│  Bookings for Jan 26, 2024:         │
│                                     │
│  ┌─────────────────────────────┐   │
│  │ Swimming Pool               │   │
│  │ 6:00 AM - 7:00 AM          │   │
│  │ John Doe (A-101)           │   │
│  │ Status: Confirmed          │   │
│  │ [View] [Cancel]            │   │
│  └─────────────────────────────┘   │
│                                     │
│  ┌─────────────────────────────┐   │
│  │ Gym                         │   │
│  │ 7:00 AM - 8:00 AM          │   │
│  │ Jane Smith (B-202)         │   │
│  │ Status: Confirmed          │   │
│  │ [View] [Cancel]            │   │
│  └─────────────────────────────┘   │
└─────────────────────────────────────┘
```

## Implementation Steps

### Step 1: Create Booking Service
File: `lib/services/booking_service.dart`

```dart
class BookingService {
  // Create booking
  Future<String> createBooking({
    required String amenityId,
    required String amenityName,
    required String bookingDate,
    required String timeSlot,
    required String userId,
    // ... other fields
  });
  
  // Get bookings by date
  Stream<List<BookingModel>> getBookingsByDate(String date);
  
  // Get bookings by amenity
  Stream<List<BookingModel>> getBookingsByAmenity(String amenityId);
  
  // Get user bookings
  Stream<List<BookingModel>> getUserBookings(String userId);
  
  // Cancel booking
  Future<void> cancelBooking(String bookingId);
  
  // Check slot availability
  Future<bool> isSlotAvailable(
    String amenityId,
    String date,
    String timeSlot,
  );
}
```

### Step 2: Create Booking Modal Widget
File: `lib/widgets/book_amenity_modal.dart`

Features:
- Calendar view
- Time slot selection
- Booking confirmation
- User information display

### Step 3: Create Bookings Management Screen
File: `lib/amenity_bookings_screen.dart`

Features:
- Calendar view for date selection
- List of bookings for selected date
- Filter by amenity and status
- View booking details
- Cancel bookings

### Step 4: Update Amenity Service
Add booking-related methods to existing amenity service:
- Get available time slots for date
- Check slot availability
- Get booking statistics

## Time Slot Configuration

### Default Time Slots:
```dart
final List<String> defaultTimeSlots = [
  '6:00 AM - 7:00 AM',
  '7:00 AM - 8:00 AM',
  '8:00 AM - 9:00 AM',
  '9:00 AM - 10:00 AM',
  '10:00 AM - 11:00 AM',
  '11:00 AM - 12:00 PM',
  '12:00 PM - 1:00 PM',
  '1:00 PM - 2:00 PM',
  '2:00 PM - 3:00 PM',
  '3:00 PM - 4:00 PM',
  '4:00 PM - 5:00 PM',
  '5:00 PM - 6:00 PM',
  '6:00 PM - 7:00 PM',
  '7:00 PM - 8:00 PM',
  '8:00 PM - 9:00 PM',
  '9:00 PM - 10:00 PM',
];
```

### Amenity-Specific Time Slots:
Each amenity can have custom time slots stored in Firestore:
```
amenities/
  {amenityId}/
    timeSlots: [
      '6:00 AM - 7:00 AM',
      '7:00 AM - 8:00 AM',
      '5:00 PM - 6:00 PM',
      '6:00 PM - 7:00 PM',
    ]
```

## UI Components Needed

### 1. Calendar Widget
- Use `table_calendar` package
- Custom styling to match app theme
- Date selection handling

### 2. Time Slot Grid
- 2-column grid layout
- Selectable time slot cards
- Disabled state for booked slots
- Visual feedback for selection

### 3. Booking Card
- Display booking information
- Status indicator
- Action buttons (View, Cancel)

## Validation Rules

1. **Date Validation**:
   - Cannot book past dates
   - Cannot book more than 30 days in advance

2. **Time Slot Validation**:
   - Check if slot is already booked
   - Check if amenity is available on selected date
   - Check if user has existing booking for same time

3. **User Validation**:
   - User must be a resident
   - User must have assigned flat
   - User must be active status

## Notifications

### Booking Confirmation:
- Send notification to resident
- Send notification to admin
- Email confirmation (optional)

### Booking Reminder:
- Send reminder 1 day before
- Send reminder 1 hour before

### Cancellation:
- Notify resident of cancellation
- Notify admin if cancelled by resident

## Reports and Analytics

### Admin Dashboard:
- Total bookings today
- Total bookings this week
- Most booked amenity
- Peak booking times
- Booking trends

### Export Options:
- Export bookings by date range
- Export by amenity
- Export by resident
- PDF and CSV formats

## Dependencies Required

Add to `pubspec.yaml`:
```yaml
dependencies:
  table_calendar: ^3.0.9  # For calendar view
  intl: ^0.18.0           # For date formatting
```

## Testing Checklist

- [ ] Create booking successfully
- [ ] View bookings by date
- [ ] Filter bookings by amenity
- [ ] Filter bookings by status
- [ ] Cancel booking
- [ ] Check slot availability
- [ ] Prevent double booking
- [ ] Validate date selection
- [ ] Validate time slot selection
- [ ] Display user information correctly
- [ ] Update booking status
- [ ] Send notifications
- [ ] Export booking reports

## Future Enhancements

1. **Recurring Bookings**: Allow weekly/monthly recurring bookings
2. **Waiting List**: Queue system for fully booked slots
3. **Payment Integration**: Charge for premium amenities
4. **Rating System**: Allow residents to rate amenities
5. **Booking Limits**: Set maximum bookings per user per month
6. **Booking Rules**: Custom rules per amenity (e.g., max 2 hours)

## Notes

- All times stored in 24-hour format internally
- Display in 12-hour format with AM/PM
- Use local timezone for all operations
- Implement proper error handling
- Add loading states for all async operations
- Implement optimistic UI updates
