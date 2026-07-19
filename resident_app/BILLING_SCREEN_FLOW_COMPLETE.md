# Billing Screen Data Flow - Complete ✅

## Overview
The Maintenance & Billing screen properly fetches and displays data from the Firestore `bills` collection according to the flow function pattern.

## Current Implementation Status

### ✅ Already Implemented
The billing screen is already fully functional with:
1. Real-time Firestore data fetching
2. Proper authentication handling (Firebase Auth + SharedPreferences)
3. Bill breakdown display
4. Payment history
5. Pay bill functionality

### ✅ Recent Fix Applied
Updated `BillFirestoreService` to support dual authentication (same as complaints fix):
- Checks Firebase Auth first
- Falls back to SharedPreferences if Firebase Auth not available
- Ensures billing works regardless of authentication method used

## Data Flow

### Flow Function Pattern
```
1. User opens Maintenance & Billing screen
   ↓
2. StreamBuilder listens to _billService.streamBills()
   ↓
3. BillFirestoreService._getResidentId()
   ↓
4. Try Firebase Auth user ID
   ↓ (if null)
5. Fallback to SharedPreferences user_id
   ↓
6. Fetch user data from users collection
   ↓
7. Extract residentId from user document
   ↓
8. Query bills collection: .where('residentId', isEqualTo: residentId)
   ↓
9. Stream real-time updates
   ↓
10. Separate bills by status (pending/paid)
   ↓
11. Display in UI with proper formatting
```

## Firestore Structure

### bills Collection
```javascript
bills/{billId}
{
  "residentId": "RES001",           // Required: Links to user
  "amount": 5000,                   // Total bill amount
  "status": "pending",              // "pending", "paid", "overdue"
  "month": "January 2024",          // Bill period
  "dueDate": Timestamp,             // When payment is due
  "paidAt": Timestamp,              // When payment was made (if paid)
  "paymentMethod": "UPI",           // Payment method used (if paid)
  "transactionId": "TXN123456",     // Transaction ID (if paid)
  
  // Bill breakdown (nested structure)
  "chargeBreakdown": {
    "Maintenance": 2000,
    "Water": 500,
    "Electricity": 1500,
    "Parking": 500,
    "Security": 300,
    "Service": 200
  },
  
  // OR flat structure (legacy support)
  "Maintenance": 2000,
  "Water": 500,
  "Electricity": 1500,
  "Parking": 500,
  "Security": 300,
  "Service": 200,
  
  "createdAt": Timestamp,
  "updatedAt": Timestamp
}
```

### users Collection (Required Fields)
```javascript
users/{userId}
{
  "name": "Preetham",
  "residentId": "RES001",           // Required: Links to bills
  "flatLabel": "t202",
  "email": "preetham@example.com",
  "phone": "+91 98765 43210"
}
```

## Screen Features

### 1. Current Bill Card
**Display**:
- Orange gradient card
- Bill amount (large, prominent)
- Due date
- Status badge (Pending/Overdue/Paid)
- "Pay Now" button (if pending)

**Data Source**:
```dart
// Get most recent pending bill
final pendingBills = bills.where((bill) => bill['status'] == 'pending').toList();
final currentBill = pendingBills.isNotEmpty ? pendingBills.first : null;
```

### 2. Bill Breakdown Card
**Display**:
- Itemized charges (Maintenance, Water, Electricity, etc.)
- Only shows non-zero items
- Total amount at bottom

**Data Source**:
```dart
// Supports both nested and flat structure
final breakdown = _billService.getBillBreakdown(bill);
// Returns: Map<String, double>
```

### 3. Payment History
**Display**:
- List of paid bills (most recent 3)
- Each item shows: month, paid date, amount
- Download receipt button
- "View All" link

**Data Source**:
```dart
// Get paid bills
final paidBills = bills.where((bill) => bill['status'] == 'paid').toList();
```

### 4. Empty States
- **No Pending Bills**: "You're all caught up!"
- **No Payment History**: "Your payment history will appear here"

## Authentication Handling

### Dual Authentication Support
```dart
// Try Firebase Auth first
String? userId;

final firebaseUser = _auth.currentUser;
if (firebaseUser != null) {
  userId = firebaseUser.uid;
  print('🆔 Using Firebase Auth User ID');
} else {
  // Fallback to Firestore-only authentication
  final prefs = await SharedPreferences.getInstance();
  userId = prefs.getString('user_id');
  print('🆔 Using Firestore User ID');
}
```

## Real-Time Updates

### StreamBuilder Implementation
```dart
StreamBuilder<List<Map<String, dynamic>>>(
  stream: _billService.streamBills(),
  builder: (context, snapshot) {
    // Loading state
    if (snapshot.connectionState == ConnectionState.waiting) {
      return CircularProgressIndicator();
    }
    
    // Error state
    if (snapshot.hasError) {
      return ErrorWidget();
    }
    
    // Data state
    final bills = snapshot.data ?? [];
    // ... display bills
  },
)
```

### Benefits
- Automatic UI updates when bills change
- No manual refresh needed
- Real-time sync across devices

## Performance Optimizations

### 1. Caching
```dart
// Cache current bill for 30 seconds
Map<String, dynamic>? _cachedCurrentBill;
DateTime? _lastFetchTime;
static const Duration _cacheDuration = Duration(seconds: 30);
```

### 2. Server-Side Filtering
```dart
// Firestore query with .where() - filters on server
.where('residentId', isEqualTo: residentId)
.where('status', isEqualTo: 'pending')
```

### 3. Limit Results
```dart
// Only show 10 most recent payments
final limitedPayments = payments.take(10).toList();
```

## Payment Flow

### 1. User Clicks "Pay Now"
```dart
onTap: () {
  showPaymentMethodModal(context, (method) {
    _handlePayment(method, billId);
  });
}
```

### 2. Select Payment Method
- UPI
- Card
- Net Banking

### 3. Process Payment
```dart
Future<void> _handlePayment(PaymentMethod method, String billId) async {
  final success = await _billService.payBill(
    billId: billId,
    paymentMethod: methodStr,
    transactionId: transactionId,
  );
  
  if (success) {
    // Show success message
    // Cache is automatically cleared
    // UI updates via StreamBuilder
  }
}
```

### 4. Update Firestore
```dart
await _firestore.collection('bills').doc(billId).update({
  'status': 'paid',
  'paidAt': FieldValue.serverTimestamp(),
  'paymentMethod': paymentMethod,
  'transactionId': transactionId,
});
```

## Error Handling

### Scenarios Covered
1. **No user logged in**: Returns empty list
2. **No residentId**: Returns empty list with warning
3. **No bills found**: Shows "No Pending Bills" card
4. **Firestore error**: Shows error widget with message
5. **Network error**: StreamBuilder handles automatically

### Logging
All operations are logged:
```
📋 BillService: Fetching bills by residentId
   residentId: RES001
   ✓ Applied .where("residentId", isEqualTo: "RES001")
✅ BillService: Fetched 3 bills by residentId
```

## Testing

### Test Case 1: Pending Bill Display
1. Create bill document:
   ```javascript
   bills/bill1
   {
     "residentId": "RES001",
     "amount": 5000,
     "status": "pending",
     "month": "January 2024",
     "dueDate": Timestamp,
     "chargeBreakdown": {
       "Maintenance": 2000,
       "Water": 500,
       "Electricity": 1500,
       "Parking": 500,
       "Security": 300,
       "Service": 200
     }
   }
   ```

2. Create user with matching residentId:
   ```javascript
   users/user1
   {
     "name": "Preetham",
     "residentId": "RES001",
     "flatLabel": "t202"
   }
   ```

3. Login and check:
   - ✅ Orange card shows bill amount ₹5000
   - ✅ Due date displays correctly
   - ✅ "Pending" badge shows
   - ✅ "Pay Now" button visible
   - ✅ Breakdown shows all 6 items
   - ✅ Total matches amount

### Test Case 2: Payment History
1. Create paid bill:
   ```javascript
   bills/bill2
   {
     "residentId": "RES001",
     "amount": 4500,
     "status": "paid",
     "month": "December 2023",
     "paidAt": Timestamp,
     "paymentMethod": "UPI",
     "transactionId": "TXN123456"
   }
   ```

2. Check:
   - ✅ Appears in Payment History section
   - ✅ Shows green checkmark icon
   - ✅ Displays paid date
   - ✅ Shows amount
   - ✅ "Receipt" button works

### Test Case 3: No Bills
1. User has no bills in Firestore
2. Check:
   - ✅ Shows "No Pending Bills" card
   - ✅ Shows "No Payment History" card
   - ✅ No errors in console

### Test Case 4: Real-Time Updates
1. Open billing screen
2. Admin adds new bill in Firestore
3. Check:
   - ✅ New bill appears automatically
   - ✅ No page refresh needed
   - ✅ UI updates smoothly

### Test Case 5: Pay Bill
1. Click "Pay Now" on pending bill
2. Select payment method (UPI)
3. Check:
   - ✅ Bill status updates to "paid"
   - ✅ Moves from current bill to payment history
   - ✅ Success message shows
   - ✅ UI updates automatically

## Files Involved
1. `lib/maintenance_billing_screen.dart` - Main screen UI
2. `lib/src/services/bill_firestore_service.dart` - Data fetching service
3. `lib/receipt_screen.dart` - Receipt display
4. `lib/payment_method_modal.dart` - Payment method selection

## Status
✅ **COMPLETE** - Billing screen properly fetches and displays data from Firestore bills collection with:
- Real-time streaming
- Dual authentication support
- Proper error handling
- Performance optimizations
- Complete payment flow

## Next Steps
1. Test with real Firestore data
2. Verify residentId is set for all users
3. Ensure bills have correct residentId
4. Test payment flow end-to-end
5. Verify real-time updates work correctly
