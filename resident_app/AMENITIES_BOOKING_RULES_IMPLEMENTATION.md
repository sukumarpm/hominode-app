# Amenities Booking - Real-World Reservation System 🏢

## Overview

The amenities booking system implements three core rules to behave like a real-world reservation system.

---

## RULE 1: Past Time Slots Must Not Appear ⏰

### Requirement
When the selected date is today, past time slots must not appear.

### Example
- Current time: 7:30 PM
- Slots before 7:30 PM must not appear
- Slots from 7:30 PM onwards should be shown

### Implementation

**File**: `lib/src/services/amenities_booking_flow_function.dart`

**Method**: `_applyRule1PastTimeSlots()`

```dart
Future<List<String>> _applyRule1PastTimeSlots({
  required DateTime selectedDate,
  required List<String> allTimeSlots,
}) async {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final selectedDay = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);

  // CASE 1: Future date → Show all slots
  if (selectedDay.isAfter(today)) {
    return allTimeSlots;
  }

  // CASE 2: Past date → Hide all slots
  if (selectedDay.isBefore(today)) {
    return [];
  }

  // CASE 3: Today → Filter past slots
  final availableSlots = <String>[];
  for (var timeSlot in allTimeSlots) {
    if (!_isTimeSlotPast(timeSlot, now)) {
      availableSlots.add(timeSlot);
    }
  }
  return availableSlots;
}
```

### Time Comparison Logic

```dart
bool _isTimeSlotPast(String timeSlot, DateTime currentTime) {
  // Parse slot time (e.g., "6:00 AM - 7:00 AM" → 6:00)
  final slotStartTime = _parseTimeString(startTimeStr);
  
  // Create DateTime for slot start time today
  final slotDateTime = DateTime(
    today.year, today.month, today.day,
    slotStartTime['hour']!, slotStartTime['minute']!,
  );

  // Check if slot start time <= current time (past or happening now)
  final isPast = slotDateTime.compareTo(currentTime) <= 0;
  return isPast;
}
```

### Test Cases

| Current Time | Selected Date | Slot | Result |
|---|---|---|---|
| 7:30 PM | Today | 6:00 PM - 7:00 PM | ❌ HIDE (past) |
| 7:30 PM | Today | 7:30 PM - 8:30 PM | ❌ HIDE (happening now) |
| 7:30 PM | Today | 8:00 PM - 9:00 PM | ✅ SHOW (future) |
| 7:30 PM | Tomorrow | 6:00 PM - 7:00 PM | ✅ SHOW (future date) |
| 7:30 PM | Yesterday | 8:00 PM - 9:00 PM | ❌ HIDE (past date) |

---

## RULE 2: Maximum Capacity Per Amenity 👥

### Requirement
Each amenity has a maximum capacity. Bookings must be counted across the entire building.

### Example
- Playground capacity: 4 users
- Booking 1: 2 people
- Booking 2: 1 person
- Booking 3: 1 person
- Total: 4 people (at capacity)
- New booking request: 1 person → REJECTED (no capacity)

### Implementation

**File**: `lib/src/services/amenities_booking_flow_function.dart`

**Method**: `_applyRule2CapacityCheck()`

```dart
Future<Map<String, dynamic>> _applyRule2CapacityCheck({
  required String amenityId,
  required DateTime selectedDate,
  required List<String> slotsToCheck,
  required int capacity,
  required int numberOfPeople,
}) async {
  // Query all bookings for this amenity and date
  // This counts bookings across the ENTIRE BUILDING
  final bookingsSnapshot = await _firestore
      .collection('amenityBookings')
      .where('amenityId', isEqualTo: amenityId)
      .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
      .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
      .get();

  // For each slot, calculate total persons booked
  for (var timeSlot in slotsToCheck) {
    int totalPersonsBooked = 0;

    // Sum numberOfPeople from all confirmed/pending bookings
    for (var doc in bookingsSnapshot.docs) {
      final data = doc.data();
      if (data['timeSlot'] == timeSlot && 
          (data['status'] == 'confirmed' || data['status'] == 'pending')) {
        totalPersonsBooked += (data['numberOfPeople'] as int? ?? 1);
      }
    }

    final remainingCapacity = capacity - totalPersonsBooked;
    final canBook = remainingCapacity >= numberOfPeople;

    slotDetails[timeSlot] = {
      'totalPersonsBooked': totalPersonsBooked,
      'remainingCapacity': remainingCapacity > 0 ? remainingCapacity : 0,
      'capacity': capacity,
      'canBook': canBook,
      'isSlotFull': totalPersonsBooked >= capacity,
    };
  }
}
```

### Capacity Calculation

```
Capacity: 4 people
Existing bookings for 10:00 AM - 11:00 AM:
  - Booking 1: 2 people (confirmed)
  - Booking 2: 1 person (confirmed)
  - Booking 3: 1 person (pending)
  
Total booked: 2 + 1 + 1 = 4 people
Remaining: 4 - 4 = 0 spots
Status: FULL ❌
```

### Test Cases

| Capacity | Booked | Requested | Result |
|---|---|---|---|
| 4 | 0 | 1 | ✅ AVAILABLE (3 spots left) |
| 4 | 2 | 2 | ✅ AVAILABLE (2 spots left) |
| 4 | 3 | 1 | ✅ AVAILABLE (1 spot left) |
| 4 | 4 | 1 | ❌ FULL (0 spots left) |
| 4 | 2 | 3 | ❌ NOT ENOUGH (only 2 spots left) |

---

## RULE 3: Display "Slot Full" and Disable Booking 🚫

### Requirement
If total bookings for a slot reach capacity, the slot must display "Slot Full" and the booking button must be disabled.

### Implementation

**File**: `lib/src/modals/booking_modal.dart`

**Method**: `_isSlotAvailable()` and UI rendering

```dart
bool _isSlotAvailable(String timeSlot) {
  // Check if slot is in the available slots list (after filtering)
  if (_availableSlots.isNotEmpty) {
    final isAvailable = _availableSlots.contains(timeSlot);
    return isAvailable;
  }
  return true;
}

// In UI:
GestureDetector(
  onTap: isAvailable ? () { /* book slot */ } : null,
  child: Container(
    decoration: BoxDecoration(
      color: !isAvailable
          ? const Color(0xFFF3F4F6)  // Disabled gray
          : isSelected
              ? const Color(0xFF2563EB)  // Selected blue
              : Colors.white,
      border: Border.all(
        color: !isAvailable
            ? const Color(0xFFE5E7EB)  // Disabled border
            : isSelected
                ? const Color(0xFF2563EB)
                : const Color(0xFFD1D5DB),
      ),
    ),
    child: Column(
      children: [
        Text(
          slot,
          style: TextStyle(
            color: !isAvailable
                ? const Color(0xFF9CA3AF)  // Disabled text
                : isSelected
                    ? Colors.white
                    : Colors.black,
          ),
        ),
        if (showCapacity) ...[
          Text(
            isAvailable
                ? '$remainingSpots/$totalCapacity spots'
                : 'Slot Full',  // RULE 3: Display "Slot Full"
            style: TextStyle(
              color: !isAvailable
                  ? const Color(0xFF9CA3AF)
                  : isSelected
                      ? Colors.white.withOpacity(0.9)
                      : const Color(0xFF6B7280),
            ),
          ),
        ],
      ],
    ),
  ),
)
```

### UI States

**Available Slot**
```
┌─────────────────────┐
│  10:00 AM - 11:00 AM│
│    3/4 spots        │
└─────────────────────┘
✅ Clickable
✅ Blue border when selected
```

**Slot Full**
```
┌─────────────────────┐
│  10:00 AM - 11:00 AM│
│    Slot Full        │
└─────────────────────┘
❌ Not clickable (grayed out)
❌ Cannot be selected
```

---

## Complete Flow Example

### Scenario: Booking Playground at 7:30 PM Today

**Amenity Details**
- Name: Playground
- Capacity: 4 people
- Time slots: 6:00 AM - 7:00 AM, 7:00 AM - 8:00 AM, ..., 8:00 PM - 9:00 PM

**Current Bookings for Today**
- 6:00 AM - 7:00 AM: 2 people (confirmed)
- 7:00 AM - 8:00 AM: 1 person (confirmed)
- 8:00 PM - 9:00 PM: 4 people (confirmed) ← FULL

**User Action**: Select today, request 1 person

### Step 1: Apply RULE 1 (Past Time Slots)
```
Current time: 7:30 PM

6:00 AM - 7:00 AM: 6:00 <= 7:30 → PAST ❌ HIDE
7:00 AM - 8:00 AM: 7:00 <= 7:30 → PAST ❌ HIDE
...
7:00 PM - 8:00 PM: 7:00 <= 7:30 → PAST ❌ HIDE
7:30 PM - 8:30 PM: 7:30 <= 7:30 → PAST ❌ HIDE (happening now)
8:00 PM - 9:00 PM: 8:00 <= 7:30 → FALSE ✅ SHOW
```

**After RULE 1**: Only 8:00 PM - 9:00 PM slot remains

### Step 2: Apply RULE 2 (Capacity Check)
```
Slot: 8:00 PM - 9:00 PM
Capacity: 4 people
Booked: 4 people
Remaining: 0 spots
Requested: 1 person
Can book: 0 >= 1 → FALSE ❌ FULL
```

**After RULE 2**: No available slots

### Step 3: Apply RULE 3 (Display "Slot Full")
```
UI shows:
┌─────────────────────┐
│  8:00 PM - 9:00 PM  │
│    Slot Full        │
└─────────────────────┘
❌ Grayed out
❌ Not clickable
❌ "Confirm Booking" button disabled
```

---

## Firestore Structure

### amenityBookings Collection

```json
{
  "bookingId": "booking_123",
  "amenityId": "amenity_456",
  "date": Timestamp("2024-03-14"),
  "timeSlot": "10:00 AM - 11:00 AM",
  "numberOfPeople": 2,
  "userId": "user_789",
  "status": "confirmed",
  "buildingId": "building_001"
}
```

### Query for Capacity Check

```dart
// Get all bookings for amenity on selected date
final bookingsSnapshot = await _firestore
    .collection('amenityBookings')
    .where('amenityId', isEqualTo: amenityId)
    .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
    .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
    .get();

// Filter by timeSlot and status in memory
for (var doc in bookingsSnapshot.docs) {
  final data = doc.data();
  if (data['timeSlot'] == timeSlot && 
      (data['status'] == 'confirmed' || data['status'] == 'pending')) {
    totalPersonsBooked += (data['numberOfPeople'] as int? ?? 1);
  }
}
```

---

## Testing Checklist

### RULE 1: Past Time Slots
- [ ] Current time 7:30 PM, select today → Slots before 7:30 PM hidden
- [ ] Current time 7:30 PM, select tomorrow → All slots shown
- [ ] Current time 7:30 PM, select yesterday → All slots hidden
- [ ] Slot at exactly current time (7:30 PM) → Hidden

### RULE 2: Capacity Check
- [ ] Capacity 4, booked 2, request 1 → Available
- [ ] Capacity 4, booked 4, request 1 → Full
- [ ] Capacity 4, booked 3, request 2 → Not enough capacity
- [ ] Multiple bookings sum correctly (2+1+1=4)

### RULE 3: Display and Disable
- [ ] Available slot shows "X/Y spots"
- [ ] Full slot shows "Slot Full"
- [ ] Full slot is grayed out
- [ ] Full slot cannot be clicked
- [ ] "Confirm Booking" button disabled when no slots available

---

## Console Output Example

```
🔵 AMENITIES BOOKING FLOW: Starting booking flow...
   Amenity ID: amenity_456
   Selected Date: 2024-03-14
   Total Slots: 14
   Capacity: 4
   Number of People: 1

⏰ STEP 3: Applying RULE 1 - Hide past time slots...
   Current time: 19:30:45
   Today: 2024-03-14
   Selected day: 2024-03-14
   ℹ️  CASE 3: Selected date is TODAY
   🔍 Filtering slots where slotStartTime < currentTime
   
   ❌ HIDE: 6:00 AM - 7:00 AM (already started)
   ❌ HIDE: 7:00 AM - 8:00 AM (already started)
   ...
   ❌ HIDE: 7:30 PM - 8:30 PM (happening now)
   ✅ SHOW: 8:00 PM - 9:00 PM (starts after current time)
   
   📊 RULE 1 RESULT: 1 slot available out of 14

📊 STEP 4: Applying RULE 2 - Hide full capacity slots...
   📊 RULE 2: Checking slot capacity...
   Amenity capacity: 4
   Requested people: 1
   📅 Querying bookings for: 2024-03-14
   📊 Total bookings found: 4
   
   Slot: 8:00 PM - 9:00 PM
   👥 Booking: 2 people (Status: confirmed)
   👥 Booking: 1 person (Status: confirmed)
   👥 Booking: 1 person (Status: pending)
   ❌ SLOT FULL: 8:00 PM - 9:00 PM (4/4 people booked)
   
   📊 RULE 2 RESULT: 0 slots available out of 1

✅ BOOKING FLOW COMPLETE
   Available slots: 0
   Message: No available slots for this date
```

---

## Summary

The amenities booking system now implements a real-world reservation system with:

✅ **RULE 1**: Past time slots hidden when date is today
✅ **RULE 2**: Capacity checked across entire building
✅ **RULE 3**: "Slot Full" displayed and booking disabled

All three rules work together to provide accurate, real-time slot availability.
