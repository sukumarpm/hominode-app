# Marketplace Testing Guide

## Quick Test Scenarios

### Scenario 1: Buyer Requests Phone Number

**Setup**: Two users in same building
- User A: Seller (has product listed)
- User B: Buyer (wants to contact seller)

**Steps**:
1. Login as User B (Buyer)
2. Go to Marketplace → Browse tab
3. Find User A's product
4. Click product card → See full details
5. Click "Request Phone Number" button
6. Verify: Button changes to "Request Sent - Waiting for Seller"
7. Verify: "View Seller Contact" button appears (disabled until accepted)

**Expected Result**: 
- ✅ Phone request created in `phoneRequests` collection
- ✅ `phoneRequestCount` incremented in product
- ✅ Button state updated

---

### Scenario 2: Seller Accepts Phone Request

**Setup**: User B has requested phone from User A

**Steps**:
1. Login as User A (Seller)
2. Go to Marketplace → Your Products tab
3. Click product with phone requests
4. Scroll to "Phone Requests" section
5. See User B's request with "Pending" status
6. Click "Accept" button
7. Verify: Request status changes to "Accepted"
8. Verify: User B's phone number is now visible

**Expected Result**:
- ✅ `phoneRequests` document status updated to "accepted"
- ✅ Phone number displayed in request card
- ✅ User B can now view seller's phone

---

### Scenario 3: Buyer Views Accepted Phone Number

**Setup**: Seller has accepted User B's request

**Steps**:
1. Login as User B (Buyer)
2. Go to Marketplace → Browse tab
3. Find User A's product
4. Click product → "View Seller Contact" button is now enabled
5. Click "View Seller Contact"
6. Verify: Seller's phone number is displayed
7. Click "Copy" button
8. Verify: Phone number copied to clipboard
9. Click "Call Seller" button
10. Verify: Call action triggered

**Expected Result**:
- ✅ Phone number visible only to accepted requester
- ✅ Copy to clipboard works
- ✅ Call button functional

---

### Scenario 4: Seller Rejects Phone Request

**Setup**: User B has requested phone from User A

**Steps**:
1. Login as User A (Seller)
2. Go to Marketplace → Your Products tab
3. Click product with phone requests
4. See User B's request with "Pending" status
5. Click "Reject" button
6. Verify: Request status changes to "Rejected"
7. Verify: Phone number NOT visible

**Expected Result**:
- ✅ `phoneRequests` document status updated to "rejected"
- ✅ Request card shows "Rejected" badge
- ✅ User B cannot view phone number

---

### Scenario 5: Seller Edits Product

**Setup**: User A has a product listed

**Steps**:
1. Login as User A (Seller)
2. Go to Marketplace → Your Products tab
3. Click product card
4. Click "Edit Product" button
5. Change title, price, description
6. Add/remove images
7. Click "Save"
8. Verify: Changes reflected in product detail
9. Verify: Changes visible in Browse tab (for other users)

**Expected Result**:
- ✅ Product details updated in Firestore
- ✅ Changes visible in real-time
- ✅ Images properly managed

---

### Scenario 6: Seller Marks Product as Sold

**Setup**: User A has a product listed

**Steps**:
1. Login as User A (Seller)
2. Go to Marketplace → Your Products tab
3. Click product card
4. Click "Mark as Sold" button
5. Verify: Product status changes to "Sold"
6. Verify: Button becomes disabled
7. Logout and login as User B
8. Go to Browse tab
9. Verify: Product no longer appears in Browse

**Expected Result**:
- ✅ Product status updated to "sold"
- ✅ Product hidden from Browse tab
- ✅ Product still visible in Your Products with "Sold" badge

---

### Scenario 7: Seller Deletes Product

**Setup**: User A has a product listed

**Steps**:
1. Login as User A (Seller)
2. Go to Marketplace → Your Products tab
3. Click product card
4. Click "Delete Product" button
5. Confirm deletion
6. Verify: Product removed from Your Products
7. Logout and login as User B
8. Go to Browse tab
9. Verify: Product no longer appears

**Expected Result**:
- ✅ Product status updated to "deleted"
- ✅ Product removed from all views
- ✅ Phone requests preserved (for history)

---

### Scenario 8: Building-Based Access Control

**Setup**: Two buildings with different users

**Steps**:
1. Create User A in Building 1 with product
2. Create User B in Building 2
3. Login as User B
4. Go to Marketplace → Browse tab
5. Verify: User A's product NOT visible
6. Verify: Only products from Building 2 visible

**Expected Result**:
- ✅ Products filtered by `buildingId`
- ✅ Cross-building products not visible
- ✅ Access control working properly

---

### Scenario 9: Search and Filter

**Setup**: Multiple products in marketplace

**Steps**:
1. Go to Marketplace → Browse tab
2. Type search query (e.g., "phone")
3. Verify: Only products with "phone" in title shown
4. Click category filter (e.g., "Electronics")
5. Verify: Only Electronics products shown
6. Combine search + filter
7. Verify: Results filtered by both criteria

**Expected Result**:
- ✅ Search works on product titles
- ✅ Category filter works
- ✅ Combined filters work correctly

---

### Scenario 10: Seller Cannot Request Own Product

**Setup**: User A has a product listed

**Steps**:
1. Login as User A (Seller)
2. Go to Marketplace → Browse tab
3. Find own product
4. Click product detail
5. Verify: "Request Phone Number" button NOT visible
6. Verify: No bottom navigation bar with request button

**Expected Result**:
- ✅ Seller protection working
- ✅ Own products identified correctly
- ✅ Request button hidden for sellers

---

## Firestore Data Verification

### Check Phone Request Creation
```
Collection: phoneRequests
Document: {
  listingId: "product_id",
  sellerId: "seller_id",
  requesterId: "buyer_id",
  requesterName: "Buyer Name",
  requesterPhone: "+91XXXXXXXXXX",
  status: "pending",
  createdAt: Timestamp,
  updatedAt: Timestamp
}
```

### Check Product Update
```
Collection: marketplaces
Document: {
  ...
  phoneRequestCount: 1,
  phoneRequestIds: ["buyer_id"],
  ...
}
```

### Check Status Update
```
After acceptance:
phoneRequests document: status = "accepted"

After rejection:
phoneRequests document: status = "rejected"
```

---

## Common Issues & Solutions

### Issue: Phone request button not showing
**Solution**: 
- Verify user is not the seller
- Check `_isOwnProduct` is false
- Verify `_isLoadingCheck` is false

### Issue: Phone number not visible after acceptance
**Solution**:
- Verify `phoneRequests` status is "accepted"
- Check `getAcceptedPhoneNumbersForBuyer()` returns data
- Verify seller's phone number is in user document

### Issue: Product not appearing in Browse
**Solution**:
- Verify product `buildingId` matches user's building
- Check product status is "active" (not "sold" or "deleted")
- Verify user has `buildingId` assigned

### Issue: Phone requests not showing for seller
**Solution**:
- Verify `phoneRequests` collection has documents
- Check `listingId` and `sellerId` match
- Verify `getPhoneRequestsForListing()` query is correct

---

## Performance Testing

### Load Testing
- [ ] Test with 100+ products in marketplace
- [ ] Test with 50+ phone requests on single product
- [ ] Verify real-time streaming performance
- [ ] Check image loading speed

### Real-Time Updates
- [ ] Create product and verify appears in Browse immediately
- [ ] Accept phone request and verify status updates in real-time
- [ ] Mark product as sold and verify disappears from Browse
- [ ] Edit product and verify changes appear immediately

---

## Status: READY FOR TESTING ✅

All marketplace features implemented and ready for comprehensive testing.
