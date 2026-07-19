# Amenities Booking - Quick Reference Card

## The Fix (One Line)
**Use `List<String>.from()` instead of `as List<String>` when converting Firestore arrays**

```dart
// ✅ CORRECT
List<String> slots = List<String>.from(data['timeSlots'] as List<dynamic>);

// ❌ INCORRECT
List<String> slots = data['timeSlots'] as List<String>;
```

---

## Three Rules

### RULE 1: Hide Past Time Slots
- **When:** Selected date is TODAY
- **Action:** Hide slots where start time <= current time
- **Example:** Current time 7:30 PM → Hide "7:00 PM - 8:00 PM"

### RULE 2: Hide Full Slots
- **When:** Total people booked >= capacity
- **Action:** Mark slot as "Slot Full" and disable booking
- **Example:** Capacity 4, booked 4 → Slot Full

### RULE 3: Prevent Overbooking
- **When:** Creating booking
- **Action:** Re-check slot availability
- **Example:** If slot became full, reject booking

---

## UI States

| State | Display | Button |
|-------|---------|--------|
| Available | "9:00 AM - 10:00 AM\n2 / 4 spots booked" | Enabled |
| Full | "9:00 AM - 10:00 AM\nSlot Full" | Disabled |
| Past (Today) | Hidden | N/A |
| Future Date | All slots | Enabled/Disabled |

---

## Booking Flow (5 Steps)

1. **Load Amenity** → Get timeSlots, capacity, packages
2. **Get Available Slots** → Apply RULE 1 & RULE 2
3. **Apply RULE 1** → Hide past slots if today
4. **Apply RULE 2** → Hide full slots
5. **Create Booking** → Validate and save

---

## Key Data Fields

### AmenityModel
```dart
- timeSlots: List<String> ← FIXED: Safe conversion
- maxCapacity: int
- allowMultipleBookings: bool
```

### BookingModel
```dart
- numberOfPeople: int ← NEW: Tracks people count
- bookingType: String ← NEW: 'daily', 'weekly', etc.
- status: String ← 'confirmed', 'pending', 'cancelled'
```

---

## Firestore Queries

### Get Bookings for Slot
```
Collection: amenityBookings
Where: amenityId == {amenityId}
Where: date == {selectedDate}
Where: timeSlot == {timeSlot}
Where: status in ['confirmed', 'pending']
```

### Calculate Capacity
```
totalPeople = sum(numberOfPeople) from all bookings
remainingCapacity = maxCapacity - totalPeople
canBook = remainingCapacity >= numberOfPeople
```

---

## Common Issues & Solutions

| Issue | Solution |
|-------|----------|
| Type casting error | Use `List<String>.from()` |
| Slots not loading | Check Firestore data structure |
| Past slots showing | Verify current time is correct |
| Overbooking allowed | Check capacity calculation |
| Real-time not updating | Verify Firestore listeners |

---

## Testing Checklist

- [ ] No type casting error on load
- [ ] Time slots display correctly
- [ ] Past slots hidden for today
- [ ] Full slots show "Slot Full"
- [ ] Booking creates successfully
- [ ] Real-time updates work
- [ ] Capacity prevents overbooking

---

## Console Logs to Check

### Success
```
✅ Loaded 14 time slots
✅ AVAILABLE: 9:00 AM - 10:00 AM (2/4 spots remaining)
✅ Booking created successfully!
```

### Errors
```
❌ SLOT FULL: 9:00 AM - 10:00 AM (4/4 people booked)
❌ NOT ENOUGH CAPACITY: 9:00 AM - 10:00 AM (need 2, have 1 spots)
❌ HIDE: 7:00 PM - 8:00 PM (already started or happening now)
```

---

## Files Modified

1. `lib/src/services/booking_firestore_service.dart` - Fixed type casting
2. `lib/src/services/amenities_booking_flow_function.dart` - Fixed type casting

---

## Documentation

- **AMENITIES_BOOKING_TYPE_CASTING_FIX.md** - Detailed fix
- **AMENITIES_BOOKING_COMPLETE_FLOW.md** - Complete flow
- **AMENITIES_BOOKING_TESTING_CHECKLIST.md** - Testing guide
- **AMENITIES_BOOKING_FIX_SUMMARY.md** - Full summary

---

## Key Takeaway

**Always convert Firestore arrays safely:**
```dart
// Pattern to follow
List<String> items = List<String>.from(data['items'] as List<dynamic>);
```

This prevents the type casting error and ensures robust data handling.
