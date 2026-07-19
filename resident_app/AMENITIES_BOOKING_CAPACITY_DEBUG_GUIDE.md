# Amenities Booking - Capacity Display Debug Guide

## Quick Diagnosis: "0/8 spots booked" Issue

### Symptom
Modal shows "0/8 spots booked" instead of "0/5 spots booked"

### Root Cause
One of these:
1. Amenity `maxCapacity` in Firestore is 8 (should be 5)
2. Amenity details not loading correctly
3. Flow function not returning correct slot details

---

## Debug Checklist

### ✅ Step 1: Verify Firestore Amenity Document

**Location**: `amenities` collection → your amenity document

**Check these fields**:
```
maxCapacity: 5  ← Should be 5, not 8
allowMultipleBookings: true  ← Should be true for capacity display
timeSlots: [...]  ← Should have time slots
```

**If maxCapacity is 8**:
- Update it to 5 in Firestore Console
- The modal will automatically show correct capacity after reload

---

### ✅ Step 2: Check Console Logs

**When modal opens**, look for these logs:

```
🔵 Loading amenity details for: [amenity-id]
✅ Loaded amenity details:
   Name: [amenity-name]
   Max capacity: 5  ← Should be 5
   Time slots: 14
   Allow multiple: true
   Price per day: 500
```

**If Max capacity shows 8**:
- Amenity document in Firestore has `maxCapacity: 8`
- Update it to 5

---

### ✅ Step 3: Check Slot Availability Logs

**When date is selected**, look for these logs:

```
🔍 Loading slot availability for [date] with 1 people
   Amenity max capacity: 5  ← Should be 5
   📊 Slot "6:00 AM - 7:00 AM":
      - Available: true
      - Total persons booked: 0
      - Capacity: 5  ← Should be 5
```

**If Capacity shows 8**:
- Check `_getTotalCapacity()` method
- Verify `_amenityDetails.maxCapacity` is being used

---

### ✅ Step 4: Verify Flow Function Output

**When flow function runs**, look for these logs:

```
🔵 AMENITIES BOOKING FLOW: Starting booking flow...
   Capacity: 5  ← Should be 5

📊 RULE 2: Checking slot capacity...
   Amenity capacity: 5  ← Should be 5
   
   📊 Slot "6:00 AM - 7:00 AM":
      totalPersonsBooked: 0
      remainingCapacity: 5
      capacity: 5  ← Should be 5
```

**If capacity shows 8**:
- Flow function is receiving wrong capacity parameter
- Check `_loadSlotAvailability()` - verify it passes `_amenityDetails!.maxCapacity`

---

## Common Issues & Fixes

### Issue 1: Capacity is 8 in Firestore
**Fix**: Update amenity document
```
Go to Firebase Console
→ Firestore Database
→ amenities collection
→ Your amenity document
→ Edit maxCapacity field: 8 → 5
```

### Issue 2: Amenity Details Not Loading
**Fix**: Check amenity ID
```dart
// In booking_modal.dart, verify:
print('Amenity ID: ${widget.amenity.id}');  // Should match Firestore document ID
```

### Issue 3: Flow Function Receiving Wrong Capacity
**Fix**: Check `_loadSlotAvailability()` method
```dart
// Should pass amenity's maxCapacity:
final result = await _bookingFlow.getAvailableSlots(
  amenityId: widget.amenity.id,
  selectedDate: _selectedDate!,
  allTimeSlots: _timeSlots,
  capacity: _amenityDetails!.maxCapacity,  // ← Should be 5
  numberOfPeople: _numberOfPeople,
);
```

### Issue 4: Slot Details Not Showing Correct Values
**Fix**: Check `_getRemainingSpots()` method
```dart
// Should use flow function's totalPersonsBooked:
final totalPersonsBooked = slotDetail?['totalPersonsBooked'] as int? ?? 0;
// NOT:
final totalPersonsBooked = slotDetail?['remainingCapacity'] as int? ?? 0;
```

---

## Testing the Fix

### Test 1: Verify Capacity Display
```
1. Open booking modal
2. Select a date
3. Look at first time slot
4. Should show: "0/5 spots booked"
5. NOT: "0/8 spots booked"
```

### Test 2: Verify Booking Updates Display
```
1. Create a booking for a slot
2. Close and reopen modal
3. That slot should show: "1/5 spots booked"
4. NOT: "1/8 spots booked"
```

### Test 3: Verify Full Slot Display
```
1. Create 5 bookings for same slot
2. That slot should show: "5/5 spots booked" + "Slot Full"
3. NOT: "5/8 spots booked"
```

---

## Log Output Reference

### Expected Logs (Correct)
```
✅ Loaded amenity details:
   Max capacity: 5
   
✅ Loading slot availability for [date] with 1 people
   Amenity max capacity: 5
   
📊 Slot "6:00 AM - 7:00 AM":
   - Total persons booked: 0
   - Capacity: 5
```

### Wrong Logs (Incorrect)
```
❌ Loaded amenity details:
   Max capacity: 8  ← WRONG!
   
❌ Loading slot availability for [date] with 1 people
   Amenity max capacity: 8  ← WRONG!
   
📊 Slot "6:00 AM - 7:00 AM":
   - Total persons booked: 0
   - Capacity: 8  ← WRONG!
```

---

## Quick Fix Checklist

- [ ] Check Firestore amenity `maxCapacity` is 5
- [ ] Check console logs show "Max capacity: 5"
- [ ] Check slot display shows "0/5 spots booked"
- [ ] Create a test booking
- [ ] Verify slot updates to "1/5 spots booked"
- [ ] Create 5 bookings
- [ ] Verify slot shows "5/5 spots booked" + "Slot Full"

---

## Still Having Issues?

### Enable Debug Mode
Add this to `_loadSlotAvailability()`:
```dart
print('🔍 DEBUG: _amenityDetails = $_amenityDetails');
print('🔍 DEBUG: _amenityDetails.maxCapacity = ${_amenityDetails?.maxCapacity}');
print('🔍 DEBUG: _slotAvailability = $_slotAvailability');
```

### Check Firestore Rules
Ensure Firestore security rules allow reading amenities:
```
match /amenities/{document=**} {
  allow read: if request.auth != null;
}
```

### Verify User Authentication
Ensure user is logged in:
```dart
final user = FirebaseAuth.instance.currentUser;
print('Current user: ${user?.uid}');
```

---

## Related Files
- `lib/src/modals/booking_modal.dart` - Booking modal implementation
- `lib/src/services/amenities_booking_flow_function.dart` - Flow function
- `lib/src/services/booking_firestore_service.dart` - Firestore service
