# Quick Reference - Firestore Indexes

## 🚀 TL;DR

**Problem:** Messages feature blocked by missing Firestore indexes

**Solution:** Create 2 indexes (5 minutes)

**Links:**
1. https://console.firebase.google.com/v1/r/project/lyvo-app-9f0ca/firestore/indexes?create_composite=Ckxwcm9qZWN0cy9seXZvLWFwcC05ZjBjYS9kYXRhYmFzZXMvKGRlZmF1bHQpL2NvbGxlY3Rpb25Hcm91cHMvY2hhdHMvaW5kZXhlcy9fEAEaEgoOcGFydGljaXBhbnRJZHMYARoNCgl1cGRhdGVkQXQQAhoMCghfX25hbWVfXxAC

2. https://console.firebase.google.com/v1/r/project/lyvo-app-9f0ca/firestore/indexes?create_composite=ClNwcm9qZWN0cy9seXZvLWFwcC05ZjBjYS9kYXRhYmFzZXMvKGRlZmF1bHQpL2NvbGxlY3Rpb25Hcm91cHMvY2hhdFJlcXVlc3RzL2luZGV4ZXMvXxABGg4KCnJlY2VpdmVySWQQARoKCgZzdGF0dXMQARoNCgljcmVhdGVkQXQQAhoMCghfX25hbWVfXxAC

**Steps:**
1. Paste Link 1 → Click "Create Index"
2. Paste Link 2 → Click "Create Index"
3. Wait 5-10 minutes
4. Run: `flutter run -d ZA222LQT6V`

---

## 📋 Index Details

### Index 1: Chats
```
Collection: chats
Field 1: participantIds (Array)
Field 2: updatedAt (Descending)
```

### Index 2: Chat Requests
```
Collection: chatRequests
Field 1: receiverId (Ascending)
Field 2: status (Ascending)
Field 3: createdAt (Descending)
```

---

## ✅ Verification

After indexes are created, check logs:
```
✅ ChatService: Streaming chats for user: [userId]
✅ ChatService: Chat requests loaded successfully
```

---

## 📚 Full Docs

- `MESSAGES_INDEXES_ACTION_REQUIRED.md` - Start here
- `FIRESTORE_INDEXES_EXACT_STEPS.md` - Step-by-step
- `FIRESTORE_INDEXES_VISUAL_GUIDE.md` - Visual guide
- `COMPLETE_MESSAGES_FIX_SUMMARY.md` - Full summary

---

## ⏱️ Timeline

- **Now:** Create indexes (5 min)
- **5-10 min:** Indexes build
- **After:** Messages work! 🎉
