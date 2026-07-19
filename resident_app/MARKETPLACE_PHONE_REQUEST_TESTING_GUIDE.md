# Marketplace Phone Request - Testing Guide

## QUICK TEST FLOW

### Prerequisites
- Two users in the same building
- User 1: Product owner (seller)
- User 2: Buyer
- Both users have phone numbers in their profiles

---

## TEST SCENARIO 1: Request Phone Number

### Step 1: Buyer Requests Phone
1. Login as User 2 (Buyer)
2. Go to Marketplace
3. Find a product from User 1
4. Click on product details
5. Click "Request Phone Number" button
6. ✅ Should see: "Request Sent - Waiting for Seller"

### Step 2: Seller Sees Request
1. Login as User 1 (Seller)
2. Go to Marketplace → "Your Products"
3. Click on the product
4. ✅ Should see: Phone Requests section with:
   - Requester name (User 2's name)
   - Flat number (User 2's flat)
   - Request time (e.g., "Just now", "5m ago")
   - Status badge: "Pending"
   - Accept and Reject buttons

---

## TEST SCENARIO 2: Accept Request

### Step 1: Seller Accepts
1. In product detail (as User 1)
2. Find the pending request
3. Click "Accept" button
4. ✅ Should see: Status changes to "Accepted"

### Step 2: Buyer Sees Phone Number
1. Login as User 2 (Buyer)
2. Go to Marketplace
3. Find the same product
4. Click on product details
5. ✅ Should see:
   - Green box with "Request Accepted"
   - Seller's phone number
   - Copy button

---

## TEST SCENARIO 3: Reject Request

### Step 1: Buyer Requests Again
1. Login as User 2
2. Request phone number for a different product from User 1
3. ✅ Request appears in seller's product detail

### Step 2: Seller Rejects
1. Login as User 1
2. Go to product detail
3. Find the pending request
4. Click "Reject" button
5. ✅ Should see: Status changes to "Rejected"

### Step 3: Buyer Sees Rejection
1. Login as User 2
2. Go to Marketplace
3. Find the product
4. Click on product details
5. ✅ Should see: "Request Sent - Waiting for Seller" (can request again)

---

## TEST SCENARIO 4: Cross-Building Validation

### Step 1: Different Building User
1. Create User 3 in a different building
2. Login as User 3
3. Go to Marketplace
4. ✅ Should NOT see products from User 1's building
5. ✅ Should NOT be able to request phone numbers

---

## EXPECTED BEHAVIORS

### Buyer View
- ✅ Can see "Request Phone Number" button for other users' products
- ✅ Button changes to "Request Sent - Waiting for Seller" after requesting
- ✅ Can see seller's phone number in green box after acceptance
- ✅ Can copy phone number to clipboard
- ✅ Cannot see products from other buildings

### Seller View
- ✅ Can see phone request count on product card
- ✅ Can see all request details in product detail screen
- ✅ Can accept or reject pending requests
- ✅ Can see status of all requests (Pending/Accepted/Rejected)
- ✅ Request time is formatted correctly

---

## FIRESTORE DATA VERIFICATION

### Check marketplaceRequests Collection
```
Collection: marketplaceRequests
Document fields:
- productId: [listing ID]
- productOwnerId: [seller user ID]
- requestUserId: [buyer user ID]
- requestUserName: [buyer name]
- requestUserFlat: [buyer flat number]
- buildingId: [building ID]
- status: "pending" | "accepted" | "rejected"
- createdAt: [timestamp]
```

### Verify in Firebase Console
1. Go to Firebase Console
2. Select your project
3. Go to Firestore Database
4. Check `marketplaceRequests` collection
5. Verify documents have correct structure

---

## COMMON ISSUES & SOLUTIONS

### Issue: Request doesn't appear in seller's product detail
**Solution**: 
- Verify both users are in same building
- Check Firestore has `marketplaceRequests` collection
- Verify `productId` and `productOwnerId` match

### Issue: Phone number not showing after acceptance
**Solution**:
- Verify seller's phone number is in their user profile
- Check request status is "accepted" in Firestore
- Refresh the page

### Issue: Can see products from other buildings
**Solution**:
- Check user's `buildingId` is set correctly
- Verify Firestore query filters by `buildingId`
- Check security rules allow only same-building access

---

## DEBUG LOGS TO CHECK

Look for these logs in console:

```
✅ Phone request created
✅ Phone request accepted
✅ Phone request rejected
📞 Streaming phone requests for listing: [listingId]
📞 Fetching accepted phone numbers for buyer: [userId]
```

---

## PERFORMANCE NOTES

- Real-time updates use StreamBuilder
- Requester details fetched from users collection
- Request time formatted in memory
- No unnecessary Firestore queries

