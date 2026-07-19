# Marketplace Phone Request - Before & After

## THE PROBLEM

**Symptom**: Seller sees "1 phone request" in product list, but product detail shows "No phone requests yet"

**Root Cause**: Incorrect Firestore query filtering in `streamPhoneRequestsForListing()`

---

## BEFORE (Broken)

```dart
// ❌ WRONG: Only filters by productId, not sellerId
.collection('marketplaceRequests')  // ❌ Wrong collection name
.where('productId', isEqualTo: listingId)
.where('productOwnerId', isEqualTo: currentUserId)  // ❌ Wrong field name
.orderBy('createdAt', descending: true)

// Result: Query returns NO documents because:
// 1. Collection name is wrong (marketplaceRequests vs marketplace_requests)
// 2. Field name is wrong (productOwnerId vs sellerId)
// 3. Shows "No phone requests yet"
```

---

## AFTER (Fixed)

```dart
// ✅ CORRECT: Filters by both productId AND sellerId
.collection('marketplace_requests')  // ✅ Correct collection name
.where('productId', isEqualTo: listingId)
.where('sellerId', isEqualTo: currentUserId)  // ✅ Correct field name
.orderBy('createdAt', descending: true)

// Result: Query returns matching documents
// Shows all requests for this product from this seller
```

---

## FIELD NAME CORRECTIONS

| Method | Before | After |
|--------|--------|-------|
| Request creation | `productOwnerId` | `sellerId` |
| Request creation | `requestUserId` | `requesterId` |
| Request creation | `requestUserName` | `requesterName` |
| Request creation | `requestUserFlat` | `requesterFlat` |
| Stream requests | `productOwnerId` | `sellerId` |
| Stream requests | `requestUserId` | `requesterId` |
| Accept request | `productOwnerId` | `sellerId` |
| Accept request | `requestUserId` | `requesterId` |
| Get phone | `productOwnerId` | `sellerId` |
| Get phone | `requestUserId` | `requesterId` |

---

## COLLECTION NAME CORRECTION

| Method | Before | After |
|--------|--------|-------|
| All methods | `marketplaceRequests` | `marketplace_requests` |

---

## IMPACT

✅ Seller now sees requests in product detail
✅ Accept/Reject buttons work correctly
✅ Real-time updates display properly
✅ Buyer sees phone number after acceptance

