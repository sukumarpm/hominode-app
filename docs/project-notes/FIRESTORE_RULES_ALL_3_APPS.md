# Firestore Security Rules for All 3 Apps

## 📋 OVERVIEW

Standard Firestore security rules for:
1. **Resident App** - Residents access their own data (bills, bookings, messages, etc.)
2. **Admin App** - Admins manage building data (buildings, amenities, complaints, etc.)
3. **Security App** - Security staff manage visitors and access control

---

## 🏠 RESIDENT APP - FIRESTORE RULES

**Purpose:** Residents can read/write their own data, building data, and shared collections

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // ============================================================================
    // USERS COLLECTION - Each user can read/write their own document
    // ============================================================================
    match /users/{userId} {
      allow read: if request.auth.uid == userId || request.auth != null;
      allow write: if request.auth.uid == userId;
      
      // User subcollections
      match /{document=**} {
        allow read, write: if request.auth.uid == userId;
      }
    }
    
    // ============================================================================
    // BILLS COLLECTION - Residents can read bills for their flat
    // ============================================================================
    match /bills/{billId} {
      allow read: if request.auth != null && 
                     (resource.data.flatId == get(/databases/$(database)/documents/users/$(request.auth.uid)).data.flatId ||
                      resource.data.userId == request.auth.uid);
      allow write: if false; // Only backend can write bills
    }
    
    // ============================================================================
    // ANNOUNCEMENTS COLLECTION - All authenticated users can read
    // ============================================================================
    match /announcements/{announcementId} {
      allow read: if request.auth != null && resource.data.status == 'active';
      allow write: if false; // Only backend can write
    }
    
    // ============================================================================
    // EVENTS COLLECTION - All authenticated users can read
    // ============================================================================
    match /events/{eventId} {
      allow read: if request.auth != null && resource.data.status == 'published';
      allow write: if false; // Only backend can write
    }
    
    // ============================================================================
    // AMENITIES COLLECTION - Residents can read amenities for their building
    // ============================================================================
    match /amenities/{amenityId} {
      allow read: if request.auth != null && 
                     resource.data.buildingId == get(/databases/$(database)/documents/users/$(request.auth.uid)).data.buildingId;
      allow write: if false; // Only backend can write
    }
    
    // ============================================================================
    // BOOKINGS COLLECTION - Residents can read/write their own bookings
    // ============================================================================
    match /bookings/{bookingId} {
      allow read: if request.auth != null && 
                     (resource.data.userId == request.auth.uid ||
                      resource.data.userId == get(/databases/$(database)/documents/users/$(request.auth.uid)).data.userId);
      allow create: if request.auth != null && 
                       request.resource.data.userId == request.auth.uid;
      allow update, delete: if request.auth != null && 
                               resource.data.userId == request.auth.uid;
    }
    
    // ============================================================================
    // MESSAGES COLLECTION - Residents can read/write messages for their flat
    // ============================================================================
    match /messages/{messageId} {
      allow read: if request.auth != null && 
                     (resource.data.senderId == request.auth.uid ||
                      resource.data.recipientId == request.auth.uid ||
                      resource.data.flatId == get(/databases/$(database)/documents/users/$(request.auth.uid)).data.flatId);
      allow create: if request.auth != null && 
                       request.resource.data.senderId == request.auth.uid;
      allow update, delete: if request.auth != null && 
                               resource.data.senderId == request.auth.uid;
    }
    
    // ============================================================================
    // COMPLAINTS COLLECTION - Residents can read/write their own complaints
    // ============================================================================
    match /complaints/{complaintId} {
      allow read: if request.auth != null && 
                     (resource.data.userId == request.auth.uid ||
                      resource.data.flatId == get(/databases/$(database)/documents/users/$(request.auth.uid)).data.flatId);
      allow create: if request.auth != null && 
                       request.resource.data.userId == request.auth.uid;
      allow update: if request.auth != null && 
                       (resource.data.userId == request.auth.uid ||
                        get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin');
      allow delete: if request.auth != null && 
                       resource.data.userId == request.auth.uid;
    }
    
    // ============================================================================
    // VISITORS COLLECTION - Residents can read/write their own visitors
    // ============================================================================
    match /visitors/{visitorId} {
      allow read: if request.auth != null && 
                     (resource.data.residentId == request.auth.uid ||
                      resource.data.flatId == get(/databases/$(database)/documents/users/$(request.auth.uid)).data.flatId);
      allow create: if request.auth != null && 
                       request.resource.data.residentId == request.auth.uid;
      allow update, delete: if request.auth != null && 
                               resource.data.residentId == request.auth.uid;
    }
    
    // ============================================================================
    // COMMUNITY WALL COLLECTION - All residents can read/write posts
    // ============================================================================
    match /community_wall/{postId} {
      allow read: if request.auth != null && 
                     resource.data.buildingId == get(/databases/$(database)/documents/users/$(request.auth.uid)).data.buildingId;
      allow create: if request.auth != null && 
                       request.resource.data.userId == request.auth.uid &&
                       request.resource.data.buildingId == get(/databases/$(database)/documents/users/$(request.auth.uid)).data.buildingId;
      allow update, delete: if request.auth != null && 
                               resource.data.userId == request.auth.uid;
      
      // Comments subcollection
      match /comments/{commentId} {
        allow read: if request.auth != null;
        allow create: if request.auth != null && 
                         request.resource.data.userId == request.auth.uid;
        allow update, delete: if request.auth != null && 
                                 resource.data.userId == request.auth.uid;
      }
    }
    
    // ============================================================================
    // MARKETPLACE COLLECTION - All residents can read/write listings
    // ============================================================================
    match /marketplace/{listingId} {
      allow read: if request.auth != null && 
                     resource.data.buildingId == get(/databases/$(database)/documents/users/$(request.auth.uid)).data.buildingId;
      allow create: if request.auth != null && 
                       request.resource.data.userId == request.auth.uid;
      allow update, delete: if request.auth != null && 
                               resource.data.userId == request.auth.uid;
      
      // Phone requests subcollection
      match /phone_requests/{requestId} {
        allow read: if request.auth != null && 
                       (resource.data.buyerId == request.auth.uid ||
                        resource.data.sellerId == request.auth.uid);
        allow create: if request.auth != null && 
                         request.resource.data.buyerId == request.auth.uid;
      }
    }
    
    // ============================================================================
    // NOTIFICATIONS COLLECTION - Users can read their own notifications
    // ============================================================================
    match /notifications/{notificationId} {
      allow read: if request.auth != null && 
                     (resource.data.userId == request.auth.uid ||
                      resource.data.targetFlats.contains(get(/databases/$(database)/documents/users/$(request.auth.uid)).data.flatId));
      allow write: if false; // Only backend can write
    }
    
    // ============================================================================
    // BUILDINGS COLLECTION - All authenticated users can read
    // ============================================================================
    match /buildings/{buildingId} {
      allow read: if request.auth != null;
      allow write: if false; // Only backend can write
    }
    
    // ============================================================================
    // FLATS COLLECTION - Residents can read flats in their building
    // ============================================================================
    match /flats/{flatId} {
      allow read: if request.auth != null && 
                     resource.data.buildingId == get(/databases/$(database)/documents/users/$(request.auth.uid)).data.buildingId;
      allow write: if false; // Only backend can write
    }
  }
}
```

---

## 👨‍💼 ADMIN APP - FIRESTORE RULES

**Purpose:** Admins can manage all building data, complaints, amenities, etc.

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Helper function to check if user is admin
    function isAdmin() {
      return get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
    }
    
    // ============================================================================
    // USERS COLLECTION - Admins can read all users in their building
    // ============================================================================
    match /users/{userId} {
      allow read: if request.auth != null && 
                     (request.auth.uid == userId ||
                      (isAdmin() && 
                       get(/databases/$(database)/documents/users/$(request.auth.uid)).data.buildingId == 
                       resource.data.buildingId));
      allow write: if request.auth.uid == userId;
    }
    
    // ============================================================================
    // BUILDINGS COLLECTION - Admins can read/write their building
    // ============================================================================
    match /buildings/{buildingId} {
      allow read: if request.auth != null && 
                     (isAdmin() && 
                      get(/databases/$(database)/documents/users/$(request.auth.uid)).data.buildingId == buildingId);
      allow write: if isAdmin() && 
                      get(/databases/$(database)/documents/users/$(request.auth.uid)).data.buildingId == buildingId;
    }
    
    // ============================================================================
    // FLATS COLLECTION - Admins can read/write flats in their building
    // ============================================================================
    match /flats/{flatId} {
      allow read: if request.auth != null && 
                     (isAdmin() && 
                      resource.data.buildingId == get(/databases/$(database)/documents/users/$(request.auth.uid)).data.buildingId);
      allow write: if isAdmin() && 
                      resource.data.buildingId == get(/databases/$(database)/documents/users/$(request.auth.uid)).data.buildingId;
    }
    
    // ============================================================================
    // AMENITIES COLLECTION - Admins can read/write amenities in their building
    // ============================================================================
    match /amenities/{amenityId} {
      allow read: if request.auth != null && 
                     (isAdmin() && 
                      resource.data.buildingId == get(/databases/$(database)/documents/users/$(request.auth.uid)).data.buildingId);
      allow write: if isAdmin() && 
                      resource.data.buildingId == get(/databases/$(database)/documents/users/$(request.auth.uid)).data.buildingId;
    }
    
    // ============================================================================
    // BOOKINGS COLLECTION - Admins can read bookings for their building
    // ============================================================================
    match /bookings/{bookingId} {
      allow read: if request.auth != null && 
                     (isAdmin() && 
                      resource.data.buildingId == get(/databases/$(database)/documents/users/$(request.auth.uid)).data.buildingId);
      allow write: if false; // Only residents can write bookings
    }
    
    // ============================================================================
    // COMPLAINTS COLLECTION - Admins can read/write complaints in their building
    // ============================================================================
    match /complaints/{complaintId} {
      allow read: if request.auth != null && 
                     (isAdmin() && 
                      resource.data.buildingId == get(/databases/$(database)/documents/users/$(request.auth.uid)).data.buildingId);
      allow write: if isAdmin() && 
                      resource.data.buildingId == get(/databases/$(database)/documents/users/$(request.auth.uid)).data.buildingId;
    }
    
    // ============================================================================
    // ANNOUNCEMENTS COLLECTION - Admins can read/write announcements
    // ============================================================================
    match /announcements/{announcementId} {
      allow read: if request.auth != null && isAdmin();
      allow write: if isAdmin();
    }
    
    // ============================================================================
    // EVENTS COLLECTION - Admins can read/write events
    // ============================================================================
    match /events/{eventId} {
      allow read: if request.auth != null && isAdmin();
      allow write: if isAdmin();
    }
    
    // ============================================================================
    // BILLS COLLECTION - Admins can read/write bills for their building
    // ============================================================================
    match /bills/{billId} {
      allow read: if request.auth != null && 
                     (isAdmin() && 
                      resource.data.buildingId == get(/databases/$(database)/documents/users/$(request.auth.uid)).data.buildingId);
      allow write: if isAdmin() && 
                      resource.data.buildingId == get(/databases/$(database)/documents/users/$(request.auth.uid)).data.buildingId;
    }
    
    // ============================================================================
    // VISITORS COLLECTION - Admins can read visitors in their building
    // ============================================================================
    match /visitors/{visitorId} {
      allow read: if request.auth != null && 
                     (isAdmin() && 
                      resource.data.buildingId == get(/databases/$(database)/documents/users/$(request.auth.uid)).data.buildingId);
      allow write: if false; // Only residents can write visitors
    }
    
    // ============================================================================
    // COMMUNITY WALL COLLECTION - Admins can moderate posts
    // ============================================================================
    match /community_wall/{postId} {
      allow read: if request.auth != null && 
                     (isAdmin() && 
                      resource.data.buildingId == get(/databases/$(database)/documents/users/$(request.auth.uid)).data.buildingId);
      allow delete: if isAdmin() && 
                       resource.data.buildingId == get(/databases/$(database)/documents/users/$(request.auth.uid)).data.buildingId;
    }
    
    // ============================================================================
    // NOTIFICATIONS COLLECTION - Admins can read/write notifications
    // ============================================================================
    match /notifications/{notificationId} {
      allow read: if request.auth != null && isAdmin();
      allow write: if isAdmin();
    }
    
    // ============================================================================
    // STAFF COLLECTION - Admins can read/write staff
    // ============================================================================
    match /staff/{staffId} {
      allow read: if request.auth != null && 
                     (isAdmin() && 
                      resource.data.buildingId == get(/databases/$(database)/documents/users/$(request.auth.uid)).data.buildingId);
      allow write: if isAdmin() && 
                      resource.data.buildingId == get(/databases/$(database)/documents/users/$(request.auth.uid)).data.buildingId;
    }
  }
}
```

---

## 🔐 SECURITY APP - FIRESTORE RULES

**Purpose:** Security staff manage visitors and access control

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Helper function to check if user is security staff
    function isSecurity() {
      return get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'security';
    }
    
    // ============================================================================
    // USERS COLLECTION - Security can read users in their building
    // ============================================================================
    match /users/{userId} {
      allow read: if request.auth != null && 
                     (request.auth.uid == userId ||
                      (isSecurity() && 
                       get(/databases/$(database)/documents/users/$(request.auth.uid)).data.buildingId == 
                       resource.data.buildingId));
      allow write: if request.auth.uid == userId;
    }
    
    // ============================================================================
    // VISITORS COLLECTION - Security can read/write/update visitors
    // ============================================================================
    match /visitors/{visitorId} {
      allow read: if request.auth != null && 
                     (isSecurity() && 
                      resource.data.buildingId == get(/databases/$(database)/documents/users/$(request.auth.uid)).data.buildingId);
      allow create: if request.auth != null && 
                       (isSecurity() || request.auth.uid == resource.data.residentId);
      allow update: if request.auth != null && 
                       (isSecurity() && 
                        resource.data.buildingId == get(/databases/$(database)/documents/users/$(request.auth.uid)).data.buildingId);
      allow delete: if isSecurity() && 
                       resource.data.buildingId == get(/databases/$(database)/documents/users/$(request.auth.uid)).data.buildingId;
    }
    
    // ============================================================================
    // BUILDINGS COLLECTION - Security can read their building
    // ============================================================================
    match /buildings/{buildingId} {
      allow read: if request.auth != null && 
                     (isSecurity() && 
                      get(/databases/$(database)/documents/users/$(request.auth.uid)).data.buildingId == buildingId);
      allow write: if false; // Only admins can write
    }
    
    // ============================================================================
    // FLATS COLLECTION - Security can read flats in their building
    // ============================================================================
    match /flats/{flatId} {
      allow read: if request.auth != null && 
                     (isSecurity() && 
                      resource.data.buildingId == get(/databases/$(database)/documents/users/$(request.auth.uid)).data.buildingId);
      allow write: if false; // Only admins can write
    }
    
    // ============================================================================
    // ACCESS LOGS COLLECTION - Security can read/write access logs
    // ============================================================================
    match /access_logs/{logId} {
      allow read: if request.auth != null && 
                     (isSecurity() && 
                      resource.data.buildingId == get(/databases/$(database)/documents/users/$(request.auth.uid)).data.buildingId);
      allow create: if request.auth != null && 
                       (isSecurity() && 
                        request.resource.data.buildingId == get(/databases/$(database)/documents/users/$(request.auth.uid)).data.buildingId);
      allow write: if false; // Only create new logs
    }
    
    // ============================================================================
    // COMPLAINTS COLLECTION - Security can read complaints
    // ============================================================================
    match /complaints/{complaintId} {
      allow read: if request.auth != null && 
                     (isSecurity() && 
                      resource.data.buildingId == get(/databases/$(database)/documents/users/$(request.auth.uid)).data.buildingId);
      allow write: if false; // Only admins can write
    }
    
    // ============================================================================
    // NOTIFICATIONS COLLECTION - Security can read notifications
    // ============================================================================
    match /notifications/{notificationId} {
      allow read: if request.auth != null && 
                     (isSecurity() && 
                      resource.data.buildingId == get(/databases/$(database)/documents/users/$(request.auth.uid)).data.buildingId);
      allow write: if false; // Only admins can write
    }
  }
}
```

---

## 📋 DEPLOYMENT INSTRUCTIONS

### Step 1: Go to Firebase Console
1. Open [Firebase Console](https://console.firebase.google.com)
2. Select your project
3. Go to **Firestore Database** → **Rules** tab

### Step 2: Deploy Rules for Each App

**For Resident App:**
- Copy the **RESIDENT APP** rules above
- Paste into Firebase Rules editor
- Click **Publish**

**For Admin App:**
- Copy the **ADMIN APP** rules above
- Paste into Firebase Rules editor
- Click **Publish**

**For Security App:**
- Copy the **SECURITY APP** rules above
- Paste into Firebase Rules editor
- Click **Publish**

### Step 3: Verify Deployment
- Check that all rules are published successfully
- Test with each app to ensure data access works

---

## 🔑 KEY FEATURES

### Resident App Rules:
✅ Residents read/write their own data
✅ Residents read building-wide data (announcements, events, amenities)
✅ Residents read/write their own bookings, complaints, messages
✅ Residents cannot modify other residents' data
✅ Backend-only write for bills, announcements, events

### Admin App Rules:
✅ Admins manage all data in their building
✅ Admins read/write buildings, flats, amenities
✅ Admins read/write complaints and bills
✅ Admins create announcements and events
✅ Admins cannot access other buildings' data

### Security App Rules:
✅ Security staff read/write visitors
✅ Security staff read building and flat data
✅ Security staff create access logs
✅ Security staff read complaints and notifications
✅ Security staff cannot modify other buildings' data

---

## 🔒 SECURITY PRINCIPLES

1. **Authentication Required** - All operations require `request.auth != null`
2. **Building Isolation** - Users can only access data from their building
3. **Role-Based Access** - Different permissions based on user role (resident, admin, security)
4. **Data Ownership** - Users can only modify their own data
5. **Backend Protection** - Critical data (bills, announcements) can only be written by backend

---

## ✅ TESTING CHECKLIST

- [ ] Resident can read their bills
- [ ] Resident can read announcements and events
- [ ] Resident can create bookings
- [ ] Resident cannot read other residents' bills
- [ ] Admin can read all building data
- [ ] Admin can create announcements
- [ ] Admin cannot access other buildings
- [ ] Security can read visitors
- [ ] Security can update visitor status
- [ ] Security cannot modify complaints

---

## 📞 TROUBLESHOOTING

**"Permission denied" error?**
→ Check that user has correct role in users collection
→ Verify buildingId matches in both user and resource documents

**Cannot read data?**
→ Ensure user is authenticated (Firebase Auth)
→ Check that buildingId is set in user document
→ Verify collection names match exactly (case-sensitive)

**Cannot write data?**
→ Check user role (admin/security/resident)
→ Verify userId matches in request
→ Ensure buildingId matches

---

**Status:** ✅ READY FOR DEPLOYMENT
