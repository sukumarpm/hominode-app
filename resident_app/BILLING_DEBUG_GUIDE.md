# Billing Data Fetch - Debug Guide

## Issue
Billing data is not fetching and displaying according to the flow function.

## Flow Function (Expected)

```
1. Get Current User ID (Firebase Auth)
   ↓
2. Query Flats Collection
   WHERE residentIds ARRAY_CONTAINS userId
   ↓
3. Get Flat ID
   ↓
4. Query Bills Collection
   WHERE flatId == flatId
   ↓
5. Display Bills
```

## Debug Steps

### Step 1: Run Test Utility

Add this to your main navigation to access the test screen:

```dart
// In your app, add a way to navigate to:
import 'test_billing_fetch.dart';

// Navigate to:
Navigator.push(
  context,
  MaterialPageRoute(builder: (context) => TestBillingFetch()),
);
```

Or add a temporary button in the Maintenance & Billing screen:

```dart
// Add this button temporarily
ElevatedButton(
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => TestBillingFetch()),
    );
  },
  child: Text('Debug Billing'),
)
```

### Step 2: Check Console Logs

The service now logs detailed information:

```
🔍 Fetching flat for user: [userId]
✅ Found flat ID: [flatId]
📋 Fetching bills for flat: [flatId]
✅ Fetched [count] bills for flat: [flatId]
```

Or error messages:

```
❌ No user logged in
⚠️ No flat found for user: [userId]
❌ Cannot fetch bills: No flat assigned to user
❌ Error fetching bills: [error]
```

### Step 3: Verify Firestore Data Structure

#### Check Users Collection
```
users/
  {userId}/
    fullName: "John Doe"
    email: "john@example.com"
    role: "resident"
    ...
```

#### Check Flats Collection
```
flats/
  {flatId}/
    flatNumber: "A-101"
    buildingId: "building123"
    residentIds: ["userId1", "userId2"]  ← MUST contain your userId
    ...
```

#### Check Bills Collection
```
bills/
  {billId}/
    flatId: "flatId123"  ← MUST match the flat ID from step 2
    amount: 5000
    status: "pending"
    month: "January 2024"
    dueDate: Timestamp
    maintenanceCharge: 3000
    waterCharge: 500
    parkingCharge: 1000
    serviceCharge: 500
    ...
```

## Common Issues & Solutions

### Issue 1: No Flat Found
**Symptom**: Log shows "No flat found for user"

**Cause**: User is not assigned to any flat

**Solution**:
1. Go to Firestore Console
2. Open `flats` collection
3. Find or create a flat document
4. Add your user ID to the `residentIds` array:
   ```json
   {
     "flatNumber": "A-101",
     "buildingId": "building123",
     "residentIds": ["YOUR_USER_ID_HERE"]
   }
   ```

### Issue 2: No Bills Found
**Symptom**: Flat is found but no bills display

**Cause**: No bills exist for this flat, or flatId doesn't match

**Solution**:
1. Go to Firestore Console
2. Open `bills` collection
3. Create a bill document with the correct flatId:
   ```json
   {
     "flatId": "YOUR_FLAT_ID_HERE",
     "amount": 5000,
     "status": "pending",
     "month": "January 2024",
     "dueDate": "2024-01-31T00:00:00Z",
     "maintenanceCharge": 3000,
     "waterCharge": 500,
     "parkingCharge": 1000,
     "serviceCharge": 500,
     "createdAt": "2024-01-01T00:00:00Z",
     "updatedAt": "2024-01-01T00:00:00Z"
   }
   ```

### Issue 3: Wrong flatId in Bills
**Symptom**: Flat found, bills exist, but still not showing

**Cause**: Bills have wrong flatId

**Solution**:
1. Get your flat ID from the test utility or console logs
2. Update all bills to use the correct flatId
3. Ensure flatId in bills matches the flat document ID (not flatNumber)

### Issue 4: User Not Logged In
**Symptom**: Log shows "No user logged in"

**Cause**: Firebase Auth session expired or user not authenticated

**Solution**:
1. Log out and log back in
2. Check Firebase Auth console to verify user exists
3. Ensure Firebase Auth is properly initialized

## Manual Data Setup (For Testing)

### 1. Create a Test Flat

In Firestore Console:
```
Collection: flats
Document ID: (auto-generate or use "flat_test_001")

Data:
{
  "flatNumber": "A-101",
  "buildingId": "building_001",
  "residentIds": ["YOUR_USER_ID"],
  "floor": 1,
  "bhk": 2,
  "area": 1000,
  "status": "occupied",
  "createdAt": (current timestamp),
  "updatedAt": (current timestamp)
}
```

### 2. Create Test Bills

In Firestore Console:
```
Collection: bills
Document ID: (auto-generate)

Pending Bill:
{
  "flatId": "flat_test_001",
  "amount": 5000,
  "status": "pending",
  "month": "February 2024",
  "dueDate": (timestamp: 2024-02-28),
  "maintenanceCharge": 3000,
  "waterCharge": 500,
  "parkingCharge": 1000,
  "serviceCharge": 500,
  "createdAt": (current timestamp),
  "updatedAt": (current timestamp)
}

Paid Bill (for history):
{
  "flatId": "flat_test_001",
  "amount": 4800,
  "status": "paid",
  "month": "January 2024",
  "dueDate": (timestamp: 2024-01-31),
  "paidAt": (timestamp: 2024-01-25),
  "paymentMethod": "UPI",
  "transactionId": "TXN123456789",
  "maintenanceCharge": 3000,
  "waterCharge": 500,
  "parkingCharge": 800,
  "serviceCharge": 500,
  "createdAt": (timestamp: 2024-01-01),
  "updatedAt": (timestamp: 2024-01-25)
}
```

## Firestore Security Rules

Ensure your security rules allow reading bills:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Flats - residents can read their own flat
    match /flats/{flatId} {
      allow read: if request.auth != null && 
                     request.auth.uid in resource.data.residentIds;
    }
    
    // Bills - residents can read bills for their flat
    match /bills/{billId} {
      allow read: if request.auth != null && 
                     exists(/databases/$(database)/documents/flats/$(resource.data.flatId)) &&
                     request.auth.uid in get(/databases/$(database)/documents/flats/$(resource.data.flatId)).data.residentIds;
    }
  }
}
```

## Quick Test Checklist

- [ ] User is logged in (check Firebase Auth)
- [ ] User document exists in `users` collection
- [ ] Flat document exists in `flats` collection
- [ ] User ID is in flat's `residentIds` array
- [ ] Bill documents exist in `bills` collection
- [ ] Bills have correct `flatId` matching the flat document ID
- [ ] Firestore security rules allow reading
- [ ] No console errors in Flutter app
- [ ] Test utility shows all steps passing

## Expected Test Output

```
=== BILLING FLOW TEST ===

✅ Step 1: Current User
   User ID: abc123xyz
   Email: john@example.com

✅ Step 2: User document exists
   Data: {fullName: John Doe, email: john@example.com, ...}

✅ Step 3: Finding flat assignment...
   Query: flats WHERE residentIds CONTAINS abc123xyz
✅ Flat found!
   Flat ID: flat_test_001
   Flat Number: A-101
   Building ID: building_001
   Resident IDs: [abc123xyz]

✅ Step 4: Querying bills...
   Query: bills WHERE flatId == flat_test_001
   Found 2 bills

✅ Bills found!

📄 Bill ID: bill_001
   Flat ID: flat_test_001
   Amount: ₹5000
   Status: pending
   Month: February 2024
   ...

📄 Bill ID: bill_002
   Flat ID: flat_test_001
   Amount: ₹4800
   Status: paid
   Month: January 2024
   ...

📊 Summary:
   Total bills: 2
   Pending bills: 1
   Paid bills: 1

=== TEST COMPLETE ===
```

## Next Steps After Fixing

1. Remove test utility button
2. Test with real data
3. Verify payment flow works
4. Test with multiple residents in same flat
5. Test with no pending bills scenario

---

**Created**: 2024
**Purpose**: Debug billing data fetch issues
**Status**: Active debugging tool
