# Create Firestore Indexes - Manual Instructions

## Quick Links (Click These)

### Index 1: Chats Collection
https://console.firebase.google.com/v1/r/project/lyvo-app-9f0ca/firestore/indexes?create_composite=Ckxwcm9qZWN0cy9seXZvLWFwcC05ZjBjYS9kYXRhYmFzZXMvKGRlZmF1bHQpL2NvbGxlY3Rpb25Hcm91cHMvY2hhdHMvaW5kZXhlcy9fEAEaEgoOcGFydGljaXBhbnRJZHMYARoNCgl1cGRhdGVkQXQQAhoMCghfX25hbWVfXxAC

### Index 2: Chat Requests Collection
https://console.firebase.google.com/v1/r/project/lyvo-app-9f0ca/firestore/indexes?create_composite=ClNwcm9qZWN0cy9seXZvLWFwcC05ZjBjYS9kYXRhYmFzZXMvKGRlZmF1bHQpL2NvbGxlY3Rpb25Hcm91cHMvY2hhdFJlcXVlc3RzL2luZGV4ZXMvXxABGg4KCnJlY2VpdmVySWQQARoKCgZzdGF0dXMQARoNCgljcmVhdGVkQXQQAhoMCghfX25hbWVfXxAC

---

## Manual Steps (If Links Don't Work)

### Step 1: Go to Firebase Console
1. Open: https://console.firebase.google.com
2. Select project: **lyvo-app-9f0ca**
3. Go to **Firestore Database** → **Indexes**

### Step 2: Create Index 1 - Chats Collection

**Collection**: `chats`

**Fields to Add** (in this order):
1. Field: `participantIds` | Type: **Array**
2. Field: `updatedAt` | Type: **Descending**

**Query Scope**: Collection

Click **Create Index**

### Step 3: Create Index 2 - Chat Requests Collection

**Collection**: `chatRequests`

**Fields to Add** (in this order):
1. Field: `receiverId` | Type: **Ascending**
2. Field: `status` | Type: **Ascending**
3. Field: `createdAt` | Type: **Descending**

**Query Scope**: Collection

Click **Create Index**

---

## What to Expect

- Indexes usually take **5-10 minutes** to build
- You'll see a "Building" status in the console
- Once complete, status changes to "Enabled"
- Messages feature will work immediately after

---

## Verification

After indexes are created, run the app again:
```bash
flutter run -d ZA222LQT6V
```

You should see in the logs:
```
✅ ChatService: Streaming chats for user: [userId]
✅ ChatService: Chat requests loaded successfully
```

Instead of:
```
❌ ChatService: Firestore error streaming chats: [cloud_firestore/failed-precondition]
```

---

## Index Details (For Reference)

### Index 1: Chats
- **Purpose**: Query chats by participant + sort by recent
- **Query**: `chats.where("participantIds", arrayContains: userId).orderBy("updatedAt", descending: true)`

### Index 2: Chat Requests
- **Purpose**: Query pending requests for a user
- **Query**: `chatRequests.where("receiverId", isEqualTo: userId).where("status", isEqualTo: "pending").orderBy("createdAt", descending: true)`
