# Permission Denied Error - Complete Fix

## Error Message
```
❌ ERROR: [cloud_firestore/permission-denied] 
The caller does not have permission to execute the specified operation.
```

## Root Causes

### 1. Missing Required Fields
Documents don't have the fields that rules check for:
- `adminId` field missing
- `authUid` field missing
- `residentUserId` field missing

### 2. Field Values Don't Match
Field values don't match the authenticated user's UID:
- `adminId` ≠ request.auth.uid
- `authUid` ≠ request.auth.uid
- `residentUserId` ≠ request.auth.uid

### 3. Wrong Data Structure
Documents created without proper fields from the start.

---

## Quick Fix: Use Permissive Rules (For Development)

If you're still setting up, use these simpler rules while you fix your data:

```firestore
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Admins - can read/write their own profile
    match /admins/{adminId} {
      allow read, write: if request.auth != null && request.auth.uid == adminId;
    }

    // Users (Residents) - can read/write their own profile
    match /users/{userId} {
      allow read, write: if request.auth != null && (
        request.auth.uid == userId ||
        request.auth.uid == resource.data.authUid
      );
      allow create: if request.auth != null;
    }

    // Security Staff - can read/write their own profile
    match /securityStaff/{securityId} {
      allow read, write: if request.auth != null && (
        request.auth.uid == securityId ||
        request.auth.uid == resource.data.authUid
      );
      allow create: if request.auth != null;
    }

    // All other collections - authenticated users can read/write
    match /buildings/{buildingId} {
      allow read, write: if request.auth != null;
    }

    match /flats/{flatId} {
      allow read, write: if request.auth != null;
    }

    match /users/{userId}/subcollection/{document=**} {
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

    // Deny all other access
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

---

## Steps to Apply Permissive Rules

1. **Open Firebase Console**
   - https://console.firebase.google.com

2. **Go to Firestore Rules**
   - Firestore Database → Rules tab

3. **Replace All Rules**
   - Select all (Ctrl+A)
   - Delete
   - Paste the permissive rules above

4. **Publish**
   - Click Publish button
   - Wait 1-2 minutes

5. **Test**
   - Try your operations again
   - Should work now

---

## After Getting It Working

Once everything works with permissive rules, you can:

1. **Fix Your Data** - Add required fields to all documents
2. **Apply Strict Rules** - Use the rules from `FIRESTORE_RULES_ALL_APPS_COMPLETE.md`
3. **Test Again** - Verify everything still works

---

## Data Structure to Add

### For Admin Documents
```json
{
  "id": "firebase-auth-uid",
  "authUid": "firebase-auth-uid",
  "name": "Admin Name",
  "email": "admin@example.com"
}
```

### For Resident Documents
```json
{
  "id": "auto-generated-doc-id",
  "authUid": "firebase-auth-uid",
  "adminId": "admin-uid",
  "name": "Resident Name",
  "email": "resident@example.com",
  "phone": "9876543210"
}
```

### For Flat Documents
```json
{
  "id": "auto-generated-doc-id",
  "flatId": "T001",
  "adminId": "admin-uid",
  "residentUserId": "resident-uid",
  "buildingId": "building-id",
  "status": "occupied"
}
```

### For Building Documents
```json
{
  "id": "auto-generated-doc-id",
  "adminId": "admin-uid",
  "name": "Building Name",
  "floors": 5,
  "flatsPerFloor": 4
}
```

### For Security Staff Documents
```json
{
  "id": "auto-generated-doc-id",
  "authUid": "firebase-auth-uid",
  "adminId": "admin-uid",
  "name": "Security Name",
  "email": "security@example.com"
}
```

---

## Troubleshooting

### Still Getting Permission Denied?

**Step 1: Check if rules are published**
- Go to Firebase Console → Firestore Database → Rules
- Look for green checkmark
- If not published, click Publish again

**Step 2: Check if user is authenticated**
- Make sure user is logged in
- Check Firebase Auth has the user account

**Step 3: Check browser cache**
- Clear browser cache
- Restart the app
- Try again

**Step 4: Check Firestore logs**
- Go to Firebase Console → Firestore Database → Rules
- Look at the logs section
- See which rule is denying access

---

## Development vs Production

### Development (Use Permissive Rules)
- Easier to test
- Faster development
- Less secure
- Good for getting things working

### Production (Use Strict Rules)
- More secure
- Proper data isolation
- Requires correct data structure
- Better for live apps

---

## Next Steps

1. **Apply permissive rules** (this document)
2. **Test all features** - should work now
3. **Fix your data** - add required fields
4. **Apply strict rules** - from `FIRESTORE_RULES_ALL_APPS_COMPLETE.md`
5. **Test again** - verify everything still works

---

## Summary

**Current Problem:**
- Firestore rules are too strict
- Documents missing required fields
- Permission denied errors

**Solution:**
- Use permissive rules for now
- Get everything working
- Then add proper security

**Time to Fix:**
- 5 minutes to apply rules
- 1-2 minutes for Firebase deployment
- 5 minutes to test

**Total: ~10 minutes**

Apply the permissive rules now and everything will work!
