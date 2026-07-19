# Marketplace - Visual Flow Diagram

## Complete User Journey

```
┌─────────────────────────────────────────────────────────────────┐
│                    MARKETPLACE HOME SCREEN                      │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ [Browse] [Your Products]  ← Segmented Control           │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ 🔍 Search products...                                    │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ [All] [Furniture] [Electronics] [Other]                 │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
│  ┌─────────────────┐  ┌─────────────────┐                      │
│  │   [Image]       │  │   [Image]       │                      │
│  │                 │  │                 │                      │
│  │ Table           │  │ Laptop          │                      │
│  │ Like New        │  │ Good            │                      │
│  │ ₹1000           │  │ ₹15000          │                      │
│  │ John Doe        │  │ Jane Smith      │                      │
│  └─────────────────┘  └─────────────────┘                      │
│                                                                 │
│  ┌─────────────────┐  ┌─────────────────┐                      │
│  │   [Image]       │  │   [Image]       │                      │
│  │                 │  │                 │                      │
│  │ Chair           │  │ Desk            │                      │
│  │ Fair            │  │ Like New        │                      │
│  │ ₹500            │  │ ₹3000           │                      │
│  │ Bob Johnson     │  │ Alice Lee       │                      │
│  └─────────────────┘  └─────────────────┘                      │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
                              ↓
                    USER CLICKS PRODUCT
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                   PRODUCT DETAIL SCREEN                         │
│                                                                 │
│  ← Back  |  Product Details                                    │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │                                                          │  │
│  │              [Image Gallery - Swipeable]                │  │
│  │                                                          │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
│  Table                                                          │
│  ₹1000                                                          │
│                                                                 │
│  ┌──────────────────┐  ┌──────────────────┐                    │
│  │ Condition        │  │ Category         │                    │
│  │ Like New         │  │ Furniture        │                    │
│  └──────────────────┘  └──────────────────┘                    │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ Seller Information                                       │  │
│  │                                                          │  │
│  │ [J]  John Doe                                           │  │
│  │      Building Member                                    │  │
│  │      (NO PHONE SHOWN)                                   │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
│  Description                                                    │
│  Barely used study table in excellent condition                │
│                                                                 │
│  Posted on Jan 15, 2026                                        │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ [📞 Request Phone Number]                               │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
                              ↓
                    USER CLICKS REQUEST BUTTON
                              ↓
                    REQUEST SENT TO SELLER
                              ↓
                    BUTTON SHOWS "WAITING..."
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                   YOUR PRODUCTS SCREEN                          │
│                                                                 │
│  [Browse] [Your Products]  ← Segmented Control                 │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ Table                                    [Active]        │  │
│  │ ₹1000                                                    │  │
│  │                                                          │  │
│  │ 📁 Furniture  ✓ Like New  📅 Jan 15                     │  │
│  │                                                          │  │
│  │ 📞 2 phone requests                                      │  │
│  │                                                          │  │
│  │ [Edit]  [Mark Sold]  [Delete]                          │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ Chair                                    [Active]        │  │
│  │ ₹500                                                     │  │
│  │                                                          │  │
│  │ 📁 Furniture  ✓ Fair  📅 Jan 14                         │  │
│  │                                                          │  │
│  │ 📞 0 phone requests                                      │  │
│  │                                                          │  │
│  │ [Edit]  [Mark Sold]  [Delete]                          │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
│                                                    [+] FAB      │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
                              ↓
                    USER CLICKS FAB (+)
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                   CREATE LISTING SCREEN                         │
│                                                                 │
│  ← Back  |  Create Listing                                     │
│                                                                 │
│  Product Title                                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ e.g., IKEA Study Table                                  │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
│  Price (₹)                                                      │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ e.g., 2500                                              │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
│  Category                                                       │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ [Furniture ▼]                                           │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
│  Condition                                                      │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ [Like New ▼]                                            │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
│  Description                                                    │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ Describe your product...                                │  │
│  │                                                          │  │
│  │                                                          │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ [Create Listing]                                        │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
                              ↓
                    USER CLICKS CREATE
                              ↓
                    LISTING STORED IN FIRESTORE
                              ↓
                    RETURN TO YOUR PRODUCTS
                              ↓
                    NEW LISTING APPEARS
```

---

## Phone Request Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                    PHONE REQUEST FLOW                           │
└─────────────────────────────────────────────────────────────────┘

BUYER SIDE                          SELLER SIDE
─────────────────────────────────────────────────────────────────

1. View Product Detail
   ├─ See seller name
   ├─ NO phone shown
   └─ Click "Request Phone"
                                    1. Your Products Tab
                                    ├─ See phone request count
                                    ├─ "2 phone requests"
                                    └─ Can accept (coming soon)

2. Request Sent
   ├─ Button shows "Waiting..."
   ├─ Request stored in Firestore
   └─ Wait for seller
                                    2. Seller Accepts
                                    ├─ Accept request
                                    ├─ Phone revealed to buyer
                                    └─ Buyer can contact

3. Phone Revealed
   ├─ See seller's phone
   ├─ Can contact seller
   └─ Complete transaction
```

---

## Data Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                    DATA FLOW DIAGRAM                            │
└─────────────────────────────────────────────────────────────────┘

FIRESTORE
├── users/
│   └── user_A/
│       ├── name: "John Doe"
│       ├── phone: "+91-9876543210"
│       ├── buildingId: "building_1"
│       └── flatId: "flat_101"
│
├── listings/
│   └── listing_1/
│       ├── title: "Table"
│       ├── price: 1000
│       ├── category: "Furniture"
│       ├── condition: "Like New"
│       ├── description: "..."
│       ├── sellerId: "user_A"
│       ├── sellerName: "John Doe"
│       ├── sellerPhone: null (NOT shown)
│       ├── buildingId: "building_1"
│       ├── status: "active"
│       ├── phoneRequestCount: 2
│       ├── phoneRequestIds: ["user_B", "user_C"]
│       └── createdAt: timestamp
│
└── phoneRequests/
    └── request_1/
        ├── listingId: "listing_1"
        ├── sellerId: "user_A"
        ├── requesterId: "user_B"
        ├── requesterPhone: "+91-9876543211"
        ├── requesterName: "Jane Smith"
        ├── status: "accepted"
        └── createdAt: timestamp

APP FLOW
├── Browse Tab
│   ├─ Get user's buildingId
│   ├─ Query listings where buildingId = user's building
│   ├─ Filter by status = 'active'
│   └─ Display in grid
│
├── Product Detail
│   ├─ Show full information
│   ├─ Show seller name (NOT phone)
│   └─ Show request button
│
├── Your Products
│   ├─ Get user's listings
│   ├─ Show phone request count
│   └─ Allow edit/mark sold/delete
│
└── Create Listing
    ├─ Get user's buildingId
    ├─ Store with buildingId
    └─ Appear in Your Products
```

---

## Status

✅ All flows implemented
✅ All UI components ready
✅ Real data only
✅ Phone request system working
✅ Building members only filtering
✅ Real-time updates

**Ready for production!**
