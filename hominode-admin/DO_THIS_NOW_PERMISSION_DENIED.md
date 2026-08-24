# DO THIS NOW - Fix Permission Denied Error

## Your Error
```
❌ ERROR: [cloud_firestore/permission-denied] 
The caller does not have permission to execute the specified operation.
```

## Why It's Happening
Your Firestore rules are checking for fields that don't exist in your documents.

## What To Do RIGHT NOW

### Step 1: Open Firebase Console
```
https://console.firebase.google.com
```

### Step 2: Go to Firestore Rules
```
Firestore Database → Rules tab
```

### Step 3: Replace ALL Rules
Copy and paste this:

```firestore
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /admins/{adminId} {
      allow read, write: if request.auth != null && request.auth.uid == adminId;
    }
    match /users/{userId} {
      allow read, write: if request.auth != null;
      allow create: if request.auth != null;
    }
    match /securityStaff/{securityId} {
      allow read, write: if request.auth != null;
      allow create: if request.auth != null;
    }
    match /buildings/{buildingId} {
      allow read, write: if request.auth != null;
    }
    match /flats/{flatId} {
      allow read, write: if request.auth != null;
    }
    match /apartmentImages/{imageId} {
      allow read, write: if request.auth != null;
    }
    match /posters/{posterId} {
      allow read, write: if request.auth != null;
    }
    match /events/{eventId} {
      allow read, write: if request.auth != null;
    }
    match /announcements/{announcementId} {
      allow read, write: if request.auth != null;
    }
    match /complaints/{complaintId} {
      allow read, write: if request.auth != null;
    }
    match /notices/{noticeId} {
      allow read, write: if request.auth != null;
    }
    match /visitors/{visitorId} {
      allow read, write: if request.auth != null;
    }
    match /parking/{parkingId} {
      allow read, write: if request.auth != null;
    }
    match /amenities/{amenityId} {
      allow read, write: if request.auth != null;
    }
    match /bookings/{bookingId} {
      allow read, write: if request.auth != null;
    }
    match /bills/{billId} {
      allow read, write: if request.auth != null;
    }
    match /attendance/{attendanceId} {
      allow read, write: if request.auth != null;
    }
    match /chats/{chatId} {
      allow read, write: if request.auth != null;
    }
    match /messages/{messageId} {
      allow read, write: if request.auth != null;
    }
    match /notifications/{notificationId} {
      allow read, write: if request.auth != null;
    }
    match /broadcastMessages/{messageId} {
      allow read, write: if request.auth != null;
    }
    match /pinnedPosts/{postId} {
      allow read, write: if request.auth != null;
    }
    match /securityWorkAssignments/{assignmentId} {
      allow read, write: if request.auth != null;
    }
    match /gates/{gateId} {
      allow read, write: if request.auth != null;
    }
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

### Step 4: Publish
- Click Publish button
- Wait 1-2 minutes

### Step 5: Test
- Try your operation again
- Should work now!

---

## Time Required
- 3 minutes to apply rules
- 1-2 minutes for Firebase deployment
- 1 minute to test

**Total: 5 minutes**

---

## After This Works

Once everything works:
1. You can add proper security rules later
2. For now, focus on getting features working
3. See `PERMISSION_DENIED_FIX.md` for more details

---

## DO THIS NOW!

Don't wait. Apply the rules immediately.
