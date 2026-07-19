# Billing Flow Function - Complete Implementation

## Overview
The Maintenance & Billing screen now fetches data from Firestore based on the resident's flat assignment, following the proper flow function.

## Flow Function

### 1. User Authentication
```
Current User (Firebase Auth)
    ↓
User ID (authUid)
```

### 2. Flat Assignment Lookup
```
User ID
    ↓
Query: flats collection
    WHERE residentIds ARRAY_CONTAINS userId
    ↓
Flat ID
```

### 3. Bills Fetch
```
Flat ID
    ↓
Query: bills collection
    WHERE flatId == flatId
    WHERE status == 'pending' (for current bill)
    OR status == 'paid' (for payment history)
    ↓
Bills Data
```

## Implementation Details

### BillFirestoreService Updates

#### New Method: `_getResidentFlatId()`
```dart
Future<String?> _getResidentFlatId() async {
  // 1. Get current user ID
  // 2. Query flats collection where residentIds contains user ID
  // 3. Return flat ID
}
```

#### Updated Methods

**`getBills()`**
- Fetches flat ID first
- Queries bills by flatId (not residentId)
- Returns all bills for the flat

**`getCurrentBill()`**
- Fetches flat ID first
- Queries pending bills by flatId
- Returns most recent pending bill

**`getPaymentHistory()`**
- Fetches flat ID first
- Queries paid bills by flatId
- Returns payment history sorted by paid date

**`streamBills()`**
- Fetches flat ID first
- Streams real-time updates for bills by flatId

## Firestore Structure

### Bills Collection
```
bills/
  {billId}/
    flatId: "flat123"           // ✅ Query by this
    amount: 5000
    dueDate: Timestamp
    status: "pending" | "paid" | "overdue"
    month: "January 2024"
    maintenanceCharge: 3000
    waterCharge: 500
    parkingCharge: 1000
    serviceCharge: 500
    paidAt: Timestamp (if paid)
    paymentMethod: "UPI" (if paid)
    transactionId: "TXN123" (if paid)
    createdAt: Timestamp
    updatedAt: Timestamp
```

### Flats Collection
```
flats/
  {flatId}/
    flatNumber: "A-101"
    buildingId: "building123"
    residentIds: ["user1", "user2"]  // ✅ Query by this
    ...
```

## Data Flow Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    Maintenance & Billing Screen              │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│                    BillFirestoreService                      │
│                                                              │
│  1. _getResidentFlatId()                                    │
│     ├─ Get current user ID from Firebase Auth              │
│     ├─ Query flats WHERE residentIds CONTAINS userId       │
│     └─ Return flatId                                        │
│                                                              │
│  2. getCurrentBill()                                        │
│     ├─ Get flatId from step 1                              │
│     ├─ Query bills WHERE flatId == flatId                  │
│     │                  AND status == 'pending'              │
│     └─ Return most recent pending bill                     │
│                                                              │
│  3. getPaymentHistory()                                     │
│     ├─ Get flatId from step 1                              │
│     ├─ Query bills WHERE flatId == flatId                  │
│     │                  AND status == 'paid'                 │
│     └─ Return paid bills sorted by paidAt                  │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│                         Firestore                            │
│                                                              │
│  Collections:                                               │
│  ├─ flats/                                                  │
│  │   └─ {flatId}                                           │
│  │       └─ residentIds: [userId1, userId2, ...]          │
│  │                                                          │
│  └─ bills/                                                  │
│      └─ {billId}                                           │
│          ├─ flatId: "flat123"                              │
│          ├─ status: "pending" | "paid"                     │
│          ├─ amount: 5000                                   │
│          └─ ...                                            │
└─────────────────────────────────────────────────────────────┘
```

## Key Changes

### Before (Incorrect)
```dart
// ❌ Querying by residentId (doesn't exist in bills)
.where('residentId', isEqualTo: _userId)
```

### After (Correct)
```dart
// ✅ First get flat ID
final flatId = await _getResidentFlatId();

// ✅ Then query by flatId
.where('flatId', isEqualTo: flatId)
```

## Benefits

1. **Correct Data Association**: Bills are associated with flats, not individual users
2. **Multi-Resident Support**: Multiple residents in the same flat see the same bills
3. **Scalable**: Follows proper relational data structure
4. **Maintainable**: Clear separation of concerns

## Testing

### Test Scenario 1: Single Resident
```
User: user123
Flat: A-101 (flatId: flat123)
Bills: 2 pending, 5 paid

Expected Result:
- Current Bill: Most recent pending bill for flat123
- Payment History: 5 paid bills for flat123
```

### Test Scenario 2: Multiple Residents
```
User1: user123
User2: user456
Flat: A-101 (flatId: flat123, residentIds: [user123, user456])
Bills: 1 pending, 3 paid

Expected Result (for both users):
- Current Bill: Same pending bill for flat123
- Payment History: Same 3 paid bills for flat123
```

### Test Scenario 3: No Flat Assigned
```
User: user789
Flat: None

Expected Result:
- Current Bill: null
- Payment History: []
- UI shows "No Pending Bills" card
```

## Error Handling

The service includes comprehensive error handling:

```dart
try {
  final flatId = await _getResidentFlatId();
  
  if (flatId == null) {
    print('❌ Cannot fetch bills: No flat assigned to user');
    return [];
  }
  
  // Fetch bills...
} catch (e) {
  print('❌ Error fetching bills: $e');
  return [];
}
```

## Logging

All methods include detailed logging:
- 🔍 Fetching operations
- ✅ Success messages with counts
- ❌ Error messages with details
- ⚠️ Warning messages for edge cases

## Next Steps

1. Test with real Firestore data
2. Verify flat assignment for test users
3. Create sample bills in Firestore
4. Test payment flow
5. Verify receipt generation

## Related Files

- `lib/src/services/bill_firestore_service.dart` - Updated service
- `lib/maintenance_billing_screen.dart` - UI screen
- `lib/src/models/bill_model.dart` - Bill data model
- `lib/src/services/resident_database_service.dart` - Reference implementation

---

**Status**: ✅ Complete
**Date**: 2024
**Updated By**: Kiro AI Assistant
