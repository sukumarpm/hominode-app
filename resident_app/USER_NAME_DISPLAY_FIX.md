# User Name Display Fix - Complete Guide

## Current Situation

You're seeing "Unknown User" or "User" instead of the actual user name in various places in the app.

## Root Cause

The user data is not being fetched properly from Firestore because:
1. The `authUid` field in Firestore is `null`
2. This breaks the link between Firebase Auth and Firestore
3. The app can't find the user's profile data

## Where User Names Are Displayed

### 1. Dashboard Screen (`dashboard_screen.dart`)
- **Location:** Header greeting
- **Fetches from:** Firestore `users` collection
- **Default:** "User" if not found
- **Code:**
```dart
Future<void> _loadUserProfile() async {
  final profile = await _authService.getUserProfile();
  setState(() {
    _userName = profile['name'] ?? 'User';  // Shows "User" if null
    _userFlat = profile['flatNumber'] ?? 'Not Set';
  });
}
```

### 2. Profile Screen (`profile_screen.dart`)
- **Location:** Profile header
- **Fetches from:** Firestore `users` collection
- **Default:** "User" if not found
- **Code:**
```dart
String get _userName => _userProfile?['name'] ?? 'User';
```

### 3. Edit Profile Screen (`edit_profile_screen.dart`)
- **Location:** Form fields
- **Fetches from:** Firestore `users` collection
- **Default:** Empty string if not found
- **Code:**
```dart
_nameController.text = profile['name'] ?? '';
```

### 4. Community Wall Posts (`post_firestore_service.dart`)
- **Location:** Post author name
- **Fetches from:** Firestore `users` collection
- **Default:** "Unknown User" if not found
- **Code:**
```dart
'authorName': userData?['name'] ?? 'Unknown User',
```

### 5. Complaints (`complaint_firestore_service.dart`)
- **Location:** Complaint submitter name
- **Default:** "Unknown User" if not found

### 6. Bookings (`booking_firestore_service.dart`)
- **Location:** Booking user name
- **Default:** "Unknown User" if not found

### 7. Visitors (`visitor_firestore_service.dart`)
- **Location:** Visitor host name
- **Default:** "Unknown User" if not found

## The Solution

### Step 1: Fix the authUid in Firestore

**This is the MOST IMPORTANT step!**

1. Go to Firebase Console: https://console.firebase.google.com/
2. Select project: `lyvo-app`
3. Go to Authentication → Users
4. Find: `preethampriyatharson07@gmail.com`
5. **Copy the UID** (e.g., `T7hNDCpFF1KTm1d4TvOw`)
6. Go to Firestore Database → `users` collection
7. Find the document for this user
8. Update field `authUid`: change from `null` to the UID you copied
9. Click "Update"

### Step 2: Verify User Data Structure

Make sure your Firestore `users` document has this structure:

```json
{
  "uid": "T7hNDCpFF1KTm1d4TvOw",
  "authUid": "T7hNDCpFF1KTm1d4TvOw",  // MUST match Firebase Auth UID
  "email": "preethampriyatharson07@gmail.com",
  "name": "preetham",  // This is what displays
  "phone": "7010678124",
  "flatNumber": "b202",
  "flatLabel": "b202",
  "residentId": "RBS2393",
  "role": "resident",
  "status": "active",
  "familyMembers": 2,
  "ownershipType": "Owner",
  "createdAt": "timestamp",
  "updatedAt": "timestamp"
}
```

### Step 3: Test

After fixing the `authUid`:

1. Hot restart the app (press `R`)
2. Login with email or phone
3. Check these screens:
   - ✅ Dashboard: Should show "Hello, preetham"
   - ✅ Profile: Should show "preetham"
   - ✅ Edit Profile: Should show "preetham" in name field
   - ✅ Community Wall posts: Should show "preetham" as author
   - ✅ Complaints: Should show "preetham" as submitter

## How Data Fetching Works

### Firebase Auth Service Method

```dart
Future<Map<String, dynamic>?> getUserProfile() async {
  try {
    final user = _auth.currentUser;  // Get current Firebase Auth user
    if (user == null) return null;

    // Fetch from Firestore using the user's UID
    final doc = await _firestore
        .collection('users')
        .doc(user.uid)  // Uses Firebase Auth UID
        .get();

    if (doc.exists) {
      return doc.data();  // Returns user data including 'name'
    }
    return null;
  } catch (e) {
    print('❌ Error fetching user profile: $e');
    return null;
  }
}
```

### Why It Fails

1. User logs in with Firebase Auth → Gets UID: `ABC123`
2. App tries to fetch from Firestore: `users/ABC123`
3. But the document is at `users/XYZ789` (wrong UID)
4. Document not found → Returns null
5. App shows "Unknown User" or "User"

### After Fix

1. User logs in with Firebase Auth → Gets UID: `ABC123`
2. App tries to fetch from Firestore: `users/ABC123`
3. Document exists at `users/ABC123` ✅
4. Returns: `{ name: "preetham", ... }`
5. App shows "preetham" ✅

## For Admin Panel - Proper User Creation

When admin creates a user, ensure this flow:

```dart
Future<void> createUserByAdmin({
  required String email,
  required String password,
  required String name,
  required String phone,
  required String flatNumber,
}) async {
  // Step 1: Create in Firebase Auth
  final userCredential = await FirebaseAuth.instance
      .createUserWithEmailAndPassword(
    email: email,
    password: password,
  );
  
  final uid = userCredential.user!.uid;
  
  // Step 2: Create in Firestore with SAME UID
  await FirebaseFirestore.instance
      .collection('users')
      .doc(uid)  // IMPORTANT: Use Firebase Auth UID as document ID
      .set({
    'uid': uid,
    'authUid': uid,  // IMPORTANT: Store the auth UID
    'email': email,
    'name': name,  // This is what displays everywhere
    'phone': phone,
    'flatNumber': flatNumber,
    'role': 'resident',
    'status': 'active',
    'createdAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
  });
}
```

## Troubleshooting

### Still showing "Unknown User"?

**Check 1: Is user logged in?**
```dart
final user = FirebaseAuth.instance.currentUser;
print('Current user: ${user?.uid}');
```

**Check 2: Does Firestore document exist?**
- Go to Firestore → `users` collection
- Look for document with ID matching the Firebase Auth UID
- Check if `name` field exists and has a value

**Check 3: Is authUid correct?**
- The `authUid` field must match the Firebase Auth UID
- The document ID must also match the Firebase Auth UID

**Check 4: Check console logs**
- Look for errors like "Error fetching user profile"
- Check if the UID being used is correct

### Name field is empty in Firestore?

Update it manually:
1. Firestore → `users` collection
2. Find the user document
3. Edit `name` field
4. Set value to the user's actual name
5. Click "Update"

## Quick Checklist

- [ ] Firebase Auth user exists
- [ ] Firestore `users` document exists
- [ ] Document ID matches Firebase Auth UID
- [ ] `authUid` field matches Firebase Auth UID
- [ ] `name` field has a value (not null or empty)
- [ ] Hot restart app
- [ ] Login and check all screens
- [ ] ✅ User name displays correctly everywhere

## Status

Once you fix the `authUid` field in Firestore, the user name will display correctly in:
- ✅ Dashboard header
- ✅ Profile screen
- ✅ Edit Profile form
- ✅ Community Wall posts
- ✅ Complaints
- ✅ Bookings
- ✅ Visitor management
- ✅ All other screens

The code is already correct - it just needs the proper data in Firestore!
