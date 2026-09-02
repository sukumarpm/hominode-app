# Step-by-Step: Apply Firestore Rules to Firebase Console

## Visual Guide

### Step 1: Open Firebase Console
```
1. Go to: https://console.firebase.google.com
2. You should see your projects
3. Click on your project (the one for this app)
```

**Screenshot location:** Top left shows project name

---

### Step 2: Navigate to Firestore Database
```
Left Menu:
├── Build
│   ├── Authentication
│   ├── Firestore Database  ← CLICK HERE
│   ├── Realtime Database
│   └── Storage
```

**What you'll see:** A database view with "Data" and "Rules" tabs

---

### Step 3: Click on Rules Tab
```
Top of page:
┌─────────────────────────────────────┐
│ [Data]  [Rules]  [Indexes]  [Usage] │
│         ↑ CLICK HERE                │
└─────────────────────────────────────┘
```

**What you'll see:** A code editor with current Firestore rules

---

### Step 4: Select All Current Rules
```
In the Rules editor:
1. Press Ctrl+A (Windows) or Cmd+A (Mac)
   OR
2. Click in the editor and use the menu to Select All
```

**What you'll see:** All text highlighted in blue

---

### Step 5: Delete Current Rules
```
After selecting all:
1. Press Delete or Backspace
   OR
2. Right-click and select Delete
```

**What you'll see:** Empty editor

---

### Step 6: Paste New Rules

**Copy this entire block:**

```firestore
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // ==================== ADMINS ====================
    match /admins/{adminId} {
      allow read, write: if request.auth.uid == adminId;
    }

    // ==================== USERS (Residents) ====================
    match /users/{userId} {
      allow read: if request.auth.uid == resource.data.authUid;
      allow write: if request.auth.uid == resource.data.authUid;
    }

    // ==================== BUILDINGS ====================
    match /buildings/{buildingId} {
      allow read, write: if request.auth != null;
    }

    // ==================== FLATS ====================
    match /flats/{flatId} {
      allow read, write: if request.auth != null;
    }

    // ==================== APARTMENT IMAGES ====================
    match /apartmentImages/{imageId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null && request.auth.uid == request.resource.data.adminId;
      allow update: if request.auth != null && request.auth.uid == resource.data.adminId;
      allow delete: if request.auth != null && request.auth.uid == resource.data.adminId;
    }

    // ==================== POSTERS ====================
    match /posters/{posterId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null && request.auth.uid == request.resource.data.adminId;
      allow update: if request.auth != null && request.auth.uid == resource.data.adminId;
      allow delete: if request.auth != null && request.auth.uid == resource.data.adminId;
    }

    // ==================== EVENTS ====================
    match /events/{eventId} {
      allow read, write: if request.auth != null;
    }

    // ==================== ANNOUNCEMENTS ====================
    match /announcements/{announcementId} {
      allow read, write: if request.auth != null;
    }

    // ==================== COMPLAINTS ====================
    match /complaints/{complaintId} {
      allow read, write: if request.auth != null;
    }

    // ==================== NOTICES ====================
    match /notices/{noticeId} {
      allow read, write: if request.auth != null;
    }

    // ==================== VISITORS ====================
    match /visitors/{visitorId} {
      allow read, write: if request.auth != null;
    }

    // ==================== PARKING ====================
    match /parking/{parkingId} {
      allow read, write: if request.auth != null;
    }

    // ==================== AMENITIES ====================
    match /amenities/{amenityId} {
      allow read, write: if request.auth != null;
    }

    // ==================== BOOKINGS ====================
    match /bookings/{bookingId} {
      allow read, write: if request.auth != null;
    }

    // ==================== BILLS ====================
    match /bills/{billId} {
      allow read, write: if request.auth != null;
    }

    // ==================== ATTENDANCE ====================
    match /attendance/{attendanceId} {
      allow read, write: if request.auth != null;
    }

    // ==================== CHAT ====================
    match /chats/{chatId} {
      allow read, write: if request.auth != null;
    }

    // ==================== MESSAGES ====================
    match /messages/{messageId} {
      allow read, write: if request.auth != null;
    }

    // ==================== NOTIFICATIONS ====================
    match /notifications/{notificationId} {
      allow read, write: if request.auth != null;
    }

    // ==================== BROADCAST MESSAGES ====================
    match /broadcastMessages/{messageId} {
      allow read, write: if request.auth != null;
    }

    // ==================== PINNED POSTS ====================
    match /pinnedPosts/{postId} {
      allow read, write: if request.auth != null;
    }

    // ==================== SECURITY WORK ASSIGNMENTS ====================
    match /securityWorkAssignments/{assignmentId} {
      allow read, write: if request.auth != null;
    }

    // ==================== GATES ====================
    match /gates/{gateId} {
      allow read, write: if request.auth != null;
    }

    // ==================== CATCH-ALL ====================
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

**Then:**
1. Right-click in the empty editor
2. Select "Paste" or press Ctrl+V (Windows) / Cmd+V (Mac)

**What you'll see:** All the new rules appear in the editor

---

### Step 7: Verify Rules Look Correct

**Check for:**
- ✅ No red underlines (syntax errors)
- ✅ All braces `{}` are matched
- ✅ All lines end with semicolons `;`
- ✅ The rules start with `rules_version = '2';`

**If you see red underlines:**
- Copy the rules again
- Make sure you copied the entire block
- Try pasting again

---

### Step 8: Click Publish Button

```
Bottom right of the editor:
┌──────────────────────────────────────┐
│                    [Publish] [Cancel] │
│                      ↑ CLICK HERE     │
└──────────────────────────────────────┘
```

**What happens:**
1. A dialog appears asking to confirm
2. Click "Publish" again to confirm
3. Firebase starts deploying the rules

---

### Step 9: Wait for Deployment

```
You'll see a message like:
"Publishing rules..."

Then after 1-2 minutes:
"Rules published successfully" ✅
```

**What to look for:**
- Green checkmark ✅
- "Published" status
- No error messages

---

### Step 10: Test Resident Login

**In your app:**
1. Logout from admin account
2. Try to login as a resident
3. Use the email and password you created for the resident
4. Verify login succeeds

**If login fails:**
- Check Firebase Console logs
- Verify resident has `authUid` field in Firestore
- See troubleshooting section below

---

## Troubleshooting

### Issue: Rules Won't Publish

**Symptoms:**
- Red underlines in the editor
- Error message when clicking Publish

**Solution:**
1. Check for syntax errors (red underlines)
2. Make sure all braces are matched: `{` and `}`
3. Make sure all lines end with semicolons: `;`
4. Copy the rules again from the beginning
5. Try publishing again

---

### Issue: Residents Still Can't Login

**Symptoms:**
- Login fails with "Permission denied" error
- Error in Firebase Console logs

**Solution:**
1. Go to Firestore Database → Data
2. Click on "users" collection
3. Click on a resident document
4. Check if it has an `authUid` field
5. If not, the resident needs to be recreated

**To verify:**
1. Open Firebase Console
2. Go to Firestore Database → Data
3. Expand "users" collection
4. Click on a resident document
5. Look for `authUid` field in the data

---

### Issue: Admin Can't Access Data

**Symptoms:**
- Admin can't see buildings, flats, etc.
- Error messages in the app

**Solution:**
1. Make sure admin is logged in
2. Check that admin UID matches the document ID in `/admins/{adminId}`
3. Verify admin document exists in Firestore

---

## Quick Checklist

- [ ] Opened Firebase Console
- [ ] Navigated to Firestore Database
- [ ] Clicked on Rules tab
- [ ] Selected all current rules
- [ ] Deleted current rules
- [ ] Pasted new rules
- [ ] Verified no red underlines
- [ ] Clicked Publish button
- [ ] Waited for deployment (1-2 minutes)
- [ ] Saw "Published successfully" message
- [ ] Tested resident login
- [ ] Login succeeded ✅

---

## What Changed

### Before (BROKEN):
```firestore
match /users/{userId} {
  allow read, write: if request.auth.uid == userId;
}
```
- Checks if auth UID matches document ID
- Residents have different document IDs and auth UIDs
- Result: ❌ Permission denied

### After (FIXED):
```firestore
match /users/{userId} {
  allow read: if request.auth.uid == resource.data.authUid;
  allow write: if request.auth.uid == resource.data.authUid;
}
```
- Checks if auth UID matches the `authUid` field in the document
- Each resident has an `authUid` field that matches their Firebase Auth UID
- Result: ✅ Permission granted

---

## Time Estimate

- **Reading this guide:** 5 minutes
- **Applying rules:** 3 minutes
- **Firebase deployment:** 1-2 minutes
- **Testing:** 2 minutes

**Total: ~10-15 minutes**

---

## Need Help?

If you get stuck:
1. Check the troubleshooting section above
2. Look at the error message in Firebase Console
3. Verify the rules were copied correctly
4. Try publishing again

That's it! Once the rules are published, everything will work.
