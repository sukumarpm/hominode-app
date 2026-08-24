# Immediate Debug Steps - Admin Data Fetch

## What to Do Right Now

### Step 1: Run the App and Check Console

1. Open your terminal/command prompt
2. Run: `flutter run -d YOUR_DEVICE_ID`
3. Watch the console output carefully

### Step 2: Look for Debug Messages

When you open the app, you should see messages like:

```
=== DEBUG: Dashboard Data Fetch ===
Auth UID: UCkGf6KNHeQBvJZGQwZ8LF7Zgv2
Auth Email: sukumar@gmail.com
Fetching from: admins/UCkGf6KNHeQBvJZGQwZ8LF7Zgv2
Document exists: true/false
Fetched data: {name: ..., email: ..., phone: ..., organization: ...}
Admin Name: ...
Admin Role: ...
Building Name: ...
===================================
```

When you open Edit Profile, you should see:

```
=== DEBUG: Edit Profile Data Fetch ===
Auth UID: UCkGf6KNHeQBvJZGQwZ8LF7Zgv2
Auth Email: sukumar@gmail.com
Fetching from: admins/UCkGf6KNHeQBvJZGQwZ8LF7Zgv2
Document exists: true/false
Fetched data: {name: ..., email: ..., phone: ..., organization: ...}
Name: ...
Email: ...
Phone: ...
Organization: ...
=====================================
```

### Step 3: Check Your Firestore

Based on the Auth UID from the console:

1. Open Firebase Console
2. Go to Firestore Database
3. Look for collection: `admins`
4. Look for document with ID: `UCkGf6KNHeQBvJZGQwZ8LF7Zgv2` (or whatever UID you see in console)

### Step 4: Fix the Issue

#### If "Document exists: false"

The admin document doesn't exist. Create it:

1. In Firestore Console → `admins` collection
2. Click "Add document"
3. Document ID: Use the UID from console (e.g., `UCkGf6KNHeQBvJZGQwZ8LF7Zgv2`)
4. Add fields:
   ```
   name: "Your Name"
   email: "your@email.com"
   phone: "1234567890"
   organization: "Your Property Name"
   role: "admin"
   buildingIds: [] (array)
   createdAt: (timestamp - current time)
   updatedAt: (timestamp - current time)
   ```
5. Save
6. Restart the app

#### If "Document exists: true" but wrong data

The document exists but has wrong data:

1. Check the "Fetched data" in console
2. Compare with what you see in Firestore
3. If they match but app shows different data, there might be caching
4. Try:
   - Clear app data
   - Uninstall and reinstall app
   - Hot restart (press 'R' in terminal)

#### If document ID doesn't match Auth UID

You have the document but with wrong ID:

1. In Firestore, note the correct data
2. Delete the wrong document
3. Create new document with correct UID as document ID
4. Copy all the fields
5. Restart app

## Quick Fix Script

If you want to create the admin document programmatically, add this temporary button to your dashboard:

```dart
// Add this button temporarily
ElevatedButton(
  onPressed: () async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance
          .collection('admins')
          .doc(user.uid)
          .set({
        'name': 'Your Name',  // Change this
        'email': user.email ?? 'your@email.com',
        'phone': '1234567890',  // Change this
        'organization': 'Your Property Name',  // Change this
        'role': 'admin',
        'buildingIds': [],
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Admin document created!')),
      );
      
      // Reload data
      setState(() {});
    }
  },
  child: Text('Create Admin Document'),
)
```

## What the Console Output Tells You

### Scenario 1: Document Doesn't Exist
```
Auth UID: UCkGf6KNHeQBvJZGQwZ8LF7Zgv2
Fetching from: admins/UCkGf6KNHeQBvJZGQwZ8LF7Zgv2
Document exists: false
WARNING: Admin document does not exist
```
**Fix:** Create the document in Firestore with the correct UID

### Scenario 2: Document Exists with Correct Data
```
Auth UID: UCkGf6KNHeQBvJZGQwZ8LF7Zgv2
Document exists: true
Fetched data: {name: lyvo home's, email: admin@lyvo.com, phone: 1010678124, ...}
Name: lyvo home's
Email: admin@lyvo.com
Phone: 1010678124
```
**Result:** App should show correct data

### Scenario 3: Document Exists but Wrong Data
```
Auth UID: UCkGf6KNHeQBvJZGQwZ8LF7Zgv2
Document exists: true
Fetched data: {name: Admin User, email: sukumar@gmail.com, ...}
```
**Fix:** Update the document in Firestore with correct data

## Summary

1. ✅ Code is updated to fetch from `admins` collection
2. ✅ Debug logging is added
3. ⏳ Need to verify document exists with correct UID
4. ⏳ Need to check console output

**Next:** Run the app and share the console output so we can identify the exact issue.
