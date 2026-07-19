# Marketplace UI & Flow - Visual Guide

## Buyer Journey

### Screen 1: Browse Tab
```
┌─────────────────────────────┐
│  Marketplace                │
│  [Browse] [Your Products]   │
├─────────────────────────────┤
│  [Search products...]       │
│  [All] [Furniture] [Elec]   │
├─────────────────────────────┤
│  ┌─────────────────────────┐│
│  │ [Image]                 ││
│  │ Product Title           ││
│  │ ₹1500                   ││
│  │ Like New                ││
│  └─────────────────────────┘│
│  ┌─────────────────────────┐│
│  │ [Image]                 ││
│  │ Another Product         ││
│  │ ₹2000                   ││
│  │ Good Condition          ││
│  └─────────────────────────┘│
└─────────────────────────────┘
```

### Screen 2: Product Detail (Buyer View)
```
┌─────────────────────────────┐
│ ← Product Details           │
├─────────────────────────────┤
│  ┌─────────────────────────┐│
│  │   [Product Image]       ││
│  │   (PageView Gallery)    ││
│  └─────────────────────────┘│
│                             │
│  Product Title              │
│  ₹1500                      │
│                             │
│  [Like New] [Furniture]     │
│                             │
│  Seller Information         │
│  ┌─────────────────────────┐│
│  │ [Avatar] Seller Name    ││
│  │          Building Member││
│  └─────────────────────────┘│
│                             │
│  Description                │
│  This is a good table...    │
│                             │
│  Posted on Mar 12, 2026     │
│                             │
│  ┌─────────────────────────┐│
│  │ Request Phone Number    ││
│  └─────────────────────────┘│
└─────────────────────────────┘
```

### Screen 3: After Request Sent
```
┌─────────────────────────────┐
│ ← Product Details           │
├─────────────────────────────┤
│  [Product Details...]       │
│                             │
│  ┌─────────────────────────┐│
│  │ Request Sent - Waiting  ││
│  │ for Seller (Disabled)   ││
│  └─────────────────────────┘│
│                             │
│  [Waiting for acceptance]   │
└─────────────────────────────┘
```

### Screen 4: After Acceptance
```
┌─────────────────────────────┐
│ ← Product Details           │
├─────────────────────────────┤
│  [Product Details...]       │
│                             │
│  ┌─────────────────────────┐│
│  │ View Seller Contact ✓   ││
│  └─────────────────────────┘│
└─────────────────────────────┘
```

### Screen 5: View Seller Contact
```
┌─────────────────────────────┐
│ ← Seller Contact            │
├─────────────────────────────┤
│  Product: Table             │
│  Price: ₹1500               │
│  Seller: John Doe           │
│                             │
│  ✓ Request Accepted         │
│                             │
│  Seller Name                │
│  John Doe                   │
│                             │
│  Phone Number               │
│  ┌─────────────────────────┐│
│  │ +91 98765 43210 [Copy]  ││
│  └─────────────────────────┘│
│                             │
│  ┌─────────────────────────┐│
│  │ Call Seller             ││
│  └─────────────────────────┘│
│                             │
│  Tips for Contacting:       │
│  ✓ Be polite and respectful │
│  ✓ Ask about condition      │
│  ✓ Arrange safe meeting     │
│  ✓ Inspect before payment   │
└─────────────────────────────┘
```

---

## Seller Journey

### Screen 1: Your Products Tab
```
┌─────────────────────────────┐
│  Marketplace                │
│  [Browse] [Your Products]   │
├─────────────────────────────┤
│  ┌─────────────────────────┐│
│  │ table              Active││
│  │ ₹1500                   ││
│  │ Furniture Like New      ││
│  │ Mar 12, 2026            ││
│  │ 📞 1 phone request →    ││
│  │ [Edit] [Mark Sold] [Del]││
│  └─────────────────────────┘│
│  ┌─────────────────────────┐│
│  │ chair              Active││
│  │ ₹800                    ││
│  │ Furniture Good Cond     ││
│  │ Mar 10, 2026            ││
│  │ [Edit] [Mark Sold] [Del]││
│  └─────────────────────────┘│
│                             │
│                          [+]│
└─────────────────────────────┘
```

### Screen 2: Product Detail (Seller View)
```
┌─────────────────────────────┐
│ ← Product Details           │
├─────────────────────────────┤
│  ┌─────────────────────────┐│
│  │   [Product Image]       ││
│  │   (1/3)                 ││
│  └─────────────────────────┘│
│                             │
│  table              Active  │
│  ₹1500                      │
│                             │
│  [Furniture] [Like New]     │
│  [Mar 12, 2026]             │
│                             │
│  Description                │
│  good table                 │
│                             │
│  Phone Requests (1)         │
│  ┌─────────────────────────┐│
│  │ John Doe                ││
│  │ Pending                 ││
│  │ [Reject] [Accept]       ││
│  └─────────────────────────┘│
│                             │
│  ┌─────────────────────────┐│
│  │ Edit Product            ││
│  └─────────────────────────┘│
│  ┌─────────────────────────┐│
│  │ Mark as Sold            ││
│  └─────────────────────────┘│
│  ┌─────────────────────────┐│
│  │ Delete Product          ││
│  └─────────────────────────┘│
└─────────────────────────────┘
```

### Screen 3: After Accepting Request
```
┌─────────────────────────────┐
│ ← Product Details           │
├─────────────────────────────┤
│  [Product Details...]       │
│                             │
│  Phone Requests (1)         │
│  ┌─────────────────────────┐│
│  │ John Doe                ││
│  │ ✓ Accepted              ││
│  │ +91 98765 43210         ││
│  └─────────────────────────┘│
│                             │
│  [Edit Product]             │
│  [Mark as Sold]             │
│  [Delete Product]           │
└─────────────────────────────┘
```

---

## Data Flow

### Phone Request Flow
```
┌─────────────┐
│   BUYER     │
│  Requests   │
│   Phone     │
└──────┬──────┘
       │
       ▼
┌──────────────────────────────┐
│  phoneRequests Collection    │
│  ┌────────────────────────┐  │
│  │ status: "pending"      │  │
│  │ requesterId: buyer_id  │  │
│  │ sellerId: seller_id    │  │
│  │ requesterPhone: +91... │  │
│  └────────────────────────┘  │
└──────┬───────────────────────┘
       │
       ▼
┌─────────────┐
│   SELLER    │
│   Accepts   │
│   Request   │
└──────┬──────┘
       │
       ▼
┌──────────────────────────────┐
│  phoneRequests Collection    │
│  ┌────────────────────────┐  │
│  │ status: "accepted"     │  │
│  │ requesterId: buyer_id  │  │
│  │ sellerId: seller_id    │  │
│  │ requesterPhone: +91... │  │
│  └────────────────────────┘  │
└──────┬───────────────────────┘
       │
       ▼
┌─────────────┐
│   BUYER     │
│   Views     │
│   Phone     │
└─────────────┘
```

---

## State Management

### Buyer State
```
_isOwnProduct = false
_phoneRequested = false
_isRequestingPhone = false
_isLoadingCheck = false
_currentUserId = "buyer_id"
```

### Seller State
```
_isLoading = false
_currentImageIndex = 0
_imageController = PageController()
```

---

## Navigation Flow

### Buyer Navigation
```
Dashboard
    ↓
Marketplace (Browse Tab)
    ↓
Product Detail Screen
    ↓
Request Phone
    ↓
View Seller Contact Screen
```

### Seller Navigation
```
Dashboard
    ↓
Marketplace (Your Products Tab)
    ↓
Your Products List
    ↓
Product Detail Screen
    ├─ Accept/Reject Request
    ├─ Edit Product
    ├─ Mark as Sold
    └─ Delete Product
```

---

## Button States

### Request Phone Button
```
Initial State:
┌─────────────────────────────┐
│ Request Phone Number        │
└─────────────────────────────┘

Loading State:
┌─────────────────────────────┐
│ [Loading Spinner]           │
└─────────────────────────────┘

After Request:
┌─────────────────────────────┐
│ Request Sent - Waiting...   │
│ (Disabled - Gray)           │
└─────────────────────────────┘

After Acceptance:
┌─────────────────────────────┐
│ View Seller Contact         │
│ (Enabled - Green)           │
└─────────────────────────────┘
```

---

## Error Handling

### Scenarios
```
1. User not authenticated
   → Show error message
   → Redirect to login

2. User has no building assigned
   → Show error message
   → Cannot create/view listings

3. Phone request already sent
   → Show error message
   → Button disabled

4. Seller not found
   → Show error message
   → Cannot view phone

5. Network error
   → Show error message
   → Retry button
```

---

## Real-Time Updates

### Streaming
```
Browse Tab
    ↓
streamAllListings()
    ↓
Real-time updates
    ↓
Products appear/disappear
    ↓
Status changes reflected
```

---

## Status: COMPLETE ✅

All UI screens properly designed and flow function working correctly.
