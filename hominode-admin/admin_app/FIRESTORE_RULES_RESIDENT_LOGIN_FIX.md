# Firestore Rules - Resident Login Fix

## Problem
Residents cannot login after being created because the Firestore rules don't allow them to read their own user documents.

## Root Cause
- Residents are created with auto-generated Firestore document IDs
- Each resident has an `authUid` field (Firebase Auth UID) that's different from the document ID
- Current rules check `request.auth.uid == userId` (document ID), but should check `request.auth.uid == resource.data.authUid`

## Solution: Updated Firestore Rules

Go to **Firebase Console → Firestore Database → Rules** and replace ALL existing rules with:

```firestore
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // ==================== ADMINS ====================
    // Admins can read/write their own profile
    match /admins/{adminId} {
      allow read, write: if request.auth.uid == adminId;
    }

    // ==================== USERS (Residents) ====================
    // Residents can read/write their own user document
    // Match by authUid field instead of document ID
    match /users/{userId} {
      allow read: if request.auth.uid == resource.data.authUid;
      allow write: if request.auth.uid == resource.data.authUid;
    }

    // ==================== BUILDINGS ====================
    // Authenticated users can read/write buildings
    match /buildings/{buildingId} {
      allow read, write: if request.auth != null;
    }

    // ==================== FLATS ====================
    // Authenticated users can read/write flats
    match /flats/{flatId} {
      allow read, write: if request.auth != null;
    }

    // ==================== APARTMENT IMAGES ====================
    // Anyone can read apartment images
    // Only admins can create/update/delete
    match /apartmentImages/{imageId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null && request.auth.uid == request.resource.data.adminId;
      allow update: if request.auth != null && request.auth.uid == resource.data.adminId;
      allow delete: if request.auth != null && request.auth.uid == resource.data.adminId;
    }

    // ==================== POSTERS ====================
    // Anyone can read posters
    // Only admins can create/update/delete
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
    // Deny all other access
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

## Key Changes

### 1. Users Collection (Residents)
**Before:**
```firestore
match /users/{userId} {
  allow read, write: if request.auth.uid == userId;
}
```

**After:**
```firestore
match /users/{userId} {
  allow read: if request.auth.uid == resource.data.authUid;
  allow write: if request.auth.uid == resource.data.authUid;
}
```

**Why:** Residents have an `authUid` field that stores their Firebase Auth UID. The document ID is auto-generated and different from the auth UID.

### 2. Apartment Images & Posters
- Anyone authenticated can read
- Only the admin who created it can update/delete

### 3. All Other Collections
- Authenticated users can read/write
- This allows admins to manage all data

## Testing

After updating the rules:

1. **Admin Login**: Should work as before
2. **Resident Creation**: Admin creates a resident
3. **Resident Login**: Resident should be able to login with:
   - Email + Password
   - Phone + Password
   - Resident ID + Password
4. **Resident Data Access**: Resident should be able to read their own profile

## Deployment Steps

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your project
3. Go to **Firestore Database** → **Rules**
4. Replace all content with the rules above
5. Click **Publish**
6. Wait for deployment (usually 1-2 minutes)
7. Test resident login

## Troubleshooting

If residents still can't login:

1. **Check authUid field**: Verify that each resident document has an `authUid` field
2. **Check Firebase Auth**: Verify that the resident's Firebase Auth account exists
3. **Check Console Logs**: Look for permission denied errors in Firebase Console
4. **Verify Rules**: Make sure the rules were published successfully

## Related Files

- `admin_app/lib/services/auth_service.dart` - Resident login logic
- `admin_app/lib/services/user_service.dart` - Resident creation
- `admin_app/lib/services/resident_service.dart` - Alternative resident creation
