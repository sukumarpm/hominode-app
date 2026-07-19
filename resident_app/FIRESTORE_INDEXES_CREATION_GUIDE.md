# Firestore Indexes Creation Guide

## Overview

After deploying Firestore rules, you need to create 5 indexes for complex queries to work.

**Time**: ~5 minutes  
**Status**: Required for data fetching to work

---

## Index 1: Bills Collection (Status + FlatId)

**Used by**: `bill_firestore_service.dart` (Lines 95-105, 155-165)  
**Query**:
```dart
.where('status', isEqualTo: 'pending')
.where('flatId', isEqualTo: flatId)
```

### Creation Steps

1. Go to Firebase Console → Firestore Database → **Indexes** tab
2. Click **Create Index**
3. Fill in:
   - **Collection ID**: `bills`
   - **Query scope**: Collection
   - **Fields to index**:
     - Field: `status` | Order: Ascending
     - Field: `flatId` | Order: Ascending
4. Click **Create Index**
5. Wait for index to build (1-2 minutes)

---

## Index 2: Marketplace Requests (ProductId + RequestUserId)

**Used by**: `marketplace_request_service.dart` (Lines 65-70)  
**Query**:
```dart
.where('productId', isEqualTo: productId)
.where('requestUserId', isEqualTo: currentUserId)
```

### Creation Steps

1. Go to Firebase Console → Firestore Database → **Indexes** tab
2. Click **Create Index**
3. Fill in:
   - **Collection ID**: `marketplaceRequests`
   - **Query scope**: Collection
   - **Fields to index**:
     - Field: `productId` | Order: Ascending
     - Field: `requestUserId` | Order: Ascending
4. Click **Create Index**
5. Wait for index to build

---

## Index 3: Marketplace Requests (ProductId + ProductOwnerId + RequestUserId + Status)

**Used by**: `marketplace_request_service.dart` (Lines 155-160)  
**Query**:
```dart
.where('productId', isEqualTo: productId)
.where('productOwnerId', isEqualTo: productOwnerId)
.where('requestUserId', isEqualTo: currentUserId)
.where('status', isEqualTo: 'accepted')
```

### Creation Steps

1. Go to Firebase Console → Firestore Database → **Indexes** tab
2. Click **Create Index**
3. Fill in:
   - **Collection ID**: `marketplaceRequests`
   - **Query scope**: Collection
   - **Fields to index**:
     - Field: `productId` | Order: Ascending
     - Field: `productOwnerId` | Order: Ascending
     - Field: `requestUserId` | Order: Ascending
     - Field: `status` | Order: Ascending
4. Click **Create Index**
5. Wait for index to build

---

## Index 4: Marketplace Listings (BuildingId + Status + Category)

**Used by**: `listing_firestore_service.dart` (Lines 200-210)  
**Query**:
```dart
.where('buildingId', isEqualTo: userBuildingId)
.where('status', isEqualTo: 'active')
.where('category', isEqualTo: category)
```

### Creation Steps

1. Go to Firebase Console → Firestore Database → **Indexes** tab
2. Click **Create Index**
3. Fill in:
   - **Collection ID**: `marketplaces`
   - **Query scope**: Collection
   - **Fields to index**:
     - Field: `buildingId` | Order: Ascending
     - Field: `status` | Order: Ascending
     - Field: `category` | Order: Ascending
4. Click **Create Index**
5. Wait for index to build

---

## Index 5: Users Collection (BuildingId + Role)

**Used by**: `admin_chat_service.dart` (Lines 100-110)  
**Query**:
```dart
.where('buildingId', isEqualTo: buildingId)
.where('role', isEqualTo: 'admin')
```

### Creation Steps

1. Go to Firebase Console → Firestore Database → **Indexes** tab
2. Click **Create Index**
3. Fill in:
   - **Collection ID**: `users`
   - **Query scope**: Collection
   - **Fields to index**:
     - Field: `buildingId` | Order: Ascending
     - Field: `role` | Order: Ascending
4. Click **Create Index**
5. Wait for index to build

---

## Verification

After all indexes are created:

1. Go to Firebase Console → Firestore Database → **Indexes** tab
2. You should see 5 indexes:
   - ✅ `bills` (status, flatId)
   - ✅ `marketplaceRequests` (productId, requestUserId)
   - ✅ `marketplaceRequests` (productId, productOwnerId, requestUserId, status)
   - ✅ `marketplaces` (buildingId, status, category)
   - ✅ `users` (buildingId, role)

---

## Troubleshooting

### Index Creation Failed

**Error**: "Index creation failed"

**Solution**:
1. Check that collection name is correct
2. Check that field names match exactly (case-sensitive)
3. Try creating index again

### Index Still Building

**Status**: "Building" (yellow)

**Solution**:
- Wait 1-2 minutes for index to build
- Refresh the page to see updated status

### Query Still Fails After Index Created

**Error**: "FAILED_PRECONDITION: The query requires an index"

**Solution**:
1. Verify index was created successfully (status should be green)
2. Verify field names and order match the query
3. Try restarting the app

---

## Next Steps

After creating all indexes:

1. ✅ Deploy Firestore rules (done)
2. ✅ Create Firestore indexes (done)
3. Test login with credentials
4. Fix code issues (user ID resolution, type casting)
5. Optimize queries

---

**Status**: Required for data fetching to work
