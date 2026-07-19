# Quick Fix Reference

## THE FIX IN 30 SECONDS

**Problem**: Seller sees "1 phone request" but product detail shows "No phone requests yet"

**Cause**: Wrong Firestore collection name and field names

**Solution**: Updated all queries to use:
- Collection: `marketplace_requests` (not `marketplaceRequests`)
- Fields: `sellerId`, `requesterId`, `requesterName`, `requesterFlat`

---

## QUERY CHANGES

### Before
```dart
.collection('marketplaceRequests')
.where('productOwnerId', isEqualTo: currentUserId)
```

### After
```dart
.collection('marketplace_requests')
.where('sellerId', isEqualTo: currentUserId)
```

---

## FIELD MAPPING

```
productOwnerId  →  sellerId
requestUserId   →  requesterId
requestUserName →  requesterName
requestUserFlat →  requesterFlat
```

---

## METHODS FIXED

1. ✅ requestPhoneNumber()
2. ✅ acceptPhoneRequest()
3. ✅ rejectPhoneRequest()
4. ✅ streamPhoneRequestsForListing()
5. ✅ getAcceptedPhoneNumbersForBuyer()

---

## STATUS

✅ All fixes applied
✅ No build errors
✅ Ready for testing

