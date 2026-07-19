# Billing Data Setup - Quick Fix

## Problem
The Maintenance & Billing screen shows "No Pending Bills" because there's no data in Firestore yet.

## Solution - 2 Options

### Option 1: Use the App (Easiest) ⭐

1. **Open the app** and login
2. **Go to** Maintenance & Billing screen
3. **Click** "Create Test Data" button (green button)
4. **Wait** for success message
5. **Go back** to Maintenance & Billing screen
6. **See your bills!** ✅

### Option 2: Manual Setup in Firestore Console

#### Step 1: Get Your User ID
1. Click "Debug" button in the app
2. Press "Run Billing Flow Test"
3. Copy your User ID from the output

#### Step 2: Create Flat
In Firestore Console:
```
Collection: flats
Click "Add document"

Document ID: (auto-generate)

Fields:
- flatNumber (string): "A-101"
- buildingId (string): "building_001"
- residentIds (array): [PASTE_YOUR_USER_ID_HERE]
- floor (number): 1
- bhk (number): 2
- area (number): 1000
- status (string): "occupied"
```

#### Step 3: Create Pending Bill
In Firestore Console:
```
Collection: bills
Click "Add document"

Document ID: (auto-generate)

Fields:
- flatId (string): PASTE_FLAT_ID_FROM_STEP_2
- amount (number): 5000
- status (string): "pending"
- month (string): "February 2024"
- dueDate (timestamp): 2024-02-28 00:00:00
- maintenanceCharge (number): 3000
- waterCharge (number): 500
- parkingCharge (number): 1000
- serviceCharge (number): 500
```

#### Step 4: Create Paid Bill (Optional - for history)
In Firestore Console:
```
Collection: bills
Click "Add document"

Document ID: (auto-generate)

Fields:
- flatId (string): SAME_FLAT_ID_FROM_STEP_2
- amount (number): 4800
- status (string): "paid"
- month (string): "January 2024"
- dueDate (timestamp): 2024-01-31 00:00:00
- paidAt (timestamp): 2024-01-25 10:30:00
- paymentMethod (string): "UPI"
- transactionId (string): "TXN123456789"
- maintenanceCharge (number): 3000
- waterCharge (number): 500
- parkingCharge (number): 800
- serviceCharge (number): 500
```

## What You'll See After Setup

### Current Bill Card (Orange)
- Amount: ₹5000
- Status: Pending
- Month: February 2024
- Due Date: Feb 28, 2024
- "Pay Now" button

### Bill Breakdown
- Maintenance Charge: ₹3000
- Water Charge: ₹500
- Parking Charge: ₹1000
- Service Charge: ₹500
- Total: ₹5000

### Payment History
- January 2024: ₹4800 (Paid)
- Receipt download button

## Flow Function (How It Works)

```
1. Get Current User ID
   ↓
2. Find Flat (WHERE residentIds CONTAINS userId)
   ↓
3. Get Flat ID
   ↓
4. Fetch Bills (WHERE flatId == flatId)
   ↓
5. Display in UI
```

## Verification

After setup, check console logs:
```
🔍 Fetching flat for user: [your-user-id]
✅ Found flat ID: [flat-id]
📋 Fetching bills for flat: [flat-id]
✅ Fetched 1 bills for flat: [flat-id]
📋 Fetching payment history for flat: [flat-id]
✅ Fetched 1 payment history records for flat: [flat-id]
```

## Troubleshooting

### Still showing "No Pending Bills"?

1. **Check console logs** - Look for error messages
2. **Run Debug** - Click "Debug" button to see what's missing
3. **Verify User ID** - Make sure it's in the flat's residentIds array
4. **Verify Flat ID** - Make sure bills have the correct flatId
5. **Restart app** - Close and reopen the app

### Common Mistakes

❌ **Wrong**: Using flatNumber in bills
```json
{"flatId": "A-101"}  // This is wrong!
```

✅ **Correct**: Using flat document ID
```json
{"flatId": "abc123xyz"}  // This is the document ID
```

❌ **Wrong**: residentIds as string
```json
{"residentIds": "user123"}  // Wrong type!
```

✅ **Correct**: residentIds as array
```json
{"residentIds": ["user123"]}  // Correct!
```

## Quick Commands

### Create Test Data (Recommended)
1. Open app
2. Go to Maintenance & Billing
3. Click "Create Test Data"
4. Done! ✅

### Debug Data
1. Open app
2. Go to Maintenance & Billing
3. Click "Debug"
4. Press "Run Billing Flow Test"
5. Read the output

## Expected Result

After setup, your Maintenance & Billing screen should show:
- ✅ Orange card with pending bill (₹5000)
- ✅ Bill breakdown with all charges
- ✅ "Pay Now" button
- ✅ Payment history section with paid bills
- ✅ Receipt download buttons

## Remove Debug Buttons (Optional)

Once everything works, you can remove the debug buttons by commenting out these lines in `maintenance_billing_screen.dart`:

```dart
// Comment out or remove this section:
Row(
  children: [
    // Debug button
    // Create Test Data button
  ],
),
```

---

**Recommendation**: Use Option 1 (Create Test Data button) - it's the fastest and easiest way!

**Status**: Ready to use
**Time**: < 1 minute with Option 1
