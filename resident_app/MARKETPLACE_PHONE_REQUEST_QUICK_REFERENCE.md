# Marketplace Phone Request - Quick Reference

## WHAT WAS FIXED

| Issue | Solution |
|-------|----------|
| Wrong collection name | Changed from `phoneRequests` to `marketplaceRequests` |
| Missing requester details | Added name, flat number, and request time display |
| No accept/reject buttons | Implemented with proper status updates |
| No real-time updates | Added StreamBuilder for live data |

---

## FIRESTORE COLLECTION

**Collection**: `marketplaceRequests`

```
productId          → Listing ID
productOwnerId     → Seller's user ID
requestUserId      → Buyer's user ID
requestUserName    → Buyer's name
requestUserFlat    → Buyer's flat number
buildingId         → Building ID (for validation)
status             → "pending" | "accepted" | "rejected"
createdAt          → Request timestamp
```

---

## USER FLOWS

### Buyer Flow
1. Browse marketplace products
2. Click "Request Phone Number"
3. See "Request Sent - Waiting for Seller"
4. After seller accepts → See seller's phone number
5. Copy phone to clipboard

### Seller Flow
1. Go to "Your Products"
2. Click product with phone requests
3. See request card with:
   - Requester name
   - Flat number
   - Request time
   - Accept/Reject buttons
4. Click Accept or Reject
5. Status updates in real-time

---

## KEY METHODS

### Request Creation
```dart
requestPhoneNumber(listingId)
// Creates marketplaceRequests document
```

### Accept Request
```dart
acceptPhoneRequest(listingId, requesterId)
// Updates status to "accepted"
```

### Reject Request
```dart
rejectPhoneRequest(requestId)
// Updates status to "rejected"
```

### Stream Requests (Seller)
```dart
streamPhoneRequestsForListing(listingId)
// Real-time stream of all requests for a product
```

### Get Phone (Buyer)
```dart
getAcceptedPhoneNumbersForBuyer(listingId)
// Returns seller's phone if request accepted
```

---

## UI COMPONENTS

### Request Card (Pending)
```
┌─────────────────────────────────────┐
│ John Doe                    Pending │
│ Flat: 101                           │
│ 5m ago                              │
│                                     │
│ [Reject]  [Accept]                  │
└─────────────────────────────────────┘
```

### Request Card (Accepted)
```
┌─────────────────────────────────────┐
│ John Doe                   Accepted │
│ Flat: 101                           │
│ 2h ago                              │
│                                     │
│ ✓ Request accepted                  │
└─────────────────────────────────────┘
```

### Phone Display (Buyer)
```
┌─────────────────────────────────────┐
│ ✓ Request Accepted                  │
│                                     │
│ Seller Phone Number                 │
│ ┌─────────────────────────────────┐ │
│ │ +1 234 567 8900      [Copy]     │ │
│ └─────────────────────────────────┘ │
└─────────────────────────────────────┘
```

---

## FILES MODIFIED

1. **listing_firestore_service.dart**
   - Updated all phone request methods
   - Changed collection from `phoneRequests` to `marketplaceRequests`

2. **marketplace_your_product_detail_screen.dart**
   - Updated request card display
   - Added requester details (name, flat, time)
   - Added status badges

---

## VALIDATION RULES

✅ Only same-building users can request
✅ Duplicate requests prevented
✅ Phone only shown after acceptance
✅ Request time formatted correctly
✅ Status updates in real-time

---

## TESTING QUICK START

1. **Create 2 users in same building**
2. **User 2 requests phone from User 1's product**
3. **User 1 sees request with details**
4. **User 1 clicks Accept**
5. **User 2 sees seller's phone number**

---

## COMMON ERRORS & FIXES

| Error | Fix |
|-------|-----|
| Request not appearing | Check buildingId matches |
| Phone not showing | Verify seller has phone number |
| Can't request | Check same building |
| Status not updating | Refresh page or check Firestore |

---

## DEBUG LOGS

```
✅ Phone request created
✅ Phone request accepted
✅ Phone request rejected
📞 Streaming phone requests for listing: [ID]
📞 Fetching accepted phone numbers for buyer: [ID]
```

---

## NEXT STEPS

1. ✅ Code implementation complete
2. ⏳ Test with real users
3. ⏳ Verify Firestore security rules
4. ⏳ Monitor for errors
5. ⏳ Deploy to production

---

## SUPPORT

For issues or questions:
1. Check console logs for error messages
2. Verify Firestore collection structure
3. Confirm user buildingId is set
4. Check security rules allow access

