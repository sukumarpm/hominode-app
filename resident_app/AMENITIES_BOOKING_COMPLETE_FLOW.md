# Amenities Booking - Complete Flow Reference

## Booking Flow Overview

### Step 1: Load Amenity Details
```dart
final amenity = await _bookingService.getAmenityDetails(amenityId);
// Returns: AmenityModel with timeSlots, capacity, packages
```

### Step 2: Load Available Slots
```dart
final result = await _bookingFlow.getAvailableSlots(
  amenityId: amenityId,
  selectedDate: selectedDate,
  allTimeSlots: amenity.timeSlots,
  capacity: amenity.maxCapacity,
  numberOfPeople: numberOfPeople,
);
// Returns: List of available slots after filtering
```

### Step 3: Apply RULE 1 - Past Time Slots
- If date is TODAY: Hide slots where start time <= current time
- If date is FUTURE: Show all slots
- If date is PAST: Hide all slots

### Step 4: Apply RULE 2 - Capacity Check
- Query all bookings for amenity + date
- Sum `numberOfPeople` from each booking
- If total >= capacity: Mark slot as FULL
- If total + requested > capacity: Mark as NOT_ENOUGH_CAPACITY

### Step 5: Create Booking
```dart
final result = await _bookingFlow.createBooking(
  amenityId: amenityId,
  amenityName: amenityName,
  date: selectedDate,
  timeSlot: selectedTimeSlot,
  numberOfPeople: numberOfPeople,
  bookingType: 'daily', // or 'weekly', 'monthly', 'yearly'
);
```

## UI Display Logic

### Available Slot
```
9:00 AM - 10:00 AM
2 / 4 spots booked
[Book Now] ← Enabled
```

### Full Slot
```
9:00 AM - 10:00 AM
Slot Full
[Book Now] ← Disabled
```

### Past Slot (Today Only)
```
Hidden from list
```

## Data Models

### AmenityModel
```dart
- id: String
- name: String
- timeSlots: List<String> ← FIXED: Uses List<String>.from()
- maxCapacity: int
- allowMultipleBookings: bool
- pricePerDay: double?
- subscriptionPackages: Map<String, double>?
```

### BookingModel
```dart
- id: String
- amenityId: String
- date: DateTime
- timeSlot: String
- numberOfPeople: int ← NEW: Tracks people count
- bookingType: String ← NEW: 'daily', 'weekly', etc.
- status: String ← 'confirmed', 'pending', 'cancelled'
```

## Firestore Queries

### Get Amenity Details
```
Collection: amenities
Document: {amenityId}
```

### Get Bookings for Date
```
Collection: amenityBookings
Where: amenityId == {amenityId}
Where: date >= {startOfDay}
Where: date <= {endOfDay}
Where: status in ['confirmed', 'pending']
```

### Calculate Slot Capacity
```
For each timeSlot:
  - Query bookings where timeSlot == {timeSlot}
  - Sum numberOfPeople from all bookings
  - remainingCapacity = maxCapacity - totalPeople
  - canBook = remainingCapacity >= numberOfPeople
```

## Error Handling

### Type Casting Error
```dart
// ✅ CORRECT
List<String> slots = List<String>.from(data['timeSlots'] as List<dynamic>);

// ❌ INCORRECT
List<String> slots = data['timeSlots'] as List<String>;
```

### Slot No Longer Available
- Re-check availability before creating booking
- If slot is full, show error: "This slot is no longer available"

### User Not Authenticated
- Check Firebase Auth first
- Fallback to SharedPreferences
- Show login screen if no user found

## Real-Time Updates

### Amenities Stream
```dart
_bookingService.streamAmenitiesRealtime()
// Updates when amenities are added/modified
```

### Bookings Stream
```dart
_bookingService.streamMyBookingsRealtime()
// Updates when user's bookings change
```

### Slot Availability
- Reloaded when date changes
- Reloaded when number of people changes
- Reloaded when booking type changes

## Booking Types

### Daily
- Price: pricePerDay
- Duration: 1 day
- Validity: 1 day

### Weekly Package
- Price: subscriptionPackages['Weekly']
- Duration: 7 days
- Validity: 7 days

### Monthly Package
- Price: subscriptionPackages['Monthly']
- Duration: 30 days
- Validity: 30 days

### Yearly Package
- Price: subscriptionPackages['Yearly']
- Duration: 365 days
- Validity: 365 days

## Debugging Tips

### Check Amenity Details
```dart
print('Amenity: ${amenity.name}');
print('Capacity: ${amenity.maxCapacity}');
print('Time Slots: ${amenity.timeSlots}');
print('Allow Multiple: ${amenity.allowMultipleBookings}');
```

### Check Slot Availability
```dart
print('Available Slots: ${result.availableSlots}');
print('Slot Details: ${result.slotDetails}');
```

### Check Bookings for Date
```dart
final bookings = await _bookingService.getBookingsForDateRange(
  amenityId: amenityId,
  startDate: date,
  endDate: date,
);
print('Bookings: $bookings');
```
