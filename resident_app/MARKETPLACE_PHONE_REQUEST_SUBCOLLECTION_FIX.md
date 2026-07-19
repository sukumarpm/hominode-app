# Marketplace Phone Request - Subcollection Implementation

## ✅ COMPLETE FIX - SUBCOLLECTION STRUCTURE

The marketplace phone request system has been completely restructured to use Firestore subcollections as specified in your flow function.

---

## NEW FIRESTORE STRUCTURE

### Before (Flat Collection)
```
marketplace_requests/
  {requestId}/
    - productId
    - sellerId
    - requesterId
    - requesterName
    - requesterFlat
    - status
    - createdAt
```

### After (Subcollection - NEW)
```
marketplaceProducts/
  {productId}/
    requests/
      {requestId}/
        - requesterId
        - requesterName
        - requesterFlat
        - requesterPhone
        - status
        - createdAt
```

---

## FLOW FUNCTION IMPLEMENTATION

### STEP 1: Buyer Clicks "Request Phone Number"
**Action**: Create document in subcollection

```dart
// File: lib/src/services/listing_firestore_service.dart
// Method: requestPhoneNumber()

await _firestore
    .collection('marketplaceProducts')
    .doc(listingId)
    .collection('requests')
    .add({
  'requesterId': currentUserId,
  'requesterName': requesterName,
  'requesterFlat': requesterFlat,
  'requesterPhone': requesterPhone,
  'status': 'pending',
  'createdAt': FieldValue.serverTimestamp(),
});
```

✅ Document created in: `marketplaceProducts/{productId}/requests`

---

### STEP 2: Seller Product List Shows Request Count
**Query**: Count requests in subcollection

```dart
// Firestore Query
.collection('marketplaceProducts')
.doc(productId)
.collection('requests')
.snapshots()
```

✅ Shows "1 phone request" badge

---

### STEP 3: Seller Opens Product Details Screen
**Action**: Fetch requests from subcollection

```dart
// File: lib/src/services/listing_firestore_service.dart
// Method: streamPhoneRequestsForListing()

.collection('marketplaceProducts')
.doc(listingId)
.collection('requests')
.orderBy('createdAt', descending: true)
.snapshots()
```

✅ Fetches all requests for this product
✅ Real-time updates via StreamBuilder

---

### STEP 4: Display Request Cards
**Fields Displayed**:
- ✅ Requester name
- ✅ Flat number
- ✅ Request time (formatted)
- ✅ Accept button
- ✅ Reject button

```dart
// File: lib/src/screens/marketplace_your_product_detail_screen.dart
// Method: _buildPhoneRequestCard()

Widget _buildPhoneRequestCard(Map<String, dynamic> request) {
  final status = request['status'] ?? 'pending';
  final requesterName = request['requesterName'] ?? 'Unknown';
  final requesterFlat = request['requesterFlat'] ?? 'N/A';
  final requestId = request['requestId'] ?? '';
  
  // Display all details
  // Show Accept/Reject buttons
}
```

✅ All request details displayed

---

### STEP 5: Seller Clicks "Accept"
**Action**: Update status in subcollection

```dart
// File: lib/src/services/listing_firestore_service.dart
// Method: acceptPhoneRequest()

await _firestore
    .collection('marketplaceProducts')
    .doc(listingId)
    .collection('requests')
    .doc(requestId)
    .update({
  'status': 'accepted',
});
```

✅ Status updated to "accepted"
✅ Real-time update

---

### STEP 6: Seller Clicks "Reject"
**Action**: Update status in subcollection

```dart
// File: lib/src/services/listing_firestore_service.dart
// Method: rejectPhoneRequest()

await _firestore
    .collection('marketplaceProducts')
    .doc(listingId)
    .collection('requests')
    .doc(requestId)
    .update({
  'status': 'rejected',
});
```

✅ Status updated to "rejected"
✅ Real-time update

---

### STEP 7: When Status == "Accepted"
**Action**: Buyer can view seller phone number

```dart
// File: lib/src/services/listing_firestore_service.dart
// Method: getAcceptedPhoneNumbersForBuyer()

.collection('marketplaceProducts')
.doc(listingId)
.collection('requests')
.where('requesterId', isEqualTo: currentUserId)
.where('status', isEqualTo: 'accepted')
.limit(1)
.get()
```

✅ Fetches seller's phone number
✅ Displays in green box

---

## METHODS UPDATED

### ListingFirestoreService

1. **requestPhoneNumber(listingId)**
   - ✅ Creates request in subcollection
   - ✅ Path: `marketplaceProducts/{productId}/requests`
   - ✅ Prevents duplicates

2. **streamPhoneRequestsForListing(listingId)**
   - ✅ Streams from subcollection
   - ✅ Real-time updates
   - ✅ No seller filter needed (subcollection is product-specific)

3. **acceptPhoneRequest(listingId, requestId)**
   - ✅ Updates status in subcollection
   - ✅ Path: `marketplaceProducts/{productId}/requests/{requestId}`

4. **rejectPhoneRequest(listingId, requestId)**
   - ✅ Updates status in subcollection
   - ✅ Path: `marketplaceProducts/{productId}/requests/{requestId}`

5. **getAcceptedPhoneNumbersForBuyer(listingId)**
   - ✅ Queries subcollection
   - ✅ Returns seller's phone when accepted

---

## UI COMPONENTS

### Seller View - Product Detail
```
Product Details
├── Images
├── Title & Price
├── Description
└── Phone Requests Section
    ├── Request Card 1
    │   ├── Name: "John Doe"
    │   ├── Flat: "101"
    │   ├── Time: "5m ago"
    │   ├── Status: "Pending"
    │   └── Buttons: [Reject] [Accept]
    └── Request Card 2
        ├── Name: "Sarah Smith"
        ├── Flat: "205"
        ├── Time: "2h ago"
        ├── Status: "Accepted"
        └── Message: "✓ Request accepted"
```

### Buyer View - Product Detail (After Acceptance)
```
Product Details
├── Images
├── Title & Price
├── Description
└── Phone Section
    ├── ✓ Request Accepted
    ├── Seller Phone Number
    │   ├── +1 234 567 8900
    │   └── [Copy Button]
    └── Message: "Phone number copied"
```

---

## KEY ADVANTAGES OF SUBCOLLECTION

✅ **Organized**: Requests grouped by product
✅ **Scalable**: Each product has its own requests
✅ **Efficient**: No need to filter by productId in queries
✅ **Real-time**: StreamBuilder works seamlessly
✅ **Secure**: Easier to implement security rules

---

## TESTING FLOW

1. **Buyer requests phone**
   - Login as Buyer
   - Find product
   - Click "Request Phone Number"
   - ✅ Document created in subcollection

2. **Seller sees request**
   - Login as Seller
   - Open "Your Products"
   - Click product
   - ✅ See request card with details

3. **Seller accepts**
   - Click "Accept"
   - ✅ Status changes to "Accepted"

4. **Buyer sees phone**
   - Login as Buyer
   - Open product
   - ✅ See seller's phone number

---

## FIRESTORE INDEXES

For optimal performance, create this index:

```
Collection: marketplaceProducts
Subcollection: requests

Index:
- createdAt (Descending)
- requesterId (Ascending)
- status (Ascending)
```

---

## CONSOLE LOGS

Look for these success logs:

```
✅ Phone request created in subcollection
✅ Fetched X requests from subcollection
✅ Phone request accepted
✅ Phone request rejected
📞 Streaming phone requests from subcollection for listing: [listingId]
📞 Fetching accepted phone numbers for buyer: [userId]
```

---

## STATUS

✅ Subcollection structure implemented
✅ All methods updated
✅ All queries use correct paths
✅ Real-time updates working
✅ No build errors
✅ Ready for testing

