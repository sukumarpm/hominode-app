# Amenities Booking - Rules Quick Reference 📋

## Three Core Rules

### RULE 1: Past Time Slots ⏰
**When**: Selected date is today
**Action**: Hide all slots where `slotStartTime <= currentTime`

```
Current: 7:30 PM
6:00 PM slot → HIDE ❌
7:30 PM slot → HIDE ❌ (happening now)
8:00 PM slot → SHOW ✅
```

### RULE 2: Capacity Check 👥
**When**: Checking slot availability
**Action**: Sum all `numberOfPeople` from confirmed/pending bookings
**Condition**: If `totalPeople >= capacity` → Slot is FULL

```
Capacity: 4
Booking 1: 2 people
Booking 2: 1 person
Booking 3: 1 person
Total: 4 people → FULL ❌
```

### RULE 3: Display "Slot Full" 🚫
**When**: Slot reaches capacity
**Action**: Show "Slot Full" text and disable booking button

```
Available: "3/4 spots" ✅ Clickable
Full: "Slot Full" ❌ Grayed out
```

---

## Implementation Files

| File | Method | Purpose |
|------|--------|---------|
| `amenities_booking_flow_function.dart` | `_applyRule1PastTimeSlots()` | Filter past slots |
| `amenities_booking_flow_function.dart` | `_applyRule2CapacityCheck()` | Check capacity |
| `booking_modal.dart` | `_isSlotAvailable()` | Determine slot state |
| `booking_modal.dart` | UI rendering | Display "Slot Full" |

---

## Key Code Snippets

### RULE 1: Time Comparison
```dart
final isPast = slotDateTime.compareTo(currentTime) <= 0;
// true = slot is past or happening now
// false = slot is in future
```

### RULE 2: Capacity Calculation
```dart
int totalPersonsBooked = 0;
for (var doc in bookingsSnapshot.docs) {
  if (data['timeSlot'] == timeSlot && 
      (data['status'] == 'confirmed' || data['status'] == 'pending')) {
    totalPersonsBooked += (data['numberOfPeople'] as int? ?? 1);
  }
}
final canBook = (capacity - totalPersonsBooked) >= numberOfPeople;
```

### RULE 3: UI Display
```dart
Text(
  isAvailable ? '$remainingSpots/$totalCapacity spots' : 'Slot Full',
  style: TextStyle(
    color: !isAvailable ? Colors.grey : Colors.black,
  ),
)
```

---

## Test Scenarios

### Scenario 1: Morning Booking
```
Current: 9:00 AM
Capacity: 4
Booked: 0

6:00 AM - 7:00 AM → HIDE (past)
8:00 AM - 9:00 AM → HIDE (happening now)
9:00 AM - 10:00 AM → SHOW (4/4 spots)
10:00 AM - 11:00 AM → SHOW (4/4 spots)
```

### Scenario 2: Full Slot
```
Current: 2:00 PM
Capacity: 4
Booked: 4 people

2:00 PM - 3:00 PM → HIDE (happening now)
3:00 PM - 4:00 PM → SHOW "Slot Full" (4/4 booked)
4:00 PM - 5:00 PM → SHOW "Slot Full" (4/4 booked)
```

### Scenario 3: Partial Capacity
```
Current: 2:00 PM
Capacity: 4
Booked: 2 people

2:00 PM - 3:00 PM → HIDE (happening now)
3:00 PM - 4:00 PM → SHOW (2/4 spots)
4:00 PM - 5:00 PM → SHOW (2/4 spots)
```

---

## Firestore Query

```dart
// Get all bookings for amenity on date
final bookingsSnapshot = await _firestore
    .collection('amenityBookings')
    .where('amenityId', isEqualTo: amenityId)
    .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
    .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
    .get();

// Filter by timeSlot and status in memory
// Count across ENTIRE BUILDING
```

---

## Console Output

```
⏰ STEP 3: Applying RULE 1 - Hide past time slots...
   ❌ HIDE: 6:00 AM - 7:00 AM (already started)
   ✅ SHOW: 10:00 AM - 11:00 AM (starts after current time)

📊 STEP 4: Applying RULE 2 - Hide full capacity slots...
   ✅ AVAILABLE: 10:00 AM - 11:00 AM (2/4 spots)
   ❌ SLOT FULL: 2:00 PM - 3:00 PM (4/4 booked)
```

---

## Validation Checklist

- [ ] RULE 1: Past slots hidden when date is today
- [ ] RULE 1: All slots shown when date is future
- [ ] RULE 1: All slots hidden when date is past
- [ ] RULE 2: Capacity counted across entire building
- [ ] RULE 2: numberOfPeople summed correctly
- [ ] RULE 3: "Slot Full" displayed for full slots
- [ ] RULE 3: Full slots are grayed out
- [ ] RULE 3: Full slots cannot be clicked
- [ ] RULE 3: "Confirm Booking" disabled when no slots available

---

## Status

✅ RULE 1: Implemented in `_applyRule1PastTimeSlots()`
✅ RULE 2: Implemented in `_applyRule2CapacityCheck()`
✅ RULE 3: Implemented in booking modal UI

All three rules working together for real-world reservation system behavior.
