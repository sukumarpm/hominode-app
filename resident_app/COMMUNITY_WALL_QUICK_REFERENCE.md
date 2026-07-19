# Community Wall - Building Members - Quick Reference

## What Changed

**Community Wall now allows all building members to access and chat together.**

### Key Changes
- Posts filtered by `buildingId` (not `flatId`)
- All residents in same building can see posts
- Building members can create, like, and comment on posts
- Real-time updates for all building members

---

## Flow Function

### 1. Authentication
```
User logs in → Get Firebase Auth UID → Query users by authUid → Get user document with buildingId
```

### 2. Create Post
```
User clicks "Add Post" → Get current user ID → Fetch user data → Validate buildingId exists → 
Create post with buildingId → Store in Firestore → Show success
```

### 3. Fetch Posts
```
User opens Community Wall → Get current user ID → Fetch user data → Get buildingId → 
Query posts WHERE buildingId = user's buildingId → Display posts
```

### 4. Real-Time Updates
```
Listen to user document → Get buildingId → Stream posts WHERE buildingId = user's buildingId → 
Update UI when new posts added
```

---

## Database Structure

### Post Document
```json
{
  "content": "Hello building members!",
  "authorId": "user_doc_id",
  "authorName": "John Doe",
  "buildingId": "building_001",        ← For filtering
  "buildingName": "Lyvo Towers",
  "flatId": "flat_1402",               ← For reference
  "flatLabel": "1402",
  "likes": 5,
  "comments": 2,
  "likedBy": ["user_id_1", "user_id_2"],
  "createdAt": "timestamp",
  "updatedAt": "timestamp"
}
```

---

## Methods

| Method | Purpose | Filter |
|--------|---------|--------|
| `createPost()` | Create new post | Validates buildingId |
| `getAllPosts()` | Fetch building posts | WHERE buildingId = user's buildingId |
| `getAdminPosts()` | Fetch admin's building posts | WHERE buildingId = admin's buildingId |
| `getPostsByBuildingId()` | Fetch posts for specific building | WHERE buildingId = specified |
| `streamAllPosts()` | Real-time building posts | WHERE buildingId = user's buildingId |
| `streamAdminPosts()` | Real-time admin posts | WHERE buildingId = admin's buildingId |

---

## Console Logs

### Success
```
📝 Creating post...
✅ Post created with ID: abc123
   Building ID: building_001
   Building Name: Lyvo Towers

📥 Fetching posts for building: building_001
✅ Fetched 8 posts for building building_001
```

### Error
```
❌ User has no building assigned - cannot access posts
❌ Cannot create post: You must be assigned to a building
```

---

## Testing

### Test 1: Create Post
1. Login as user in building_001
2. Open Community Wall
3. Click "Add Post"
4. Enter content and post
5. Verify post appears

### Test 2: View Building Posts
1. Login as user in building_001
2. Open Community Wall
3. Verify posts from building_001 shown
4. Verify posts from other buildings NOT shown

### Test 3: Real-Time Updates
1. User A opens Community Wall
2. User B (same building) creates post
3. Verify post appears instantly on User A's screen

### Test 4: Like/Comment
1. Open Community Wall
2. Like a post
3. Add a comment
4. Verify updates appear

---

## Files Modified

- ✅ `lib/src/services/post_firestore_service.dart`
  - Updated all methods to use buildingId
  - Added buildingId validation
  - Updated queries and streams

---

## Status

✅ **COMPLETE** - Ready for testing

All building members can now:
- ✅ Access Community Wall
- ✅ Create posts
- ✅ Like posts
- ✅ Comment on posts
- ✅ See real-time updates
- ✅ Chat with all building members
