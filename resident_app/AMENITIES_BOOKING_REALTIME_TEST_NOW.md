# Amenities Booking - Real-Time Test Guide 🧪

## Quick Test Steps

### Test 1: Auto-Select Today
1. Open the app
2. Navigate to Amenities
3. Click "Book" on any amenity
4. **Expected**: Modal opens and today's date is already selected
5. **Check Console**: Should show "✅ Auto-selected today: YYYY-MM-DD"

### Test 2: Past Slots Hidden (Current Time 9:32 AM)
1. Open amenities booking modal at 9:32 AM
2. Today's date should be auto-selected
3. **Expected**: 
   - Slots before 9:32 AM are NOT shown (6:00 AM, 7:00 AM, 8:00 AM, 9:00 AM)
   - Slots from 9:32 AM onwards ARE shown (10:00 AM, 11:00 AM, etc.)
4. **Check Console**: Should show time comparison for each slot

### Test 3: Real-Time Accuracy
1. Open modal at 9:32 AM
2. Wait 2 minutes (now 9:34 AM)
3. Select a different date, then select today again
4. **Expected**: 
   - Console shows "Current time (FRESH): 9:34:XX"
   - 9:00 AM slot is now hidden (was available at 9:32)
5. **Why**: Proves fresh time is fetched each time

### Test 4: Future Date Shows All Slots
1. Open modal at 9:32 AM
2. Select tomorrow's date
3. **Expected**: All time slots are shown (no past slots hidden)
4. **Check Console**: Should show "ℹ️  Selected date is in the future - no past slots"

### Test 5: Capacity Checking Works
1. Open modal and select today
2. Select a time slot
3. **Expected**: 
   - Slot shows remaining capacity (e.g., "8/10 spots")
   - If full, slot is disabled and shows "Full"
4. **Check Console**: Should show capacity details for each slot

### Test 6: Booking Creation
1. Select today's date
2. Select an available time slot (e.g., 10:00 AM)
3. Click "Confirm Booking"
4. **Expected**: Booking is created successfully
5. **Check Console**: Should show "✅ BOOKING CREATION COMPLETE"

## Console Output to Look For

### ✅ Correct Output
```
🔵 Loading amenity details for: amenity_123
✅ Loaded 14 time slots
✅ Auto-selected today: 2024-03-14
🔍 Loading slot availability for 2024-03-14 with 1 people
   Current time (FRESH): 9:32:15

⏰ STEP 3: Applying RULE 1 - Hide past time slots...
   ℹ️  Selected date is today - filtering past slots
   ❌ Slot past: 6:00 AM - 7:00 AM
   ✅ Slot available: 10:00 AM - 11:00 AM

✅ Available slots returned: 5 slots
```

### ❌ Wrong Output (Indicates Issue)
```
⚠️  No amenity details found
❌ Error loading availability
⚠️  No availability data loaded yet
```

## Debugging Tips

### If Past Slots Are Still Showing
1. Check console for time comparison logs
2. Verify current time is correct: `print(DateTime.now())`
3. Check if `_loadSlotAvailability()` is being called
4. Verify flow function is returning correct available slots

### If Modal Doesn't Auto-Select Today
1. Check console for "✅ Auto-selected today"
2. Verify `_loadAmenityDetails()` is completing
3. Check if `_selectedDate` is being set in setState

### If Capacity Checking Isn't Working
1. Check Firestore has booking data for the date
2. Verify booking status is "confirmed" or "pending"
3. Check if `numberOfPeople` field exists in bookings

## Test Scenarios

### Scenario 1: Morning Booking (9:32 AM)
- Current time: 9:32 AM
- Select: Today
- Expected: Slots before 9:32 AM hidden, 10:00 AM onwards shown

### Scenario 2: Afternoon Booking (3:45 PM)
- Current time: 3:45 PM
- Select: Today
- Expected: Slots before 3:45 PM hidden, 4:00 PM onwards shown

### Scenario 3: Evening Booking (7:30 PM)
- Current time: 7:30 PM
- Select: Today
- Expected: Slots before 7:30 PM hidden, 8:00 PM onwards shown (if available)

### Scenario 4: Future Date Booking
- Current time: 9:32 AM
- Select: Tomorrow
- Expected: All slots shown (no time filtering)

### Scenario 5: Past Date Booking
- Current time: 9:32 AM
- Select: Yesterday
- Expected: No slots available (all past)

## Success Criteria

✅ Modal auto-selects today on open
✅ Past slots are hidden (not shown as "Full")
✅ Real-time is fetched fresh each time
✅ Console shows detailed time comparisons
✅ Capacity checking works correctly
✅ Booking creation succeeds
✅ Flow function follows pattern: Validate → Execute → Log → Return

## Quick Commands

### View Console Logs
```
flutter logs
```

### Filter for Amenities Logs
```
flutter logs | grep -i "amenities\|booking\|slot"
```

### Test on Device
```
flutter run -v
```

## Notes

- Real-time is fetched using `DateTime.now()` which gets system time
- Time comparison uses `<=` to hide slots that are currently happening
- Flow function is called every time availability is checked
- Modal auto-loads availability for today on init
