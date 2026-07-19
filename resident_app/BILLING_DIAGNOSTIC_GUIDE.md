# Billing Data Flow Diagnostic Guide

## Issue
User reports no billing data showing in Maintenance & Billing screen despite:
- ✅ Billing data exists in Firestore `bills` collection
- ✅ Dashboard shows "Pending Bill ₹850" (working)
- ✅ Login works with Firestore-only authentication
- ✅ Implementation follows flow function correctly

## Data Flow Architecture

```
┌─────────────────────────────────────────────────────────────┐
│ 1. USER LOGS IN                                              │
│    - signInFirestoreOnly(email, password)                    │
│    - Validates credentials from Firestore users collection   │
│    - Saves userId to SharedPreferences                       │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ 2. NAVIGATE TO MAINTENANCE & BILLING SCREEN                  │
│    - StreamBuilder calls billService.streamBills()           │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ 3. BILL SERVICE GETS USER DATA                               │
│    - Calls UserDataService.getCurrentUserData()              │
│    - UserDataService tries:                                  │
│      a) Firebase Auth UID (if available)                     │
│      b) Stored userId from SharedPreferences (fallback)      │
│    - Fetches user document from Firestore users/{userId}     │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ 4. EXTRACT IDENTIFIERS                                       │
│    - residentId: userData['residentId']                      │
│    - flatId: userData['flatId'] ?? userData['flatLabel']     │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ 5. QUERY FIRESTORE BILLS                                     │
│    - Primary: .where('residentId', ==, residentId)           │
│    - Fallback: .where('flatId', ==, flatId)                  │
│    - Returns real-time stream with .snapshots()              │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ 6. DISPLAY IN UI                                             │
│    - StreamBuilder receives bills                            │
│    - Separates pending and paid bills                        │
│    - Shows current bill card + payment history               │
└─────────────────────────────────────────────────────────────┘
```

## Run Diagnostic Tool

### Step 1: Run the diagnostic app
```bash
flutter run -t lib/diagnose_billing_flow.dart
```

### Step 2: Check the logs
The diagnostic will verify each step:
1. ✅ SharedPreferences state before login
2. ✅ Login with Firestore-only authentication
3. ✅ SharedPreferences state after login (userId saved?)
4. ✅ UserDataService retrieves user data
5. ✅ Extract residentId and flatId
6. ✅ Direct Firestore query by residentId
7. ✅ Direct Firestore query by flatId
8. ✅ BillService.streamBills() output
9. ✅ All bills in Firestore (no filter)

## Common Issues & Solutions

### Issue 1: userId not saved to SharedPreferences
**Symptom**: Login succeeds but UserDataService returns null

**Solution**: Verify `_saveLoginState()` in `firestore_auth_service.dart`
```dart
await prefs.setBool('is_logged_in', true);
await prefs.setString('user_id', userId);  // ← Must save userId
```

### Issue 2: User document missing flatId/flatLabel
**Symptom**: Query returns 0 bills even though bills exist

**Check Firestore user document**:
```
users/{userId}
  - flatId: "t202"  OR  flatLabel: "t202"
  - residentId: "RES001"
```

**Solution**: Ensure user document has at least one identifier

### Issue 3: Bill documents don't match user identifiers
**Symptom**: Bills exist but query returns 0 results

**Check Firestore bill documents**:
```
bills/{billId}
  - flatId: "t202"  (must match user's flatId/flatLabel)
  - residentId: "RES001"  (must match user's residentId)
  - status: "pending"
  - amount: 850
```

**Solution**: Ensure bill documents have matching identifiers

### Issue 4: Firebase Auth interfering with Firestore-only login
**Symptom**: UserDataService tries Firebase Auth first and fails

**Check**: UserDataService.getCurrentUserData()
```dart
// Should fallback to stored userId when Firebase Auth is null
final firebaseUser = _auth.currentUser;  // null for Firestore-only
if (firebaseUser != null) {
  // Try Firebase Auth UID
} else {
  // Fallback to stored userId ← This should work
  userId = await _authService.getCurrentUserId();
}
```

## Manual Verification Steps

### 1. Check user document in Firestore
```
Collection: users
Document ID: {userId from login}

Expected fields:
- name: "Preetham Priyatharson"
- email: "preethampriyatharson07@gmail.com"
- phone: "9876543210"
- flatId: "t202" OR flatLabel: "t202"
- residentId: "RES001" (optional)
- status: "active"
```

### 2. Check bill documents in Firestore
```
Collection: bills

Expected documents:
- flatId: "t202" (must match user's flatId/flatLabel)
- residentId: "RES001" (if user has residentId)
- status: "pending" or "paid"
- amount: 850
- month: "January 2025"
- dueDate: Timestamp
```

### 3. Check SharedPreferences after login
```dart
final prefs = await SharedPreferences.getInstance();
print('is_logged_in: ${prefs.getBool('is_logged_in')}');  // Should be true
print('user_id: ${prefs.getString('user_id')}');  // Should be userId
```

### 4. Test the query directly
```dart
// Test by residentId
final snapshot = await FirebaseFirestore.instance
    .collection('bills')
    .where('residentId', isEqualTo: 'RES001')
    .get();
print('Bills by residentId: ${snapshot.docs.length}');

// Test by flatId
final snapshot2 = await FirebaseFirestore.instance
    .collection('bills')
    .where('flatId', isEqualTo: 't202')
    .get();
print('Bills by flatId: ${snapshot2.docs.length}');
```

## Expected Console Output (Success)

```
🔐 Starting Firestore-only authentication...
   Identifier: preethampriyatharson07@gmail.com
📧 Detected email, searching in Firestore...
   Searching for email: preethampriyatharson07@gmail.com
   ✅ Found user with email: preethampriyatharson07@gmail.com
   User ID: abc123xyz
   User Name: Preetham Priyatharson
   Verifying password...
✅ Password verified successfully
💾 Login state saved
✅ Login successful! (Firestore-only)

📥 Fetching user data from Firestore...
   User ID: abc123xyz
✅ User data fetched successfully
   Name: Preetham Priyatharson
   Email: preethampriyatharson07@gmail.com
   Phone: 9876543210

🔍 BillService: Fetching flat for user: abc123xyz
✅ BillService: Found flat ID: t202 (cached)

📋 BillService: Fetching bills with Firestore .where() query
   residentId: RES001
   flatId: t202
   ✓ Applied .where("residentId", isEqualTo: "RES001")
✅ BillService: Fetched 2 bills (server-side filtered)

📡 Streaming bills with Firestore .where() query
   residentId: RES001
   flatId: t202
   ✓ Applied .where("residentId", isEqualTo: "RES001")
📡 Streamed 2 bills (server-side filtered)
```

## Next Steps

1. **Run the diagnostic tool** to identify which step is failing
2. **Check the console logs** for error messages
3. **Verify Firestore data** matches expected structure
4. **Test queries directly** in Firebase Console

## Files to Check

- `lib/src/services/firestore_auth_service.dart` - Login and save state
- `lib/src/services/user_data_service.dart` - Fetch user data
- `lib/src/services/bill_firestore_service.dart` - Query bills
- `lib/maintenance_billing_screen.dart` - Display bills

## Contact

If the diagnostic shows all steps passing but UI still shows no data, check:
1. StreamBuilder connection state
2. UI rendering logic
3. Error handling in build method
