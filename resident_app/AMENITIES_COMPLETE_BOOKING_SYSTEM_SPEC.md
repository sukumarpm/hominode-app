# 🎯 Complete Amenities Booking System - Specification

## Overview
Comprehensive booking system supporting daily bookings, subscription packages (weekly/monthly/yearly), family member bookings, and cancellation functionality.

---

## Requirements

### 1. Booking Types
- **Daily**: Single day booking
- **Weekly**: 7-day subscription package
- **Monthly**: 30-day subscription package  
- **Yearly**: 365-day subscription package

### 2. Family Member Support
- User can book for multiple family members
- Track total number of people in booking
- Each person counts toward amenity capacity

### 3. Package Duration Tracking
- Store subscription start date
- Calculate and store subscription end date
- Track validity period

### 4. Cancellation Support
- Users can cancel their bookings
- Update booking status to 'cancelled'
- Free up capacity when cancelled

---

## Firestore Data Structure

### Enhanced Booking Document:
```json
{
  // User Info
  "userId": "user_uid",
  "userName": "John Doe",
  "userEmail": "john@example.com",
  "flatId": "flat_456",
  "flatLabel": "A-101",
  
  // Building Info
  "buildingId": "building_123",
  "organizationId": "org_456",
  
  // Amenity Info
  "amenityId": "amenity_id",
  "amenityName": "Gym",
  
  // Admin Info
  "adminId": "admin_uid",
  "adminName": "Admin Name",
  "adminEmail": "admin@example.com",
  
  // Booking Type & Duration (NEW)
  "bookingType": "monthly",  // "daily", "weekly", "monthly", "yearly"
  "packageType": "Monthly",  // null for daily, "Weekly", "Monthly", "Yearly" for packages
  
  // Date & Time
  "date": "Timestamp",  // Booking start date
  "timeSlot": "6:00 AM - 7:00 AM",
  
  // Package Duration (NEW)
  "subscriptionStartDate": "Timestamp",  // Same as date for packages
  "subscriptionEndDate": "Timestamp",    // Calculated based on package type
  "validityDays": 30,  // 1 for daily, 7 for weekly, 30 for monthly, 365 for yearly
  
  // Family Members (NEW)
  "numberOfPeople": 2,  // Total people in this booking
  "familyMembers": [    // Optional: List of family member names
    "John Doe",
    "Jane Doe"
  ],
  
  // Pricing
  "price": 5000,  // Amount paid
  "pricePerDay": 50,  // For reference
  
  // Status
  "status": "confirmed",  // "confirmed", "cancelled", "completed", "expired"
  "cancellationDate": null,  // Timestamp when cancelled
  "cancellationReason": null,  // Optional reason
  
  // Timestamps
  "createdAt": "Timestamp",
  "updatedAt": "Timestamp"
}
```

---

## Booking Flow

### Step 1: Select Booking Type
```
User sees options:
┌─────────────────────────────────┐
│ ○ Daily (₹50/day)               │
│ ● Monthly Package (₹5000/month) │ ← Selected
│ ○ Yearly Package (₹10000/year)  │
└─────────────────────────────────┘
```

### Step 2: Select Number of People
```
┌─────────────────────────────────┐
│ Number of People                │
│ ┌───┐                           │
│ │ 2 │ [- +]                     │
│ └───┘                           │
│                                 │
│ Note: Each person counts toward │
│ amenity capacity                │
└─────────────────────────────────┘
```

### Step 3: Select Date & Time
```
Calendar → Select start date
Time Slots → Select time slot
Shows: "5/10 spots remaining"
```

### Step 4: Confirm Booking
```
Summary:
- Amenity: Gym
- Type: Monthly Package
- People: 2
- Start: Feb 26, 2026
- End: Mar 28, 2026 (30 days)
- Time: 6:00 AM - 7:00 AM
- Price: ₹5000

[Confirm Booking]
```

---

## Capacity Calculation

### For Daily Bookings:
```
Available spots = maxCapacity - (sum of numberOfPeople for all bookings)

Example:
- Gym capacity: 10
- Booking 1: 2 people
- Booking 2: 3 people
- Booking 3: 1 person
- Available: 10 - (2 + 3 + 1) = 4 spots
```

### For Package Bookings:
```
Check capacity for EACH day in the package period

Example: Monthly package (30 days)
- Check capacity for all 30 days
- If any day is full, show warning
- User can still book if willing to skip full days
```

---

## Date Calculations

### Daily Booking:
```dart
subscriptionStartDate = selectedDate
subscriptionEndDate = selectedDate (same day)
validityDays = 1
```

### Weekly Package:
```dart
subscriptionStartDate = selectedDate
subscriptionEndDate = selectedDate + 7 days
validityDays = 7
```

### Monthly Package:
```dart
subscriptionStartDate = selectedDate
subscriptionEndDate = selectedDate + 30 days
validityDays = 30
```

### Yearly Package:
```dart
subscriptionStartDate = selectedDate
subscriptionEndDate = selectedDate + 365 days
validityDays = 365
```

---

## Cancellation Flow

### User Cancels Booking:
```
1. User taps "Cancel Booking"
2. Show confirmation dialog:
   "Are you sure you want to cancel?"
   [No] [Yes, Cancel]
3. If confirmed:
   - Update status to 'cancelled'
   - Set cancellationDate
   - Optional: Ask for reason
4. Free up capacity
5. Show success message
```

### Firestore Update:
```dart
await bookings.doc(bookingId).update({
  'status': 'cancelled',
  'cancellationDate': FieldValue.serverTimestamp(),
  'cancellationReason': reason,  // Optional
  'updatedAt': FieldValue.serverTimestamp(),
});
```

---

## UI Components Needed

### 1. Booking Type Selector (Already exists)
- Radio buttons for Daily/Weekly/Monthly/Yearly
- Show prices for each option

### 2. Number of People Selector (NEW)
```dart
Widget _buildPeopleSelector() {
  return Row(
    children: [
      Text('Number of People'),
      IconButton(
        icon: Icon(Icons.remove),
        onPressed: () => setState(() {
          if (_numberOfPeople > 1) _numberOfPeople--;
        }),
      ),
      Text('$_numberOfPeople'),
      IconButton(
        icon: Icon(Icons.add),
        onPressed: () => setState(() {
          _numberOfPeople++;
        }),
      ),
    ],
  );
}
```

### 3. Package Summary (NEW)
```dart
Widget _buildPackageSummary() {
  if (_bookingType == 'daily') return SizedBox.shrink();
  
  return Container(
    child: Column(
      children: [
        Text('Package Duration'),
        Text('Start: ${formatDate(_selectedDate)}'),
        Text('End: ${formatDate(_calculateEndDate())}'),
        Text('Valid for: $_validityDays days'),
      ],
    ),
  );
}
```

### 4. My Bookings Display (Enhanced)
```dart
Widget _buildBookingCard(Booking booking) {
  return Card(
    child: Column(
      children: [
        Text(booking.amenityName),
        Text('Type: ${booking.bookingType}'),
        Text('People: ${booking.numberOfPeople}'),
        if (booking.isPackage) ...[
          Text('Valid: ${booking.startDate} - ${booking.endDate}'),
        ],
        Text('Status: ${booking.status}'),
        if (booking.status == 'confirmed')
          ElevatedButton(
            onPressed: () => _cancelBooking(booking),
            child: Text('Cancel Booking'),
          ),
      ],
    ),
  );
}
```

---

## Service Methods Needed

### 1. Enhanced createBooking()
```dart
Future<BookingResult> createBooking({
  required String amenityId,
  required String amenityName,
  required DateTime date,
  required String timeSlot,
  required String bookingType,  // NEW
  required int numberOfPeople,  // NEW
  List<String>? familyMembers,  // NEW
}) async {
  // Calculate end date based on booking type
  final endDate = _calculateEndDate(date, bookingType);
  final validityDays = _calculateValidityDays(bookingType);
  final price = _calculatePrice(amenityId, bookingType);
  
  // Create booking with all fields
  final bookingData = {
    // ... existing fields ...
    'bookingType': bookingType,
    'packageType': bookingType == 'daily' ? null : _getPackageType(bookingType),
    'numberOfPeople': numberOfPeople,
    'familyMembers': familyMembers,
    'subscriptionStartDate': Timestamp.fromDate(date),
    'subscriptionEndDate': Timestamp.fromDate(endDate),
    'validityDays': validityDays,
    'price': price,
    // ... rest of fields ...
  };
  
  // Save to Firestore
  await _firestore.collection('bookings').add(bookingData);
}
```

### 2. Calculate End Date
```dart
DateTime _calculateEndDate(DateTime startDate, String bookingType) {
  switch (bookingType) {
    case 'daily':
      return startDate;
    case 'weekly':
      return startDate.add(Duration(days: 7));
    case 'monthly':
      return startDate.add(Duration(days: 30));
    case 'yearly':
      return startDate.add(Duration(days: 365));
    default:
      return startDate;
  }
}
```

### 3. Calculate Price
```dart
double _calculatePrice(AmenityModel amenity, String bookingType) {
  if (bookingType == 'daily') {
    return amenity.pricePerDay ?? 0;
  } else if (amenity.subscriptionPackages != null) {
    final packageKey = bookingType == 'weekly' ? 'Weekly'
                     : bookingType == 'monthly' ? 'Monthly'
                     : 'Yearly';
    return amenity.subscriptionPackages![packageKey] ?? 0;
  }
  return 0;
}
```

### 4. Enhanced Capacity Check
```dart
Future<Map<String, dynamic>> checkSlotAvailability({
  required String amenityId,
  required DateTime date,
  required String timeSlot,
  int numberOfPeople = 1,  // NEW
}) async {
  // Query bookings
  final bookings = await _getBookingsForSlot(amenityId, date, timeSlot);
  
  // Sum up numberOfPeople from all bookings
  int totalPeople = 0;
  for (var booking in bookings) {
    totalPeople += booking['numberOfPeople'] as int? ?? 1;
  }
  
  // Check capacity
  final amenity = await getAmenityDetails(amenityId);
  final remainingSpots = amenity.maxCapacity - totalPeople;
  final canBook = remainingSpots >= numberOfPeople;
  
  return {
    'available': canBook,
    'remainingSpots': remainingSpots,
    'totalCapacity': amenity.maxCapacity,
    'currentOccupancy': totalPeople,
  };
}
```

### 5. Cancel Booking
```dart
Future<BookingResult> cancelBooking(
  String bookingId, {
  String? reason,
}) async {
  try {
    await _firestore.collection('bookings').doc(bookingId).update({
      'status': 'cancelled',
      'cancellationDate': FieldValue.serverTimestamp(),
      'cancellationReason': reason,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    
    return BookingResult.success(message: 'Booking cancelled successfully');
  } catch (e) {
    return BookingResult.failure(message: 'Failed to cancel booking');
  }
}
```

---

## Implementation Priority

### Phase 1: Core Booking Enhancement (CURRENT)
1. ✅ Add booking type selection
2. ✅ Add number of people selector
3. ✅ Calculate package end dates
4. ✅ Store all booking data
5. ✅ Enhanced capacity checking

### Phase 2: UI Enhancement
1. Package summary display
2. Family member names input
3. Enhanced booking cards
4. Package validity indicators

### Phase 3: Cancellation
1. Cancel booking button
2. Confirmation dialog
3. Status update
4. Capacity release

---

## Testing Scenarios

### Test 1: Daily Booking for 2 People
```
1. Select Daily booking
2. Set people: 2
3. Select date and time
4. Confirm
5. Verify:
   - numberOfPeople: 2
   - validityDays: 1
   - endDate = startDate
```

### Test 2: Monthly Package for 1 Person
```
1. Select Monthly package
2. Set people: 1
3. Select date: Feb 26, 2026
4. Confirm
5. Verify:
   - bookingType: "monthly"
   - packageType: "Monthly"
   - startDate: Feb 26, 2026
   - endDate: Mar 28, 2026
   - validityDays: 30
```

### Test 3: Capacity with Multiple People
```
1. Gym capacity: 10
2. User A books for 3 people
3. User B books for 4 people
4. Available: 10 - 7 = 3 spots
5. User C tries to book for 4 people
6. Should show: "Not enough capacity"
```

### Test 4: Cancel Booking
```
1. Create a booking
2. Click "Cancel Booking"
3. Confirm cancellation
4. Verify:
   - status: "cancelled"
   - cancellationDate: set
   - Capacity freed up
```

---

## Next Steps

This specification provides the complete structure. The implementation will be done in phases:

1. **Immediate**: Update booking modal to collect booking type and number of people
2. **Next**: Enhance createBooking() to store all new fields
3. **Then**: Update capacity checking to sum numberOfPeople
4. **Finally**: Add cancellation functionality

Would you like me to proceed with implementing Phase 1?

