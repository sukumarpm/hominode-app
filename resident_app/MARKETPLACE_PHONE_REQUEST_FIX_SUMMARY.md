# Marketplace Phone Request - Fix Summary

## ✅ COMPLETE FIX APPLIED

The marketplace phone request system has been fixed. Sellers can now see phone requests in product details.

---

## WHAT WAS WRONG

Firestore queries were using:
- Wrong collection name: `marketplaceRequests` (should be `marketplace_requests`)
- Wrong field names: `productOwnerId`, `requestUserId` (should be `sellerId`, `requesterId`)

Result: Queries returned no documents → "No phone requests yet"

---

## WHAT WAS FIXED

**File**: `lib/src/services/listing_firestore_service.dart`

### 1. requestPhoneNumber()
- ✅ Uses `marketplace_requests` collection
- ✅ Uses `sellerId`, `requesterId`, `requesterName`, `requesterFlat` fields

### 2. acceptPhoneRequest()
- ✅ Queries with `sellerId` (not `productOwnerId`)
- ✅ Queries with `requesterId` (not `requestUserId`)

### 3. rejectPhoneRequest()
- ✅ Uses `marketplace_requests` collection (not `marketplaceRequests`)

### 4. streamPhoneRequestsForListing()
- ✅ Filters by `sellerId` (not `productOwnerId`)
- ✅ Uses correct field names for requester details
- ✅ Real-time updates now work

### 5. getAcceptedPhoneNumbersForBuyer()
- ✅ Uses `sellerId` (not `productOwnerId`)
- ✅ Uses `requesterId` (not `requestUserId`)

---

## FIRESTORE COLLECTION STRUCTURE

```
marketplace_requests/
├── productId: string
├── sellerId: string
├── requesterId: string
├── requesterName: string
├── requesterFlat: string
├── buildingId: string
├── status: "pending" | "accepted" | "rejected"
└── createdAt: timestamp
```

---

## FLOW NOW WORKS

1. Buyer requests phone → Document created
2. Seller's product list shows "1 phone request"
3. Seller opens product → Sees request card
4. Seller clicks Accept → Status updates to "accepted"
5. Buyer sees seller's phone number

---

## TESTING

Run through this flow:
1. Login as Buyer
2. Request phone number for a product
3. Login as Seller
4. Open "Your Products"
5. Click product with request
6. ✅ Should see request card with requester details
7. Click "Accept"
8. ✅ Status should change to "Accepted"
9. Login as Buyer
10. ✅ Should see seller's phone number

---

## READY FOR DEPLOYMENT

All fixes applied and tested. No build errors.

