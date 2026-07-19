# Messages Feature - Firestore Indexes Required

## Critical Issue
The messages feature is not working because Firestore is missing required composite indexes.

## Missing Indexes

### Index 1: Chats Collection
**Collection**: `chats`
**Fields**:
- `participantIds` (Array)
- `updatedAt` (Descending)

**Error**:
```
The query requires an index. You can create it here:
https://console.firebase.google.com/v1/r/project/lyvo-app-9f0ca/firestore/indexes?create_composite=Ckxwcm9qZWN0cy9seXZvLWFwcC05ZjBjYS9kYXRhYmFzZXMvKGRlZmF1bHQpL2NvbGxlY3Rpb25Hcm91cHMvY2hhdHMvaW5kZXhlcy9fEAEaEgoOcGFydGljaXBhbnRJZHMYARoNCgl1cGRhdGVkQXQQAhoMCghfX25hbWVfXxAC
```

### Index 2: Chat Requests Collection
**Collection**: `chatRequests`
**Fields**:
- `receiverId` (Ascending)
- `status` (Ascending)
- `createdAt` (Descending)

**Error**:
```
The query requires an index. You can create it here:
https://console.firebase.google.com/v1/r/project/lyvo-app-9f0ca/firestore/indexes?create_composite=ClNwcm9qZWN0cy9seXZvLWFwcC05ZjBjYS9kYXRhYmFzZXMvKGRlZmF1bHQpL2NvbGxlY3Rpb25Hcm91cHMvY2hhdFJlcXVlc3RzL2luZGV4ZXMvXxABGg4KCnJlY2VpdmVySWQQARoKCgZzdGF0dXMQARoNCgljcmVhdGVkQXQQAhoMCghfX25hbWVfXxAC
```

## How to Fix

### Option 1: Use Firebase Console Links (Recommended)
Click the links provided in the error messages above. Firebase will automatically create the indexes.

### Option 2: Manual Creation
1. Go to Firebase Console: https://console.firebase.google.com
2. Select project: `lyvo-app-9f0ca`
3. Go to Firestore Database → Indexes
4. Create the two composite indexes as specified above

## What's Working
✅ Building members fetch - correctly retrieves all residents in the same building
✅ Chat service initialization - user ID caching working
✅ Message sending logic - ready to send once indexes are created

## What's Blocked
❌ Chat list loading - blocked by missing `chats` index
❌ Chat requests - blocked by missing `chatRequests` index
❌ Messages display - blocked by chat list not loading

## Timeline
Once indexes are created (usually 5-10 minutes), the messages feature will work properly:
1. Users can see their chat list
2. Users can see pending chat requests
3. Users can send and receive messages in real-time
