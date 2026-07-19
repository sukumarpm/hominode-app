# Fix Billing Fetch - Action Plan

## Current Issue

Billing data not fetching properly from Firestore.

## Immediate Actions

### Action 1: Check Console Logs (2 minutes)

```bash
# Run the app
flutter run

# Login and go to Bills tab
# Watch console output

# Look for these messages:
🔍 Fetching flat for user: <userId>
✅ Found flat ID: <flatId>
📋 Fetching pending bills for flat: <flatId>
```

**If you see**: `⚠️ No flat assigned to user`
→ Go to Action 2

**If you see**: `ℹ️ No pending bills found`
→ Go to Action 3

---

### Action 2: Add FlatId to User (5 minutes)

```
1. Open Firebase Console
   https://console.firebase.google.com

2. Select your project: lyvo-app

3. Go to: Firestore Database

4. Navigate to: users collection

5. Find your user document (use phone: 7010678124)

6. Click "Edit"

7. Add field:
   Field name: flatId
   Field type: string
   Field value: 1202

8. Also add:
   Field name: flatLabel
   Field type: string
   Field value: 1202

9. Click "Update"

10. Restart app and test
```

---

### Action 3: Create Test Bill (10 minutes)

```
1. Open Firebase Console

2. Go to: Firestore Database

3. Navigate to: bills collection

4. Click "Add document"

5. Auto-generate document ID

6. Add these fields:

   amount (number): 4500
   
   chargeBreakdown (map):
     Electricity (number): 1500
     Maintenance (number): 1000
     Water (number): 1000
     Service (number): 500
     Parking (number): 250
     Security (number): 250
   
   createdAt (timestamp): <select current date/time>
   
   dueDate (timestamp): <select future date>
   
   flatId (string): 1202
   
   flatLabel (string): 1202
   
   month (string): February
   
   residentId (string): RES68429
   
   residentName (string): Preetham
   
   status (string): pending
   
   type (string): combined
   
   updatedAt (timestamp): <select current date/time>
   
   year (string): 2026

7. Click "Save"

8. Restart app and test
```

---

### Action 4: Verify Match (2 minutes)

```
Check that:
1. User's flatId = "1202"
2. Bill's flatId = "1202"
3. They match EXACTLY (case-sensitive)

If they don't match:
- Update bill's flatId to match user's flatId
```

---

## Quick Verification

After completing actions above, run app and check:

### Expected Screen:
```
✅ Current Bill Card shows:
   - Amount: ₹4500
   - Due Date: Feb 28, 2026
   - Month: February
   - Status: Pending

✅ Bill Breakdown shows:
   - Electricity: ₹1500
   - Maintenance: ₹1000
   - Water: ₹1000
   - Service: ₹500
   - Parking: ₹250
   - Security: ₹250
   - Total: ₹4500
```

### Expected Console:
```
🔍 Fetching flat for user: <userId>
✅ Found flat ID: 1202
📋 Fetching pending bills for flat: 1202
   Query result: 1 documents
✅ Found current bill: <billId> for flat: 1202
   Amount: 4500
   Month: February
   Status: pending
   Has chargeBreakdown: true
```

---

## Still Not Working?

### Debug Script

Run this to see detailed information:

```bash
# Add to your app temporarily
import 'lib/test_billing_debug.dart';

// Call in a button or on screen load
await testBillingFetch();

# Check console output for detailed debug info
```

### Common Issues

**Issue**: "No user logged in"
**Fix**: Login first with phone: 7010678124, password: 121456

**Issue**: "User document not found"
**Fix**: Ensure user exists in Firestore users collection

**Issue**: "Permission denied"
**Fix**: Update Firestore rules to allow read access

---

## Documentation

📄 **Complete Fix Guide**: `BILLING_NOT_FETCHING_FIX.md`
📄 **Debug Guide**: `BILLING_DEBUG_NOW.md`
📄 **Test Guide**: `TEST_BILLING_FIRESTORE.md`

---

## Summary

1. ✅ Check console logs
2. ✅ Add flatId to user if missing
3. ✅ Create test bill if none exists
4. ✅ Verify flatId matches
5. ✅ Test and verify

**Time Required**: 15-20 minutes
**Priority**: HIGH
**Status**: Action Required
