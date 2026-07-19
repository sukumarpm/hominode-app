# Marketplace Phone Request - Seller Phone Display Fix ✅

## Problem
The buyer was seeing the **wrong phone number** - they were seeing the **buyer's phone** instead of the **seller's phone** when the request was accepted.

## Root Cause
The `getAcceptedPhoneNumbersForBuyer()` method was retrieving `requesterPhone` from the request document, which contains the **buyer's phone**, not the seller's phone.

```dart
// WRONG - This is the buyer's phone
final sellerPhone = requestData['requesterPhone'] ?? '';
```

## Solution Implemented

### Changed Data Source
**Before:**
```dart
// Got phone from request document (which has buyer's phone)
final requestData = querySnapshot.docs.first.data() as Map<String, dynamic>;
final sellerPhone = requestData['requesterPhone'] ?? '';
```

**After:**
```dart
// Get seller's ID from listing
final sellerId = listingData?['sellerId'];

// Fetch seller's phone from users collection
final sellerDoc = await _usersCollection.doc(sellerId).get();
final sellerData = sellerDoc.data() as Map<String, dynamic>?;
final sellerPhone = sellerData?['phone'] ?? '';
```

## Updated Flow Function

### Step 1: Buyer Requests Phone
- Request created with buyer's details (name, flat, phone)
- Status: "pending"

### Step 2: Seller Accepts Request
- Status updated to "accepted"
- Request document still contains buyer's details

### Step 3: Buyer Views Seller Phone (FIXED)
```dart
// Service now:
// 1. Gets listing details (sellerId)
// 2. Fetches seller's user document
// 3. Extracts seller's phone from users collection
// 4. Returns seller's phone to buyer
```

## Data Flow

```
Request Document (marketplaces/{productId}/requests/{requestId}):
├── requesterId: "buyer123"
├── requesterName: "John Doe"
├── requesterFlat: "A-101"
├── requesterPhone: "+91-9876543210" (BUYER'S PHONE - NOT USED)
├── status: "accepted"
└── createdAt: timestamp

Listing Document (marketplaces/{productId}):
├── title: "Good Table"
├── price: 400
├── sellerId: "seller456"
├── sellerName: "Preetham"
└── buildingId: "building789"

Seller Document (users/seller456):
├── name: "Preetham"
├── phone: "+91-8765432109" ✅ THIS IS SHOWN TO BUYER
├── flatLabel: "B-202"
└── buildingId: "building789"
```

## What Buyer Sees

### Before Fix (WRONG)
```
Request Accepted
Seller Phone Number: +91-9876543210 ❌ (This was buyer's phone)
```

### After Fix (CORRECT)
```
Request Accepted
Seller Phone Number: +91-8765432109 ✅ (This is seller's phone)
```

## Files Modified

### `lib/src/services/listing_firestore_service.dart`
- Updated `getAcceptedPhoneNumbersForBuyer()` method
- Changed to fetch seller's phone from `users/{sellerId}` collection
- Added seller ID extraction from listing document

## Testing Checklist

- [ ] Buyer requests phone from seller
- [ ] Seller accepts request
- [ ] Buyer sees seller's phone (not buyer's phone)
- [ ] Phone number is correct and matches seller's profile
- [ ] Copy to clipboard works
- [ ] Phone can be called/messaged

## Build Status
✅ No compilation errors
✅ All diagnostics passed
✅ Ready for testing

## Complete Flow Summary

| Step | Action | Data Source | Result |
|------|--------|-------------|--------|
| 1 | Buyer requests phone | users/{buyerId} | Request created with buyer details |
| 2 | Seller accepts | marketplaces/{productId}/requests | Status = "accepted" |
| 3 | Buyer views phone | users/{sellerId} | Shows seller's phone ✅ |

## Key Improvements

✅ **Correct Phone Display** - Buyer now sees seller's phone, not their own
✅ **Proper Data Fetching** - Fetches from correct user document
✅ **Flow Function Compliance** - Matches the intended flow function
✅ **No Breaking Changes** - Request document structure unchanged
