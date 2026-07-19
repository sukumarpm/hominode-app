# Amenities Booking Testing Guide

## 🧪 Quick Testing Checklist

### Test 1: Past Time Slots Hidden ✅
**Setup:**
- Current time: 9:08 AM
- Selected date: Today
- Time slots: 6:00 AM, 7:00 AM, 8:00 AM, 9:00 AM, 10:00 AM

**Expected Result:**
- 6:00 AM - 7:00 AM: HIDDEN (grey)
- 7:00 AM - 8:00 AM: HIDDEN (grey)
- 8:00 AM - 9:00 AM: HIDDEN (grey)
- 9:00 AM - 10:00 AM: SHOWN (blue)
- 10:00 AM - 11:00 AM: SHOWN (blue)

**How to Test:**
1. Open amenities booking modal
2. Select today's date
3. Check time slot list
4. Verify past slots are not shown

---

### Test 2: Full Capacity Slots Hidden ✅
**Setup:**
- Amenity capacity: 20 people
- Date: 2024-03-15 (any future date)
- Time slot: 2:00 PM - 3:00 PM
- Existing bookings:
  - User A: 10 people (confirmed)
  - User B: 10 people (confirmed)
  - Total: 20 people (at capacity)

**Expected Result:**
- 2:00 PM - 3:00 PM: HIDDEN (red, "Full")

**How to Test:**
1. Create test bookings in Firestore for the date/time
2. Open amenities booking modal
3. Select the date
4. Check if 2:00 PM slot is hidden

---

### Test 3: Partial Capacity Shown ✅
**Setup:**
- Amenity capacity: 20 people
- Date: 2024-03-15
- Time slot: 2:00 PM - 3:00 PM
- Existing bookings:
  - User A: 5 people (confirmed)
  - User B: 10 people (confirmed)
  - Total: 15 people (5 spots remaining)

**Expected Result:**
- 2:00 PM - 3:00 PM: SHOWN (blue, "5/20 spots")

**How to Test:**
1. Create test bookings in Firestore
2. Open amenities booking modal
3. Select the date
4. Verify slot shows remaining capacity

---

### Test 4: Future Date Shows All Slots ✅
**Setup:**
- Current time: 9:08 AM
- Selected date: Tomorrow
- Time slots: 6:00 AM, 7:00 AM, 8:00 AM, 9:00 AM, 10:00 AM

**Expected Result:**
- All slots SHOWN (past time rules don't apply to future dates)

**How to Test:**
1. Open amenities booking modal
2. Select tomorrow's date
3. Verify all slots are shown

---

### Test 5: Booking Validation ✅
**Setup:**
- Select a slot that appears available
- Another user books the same slot before you confirm
- You click "Confirm Booking"

**Expected Result:**
- Error message: "This slot is no longer available"
- Booking is NOT created

**How to Test:**
1. Open booking modal
2. Select a slot
3. Have another user book the same slot (in another browser/device)
4. Click "Confirm Booking"
5. Verify error message appears

---

### Test 6: Multiple People Booking ✅
**Setup:**
- Amenity capacity: 20 people
- Date: 2024-03-15
- Time slot: 2:00 PM - 3:00 PM
- Existing bookings: 15 people
- You want to book for: 6 people

**Expected Result:**
- Slot is HIDDEN (not enough capacity for 6 people)

**How to Test:**
1. Create test bookings for 15 people
2. Open booking modal
3. Select "6 people" in the people selector
4. Select the date
5. Verify slot is hidden

---

## 🔍 Console Logging

When testing, check the console for detailed logs:

```
🔵 AMENITIES BOOKING LOGIC: Getting available time slots...
   Amenity: pool123
   Date: 2024-03-14
   Total slots: 4
   Capacity: 20

📍 Checking slot: 6:00 AM - 7:00 AM
   🔍 Checking if time slot is past...
   Selected date: 2024-03-14
   Current time: 2024-03-14 09:08:00.000
   Time slot: 6:00 AM - 7:00 AM
   📅 Selected date is today - checking time slot...
   Slot start time: 2024-03-14 06:00:00.000
   Current time: 2024-03-14 09:08:00.000
   ❌ Time slot has passed (slot: 6:00, current: 9:08)
   ❌ RULE 1 FAILED: Time slot has passed

📍 Checking slot: 9:00 AM - 10:00 AM
   ✅ RULE 1 PASSED: Time slot is not in the past
   📊 Calculating total persons booked...
   📊 Found 2 total bookings for this date
   ✅ Booking: 10 people (Status: confirmed)
   ✅ Booking: 5 people (Status: confirmed)
   📊 Total persons booked for this slot: 15
   ✅ RULE 2 PASSED: Slot has available capacity
   ✅ SLOT AVAILABLE

✅ RESULT: 1 available slots out of 4
   Available slots: [9:00 AM - 10:00 AM]
```

---

## 📊 Firestore Test Data

### Create Test Bookings

```javascript
// Firestore Console - Add to amenityBookings collection

// Booking 1: 10 people
{
  "amenityId": "pool123",
  "date": Timestamp.fromDate(new Date(2024, 2, 15, 14, 0, 0)),
  "timeSlot": "2:00 PM - 3:00 PM",
  "userId": "user1",
  "numberOfPeople": 10,
  "status": "confirmed",
  "createdAt": Timestamp.now()
}

// Booking 2: 10 people
{
  "amenityId": "pool123",
  "date": Timestamp.fromDate(new Date(2024, 2, 15, 14, 0, 0)),
  "timeSlot": "2:00 PM - 3:00 PM",
  "userId": "user2",
  "numberOfPeople": 10,
  "status": "confirmed",
  "createdAt": Timestamp.now()
}
```

---

## 🐛 Debugging Tips

### If Past Slots Are Still Showing
1. Check console logs for time parsing errors
2. Verify current time is correct
3. Check if selected date is actually today
4. Verify time slot format is "HH:MM AM/PM - HH:MM AM/PM"

### If Full Slots Are Still Showing
1. Check Firestore bookings have `numberOfPeople` field
2. Verify bookings have status "confirmed" or "pending"
3. Check if bookings are for the correct date and time slot
4. Verify amenity has correct `maxCapacity` set

### If Booking Validation Fails
1. Check console for validation error
2. Verify slot is actually available
3. Check if another booking was created between check and confirm
4. Verify amenity capacity is set correctly

---

## ✅ Verification Checklist

- [ ] Past time slots are hidden when selected date is today
- [ ] Full capacity slots are hidden
- [ ] Partial capacity slots show remaining spots
- [ ] Future dates show all slots
- [ ] Booking validation prevents race conditions
- [ ] Multiple people booking respects capacity
- [ ] Console logs show detailed information
- [ ] Error messages are clear and helpful
- [ ] UI updates correctly after date selection
- [ ] Remaining capacity updates in real-time

---

## 🎯 Test Execution Steps

1. **Setup Test Data**
   - Create amenity with capacity 20
   - Create test bookings in Firestore

2. **Test Past Slots**
   - Open booking modal
   - Select today's date
   - Verify past slots are hidden

3. **Test Full Capacity**
   - Create bookings totaling 20 people
   - Select the date
   - Verify slot is hidden

4. **Test Partial Capacity**
   - Create bookings totaling 15 people
   - Select the date
   - Verify slot shows 5 remaining spots

5. **Test Booking Validation**
   - Select a slot
   - Have another user book it
   - Try to confirm
   - Verify error message

6. **Test Multiple People**
   - Select 6 people
   - Verify only slots with 6+ capacity are shown

---

## 📝 Test Results Template

```
Test Date: ___________
Tester: ___________

Test 1: Past Time Slots
- Result: PASS / FAIL
- Notes: ___________

Test 2: Full Capacity
- Result: PASS / FAIL
- Notes: ___________

Test 3: Partial Capacity
- Result: PASS / FAIL
- Notes: ___________

Test 4: Future Date
- Result: PASS / FAIL
- Notes: ___________

Test 5: Booking Validation
- Result: PASS / FAIL
- Notes: ___________

Test 6: Multiple People
- Result: PASS / FAIL
- Notes: ___________

Overall: PASS / FAIL
Issues Found: ___________
```

---

## 🚀 Ready to Test!

The amenities booking logic is now integrated and ready for testing. Follow the scenarios above to verify everything works correctly.

