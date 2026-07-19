# Marketplace Phone Request Feature - Fix Complete ✅

## Problem Summary
The seller saw "1 phone request" in the product list but when opening the Product Details screen, it showed "No phone requests yet". This was caused by **collection name mismatch** between where requests were being created and where they were being queried.

## Root Cause
- **Listings Collection**: `marketplaces` (where products are stored)
- **Requests Collection (WRONG)**: `marketplaceProducts` (where requests were being queried)
- **Mismatch**: Requests were being created in `marketplaces/{productId}/requests` but queried from `marketplaceProducts/{productId}/requests`

## Solution Implemented

### 1. Fixed Collection References
Updated all phone request methods to use the correct collection path: `marketplaces/{productId}/requests`

**Methods Updated:**
- ✅ `requestPhoneNumber()` - Creates requests in correct subcollection
- ✅ `acceptPhoneRequest()` - Updates requests in correct subcollection
- ✅ `rejectPhoneRequest()` - Updates requests in correct subcollection
- ✅ `streamPhoneRequestsForListing()` - Streams from correct subcollection
- ✅ `getAcceptedPhoneNumbersForBuyer()` - Queries from correct subcollection

### 2. Building Member Data Integration
The `requestPhoneNumber()` method now correctly:
1. Fetches requester details from `users/{userId}` collection
2. Validates user is in the **same building** as the listing before creating request
3. Stores requester information:
   - `requesterName` - From user data
   - `requesterFlat` - From user's `flatLabel`
   - `requesterPhone` - From user's phone
   - `requesterId` - Current user ID
   - `status` - "pending" (can be "accepted" or "rejected")
   - `createdAt` - Server timestamp

### 3. Firestore Structure (Correct)
```
marketplaces/
  └── {productId}/
      ├── title
      ├── price
      ├── sellerId
      ├── buildingId
      ├── createdAt
      └── requests/ (subcollection)
          └── {requestId}/
              ├── requesterId
              ├── requesterName
              ├── requesterFlat
              ├── requesterPhone
              ├── status (pending/accepted/rejected)
              └── createdAt
```

## Flow Function - Complete

### Step 1: Buyer Requests Phone
```dart
// Buyer clicks "Request Phone Number"
await _listingService.requestPhoneNumber(listingId);
// Creates: marketplaces/{productId}/requests/{requestId}
```

### Step 2: Seller Sees Request Count
- Product list shows count from subcollection
- Real-time updates via StreamBuilder

### Step 3: Seller Opens Product Details
```dart
// Streams from correct subcollection
streamPhoneRequestsForListing(widget.listing.id!)
// Fetches: marketplaces/{productId}/requests
```

### Step 4: Display Request Cards
Shows:
- Requester name (from building member)
- Flat number (from building member)
- Request time (formatted)
- Accept/Reject buttons (for pending requests)

### Step 5: Seller Accepts Request
```dart
await _listingService.acceptPhoneRequest(listingId, requestId);
// Updates: marketplaces/{productId}/requests/{requestId}
// Sets: status = "accepted"
```

### Step 6: Buyer Sees Seller Phone
```dart
// Buyer can now view seller phone when status == "accepted"
final acceptedNumbers = await _listingService.getAcceptedPhoneNumbersForBuyer(listingId);
// Queries: marketplaces/{productId}/requests
// Where: requesterId == currentUserId AND status == "accepted"
```

## Files Modified

### 1. `lib/src/services/listing_firestore_service.dart`
- Fixed `requestPhoneNumber()` - Uses `marketplaces` collection
- Fixed `acceptPhoneRequest()` - Uses `marketplaces` collection
- Fixed `rejectPhoneRequest()` - Uses `marketplaces` collection
- Fixed `streamPhoneRequestsForListing()` - Uses `marketplaces` collection
- Fixed `getAcceptedPhoneNumbersForBuyer()` - Uses `marketplaces` collection

### 2. `lib/src/screens/marketplace_your_product_detail_screen.dart`
- Already correctly using `streamPhoneRequestsForListing()`
- Displays requests with accept/reject buttons
- Shows request status (pending/accepted/rejected)

### 3. `lib/src/screens/marketplace_product_detail_screen.dart`
- Already correctly using `requestPhoneNumber()`
- Shows request button or accepted phone number
- Handles phone request status checking

## Testing Checklist

- [ ] Buyer requests phone number
- [ ] Seller sees request count in product list
- [ ] Seller opens product details and sees request
- [ ] Request shows buyer name, flat, and time
- [ ] Seller clicks "Accept" button
- [ ] Request status changes to "accepted"
- [ ] Buyer sees seller phone number
- [ ] Buyer can copy phone number
- [ ] Seller can reject request
- [ ] Request status changes to "rejected"
- [ ] Real-time updates work via StreamBuilder

## Key Improvements

✅ **Correct Collection Structure** - All requests now use `marketplaces/{productId}/requests`
✅ **Building Member Integration** - Requester details fetched from building members
✅ **Real-time Updates** - StreamBuilder shows live request updates
✅ **Status Management** - Requests track pending/accepted/rejected status
✅ **Error Handling** - Validates building membership before creating request
✅ **No Duplicates** - Prevents duplicate requests from same buyer

## Build Status
✅ No compilation errors
✅ All diagnostics passed
✅ Ready for testing
