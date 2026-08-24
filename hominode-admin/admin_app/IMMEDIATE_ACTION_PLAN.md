# Immediate Action Plan - Fix Data Storage Issue

## 🚨 URGENT: Data Not Storing Properly

Follow these steps IN ORDER to fix the issue:

---

## Step 1: Check Your Admin Profile (5 minutes)

### Open Firebase Console
1. Go to https://console.firebase.google.com
2. Select your project
3. Click "Firestore Database" in left menu
4. Click on `admins` collection
5. Find YOUR admin document (look for your email)

### Verify These Fields Exist and Are NOT Empty:
```
✅ name: "Your Name"
✅ email: "your@email.com"  
✅ phone: "1234567890"
✅ organization: "Your Organization"
```

### If ANY field is missing or empty:
1. Click on your admin document
2. Click "Add field" or "Edit"
3. Add the missing fields with real values
4. Click "Update"

**This is the #1 cause of empty data!**

---

## Step 2: Run the Diagnostic Tool (2 minutes)

### Add Debug Screen to Your App

1. Open `admin_app/lib/main.dart` or any screen
2. Add this button temporarily:

```dart
ElevatedButton(
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const DebugDataStorageScreen(),
      ),
    );
  },
  child: const Text('Debug Data Storage'),
)
```

3. Import the screen:
```dart
import 'debug_data_storage_screen.dart';
```

4. Run the app
5. Tap the "Debug Data Storage" button
6. Tap "Run Diagnostic"
7. Check the console output

---

## Step 3: Test Creating a Resident (3 minutes)

### Create a Test Resident
1. Open your admin app
2. Go to "Manage Buildings" or "Residents"
3. Click "Add Resident" or "Assign Resident" → "Add New"
4. Fill in:
   - Name: "Test User"
   - Phone: "9999999999"
   - Email: "test@test.com"
5. Click "Create" or "Create & Assign"

### Check Console Output
Look for these messages:
```
✅ Admin details fetched
✅ Resident ID generated
✅ Firestore document created successfully
✅ Document verified in Firestore
```

### Check Firestore
1. Go to Firebase Console → Firestore
2. Open `users` collection
3. Find the newly created user
4. Verify ALL these fields exist and are NOT empty:
   - adminId
   - adminName
   - adminEmail
   - adminPhone
   - organization
   - buildingId
   - buildingName

---

## Step 4: If Still Not Working

### Check Firestore Rules
1. Go to Firebase Console → Firestore
2. Click "Rules" tab
3. Make sure you have:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read, write: if request.auth != null;
    }
    match /flats/{flatId} {
      allow read, write: if request.auth != null;
    }
    match /admins/{adminId} {
      allow read: if request.auth != null;
      allow write: if request.auth.uid == adminId;
    }
  }
}
```

4. Click "Publish"

---

## Quick Fixes for Common Issues

### Issue: adminName, adminPhone, organization are empty

**Fix**: Update your admin profile in Firestore (Step 1)

### Issue: buildingId, buildingName are null

**Fix**: Either:
1. Add buildingId and buildingName to your admin profile, OR
2. Make sure you're creating residents from "Manage Buildings" screen (not from Residents screen)

### Issue: residentId, residentName not in flats collection

**Fix**: This happens during assignment. Make sure:
1. You're using the "Assign Resident" button from flat grid
2. The flat exists in Firestore
3. Firestore rules allow writes to flats collection

---

## Expected Result

After fixing, when you create a resident, you should see in Firestore:

### users/{userId}
```json
{
  "name": "Test User",
  "phone": "9999999999",
  "email": "test@test.com",
  "residentId": "RES1234",
  "adminId": "your-admin-id",
  "adminName": "Your Name",          ← Should NOT be empty
  "adminEmail": "your@email.com",    ← Should NOT be empty
  "adminPhone": "1234567890",        ← Should NOT be empty
  "organization": "Your Org",        ← Should NOT be empty
  "buildingId": "building-id",       ← Should NOT be null
  "buildingName": "Tower A",         ← Should NOT be null
  "flatId": null,
  "flatLabel": null
}
```

### flats/{flatId} (after assignment)
```json
{
  "flatId": "A101",
  "buildingId": "building-id",
  "buildingName": "Tower A",
  "residentId": "RES1234",           ← Should be set
  "residentName": "Test User",       ← Should be set
  "residentUserId": "user-id",       ← Should be set
  "status": "occupied"               ← Should be "occupied"
}
```

---

## Still Having Issues?

1. Run the diagnostic tool (Step 2)
2. Copy the console output
3. Take screenshots of:
   - Your admin document in Firestore
   - The user document in Firestore
   - Any error messages
4. Check `DATA_NOT_STORING_TROUBLESHOOTING.md` for detailed help

---

## Success Checklist

- [ ] Admin profile has complete data (name, email, phone, organization)
- [ ] Diagnostic tool runs without errors
- [ ] Can create a test resident
- [ ] User document has all required fields
- [ ] Can assign resident to flat
- [ ] Flat document updates with resident info
- [ ] No errors in console

**If all checkboxes are checked, your system is working correctly!** ✅
