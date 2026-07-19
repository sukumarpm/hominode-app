# Test Billing Data - Quick Start

## 🚀 Quick Test

1. **Run the app**
2. **Login** with your test account
3. **Navigate** to Maintenance & Billing screen
4. **Click** "Debug Billing Data" button
5. **Press** "Run Billing Flow Test"
6. **Read** the console output

## 📋 What the Test Shows

The test will show you:
- ✅ Current user ID and email
- ✅ Whether user document exists
- ✅ Which flat the user is assigned to
- ✅ All bills for that flat
- ❌ Any errors in the flow

## 🔧 Common Fixes

### Fix 1: User Not Assigned to Flat

**If you see**: "No flat found for user"

**Do this in Firestore Console**:
1. Go to `flats` collection
2. Open any flat document (or create one)
3. Add field `residentIds` (type: array)
4. Add your user ID to the array

Example:
```json
{
  "flatNumber": "A-101",
  "buildingId": "building_001",
  "residentIds": ["YOUR_USER_ID_FROM_TEST"]
}
```

### Fix 2: No Bills Exist

**If you see**: "No bills found for this flat"

**Do this in Firestore Console**:
1. Go to `bills` collection
2. Click "Add document"
3. Use the flat ID from the test output
4. Add this data:

```json
{
  "flatId": "YOUR_FLAT_ID_FROM_TEST",
  "amount": 5000,
  "status": "pending",
  "month": "February 2024",
  "dueDate": "2024-02-28T00:00:00Z",
  "maintenanceCharge": 3000,
  "waterCharge": 500,
  "parkingCharge": 1000,
  "serviceCharge": 500,
  "createdAt": "2024-02-01T00:00:00Z",
  "updatedAt": "2024-02-01T00:00:00Z"
}
```

### Fix 3: Wrong Flat ID in Bills

**If you see**: Bills exist but not showing

**Do this**:
1. Note the flat ID from test output (e.g., "flat_abc123")
2. Go to `bills` collection
3. Update each bill's `flatId` field to match exactly

## 📊 Expected Success Output

```
=== BILLING FLOW TEST ===

✅ Step 1: Current User
   User ID: abc123xyz
   Email: test@example.com

✅ User document exists

✅ Flat found!
   Flat ID: flat_001
   Flat Number: A-101

✅ Bills found!

📄 Bill ID: bill_001
   Amount: ₹5000
   Status: pending
   Month: February 2024

📊 Summary:
   Total bills: 1
   Pending bills: 1
   Paid bills: 0

=== TEST COMPLETE ===
```

## 🎯 After Fixing

1. Close and reopen the app
2. Go to Maintenance & Billing
3. You should now see your bills!
4. Remove the debug button (optional)

## 📝 Sample Data for Quick Setup

### Create Flat
```
Collection: flats
Document ID: flat_test_001

{
  "flatNumber": "A-101",
  "buildingId": "building_001",
  "residentIds": ["PASTE_YOUR_USER_ID_HERE"],
  "floor": 1,
  "bhk": 2,
  "area": 1000,
  "status": "occupied"
}
```

### Create Pending Bill
```
Collection: bills
Document ID: (auto-generate)

{
  "flatId": "flat_test_001",
  "amount": 5000,
  "status": "pending",
  "month": "February 2024",
  "dueDate": "2024-02-28T00:00:00Z",
  "maintenanceCharge": 3000,
  "waterCharge": 500,
  "parkingCharge": 1000,
  "serviceCharge": 500
}
```

### Create Paid Bill (for history)
```
Collection: bills
Document ID: (auto-generate)

{
  "flatId": "flat_test_001",
  "amount": 4800,
  "status": "paid",
  "month": "January 2024",
  "dueDate": "2024-01-31T00:00:00Z",
  "paidAt": "2024-01-25T10:30:00Z",
  "paymentMethod": "UPI",
  "transactionId": "TXN123456789",
  "maintenanceCharge": 3000,
  "waterCharge": 500,
  "parkingCharge": 800,
  "serviceCharge": 500
}
```

## 🔍 Console Logs to Watch

Look for these in your Flutter console:

**Success**:
```
🔍 Fetching flat for user: abc123
✅ Found flat ID: flat_001
📋 Fetching bills for flat: flat_001
✅ Fetched 2 bills for flat: flat_001
```

**Errors**:
```
❌ No user logged in
⚠️ No flat found for user: abc123
❌ Cannot fetch bills: No flat assigned to user
```

---

**Quick Tip**: Copy your user ID from the test output and paste it directly into Firestore when setting up the flat!
