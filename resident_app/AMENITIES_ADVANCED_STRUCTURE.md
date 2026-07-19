# 🏢 Advanced Amenities Booking System - Complete Structure

## Firestore Data Structure

### Amenity Document (amenities collection)
```json
{
  "name": "Gym",
  "type": "Sports",
  "buildingId": "7Njk8rUiTgUutQ0c6V7E",
  "buildingName": "tower z",
  "organizationId": "org_456",
  "adminId": "lMix368zbKWsxh35xthSfUJNKKy1",
  "adminName": "Admin Name",
  "adminEmail": "admin@example.com",
  
  // Pricing Options
  "isFree": false,
  "pricePerDay": 50,
  "hasSubscriptionPackages": true,
  "subscriptionPackages": {
    "Monthly": 5000,
    "Weekly": 1000,
    "Yearly": 10000
  },
  
  // Capacity Management
  "allowMultipleBookings": true,
  "maxCapacity": 10,
  
  // Time Management
  "timeSlots": [
    "6:00 AM - 7:00 AM",
    "7:00 AM - 8:00 AM",
    "8:00 AM - 9:00 AM",
    "9:00 PM - 10:00 PM",
    "7:00 PM - 8:00 PM",
    "6:00 PM - 7:00 PM",
    "5:00 PM - 6:00 PM"
  ],
  "bookingDurations": ["1 hour"],
  
  // Availability
  "isAvailable": true,
  "iconName": "gym",
  "imageUrl": null,
  "description": null,
  
  // Timestamps
  "createdAt": "26 February 2026 at 11:19:42 UTC+5:30",
  "updatedAt": "26 February 2026 at 11:19:42 UTC+5:30"
}
```

### Booking Document (bookings collection)
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
  
  // Booking Details
  "bookingType": "daily",  // "daily", "weekly", "monthly", "yearly"
  "date": "Timestamp",
  "timeSlot": "6:00 AM - 7:00 AM",
  "duration": "1 hour",
  
  // Pricing
  "price": 50,
  "packageType": null,  // "Monthly", "Weekly", "Yearly" or null for daily
  
  // Status
  "status": "confirmed",  // "confirmed", "cancelled", "completed"
  
  // Timestamps
  "createdAt": "Timestamp",
  "updatedAt": "Timestamp",
  
  // Subscription Info (if applicable)
  "subscriptionStartDate": null,
  "subscriptionEndDate": null
}
```

---

## Flow Function Logic

### 1. Fetch Amenities
```
Query: amenities collection
WHERE isAvailable == true
WHERE buildingId == user.buildingId

Display:
- Name, Type, Icon
- Price per day
- Subscription packages (if hasSubscriptionPackages == true)
- Capacity info (if allowMultipleBookings == true)
- Current availability status
```

### 2. Check Availability for Date/Time
```
For each date + timeSlot:
  Query: bookings collection
  WHERE amenityId == selected_amenity_id
  WHERE date == selected_date
  WHERE timeSlot == selected_time_slot
  WHERE status IN ["confirmed", "pending"]
  
  Count bookings = result.length
  
  IF amenity.allowMultipleBookings == false:
    IF count > 0:
      Slot is BLOCKED (fully booked)
    ELSE:
      Slot is AVAILABLE
  
  ELSE IF amenity.allowMultipleBookings == true:
    IF count >= amenity.maxCapacity:
      Slot is BLOCKED (capacity full)
    ELSE:
      Slot is AVAILABLE
      Show: "X/Y spots remaining"
```

### 3. Calendar Blocking
```
For each date in calendar:
  For each timeSlot:
    Check availability (as above)
    
    IF all slots blocked for a date:
      Mark date as BLOCKED in calendar
    ELSE:
      Mark date as AVAILABLE
```

### 4. Booking Creation
```
1. Validate capacity:
   - Check current bookings for date + timeSlot
   - Ensure capacity not exceeded
   
2. Calculate price:
   IF bookingType == "daily":
     price = amenity.pricePerDay
   ELSE IF bookingType == "weekly":
     price = amenity.subscriptionPackages.Weekly
   ELSE IF bookingType == "monthly":
     price = amenity.subscriptionPackages.Monthly
   ELSE IF bookingType == "yearly":
     price = amenity.subscriptionPackages.Yearly
   
3. Create booking document
4. Return success/failure
```

---

## UI Flow

### Amenity Card Display
```
┌─────────────────────────┐
│     [Icon]              │
│                         │
│   Swimming Pool         │
│   Recreation            │
│                         │
│   ₹50/day               │
│   📦 Packages Available │
│                         │
│   [10/10 Available]     │  ← If allowMultipleBookings
│   OR                    │
│   [Available]           │  ← If single booking
└─────────────────────────┘
```

### Booking Modal Flow
```
1. Select Booking Type:
   ○ Daily (₹50)
   ○ Weekly Package (₹1000)
   ○ Monthly Package (₹5000)
   ○ Yearly Package (₹10000)

2. Select Date:
   [Calendar with blocked dates shown in red]
   
3. Select Time Slot:
   ✓ 6:00 AM - 7:00 AM (8/10 spots)
   ✓ 7:00 AM - 8:00 AM (5/10 spots)
   ✗ 8:00 AM - 9:00 AM (FULL)
   
4. Confirm Booking
```

---

## Implementation Requirements

### Service Methods Needed:
1. `getAmenityDetails(amenityId)` - Fetch amenity with all fields
2. `checkSlotAvailability(amenityId, date, timeSlot)` - Check capacity
3. `getBookingsForDateRange(amenityId, startDate, endDate)` - For calendar
4. `createBooking(bookingData)` - Create with validation
5. `getAvailableSpots(amenityId, date, timeSlot)` - Get remaining capacity

### UI Components Needed:
1. Enhanced Amenity Card - Show packages and capacity
2. Booking Type Selector - Radio buttons for daily/packages
3. Smart Calendar - Block fully booked dates
4. Time Slot Selector - Show remaining spots
5. Capacity Indicator - Visual representation

---

## Example Scenarios

### Scenario 1: Single User Amenity (Tennis Court)
```json
{
  "name": "Tennis Court",
  "allowMultipleBookings": false,
  "maxCapacity": 1
}
```
**Behavior**: Only 1 booking per time slot. If booked, slot is blocked.

### Scenario 2: Multiple User Amenity (Gym)
```json
{
  "name": "Gym",
  "allowMultipleBookings": true,
  "maxCapacity": 10
}
```
**Behavior**: Up to 10 bookings per time slot. Shows "X/10 spots remaining".

### Scenario 3: Subscription Package
```json
{
  "name": "Swimming Pool",
  "hasSubscriptionPackages": true,
  "subscriptionPackages": {
    "Monthly": 5000,
    "Weekly": 1000
  }
}
```
**Behavior**: User can choose daily or package. Package gives access for duration.

---

## Calendar Blocking Logic

```dart
// Pseudo-code
for (date in calendarMonth) {
  bool hasAvailableSlot = false;
  
  for (timeSlot in amenity.timeSlots) {
    int bookingCount = getBookingCount(amenityId, date, timeSlot);
    
    if (amenity.allowMultipleBookings) {
      if (bookingCount < amenity.maxCapacity) {
        hasAvailableSlot = true;
        break;
      }
    } else {
      if (bookingCount == 0) {
        hasAvailableSlot = true;
        break;
      }
    }
  }
  
  if (!hasAvailableSlot) {
    blockDate(date);  // Show in red on calendar
  }
}
```

---

## Status Indicators

### Amenity Card:
- **Available** (Green) - Has capacity
- **Limited** (Orange) - < 30% capacity remaining
- **Full** (Red) - No capacity

### Time Slot:
- **Available** (Green) - Can book
- **Limited** (Orange) - Few spots left
- **Full** (Red) - Cannot book

### Calendar Date:
- **Normal** (White) - Has available slots
- **Blocked** (Red) - All slots full

---

This structure supports:
✅ Daily bookings
✅ Subscription packages (Weekly/Monthly/Yearly)
✅ Single user amenities
✅ Multiple user amenities with capacity
✅ Real-time availability checking
✅ Calendar blocking for full dates
✅ Capacity indicators
