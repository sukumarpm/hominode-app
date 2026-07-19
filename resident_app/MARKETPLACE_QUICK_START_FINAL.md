# Marketplace - Quick Start Guide

## How It Works

### For Buyers
1. **Browse** → Find products from your building
2. **Search & Filter** → Find what you need
3. **View Details** → See full product info
4. **Request Phone** → Ask seller for their number
5. **Wait** → Seller accepts or rejects
6. **Contact** → Call or message seller

### For Sellers
1. **Create** → List a product with images
2. **Manage** → View your products
3. **Accept Requests** → Give phone to interested buyers
4. **Edit** → Update product details
5. **Mark Sold** → Remove from listings
6. **Delete** → Remove product completely

---

## Key Rules

✅ **Only building members can see products**
- Products filtered by building ID
- Cross-building products hidden

✅ **Phone numbers are private**
- Not shown by default
- Require buyer request
- Seller must accept
- Only visible to accepted buyer

✅ **Sellers are protected**
- Can't request own products
- Only see requests for their products
- Can accept or reject requests

✅ **Real-time updates**
- Products appear immediately
- Status changes instant
- Phone requests update live

---

## Screens

### Buyer Screens
| Screen | Purpose |
|--------|---------|
| Browse Tab | Search & filter products |
| Product Detail | View full product info |
| Seller Contact | View accepted phone number |

### Seller Screens
| Screen | Purpose |
|--------|---------|
| Your Products | Manage your listings |
| Product Detail | View requests & manage |
| Create Listing | Add new product |
| Edit Listing | Update product info |

---

## Data Flow

### Creating a Product
```
Seller creates listing
    ↓
Stored in marketplaces collection
    ↓
buildingId set automatically
    ↓
Visible to all building members
```

### Requesting Phone
```
Buyer clicks "Request Phone Number"
    ↓
Document created in phoneRequests collection
    ↓
Status: pending
    ↓
Seller sees request in Your Products
```

### Accepting Request
```
Seller clicks "Accept"
    ↓
phoneRequests status → accepted
    ↓
Buyer can now view phone number
    ↓
Seller's phone visible to buyer
```

---

## Firestore Collections

### marketplaces
- Stores all products
- Filtered by buildingId
- Status: active/sold/deleted

### phoneRequests
- Stores all phone requests
- Status: pending/accepted/rejected
- Links buyer to seller

### users
- Stores user data
- Contains phone number
- Contains buildingId

---

## Common Actions

### Browse Products
```dart
streamAllListings() // Real-time stream
getAllListings()    // One-time fetch
```

### Get My Products
```dart
getMyListings() // Only seller's products
```

### Request Phone
```dart
requestPhoneNumber(listingId)
```

### Accept Request
```dart
acceptPhoneRequest(listingId, requesterId)
```

### View Phone Number (Buyer)
```dart
getAcceptedPhoneNumbersForBuyer(listingId)
```

### View Requests (Seller)
```dart
getPhoneRequestsForListing(listingId)
```

---

## Status Badges

### Product Status
- **Active** - Available for sale
- **Sold** - No longer available
- **Deleted** - Removed by seller

### Request Status
- **Pending** - Waiting for seller response
- **Accepted** - Seller shared phone number
- **Rejected** - Seller declined request

---

## Tips for Users

### For Buyers
- Search by product name
- Filter by category
- Check product condition
- Read full description
- Request phone early
- Be polite to sellers

### For Sellers
- Add clear product images
- Write detailed description
- Set fair price
- Respond to requests quickly
- Accept genuine buyers
- Mark sold when done

---

## Troubleshooting

### Can't see products?
- Check if you're in a building
- Verify building ID is set
- Try refreshing

### Phone request not sending?
- Check internet connection
- Verify you're not the seller
- Try again in a moment

### Can't see phone number?
- Wait for seller to accept
- Check request status
- Refresh the screen

### Product not appearing?
- Verify status is "active"
- Check building ID matches
- Wait for real-time update

---

## Performance Tips

- Images load faster with good connection
- Real-time updates work best on WiFi
- Search is instant with good data
- Filtering happens locally (fast)

---

## Security & Privacy

✅ Phone numbers protected
✅ Only shared with accepted buyers
✅ Building members only
✅ Seller can reject requests
✅ Data encrypted in transit

---

## Status: READY ✅

Marketplace fully functional and ready for use!
