# Fix Firestore Rules NOW - Quick Action

## 🔴 Problem
All screens showing permission-denied errors

## ✅ Solution (2 minutes)

### Step 1: Open Firebase Console
https://console.firebase.google.com/project/lvo-app-9f8ca/firestore/databases/_default/security/rules

### Step 2: Delete All Existing Rules
- Select all text (Ctrl+A or Cmd+A)
- Delete it

### Step 3: Paste This Complete Rules

```firestore
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /admins/{adminId} {
      allow read, write: if request.auth.uid == adminId;
    }
    match /users/{userId} {
      allow read, write: if request.auth.uid == userId;
    }
    match /buildings/{buildingId} {
      allow read, write: if request.auth != null;
    }
    match /residents/{residentId} {
      allow read, write: if request.auth != null;
    }
    match /visitors/{visitorId} {
      allow read, write: if request.auth != null;
    }
    match /bills/{billId} {
      allow read, write: if request.auth != null;
    }
    match /apartmentImages/{imageId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null && request.auth.uid == resource.data.adminId;
      allow update: if request.auth != null && request.auth.uid == resource.data.adminId;
      allow delete: if request.auth != null && request.auth.uid == resource.data.adminId;
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
    match /parking/{parkingId} {
      allow read, write: if request.auth != null;
    }
    match /amenities/{amenityId} {
      allow read, write: if request.auth != null;
    }
    match /staff/{staffId} {
      allow read, write: if request.auth != null;
    }
    match /vendors/{vendorId} {
      allow read, write: if request.auth != null;
    }
    match /attendance/{attendanceId} {
      allow read, write: if request.auth != null;
    }
    match /messages/{messageId} {
      allow read, write: if request.auth != null;
    }
    match /broadcasts/{broadcastId} {
      allow read, write: if request.auth != null;
    }
    match /gates/{gateId} {
      allow read, write: if request.auth != null;
    }
    match /security/{securityId} {
      allow read, write: if request.auth != null;
    }
    match /{document=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

### Step 4: Click Publish
- Click the blue **Publish** button
- Wait for success message

### Step 5: Restart App
- Close the app completely
- Reopen it
- All screens should now work!

---

## ✅ Verification

After publishing, check:
- [ ] Buildings screen loads (no error)
- [ ] Residents screen loads (no error)
- [ ] Visitors screen loads (no error)
- [ ] Billing screen loads (no error)
- [ ] No "permission-denied" errors
- [ ] No "Admin profile not found" errors

---

## 🎉 Done!

Once all screens load without errors, you're ready to proceed with apartment images setup.

**Time**: 2 minutes
**Difficulty**: Easy
