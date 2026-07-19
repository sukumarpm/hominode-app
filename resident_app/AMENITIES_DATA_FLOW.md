# 📊 Amenities Booking - Data Flow Diagram

## Complete Data Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                    AMENITIES BOOKING SCREEN                      │
│                                                                   │
│  1. Screen loads → calls _loadAmenities()                        │
│  2. Shows loading spinner                                        │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│              BOOKING FIRESTORE SERVICE                           │
│                                                                   │
│  getAmenities() method called                                    │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                    GET CURRENT USER                              │
│                                                                   │
│  • Firebase Auth user OR SharedPreferences user_id               │
│  • Returns userId                                                │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                  FETCH USER DOCUMENT                             │
│                                                                   │
│  Firestore: users/{userId}                                       │
│                                                                   │
│  Extract:                                                        │
│  • role (resident/admin)                                         │
│  • adminId                                                       │
│  • buildingId                                                    │
└─────────────────────────────────────────────────────────────────┘
                              ↓
                    ┌─────────┴─────────┐
                    │                   │
              ┌─────▼─────┐      ┌─────▼─────┐
              │  RESIDENT │      │   ADMIN   │
              └─────┬─────┘      └─────┬─────┘
                    │                   │
                    │                   │
         ┌──────────▼──────────┐       │
         │ filterAdminId =     │       │
         │ user.adminId        │       │
         │                     │       │
         │ filterBuildingId =  │       │
         │ user.buildingId     │       │
         └──────────┬──────────┘       │
                    │                   │
                    │         ┌─────────▼──────────┐
                    │         │ filterAdminId =    │
                    │         │ user.uid (own ID)  │
                    │         │                    │
                    │         │ filterBuildingId = │
                    │         │ user.buildingId    │
                    │         └─────────┬──────────┘
                    │                   │
                    └─────────┬─────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                  BUILD FIRESTORE QUERY                           │
│                                                                   │
│  Query: amenities collection                                     │
│  WHERE adminId == filterAdminId                                  │
│  WHERE buildingId == filterBuildingId (if available)             │
│  WHERE isActive == true                                          │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                    EXECUTE QUERY                                 │
│                                                                   │
│  Firestore.collection('amenities')                               │
│    .where('adminId', isEqualTo: filterAdminId)                   │
│    .where('buildingId', isEqualTo: filterBuildingId)             │
│    .where('isActive', isEqualTo: true)                           │
│    .get()                                                        │
└─────────────────────────────────────────────────────────────────┘
                              ↓
                    ┌─────────┴─────────┐
                    │                   │
            ┌───────▼────────┐   ┌──────▼──────┐
            │ Results Found  │   │  No Results │
            └───────┬────────┘   └──────┬──────┘
                    │                   │
                    │                   ↓
                    │         ┌─────────────────────┐
                    │         │  FALLBACK LEVEL 1   │
                    │         │                     │
                    │         │  Try adminId only   │
                    │         │  (no buildingId)    │
                    │         └──────────┬──────────┘
                    │                    │
                    │         ┌──────────┴──────────┐
                    │         │                     │
                    │    ┌────▼─────┐      ┌───────▼────────┐
                    │    │  Found   │      │  Still Empty   │
                    │    └────┬─────┘      └───────┬────────┘
                    │         │                    │
                    │         │                    ↓
                    │         │          ┌─────────────────────┐
                    │         │          │  FALLBACK LEVEL 2   │
                    │         │          │                     │
                    │         │          │  Fetch all active   │
                    │         │          │  amenities          │
                    │         │          └──────────┬──────────┘
                    │         │                     │
                    └─────────┴─────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│              VALIDATE FIELDS FOR EACH AMENITY                    │
│                                                                   │
│  _ensureRequiredFields(data)                                     │
│                                                                   │
│  Ensures these fields exist with defaults:                       │
│  • name → "Unknown Amenity"                                      │
│  • price → "Free"                                                │
│  • isAvailable → true                                            │
│  • iconName → "apartment"                                        │
│  • backgroundColor → "#D6EBFF"                                   │
│  • iconColor → "#0A64FF"                                         │
│  • openTime → "6:00 AM"                                          │
│  • closeTime → "8:00 PM"                                         │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                  RETURN AMENITIES LIST                           │
│                                                                   │
│  List<Map<String, dynamic>>                                      │
│  Each map contains all required fields                           │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                    SCREEN UPDATES                                │
│                                                                   │
│  setState(() {                                                   │
│    _amenities = amenities;                                       │
│    _isLoadingAmenities = false;                                  │
│  })                                                              │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                    BUILD AMENITIES GRID                          │
│                                                                   │
│  GridView.builder displays:                                      │
│  • AmenityCard for each amenity                                  │
│  • Shows: name, price, status, icon                              │
│  • Tap opens BookingModal                                        │
└─────────────────────────────────────────────────────────────────┘
```

---

## Data Matching Requirements

```
┌─────────────────────────────────────────────────────────────────┐
│                    CRITICAL MATCHING                             │
│                                                                   │
│  For amenities to display:                                       │
│                                                                   │
│  ┌──────────────────┐         ┌──────────────────┐              │
│  │  User Document   │         │ Amenity Document │              │
│  ├──────────────────┤         ├──────────────────┤              │
│  │ adminId: "xyz"   │  ═══►   │ adminId: "xyz"   │              │
│  │ buildingId: "123"│  ═══►   │ buildingId: "123"│              │
│  └──────────────────┘         │ isActive: true   │              │
│                                └──────────────────┘              │
│                                                                   │
│  MUST MATCH ✓                                                    │
└─────────────────────────────────────────────────────────────────┘
```

---

## Booking Creation Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                    USER TAPS AMENITY CARD                        │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                    BOOKING MODAL OPENS                           │
│                                                                   │
│  • Shows amenity details                                         │
│  • Date picker                                                   │
│  • Time slot selector                                            │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                USER SELECTS DATE & TIME                          │
│                                                                   │
│  • Picks date from calendar                                      │
│  • Selects time slot                                             │
│  • Clicks "Confirm Booking"                                      │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│              BOOKING FIRESTORE SERVICE                           │
│                                                                   │
│  createBooking() called with:                                    │
│  • amenityId                                                     │
│  • amenityName                                                   │
│  • date                                                          │
│  • timeSlot                                                      │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                  FETCH USER DATA                                 │
│                                                                   │
│  Get from Firestore users/{userId}:                              │
│  • userName                                                      │
│  • userEmail                                                     │
│  • flatId                                                        │
│  • flatLabel                                                     │
│  • adminId                                                       │
│  • buildingId                                                    │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                  CREATE BOOKING DOCUMENT                         │
│                                                                   │
│  Firestore: bookings collection                                  │
│                                                                   │
│  Document fields:                                                │
│  • userId, userName, userEmail                                   │
│  • flatId, flatLabel                                             │
│  • adminId, buildingId                                           │
│  • amenityId, amenityName                                        │
│  • date, timeSlot                                                │
│  • status: "confirmed"                                           │
│  • createdAt, updatedAt                                          │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                    SUCCESS RESPONSE                              │
│                                                                   │
│  • Modal closes                                                  │
│  • Success message shown                                         │
│  • Screen refreshes bookings list                                │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                BOOKING APPEARS IN "MY BOOKINGS"                  │
│                                                                   │
│  • Shows amenity name                                            │
│  • Shows date and time                                           │
│  • Shows status (Confirmed)                                      │
│  • Cancel button available                                       │
└─────────────────────────────────────────────────────────────────┘
```

---

## Console Log Flow

```
📥 Fetching amenities from Firestore (Flow Function)...
    ↓
✅ User logged in: abc123
    ↓
📋 User data fields: [name, email, role, adminId, buildingId, flatId, flatLabel]
    ↓
👤 User role: resident
🔑 User adminId: admin_xyz
🏢 User buildingId: building_123
    ↓
🔍 Resident user - filtering by adminId and buildingId
    ↓
🔍 Querying amenities:
   adminId: admin_xyz
   buildingId: building_123
   isActive: true
   ✅ Added buildingId filter
    ↓
📊 Query returned 2 documents
    ↓
  📍 Swimming Pool (adminId: admin_xyz, buildingId: building_123)
  📍 Gym (adminId: admin_xyz, buildingId: building_123)
    ↓
✅ Fetched 2 amenities (adminId + buildingId filter)
```

---

## Error Handling Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                    ERROR OCCURS                                  │
└─────────────────────────────────────────────────────────────────┘
                              ↓
                    ┌─────────┴─────────┐
                    │                   │
        ┌───────────▼──────────┐       │
        │  No User Logged In   │       │
        └───────────┬──────────┘       │
                    │                   │
                    ↓                   │
        ❌ Return empty list            │
                                        │
                              ┌─────────▼──────────┐
                              │ User Doc Not Found │
                              └─────────┬──────────┘
                                        │
                                        ↓
                              ❌ Return empty list
                                        
                              ┌─────────▼──────────┐
                              │  No AdminId Found  │
                              └─────────┬──────────┘
                                        │
                                        ↓
                              ⚠️ Fetch all active
                                 amenities (fallback)
                                        
                              ┌─────────▼──────────┐
                              │ Firestore Error    │
                              └─────────┬──────────┘
                                        │
                                        ↓
                              ❌ Log error
                              ❌ Return empty list
                              ❌ Show error snackbar
```

---

## Summary

The data flow ensures:
1. ✅ Proper user authentication
2. ✅ Correct adminId and buildingId filtering
3. ✅ Field validation with defaults
4. ✅ Multiple fallback levels
5. ✅ Detailed error handling
6. ✅ Complete booking creation with all metadata
