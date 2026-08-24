# Debug: Admin Data Fetch Issue

## Problem
App is showing wrong data or not fetching from `admins` collection properly.

## Quick Debug Steps

### Step 1: Check Your Firebase Auth UID

Add this temporary code to your dashboard or profile screen to see your Auth UID:

```dart
@override
void initState() {
  super.initState();
  final user = FirebaseAuth.instance.currentUser;
  print('=== DEBUG: My Firebase Auth UID ===');
  print('UID: ${user?.uid}');
  print('Email: ${user?.email}');
  print('===================================');
  _loadAdminData();
}
```

### Step 2: Check Firestore Document

1. Open Firebase Console → Firestore Database
2. Go to `admins` collection
3. Find document with ID matching your Auth UID from Step 1
4. If document doesn't exist, create it:

```javascript
// Document ID: YOUR_AUTH_UID_FROM_STEP_1
{
  "name": "Your Name",
  "email": "your@email.com",
  "phone": "1234567890",
  "organization": "Your Property Name",
  "role": "admin",
  "buildingIds": [],
  "createdAt": {current timestamp},
  "updatedAt": {current timestamp}
}
```

### Step 3: Add Debug Logging to Edit Profile Modal

Update `_loadUserData()` in `edit_profile_modal.dart`:

```dart
Future<void> _loadUserData() async {
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('DEBUG: No user logged in');
      return;
    }

    _userId = user.uid;
    print('DEBUG: Fetching admin data for UID: $_userId');

    // Fetch admin data from Firestore admins collection
    final userDoc = await FirebaseFirestore.instance
        .collection('admins')
        .doc(_userId)
        .get();

    print('DEBUG: Document exists: ${userDoc.exists}');
    
    if (userDoc.exists) {
      final data = userDoc.data()!;
      print('DEBUG: Fetched data: $data');
      
      setState(() {
        _nameController.text = data['name'] ?? 'Admin User';
        _emailController.text = data['email'] ?? user.email ?? '';
        _phoneController.text = data['phone'] ?? '';
        _organizationController.text = data['organization'] ?? 'LYVO Property Management';
        _isLoading = false;
      });
      
      print('DEBUG: Name set to: ${_nameController.text}');
      print('DEBUG: Email set to: ${_emailController.text}');
      print('DEBUG: Phone set to: ${_phoneController.text}');
      print('DEBUG: Organization set to: ${_organizationController.text}');
    } else {
      print('DEBUG: Admin document does not exist!');
      print('DEBUG: Expected document path: admins/$_userId');
    }
  } catch (e) {
    print('DEBUG ERROR: $e');
  }
}
```

### Step 4: Check Console Output

Run the app and check the console/logcat for debug messages:

```
DEBUG: My Firebase Auth UID
UID: UCkGf6KNHeQBvJZGQwZ8LF7Zgv2
Email: sukumar@gmail.com
===================================

DEBUG: Fetching admin data for UID: UCkGf6KNHeQBvJZGQwZ8LF7Zgv2
DEBUG: Document exists: true
DEBUG: Fetched data: {name: lyvo home's, email: admin@lyvo.com, ...}
DEBUG: Name set to: lyvo home's
DEBUG: Email set to: admin@lyvo.com
DEBUG: Phone set to: 1010678124
DEBUG: Organization set to: LYVO Property Management
```

## Common Issues

### Issue 1: Document ID Mismatch
**Problem:** Admin document ID doesn't match Firebase Auth UID
**Solution:** 
- Check Auth UID in Firebase Console → Authentication
- Check document ID in Firestore → admins collection
- They must match exactly

### Issue 2: Document Doesn't Exist
**Problem:** No document in `admins` collection for your UID
**Solution:** Create the document manually in Firestore console

### Issue 3: Wrong Collection
**Problem:** Code is still fetching from `users` collection
**Solution:** Verify code says `.collection('admins')` not `.collection('users')`

### Issue 4: Cached Data
**Problem:** App is showing old cached data
**Solution:** 
- Clear app data
- Uninstall and reinstall app
- Or add: `await FirebaseFirestore.instance.clearPersistence();`

## Verification Checklist

- [ ] Firebase Auth UID matches Firestore document ID
- [ ] Document exists in `admins` collection
- [ ] Document has all required fields (name, email, phone, organization)
- [ ] Code is fetching from `admins` collection (not `users`)
- [ ] No errors in console/logcat
- [ ] App data cleared/reinstalled

## Expected vs Actual

### Expected (from Firestore screenshot):
- Name: "lyvo home's"
- Email: "admin@lyvo.com"
- Phone: "1010678124"
- Organization: "LYVO Property Management"

### Actual (from app screenshot):
- Name: "Admin User"
- Email: "sukumar@gmail.com"
- Phone: (empty)
- Organization: "LYVO Property Management"

### Analysis:
The mismatch suggests either:
1. Wrong document ID being used
2. Multiple admin documents exist
3. Code is fetching from wrong collection
4. Cached data from previous implementation

## Next Steps

1. Add debug logging (see Step 3 above)
2. Run app and check console output
3. Verify document ID matches Auth UID
4. Share console output for further debugging
