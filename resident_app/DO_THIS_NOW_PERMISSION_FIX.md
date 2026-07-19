# 🚨 DO THIS NOW: Fix Permission Denied Error

## Your Error
```
❌ Error fetching visitors: [cloud_firestore/permission-denied]
❌ Dashboard: No user data found
```

## The Problem
Your user document in Firestore doesn't exist or doesn't match your Firebase Auth UID.

## The Fix (2 Options)

### Option 1: Automated Fix (Recommended)

**Step 1: Run Diagnostic**
```bash
# Double-click this file:
RUN_DIAGNOSTIC_NOW.bat

# Or run manually:
flutter run lib/diagnose_firestore_permission.dart
```

**Step 2: Update Fix Script**
Open `lib/fix_firestore_permissions_complete.dart` and update lines 48-53:
```dart
'name': 'Your Actual Name',        // ← CHANGE THIS
'phone': '+1234567890',             // ← CHANGE THIS
'buildingId': 'your_building_id',   // ← CHANGE THIS
'flatId': 'your_flat_id',           // ← CHANGE THIS
'role': 'resident',                 // ← or 'admin'
```

**Step 3: Run Fix**
```bash
# Double-click this file:
FIX_PERMISSION_NOW.bat

# Or run manually:
flutter run lib/fix_firestore_permissions_complete.dart
```

**Step 4: Restart App**
```bash
# Stop app completely, then:
flutter run
```

---

### Option 2: Manual Fix in Firebase Console

**Step 1: Get Your Firebase Auth UID**
1. Go to Firebase Console → Authentication → Users
2. Find your user
3. Copy the UID (e.g., `abc123xyz`)

**Step 2: Create/Update User Document**
1. Go to Firebase Console → Firestore Database
2. Open `users` collection
3. Look for document with ID = your Firebase Auth UID
4. If it doesn't exist, click "Add document"
5. Set Document ID = your Firebase Auth UID
6. Add these fields:

```
id: "abc123xyz" (same as document ID)
authUid: "abc123xyz" (same as document ID)
email: "your@email.com"
name: "Your Name"
phone: "+1234567890"
buildingId: "building1"  ← YOUR BUILDING ID
flatId: "flat101"        ← YOUR FLAT ID
flatLabel: "A-101"
role: "resident"         ← or "admin"
residentId: "RES123456"
ownershipType: "Owner"
createdAt: (timestamp) now
updatedAt: (timestamp) now
```

**Step 3: Save and Wait**
- Click "Save"
- Wait 2 minutes
- Restart your app

---

## Quick Checklist

- [ ] User is logged in (check Firebase Auth console)
- [ ] User document exists in Firestore
- [ ] Document ID matches Firebase Auth UID
- [ ] Document has `buildingId` field
- [ ] Document has `flatId` field
- [ ] Document has `role` field
- [ ] Firestore rules are published
- [ ] Waited 2 minutes
- [ ] Restarted app

---

## Expected Result

After fixing, you should see:
```
✅ User data fetched successfully
   ID: abc123xyz
   Name: Your Name
   Building ID: building1
   Flat ID: flat101
✅ Bills fetched
✅ Complaints fetched
✅ Visitors fetched
✅ Dashboard loaded
```

---

## Still Not Working?

1. **Check Firebase Auth**: Make sure you're logged in
2. **Check Document ID**: Must match Firebase Auth UID exactly
3. **Check Required Fields**: buildingId, flatId, role must exist
4. **Wait Longer**: Rules can take up to 5 minutes to propagate
5. **Check Rules**: Go to Firebase Console → Firestore → Rules

---

## Files You Need

- **Diagnostic**: `RUN_DIAGNOSTIC_NOW.bat` or `lib/diagnose_firestore_permission.dart`
- **Fix**: `FIX_PERMISSION_NOW.bat` or `lib/fix_firestore_permissions_complete.dart`
- **Documentation**: `START_HERE_PERMISSION_DENIED_FIX.md`

---

**The rules are correct. Fix your user document and everything will work!**

