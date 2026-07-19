# Community Wall - Building Members Flow - Visual Guide

## User Journey

```
┌─────────────────────────────────────────────────────────────────┐
│                    USER OPENS COMMUNITY WALL                     │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│              SYSTEM: Get Current User ID                         │
│  - Check Firebase Auth user                                      │
│  - Get Firebase Auth UID                                         │
│  - Query users collection by authUid                             │
│  - Get user document ID                                          │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│              SYSTEM: Fetch User Data                             │
│  - Get user document from Firestore                              │
│  - Extract buildingId                                            │
│  - Extract buildingName                                          │
│  - Extract flatId and flatLabel                                  │
└─────────────────────────────────────────────────────────────────┘
                              ↓
                    ┌─────────┴─────────┐
                    ↓                   ↓
            ┌──────────────┐    ┌──────────────┐
            │ buildingId   │    │ buildingId   │
            │ exists?      │    │ is null?     │
            └──────────────┘    └──────────────┘
                    │                   │
                   YES                  NO
                    ↓                   ↓
            ┌──────────────┐    ┌──────────────┐
            │ Query posts  │    │ Show error   │
            │ WHERE        │    │ "No building │
            │ buildingId = │    │ assigned"    │
            │ user's       │    └──────────────┘
            │ buildingId   │
            └──────────────┘
                    ↓
┌─────────────────────────────────────────────────────────────────┐
│              FIRESTORE: Query Posts                              │
│  Collection: posts                                               │
│  Filter: WHERE buildingId = "building_001"                       │
│  Result: [post1, post2, post3, ...]                              │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│              SYSTEM: Convert to Post Models                      │
│  - Extract post data from Firestore documents                    │
│  - Check if current user liked post                              │
│  - Check if current user is author                               │
│  - Format time ago (e.g., "2 hours ago")                         │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│              SYSTEM: Sort Posts                                  │
│  - Sort by createdAt (newest first)                              │
│  - Display in ListView                                           │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                    UI: Display Posts                             │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │ Post 1                                                  │    │
│  │ Author: John Doe (Flat 1402)                            │    │
│  │ Building: Lyvo Towers                                   │    │
│  │ Content: Hello building members!                        │    │
│  │ 2 hours ago                                             │    │
│  │ ❤️ 5 likes  💬 2 comments  🔗 Share  ⋮ Menu             │    │
│  └─────────────────────────────────────────────────────────┘    │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │ Post 2                                                  │    │
│  │ Author: Jane Smith (Flat 1403)                          │    │
│  │ Building: Lyvo Towers                                   │    │
│  │ Content: Great community!                               │    │
│  │ 1 hour ago                                              │    │
│  │ ❤️ 3 likes  💬 1 comment  🔗 Share  ⋮ Menu              │    │
│  └─────────────────────────────────────────────────────────┘    │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │ Post 3                                                  │    │
│  │ Author: Mike Johnson (Flat 1404)                        │    │
│  │ Building: Lyvo Towers                                   │    │
│  │ Content: Anyone for tennis?                             │    │
│  │ 30 minutes ago                                          │    │
│  │ ❤️ 8 likes  💬 4 comments  🔗 Share  ⋮ Menu             │    │
│  └─────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────┘
                              ↓
                    ┌─────────┴─────────┐
                    ↓                   ↓
            ┌──────────────┐    ┌──────────────┐
            │ User likes   │    │ User creates │
            │ post         │    │ new post     │
            └──────────────┘    └──────────────┘
                    ↓                   ↓
            ┌──────────────┐    ┌──────────────┐
            │ Increment    │    │ Get user ID  │
            │ likes count  │    │ and data     │
            │ Update UI    │    │ Validate     │
            │ Real-time    │    │ buildingId   │
            └──────────────┘    └──────────────┘
                                        ↓
                                ┌──────────────┐
                                │ Create post  │
                                │ with:        │
                                │ - authorId   │
                                │ - buildingId │
                                │ - flatId     │
                                │ - content    │
                                │ - timestamp  │
                                └──────────────┘
                                        ↓
                                ┌──────────────┐
                                │ Store in     │
                                │ Firestore    │
                                │ posts        │
                                │ collection   │
                                └──────────────┘
                                        ↓
                                ┌──────────────┐
                                │ Real-time    │
                                │ update: post │
                                │ appears in   │
                                │ all building │
                                │ members'     │
                                │ screens      │
                                └──────────────┘
```

---

## Real-Time Streaming Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                    USER OPENS COMMUNITY WALL                     │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│              SYSTEM: Start Listening to User Document            │
│  - Listen to users/{userId} document                             │
│  - Watch for changes to buildingId                               │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│              USER DOCUMENT SNAPSHOT RECEIVED                     │
│  - Get buildingId from user document                             │
│  - Start streaming posts for this building                       │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│              SYSTEM: Stream Posts by Building                    │
│  - Listen to posts collection                                    │
│  - Filter: WHERE buildingId = user's buildingId                  │
│  - Real-time updates enabled                                     │
└─────────────────────────────────────────────────────────────────┘
                              ↓
                    ┌─────────┴─────────┐
                    ↓                   ↓
            ┌──────────────┐    ┌──────────────┐
            │ New post     │    │ Post liked   │
            │ created      │    │ by someone   │
            └──────────────┘    └──────────────┘
                    ↓                   ↓
            ┌──────────────┐    ┌──────────────┐
            │ Firestore    │    │ Firestore    │
            │ snapshot     │    │ snapshot     │
            │ received     │    │ received     │
            └──────────────┘    └──────────────┘
                    ↓                   ↓
            ┌──────────────┐    ┌──────────────┐
            │ Convert to   │    │ Update like  │
            │ Post model   │    │ count in UI  │
            │ Add to list  │    │ Real-time    │
            └──────────────┘    └──────────────┘
                    ↓                   ↓
            ┌──────────────┐    ┌──────────────┐
            │ Update UI    │    │ All building │
            │ Insert new   │    │ members see  │
            │ post at top  │    │ update       │
            │ All building │    │ instantly    │
            │ members see  │    └──────────────┘
            │ instantly    │
            └──────────────┘
```

---

## Data Flow Diagram

```
┌──────────────────────────────────────────────────────────────────┐
│                         FIRESTORE DATABASE                        │
├──────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │ users collection                                        │    │
│  │ ┌─────────────────────────────────────────────────────┐ │    │
│  │ │ Document: user_001                                  │ │    │
│  │ │ - authUid: "firebase_uid_123"                       │ │    │
│  │ │ - name: "John Doe"                                  │ │    │
│  │ │ - buildingId: "building_001"  ← KEY FIELD           │ │    │
│  │ │ - flatId: "flat_1402"                               │ │    │
│  │ │ - flatLabel: "1402"                                 │ │    │
│  │ └─────────────────────────────────────────────────────┘ │    │
│  │ ┌─────────────────────────────────────────────────────┐ │    │
│  │ │ Document: user_002                                  │ │    │
│  │ │ - authUid: "firebase_uid_456"                       │ │    │
│  │ │ - name: "Jane Smith"                                │ │    │
│  │ │ - buildingId: "building_001"  ← SAME BUILDING       │ │    │
│  │ │ - flatId: "flat_1403"                               │ │    │
│  │ │ - flatLabel: "1403"                                 │ │    │
│  │ └─────────────────────────────────────────────────────┘ │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                   │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │ posts collection                                        │    │
│  │ ┌─────────────────────────────────────────────────────┐ │    │
│  │ │ Document: post_001                                  │ │    │
│  │ │ - authorId: "user_001"                              │ │    │
│  │ │ - authorName: "John Doe"                            │ │    │
│  │ │ - buildingId: "building_001"  ← FILTER KEY          │ │    │
│  │ │ - buildingName: "Lyvo Towers"                       │ │    │
│  │ │ - flatId: "flat_1402"                               │ │    │
│  │ │ - flatLabel: "1402"                                 │ │    │
│  │ │ - content: "Hello building members!"                │ │    │
│  │ │ - likes: 5                                          │ │    │
│  │ │ - comments: 2                                       │ │    │
│  │ │ - createdAt: "2026-03-12T10:30:00Z"                 │ │    │
│  │ └─────────────────────────────────────────────────────┘ │    │
│  │ ┌─────────────────────────────────────────────────────┐ │    │
│  │ │ Document: post_002                                  │ │    │
│  │ │ - authorId: "user_002"                              │ │    │
│  │ │ - authorName: "Jane Smith"                          │ │    │
│  │ │ - buildingId: "building_001"  ← SAME BUILDING       │ │    │
│  │ │ - buildingName: "Lyvo Towers"                       │ │    │
│  │ │ - flatId: "flat_1403"                               │ │    │
│  │ │ - flatLabel: "1403"                                 │ │    │
│  │ │ - content: "Great community!"                       │ │    │
│  │ │ - likes: 3                                          │ │    │
│  │ │ - comments: 1                                       │ │    │
│  │ │ - createdAt: "2026-03-12T11:00:00Z"                 │ │    │
│  │ └─────────────────────────────────────────────────────┘ │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                   │
└──────────────────────────────────────────────────────────────────┘
                              ↑
                              │
                    ┌─────────┴─────────┐
                    ↓                   ↓
        ┌──────────────────┐  ┌──────────────────┐
        │ User A (John)    │  │ User B (Jane)    │
        │ buildingId:      │  │ buildingId:      │
        │ building_001     │  │ building_001     │
        │                  │  │                  │
        │ Query:           │  │ Query:           │
        │ WHERE buildingId │  │ WHERE buildingId │
        │ = building_001   │  │ = building_001   │
        │                  │  │                  │
        │ Sees:            │  │ Sees:            │
        │ - post_001       │  │ - post_001       │
        │ - post_002       │  │ - post_002       │
        │ - post_003       │  │ - post_003       │
        │ (all building    │  │ (all building    │
        │  posts)          │  │  posts)          │
        └──────────────────┘  └──────────────────┘
```

---

## Query Execution

```
┌─────────────────────────────────────────────────────────────────┐
│                    QUERY EXECUTION FLOW                          │
└─────────────────────────────────────────────────────────────────┘

Step 1: Get Current User
┌─────────────────────────────────────────────────────────────────┐
│ _getCurrentUserId()                                              │
│ - Get Firebase Auth UID: "firebase_uid_123"                      │
│ - Query: users.where("authUid", isEqualTo: "firebase_uid_123")   │
│ - Result: user_001                                               │
└─────────────────────────────────────────────────────────────────┘

Step 2: Get User Data
┌─────────────────────────────────────────────────────────────────┐
│ _usersCollection.doc("user_001").get()                           │
│ - Result: {                                                      │
│     "name": "John Doe",                                          │
│     "buildingId": "building_001",                                │
│     "flatId": "flat_1402",                                       │
│     "flatLabel": "1402"                                          │
│   }                                                              │
└─────────────────────────────────────────────────────────────────┘

Step 3: Query Posts by Building
┌─────────────────────────────────────────────────────────────────┐
│ _postsCollection                                                 │
│   .where("buildingId", isEqualTo: "building_001")                │
│   .get()                                                         │
│                                                                  │
│ Firestore executes:                                              │
│ SELECT * FROM posts WHERE buildingId = "building_001"            │
│                                                                  │
│ Result: [post_001, post_002, post_003, ...]                      │
└─────────────────────────────────────────────────────────────────┘

Step 4: Convert to Post Models
┌─────────────────────────────────────────────────────────────────┐
│ For each post document:                                          │
│ - Extract data                                                   │
│ - Check if current user liked (user_001 in likedBy array?)       │
│ - Check if current user is author (authorId == user_001?)        │
│ - Format time ago                                                │
│ - Create Post model                                              │
└─────────────────────────────────────────────────────────────────┘

Step 5: Sort Posts
┌─────────────────────────────────────────────────────────────────┐
│ Sort by createdAt (newest first)                                 │
│ [post_003, post_002, post_001]                                   │
└─────────────────────────────────────────────────────────────────┘

Step 6: Display in UI
┌─────────────────────────────────────────────────────────────────┐
│ ListView.builder displays posts in order                         │
│ - post_003 (newest)                                              │
│ - post_002                                                       │
│ - post_001 (oldest)                                              │
└─────────────────────────────────────────────────────────────────┘
```

---

## Error Handling Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                    ERROR HANDLING FLOW                           │
└─────────────────────────────────────────────────────────────────┘

Scenario 1: User Not Authenticated
┌─────────────────────────────────────────────────────────────────┐
│ _getCurrentUserId() returns null                                 │
│ ↓                                                                │
│ getAllPosts() returns []                                         │
│ ↓                                                                │
│ UI shows: "No posts yet. Be the first to post!"                  │
│ Console: "❌ User not authenticated"                             │
└─────────────────────────────────────────────────────────────────┘

Scenario 2: User Has No Building Assigned
┌─────────────────────────────────────────────────────────────────┐
│ User document exists but buildingId is null                      │
│ ↓                                                                │
│ getAllPosts() returns []                                         │
│ ↓                                                                │
│ UI shows: "No posts yet. Be the first to post!"                  │
│ Console: "❌ User has no building assigned - cannot access posts"│
└─────────────────────────────────────────────────────────────────┘

Scenario 3: User Tries to Create Post Without Building
┌─────────────────────────────────────────────────────────────────┐
│ createPost() called                                              │
│ ↓                                                                │
│ buildingId is null                                               │
│ ↓                                                                │
│ Return error: "Cannot create post: You must be assigned to a     │
│               building"                                          │
│ ↓                                                                │
│ UI shows SnackBar with error message                             │
│ Console: "❌ User has no building assigned"                      │
└─────────────────────────────────────────────────────────────────┘

Scenario 4: Firestore Query Error
┌─────────────────────────────────────────────────────────────────┐
│ Query throws exception                                           │
│ ↓                                                                │
│ Catch block executes                                             │
│ ↓                                                                │
│ Return []                                                        │
│ ↓                                                                │
│ UI shows: "No posts yet. Be the first to post!"                  │
│ Console: "❌ Error fetching posts: [error details]"              │
└─────────────────────────────────────────────────────────────────┘
```

---

## Summary

✅ **Building Members Can Access Community Wall**
- All residents in same building see posts
- All residents can create posts
- All residents can like/comment
- Real-time updates for all members

✅ **Data Isolation**
- Posts filtered by buildingId
- Users from different buildings cannot see each other's posts
- Each building has its own community

✅ **Real-Time Features**
- New posts appear instantly
- Likes/comments update in real-time
- Streaming via Firestore listeners

✅ **Error Handling**
- Clear error messages
- Graceful fallbacks
- Console logs for debugging
