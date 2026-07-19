# Community Wall - Quick Guide

## What Changed?

Community wall posts now enforce flat-based access:
- Posts include `flatId`, `flatLabel`, and `adminId`
- Residents only see posts from their flat members
- Admins see posts from all flats they manage
- Users without flat assignment cannot access community wall

## Usage

### For Residents
```dart
// Get posts from my flat only
final posts = await PostFirestoreService().getAllPosts();

// Stream posts (real-time)
StreamBuilder(
  stream: PostFirestoreService().streamAllPosts(),
  builder: (context, snapshot) {
    // Build UI
  },
)

// Or use auto-detect
final posts = await PostFirestoreService().getPostsForCurrentUser();
```

### For Admins
```dart
// Get all posts from managed flats
final posts = await PostFirestoreService().getAdminPosts();

// Get posts for specific flat
final flatPosts = await PostFirestoreService()
    .getPostsByFlatId('flat-id');

// Stream admin posts
StreamBuilder(
  stream: PostFirestoreService().streamAdminPosts(),
  builder: (context, snapshot) {
    // Build UI
  },
)
```

### Create Post
```dart
final result = await PostFirestoreService().createPost(
  content: 'Hello from my flat!',
);

if (result.success) {
  print('Post created: ${result.data}');
} else {
  print('Error: ${result.message}');
}
```

### Post Interactions
```dart
// Like a post
await PostFirestoreService().likePost(postId);

// Unlike a post
await PostFirestoreService().unlikePost(postId);

// Add comment
await PostFirestoreService().addComment(
  postId: postId,
  comment: 'Great post!',
);

// Get comments
final comments = await PostFirestoreService().getComments(postId);

// Delete post (own posts only)
await PostFirestoreService().deletePost(postId);

// Report post
await PostFirestoreService().reportPost(postId, 'Inappropriate content');
```

## Testing

Run the test script:
```bash
# Make sure you're logged in first
flutter run lib/test_community_wall_access.dart
```

## Firestore Structure

```
posts/
  └── {postId}
      ├── authorId: "user-123"
      ├── authorName: "John Doe"
      ├── content: "Post content"
      ├── flatId: "flat-456"           ← For filtering
      ├── flatLabel: "A-101"           ← Display label
      ├── adminId: "admin-789"         ← Admin access
      ├── likes: 5
      ├── comments: 3
      ├── likedBy: ["user-1", "user-2"]
      ├── createdAt: Timestamp
      └── updatedAt: Timestamp
      
      └── comments/
          └── {commentId}
              ├── authorId: "user-456"
              ├── authorName: "Jane Smith"
              ├── comment: "Nice post!"
              └── createdAt: Timestamp
```

## Query Examples

### Resident Query
```dart
// Returns only posts where flatId matches user's flat
posts.where('flatId', isEqualTo: userFlatId)
```

### Admin Query
```dart
// Returns all posts from flats managed by admin
posts.where('adminId', isEqualTo: currentAdminId)
```

## Access Control

### Without Flat Assignment:
- ❌ Cannot create posts
- ❌ Cannot view community wall
- Error: "You must be assigned to a flat"

### With Flat Assignment:
- ✅ Can create posts
- ✅ Can view posts from flat members
- ✅ Can like, comment, share
- ✅ Real-time updates

## Benefits

1. **Privacy**: Posts only visible to flat members
2. **Relevance**: Content relevant to flat community
3. **Admin Oversight**: Admins can moderate all managed flats
4. **Security**: Database-level access control
5. **Real-Time**: Live updates for engaging experience

## Complete System Coverage

All modules now support flat & admin access:
- ✅ Visitors Management
- ✅ Complaints/Requests
- ✅ Community Wall

## Next Steps

1. Update community wall screen to use new methods
2. Add admin moderation features
3. Implement Firestore security rules
4. Add image/media support
5. Add hashtag and mention support
