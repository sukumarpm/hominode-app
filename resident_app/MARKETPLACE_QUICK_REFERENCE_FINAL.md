# Marketplace - Quick Reference Guide

## Complete Feature Summary

### ✅ Edit Function
- **Location**: Your Products → Click Product → Edit Product button
- **Features**: Update title, price, category, condition, description, images
- **Validation**: All fields required
- **Result**: Product updated in Firestore

### ✅ Full View
- **Buyer View**: Browse → Click Product
  - Shows: Images, title, price, category, condition, description, seller name, date
  - Action: Request Phone Number button
  
- **Seller View**: Your Products → Click Product
  - Shows: All buyer details + Phone Requests section
  - Actions: Edit, Mark Sold, Delete buttons

### ✅ Phone Request Accept
- **Seller Action**: Your Products → Click Product → Phone Requests section
- **Process**: 
  1. See pending requests with requester name
  2. Click "Accept" button
  3. Request status changes to "Accepted"
  4. Requester's phone number now visible to seller
  5. Buyer can now see phone number

### ✅ Phone Number Display (After Accept)
- **Buyer View**: Browse → Click Product → "View Seller Contact" button
  - Shows: Seller name, phone number (if accepted)
  - Actions: Copy to clipboard, Call seller
  - If not accepted: "Seller has not accepted your request yet"

- **Seller View**: Your Products → Click Product → Phone Requests
  - Shows: Requester name, phone number (if accepted)
  - Status badge: Pending/Accepted/Rejected

### ✅ Delete Function
- **Location**: Your Products → Click Product → Delete Product button
- **Process**:
  1. Click Delete button
  2. Confirmation dialog appears
  3. Confirm deletion
  4. Product soft-deleted (status = 'deleted')
  5. Product removed from marketplace

---

## Data Flow

### Creating a Product
```
Seller creates product
  ↓
Data stored in 'marketplaces' collection with buildingId
  ↓
Product visible to all building members
```

### Phone Request Flow
```
Buyer clicks "Request Phone Number"
  ↓
Request stored in 'phoneRequests' collection (status: pending)
  ↓
Seller sees pending request in product details
  ↓
Seller clicks "Accept"
  ↓
Request status changes to "accepted"
  ↓
Buyer can now see phone number in "View Seller Contact"
```

### Editing a Product
```
Seller clicks "Edit Product"
  ↓
Edit screen opens with current data
  ↓
Seller updates fields and images
  ↓
Seller clicks "Update Product"
  ↓
Product updated in Firestore
  ↓
Changes visible immediately
```

### Deleting a Product
```
Seller clicks "Delete Product"
  ↓
Confirmation dialog
  ↓
Seller confirms
  ↓
Product status changed to 'deleted'
  ↓
Product removed from marketplace
```

---

## Key Points

1. **Building Members Only**: Products visible only to members of same building
2. **Phone Hidden by Default**: Phone numbers never shown until seller accepts
3. **Specific to Requester**: Each buyer only sees phone if THEY requested it
4. **Real-time Updates**: Changes visible immediately via Firestore streaming
5. **Soft Delete**: Products marked as deleted, not permanently removed
6. **Form Validation**: All required fields must be filled
7. **Error Handling**: User-friendly error messages for all operations

---

## Screens

1. **Marketplace Screen** (Main)
   - Browse Tab: View all products
   - Your Products Tab: Manage your products

2. **Product Detail Screen** (Buyer)
   - View product details
   - Request phone number
   - View seller contact (if accepted)

3. **Your Product Detail Screen** (Seller)
   - View product details
   - Manage phone requests
   - Edit, mark sold, delete options

4. **Edit Listing Screen**
   - Update product information
   - Add/remove images
   - Save changes

5. **Buyer Phone View Screen**
   - View seller contact info
   - Copy phone number
   - Call seller

---

## Service Methods

### For Buyers
- `requestPhoneNumber(listingId)` - Request phone
- `getAcceptedPhoneNumbersForBuyer(listingId)` - Get phone if accepted

### For Sellers
- `createListing(...)` - Create product
- `getMyListings()` - Get your products
- `updateListing(...)` - Edit product
- `deleteListing(listingId)` - Delete product
- `updateListingStatus(listingId, status)` - Mark as sold
- `acceptPhoneRequest(listingId, requesterId)` - Accept request
- `rejectPhoneRequest(requestId)` - Reject request
- `getPhoneRequestsForListing(listingId)` - Get all requests

### For Both
- `getAllListings()` - Get all products for building
- `getListingsByCategory(category)` - Filter by category
- `streamAllListings()` - Real-time product stream

---

## Compilation Status

✅ All 7 files compile without errors
✅ No type mismatches
✅ All imports resolved
✅ Ready for testing

