# Flat Access Control - Visual Flow

## System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      RESIDENT APP                            │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌────────────────────────────────────────────────────┐    │
│  │              Main Navigation                        │    │
│  │  (Dashboard, Visitors, Bills, Events, Profile)     │    │
│  └────────────────────────────────────────────────────┘    │
│                          ▲                                   │
│                          │                                   │
│                          │ Wraps                             │
│                          │                                   │
│  ┌────────────────────────────────────────────────────┐    │
│  │          Flat Access Wrapper                        │    │
│  │  (Monitors access and switches screens)            │    │
│  └────────────────────────────────────────────────────┘    │
│                          ▲                                   │
│                          │                                   │
│                          │ Streams                           │
│                          │                                   │
│  ┌────────────────────────────────────────────────────┐    │
│  │      Flat Access Control Service                    │    │
│  │  (Validates flatId and buildingId)                 │    │
│  └────────────────────────────────────────────────────┘    │
│                          ▲                                   │
│                          │                                   │
│                          │ Queries                           │
│                          │                                   │
└──────────────────────────┼──────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                    FIRESTORE DATABASE                        │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  users/{userId}                                             │
│  ├─ flatId: "A-101"                                         │
│  ├─ buildingId: "building_001"                              │
│  └─ name, email, phone, role                                │
│                                                              │
│  bills/{billId}                                             │
│  ├─ flatId: "A-101"                                         │
│  └─ amount, status, dueDate                                 │
│                                                              │
│  amenities/{amenityId}                                      │
│  ├─ buildingId: "building_001"                              │
│  ├─ isAvailable: true                                       │
│  └─ name, type, price                                       │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

## Access Decision Flow

```
┌─────────────────┐
│   User Login    │
└────────┬────────┘
         │
         ▼
┌─────────────────────────────────────┐
│  Fetch User Document from Firestore │
└────────┬────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────┐
│     Check flatId Field              │
└────────┬────────────────────────────┘
         │
         ├─────────────────────────────┐
         │                             │
         ▼                             ▼
┌──────────────────┐         ┌──────────────────┐
│ flatId is null   │         │ flatId exists    │
│ or empty         │         │ (e.g., "A-101")  │
└────────┬─────────┘         └────────┬─────────┘
         │                             │
         ▼                             ▼
┌──────────────────┐         ┌──────────────────┐
│  ACCESS DENIED   │         │  ACCESS GRANTED  │
└────────┬─────────┘         └────────┬─────────┘
         │                             │
         ▼                             ▼
┌──────────────────┐         ┌──────────────────┐
│ Show Blocked     │         │ Show Dashboard   │
│ Screen           │         │ and Features     │
│                  │         │                  │
│ 🔒 Lock Icon     │         │ 🏠 Home          │
│                  │         │ 👥 Visitors      │
│ "Not assigned    │         │ 💰 Bills         │
│  to a flat"      │         │ 📅 Events        │
│                  │         │ 👤 Profile       │
│ [Contact Admin]  │         │                  │
│ [Sign Out]       │         │                  │
└──────────────────┘         └──────────────────┘
```

## Real-Time Update Flow

```
┌─────────────────────────────────────────────────────────────┐
│                    ADMIN CONSOLE                             │
└────────┬────────────────────────────────────────────────────┘
         │
         │ Admin assigns flatId to user
         │
         ▼
┌─────────────────────────────────────────────────────────────┐
│              FIRESTORE DATABASE                              │
│  users/{userId}                                             │
│  ├─ flatId: "A-101"  ← Updated                              │
│  └─ buildingId: "building_001"                              │
└────────┬────────────────────────────────────────────────────┘
         │
         │ Firestore triggers snapshot
         │
         ▼
┌─────────────────────────────────────────────────────────────┐
│              RESIDENT APP (User's Device)                    │
│                                                              │
│  StreamBuilder receives update                              │
│         │                                                    │
│         ▼                                                    │
│  FlatAccessWrapper re-evaluates                             │
│         │                                                    │
│         ▼                                                    │
│  Access granted (flatId now exists)                         │
│         │                                                    │
│         ▼                                                    │
│  Automatically switch from Blocked Screen to Dashboard      │
│                                                              │
│  ⏱️  Time: < 1 second                                       │
│  🔄 No app restart needed                                   │
│  ✨ Smooth transition                                        │
└─────────────────────────────────────────────────────────────┘
```

## Data Query Flow

### Bills Query

```
┌─────────────────┐
│  User Document  │
│  flatId: "A-101"│
└────────┬────────┘
         │
         ▼
┌─────────────────────────────────────┐
│  Bill Service                       │
│  streamBills()                      │
└────────┬────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────┐
│  Firestore Query                    │
│  .collection('bills')               │
│  .where('flatId', isEqualTo: flatId)│
│  .snapshots()                       │
└────────┬────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────┐
│  Matching Bills                     │
│  ├─ Bill 1: flatId = "A-101"        │
│  ├─ Bill 2: flatId = "A-101"        │
│  └─ Bill 3: flatId = "A-101"        │
└────────┬────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────┐
│  StreamBuilder                      │
│  Displays bills in UI               │
└─────────────────────────────────────┘
```

### Amenities Query

```
┌─────────────────┐
│  User Document  │
│  buildingId:    │
│  "building_001" │
└────────┬────────┘
         │
         ▼
┌─────────────────────────────────────┐
│  Booking Service                    │
│  streamAmenitiesRealtime()          │
└────────┬────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────┐
│  Firestore Query                    │
│  .collection('amenities')           │
│  .where('isAvailable', isEqualTo:   │
│         true)                       │
│  .where('buildingId', isEqualTo:    │
│         buildingId)                 │
│  .snapshots()                       │
└────────┬────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────┐
│  Matching Amenities                 │
│  ├─ Pool: buildingId = "building_001│
│  ├─ Gym: buildingId = "building_001"│
│  └─ Hall: buildingId = "building_001│
└────────┬────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────┐
│  StreamBuilder                      │
│  Displays amenities in UI           │
└─────────────────────────────────────┘
```

## Screen States

### Loading State
```
┌──────────────────────────┐
│                          │
│                          │
│      ⏳ Loading...       │
│                          │
│   (CircularProgress)     │
│                          │
│                          │
└──────────────────────────┘
```

### Access Blocked State
```
┌──────────────────────────┐
│                          │
│    ┌────────────┐        │
│    │     🔒     │        │
│    │  Lock Icon │        │
│    └────────────┘        │
│                          │
│  Access Restricted       │
│                          │
│  Your account is not     │
│  yet assigned to a flat. │
│  Please contact admin.   │
│                          │
│  ┌──────────────────┐   │
│  │ Contact Admin    │   │
│  └──────────────────┘   │
│                          │
│  ┌──────────────────┐   │
│  │ Sign Out         │   │
│  └──────────────────┘   │
│                          │
│  ┌──────────────────┐   │
│  │ ℹ️  Your account │   │
│  │ needs to be      │   │
│  │ linked to a flat │   │
│  └──────────────────┘   │
│                          │
└──────────────────────────┘
```

### Access Granted State
```
┌──────────────────────────┐
│  ┌────────────────────┐  │
│  │   Dashboard        │  │
│  │                    │  │
│  │  Welcome, John!    │  │
│  │  Flat: A-101       │  │
│  │                    │  │
│  │  📊 Summary Cards  │  │
│  │  🔔 Notifications  │  │
│  │  🎯 Quick Actions  │  │
│  │                    │  │
│  └────────────────────┘  │
│                          │
│  ┌────────────────────┐  │
│  │ 🏠 👥 💰 📅 👤   │  │
│  │ Bottom Navigation  │  │
│  └────────────────────┘  │
└──────────────────────────┘
```

### Error State
```
┌──────────────────────────┐
│                          │
│    ┌────────────┐        │
│    │     ⚠️     │        │
│    │ Error Icon │        │
│    └────────────┘        │
│                          │
│  Error checking access   │
│                          │
│  Please try again        │
│                          │
└──────────────────────────┘
```

## Component Hierarchy

```
MaterialApp
  └─ MainNavigation
      └─ FlatAccessWrapper ← Access control layer
          ├─ StreamBuilder<AccessControlResult>
          │   ├─ Loading → CircularProgressIndicator
          │   ├─ Error → Error message
          │   ├─ No Access → AccessBlockedScreen
          │   └─ Has Access → Scaffold
          │                     ├─ IndexedStack (screens)
          │                     │   ├─ DashboardScreen
          │                     │   ├─ VisitorManagementScreen
          │                     │   ├─ MaintenanceBillingScreen
          │                     │   ├─ EventsAnnouncementsScreen
          │                     │   └─ ProfileScreen
          │                     └─ BottomNavigationBar
          └─ FlatAccessControlService.streamFlatAccess()
```

## Service Layer

```
┌─────────────────────────────────────────────────────────────┐
│                    SERVICE LAYER                             │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  FlatAccessControlService                                   │
│  ├─ checkFlatAccess() → AccessControlResult                │
│  ├─ streamFlatAccess() → Stream<AccessControlResult>       │
│  └─ clearCache()                                            │
│                                                              │
│  BillFirestoreService                                       │
│  ├─ streamBills() → Stream<List<Bill>>                     │
│  ├─ getCurrentBill() → Future<Bill?>                       │
│  └─ getPaymentHistory() → Future<List<Bill>>               │
│                                                              │
│  BookingFirestoreService                                    │
│  ├─ streamAmenitiesRealtime() → Stream<List<Amenity>>      │
│  ├─ streamMyBookingsRealtime() → Stream<List<Booking>>     │
│  └─ createBooking() → Future<BookingResult>                │
│                                                              │
│  UserDataService                                            │
│  ├─ getCurrentUserData() → Future<Map<String, dynamic>?>   │
│  └─ streamUserData() → Stream<Map<String, dynamic>?>       │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

## Summary

This visual flow shows:

✅ **Architecture** - How components are organized
✅ **Access Flow** - Decision logic for granting/denying access
✅ **Real-Time Updates** - How changes propagate automatically
✅ **Data Queries** - How data is filtered by flatId/buildingId
✅ **Screen States** - All possible UI states
✅ **Component Hierarchy** - Widget tree structure
✅ **Service Layer** - Available services and methods

The system provides comprehensive access control with real-time monitoring and a clean user experience.
