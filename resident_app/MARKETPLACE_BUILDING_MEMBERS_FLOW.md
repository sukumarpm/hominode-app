# Marketplace - Building Members Flow (CORRECTED)

**Status**: ✅ COMPLETE - Building Members Only

## Key Change

**Marketplace now shows products to BUILDING MEMBERS only** (not flat members)

---

## Flow Function Pattern

### Data Storage
```
WHEN USER CREATES LISTING
├─ Get current user ID
├─ Fetch user data from Firestore
├─ Get user's buildingId (NOT flatId)
├─ Store listing with buildingId
└─ Listing visible to all building members
```

### Data Fetching
```
WHEN USER OPENS MARKETPLACE
├─ Get current user ID
├─ Fetch user data
├─ Get user's buildingId
├─ Query listings where buildingId = user's buildingId
├─ Filter by status = "active"
├─ Display to all building members
└─ Real-time updates
```

### Display Logic
```
BUILDING A
├─ Flat 101 - User A
├─ Flat 102 - User B
├─ Flat 103 - User C
└─ All can see each other's products

BUILDING B
├─ Flat 201 - User D
├─ Flat 202 - User E
└─ Can only see Building B products

MARKETPLACE
├─ User A sees: Products from Building A only
├─ User B sees: Products from Building A only
├─ User D sees: Products from Building B only
└─ Cross-building products NOT visible
```

---

## Firestore Structure

### Listings Collection
```
listings/
├── listing_1/
│   ├── title: "IKEA Study Table"
│   ├── price: 2500
│   ├── category: "Furniture"
│   ├── condition: "Like New"
│   ├── description: "..."
│   ├── images: ["url1", "url2"]
│   ├── sellerId: "user_A_doc_id"
│   ├── sellerName: "John Doe"
│   ├── sellerPhone: null
│   ├── buildingId: "building_1"  ← KEY: Building ID, not Flat ID
│   ├── status: "active"
│   ├── phoneRequestCount: 2
│   ├── phoneRequestIds: ["user_B", "user_C"]
│   ├── createdAt: timestamp
│   └── updatedAt: timestamp
```

### Users Collection
```
users/
├── user_A_doc_id/
│   ├── name: "John Doe"
│   ├── email: "john@example.com"
│   ├── phone: "+91-9876543210"
│   ├── buildingId: "building_1"  ← Used for marketplace filtering
│   ├── buildingName: "Tower A"
│   ├── flatId: "flat_101"
│   ├── flatNumber: "101"
│   └── authUid: "firebase_uid_A"
```

---

## API Methods

### Create Listing
```dart
Future<ServiceResult> createListing({
  required String title,
  required int price,
  required String category,
  required String condition,
  required String description,
  List<String> images = const [],
})
```
**Flow**:
1. Get current user ID
2. Fetch user data
3. Get user's buildingId
4. Store listing with buildingId
5. Return success

### Get All Listings
```dart
Future<List<ListingModel>> getAllListings()
```
**Flow**:
1. Get current user ID
2. Fetch user data
3. Get user's buildingId
4. Query: `listings.where('buildingId', isEqualTo: buildingId).where('status', isEqualTo: 'active')`
5. Return filtered listings

### Stream All Listings
```dart
Stream<List<ListingModel>> streamAllListings()
```
**Flow**:
1. Get current user ID
2. Listen to user document changes
3. Get buildingId from user data
4. Stream listings for that building
5. Real-time updates

### Get My Listings
```dart
Future<List<ListingModel>> getMyListings()
```
**Flow**:
1. Get current user ID
2. Query: `listings.where('sellerId', isEqualTo: currentUserId)`
3. Return all user's listings (all statuses)

---

## UI Components

### Browse Tab
- Shows products from **same building only**
- Search filters by title
- Category filter (All, Furniture, Electronics, Other)
- Grid view (2 columns)
- Product cards show:
  - Image
  - Title
  - Condition
  - Price
  - Seller name (from same building)

### Product Detail Screen
- Full product information
- Seller info (name, phone if shared)
- Phone request button
- Image gallery

### Your Products Tab
- Shows all your listings
- Status (Active/Sold)
- Phone request count
- Edit/Mark Sold/Delete buttons

---

## Example Scenario

### Building A Setup
```
Building A (buildingId: "bldg_A")
├─ Flat 101: John Doe (User A)
├─ Flat 102: Jane Smith (User B)
├─ Flat 103: Bob Johnson (User C)
└─ Flat 104: Alice Lee (User D)
```

### Listings Created
```
Listing 1: "IKEA Table" by John Doe
├─ buildingId: "bldg_A"
├─ sellerId: "user_A"
└─ Visible to: Jane, Bob, Alice (same building)

Listing 2: "Laptop" by Jane Smith
├─ buildingId: "bldg_A"
├─ sellerId: "user_B"
└─ Visible to: John, Bob, Alice (same building)
```

### When John Opens Marketplace
```
1. Get John's buildingId: "bldg_A"
2. Query listings where buildingId = "bldg_A"
3. Results:
   - "IKEA Table" by John Doe (his own)
   - "Laptop" by Jane Smith
   - (any other products from Building A)
4. Display all to John
```

### When User from Building B Opens Marketplace
```
1. Get User's buildingId: "bldg_B"
2. Query listings where buildingId = "bldg_B"
3. Results:
   - Only products from Building B
   - Cannot see Building A products
4. Display Building B products only
```

---

## Phone Request Flow

### Request Phase
```
BUYER (Building A)
├─ Sees product from Building A seller
├─ Clicks "Request Phone Number"
├─ Request stored in phoneRequests collection
└─ Seller's phoneRequestCount incremented

SELLER (Building A)
├─ Opens "Your Products"
├─ Sees phone request count
├─ Can accept/reject request
└─ Phone number revealed to buyer
```

---

## Status Lifecycle

```
CREATE LISTING
      │
      ▼
   ACTIVE ◄─────────────────┐
      │                     │
      ├─ Receive Requests   │
      │                     │
      ├─ Accept Requests    │
      │                     │
      ├─ Sell Product       │
      │                     │
      ▼                     │
    SOLD ──────────────────┤
      │                     │
      ├─ Delete Product     │
      │                     │
      ▼                     │
   DELETED ────────────────┘
      │
      └─ Removed from Marketplace
```

---

## Firestore Queries

### Get Building Listings (Active Only)
```
db.collection('listings')
  .where('buildingId', '==', userBuildingId)
  .where('status', '==', 'active')
  .orderBy('createdAt', 'desc')
```

### Get My Listings (All Statuses)
```
db.collection('listings')
  .where('sellerId', '==', currentUserId)
  .orderBy('createdAt', 'desc')
```

### Get Listings by Category
```
db.collection('listings')
  .where('buildingId', '==', userBuildingId)
  .where('status', '==', 'active')
  .where('category', '==', category)
  .orderBy('createdAt', 'desc')
```

---

## Testing Checklist

- [x] Listings stored with buildingId (not flatId)
- [x] Browse tab shows only building members' products
- [x] Search filters correctly
- [x] Category filter works
- [x] Your Products shows only your listings
- [x] Phone request system works
- [x] Mark as Sold updates status
- [x] Delete removes product
- [x] Real-time updates work
- [x] Cross-building products NOT visible
- [x] Skeleton loaders show
- [x] Error handling works
- [x] No demo data visible

---

## Key Differences from Previous Version

| Aspect | Previous | Current |
|--------|----------|---------|
| Filtering | flatId (flat members) | buildingId (building members) |
| Visibility | Flat members only | Building members only |
| Data Storage | flatId field | buildingId field |
| Query | where('flatId', ...) | where('buildingId', ...) |
| Scope | Same flat | Same building |

---

## Compilation Status

✅ All files compile without errors
✅ No type warnings
✅ Ready for production

---

## Summary

The marketplace now correctly:
- ✅ Stores listings with buildingId
- ✅ Shows products to building members only
- ✅ Fetches data according to flow function
- ✅ Displays UI properly
- ✅ Handles phone requests
- ✅ Manages product lifecycle

**Status**: ✅ COMPLETE AND READY FOR PRODUCTION

All building members can see each other's products, but products are NOT visible across buildings.
