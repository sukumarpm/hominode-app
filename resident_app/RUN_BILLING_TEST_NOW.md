# Run Billing Test - Step by Step Guide

## Current Situation

Based on your Firestore screenshots:
- ✅ Bill exists in Firestore (ID: `dKoTQtdVuiNkBqLWZmQP`)
- ✅ FlatId: `"1202"`
- ✅ Amount: `6000`
- ✅ Status: `"pending"`
- ✅ ChargeBreakdown exists
- ❌ App shows "No Pending Bills"

## Test Method 1: Run Main App with Console Logs

### Step 1: Run the App
```bash
cd resident_app
flutter run
```

### Step 2: Login
```
Phone: 7010678124
Password: 121456
```

### Step 3: Navigate to Bills Tab
Tap on "Bills" in the bottom navigation bar

### Step 4: Check Console Output

Look for these log messages in your console:

#### ✅ SUCCESS PATTERN (Everything Working):
```
🔍 BillService: Fetching flat for user: <userId>
✅ BillService: Found flat ID: 1202
📋 BillService: Fetching pending bills for flat: 1202
   Collection: bills
   Query: WHERE flatId == "1202" AND status == "pending"
   Query result: 1 documents
✅ BillService: Found current bill: dKoTQtdVuiNkBqLWZmQP
   FlatId: 1202
   Amount: 6000
   Month: February
   Status: pending
   Has chargeBreakdown: true
```

#### ❌ PROBLEM PATTERN 1 (No FlatId in User):
```
🔍 BillService: Fetching flat for user: <userId>
⚠️ BillService: No flat assigned to user
   User data: [uid, name, email, phone, ...]
❌ BillService: Cannot fetch bills - No flat assigned
```

**FIX**: Add `flatId` field to user document in Firebase Console

#### ❌ PROBLEM PATTERN 2 (FlatId Mismatch):
```
✅ BillService: Found flat ID: 1402
📋 BillService: Fetching pending bills for flat: 1402
   Query result: 0 documents
ℹ️ BillService: No pending bills found for flat: 1402
   Debug: Checking all bills for flat...
   Debug: Total bills for flat 1402: 0
```

**FIX**: User's flatId doesn't match bill's flatId. Update one to match the other.

#### ❌ PROBLEM PATTERN 3 (Wrong Status):
```
✅ BillService: Found flat ID: 1202
📋 BillService: Fetching pending bills for flat: 1202
   Query result: 0 documents
ℹ️ BillService: No pending bills found for flat: 1202
   Debug: Checking all bills for flat...
   Debug: Total bills for flat 1202: 1
   Debug: Bill statuses:
      - dKoTQtdVuiNkBqLWZmQP:
         flatId: 1202
         status: paid  ← Should be "pending"
         amount: 6000
```

**FIX**: Bill status is not "pending". Change it to "pending" in Firebase Console.

---

## Test Method 2: Run Debug Script

### Step 1: Run Debug Script
```bash
cd resident_app
flutter run lib/test_billing_debug.dart
```

This will output detailed information about:
- Current logged-in user
- User's flatId
- All bills for that flatId
- Bill details (amount, status, breakdown)
- Pending bills count
- Paid bills count

### Step 2: Analyze Output

The script will show you exactly what data exists and what might be missing.

---

## Common Issues and Fixes

### Issue 1: User Missing FlatId

**Symptoms**:
```
⚠️ BillService: No flat assigned to user
```

**Fix in Firebase Console**:
1. Go to Firestore Database
2. Navigate to `users` collection
3. Find user with phone `7010678124`
4. Click "Edit"
5. Add field:
   - Name: `flatId`
   - Type: `string`
   - Value: `1202`
6. Also add:
   - Name: `flatLabel`
   - Type: `string`
   - Value: `1202`
7. Click "Update"
8. Restart app

---

### Issue 2: FlatId Mismatch

**Symptoms**:
```
✅ Found flat ID: 1402
📋 Fetching bills for flat: 1402
   Query result: 0 documents
```

But your bill has `flatId: "1202"`

**Fix Option A - Update User's FlatId**:
1. Go to Firestore Database
2. Navigate to `users` collection
3. Find user document
4. Change `flatId` from `1402` to `1202`
5. Change `flatLabel` from `1402` to `1202`
6. Restart app

**Fix Option B - Update Bill's FlatId**:
1. Go to Firestore Database
2. Navigate to `bills` collection
3. Find bill document `dKoTQtdVuiNkBqLWZmQP`
4. Change `flatId` from `1202` to `1402`
5. Change `flatLabel` from `1202` to `1402`
6. Restart app

---

### Issue 3: Bill Status Not "pending"

**Symptoms**:
```
Debug: Bill statuses:
   - dKoTQtdVuiNkBqLWZmQP:
      status: paid  ← Should be "pending"
```

**Fix in Firebase Console**:
1. Go to Firestore Database
2. Navigate to `bills` collection
3. Find bill document `dKoTQtdVuiNkBqLWZmQP`
4. Click "Edit"
5. Change `status` field value to `pending` (lowercase)
6. Click "Update"
7. Restart app

---

### Issue 4: Data Type Mismatch

**Symptoms**:
- Query returns 0 results even though data looks correct

**Check in Firebase Console**:
```
User Document:
✅ flatId: "1202" (String type)

Bill Document:
✅ flatId: "1202" (String type)
✅ status: "pending" (String type)
✅ amount: 6000 (Number type)

❌ Common mistakes:
   - flatId as Number instead of String
   - status with capital letter "Pending" instead of "pending"
   - Extra spaces in values " 1202 " instead of "1202"
```

---

## Verification Checklist

After fixing, verify these in Firebase Console:

### User Document (users collection)
```
Document ID: <Firebase Auth UID>
Fields:
  ✅ flatId: "1202" (string)
  ✅ flatLabel: "1202" (string)
  ✅ name: "Preetham" (string)
  ✅ phone: "7010678124" (string)
  ✅ email: "preethampriyadharshan07@gmail.com" (string)
```

### Bill Document (bills collection)
```
Document ID: dKoTQtdVuiNkBqLWZmQP
Fields:
  ✅ flatId: "1202" (string) - MUST MATCH user's flatId
  ✅ status: "pending" (string) - lowercase
  ✅ amount: 6000 (number)
  ✅ month: "February" (string)
  ✅ year: "2026" (string)
  ✅ chargeBreakdown: (map)
      Electricity: 2000 (number)
      Maintenance: 2000 (number)
      Water: 500 (number)
      Service: 500 (number)
      Parking: 500 (number)
      Security: 500 (number)
  ✅ dueDate: <Timestamp>
```

---

## Expected Result After Fix

### On Screen:
```
┌─────────────────────────────────────────┐
│ February Bill              [Pending]    │
│                                         │
│ ₹6000                                   │
│                                         │
│ Due Date: Feb 28, 2026                  │
│                                         │
│ [        Pay Now        ]               │
└─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│ Bill Breakdown                          │
│                                         │
│ Electricity          ₹2000              │
│ Maintenance          ₹2000              │
│ Water                ₹500               │
│ Service              ₹500               │
│ Parking              ₹500               │
│ Security             ₹500               │
│ ─────────────────────────────────────── │
│ Total Amount         ₹6000              │
└─────────────────────────────────────────┘
```

### In Console:
```
🔍 BillService: Fetching flat for user: <userId>
✅ BillService: Found flat ID: 1202
📋 BillService: Fetching pending bills for flat: 1202
   Collection: bills
   Query: WHERE flatId == "1202" AND status == "pending"
   Query result: 1 documents
✅ BillService: Found current bill: dKoTQtdVuiNkBqLWZmQP
   FlatId: 1202
   Amount: 6000
   Month: February
   Status: pending
   Has chargeBreakdown: true
```

---

## Quick Commands

### Run Main App
```bash
cd resident_app
flutter run
```

### Run Debug Script
```bash
cd resident_app
flutter run lib/test_billing_debug.dart
```

### Clean and Rebuild (if needed)
```bash
cd resident_app
flutter clean
flutter pub get
flutter run
```

---

## Summary

1. ✅ Run the app and check console logs
2. ✅ Identify which pattern matches your issue
3. ✅ Apply the corresponding fix in Firebase Console
4. ✅ Restart app and verify

The console logs will tell you EXACTLY what's wrong. Just match the pattern and apply the fix.

---

**Status**: Ready for Testing
**Priority**: HIGH
**Action**: Run app and check console output
