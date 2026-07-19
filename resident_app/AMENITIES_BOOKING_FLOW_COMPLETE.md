# Amenities Booking - Complete Flow Diagram 🔄

## User Journey

```
User Opens Amenities Booking Modal
    ↓
Modal Loads Amenity Details
    ↓
User Selects Date
    ↓
Flow Function Executes
    ├─ STEP 1: Validate User ✅
    ├─ STEP 2: Validate Amenity ✅
    ├─ STEP 3: Apply RULE 1 (Past Slots)
    │   ├─ If today: Filter past slots
    │   ├─ If future: Show all slots
    │   └─ If past: Hide all slots
    ├─ STEP 4: Apply RULE 2 (Capacity)
    │   ├─ Query bookings for date
    │   ├─ Sum numberOfPeople per slot
    │   └─ Mark full slots
    └─ STEP 5: Return Available Slots
    ↓
Modal Updates UI
    ├─ Show available slots
    ├─ Display "Slot Full" for full slots
    └─ Disable full slots
    ↓
User Selects Slot
    ↓
User Clicks "Confirm Booking"
    ↓
Booking Created in Firestore
    ↓
Confirmation Message
```

---

## RULE 1: Past Time Slots Filter

```
Input: All time slots for amenity
       Current time: 7:30 PM
       Selected date: Today

Process:
  6:00 AM - 7:00 AM  → 6:00 <= 7:30 → PAST ❌
  7:00 AM - 8:00 AM  → 7:00 <= 7:30 → PAST ❌
  ...
  7:00 PM - 8:00 PM  → 7:00 <= 7:30 → PAST ❌
  7:30 PM - 8:30 PM  → 7:30 <= 7:30 → PAST ❌ (happening now)
  8:00 PM - 9:00 PM  → 8:00 <= 7:30 → FALSE ✅
  8:30 PM - 9:30 PM  → 8:30 <= 7:30 → FALSE ✅

Output: [8:00 PM - 9:00 PM, 8:30 PM - 9:30 PM]
```

---

## RULE 2: Capacity Check

```
Input: Slots after RULE 1
       Amenity capacity: 4
       Requested people: 1

Firestore Query:
  SELECT * FROM amenityBookings
  WHERE amenityId = "playground_123"
  AND date = "2024-03-14"
  AND status IN ["confirmed", "pending"]

Results:
  Booking 1: timeSlot="8:00 PM - 9:00 PM", numberOfPeople=2
  Booking 2: timeSlot="8:00 PM - 9:00 PM", numberOfPeople=1
  Booking 3: timeSlot="8:00 PM - 9:00 PM", numberOfPeople=1
  Booking 4: timeSlot="8:30 PM - 9:30 PM", numberOfPeople=2

Calculation:
  Slot: 8:00 PM - 9:00 PM
    Total booked: 2 + 1 + 1 = 4 people
    Remaining: 4 - 4 = 0 spots
    Can book 1 person: 0 >= 1 → FALSE ❌ FULL
  
  Slot: 8:30 PM - 9:30 PM
    Total booked: 2 people
    Remaining: 4 - 2 = 2 spots
    Can book 1 person: 2 >= 1 → TRUE ✅ AVAILABLE

Output: [8:30 PM - 9:30 PM]
```

---

## RULE 3: UI Display

```
Available Slot:
┌─────────────────────────────┐
│  8:30 PM - 9:30 PM          │
│  2/4 spots                  │
│  [Clickable] [Blue border]  │
└─────────────────────────────┘

Full Slot:
┌─────────────────────────────┐
│  8:00 PM - 9:00 PM          │
│  Slot Full                  │
│  [Grayed out] [Not clickable]│
└─────────────────────────────┘
```

---

## Complete Example: Playground Booking

### Initial State
```
Amenity: Playground
Capacity: 4 people
Current time: 7:30 PM
Selected date: Today (2024-03-14)
Requested people: 1
```

### Available Time Slots
```
6:00 AM - 7:00 AM
7:00 AM - 8:00 AM
8:00 AM - 9:00 AM
9:00 AM - 10:00 AM
10:00 AM - 11:00 AM
11:00 AM - 12:00 PM
12:00 PM - 1:00 PM
1:00 PM - 2:00 PM
2:00 PM - 3:00 PM
3:00 PM - 4:00 PM
4:00 PM - 5:00 PM
5:00 PM - 6:00 PM
6:00 PM - 7:00 PM
7:00 PM - 8:00 PM
7:30 PM - 8:30 PM
8:00 PM - 9:00 PM
8:30 PM - 9:30 PM
```

### After RULE 1 (Past Slots)
```
Only future slots remain:
7:30 PM - 8:30 PM
8:00 PM - 9:00 PM
8:30 PM - 9:30 PM
```

### Existing Bookings
```
7:30 PM - 8:30 PM: 3 people (confirmed)
8:00 PM - 9:00 PM: 4 people (confirmed) ← FULL
8:30 PM - 9:30 PM: 1 person (confirmed)
```

### After RULE 2 (Capacity Check)
```
7:30 PM - 8:30 PM: 3/4 spots → AVAILABLE ✅
8:00 PM - 9:00 PM: 4/4 spots → FULL ❌
8:30 PM - 9:30 PM: 3/4 spots → AVAILABLE ✅
```

### Final UI Display
```
┌─────────────────────────────┐
│  7:30 PM - 8:30 PM          │
│  1/4 spots                  │
│  [Clickable] [Blue border]  │
└─────────────────────────────┘

┌─────────────────────────────┐
│  8:00 PM - 9:00 PM          │
│  Slot Full                  │
│  [Grayed out] [Not clickable]│
└─────────────────────────────┘

┌─────────────────────────────┐
│  8:30 PM - 9:30 PM          │
│  3/4 spots                  │
│  [Clickable] [Blue border]  │
└─────────────────────────────┘
```

### User Selects 7:30 PM - 8:30 PM
```
Booking Created:
{
  "amenityId": "playground_123",
  "date": Timestamp("2024-03-14"),
  "timeSlot": "7:30 PM - 8:30 PM",
  "numberOfPeople": 1,
  "userId": "user_456",
  "status": "confirmed",
  "createdAt": Timestamp.now()
}

Result: ✅ Booking confirmed!
```

---

## Code Flow

### Step 1: User Selects Date
```dart
_selectedDate = DateTime(2024, 3, 14);
_loadSlotAvailability();
```

### Step 2: Flow Function Executes
```dart
final result = await _bookingFlow.getAvailableSlots(
  amenityId: 'playground_123',
  selectedDate: DateTime(2024, 3, 14),
  allTimeSlots: [...14 slots...],
  capacity: 4,
  numberOfPeople: 1,
);
```

### Step 3: RULE 1 Applied
```dart
final slotsAfterRule1 = await _applyRule1PastTimeSlots(
  selectedDate: DateTime(2024, 3, 14),
  allTimeSlots: [...14 slots...],
);
// Returns: [7:30 PM - 8:30 PM, 8:00 PM - 9:00 PM, 8:30 PM - 9:30 PM]
```

### Step 4: RULE 2 Applied
```dart
final result = await _applyRule2CapacityCheck(
  amenityId: 'playground_123',
  selectedDate: DateTime(2024, 3, 14),
  slotsToCheck: [7:30 PM - 8:30 PM, 8:00 PM - 9:00 PM, 8:30 PM - 9:30 PM],
  capacity: 4,
  numberOfPeople: 1,
);
// Returns: {
//   availableSlots: [7:30 PM - 8:30 PM, 8:30 PM - 9:30 PM],
//   slotDetails: {
//     "7:30 PM - 8:30 PM": {canBook: true, remainingCapacity: 1},
//     "8:00 PM - 9:00 PM": {canBook: false, isSlotFull: true},
//     "8:30 PM - 9:30 PM": {canBook: true, remainingCapacity: 3}
//   }
// }
```

### Step 5: UI Updates
```dart
setState(() {
  _availableSlots = result.availableSlots;
  _slotAvailability = result.slotDetails;
});
// UI renders with available slots and "Slot Full" for full slots
```

---

## Validation Points

### RULE 1 Validation
- [ ] Past slots are hidden
- [ ] Current time slot is hidden
- [ ] Future slots are shown
- [ ] Future dates show all slots
- [ ] Past dates show no slots

### RULE 2 Validation
- [ ] Bookings queried for correct date
- [ ] numberOfPeople summed correctly
- [ ] Capacity compared correctly
- [ ] Full slots marked correctly
- [ ] Partial capacity calculated correctly

### RULE 3 Validation
- [ ] Available slots show "X/Y spots"
- [ ] Full slots show "Slot Full"
- [ ] Full slots are grayed out
- [ ] Full slots are not clickable
- [ ] "Confirm Booking" button disabled when no slots

---

## Error Handling

```
User selects date
    ↓
Flow function executes
    ├─ User not authenticated → Show error
    ├─ Amenity not found → Show error
    ├─ Firestore query fails → Show error
    └─ Success → Continue
    ↓
Slots filtered and displayed
    ├─ No available slots → Show message
    └─ Slots available → Show UI
    ↓
User confirms booking
    ├─ Slot no longer available → Show error
    ├─ Firestore write fails → Show error
    └─ Success → Show confirmation
```

---

## Performance Considerations

1. **Firestore Query**: Single query per date (not per slot)
2. **In-Memory Filtering**: Filter by timeSlot and status in memory
3. **Caching**: Availability cached until date changes
4. **Real-time**: Fresh query on each date selection

---

## Summary

The complete amenities booking flow:
1. ✅ Validates user and amenity
2. ✅ Applies RULE 1 (past slots)
3. ✅ Applies RULE 2 (capacity)
4. ✅ Applies RULE 3 (display)
5. ✅ Returns available slots
6. ✅ Updates UI
7. ✅ Creates booking on confirmation

All three rules work together to provide a real-world reservation system.
