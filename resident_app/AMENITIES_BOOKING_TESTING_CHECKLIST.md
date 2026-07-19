# Amenities Booking - Testing Checklist

## Type Casting Fix Verification

### ✅ Test 1: Load Amenity Without Error
**Steps:**
1. Open Amenities Booking screen
2. Tap on any amenity to open booking modal
3. Check console for errors

**Expected Result:**
- No "type 'List<dynamic>' is not a subtype of type 'List<String>?'" error
- Time slots load successfully
- Console shows: "✅ Loaded X time slots"

**Console Output:**
```
🔵 Loading amenity details for: {amenityId}
✅ Loaded 14 time slots
   Has packages: true/false
   Allow multiple: true/false
   Max capacity: 4
```

---

## Real-Time Slot Filtering (RULE 1)

### ✅ Test 2: Hide Past Slots on Today's Date
**Setup:**
- Current time: 7:30 PM
- Available slots: 6:00 AM - 10:00 PM

**Steps:**
1. Open booking modal
2. Select TODAY as date
3. Check time slot list

**Expected Result:**
- All slots before 7:30 PM are hidden
- Only slots starting at 7:30 PM or later appear
- Example: "7:00 PM - 8:00 PM" is hidden, "8:00 PM - 9:00 PM" is shown

**Console Output:**
```
⏰ STEP 3: Applying RULE 1 - Hide past time slots...
Current time: 19:30:00
Today: 2026-03-14
Selected day: 2026-03-14
ℹ️  CASE 3: Selected date is TODAY
🔍 Filtering slots where slotStartTime < currentTime
✅ SHOW: 8:00 PM - 9:00 PM (starts after current time)
❌ HIDE: 7:00 PM - 8:00 PM (already started or happening now)
```

### ✅ Test 3: Show All Slots on Future Date
**Steps:**
1. Open booking modal
2. Select TOMORROW as date
3. Check time slot list

**Expected Result:**
- All time slots are visible
- No slots are hidden
- Past time filtering doesn't apply

**Console Output:**
```
ℹ️  CASE 1: Selected date is in the future
✅ Show all slots (no past slots to hide)
```

### ✅ Test 4: Hide All Slots on Past Date
**Steps:**
1. Open booking modal
2. Select YESTERDAY as date
3. Check time slot list

**Expected Result:**
- No time slots are visible
- Message: "No available slots for this date"

**Console Output:**
```
ℹ️  CASE 2: Selected date is in the past
❌ Hide all slots (entire day is past)
```

---

## Capacity Validation (RULE 2)

### ✅ Test 5: Show Available Slot with Remaining Capacity
**Setup:**
- Amenity capacity: 4 people
- Current bookings for 9:00 AM: 2 people
- Requesting: 1 person

**Steps:**
1. Open booking modal
2. Select a date
3. Check 9:00 AM slot

**Expected Result:**
- Slot shows: "9:00 AM - 10:00 AM"
- Displays: "2 / 4 spots booked"
- Button is ENABLED
- Can proceed with booking

**Console Output:**
```
✅ AVAILABLE: 9:00 AM - 10:00 AM (2/4 spots remaining)
```

### ✅ Test 6: Show Full Slot (Overbooking Prevention)
**Setup:**
- Amenity capacity: 4 people
- Current bookings for 9:00 AM: 4 people
- Requesting: 1 person

**Steps:**
1. Open booking modal
2. Select a date
3. Check 9:00 AM slot

**Expected Result:**
- Slot shows: "9:00 AM - 10:00 AM"
- Displays: "Slot Full"
- Button is DISABLED
- Cannot proceed with booking

**Console Output:**
```
❌ SLOT FULL: 9:00 AM - 10:00 AM (4/4 people booked)
```

### ✅ Test 7: Show Not Enough Capacity
**Setup:**
- Amenity capacity: 4 people
- Current bookings for 9:00 AM: 3 people
- Requesting: 2 people

**Steps:**
1. Open booking modal
2. Select number of people: 2
3. Check 9:00 AM slot

**Expected Result:**
- Slot shows: "9:00 AM - 10:00 AM"
- Displays: "1 / 4 spots booked"
- Button is DISABLED
- Message: "Not enough capacity"

**Console Output:**
```
⚠️  NOT ENOUGH CAPACITY: 9:00 AM - 10:00 AM (need 2, have 1 spots)
```

---

## Booking Creation

### ✅ Test 8: Create Daily Booking
**Steps:**
1. Open booking modal
2. Select date: Tomorrow
3. Select time slot: 9:00 AM - 10:00 AM
4. Select number of people: 1
5. Booking type: Daily
6. Tap "Confirm Booking"

**Expected Result:**
- Booking created successfully
- Success message: "Amenity booked successfully!"
- Booking appears in "My Bookings" section
- Status: "Confirmed"

**Console Output:**
```
✅ Booking created successfully!
🆔 Booking ID: {bookingId}
```

### ✅ Test 9: Create Weekly Package Booking
**Steps:**
1. Open booking modal
2. Select booking type: Weekly Package
3. Select date: Tomorrow
4. Select time slot: 9:00 AM - 10:00 AM
5. Tap "Confirm Booking"

**Expected Result:**
- Booking created with package type
- Shows validity period: "Valid: 14 Mar 2026 - 21 Mar 2026"
- Price shows weekly rate

### ✅ Test 10: Prevent Overbooking
**Setup:**
- Slot is full (4/4 people)
- User tries to book

**Steps:**
1. Open booking modal
2. Select full slot
3. Tap "Confirm Booking"

**Expected Result:**
- Button is disabled
- Cannot tap to book
- Shows "Slot Full" message

---

## UI State Verification

### ✅ Test 11: Verify UI States
**Check each state displays correctly:**

**Available Slot:**
```
9:00 AM - 10:00 AM
2 / 4 spots booked
[Book Now] ← Blue, Enabled
```

**Full Slot:**
```
9:00 AM - 10:00 AM
Slot Full
[Book Now] ← Gray, Disabled
```

**Past Slot (Today):**
```
Hidden from list
```

**Future Date:**
```
All slots visible
```

---

## Real-Time Updates

### ✅ Test 12: Real-Time Availability Update
**Setup:**
- Two devices/users
- Same amenity, same time slot

**Steps:**
1. Device A: Open booking modal, see slot available
2. Device B: Book the last available spot
3. Device A: Check if slot updates to "Slot Full"

**Expected Result:**
- Device A sees real-time update
- Slot changes to "Slot Full" within 2-3 seconds
- Button becomes disabled

---

## Error Handling

### ✅ Test 13: Handle Network Error
**Steps:**
1. Turn off internet
2. Open booking modal
3. Try to load amenity details

**Expected Result:**
- Shows loading spinner
- Eventually shows error message
- Can retry when internet is back

### ✅ Test 14: Handle Invalid Amenity
**Steps:**
1. Manually pass invalid amenityId
2. Try to open booking modal

**Expected Result:**
- Shows error: "Amenity not found"
- Modal closes gracefully

---

## Performance

### ✅ Test 15: Check Performance
**Metrics:**
- Amenity details load: < 2 seconds
- Slot availability check: < 1 second
- Booking creation: < 2 seconds
- Real-time updates: < 3 seconds

**Steps:**
1. Monitor console timestamps
2. Check for any lag in UI

**Expected Result:**
- All operations complete within expected time
- No UI freezing
- Smooth animations

---

## Data Integrity

### ✅ Test 16: Verify Booking Data
**Steps:**
1. Create a booking
2. Check Firestore console
3. Verify booking document

**Expected Fields:**
```
- userId: {userId}
- amenityId: {amenityId}
- date: {timestamp}
- timeSlot: "9:00 AM - 10:00 AM"
- numberOfPeople: 1
- bookingType: "daily"
- status: "confirmed"
- createdAt: {timestamp}
```

### ✅ Test 17: Verify Capacity Calculation
**Steps:**
1. Create multiple bookings for same slot
2. Check total numberOfPeople sum
3. Verify slot becomes full

**Expected Result:**
- Sum of numberOfPeople matches capacity
- Slot correctly marked as full
- No overbooking possible

---

## Summary
All tests should pass with the type casting fix in place. The booking system now:
- ✅ Safely converts Firestore arrays
- ✅ Filters past time slots correctly
- ✅ Validates capacity accurately
- ✅ Prevents overbooking
- ✅ Shows correct UI states
- ✅ Handles errors gracefully
