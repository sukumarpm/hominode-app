# Amenities Booking Capacity & Configuration - COMPLETE

## Status: ✅ COMPLETE

## Overview
Added comprehensive booking configuration system for amenities that allows:
1. Multiple bookings for the same time slot (e.g., swimming pool with 30 people capacity)
2. Configurable booking durations (e.g., 1 hour, half day, full day)
3. Capacity management and availability checking

## Key Features Implemented

### 1. Multiple Bookings Support
Amenities can now allow multiple residents to book the same time slot simultaneously, with a configurable maximum capacity.

**Examples**:
- Swimming Pool: 30 people can book the same time slot
- Gym: 10 people can use at the same time
- Hall: Only 1 booking allowed (exclusive use)
- Parking: 50 slots available

### 2. Booking Duration Options
Each amenity can have multiple booking duration options:
- **Predefined Options**: 1 hour, 2 hours, 3 hours, Half day, Full day
- **Custom Options**: Admin can add custom durations (e.g., "4 hours", "Weekend")

**Examples**:
- Swimming Pool: 1 hour, 2 hours
- Hall: Half day, Full day
- Gym: 1 hour, 2 hours, 3 hours

### 3. Capacity Management
System tracks current bookings and prevents overbooking:
- Checks available capacity before allowing new bookings
- Shows "spots left" information to residents
- Prevents bookings when capacity is reached

## Firestore Structure Updates

### Amenities Collection
```javascript
amenities/{amenityId}
{
  // Existing fields...
  name: "Swimming Pool",
  type: "Recreation",
  isFree: true,
  pricePerDay: 0,
  timeSlots: ["6:00 AM - 7:00 AM", "7:00 AM - 8:00 AM", ...],
  
  // NEW: Booking Configuration
  maxCapacity: 30,  // Maximum number of people/bookings at same time
  allowMultipleBookings: true,  // Allow multiple bookings for same slot
  bookingDurations: ["1 hour", "2 hours"],  // Available duration options
  
  // Other fields...
  buildingId: "building123",
  buildingName: "Sunrise Apartments",
  adminId: "admin123",
  createdAt: Timestamp,
  updatedAt: Timestamp
}
```

### Bookings Collection
```javascript
bookings/{bookingId}
{
  // Amenity Info
  amenityId: "amenity123",
  amenityName: "Swimming Pool",
  
  // Date & Time
  bookingDate: "2024-01-26",  // YYYY-MM-DD
  timeSlot: "6:00 AM - 7:00 AM",
  
  // NEW: Booking Duration
  bookingDuration: "1 hour",  // Selected duration option
  
  // Resident Info
  residentId: "RES1234",
  residentName: "John Doe",
  flatLabel: "A-101",
  phone: "+91 9876543210",
  
  // Status
  status: "pending" | "approved" | "confirmed" | "rejected" | "cancelled",
  
  // Other fields...
}
```

## Implementation Details

### 1. Updated Files

#### A. `lib/services/amenity_service.dart`
**Added Fields to AmenityModel**:
- `maxCapacity`: int - Maximum number of bookings allowed
- `allowMultipleBookings`: bool - Whether multiple bookings are allowed
- `bookingDurations`: List<String> - Available duration options
- `capacityDisplay`: String getter - Displays capacity in user-friendly format

**New Methods**:
```dart
// Check if a time slot is available
Future<Map<String, dynamic>> checkSlotAvailability({
  required String amenityId,
  required String bookingDate,
  required String timeSlot,
})

// Get current bookings count for a slot
Future<int> getSlotBookingsCount({
  required String amenityId,
  required String bookingDate,
  required String timeSlot,
})
```

**Updated Methods**:
```dart
Future<String> addAmenity({
  // Existing parameters...
  int? maxCapacity,
  bool? allowMultipleBookings,
  List<String>? bookingDurations,
})
```

#### B. `lib/widgets/add_amenity_modal.dart`
**New UI Components**:
1. **Allow Multiple Bookings Toggle**
   - Switch to enable/disable multiple bookings
   - Automatically sets capacity to 1 when disabled

2. **Maximum Capacity Field**
   - Only shown when multiple bookings are enabled
   - Validates minimum capacity of 2
   - Helper text explains the purpose

3. **Booking Duration Options**
   - Predefined options: 1 hour, 2 hours, 3 hours, Half day, Full day
   - Custom duration input field
   - Visual chips showing selected durations
   - At least one duration must be selected

#### C. `lib/amenities_management_screen.dart`
**Enhanced Amenity Card Display**:
- Shows capacity information with icon
- Displays "Multiple bookings" badge if enabled
- Shows available booking durations
- Better visual hierarchy

### 2. Booking Availability Logic

```
When resident tries to book:
  ↓
1. Check if amenity allows multiple bookings
  ↓
  NO → Check if ANY booking exists for that slot
        ↓
        YES → Show "Already booked"
        NO → Allow booking
  ↓
  YES → Check current bookings count
        ↓
        Count >= maxCapacity → Show "Capacity full (30/30)"
        Count < maxCapacity → Allow booking, show "X spots left"
```

### 3. Example Configurations

#### Swimming Pool (Multiple Bookings)
```javascript
{
  name: "Swimming Pool",
  maxCapacity: 30,
  allowMultipleBookings: true,
  bookingDurations: ["1 hour", "2 hours"],
  timeSlots: [
    "6:00 AM - 7:00 AM",
    "7:00 AM - 8:00 AM",
    "5:00 PM - 6:00 PM",
    "6:00 PM - 7:00 PM"
  ]
}
```
**Behavior**: Up to 30 people can book the same time slot. Each person can choose 1 hour or 2 hours duration.

#### Community Hall (Exclusive Booking)
```javascript
{
  name: "Community Hall",
  maxCapacity: 1,
  allowMultipleBookings: false,
  bookingDurations: ["Half day", "Full day"],
  timeSlots: null  // No specific time slots
}
```
**Behavior**: Only one booking allowed at a time. Can be booked for half day or full day.

#### Gym (Limited Multiple Bookings)
```javascript
{
  name: "Gym",
  maxCapacity: 10,
  allowMultipleBookings: true,
  bookingDurations: ["1 hour", "2 hours", "3 hours"],
  timeSlots: [
    "6:00 AM - 7:00 AM",
    "7:00 AM - 8:00 AM",
    ...
  ]
}
```
**Behavior**: Up to 10 people can use gym at the same time. Each person can book for 1, 2, or 3 hours.

## UI/UX Improvements

### Add Amenity Modal
1. **Booking Configuration Section**
   - Clear section header
   - Toggle switch for multiple bookings
   - Conditional capacity field
   - Duration selection with chips
   - Custom duration input

2. **Visual Feedback**
   - Selected durations shown as blue chips
   - Available durations shown as white chips
   - Validation messages for required fields
   - Helper text explaining each field

### Amenity Card Display
1. **Capacity Information**
   - Icon + text showing capacity
   - "Multiple bookings" badge if enabled
   - Booking durations list

2. **Better Organization**
   - Grouped related information
   - Clear visual hierarchy
   - Consistent spacing

## Validation Rules

### Add Amenity Form
1. **Multiple Bookings**:
   - If enabled, capacity must be at least 2
   - If disabled, capacity automatically set to 1

2. **Booking Durations**:
   - At least one duration must be selected
   - Custom durations can be added
   - Durations can be removed (except last one)

3. **Capacity**:
   - Must be a valid number
   - Must be greater than 1 if multiple bookings enabled

### Booking Creation (Resident App)
1. **Availability Check**:
   - Check if slot is available
   - Check if capacity allows new booking
   - Show appropriate error message

2. **Duration Selection**:
   - Only show durations configured for amenity
   - Validate selected duration

## Flow Function Compliance

✅ **Multiple bookings stored in same collection**: All bookings stored in `bookings` collection
✅ **Capacity tracking**: System tracks current bookings vs max capacity
✅ **Duration options**: Each amenity has configurable duration options
✅ **Availability checking**: Real-time availability check before booking
✅ **Proper data structure**: All configuration stored in amenity document

## Testing Checklist

- [x] Add amenity with multiple bookings enabled
- [x] Add amenity with multiple bookings disabled
- [x] Set different capacity values
- [x] Add multiple booking durations
- [x] Add custom booking duration
- [x] Remove booking duration
- [x] Display capacity on amenity card
- [x] Display booking durations on amenity card
- [x] Show "Multiple bookings" badge
- [x] Validate capacity field
- [x] Validate duration selection
- [x] Check slot availability method
- [x] Get bookings count method
- [x] No compilation errors

## Usage Examples

### Example 1: Swimming Pool (High Capacity)
```dart
await amenityService.addAmenity(
  name: "Swimming Pool",
  type: "Recreation",
  isFree: true,
  buildingId: "building123",
  buildingName: "Sunrise Apartments",
  maxCapacity: 30,
  allowMultipleBookings: true,
  bookingDurations: ["1 hour", "2 hours"],
  timeSlots: ["6:00 AM - 7:00 AM", "7:00 AM - 8:00 AM"],
);
```

### Example 2: Community Hall (Exclusive)
```dart
await amenityService.addAmenity(
  name: "Community Hall",
  type: "Event",
  isFree: false,
  pricePerDay: 5000,
  buildingId: "building123",
  buildingName: "Sunrise Apartments",
  maxCapacity: 1,
  allowMultipleBookings: false,
  bookingDurations: ["Half day", "Full day"],
);
```

### Example 3: Check Availability
```dart
final availability = await amenityService.checkSlotAvailability(
  amenityId: "amenity123",
  bookingDate: "2024-01-26",
  timeSlot: "6:00 AM - 7:00 AM",
);

if (availability['available']) {
  print("Available! ${availability['spotsLeft']} spots left");
} else {
  print("Not available: ${availability['reason']}");
}
```

## Benefits

1. **Flexibility**: Different amenities can have different booking rules
2. **Capacity Management**: Prevents overbooking automatically
3. **User Experience**: Residents see available spots before booking
4. **Scalability**: System handles both exclusive and shared amenities
5. **Customization**: Admins can configure each amenity independently

## Next Steps (Optional Enhancements)

1. **Dynamic Pricing**: Different prices for different durations
2. **Peak Hours**: Higher capacity or pricing during peak times
3. **Booking Limits**: Limit bookings per resident per month
4. **Waitlist**: Queue system when capacity is full
5. **Recurring Bookings**: Allow weekly/monthly recurring bookings
6. **Booking Analytics**: Track popular time slots and capacity utilization

## Conclusion

The amenities booking system now supports flexible capacity management and multiple booking configurations. Admins can configure each amenity according to its specific requirements, whether it's a high-capacity swimming pool or an exclusive community hall. The system automatically tracks bookings and prevents overbooking while providing clear feedback to residents about availability.

All changes follow the flow function requirements and are ready for production use.
