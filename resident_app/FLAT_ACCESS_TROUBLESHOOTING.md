# Flat-Based Access - Troubleshooting Guide

## Common Issues and Solutions

---

## Issue 1: Empty Lists (No Posts/Listings Showing)

### Symptoms
- User has flat assigned
- Community Wall shows empty
- Marketplace shows empty
- Console shows "Fetched 0 posts"

### Possible Causes

#### A. No Data in Firestore
**Check**: Open Firebase Console → Firestore → Check `posts` and `listings` collections

**Solution**: Create test data
```json
// Add to posts collection
{
  "authorId": "user123",
  "authorName": "Test User",
  "flatId": "1402",
  "content": "Test post",
  "likes": 0,
  "comments": 0,
  "createdAt": "timestamp"
}
```

#### B. FlatId Mismatch
**Check**: User's flatId doesn't match data flatId

**Debug**:
```dart
// Add to service
final userData = await _usersCollection.doc(_currentUserId).get();
print('User flatId: ${userData.data()?['flatId']}');

final posts = await _postsCollection.get();
posts.docs.forEach((doc) {
  print('Post flatId: ${doc.data()['flatId']}');
});
```

**Solution**: Ensure flatId values match exactly (case-sensitive)

#### C. FlatId Field Missing
**Check**: Old data doesn't have flatId field

**Solution**: Update existing data in Firestore
```javascript
// Firebase Console → Firestore
// For each post/listing without flatId:
// Add field: flatId = "1402"
```

---

## Issue 2: Cannot Create Posts/Listings

### Symptoms
- Error: "Cannot create post: You must be assigned to a flat"
- User thinks they have flat assigned

### Possible Causes

#### A. FlatId is Empty String
**Check**: User document has `flatId: ""`

**Debug**:
```dart
final userData = await UserDataService().getCurrentUserData();
print('FlatId value: "${userData?['flatId']}"');
print('FlatId is empty: ${userData?['flatId']?.toString().isEmpty}');
```

**Solution**: Update user document in Firestore
```json
{
  "flatId": "1402"  // Not empty string
}
```

#### B. FlatId is Null
**Check**: User document missing flatId field

**Solution**: Add flatId field to user document

#### C. Wrong Field Name
**Check**: Using `flat` instead of `flatId`

**Solution**: Ensure field name is exactly `flatId`

---

## Issue 3: Seeing Content from Other Flats

### Symptoms
- User in flat 1402 sees posts from flat 1403
- Filtering not working

### Possible Causes

#### A. Query Not Using FlatId
**Check**: Service code is using correct query

**Debug**: Check console logs
```
Should see: "Fetching posts for flat: 1402"
Should NOT see: "Fetching all posts..."
```

**Solution**: Verify service code has `.where('flatId', isEqualTo: userFlatId)`

#### B. Multiple Users Logged In
**Check**: Different user logged in than expected

**Debug**:
```dart
final user = FirebaseAuth.instance.currentUser;
print('Current user: ${user?.uid}');
```

**Solution**: Logout and login with correct user

---

## Issue 4: Error Messages Not Showing

### Symptoms
- Operation fails silently
- No error message displayed

### Possible Causes

#### A. Context Not Available
**Check**: SnackBar needs BuildContext

**Solution**: Ensure context is passed to error handler
```dart
if (!result.success) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(result.message ?? 'Error')),
  );
}
```

#### B. Error Not Caught
**Check**: Try-catch block missing

**Solution**: Add error handling
```dart
try {
  final result = await service.createPost(content: content);
  if (!result.success) {
    _showError(result.message);
  }
} catch (e) {
  _showError('Failed to create post');
  print('Error: $e');
}
```

---

## Issue 5: Firestore Permission Denied

### Symptoms
- Error: "PERMISSION_DENIED"
- Cannot read/write data

### Possible Causes

#### A. Firestore Rules Too Restrictive
**Check**: Firebase Console → Firestore → Rules

**Temporary Solution** (Development Only):
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

**Production Solution**: See `FLAT_BASED_ACCESS_COMPLETE.md` for proper rules

#### B. User Not Authenticated
**Check**: User is logged in

**Debug**:
```dart
final user = FirebaseAuth.instance.currentUser;
print('Authenticated: ${user != null}');
```

---

## Issue 6: Data Not Updating in Real-Time

### Symptoms
- Create post but doesn't appear
- Need to refresh manually

### Possible Causes

#### A. Using Get Instead of Stream
**Check**: Screen is using `getAllPosts()` instead of `streamAllPosts()`

**Solution**: Use stream for real-time updates
```dart
// Instead of:
final posts = await service.getAllPosts();

// Use:
StreamBuilder<List<Post>>(
  stream: service.streamAllPosts(),
  builder: (context, snapshot) {
    // ...
  },
)
```

#### B. Not Refreshing After Create
**Check**: Screen doesn't reload after creating

**Solution**: Call refresh after create
```dart
await service.createPost(content: content);
_loadPosts(); // Refresh list
```

---

## Debugging Commands

### Check User Data
```dart
final userData = await UserDataService().getCurrentUserData();
print('=== USER DATA ===');
print('UID: ${userData?['uid']}');
print('Name: ${userData?['name']}');
print('FlatId: ${userData?['flatId']}');
print('Status: ${userData?['status']}');
print('Role: ${userData?['role']}');
```

### Check Posts Query
```dart
final userDoc = await _usersCollection.doc(_currentUserId).get();
final userFlatId = userDoc.data()?['flatId'];
print('=== QUERY DEBUG ===');
print('User FlatId: $userFlatId');

final querySnapshot = await _postsCollection
    .where('flatId', isEqualTo: userFlatId)
    .get();
print('Posts found: ${querySnapshot.docs.length}');

querySnapshot.docs.forEach((doc) {
  final data = doc.data();
  print('Post: ${doc.id}');
  print('  FlatId: ${data['flatId']}');
  print('  Content: ${data['content']}');
});
```

### Check Validation
```dart
final validator = UserValidationService();
print('=== VALIDATION ===');
print('Has Flat: ${await validator.hasFlat()}');
print('Is Active: ${await validator.isActive()}');
print('Can Access: ${await validator.canAccessFlatData()}');
print('Flat ID: ${await validator.getUserFlatId()}');
```

---

## Test Data Setup

### Create Test User with Flat
```json
// Firestore → users collection → Add document
{
  "uid": "test_user_1",
  "name": "Test User 1",
  "email": "test1@example.com",
  "phone": "1111111111",
  "password": "test123",
  "flatId": "1402",
  "flatLabel": "1402",
  "role": "resident",
  "status": "active",
  "createdAt": "2024-01-01T00:00:00Z"
}
```

### Create Test Post
```json
// Firestore → posts collection → Add document
{
  "authorId": "test_user_1",
  "authorName": "Test User 1",
  "flatId": "1402",
  "content": "Test post for flat 1402",
  "likes": 0,
  "comments": 0,
  "likedBy": [],
  "createdAt": "2024-01-01T00:00:00Z"
}
```

### Create Test Listing
```json
// Firestore → listings collection → Add document
{
  "sellerId": "test_user_1",
  "sellerName": "Test User 1",
  "flatId": "1402",
  "title": "Test Item",
  "price": 1000,
  "category": "Furniture",
  "condition": "Good",
  "description": "Test listing",
  "images": [],
  "status": "active",
  "createdAt": "2024-01-01T00:00:00Z"
}
```

---

## Console Log Patterns

### Normal Operation
```
📥 Fetching posts for flat: 1402
✅ Fetched 5 posts for flat 1402
📝 Creating post...
   Flat ID: 1402
✅ Post created with ID: abc123
🔍 User flat check: Has flat (1402)
🔍 Flat data access check: ALLOWED
```

### Error: No Flat
```
❌ User has no flat assigned - cannot access posts
❌ Cannot create post: You must be assigned to a flat
🔍 User flat check: No flat assigned
🔍 Flat data access check: DENIED
```

### Error: Firestore
```
❌ Error fetching posts: [cloud_firestore/permission-denied]
❌ Error creating post: Missing or insufficient permissions
```

---

## Quick Fixes

### Fix 1: Reset User Flat
```dart
// In Firebase Console or code
await FirebaseFirestore.instance
    .collection('users')
    .doc(userId)
    .update({'flatId': '1402'});
```

### Fix 2: Add FlatId to Existing Data
```javascript
// Firebase Console → Firestore → Run query
// For each post/listing:
db.collection('posts').get().then(snapshot => {
  snapshot.docs.forEach(doc => {
    doc.ref.update({flatId: '1402'});
  });
});
```

### Fix 3: Clear Cache
```dart
// In app
await UserDataService().getCurrentUserData(forceRefresh: true);
```

---

## When to Contact Support

Contact if:
- ❌ Followed all steps but still not working
- ❌ Console shows unexpected errors
- ❌ Firestore rules are blocking access
- ❌ Data structure is corrupted

Provide:
- Console logs
- User document screenshot
- Post/listing document screenshot
- Steps to reproduce

---

## Useful Links

- Firebase Console: https://console.firebase.google.com
- Firestore Documentation: https://firebase.google.com/docs/firestore
- Flutter Firebase: https://firebase.flutter.dev

---

**Last Updated**: February 23, 2026
**Status**: Active Troubleshooting Guide
