# Firestore Rules - Detailed Explanation

## The Critical Change

### Before (BROKEN)
```firestore
match /users/{userId} {
  allow read, write: if request.auth.uid == userId;
}
```

### After (FIXED)
```firestore
match /users/{userId} {
  allow read: if request.auth.uid == resource.data.authUid;
  allow write: if request.auth.uid == resource.data.authUid;
}
```

### Why This Matters

**The Problem:**
- `userId` is the Firestore document ID (auto-generated, e.g., "abc123xyz")
- `request.auth.uid` is the Firebase Auth UID (e.g., "auth_xyz789")
- They are DIFFERENT values
- Rule checks if they match → They don't → Permission denied ❌

**The Solution:**
- Each resident document has an `authUid` field
- The `authUid` field contains the Firebase Auth UID
- Rule checks if auth UID matches the `authUid` field
- They match → Permission granted ✅

---

## Complete Firestore Rules with Explanations

```firestore
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // ==================== ADMINS ====================
    // Admin can read/write their own profile
    // The document ID must match the admin's Firebase Auth UID
    match /admins/{adminId} {
      allow read, write: if request.auth.uid == adminId;
    }
    // Example:
    // - Admin UID: "admin_xyz789"
    // - Document ID: "admin_xyz789"
    // - Rule: request.auth.uid == adminId → "admin_xyz789" == "admin_xyz789" → ✅

    // ==================== USERS (Residents) ====================
    // Resident can read/write their own user document
    // The document ID is auto-generated, but the authUid field matches the Firebase Auth UID
    match /users/{userId} {
      allow read: if request.auth.uid == resource.data.authUid;
      allow write: if request.auth.uid == resource.data.authUid;
    }
    // Example:
    // - Document ID: "abc123xyz" (auto-generated)
    // - Firebase Auth UID: "auth_xyz789"
    // - authUid field: "auth_xyz789"
    // - Rule: request.auth.uid == resource.data.authUid → "auth_xyz789" == "auth_xyz789" → ✅

    // ==================== BUILDINGS ====================
    // Any authenticated user can read/write buildings
    // This allows admins to manage buildings
    match /buildings/{buildingId} {
      allow read, write: if request.auth != null;
    }
    // Example:
    // - Admin is logged in: request.auth != null → ✅
    // - Unauthenticated user: request.auth == null → ❌

    // ==================== FLATS ====================
    // Any authenticated user can read/write flats
    // This allows admins to manage flats
    match /flats/{flatId} {
      allow read, write: if request.auth != null;
    }
    // Example:
    // - Admin is logged in: request.auth != null → ✅
    // - Resident is logged in: request.auth != null → ✅
    // - Unauthenticated user: request.auth == null → ❌

    // ==================== APARTMENT IMAGES ====================
    // Any authenticated user can read apartment images
    // Only the admin who created the image can update/delete it
    match /apartmentImages/{imageId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null && request.auth.uid == request.resource.data.adminId;
      allow update: if request.auth != null && request.auth.uid == resource.data.adminId;
      allow delete: if request.auth != null && request.auth.uid == resource.data.adminId;
    }
    // Example:
    // - Admin reads image: request.auth != null → ✅
    // - Resident reads image: request.auth != null → ✅
    // - Admin creates image: request.auth.uid == request.resource.data.adminId → ✅
    // - Different admin updates image: request.auth.uid == resource.data.adminId → ❌

    // ==================== POSTERS ====================
    // Any authenticated user can read posters
    // Only the admin who created the poster can update/delete it
    match /posters/{posterId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null && request.auth.uid == request.resource.data.adminId;
      allow update: if request.auth != null && request.auth.uid == resource.data.adminId;
      allow delete: if request.auth != null && request.auth.uid == resource.data.adminId;
    }
    // Example:
    // - Admin reads poster: request.auth != null → ✅
    // - Resident reads poster: request.auth != null → ✅
    // - Admin creates poster: request.auth.uid == request.resource.data.adminId → ✅
    // - Different admin updates poster: request.auth.uid == resource.data.adminId → ❌

    // ==================== EVENTS ====================
    // Any authenticated user can read/write events
    match /events/{eventId} {
      allow read, write: if request.auth != null;
    }

    // ==================== ANNOUNCEMENTS ====================
    // Any authenticated user can read/write announcements
    match /announcements/{announcementId} {
      allow read, write: if request.auth != null;
    }

    // ==================== COMPLAINTS ====================
    // Any authenticated user can read/write complaints
    match /complaints/{complaintId} {
      allow read, write: if request.auth != null;
    }

    // ==================== NOTICES ====================
    // Any authenticated user can read/write notices
    match /notices/{noticeId} {
      allow read, write: if request.auth != null;
    }

    // ==================== VISITORS ====================
    // Any authenticated user can read/write visitor records
    match /visitors/{visitorId} {
      allow read, write: if request.auth != null;
    }

    // ==================== PARKING ====================
    // Any authenticated user can read/write parking information
    match /parking/{parkingId} {
      allow read, write: if request.auth != null;
    }

    // ==================== AMENITIES ====================
    // Any authenticated user can read/write amenities
    match /amenities/{amenityId} {
      allow read, write: if request.auth != null;
    }

    // ==================== BOOKINGS ====================
    // Any authenticated user can read/write bookings
    match /bookings/{bookingId} {
      allow read, write: if request.auth != null;
    }

    // ==================== BILLS ====================
    // Any authenticated user can read/write bills
    match /bills/{billId} {
      allow read, write: if request.auth != null;
    }

    // ==================== ATTENDANCE ====================
    // Any authenticated user can read/write attendance records
    match /attendance/{attendanceId} {
      allow read, write: if request.auth != null;
    }

    // ==================== CHAT ====================
    // Any authenticated user can read/write chat messages
    match /chats/{chatId} {
      allow read, write: if request.auth != null;
    }

    // ==================== MESSAGES ====================
    // Any authenticated user can read/write messages
    match /messages/{messageId} {
      allow read, write: if request.auth != null;
    }

    // ==================== NOTIFICATIONS ====================
    // Any authenticated user can read/write notifications
    match /notifications/{notificationId} {
      allow read, write: if request.auth != null;
    }

    // ==================== BROADCAST MESSAGES ====================
    // Any authenticated user can read/write broadcast messages
    match /broadcastMessages/{messageId} {
      allow read, write: if request.auth != null;
    }

    // ==================== PINNED POSTS ====================
    // Any authenticated user can read/write pinned posts
    match /pinnedPosts/{postId} {
      allow read, write: if request.auth != null;
    }

    // ==================== SECURITY WORK ASSIGNMENTS ====================
    // Any authenticated user can read/write security work assignments
    match /securityWorkAssignments/{assignmentId} {
      allow read, write: if request.auth != null;
    }

    // ==================== GATES ====================
    // Any authenticated user can read/write gate information
    match /gates/{gateId} {
      allow read, write: if request.auth != null;
    }

    // ==================== CATCH-ALL ====================
    // Deny all other access by default
    // This is a security best practice
    match /{document=**} {
      allow read, write: if false;
    }
    // Example:
    // - Any access to undefined collections: false → ❌
    // - This prevents accidental data exposure
  }
}
```

---

## Key Concepts

### 1. Authentication Check

```firestore
if request.auth != null
```

**Meaning:** User is logged in (authenticated)

**Examples:**
- Admin logged in: ✅
- Resident logged in: ✅
- No one logged in: ❌

---

### 2. User Identity Check

```firestore
if request.auth.uid == userId
```

**Meaning:** The authenticated user's UID matches the document ID

**Examples:**
- Admin UID: "admin_xyz789"
- Document ID: "admin_xyz789"
- Result: ✅ (they match)

---

### 3. Field Value Check

```firestore
if request.auth.uid == resource.data.authUid
```

**Meaning:** The authenticated user's UID matches the `authUid` field in the document

**Examples:**
- Firebase Auth UID: "auth_xyz789"
- Document authUid field: "auth_xyz789"
- Result: ✅ (they match)

---

### 4. Creator Check

```firestore
if request.auth.uid == resource.data.adminId
```

**Meaning:** The authenticated user's UID matches the `adminId` field in the document

**Examples:**
- Admin UID: "admin_xyz789"
- Document adminId field: "admin_xyz789"
- Result: ✅ (they match)

---

## Common Patterns

### Pattern 1: Own Document Access
```firestore
match /collection/{docId} {
  allow read, write: if request.auth.uid == docId;
}
```
**Use case:** Admin profile (document ID = admin UID)

---

### Pattern 2: Field-Based Access
```firestore
match /collection/{docId} {
  allow read, write: if request.auth.uid == resource.data.authUid;
}
```
**Use case:** Resident profile (document ID ≠ auth UID, but authUid field = auth UID)

---

### Pattern 3: Authenticated Access
```firestore
match /collection/{docId} {
  allow read, write: if request.auth != null;
}
```
**Use case:** Shared data (any logged-in user can access)

---

### Pattern 4: Creator-Only Access
```firestore
match /collection/{docId} {
  allow read: if request.auth != null;
  allow create: if request.auth != null && request.auth.uid == request.resource.data.adminId;
  allow update: if request.auth != null && request.auth.uid == resource.data.adminId;
  allow delete: if request.auth != null && request.auth.uid == resource.data.adminId;
}
```
**Use case:** Images/Posters (anyone can read, only creator can modify)

---

## Testing the Rules

### Test 1: Admin Access
```
Admin UID: "admin_xyz789"
Admin Document ID: "admin_xyz789"
Rule: request.auth.uid == adminId
Result: "admin_xyz789" == "admin_xyz789" → ✅
```

### Test 2: Resident Access
```
Resident Firebase Auth UID: "auth_xyz789"
Resident Document ID: "abc123xyz"
Resident authUid field: "auth_xyz789"
Rule: request.auth.uid == resource.data.authUid
Result: "auth_xyz789" == "auth_xyz789" → ✅
```

### Test 3: Unauthorized Access
```
Resident A Firebase Auth UID: "auth_aaa111"
Resident B Document ID: "xyz789abc"
Resident B authUid field: "auth_bbb222"
Rule: request.auth.uid == resource.data.authUid
Result: "auth_aaa111" == "auth_bbb222" → ❌
```

---

## Debugging Rules

### If You See "Permission denied" Error

**Step 1:** Check if user is authenticated
```
Is request.auth != null?
- If no: User not logged in
- If yes: Continue to step 2
```

**Step 2:** Check the rule condition
```
For /users/{userId}:
- Is request.auth.uid == resource.data.authUid?
- If no: authUid field doesn't match
- If yes: Rule should allow access
```

**Step 3:** Verify the data
```
Go to Firebase Console → Firestore Database → Data
- Click on users collection
- Click on the user document
- Check if authUid field exists
- Check if authUid value matches Firebase Auth UID
```

**Step 4:** Check Firebase Console logs
```
Go to Firebase Console → Firestore Database → Rules
- Look for error messages
- Check which rule is denying access
```

---

## Security Best Practices

### 1. Always Authenticate
```firestore
// ✅ GOOD: Check if user is logged in
if request.auth != null

// ❌ BAD: Allow unauthenticated access
if true
```

### 2. Check User Identity
```firestore
// ✅ GOOD: Check if user owns the document
if request.auth.uid == resource.data.authUid

// ❌ BAD: Allow any authenticated user
if request.auth != null
```

### 3. Use Catch-All Rule
```firestore
// ✅ GOOD: Deny all other access
match /{document=**} {
  allow read, write: if false;
}

// ❌ BAD: No catch-all rule
// (allows accidental data exposure)
```

### 4. Separate Read and Write
```firestore
// ✅ GOOD: Different rules for read and write
allow read: if request.auth != null;
allow write: if request.auth.uid == resource.data.adminId;

// ❌ BAD: Same rule for read and write
allow read, write: if request.auth != null;
```

---

## Summary

| Rule | Meaning | Use Case |
|------|---------|----------|
| `request.auth != null` | User is logged in | Shared data |
| `request.auth.uid == docId` | User owns document (ID) | Admin profile |
| `request.auth.uid == resource.data.authUid` | User owns document (field) | Resident profile |
| `request.auth.uid == resource.data.adminId` | User created document | Images/Posters |
| `if false` | Deny all access | Catch-all rule |

---

## Next Steps

1. **Understand the rules:** Read this document
2. **Apply the rules:** Go to Firebase Console → Firestore Database → Rules
3. **Paste the rules:** Copy from `FIRESTORE_RULES_COPY_PASTE.md`
4. **Publish:** Click Publish button
5. **Test:** Try resident login

That's it! 🎉
