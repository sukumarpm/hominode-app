# Billing Not Fetching - Complete Fix Guide

## Problem

Billing data is not fetching properly from Firestore according to the flow function.

## Root Causes & Solutions

### Cause 1: User Document Missing flatId ❌

**Check**:
```
1. Open Firebase Console
2. Go to Firestore Database
3. Navigate to: users > <your-user-id>
4. Look for 'flatId' field
```

**If Missing or Empty**:
```
Add field:
- Field name: flatId
- Field type: string
- Field value: "1202" (or your flat number)

Also add:
- flatLabel: "1202"
```

**Console Log Pattern**:
```
⚠️ No flat assigned to user: <userId>
❌ Cannot fetch bills: No flat assigned to user
```

---

### Cause 2: Bill Document Missing or Wrong flatId ❌

**Check**:
```
1. Open Firebase Console
2. Go to Firestore Database
3. Navigate to: bills collection
4. Check if bills exist
5. Check if bill's flatId matches user's flatId
```

**If No Bills Exist**:
Create a test bill:
```json
{
  "amount": 4500,
  "chargeBreakdown": {
    "Electricity": 1500,
    "Maintenance": 1000,
    "Water": 1000,
    "Service": 500,
    "Parking": 250,
    "Security": 250
  },
  "createdAt": "2026-02-23T15:55:40.000Z",
  "dueDate": "2026-02-28T00:00:00.000Z",
  "flatId": "1202",
  "flatLabel": "1202",
  "month": "February",
  "residentId": "RES68429",
  "residentName": "Preetham",
  "status": "pending",
  "type": "combined",
  "updatedAt": "2026-02-23T15:55:40.000Z",
  "year": "2026"
}
```

**If flatId Mismatch**:
```
User flatId: "1202"
Bill flatId: "1203"  ← WRONG!

Fix: Update bill's flatId to match user's flatId
```

**Console Log Pattern**:
```
✅ Found flat ID: 1202
📋 Fetching pending bills for flat: 1202
   Query result: 0 documents
ℹ️ No pending bills found for flat: 1202
   Debug: Total bills for flat 1202: 0
```

---

### Cause 3: Bill Status Not "pending" ❌

**Check**:
```
1. Open bill document in Firestore
2. Check 'status' field
3. Should be: "pending" (lowercase)
```

**If Wrong Status**:
```
Wrong: "Pending", "PENDING", "paid", "overdue"
Correct: "pending"

Fix: Update status field to "pending"
```

**Console Log Pattern**:
```
✅ Found flat ID: 1202
📋 Fetching pending bills for flat: 1202
   Query result: 0 documents
   Debug: Total bills for flat 1202: 1
   Debug: Bill statuses:
      - bill123: status = paid  ← Not "pending"
```

---

### Cause 4: Firestore Rules Blocking Access ❌

**Check**:
```
1. Open Firebase Console
2. Go to Firestore Database
3. Click "Rules" tab
4. Check if rules allow read access
```

**Temporary Fix** (Development Only):
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

**Console Log Pattern**:
```
❌ Error fetching current bill: [cloud_firestore/permission-denied]
```

---

## Step-by-Step Fix

### Step 1: Verify User Has FlatId

```bash
# Run this in your app or Firebase Console
1. Login to app
2. Check console logs for:
   "🔍 Fetching flat for user: <userId>"
   "✅ Found flat ID: 1202"

# If you see "⚠️ No flat assigned to user"
# Then add flatId to user document
```

### Step 2: Verify Bill Exists

```bash
# In Firebase Console:
1. Go to Firestore > bills collection
2. Look for document with:
   - flatId: "1202" (matches user's flatId)
   - status: "pending"
   - amount: 4500
   - chargeBreakdown: { ... }

# If no bill exists, create one using the JSON above
```

### Step 3: Test the Fix

```bash
# Run the app
flutter run

# Login
Phone: 7010678124
Password: 121456

# Navigate to Bills tab
# Check console logs

# Expected logs:
🔍 Fetching flat for user: <userId>
✅ Found flat ID: 1202
📋 Fetching pending bills for flat: 1202
   Query: bills WHERE flatId == "1202" AND status == "pending"
   Query result: 1 documents
✅ Found current bill: <billId> for flat: 1202
   Amount: 4500
   Month: February
   Status: pending
   Has chargeBreakdown: true
```

---

## Quick Test Script

Add this button to your app temporarily:

```dart
// In maintenance_billing_screen.dart
FloatingActionButton(
  onPressed: () async {
    print('═══ MANUAL BILLING TEST ═══');
    
    // Test 1: Check user
    final user = FirebaseAuth.instance.currentUser;
    print('User: ${user?.uid}');
    
    // Test 2: Get user doc
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user?.uid)
        .get();
    print('User flatId: ${userDoc.data()?['flatId']}');
    
    // Test 3: Query bills
    final flatId = userDoc.data()?['flatId'];
    final bills = await FirebaseFirestore.instance
        .collection('bills')
        .where('flatId', isEqualTo: flatId)
        .get();
    print('Bills found: ${bills.docs.length}');
    
    // Test 4: Check pending
    final pending = bills.docs
        .where((d) => d.data()['status'] == 'pending')
        .toList();
    print('Pending bills: ${pending.length}');
    
    if (pending.isNotEmpty) {
      final bill = pending.first.data();
      print('Bill amount: ${bill['amount']}');
      print('Bill month: ${bill['month']}');
      print('Has breakdown: ${bill.containsKey('chargeBreakdown')}');
    }
  },
  child: Icon(Icons.bug_report),
)
```

---

## Expected Firestore Structure

### User Document
```
Collection: users
Document ID: <Firebase Auth UID>

Required Fields:
{
  "uid": "<same as document ID>",
  "name": "Preetham",
  "email": "user@example.com",
  "phone": "7010678124",
  "flatId": "1202",           ← MUST EXIST
  "flatLabel": "1202",
  "residentId": "RES68429",
  "role": "resident",
  "status": "active"
}
```

### Bill Document
```
Collection: bills
Document ID: <auto-generated>

Required Fields:
{
  "flatId": "1202",           ← MUST MATCH user's flatId
  "flatLabel": "1202",
  "amount": 4500,
  "status": "pending",        ← MUST BE "pending" (lowercase)
  "month": "February",
  "year": "2026",
  "dueDate": Timestamp,
  "residentName": "Preetham",
  "residentId": "RES68429",
  "type": "combined",
  "chargeBreakdown": {        ← MUST EXIST for breakdown display
    "Electricity": 1500,
    "Maintenance": 1000,
    "Water": 1000,
    "Service": 500,
    "Parking": 250,
    "Security": 250
  },
  "createdAt": Timestamp,
  "updatedAt": Timestamp
}
```

---

## Verification Checklist

Before testing, verify:

- [ ] User document exists in Firestore
- [ ] User document has `flatId` field (not empty)
- [ ] Bill document exists in Firestore
- [ ] Bill's `flatId` matches user's `flatId` EXACTLY
- [ ] Bill's `status` is "pending" (lowercase)
- [ ] Bill has `chargeBreakdown` field
- [ ] Bill has `amount` field
- [ ] Firestore rules allow read access
- [ ] User is logged in (Firebase Auth)
- [ ] Internet connection is working

---

## Console Log Decoder

### ✅ Success Pattern
```
🔍 Fetching flat for user: abc123
✅ Found flat ID: 1202
📋 Fetching pending bills for flat: 1202
   Query: bills WHERE flatId == "1202" AND status == "pending"
   Query result: 1 documents
✅ Found current bill: xyz789 for flat: 1202
   Amount: 4500
   Month: February
   Status: pending
   Has chargeBreakdown: true
```
**Meaning**: Everything working correctly!

### ❌ No FlatId Pattern
```
🔍 Fetching flat for user: abc123
⚠️ No flat assigned to user: abc123
❌ Cannot fetch bills: No flat assigned to user
```
**Fix**: Add `flatId` to user document

### ❌ No Bills Pattern
```
✅ Found flat ID: 1202
📋 Fetching pending bills for flat: 1202
   Query result: 0 documents
ℹ️ No pending bills found for flat: 1202
   Debug: Total bills for flat 1202: 0
```
**Fix**: Create bill document with matching `flatId`

### ❌ Wrong Status Pattern
```
✅ Found flat ID: 1202
📋 Fetching pending bills for flat: 1202
   Query result: 0 documents
   Debug: Total bills for flat 1202: 1
   Debug: Bill statuses:
      - xyz789: status = paid
```
**Fix**: Change bill status to "pending"

---

## Still Not Working?

### Run Full Debug

1. Use the debug script: `lib/test_billing_debug.dart`
2. Check ALL console output
3. Compare with expected patterns above
4. Identify which step is failing
5. Apply the specific fix

### Check Firestore Indexes

```
1. Open Firebase Console
2. Go to Firestore Database
3. Click "Indexes" tab
4. Check if composite index exists for:
   - Collection: bills
   - Fields: flatId (Ascending), status (Ascending)
```

### Verify Data Types

```
In Firestore Console, check:
- flatId: Must be String, not Number
- amount: Must be Number, not String
- status: Must be String "pending", not Boolean
- chargeBreakdown: Must be Map, not Array
```

---

## Summary

The billing fetch works by:
1. Getting user's `flatId` from user document
2. Querying bills WHERE `flatId` == user's flatId AND `status` == "pending"
3. Displaying the bill with breakdown

If any step fails, check the corresponding section above.

---

**Status**: Troubleshooting Guide
**Priority**: HIGH
**Action**: Follow steps above to identify and fix the issue
