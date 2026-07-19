# Flat-Based Data Access Requirements

## Overview

Only admin-registered flat members can access data. Users can only see data from their own flat, not from other flats.

## Access Rules

### 1. User Registration
- ✅ Only admin can register users
- ✅ Admin assigns user to a flat
- ✅ User must have `flatId` field in Firestore
- ❌ Users without flat assignment cannot access data

### 2. Data Access by Flat

#### Community Wall
- ✅ User can see posts from their flat only
- ❌ User cannot see posts from other flats
- Query: `where('flatId', '==', userFlatId)`

#### Marketplace
- ✅ User can see listings from their flat only
- ❌ User cannot see listings from other flats
- Query: `where('flatId', '==', userFlatId)`

#### Messages
- ✅ User can see messages for their flat only
- ❌ User cannot see messages from other flats
- Query: `where('flatId', '==', userFlatId)`

### 3. User Validation
- ✅ Check if user has `flatId` assigned
- ✅ Check if user `status` is 'active'
- ✅ Check if user `role` is 'resident'
- ❌ Block access if any validation fails

## Implementation

### Step 1: Update Firestore Security Rules

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Helper function to check if user is authenticated
    function isAuthenticated() {
      return request.auth != null;
    }
    
    // Helper function to get user data
    function getUserData() {
      return get(/databases/$(database)/documents/users/$(request.auth.uid)).data;
    }
    
    // Helper function to check if user has flat assigned
    function hasFlat() {
      return getUserData().flatId != null && getUserData().flatId != '';
    }
    
    // Helper function to check if user is active
    function isActive() {
      return getUserData().status == 'active';
    }
    
    // Helper function to get user's flat ID
    function getUserFlatId() {
      return getUserData().flatId;
    }
    
    // Users collection
    match /users/{userId} {
      allow read: if isAuthenticated() && request.auth.uid == userId;
      allow write: if isAuthenticated() && request.auth.uid == userId;
    }
    
    // Community Wall Posts - Flat-based access
    match /posts/{postId} {
      allow read: if isAuthenticated() 
                  && hasFlat() 
                  && isActive()
                  && resource.data.flatId == getUserFlatId();
      
      allow create: if isAuthenticated() 
                    && hasFlat() 
                    && isActive()
                    && request.resource.data.flatId == getUserFlatId();
      
      allow update, delete: if isAuthenticated() 
                             && hasFlat()
                             && resource.data.userId == request.auth.uid;
    }
    
    // Marketplace Listings - Flat-based access
    match /listings/{listingId} {
      allow read: if isAuthenticated() 
                  && hasFlat() 
                  && isActive()
                  && resource.data.flatId == getUserFlatId();
      
      allow create: if isAuthenticated() 
                    && hasFlat() 
                    && isActive()
                    && request.resource.data.flatId == getUserFlatId();
      
      allow update, delete: if isAuthenticated() 
                             && hasFlat()
                             && resource.data.userId == request.auth.uid;
    }
    
    // Messages - Flat-based access
    match /messages/{messageId} {
      allow read: if isAuthenticated() 
                  && hasFlat() 
                  && isActive()
                  && resource.data.flatId == getUserFlatId();
      
      allow create: if isAuthenticated() 
                    && hasFlat() 
                    && isActive()
                    && request.resource.data.flatId == getUserFlatId();
    }
    
    // Other collections (accessible to all authenticated users)
    match /notices/{noticeId} {
      allow read: if isAuthenticated();
    }
    
    match /events/{eventId} {
      allow read: if isAuthenticated();
    }
    
    match /announcements/{announcementId} {
      allow read: if isAuthenticated();
    }
  }
}
```

### Step 2: Update Services to Filter by Flat

#### Community Wall Service

```dart
// lib/src/services/post_firestore_service.dart

Future<List<Post>> getPosts() async {
  try {
    // Get current user's flat ID
    final userData = await UserDataService().getCurrentUserData();
    final userFlatId = userData?['flatId'];
    
    if (userFlatId == null || userFlatId.isEmpty) {
      print('❌ User has no flat assigned');
      return [];
    }
    
    print('📥 Fetching posts for flat: $userFlatId');
    
    // Query posts for user's flat only
    final querySnapshot = await _firestore
        .collection('posts')
        .where('flatId', isEqualTo: userFlatId)
        .orderBy('createdAt', descending: true)
        .get();
    
    return querySnapshot.docs
        .map((doc) => Post.fromFirestore(doc))
        .toList();
  } catch (e) {
    print('❌ Error fetching posts: $e');
    return [];
  }
}
```

#### Marketplace Service

```dart
// lib/src/services/listing_firestore_service.dart

Future<List<Listing>> getListings() async {
  try {
    // Get current user's flat ID
    final userData = await UserDataService().getCurrentUserData();
    final userFlatId = userData?['flatId'];
    
    if (userFlatId == null || userFlatId.isEmpty) {
      print('❌ User has no flat assigned');
      return [];
    }
    
    print('📥 Fetching listings for flat: $userFlatId');
    
    // Query listings for user's flat only
    final querySnapshot = await _firestore
        .collection('listings')
        .where('flatId', isEqualTo: userFlatId)
        .where('status', isEqualTo: 'active')
        .orderBy('createdAt', descending: true)
        .get();
    
    return querySnapshot.docs
        .map((doc) => Listing.fromFirestore(doc))
        .toList();
  } catch (e) {
    print('❌ Error fetching listings: $e');
    return [];
  }
}
```

#### Messages Service

```dart
// lib/src/services/message_service.dart

Future<List<Message>> getMessages() async {
  try {
    // Get current user's flat ID
    final userData = await UserDataService().getCurrentUserData();
    final userFlatId = userData?['flatId'];
    
    if (userFlatId == null || userFlatId.isEmpty) {
      print('❌ User has no flat assigned');
      return [];
    }
    
    print('📥 Fetching messages for flat: $userFlatId');
    
    // Query messages for user's flat only
    final querySnapshot = await _firestore
        .collection('messages')
        .where('flatId', isEqualTo: userFlatId)
        .orderBy('timestamp', descending: true)
        .get();
    
    return querySnapshot.docs
        .map((doc) => Message.fromFirestore(doc))
        .toList();
  } catch (e) {
    print('❌ Error fetching messages: $e');
    return [];
  }
}
```

### Step 3: Add Flat ID When Creating Data

#### Create Post

```dart
Future<bool> createPost(String content, String? imageUrl) async {
  try {
    final userData = await UserDataService().getCurrentUserData();
    final userFlatId = userData?['flatId'];
    
    if (userFlatId == null || userFlatId.isEmpty) {
      print('❌ Cannot create post: User has no flat assigned');
      return false;
    }
    
    await _firestore.collection('posts').add({
      'userId': userData['uid'],
      'userName': userData['name'],
      'flatId': userFlatId,  // Add flat ID
      'content': content,
      'imageUrl': imageUrl,
      'createdAt': FieldValue.serverTimestamp(),
    });
    
    return true;
  } catch (e) {
    print('❌ Error creating post: $e');
    return false;
  }
}
```

#### Create Listing

```dart
Future<bool> createListing(Map<String, dynamic> listingData) async {
  try {
    final userData = await UserDataService().getCurrentUserData();
    final userFlatId = userData?['flatId'];
    
    if (userFlatId == null || userFlatId.isEmpty) {
      print('❌ Cannot create listing: User has no flat assigned');
      return false;
    }
    
    await _firestore.collection('listings').add({
      ...listingData,
      'userId': userData['uid'],
      'userName': userData['name'],
      'flatId': userFlatId,  // Add flat ID
      'createdAt': FieldValue.serverTimestamp(),
    });
    
    return true;
  } catch (e) {
    print('❌ Error creating listing: $e');
    return false;
  }
}
```

### Step 4: Add User Validation Helper

```dart
// lib/src/services/user_validation_service.dart

class UserValidationService {
  static final UserValidationService instance = UserValidationService._internal();
  factory UserValidationService() => instance;
  UserValidationService._internal();
  
  final _userDataService = UserDataService();
  
  /// Check if user has flat assigned
  Future<bool> hasFlat() async {
    final userData = await _userDataService.getCurrentUserData();
    final flatId = userData?['flatId'];
    return flatId != null && flatId.toString().isNotEmpty;
  }
  
  /// Check if user is active
  Future<bool> isActive() async {
    final userData = await _userDataService.getCurrentUserData();
    return userData?['status'] == 'active';
  }
  
  /// Check if user can access flat-based data
  Future<bool> canAccessFlatData() async {
    return await hasFlat() && await isActive();
  }
  
  /// Get user's flat ID
  Future<String?> getUserFlatId() async {
    final userData = await _userDataService.getCurrentUserData();
    return userData?['flatId'];
  }
  
  /// Show error message if user cannot access data
  void showAccessDeniedMessage(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Access denied. Please contact admin to assign you to a flat.'),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 3),
      ),
    );
  }
}
```

## Data Structure

### User Document (Firestore)
```json
{
  "uid": "user123",
  "name": "Preetham",
  "email": "user@example.com",
  "phone": "7010678124",
  "flatId": "1402",           // REQUIRED for data access
  "flatLabel": "1402",
  "residentId": "RES1046",
  "role": "resident",
  "status": "active",         // REQUIRED to be 'active'
  "createdAt": "timestamp",
  "updatedAt": "timestamp"
}
```

### Post Document (Community Wall)
```json
{
  "postId": "post123",
  "userId": "user123",
  "userName": "Preetham",
  "flatId": "1402",           // REQUIRED - matches user's flat
  "content": "Hello neighbors!",
  "imageUrl": "url",
  "createdAt": "timestamp"
}
```

### Listing Document (Marketplace)
```json
{
  "listingId": "listing123",
  "userId": "user123",
  "userName": "Preetham",
  "flatId": "1402",           // REQUIRED - matches user's flat
  "title": "Sofa for sale",
  "price": 5000,
  "status": "active",
  "createdAt": "timestamp"
}
```

### Message Document
```json
{
  "messageId": "msg123",
  "userId": "user123",
  "userName": "Preetham",
  "flatId": "1402",           // REQUIRED - matches user's flat
  "content": "Message text",
  "timestamp": "timestamp"
}
```

## Testing

### Test Scenario 1: User with Flat
```
User: Preetham
Flat: 1402
Status: active

Expected:
✅ Can see posts from flat 1402
✅ Can see listings from flat 1402
✅ Can see messages for flat 1402
❌ Cannot see data from flat 1403
```

### Test Scenario 2: User without Flat
```
User: John
Flat: null
Status: active

Expected:
❌ Cannot see any posts
❌ Cannot see any listings
❌ Cannot see any messages
⚠️  Shows "Access denied" message
```

### Test Scenario 3: Inactive User
```
User: Jane
Flat: 1402
Status: inactive

Expected:
❌ Cannot access data
⚠️  Shows "Account inactive" message
```

## Implementation Checklist

- [ ] Update Firestore Security Rules
- [ ] Update Community Wall Service to filter by flatId
- [ ] Update Marketplace Service to filter by flatId
- [ ] Update Messages Service to filter by flatId
- [ ] Add flatId when creating posts
- [ ] Add flatId when creating listings
- [ ] Add flatId when creating messages
- [ ] Create UserValidationService
- [ ] Add validation checks in screens
- [ ] Test with users from different flats
- [ ] Test with users without flat assignment

## Benefits

1. **Privacy**: Users only see data from their flat
2. **Security**: Firestore rules enforce access control
3. **Scalability**: Works for any number of flats
4. **Admin Control**: Only admin can assign users to flats
5. **Clear Separation**: Each flat has isolated data

---

**Status**: 📋 REQUIREMENTS DOCUMENTED
**Next Step**: Implement Firestore Security Rules
**Priority**: HIGH - Security Feature
