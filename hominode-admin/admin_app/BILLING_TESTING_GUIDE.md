# Billing System Testing Guide

## Quick Test Steps

### 1. Verify Firestore Data Structure

Check your `users` collection in Firebase Console:

```javascript
users/{documentId} {
  residentId: "RES%16",     // ✅ Required
  name: "sukumar",          // ✅ Required
  flatId: "t401",           // ✅ Required
  flatLabel: "t401",        // ✅ Required
  role: "resident",         // ✅ Required
  email: "sukumar@gmail.com",
  phone: "+91 72003 43219",
  // ... other fields
}
```

### 2. Run the App

```bash
cd admin_app
flutter run
```

### 3. Generate Test Bills

1. Login to admin app
2. Navigate to "Billing & Payments" screen
3. Click "Create Bill" button
4. Fill in the form:
   - **Month & Year**: Select current or next month
   - **Bill Charges**:
     - Maintenance: 5000
     - Water: 500
     - Parking: 1000
     - Service: 300
   - **Due Date**: Select a future date
   - **Apply Bills To**: All Residents
5. Click "Generate Bills"

### 4. Watch Console Output

You should see detailed logs like:

```
🔍 Starting bill generation...
📅 Month: January, Year: 2024
💰 Total Amount: ₹6800
📊 Charge Breakdown: {Maintenance: 5000, Water: 500, Parking: 1000, Service: 300}
🏢 Generating bills for ALL residents
👥 Found 1 residents in users collection

📄 Processing document: 0oLNbxo8GrFzyMCQlo4
   Data: {residentId: RES%16, name: sukumar, email: sukumar@gmail.com, ...}
   residentId: RES%16
   residentName: sukumar
   flatId: t401
   flatLabel: t401
✅ Bill created: bill_abc123 for sukumar (RES%16)
   ✅ SUCCESS: Bill created for sukumar (RES%16) - Flat t401

📊 SUMMARY:
   Total residents found: 1
   Bills created: 1
   Residents skipped: 0
```

### 5. Verify in Firestore

Check the `bills` collection in Firebase Console:

```javascript
bills/{billId} {
  residentId: "RES%16",        // ✅ Should match users.residentId
  residentName: "sukumar",     // ✅ Should match users.name
  flatId: "t401",
  flatLabel: "t401",
  amount: 6800,
  chargeBreakdown: {
    "Maintenance": 5000,
    "Water": 500,
    "Parking": 1000,
    "Service": 300
  },
  month: "January",
  year: "2024",
  type: "combined",
  status: "pending",
  dueDate: Timestamp,
  createdAt: Timestamp,
  updatedAt: Timestamp
}
```

### 6. Check Billing Screen

The bills should now display in the app:

```
┌─────────────────────────────────────┐
│ sukumar                    [Pending]│  ← residentName
│ t401                                │  ← flatLabel
│                                     │
│ Amount: ₹6,800                      │
│ Due Date: 31 Jan 2024               │
└─────────────────────────────────────┘
```

## Troubleshooting

### No Bills Generated

**Console shows:**
```
👥 Found 0 residents in users collection
```

**Solution:**
1. Check Firestore `users` collection
2. Ensure at least one user has:
   - `role: "resident"`
   - `flatId: "t401"` (or any value)
   - `residentId: "RES%16"` (or any value)
   - `name: "sukumar"` (or any value)

### Bills Generated but residentId is null

**Console shows:**
```
📄 Processing document: ...
   residentId: null
   ⚠️ SKIPPED: Missing residentId field
```

**Solution:**
1. Open Firebase Console
2. Go to Firestore Database
3. Open `users` collection
4. Select the resident document
5. Add field: `residentId` with value like "RES%16"

### Bills Generated but residentName is null

**Console shows:**
```
📄 Processing document: ...
   residentName: null
   ⚠️ SKIPPED: Missing name field
```

**Solution:**
1. Open Firebase Console
2. Go to Firestore Database
3. Open `users` collection
4. Select the resident document
5. Add field: `name` with value like "sukumar"

## Success Criteria

✅ Console shows: "Bills created: X" (where X > 0)
✅ Firestore `bills` collection has new documents
✅ Each bill has `residentId` = "RES%16" (or similar)
✅ Each bill has `residentName` = "sukumar" (or similar)
✅ Billing screen displays the bills with resident names
✅ No error messages in console

## Next Steps

Once bills are generated successfully:

1. Test marking bills as paid
2. Test downloading invoices
3. Test sending reminders
4. Test filtering by status
5. Test generating bills for specific units

