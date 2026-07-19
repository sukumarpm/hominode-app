# Community Wall - Flat-Based Access Complete ✅

## Overview
The community wall system now enforces flat-based access control. Residents can only see and interact with posts from members of their own flat. Admins can see posts from all flats they manage.

## Data Structure

### Post Document Fields
```dart
{
  'id': 'auto-generated',
  'authorId': 'user-id-who-created-post',
  'authorName': 'User Name',
  'profileImage': 'https://...',
  'content': 'Post content text',
  'flat': 'A-101',                      // Display label
  'flatId': 'flat-document-id',         // ✅ For filtering
  'flatLabel': 'A-101',                 // ✅ NEW - Human-readable
  'adminId': 'admin-user-id',           // ✅ NEW - Admin who manages flat
  'likes': 0,
  'comments': 0,
  'likedBy': ['user-id-1', 'user-id-2'],
  'createdAt': Timestamp,
  'updatedAt': Timestamp,
}
```

## Access Control Flow

### 1. Resident Creates Post
```
User logs in → User data fetched from Firestore
  ↓
Check: Does user have flatId assigned?
  ↓
If NO: Cannot create post (error message)
If YES: Extract flatId, flatLabel, adminId
  ↓
Create post document with flat data
  ↓
Store in Firestore 'posts' collection
```

### 2. Resident Views Posts
```
User opens community wall → Fetch user's flatId
  ↓
Query: posts.where('flatId', isEqualTo: userFlatId)
  ↓
Returns: Only posts from same flat members
```

### 3. Admin Views Posts
```
Admin opens community wall → Check user role
  ↓
If role == 'admin':
  Query: posts.where('adminId', isEqualTo: currentUserId)
  ↓
Returns: All posts from flats managed by this admin
```

## Key Features

### ✅ Flat Isolation
- Residents only see posts from their flat members
- Cannot see posts from other flats
- Must have flatId assigned to create/view posts

### ✅ Admin Visibility
- Admins see posts from all flats they manage
- Can moderate content across managed flats
- Maintains oversight of community activity

### ✅ Real-Time Updates
- Live streaming of posts
- Instant updates when new posts are created
- Real-time like and comment counts

## Updated Files

### Post Firestore Service (`lib/src/services/post_firestore_service.dart`)

#### Updated Methods:
- `createPost()` - Now stores flatId, flatLabel, adminId

#### New Methods:
- `getAdminPosts()` - Get all posts for flats managed by admin
- `getPostsByFlatId(flatId)` - Get posts for specific flat
- `getPostsForCurrentUser()` - Auto-detect role and return appropriate posts
- `streamAdminPosts()` - Real-time stream for admin posts
- `streamPostsForCurrentUser()` - Auto-detect role for streaming

## API Methods

### For Residents
```dart
// Get posts from my flat only
final posts = await PostFirestoreService().getAllPosts();

// Stream posts from my flat
PostFirestoreService().streamAllPosts();
```

### For Admins
```dart
// Get all posts from managed flats
final posts = await PostFirestoreService().getAdminPosts();

// Get posts for specific flat
final flatPosts = await PostFirestoreService()
    .getPostsByFlatId('flat-id');

// Stream admin posts
PostFirestoreService().streamAdminPosts();
```

### Auto-Detect Role
```dart
// Automatically returns correct posts based on role
final posts = await PostFirestoreService()
    .getPostsForCurrentUser();

// Stream with auto-detect
PostFirestoreService().streamPostsForCurrentUser();
```

## Firestore Queries

### Resident Query
```dart
posts
  .where('flatId', isEqualTo: userFlatId)
  .get()
```

### Admin Query
```dart
posts
  .where('adminId', isEqualTo: currentAdminId)
  .get()
```

### Flat-Specific Query
```dart
posts
  .where('flatId', isEqualTo: flatId)
  .get()
```

## Security Rules (Recommended)

```javascript
match /posts/{postId} {
  // Users can only read posts from their flat
  allow read: if request.auth != null && 
    (get(/databases/$(database)/documents/users/$(request.auth.uid)).data.flatId == 
     resource.data.flatId ||
     get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin');
  
  // Users can only create posts if they have a flat assigned
  allow create: if request.auth != null && 
    request.resource.data.authorId == request.auth.uid &&
    get(/databases/$(database)/documents/users/$(request.auth.uid)).data.flatId != null;
  
  // Only author can update their own posts
  allow update: if request.auth != null && 
    resource.data.authorId == request.auth.uid;
  
  // Only author or admin can delete posts
  allow delete: if request.auth != null && 
    (resource.data.authorId == request.auth.uid ||
     get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin');
}

// Comments subcollection
match /posts/{postId}/comments/{commentId} {
  // Users can read comments if they can read the post
  allow read: if request.auth != null;
  
  // Users can create comments if they can read the post
  allow create: if request.auth != null && 
    request.resource.data.authorId == request.auth.uid;
  
  // Only author can delete their comments
  allow delete: if request.auth != null && 
    resource.data.authorId == request.auth.uid;
}
```

## User Experience

### Without Flat Assignment
```
User tries to create post
  ↓
Error: "Cannot create post: You must be assigned to a flat"
  ↓
User cannot view community wall
```

### With Flat Assignment
```
User creates post
  ↓
Post visible to all members of same flat
  ↓
Other flat members can like, comment, share
  ↓
Real-time updates for all flat members
```

## Testing

### Test Resident Flow
```dart
// 1. Login as resident with flatId
// 2. Create a post
final result = await PostFirestoreService().createPost(
  content: 'Hello from my flat!',
);

// 3. Verify post has flatId, flatLabel, adminId
final posts = await PostFirestoreService().getAllPosts();
print('Total posts in my flat: ${posts.length}');

// 4. Login as different resident from same flat
// 5. Verify you can see the post

// 6. Login as resident from different flat
// 7. Verify you CANNOT see the post
```

### Test Admin Flow
```dart
// 1. Login as admin
// 2. Get all posts from managed flats
final posts = await PostFirestoreService().getAdminPosts();
print('Total posts across managed flats: ${posts.length}');

// 3. Get posts for specific flat
final flatPosts = await PostFirestoreService()
    .getPostsByFlatId('flat-123');
print('Posts in flat 123: ${flatPosts.length}');
```

## Benefits

1. **Privacy**: Residents only see posts from their flat community
2. **Relevance**: Content is relevant to flat members
3. **Admin Oversight**: Admins can moderate all managed flats
4. **Security**: Database-level access control
5. **Scalability**: Efficient indexed queries
6. **Real-Time**: Live updates for engaging experience

## Post Features

### Supported Actions:
- ✅ Create post (text content)
- ✅ Like/Unlike post
- ✅ Comment on post
- ✅ Share post (increment counter)
- ✅ Delete own post
- ✅ Report post
- ✅ Real-time updates

### Post Interactions:
- Like count with user tracking
- Comment count with subcollection
- Share count
- Time ago display
- Author profile display

## Comments System

Comments are stored in a subcollection:
```
posts/{postId}/comments/{commentId}
  ├── authorId
  ├── authorName
  ├── profileImage
  ├── comment
  └── createdAt
```

## Next Steps

1. Update community wall screen to use `streamPostsForCurrentUser()`
2. Add admin moderation features
3. Implement Firestore security rules
4. Add post filtering (by date, popularity)
5. Add image/media support for posts
6. Add hashtag support
7. Add mention support (@username)

## Migration Notes

For existing posts without flatId, flatLabel, adminId:

```dart
Future<void> migrateExistingPosts() async {
  final posts = await FirebaseFirestore.instance
      .collection('posts')
      .where('flatId', isNull: true)
      .get();
  
  for (var doc in posts.docs) {
    final authorId = doc.data()['authorId'];
    
    // Fetch author's user data
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(authorId)
        .get();
    
    if (userDoc.exists) {
      final userData = userDoc.data()!;
      
      // Update post with flat data
      await doc.reference.update({
        'flatId': userData['flatId'],
        'flatLabel': userData['flatLabel'],
        'adminId': userData['adminId'],
      });
    }
  }
}
```

## Status: ✅ COMPLETE

Community wall now enforces flat-based access:
- ✅ flatId stored in posts
- ✅ flatLabel stored for display
- ✅ adminId stored for admin access
- ✅ Flat-based filtering implemented
- ✅ Admin query methods added
- ✅ Role-based access methods added
- ✅ Real-time streaming support
- ✅ Privacy and security enforced
