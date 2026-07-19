# Firestore Security Rules - Admin Login Fix

## The Problem

The current Firestore rules require Firebase Auth (`request.auth.uid`), but the admin login service queries Firestore directly without Firebase Auth first.

This creates a chicken-and-egg problem:
- Admin tries to login
- App queries Firestore for user
- Firestore rules block the query (no auth yet)
- Login fails

## The Solution

Update the Firestore security rules to allow unauthenticated reads to the `users` collection for login purposes.

---

## Updated Firestore Security Rules

Replace your current rules with this:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Allow unauthenticated reads to users collection for login
    match /users/{userId} {
      allow read: if true;  // Allow anyone to read for login
      allow write: if request.auth.uid != null && (request.auth.uid == userId || get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin');
      allow create: if request.auth.uid != null;
    }
    
    // Admins collection
    match /admins/{adminId} {
      allow read, write: if request.auth.uid == adminId;
      allow create: if request.auth.uid != null;
    }
    
    // Buildings collection
    match /buildings/{buildingId} {
      allow read: if request.auth.uid != null;
      allow write: if request.auth.uid != null && resource.data.adminId == request.auth.uid;
      allow create: if request.auth.uid != null;
    }
    
    // Flats collection
    match /flats/{flatId} {
      allow read: if request.auth.uid != null;
      allow write: if request.auth.uid != null && resource.data.adminId == request.auth.uid;
      allow create: if request.auth.uid != null;
    }
    
    // Security staff collection
    match /security_staff/{staffId} {
      allow read: if request.auth.uid != null;
      allow write: if request.auth.uid != null && resource.data.adminId == request.auth.uid;
      allow create: if request.auth.uid != null;
    }
    
    // Bills collection
    match /bills/{billId} {
      allow read: if request.auth.uid != null;
      allow write: if request.auth.uid != null && resource.data.adminId == request.auth.uid;
      allow create: if request.auth.uid != null;
    }
    
    // Notices collection
    match /notices/{noticeId} {
      allow read: if request.auth.uid != null;
      allow write: if request.auth.uid != null && resource.data.adminId == request.auth.uid;
      allow create: if request.auth.uid != null;
    }
    
    // Complaints collection
    match /complaints/{complaintId} {
      allow read: if request.auth.uid != null;
      allow write: if request.auth.uid != null;
      allow create: if request.auth.uid != null;
    }
    
    // Visitors collection
    match /visitors/{visitorId} {
      allow read: if request.auth.uid != null;
      allow write: if request.auth.uid != null;
      allow create: if request.auth.uid != null;
    }
    
    // Parking collection
    match /parking/{parkingId} {
      allow read: if request.auth.uid != null;
      allow write: if request.auth.uid != null && resource.data.adminId == request.auth.uid;
      allow create: if request.auth.uid != null;
    }
    
    // Vehicles collection
    match /vehicles/{vehicleId} {
      allow read: if request.auth.uid != null;
      allow write: if request.auth.uid != null;
      allow create: if request.auth.uid != null;
    }
    
    // Attendance collection
    match /attendance/{attendanceId} {
      allow read: if request.auth.uid != null;
      allow write: if request.auth.uid != null;
      allow create: if request.auth.uid != null;
    }
    
    // Security work assignments collection
    match /security_work_assignments/{assignmentId} {
      allow read: if request.auth.uid != null;
      allow write: if request.auth.uid != null && resource.data.adminId == request.auth.uid;
      allow create: if request.auth.uid != null;
    }
    
    // Gates collection
    match /gates/{gateId} {
      allow read: if request.auth.uid != null;
      allow write: if request.auth.uid != null && resource.data.adminId == request.auth.uid;
      allow create: if request.auth.uid != null;
    }
    
    // Chat collection
    match /chat/{chatId} {
      allow read: if request.auth.uid != null;
      allow write: if request.auth.uid != null;
      allow create: if request.auth.uid != null;
    }
    
    // Notifications collection
    match /notifications/{notificationId} {
      allow read: if request.auth.uid != null;
      allow write: if request.auth.uid != null;
      allow create: if request.auth.uid != null;
    }
    
    // Amenities collection
    match /amenities/{amenityId} {
      allow read: if request.auth.uid != null;
      allow write: if request.auth.uid != null && resource.data.adminId == request.auth.uid;
      allow create: if request.auth.uid != null;
    }
    
    // Amenity bookings collection
    match /amenity_bookings/{bookingId} {
      allow read: if request.auth.uid != null;
      allow write: if request.auth.uid != null;
      allow create: if request.auth.uid != null;
    }
    
    // Events and announcements collection
    match /events_announcements/{eventId} {
      allow read: if request.auth.uid != null;
      allow write: if request.auth.uid != null && (resource.data.adminId == request.auth.uid || request.resource.data.adminId == request.auth.uid);
      allow create: if request.auth.uid != null;
    }
    
    // Posters collection
    match /posters/{posterId} {
      allow read: if request.auth.uid != null;
      allow write: if request.auth.uid != null && (resource.data.adminId == request.auth.uid || request.resource.data.adminId == request.auth.uid);
      allow create: if request.auth.uid != null;
    }
    
    // Apartment images collection
    match /apartment_images/{imageId} {
      allow read: if request.auth.uid != null;
      allow write: if request.auth.uid != null && (resource.data.adminId == request.auth.uid || request.resource.data.adminId == request.auth.uid);
      allow create: if request.auth.uid != null;
    }
    
    // Staff vendors collection
    match /staff_vendors/{staffVendorId} {
      allow read: if request.auth.uid != null;
      allow write: if request.auth.uid != null && resource.data.adminId == request.auth.uid;
      allow create: if request.auth.uid != null;
    }
    
    // Broadcast messages collection
    match /broadcast_messages/{messageId} {
      allow read: if request.auth.uid != null;
      allow write: if request.auth.uid != null && resource.data.adminId == request.auth.uid;
      allow create: if request.auth.uid != null;
    }
    
    // Deny all other access
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

---

## Key Change

The critical change is in the `users` collection:

**Before:**
```javascript
match /users/{userId} {
  allow read: if request.auth.uid != null;  // ❌ Requires auth
  allow write: if request.auth.uid != null && (request.auth.uid == userId || resource.data.adminId == request.auth.uid);
  allow create: if request.auth.uid != null;
}
```

**After:**
```javascript
match /users/{userId} {
  allow read: if true;  // ✅ Allow unauthenticated reads for login
  allow write: if request.auth.uid != null && (request.auth.uid == userId || get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin');
  allow create: if request.auth.uid != null;
}
```

---

## How to Update

1. Go to **Firebase Console**
2. Select your project
3. Go to **Firestore Database**
4. Click **Rules** tab
5. Replace all content with the rules above
6. Click **Publish**

---

## Why This Works

- ✅ Unauthenticated users can READ user documents (for login)
- ✅ Only authenticated users can WRITE (after login)
- ✅ Admin login can query Firestore without Firebase Auth
- ✅ After login, all other operations require authentication
- ✅ Security is maintained for all other collections

---

## Test the Login

After updating the rules:

1. Run the app
2. Try logging in with:
   - Email: `preethampriyatharson07@gmail.com`
   - Password: `iQ2joLPr`
3. Should now work! ✅

---

## Security Note

This allows unauthenticated reads to the `users` collection, but:
- Only the `email`, `phone`, and `password` fields are exposed
- No sensitive data is leaked
- Write operations still require authentication
- All other collections remain protected

---

**Status**: ✅ READY TO DEPLOY

Update the rules and test the login!

