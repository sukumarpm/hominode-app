# Test Billing Data Fetch - Quick Guide

## Quick Test

### 1. Run the App
```bash
flutter run
```

### 2. Login
```
Phone: 7010678124
Password: 121456
```

### 3. Navigate to Bills Tab
Tap on "Bills" in the bottom navigation

### 4. Expected Results

#### If Bill Exists for Flat 1202:
```
✅ Current Bill Card shows:
   - Amount: ₹4500
   - Due Date: Feb 28, 2026
   - Month: February
   - Status: Pending
   - "Pay Now" button

✅ Bill Breakdown shows:
   - Electricity: ₹1500
   - Maintenance: ₹1000
   - Water: ₹1000
   - Service: ₹500
   - Parking: ₹250
   - Security: ₹250
   - Total: ₹4500

✅ Payment History (if exists):
   - Shows paid bills
   - Each with "Receipt" button
```

#### If No Bill Exists:
```
ℹ️ Shows "No Pending Bills"
ℹ️ Shows "You're all caught up!"
```

---

## Console Logs to Watch

### Success
```
🔍 Fetching flat for user: <userId>
✅ Found flat ID: 1202
📋 Fetching pending bills for flat: 1202
✅ Found current bill: <billId> for flat: 1202
📋 Fetching payment history for flat: 1202
✅ Fetched X payment history records for flat: 1202
```

### No Bills
```
🔍 Fetching flat for user: <userId>
✅ Found flat ID: 1202
📋 Fetching pending bills for flat: 1202
ℹ️ No pending bills found for flat: 1202
```

### No Flat Assigned
```
🔍 Fetching flat for user: <userId>
⚠️ No flat assigned to user: <userId>
❌ Cannot fetch bills: No flat assigned to user
```

---

## Test Payment Flow

### 1. Click "Pay Now"
- Payment method modal appears

### 2. Select Payment Method
- UPI
- Card
- Net Banking

### 3. Confirm Payment
- Success message appears
- Bill moves to payment history
- Receipt becomes available

### 4. View Receipt
- Click "Receipt" button
- Receipt screen opens
- Shows all bill details
- Can download/share

---

## Verify Firestore Data

### Check User Document
```
Collection: users
Document ID: <userId>

Required Fields:
✅ flatId: "1202"
✅ flatLabel: "1202"
✅ residentId: "RES68429"
✅ name: "Preetham"
```

### Check Bill Document
```
Collection: bills
Document ID: <billId>

Required Fields:
✅ flatId: "1202"
✅ amount: 4500
✅ status: "pending"
✅ month: "February"
✅ dueDate: Timestamp
✅ chargeBreakdown: {
     Electricity: 1500,
     Maintenance: 1000,
     Water: 1000,
     Service: 500,
     Parking: 250,
     Security: 250
   }
```

---

## Test Scenarios

### Scenario 1: User with Pending Bill ✅
```
User: Preetham
Flat: 1202
Bill Status: pending

Expected:
✅ Shows current bill card
✅ Shows bill breakdown
✅ Shows "Pay Now" button
✅ Can pay bill
✅ Bill moves to history after payment
```

### Scenario 2: User with No Bills ℹ️
```
User: John
Flat: 1203
Bill Status: none

Expected:
ℹ️ Shows "No Pending Bills"
ℹ️ Shows "You're all caught up!"
ℹ️ No breakdown card
ℹ️ No payment history
```

### Scenario 3: User without Flat ❌
```
User: Jane
Flat: null
Bill Status: N/A

Expected:
❌ Shows "No Pending Bills"
❌ Console shows "No flat assigned"
❌ No data fetched
```

---

## Breakdown Display Test

### Test 1: All Charges Present
```
Bill has all charges:
✅ Electricity: ₹1500
✅ Maintenance: ₹1000
✅ Water: ₹1000
✅ Service: ₹500
✅ Parking: ₹250
✅ Security: ₹250

Expected:
✅ All 6 items displayed
✅ Total: ₹4500
```

### Test 2: Some Charges Zero
```
Bill has:
✅ Maintenance: ₹1000
✅ Water: ₹500
❌ Electricity: 0
❌ Service: 0
❌ Parking: 0
❌ Security: 0

Expected:
✅ Only 2 items displayed (Maintenance, Water)
✅ Total: ₹1500
❌ Zero charges not shown
```

### Test 3: No Breakdown
```
Bill has no chargeBreakdown field

Expected:
ℹ️ Shows "No breakdown available"
✅ Still shows total amount
```

---

## Receipt Test

### 1. Pay a Bill
- Click "Pay Now"
- Select payment method
- Confirm payment

### 2. View Receipt
- Go to payment history
- Click "Receipt" button
- Receipt screen opens

### 3. Verify Receipt Contains
```
✅ Transaction ID
✅ Date & Time
✅ Resident Name: Preetham
✅ Flat Number: 1202
✅ Payment Method: UPI/Card/Net Banking
✅ Bill Period: February
✅ Bill Breakdown (all charges)
✅ Total Amount: ₹4500
✅ QR Code
✅ Society Details
```

### 4. Test Receipt Actions
```
✅ Download PDF
✅ Share via apps
✅ View in PDF viewer
```

---

## Troubleshooting

### Bills Not Showing
1. Check user has `flatId` in Firestore
2. Check bills exist with matching `flatId`
3. Check console logs for errors
4. Verify Firestore rules allow read access

### Breakdown Not Showing
1. Check bill has `chargeBreakdown` field
2. Check field names match exactly (case-sensitive)
3. Check values are numbers, not strings
4. Check at least one charge > 0

### Payment Not Working
1. Check bill has `id` field
2. Check user is authenticated
3. Check Firestore rules allow write access
4. Check console logs for errors

---

## Quick Commands

### Check User Flat
```dart
final userDoc = await FirebaseFirestore.instance
    .collection('users')
    .doc(userId)
    .get();
print('User flatId: ${userDoc.data()?['flatId']}');
```

### Check Bills
```dart
final bills = await FirebaseFirestore.instance
    .collection('bills')
    .where('flatId', isEqualTo: '1202')
    .get();
print('Bills found: ${bills.docs.length}');
bills.docs.forEach((doc) {
  print('Bill: ${doc.id}');
  print('  Amount: ${doc.data()['amount']}');
  print('  Status: ${doc.data()['status']}');
});
```

### Check Breakdown
```dart
final bill = await FirebaseFirestore.instance
    .collection('bills')
    .doc(billId)
    .get();
final breakdown = bill.data()?['chargeBreakdown'];
print('Breakdown: $breakdown');
```

---

## Success Criteria

✅ Bills fetch from Firestore
✅ Bill breakdown displays correctly
✅ Only non-zero charges shown
✅ Total amount matches
✅ Payment flow works
✅ Receipt generates correctly
✅ Payment history shows paid bills
✅ Console logs show correct data

---

**Status**: Ready for Testing
**Duration**: 10-15 minutes
**Priority**: HIGH
