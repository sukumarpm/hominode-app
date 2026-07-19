# Billing Flow Visual Debug Guide

## 🎯 Quick Diagnostic

Run this command to diagnose the issue:
```bash
RUN_BILLING_DIAGNOSTIC.bat
```

## 🔍 What to Check

### Step 1: Login Flow
```
┌─────────────────────────────────────┐
│  User enters credentials            │
│  Email: preetham...@gmail.com       │
│  Password: DvgIDLEy                 │
└─────────────────────────────────────┘
              ↓
┌─────────────────────────────────────┐
│  FirestoreAuthService               │
│  .signInFirestoreOnly()             │
│                                     │
│  ✓ Query Firestore users           │
│  ✓ Verify password                  │
│  ✓ Save to SharedPreferences        │
└─────────────────────────────────────┘
              ↓
┌─────────────────────────────────────┐
│  SharedPreferences                  │
│  is_logged_in: true                 │
│  user_id: "abc123xyz"  ← CRITICAL   │
└─────────────────────────────────────┘
```

**✅ Check**: Console should show "💾 Login state saved"

**❌ If missing**: Login succeeded but userId not saved

---

### Step 2: User Data Fetch
```
┌─────────────────────────────────────┐
│  UserDataService                    │
│  .getCurrentUserData()              │
└─────────────────────────────────────┘
              ↓
┌─────────────────────────────────────┐
│  Try Firebase Auth UID              │
│  (null for Firestore-only login)    │
└─────────────────────────────────────┘
              ↓
┌─────────────────────────────────────┐
│  Fallback: Get from SharedPref      │
│  userId = prefs.getString('user_id')│
└─────────────────────────────────────┘
              ↓
┌─────────────────────────────────────┐
│  Fetch from Firestore               │
│  users/{userId}                     │
│                                     │
│  ✓ name: "Preetham..."              │
│  ✓ email: "preetham...@gmail.com"   │
│  ✓ flatId: "t202"  ← CRITICAL       │
│  ✓ residentId: "RES001"             │
└─────────────────────────────────────┘
```

**✅ Check**: Console should show "✅ User data fetched successfully"

**❌ If missing**: userId not in SharedPreferences OR user document not found

---

### Step 3: Bill Query
```
┌─────────────────────────────────────┐
│  BillFirestoreService               │
│  .streamBills()                     │
└─────────────────────────────────────┘
              ↓
┌─────────────────────────────────────┐
│  Extract identifiers from user data │
│  residentId: "RES001"               │
│  flatId: "t202"                     │
└─────────────────────────────────────┘
              ↓
┌─────────────────────────────────────┐
│  Build Firestore query              │
│                                     │
│  PRIMARY:                           │
│  .where('residentId', ==, 'RES001') │
│                                     │
│  FALLBACK:                          │
│  .where('flatId', ==, 't202')       │
└─────────────────────────────────────┘
              ↓
┌─────────────────────────────────────┐
│  Execute query with .snapshots()    │
│  Returns Stream<QuerySnapshot>      │
└─────────────────────────────────────┘
              ↓
┌─────────────────────────────────────┐
│  Results                            │
│  Bill 1: ₹850 (pending)             │
│  Bill 2: ₹750 (paid)                │
└─────────────────────────────────────┘
```

**✅ Check**: Console should show "📡 Streamed X bills"

**❌ If 0 bills**: User identifiers don't match bill documents

---

### Step 4: UI Display
```
┌─────────────────────────────────────┐
│  MaintenanceBillingScreen           │
│  StreamBuilder<List<Map>>           │
└─────────────────────────────────────┘
              ↓
┌─────────────────────────────────────┐
│  Connection State                   │
│  - waiting: Show loading            │
│  - error: Show error message        │
│  - done: Process data               │
└─────────────────────────────────────┘
              ↓
┌─────────────────────────────────────┐
│  Separate bills by status           │
│  pendingBills = status == 'pending' │
│  paidBills = status == 'paid'       │
└─────────────────────────────────────┘
              ↓
┌─────────────────────────────────────┐
│  Display                            │
│  - Current Bill Card (pending)      │
│  - Bill Breakdown                   │
│  - Payment History (paid)           │
└─────────────────────────────────────┘
```

**✅ Check**: UI should show bill cards

**❌ If empty**: StreamBuilder not receiving data OR bills array is empty

---

## 🐛 Common Issues

### Issue 1: "No user logged in"
```
❌ BillService: No user logged in
```
**Cause**: userId not in SharedPreferences

**Fix**: Check `_saveLoginState()` in firestore_auth_service.dart

---

### Issue 2: "User document not found"
```
✅ Login successful
❌ User document not found
```
**Cause**: userId doesn't match Firestore document ID

**Fix**: Verify userId in SharedPreferences matches Firestore

---

### Issue 3: "No flat assigned to user"
```
✅ User data fetched
⚠️ No flat assigned to user
```
**Cause**: User document missing `flatId` and `flatLabel`

**Fix**: Add `flatId: "t202"` to user document in Firestore

---

### Issue 4: "Fetched 0 bills"
```
✅ Applied .where("residentId", ==, "RES001")
ℹ️ Fetched 0 bills
```
**Cause**: No bills match the query

**Fix**: Check bill documents have matching `residentId` or `flatId`

---

## 📊 Firestore Data Structure

### ✅ Correct User Document
```json
{
  "name": "Preetham Priyatharson",
  "email": "preethampriyatharson07@gmail.com",
  "phone": "9876543210",
  "flatId": "t202",           ← MUST HAVE
  "flatLabel": "t202",        ← OR THIS
  "residentId": "RES001",     ← OPTIONAL
  "status": "active"
}
```

### ✅ Correct Bill Document
```json
{
  "flatId": "t202",           ← MUST MATCH USER
  "residentId": "RES001",     ← MUST MATCH USER
  "status": "pending",
  "amount": 850,
  "month": "January 2025",
  "dueDate": "2025-01-31T00:00:00Z"
}
```

### ❌ Wrong: Identifiers Don't Match
```
User:  flatId: "t202"
Bill:  flatId: "T202"  ← Case mismatch!

User:  flatId: "t202"
Bill:  flatId: "202"   ← Missing prefix!

User:  residentId: "RES001"
Bill:  residentId: null  ← Missing field!
```

---

## 🚀 Quick Test

### Test 1: Check SharedPreferences
```dart
final prefs = await SharedPreferences.getInstance();
print('Logged in: ${prefs.getBool('is_logged_in')}');
print('User ID: ${prefs.getString('user_id')}');
```

### Test 2: Check User Document
```dart
final doc = await FirebaseFirestore.instance
    .collection('users')
    .doc(userId)
    .get();
print('User data: ${doc.data()}');
```

### Test 3: Check Bills Query
```dart
final snapshot = await FirebaseFirestore.instance
    .collection('bills')
    .where('flatId', isEqualTo: 't202')
    .get();
print('Bills found: ${snapshot.docs.length}');
```

---

## 📝 Diagnostic Output Example

### ✅ Success
```
🚀 Starting Billing Flow Diagnostic...

📋 STEP 1: Checking SharedPreferences
   is_logged_in: false
   user_id: null

📋 STEP 2: Login with Firestore-only
   Email: preethampriyatharson07@gmail.com
   ✅ Login successful
   User ID: abc123xyz

📋 STEP 3: Verify SharedPreferences after login
   is_logged_in: true
   user_id: abc123xyz
   ✅ Login state saved correctly

📋 STEP 4: Get user data via UserDataService
   ✅ User data retrieved
   Name: Preetham Priyatharson
   flatId: t202
   residentId: RES001

📋 STEP 5: Extract identifiers for billing query
   flatId: t202
   residentId: RES001

📋 STEP 6: Query Firestore bills collection directly
   Querying by residentId: RES001
   Found 2 bills by residentId
   - Bill ID: bill123
     Amount: 850
     Status: pending

📋 STEP 7: Test BillService.streamBills()
   📡 Stream update: 2 bills
   - January 2025: ₹850 (pending)
   - December 2024: ₹750 (paid)

✅ Diagnostic complete!
```

### ❌ Failure (No bills)
```
📋 STEP 6: Query Firestore bills collection directly
   Querying by residentId: RES001
   Found 0 bills by residentId  ← PROBLEM!
   
   Querying by flatId: t202
   Found 0 bills by flatId  ← PROBLEM!

📋 STEP 8: Check all bills in Firestore (no filter)
   Total bills in collection: 5
   - Bill ID: bill1
     flatId: T202  ← Case mismatch!
     residentId: null
   - Bill ID: bill2
     flatId: 202  ← Missing 't' prefix!
     residentId: RES002
```

**Solution**: Fix bill documents to match user identifiers exactly

---

## 🎯 Action Items

1. **Run diagnostic**: `RUN_BILLING_DIAGNOSTIC.bat`
2. **Read console logs**: Identify which step fails
3. **Fix Firestore data**: Ensure identifiers match
4. **Test in app**: Login and check Maintenance & Billing screen

---

## 📞 Support

If diagnostic shows all steps passing but UI still empty:
- Check StreamBuilder connection state
- Check error handling in build method
- Verify bills array is not filtered out by UI logic
