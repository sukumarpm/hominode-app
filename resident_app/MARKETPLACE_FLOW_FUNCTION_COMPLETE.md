# Marketplace Flow Function - Complete Implementation

## Overview
The marketplace has been fully implemented with proper flow function following the requirements:
- **Data Storage**: Uses `buildingId` (NOT `flatId`)
- **Visibility**: Products visible to **building members only**
- **Phone Numbers**: NOT shown by default - require request → acceptance flow
- **Seller Protection**: Sellers don't see "Request Phone Number" button on their own products
- **UI**: Two-tab interface (Browse / Your Products)

---

## Complete Flow Function

### 1. BUYER FLOW - Browse & Request Phone

#### Step 1: Browse Products
- **Screen**: `MarketplaceScreen` (Browse tab)
- **Data Source**: `streamAllListings()` - streams products from `marketplaces` collection
- **Filter**: Only shows products where `buildingId` matches user's building
- **Features**:
  - Search by product title
  - Filter by category (All, Furniture, Electronics, Appliances, Books, Clothing, Sports, Toys, Home Decor, Kitchen, Other)
  - Grid view with product image, title, price, condition

#### Step 2: View Product Details
- **Screen**: `MarketplaceProductDetailScreen`
- **Data Displayed**:
  - Full product images (PageView gallery)
  - Title, price, category, condition
  - Seller information (name, avatar)
  - Full description
  - Posted date
- **Ownership Check**: 
  - If user is the seller → No "Request Phone Number" button shown
  - If user is a buyer → "Request Phone Number" button shown in bottom navigation bar

#### Step 3: Request Phone Number
- **Action**: Click "Request Phone Number" button
- **What Happens**:
  1. Creates document in `phoneRequests` collection with:
     - `listingId`: Product ID
     - `sellerId`: Seller's user ID
     - `requesterId`: Buyer's user ID
     - `requesterName`: Buyer's name
     - `requesterPhone`: Buyer's phone number
     - `status`: "pending"
     - `createdAt`: Timestamp
  2. Updates `marketplaces` document:
     - Adds buyer ID to `phoneRequestIds` array
     - Increments `phoneRequestCount`
  3. Shows success message: "Phone request sent to seller"
  4. Button changes to "Request Sent - Waiting for Seller" (disabled)

#### Step 4: Wait for Seller Acceptance
- **Status**: "pending" in `phoneRequests` collection
- **Buyer View**: Button shows "Request Sent - Waiting for Seller"
- **Seller View**: Phone request appears in "Your Products" → Product Detail → Phone Requests section

#### Step 5: View Accepted Phone Number
- **Trigger**: Seller accepts the request
- **Screen**: `MarketplaceBuyerPhoneViewScreen`
- **Access**: Click "View Seller Contact" button (only appears after request is sent)
- **Data Displayed**:
  - Seller name
  - Seller phone number (only if seller accepted)
  - Copy to clipboard button
  - Call seller button
  - Tips for contacting seller

---

### 2. SELLER FLOW - Manage Products & Phone Requests

#### Step 1: Create Product
- **Screen**: `MarketplaceCreateListingScreen`
- **Features**:
  - Title, price, category, condition, description
  - Image picker (gallery or camera)
  - Images optimized to 1024x1024px, 85% quality
  - Up to 10 categories
- **Data Stored**:
  - `buildingId`: Automatically set from user's building
  - `sellerId`: Current user ID
  - `sellerName`: Current user's name
  - `status`: "active"
  - `phoneRequestCount`: 0
  - `phoneRequestIds`: []

#### Step 2: View Your Products
- **Screen**: `MarketplaceScreen` (Your Products tab)
- **Component**: `MarketplaceYourProductsScreen`
- **Data Source**: `getMyListings()` - fetches products where `sellerId` matches current user
- **Product Card Shows**:
  - Product image, title, price
  - Status badge (Active/Sold)
  - Category, condition, date chips
  - Phone request count (clickable)
  - Edit, Mark Sold, Delete buttons

#### Step 3: View Product Details (Seller View)
- **Screen**: `MarketplaceYourProductDetailScreen`
- **Data Displayed**:
  - Full product images (PageView gallery with counter)
  - Title, price, status badge
  - Category, condition, date
  - Full description
  - **Phone Requests Section** (NEW):
    - Shows all phone requests for this product
    - For each request shows:
      - Requester name
      - Request status (Pending/Accepted/Rejected)
      - If accepted: Shows requester's phone number
      - If pending: Accept/Reject buttons
  - Action buttons: Edit Product, Mark as Sold, Delete Product

#### Step 4: Accept/Reject Phone Requests
- **Location**: Product Detail → Phone Requests section
- **Accept Action**:
  1. Updates `phoneRequests` document: `status` → "accepted"
  2. Requester can now view seller's phone number
  3. Request card shows "Accepted" badge with phone number
- **Reject Action**:
  1. Updates `phoneRequests` document: `status` → "rejected"
  2. Request card shows "Rejected" badge
  3. Requester cannot view phone number

#### Step 5: Edit Product
- **Screen**: `MarketplaceEditListingScreen`
- **Features**:
  - Edit all product details (title, price, category, condition, description)
  - Manage images (add/remove)
  - Form validation
- **Data Updated**: Updates `marketplaces` document with new values

#### Step 6: Mark as Sold
- **Action**: Click "Mark as Sold" button
- **What Happens**:
  1. Updates `marketplaces` document: `status` → "sold"
  2. Product no longer appears in Browse tab
  3. Product card shows "Sold" badge in Your Products tab
  4. Button becomes disabled

#### Step 7: Delete Product
- **Action**: Click "Delete Product" button
- **Confirmation**: Shows confirmation dialog
- **What Happens**:
  1. Updates `marketplaces` document: `status` → "deleted"
  2. Product removed from all views
  3. Phone requests remain in database (for history)

---

## Data Structure

### Firestore Collections

#### `marketplaces` Collection
```
{
  id: "listing_id",
  title: "Product Title",
  price: 5000,
  category: "Electronics",
  condition: "Like New",
  description: "Product description...",
  images: ["url1", "url2", ...],
  sellerId: "user_id",
  sellerName: "Seller Name",
  buildingId: "building_id",
  status: "active" | "sold" | "deleted",
  phoneRequestCount: 2,
  phoneRequestIds: ["buyer_id_1", "buyer_id_2"],
  createdAt: Timestamp,
  updatedAt: Timestamp
}
```

#### `phoneRequests` Collection
```
{
  id: "request_id",
  listingId: "listing_id",
  sellerId: "seller_id",
  sellerName: "Seller Name",
  requesterId: "buyer_id",
  requesterName: "Buyer Name",
  requesterPhone: "+91XXXXXXXXXX",
  status: "pending" | "accepted" | "rejected",
  createdAt: Timestamp,
  updatedAt: Timestamp
}
```

---

## Key Service Methods

### ListingFirestoreService

#### Create Listing
```dart
Future<ServiceResult> createListing({
  required String title,
  required int price,
  required String category,
  required String condition,
  required String description,
  List<String> images = const [],
})
```

#### Get Listings
```dart
Future<List<ListingModel>> getAllListings()  // Building members only
Future<List<ListingModel>> getMyListings()   // Current user's products
Stream<List<ListingModel>> streamAllListings() // Real-time building products
```

#### Phone Request Operations
```dart
Future<ServiceResult> requestPhoneNumber(String listingId)
Future<ServiceResult> acceptPhoneRequest(String listingId, String requesterId)
Future<ServiceResult> rejectPhoneRequest(String requestId)
Future<List<Map<String, dynamic>>> getPhoneRequestsForListing(String listingId)
Future<List<Map<String, dynamic>>> getAcceptedPhoneNumbersForBuyer(String listingId)
```

#### Update/Delete
```dart
Future<ServiceResult> updateListing({...})
Future<ServiceResult> updateListingStatus(String listingId, String status)
Future<ServiceResult> deleteListing(String listingId)
```

---

## UI Screens

### Buyer Screens
1. **MarketplaceScreen (Browse Tab)**
   - Search and category filter
   - Grid view of products
   - Real-time streaming

2. **MarketplaceProductDetailScreen**
   - Full product details
   - Image gallery
   - Seller information
   - Request phone button (for buyers only)

3. **MarketplaceBuyerPhoneViewScreen**
   - Shows accepted phone number
   - Copy to clipboard
   - Call seller button
   - Tips for contacting

### Seller Screens
1. **MarketplaceScreen (Your Products Tab)**
   - List of seller's products
   - Status badges
   - Phone request count
   - Quick actions (Edit, Mark Sold, Delete)

2. **MarketplaceYourProductDetailScreen**
   - Full product details
   - Phone requests section with Accept/Reject
   - Edit, Mark Sold, Delete buttons

3. **MarketplaceCreateListingScreen**
   - Create new product
   - Image picker
   - Form validation

4. **MarketplaceEditListingScreen**
   - Edit product details
   - Manage images
   - Form validation

---

## Security & Access Control

### Building-Based Access
- Products only visible to members of the same building
- Queries filter by `buildingId` from user's profile
- User must have `buildingId` assigned to create/view listings

### Seller Protection
- Sellers cannot see "Request Phone Number" button on their own products
- Sellers can only manage their own products
- Phone requests only visible to product seller

### Phone Number Privacy
- Phone numbers NOT shown by default
- Requires explicit request from buyer
- Seller must accept request to reveal phone number
- Phone number only visible to specific requester who was accepted

---

## Testing Checklist

### Buyer Flow
- [ ] Browse products from building members
- [ ] Search products by title
- [ ] Filter by category
- [ ] View full product details
- [ ] Request phone number
- [ ] See "Request Sent" status
- [ ] View seller contact after acceptance
- [ ] Copy phone number to clipboard

### Seller Flow
- [ ] Create product with images
- [ ] View Your Products list
- [ ] See phone request count
- [ ] View product details
- [ ] See phone requests with requester info
- [ ] Accept phone request
- [ ] Reject phone request
- [ ] Edit product details
- [ ] Mark product as sold
- [ ] Delete product

### Data Integrity
- [ ] Products only visible to building members
- [ ] Phone requests properly stored
- [ ] Status updates reflected in real-time
- [ ] Seller cannot see own products in Browse tab
- [ ] Phone numbers only shown after acceptance

---

## Status: COMPLETE ✅

All marketplace features implemented according to flow function requirements:
- ✅ Building-based access control
- ✅ Two-tab interface (Browse/Your Products)
- ✅ Phone request system with acceptance flow
- ✅ Seller product management
- ✅ Real-time data streaming
- ✅ Image handling with optimization
- ✅ Proper UI/UX with loading states
- ✅ Error handling and validation
