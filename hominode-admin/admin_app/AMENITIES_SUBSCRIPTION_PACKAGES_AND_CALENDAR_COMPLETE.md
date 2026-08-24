# Amenities Subscription Packages & Calendar View - COMPLETE

## Status: ✅ COMPLETE

## Overview
Implemented two major features for the amenities booking system:
1. **Subscription Packages**: Weekly, monthly, and yearly packages for amenities like gym memberships
2. **Calendar View**: Visual calendar showing all bookings with support for multiple bookings on the same date/time

## Feature 1: Subscription Packages

### Purpose
Some amenities like gyms require recurring subscriptions rather than one-time bookings. This feature allows admins to configure subscription packages (weekly, monthly, yearly) for amenities.

### Implementation

#### Firestore Structure
```javascript
amenities/{amenityId}
{
  // Existing fields...
  name: "Gym",
  isFree: false,
  pricePerDay: 100,
  
  // NEW: Subscription Packages
  hasSubscriptionPackages: true,
  subscriptionPackages: {
    "Weekly": 500,
    "Monthly": 1500,
    "Yearly": 15000
  }
}
```

#### UI Components

**Add Amenity Modal - Subscription Section**:
- Toggle switch to enable subscription packages
- Three input fields for Weekly, Monthly, Yearly prices
- Only shown when pricing type is "Paid"
- Optional - admin can leave packages empty

**Display**:
- Amenity cards show subscription price if available
- Format: "₹1500/Monthly" instead of "₹100/day"

### Usage Examples

#### Example 1: Gym with Subscriptions
```dart
await amenityService.addAmenity(
  name: "Gym",
  type: "Sports",
  isFree: false,
  pricePerDay: 100,  // Daily rate if no subscription
  hasSubscriptionPackages: true,
  subscriptionPackages: {
    "Weekly": 500,
    "Monthly": 1500,
    "Yearly": 15000,
  },
  buildingId: "building123",
  buildingName: "Sunrise Apartments",
);
```

#### Example 2: Swimming Pool (No Subscriptions)
```dart
await amenityService.addAmenity(
  name: "Swimming Pool",
  type: "Recreation",
  isFree: false,
  pricePerDay: 50,
  hasSubscriptionPackages: false,  // No subscriptions
  buildingId: "building123",
  buildingName: "Sunrise Apartments",
);
```

## Feature 2: Calendar View with Multiple Bookings

### Purpose
Provide admins with a visual calendar to see all bookings at a glance, with special indicators for dates with multiple bookings on the same time slot.

### Implementation

#### Calendar Features
1. **Monthly Calendar View**
   - Shows current month with navigation
   - Today's date highlighted
   - Selected date highlighted
   - Booking indicators (dots) on dates with bookings

2. **Date Selection**
   - Click any date to view bookings for that day
   - Shows booking count for selected date
   - Automatically loads bookings for visible month

3. **Multiple Bookings Display**
   - Groups bookings by amenity and time slot
   - Shows count badge when multiple people booked same slot
   - Lists all residents for each time slot
   - Color-coded status indicators

#### UI Layout
```
┌─────────────────────────────────────┐
│  Calendar (Monthly View)            │
│  • Dots on dates with bookings      │
│  • Selected date highlighted        │
├─────────────────────────────────────┤
│  Selected Date: 26/01/2024          │
│  [3 bookings]                       │
├─────────────────────────────────────┤
│  Bookings List:                     │
│                                     │
│  ┌─────────────────────────────┐   │
│  │ Swimming Pool               │   │
│  │ 6:00 AM - 7:00 AM          │   │
│  │ [👥 3 bookings]            │   │
│  │                             │   │
│  │ • John Doe (A-101) [Pending]│   │
│  │ • Jane Smith (B-202) [Approved]│
│  │ • Bob Wilson (C-303) [Confirmed]│
│  └─────────────────────────────┘   │
│                                     │
│  ┌─────────────────────────────┐   │
│  │ Gym                         │   │
│  │ 7:00 AM - 8:00 AM          │   │
│  │ [👥 2 bookings]            │   │
│  │                             │   │
│  │ • Alice Brown (A-102) [Confirmed]│
│  │ • Charlie Davis (B-201) [Pending]│
│  └─────────────────────────────┘   │
└─────────────────────────────────────┘
```

### Technical Details

#### New Service Methods

**`getBookingsByDateRange`**:
```dart
Stream<List<AmenityBookingModel>> getBookingsByDateRange({
  required DateTime startDate,
  required DateTime endDate,
})
```
- Fetches bookings for a date range
- Used for calendar month view
- Returns real-time stream

**`getBookingsGroupedByDate`**:
```dart
Future<Map<DateTime, List<AmenityBookingModel>>> getBookingsGroupedByDate({
  required DateTime startDate,
  required DateTime endDate,
})
```
- Groups bookings by date for calendar markers
- Returns Map<DateTime, List<Bookings>>
- Used to show dots on calendar dates

#### Calendar Widget

**`_BookingsCalendarView`**:
- Stateful widget managing calendar state
- Uses `table_calendar` package
- Loads bookings for current month
- Reloads when month changes
- Groups bookings by time slot for display

**Key Features**:
- Month navigation (previous/next)
- Date selection
- Event markers (dots) on dates with bookings
- Booking count badge
- Grouped booking display

### Multiple Bookings Display Logic

```dart
// Group bookings by amenity + time slot
final Map<String, List<AmenityBookingModel>> bookingsBySlot = {};
for (var booking in bookings) {
  final key = '${booking.amenityName}_${booking.timeSlot}';
  if (!bookingsBySlot.containsKey(key)) {
    bookingsBySlot[key] = [];
  }
  bookingsBySlot[key]!.add(booking);
}

// Display each group
for (var entry in bookingsBySlot.entries) {
  final slotBookings = entry.value;
  // Show amenity name, time slot
  // Show count badge if multiple bookings
  // List all residents with status
}
```

## Updated Files

### 1. `pubspec.yaml`
**Added**:
```yaml
dependencies:
  table_calendar: ^3.0.9  # For calendar view
```

### 2. `lib/services/amenity_service.dart`
**Added to AmenityModel**:
- `hasSubscriptionPackages`: bool
- `subscriptionPackages`: Map<String, double>
- Updated `priceDisplay` getter to show subscription price

**New Methods**:
- `getBookingsByDateRange()`: Stream bookings for date range
- `getBookingsGroupedByDate()`: Group bookings by date
- `_formatDate()`: Helper to format dates as YYYY-MM-DD

**Updated Methods**:
- `addAmenity()`: Added subscription package parameters

### 3. `lib/widgets/add_amenity_modal.dart`
**Added**:
- `_hasSubscriptionPackages`: bool state
- `_packageControllers`: Map of controllers for package prices
- Subscription packages UI section with toggle
- Three input fields for Weekly, Monthly, Yearly prices
- Updated submit logic to include packages

### 4. `lib/amenities_management_screen.dart`
**Replaced**:
- Simple bookings list with calendar view
- Added `table_calendar` import
- Created `_BookingsCalendarView` widget

**New Widget Features**:
- Monthly calendar with event markers
- Date selection
- Booking count display
- Grouped bookings by time slot
- Multiple bookings indicator
- Resident list with status

## Data Flow

### Subscription Packages Flow
```
1. Admin creates amenity
   ↓
2. Enables "Subscription Packages"
   ↓
3. Enters prices for Weekly, Monthly, Yearly
   ↓
4. Data saved to Firestore amenities collection
   ↓
5. Resident app shows subscription options
   ↓
6. Resident selects package and subscribes
   ↓
7. Subscription stored in bookings collection
```

### Calendar View Flow
```
1. Admin opens Bookings tab
   ↓
2. Calendar loads current month
   ↓
3. Fetch bookings for month from Firestore
   ↓
4. Group bookings by date
   ↓
5. Show dots on dates with bookings
   ↓
6. Admin selects a date
   ↓
7. Show all bookings for that date
   ↓
8. Group by amenity + time slot
   ↓
9. Display with multiple bookings indicator
   ↓
10. Show all residents for each slot
```

## Benefits

### Subscription Packages
1. **Flexibility**: Support both one-time and recurring bookings
2. **Revenue Model**: Better for amenities like gyms
3. **User Choice**: Residents can choose package that suits them
4. **Pricing Options**: Weekly, monthly, yearly options

### Calendar View
1. **Visual Overview**: See all bookings at a glance
2. **Easy Navigation**: Month-by-month navigation
3. **Multiple Bookings**: Clear indication of shared slots
4. **Detailed View**: See all residents for each time slot
5. **Status Tracking**: Color-coded status for each booking
6. **Real-time Updates**: Calendar updates automatically

## Testing Checklist

- [x] Add amenity with subscription packages
- [x] Add amenity without subscription packages
- [x] Display subscription price on amenity card
- [x] Calendar shows current month
- [x] Calendar navigation (previous/next month)
- [x] Dots appear on dates with bookings
- [x] Select date shows bookings for that date
- [x] Multiple bookings grouped by time slot
- [x] Count badge shows number of bookings
- [x] All residents listed for each slot
- [x] Status colors displayed correctly
- [x] Empty state when no bookings
- [x] Calendar reloads when month changes
- [x] No compilation errors

## Usage Scenarios

### Scenario 1: Gym Membership
```
Admin creates Gym amenity:
- Enable subscription packages
- Weekly: ₹500
- Monthly: ₹1500
- Yearly: ₹15000

Resident subscribes:
- Selects "Monthly" package
- Pays ₹1500
- Gets access for 30 days
```

### Scenario 2: Swimming Pool (Multiple Bookings)
```
Date: January 26, 2024
Time: 6:00 AM - 7:00 AM
Capacity: 30 people

Calendar shows:
- Dot on January 26
- Click date → Shows "Swimming Pool"
- Badge: "👥 15 bookings"
- Lists all 15 residents with status
```

### Scenario 3: Community Hall (Exclusive)
```
Date: January 26, 2024
Duration: Full day

Calendar shows:
- Dot on January 26
- Click date → Shows "Community Hall"
- Single booking (no badge)
- Shows resident details
```

## Flow Function Compliance

✅ **Subscription packages stored in amenities collection**
✅ **Weekly, monthly, yearly options available**
✅ **Calendar view shows all bookings**
✅ **Multiple bookings on same date/time displayed**
✅ **Grouped by amenity and time slot**
✅ **Visual indicators for multiple bookings**
✅ **Real-time updates from Firestore**
✅ **Proper date formatting (YYYY-MM-DD)**

## Next Steps (Optional Enhancements)

1. **Subscription Management**: Track active subscriptions
2. **Auto-renewal**: Automatic subscription renewal
3. **Expiry Notifications**: Alert residents before expiry
4. **Usage Tracking**: Track how many times resident used amenity
5. **Calendar Filters**: Filter by amenity type or status
6. **Export Calendar**: Export bookings to PDF/CSV
7. **Booking Conflicts**: Highlight conflicting bookings
8. **Capacity Visualization**: Show capacity utilization on calendar

## Conclusion

The amenities booking system now supports:
1. **Subscription packages** for recurring bookings (gym memberships, etc.)
2. **Calendar view** with visual indicators for multiple bookings
3. **Grouped display** showing all residents for each time slot
4. **Real-time updates** with automatic calendar refresh

Both features are fully integrated, tested, and ready for production use. The system provides admins with powerful tools to manage amenity bookings efficiently while supporting different pricing models and booking patterns.
