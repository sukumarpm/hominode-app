# Run Billing Diagnostic - Find the Issue

## Quick Start

### Step 1: Run Diagnostic App
```bash
cd resident_app
flutter run lib/diagnose_billing_now.dart
```

### Step 2: Click "Run Diagnostic" Button

The app will check:
1. ✅ Is user logged in?
2. ✅ Does user document exist?
3. ✅ Does user have identifiers (flatId, residentId, name)?
4. ✅ Do bills exist in Firestore?
5. ✅ Do any bills match user's identifiers?
6. ✅ Are matching bills "pending"?

### Step 3: Read the Output

The diagnostic will tell you EXACTLY what's wrong and how to fix it.

---

## Possible Issues & Solutions

### Issue 1: No User Logged In
```
❌ ERROR: No user logged in

SOLUTION: Login first with:
   Phone: 7010678124
   Password: 121456
```

**Fix**: Login to the app first, then run diagnostic again

---

### Issue 2: User Document Not Found
```
❌ ERROR: User document not found
   Collection: users
   Document ID: abc123xyz

SOLUTION: Create user document in Firebase Console
```

**Fix**:
1. Go to Firebase Console
2. Firestore Database → users collection
3. Create document with ID = your Firebase Auth UID
4. Add fields: flatId, residentId, name

---

### Issue 3: No Identifiers
```
❌ ERROR: No identifiers found
   User has no flatId, residentId, or name

SOLUTION: Add at least one identifier
```

**Fix**:
1. Firebase Console → Firestore → users → (your user)
2. Add field: `flatId` (string) = `"1202"`
3. Add field: `residentId` (string) = `"RES68429"`
4. Add field: `name` (string) = `"Preetham"`

---

### Issue 4: No Bills Exist
```
❌ ERROR: No bills exist in Firestore

SOLUTION: Create a bill in Firebase Console
```

**Fix**:
1. Firebase Console → Firestore → bills collection
2. Add document (auto-generate ID)
3. Add fields:
   ```
   flatId: "1202"
   status: "pending"
   amount: 6000
   month: "February"
   year: "2026"
   dueDate: (select timestamp)
   chargeBreakdown: (map)
     Electricity: 2000
     Maintenance: 2000
     Water: 500
     Service: 500
     Parking: 500
     Security: 500
   ```

---

### Issue 5: No Matching Bills
```
❌ ERROR: No matching bills found

REASON: None of the bills match your identifiers

Your identifiers:
   flatId: 1202
   residentId: RES68429
   name: Preetham

SOLUTION: Update a bill to match
```

**Fix**:
1. Firebase Console → Firestore → bills → (any bill)
2. Update `flatId` to match your user's flatId: `"1202"`
3. Ensure `status` = `"pending"`

---

### Issue 6: No Pending Bills
```
⚠️  WARNING: Matching bills found but none are pending

SOLUTION: Change a bill status to "pending"
```

**Fix**:
1. Firebase Console → Firestore → bills → (matching bill)
2. Change `status` field to `"pending"` (lowercase)

---

### Issue 7: Success!
```
✅ SUCCESS: Found 1 pending bill(s)

The app should display these bills.
If not, check console logs for errors.
```

**Next Step**: Run the main app and check if bills display

---

## After Running Diagnostic

### If Diagnostic Shows Success
```bash
# Run main app
cd resident_app
flutter run

# Login and navigate to Bills tab
# Bills should now display
```

### If Diagnostic Shows Error
1. Read the error message
2. Follow the SOLUTION steps
3. Run diagnostic again
4. Repeat until you see SUCCESS

---

## Example Output

### Successful Diagnostic
```
═══════════════════════════════════════
🔍 BILLING DIAGNOSTIC START
═══════════════════════════════════════

STEP 1: Check Current User
─────────────────────────────────────
✅ User logged in
   UID: abc123xyz
   Email: preethampriyadharshan07@gmail.com
   Phone: +917010678124

STEP 2: Check User Document
─────────────────────────────────────
✅ User document found
   Fields: uid, name, email, phone, flatId, residentId
   flatId: 1202
   residentId: RES68429
   name: Preetham

STEP 3: Query All Bills
─────────────────────────────────────
✅ Total bills in collection: 5

STEP 4: Check Bills for Matches
─────────────────────────────────────
✓ Bill dKoTQtdVuiNkBqLWZmQP:
   Matched by: flatId
   flatId: 1202
   residentId: RES68429
   residentName: Preetham
   status: pending
   amount: 6000
   month: February

─────────────────────────────────────
SUMMARY:
   Total bills: 5
   Matching bills: 1
   Pending matching bills: 1

✅ SUCCESS: Found 1 pending bill(s)

The app should display these bills.
If not, check console logs for errors.

═══════════════════════════════════════
🔍 DIAGNOSTIC COMPLETE
═══════════════════════════════════════
```

---

## Quick Commands

### Run Diagnostic
```bash
cd resident_app
flutter run lib/diagnose_billing_now.dart
```

### Run Main App
```bash
cd resident_app
flutter run
```

### Hot Restart
```
Press 'R' in terminal
```

---

## Summary

This diagnostic will:
- ✅ Check every step of the data flow
- ✅ Identify the exact problem
- ✅ Provide specific solutions
- ✅ Show you what data exists
- ✅ Tell you what's missing

Run it now to find out why bills aren't displaying!

---

**Status**: Ready to Run
**Time**: 30 seconds
**Result**: Exact problem identification
