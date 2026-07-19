# 🚀 Amenities Booking - Quick Reference

## Quick Start

### 1. Create Test Amenity in Firestore
```
Firebase Console → Firestore → amenities → Add Document

Paste this:
{
  "name": "Gym",
  "type": "Sports",
  "buildingId": "7Njk8rUiTgUutQ0c6V7E",
  "organizationId": "org_456",
  "adminId": "lMix368zbKWsxh35xthSfUJNKKy1",
  "isFree": false,
  "pricePerDay": 50,
  "hasSubscriptionPackages": true,
  "subscriptionPackages": {
    "Weekly": 1000,
    "Monthly": 5000,
    "Yearly": 10000
  },
  "allowMultipleBookings": true,
  "maxCapacity": 10,
  "timeSlots": [
    "6:00 AM - 7:00 AM",
    "7:00 AM - 8:00 AM",
    "8:00 AM - 9:00 AM",
    "5:00 PM - 6:00 PM",
    "6:00 PM - 7:00 PM",
    "7:00 PM - 8:00 PM"
  ],
  "bookingDurations": ["1 hour"],
  "isAvailable": true,
  "iconName": "gym"
}
```

### 2. Test the App
```
1. Hot reload app
2. Navigate to Amenities Booking
3. Tap on Gym card
4. See booking type selector (Daily/Weekly/Monthly/Yearly)
5. Select a date
6. See time slots with capacity (e.g., "5/10 spots")
7. Select a time slot
8. Confirm booking
9. Check "My Bookings" section
```

---

## Features Overview

### ✅ Subscription Packages
- Daily bookings
- Weekly packages
- Monthly packages
- Yearly packages
- Dynamic price display

### ✅ Multiple User Capacity
- Single booking mode (1 user per slot)
- Multiple booking mode (up to X users per slot)
- Real-time capacity tracking
- Remaining spots display

### ✅ Availability Checking
- Real-time slot availability
- Capacity validation
- Blocked slot indicators
- Re-validation before booking

### ✅ Calendar Blocking
- Blocks fully booked dates
- Visual red indicator
- Prevents selection of blocked dates
- Updates in real-time

---

## Firestore Field Reference

### Required Fields:
```
name: string
type: string
buildingId: string
isAvailable: boolean
timeSlots: array of strings
```

### Pricing Fields:
```
isFree: boolean
pricePerDay: number (if not free)
hasSubscriptionPackages: boolean
subscriptionPackages: {
  Weekly: number,
  Monthly: number,
  Yearly: number
}
```

### Capacity Fields:
```
allowMultipleBookings: boolean
maxCapacity: number (default: 1)
```

---

## Service Methods Quick Reference

### Get Amenity Details:
```dart
final amenity = await BookingFirestoreService()
    .getAmenityDetails('amenity_id');
```

### Check Slot Availability:
```dart
final availability = await BookingFirestoreService()
    .checkSlotAvailability(
      amenityId: 'amenity_id',
      date: DateTime(2026, 2, 26),
      timeSlot: '6:00 AM - 7:00 AM',
    );

// Returns: {available, reason, remainingSpots, totalCapacity}
```

### Check if Date is Fully Booked:
```dart
final isBlocked = await BookingFirestoreService()
    .isDateFullyBooked(
      amenityId: 'amenity_id',
      date: DateTime(2026, 2, 26),
    );
```

### Create Booking:
```dart
final result = await BookingFirestoreService()
    .createBooking(
      amenityId: 'amenity_id',
      amenityName: 'Gym',
      date: DateTime(2026, 2, 26),
      timeSlot: '6:00 AM - 7:00 AM',
    );
```

---

## Testing Scenarios

### Scenario 1: Single User Amenity
```
allowMultipleBookings: false
maxCapacity: 1

Expected:
- Shows "Available" or "Booked"
- Only 1 booking per slot
- Slot blocked immediately when booked
```

### Scenario 2: Multiple User Amenity
```
allowMultipleBookings: true
maxCapacity: 10

Expected:
- Shows "X/10 spots"
- Multiple users can book same slot
- Slot blocked when 10 bookings reached
```

### Scenario 3: With Packages
```
hasSubscriptionPackages: true
subscriptionPackages: {Weekly: 1000, Monthly: 5000}

Expected:
- Booking type selector appears
- Shows all package options
- User can select daily or package
```

---

## Console Logs to Watch

### Success Logs:
```
✅ Loaded 7 time slots
✅ Found 3 blocked dates
✅ Available: true, Remaining: 5/10
✅ Booking created successfully!
```

### Warning Logs:
```
⚠️  No amenity details found
⚠️  No bookings found
```

### Error Logs:
```
❌ Error loading amenity details
❌ Error checking availability
❌ Firebase Error: permission-denied
```

---

## Troubleshooting

### Issue: No amenities showing
**Solution:**
1. Check `isAvailable` is `true`
2. Check `buildingId` matches user's building
3. Check Firestore rules allow read access

### Issue: Time slots not loading
**Solution:**
1. Check `timeSlots` field exists in amenity
2. Check it's an array of strings
3. Check console for errors

### Issue: Booking type selector not showing
**Solution:**
1. Check `hasSubscriptionPackages` is `true`
2. Check `subscriptionPackages` field exists
3. Check it has at least one package (Weekly/Monthly/Yearly)

### Issue: Capacity not showing
**Solution:**
1. Check `allowMultipleBookings` is `true`
2. Check `maxCapacity` field exists
3. Check it's a number greater than 1

### Issue: Calendar not blocking dates
**Solution:**
1. Check bookings exist in Firestore
2. Check `status` is 'confirmed' or 'pending'
3. Check date and time slot match

---

## Quick Commands

### Run test script:
```bash
# Not needed - just hot reload the app
```

### Check Firestore data:
```
Firebase Console → Firestore
- Check amenities collection
- Check bookings collection
- Verify field names match exactly
```

### View console logs:
```
VS Code → Debug Console
Look for:
- 🔵 Loading amenity details
- ✅ Loaded X time slots
- 📅 Checking blocked dates
- 🔍 Checking availability
```

---

## Summary

The amenities booking system now supports:
- ✅ Daily and package bookings
- ✅ Multiple user capacity
- ✅ Real-time availability
- ✅ Calendar blocking
- ✅ Capacity indicators

**Status: PRODUCTION READY** 🚀

For detailed documentation, see:
- `AMENITIES_BOOKING_ADVANCED_COMPLETE.md` - Complete implementation guide
- `AMENITIES_ADVANCED_STRUCTURE.md` - Data structure reference
- `AMENITIES_COMPLETE_IMPLEMENTATION.md` - Implementation summary

