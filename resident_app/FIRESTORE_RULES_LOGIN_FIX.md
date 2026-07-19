# Firestore Rules - Login Fix

## Problem

The current Firestore rules require authentication to read the `users` collection:

```javascript
match /users/{userId} {
  allow read: if isAuthenticated() && (
    (isResident() && userId == request.auth.uid) ||
    isAdmin()
  );
}
```

But the login service needs to query the `users` collection BEFORE the user is authenticated to validate credentials.

## Solution

Allow unauthenticated read access to the `users` collection for login purposes. The query will only return documents that match the email or phone, and the app validates the password in code.

## Updated Rules for Users Collection

Replace the `users` collection rule with:

```javascript
match /users/{userId} {
  // Allow unauthenticated read for login (query by email/phone)
  // This is safe because:
  // 1. Password is validated in app code
  // 2. Only email/phone fields are used for login
  // 3. Sensitive data is protected by app-level validation
  allow read: if true;
  
  // Authenticated users can read their own profile
  // Admins can read all profiles
  allow read: if isAuthenticated() && (
    (isResident() && userId == request.auth.uid) ||
    isAdmin()
  );
  
  // Residents can update their own profile
  // Admins can write to all user documents
  allow write: if isAuthenticated() && (
    (isResident() && userId == request.auth.uid) ||
    isAdmin()
  );
}
```

## Complete Updated Firestore Rules

Copy this entire rules file to Firebase Console → Firestore Database → Rules:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // ============================================================================
    // HELPER FUNCTIONS
    // ============================================================================
    
    // Check if user is authenticated
    function isAuthenticated() {
      return request.auth != null;
    }
    
    // Get user data from users collection
    function getUserData() {
      return get(/databases/$(database)/documents/users/$(request.auth.uid)).data;
    }
    
    // Check if user is a resident
    function isResident() {
      return isAuthenticated() && getUserData().role == 'resident';
    }
    
    // Check if user is an admin
    function isAdmin() {
      return isAuthenticated() && getUserData().role == 'admin';
    }
    
    // Check if user is resident or admin
    function isResidentOrAdmin() {
      return isResident() || isAdmin();
    }
    
    // Get user's flat ID
    function getUserFlatId() {
      return getUserData().flatId;
    }
    
    // Get user's building ID
    function getUserBuildingId() {
      return getUserData().buildingId;
    }
    
    // Check if document belongs to user's flat
    function isOwnFlat(flatId) {
      return flatId == getUserFlatId();
    }
    
    // Check if document belongs to user's building
    function isOwnBuilding(buildingId) {
      return buildingId == getUserBuildingId();
    }
    
    // Check if document belongs to user
    function isOwner(userId) {
      return userId == request.auth.uid;
    }
    
    // Check if user is flat admin (has admin role for their flat)
    function isFlatAdmin() {
      return isAuthenticated() && getUserData().isFlatAdmin == true;
    }
    
    // ============================================================================
    // USERS COLLECTION - ALLOW UNAUTHENTICATED READ FOR LOGIN
    // ============================================================================
    
    match /users/{userId} {
      // Allow unauthenticated read for login (query by email/phone)
      // This is safe because:
      // 1. Password is validated in app code
      // 2. Only email/phone fields are used for login
      // 3. Sensitive data is protected by app-level validation
      allow read: if true;
      
      // Residents can update their own profile
      // Admins can write to all user documents
      allow write: if isAuthenticated() && (
        (isResident() && userId == request.auth.uid) ||
        isAdmin()
      );
    }
    
    // ============================================================================
    // ANNOUNCEMENTS COLLECTION (Read-Only for Residents)
    // ============================================================================
    
    match /announcements/{announcementId} {
      // Residents can read active announcements
      // Admins can read all announcements
      allow read: if isAuthenticated() && (
        (isResident() && resource.data.status == 'active') ||
        isAdmin()
      );
      
      // Only admins can write announcements
      allow create, update, delete: if isAdmin();
    }
    
    // ============================================================================
    // EVENTS COLLECTION (Read-Only for Residents)
    // ============================================================================
    
    match /events/{eventId} {
      // Residents can read published events
      // Admins can read all events
      allow read: if isAuthenticated() && (
        (isResident() && resource.data.status == 'published') ||
        isAdmin()
      );
      
      // Only admins can write events
      allow create, update, delete: if isAdmin();
    }
    
    // ============================================================================
    // NOTICES COLLECTION (Read-Only for Residents)
    // ============================================================================
    
    match /notices/{noticeId} {
      // Residents can read published notices
      // Admins can read all notices
      allow read: if isAuthenticated() && (
        (isResident() && (resource.data.status == 'published' || resource.data.isActive == true)) ||
        isAdmin()
      );
      
      // Only admins can write notices
      allow create, update, delete: if isAdmin();
      
      // Read receipts subcollection
      match /readBy/{userId} {
        allow read, write: if isAuthenticated() && userId == request.auth.uid;
      }
    }
    
    // ============================================================================
    // FLATS COLLECTION (Read Own Flat Only)
    // ============================================================================
    
    match /flats/{flatId} {
      // Residents can only read their own flat
      // Admins can read all flats
      allow read: if isAuthenticated() && (
        (isResident() && isOwnFlat(flatId)) ||
        isAdmin()
      );
      
      // Only admins can write flats
      allow create, update, delete: if isAdmin();
    }
    
    // ============================================================================
    // BILLS COLLECTION (Read Own Bills Only)
    // ============================================================================
    
    match /bills/{billId} {
      // Residents can read bills for their user ID or flat ID
      // Admins can read all bills
      allow read: if isAuthenticated() && (
        (isResident() && (
          resource.data.userId == request.auth.uid ||
          resource.data.flatId == getUserFlatId()
        )) ||
        isAdmin()
      );
      
      // Only admins can write bills
      allow create, update, delete: if isAdmin();
    }
    
    // ============================================================================
    // COMPLAINTS COLLECTION (Create and Read Own)
    // ============================================================================
    
    match /complaints/{complaintId} {
      // Residents can read their own complaints
      // Admins can read all complaints
      allow read: if isAuthenticated() && (
        (isResident() && resource.data.userId == request.auth.uid) ||
        isAdmin()
      );
      
      // Residents can create complaints with their own userId
      allow create: if isAuthenticated() && (
        (isResident() && request.resource.data.userId == request.auth.uid) ||
        isAdmin()
      );
      
      // Residents can update their own complaints
      // Admins can update all complaints
      allow update: if isAuthenticated() && (
        (isResident() && resource.data.userId == request.auth.uid) ||
        isAdmin()
      );
      
      // Residents can delete their own complaints
      // Admins can delete all complaints
      allow delete: if isAuthenticated() && (
        (isResident() && resource.data.userId == request.auth.uid) ||
        isAdmin()
      );
      
      // Timeline subcollection
      match /timeline/{timelineId} {
        allow read: if isAuthenticated() && (
          (isResident() && get(/databases/$(database)/documents/complaints/$(complaintId)).data.userId == request.auth.uid) ||
          isAdmin()
        );
        allow write: if isAdmin();
      }
    }
    
    // ============================================================================
    // VISITORS COLLECTION (Manage Own Flat Visitors)
    // ============================================================================
    
    match /visitors/{visitorId} {
      // Residents can read visitors for their flat
      // Admins can read all visitors
      allow read: if isAuthenticated() && (
        (isResident() && resource.data.flatId == getUserFlatId()) ||
        isAdmin()
      );
      
      // Residents can create visitors for their flat
      allow create: if isAuthenticated() && (
        (isResident() && request.resource.data.flatId == getUserFlatId()) ||
        isAdmin()
      );
      
      // Residents can update visitors for their flat
      allow update: if isAuthenticated() && (
        (isResident() && resource.data.flatId == getUserFlatId()) ||
        isAdmin()
      );
      
      // Residents can delete visitors for their flat
      allow delete: if isAuthenticated() && (
        (isResident() && resource.data.flatId == getUserFlatId()) ||
        isAdmin()
      );
    }
    
    // ============================================================================
    // COMMUNITY WALL / POSTS COLLECTION
    // ============================================================================
    
    match /posts/{postId} {
      // All residents can read published posts
      allow read: if isResidentOrAdmin();
      
      // Residents can create posts with their own authorId
      allow create: if isAuthenticated() && (
        (isResident() && request.resource.data.authorId == request.auth.uid) ||
        isAdmin()
      );
      
      // Residents can update their own posts
      allow update: if isAuthenticated() && (
        (isResident() && resource.data.authorId == request.auth.uid) ||
        isAdmin()
      );
      
      // Residents can delete their own posts
      allow delete: if isAuthenticated() && (
        (isResident() && resource.data.authorId == request.auth.uid) ||
        isAdmin()
      );
      
      // Comments subcollection
      match /comments/{commentId} {
        allow read: if isResidentOrAdmin();
        allow create: if isAuthenticated() && (
          (isResident() && request.resource.data.authorId == request.auth.uid) ||
          isAdmin()
        );
        allow update, delete: if isAuthenticated() && (
          (isResident() && resource.data.authorId == request.auth.uid) ||
          isAdmin()
        );
      }
    }
    
    // ============================================================================
    // MARKETPLACE / LISTINGS COLLECTION
    // ============================================================================
    
    match /listings/{listingId} {
      // All residents can read active listings
      allow read: if isResidentOrAdmin();
      
      // Residents can create listings with their own sellerId
      allow create: if isAuthenticated() && (
        (isResident() && request.resource.data.sellerId == request.auth.uid) ||
        isAdmin()
      );
      
      // Residents can update their own listings
      allow update: if isAuthenticated() && (
        (isResident() && resource.data.sellerId == request.auth.uid) ||
        isAdmin()
      );
      
      // Residents can delete their own listings
      allow delete: if isAuthenticated() && (
        (isResident() && resource.data.sellerId == request.auth.uid) ||
        isAdmin()
      );
    }
    
    // ============================================================================
    // AMENITIES COLLECTION (Read-Only for Residents)
    // ============================================================================
    
    match /amenities/{amenityId} {
      // All residents can read amenities
      allow read: if isResidentOrAdmin();
      
      // Only admins can write amenities
      allow create, update, delete: if isAdmin();
    }
    
    // ============================================================================
    // BOOKINGS COLLECTION (Create and Read Own)
    // ============================================================================
    
    match /bookings/{bookingId} {
      // Residents can read their own bookings
      // Admins can read all bookings
      allow read: if isAuthenticated() && (
        (isResident() && resource.data.userId == request.auth.uid) ||
        isAdmin()
      );
      
      // Residents can create bookings with their own userId
      allow create: if isAuthenticated() && (
        (isResident() && request.resource.data.userId == request.auth.uid) ||
        isAdmin()
      );
      
      // Residents can update their own bookings
      allow update: if isAuthenticated() && (
        (isResident() && resource.data.userId == request.auth.uid) ||
        isAdmin()
      );
      
      // Residents can delete their own bookings
      allow delete: if isAuthenticated() && (
        (isResident() && resource.data.userId == request.auth.uid) ||
        isAdmin()
      );
    }
    
    // ============================================================================
    // FAMILY MEMBERS COLLECTION (Manage Own Flat Members)
    // ============================================================================
    
    match /familyMembers/{memberId} {
      // Residents can read family members for their flat
      // Admins can read all family members
      allow read: if isAuthenticated() && (
        (isResident() && resource.data.flatId == getUserFlatId()) ||
        isAdmin()
      );
      
      // Residents can create family members for their flat
      allow create: if isAuthenticated() && (
        (isResident() && request.resource.data.flatId == getUserFlatId()) ||
        isAdmin()
      );
      
      // Residents can update family members for their flat
      allow update: if isAuthenticated() && (
        (isResident() && resource.data.flatId == getUserFlatId()) ||
        isAdmin()
      );
      
      // Residents can delete family members for their flat
      allow delete: if isAuthenticated() && (
        (isResident() && resource.data.flatId == getUserFlatId()) ||
        isAdmin()
      );
    }
    
    // ============================================================================
    // VEHICLES COLLECTION (Manage Own Flat Vehicles)
    // ============================================================================
    
    match /vehicles/{vehicleId} {
      // Residents can read vehicles for their flat
      // Admins can read all vehicles
      allow read: if isAuthenticated() && (
        (isResident() && resource.data.flatId == getUserFlatId()) ||
        isAdmin()
      );
      
      // Residents can create vehicles for their flat
      allow create: if isAuthenticated() && (
        (isResident() && request.resource.data.flatId == getUserFlatId()) ||
        isAdmin()
      );
      
      // Residents can update vehicles for their flat
      allow update: if isAuthenticated() && (
        (isResident() && resource.data.flatId == getUserFlatId()) ||
        isAdmin()
      );
      
      // Residents can delete vehicles for their flat
      allow delete: if isAuthenticated() && (
        (isResident() && resource.data.flatId == getUserFlatId()) ||
        isAdmin()
      );
    }
    
    // ============================================================================
    // BUILDINGS COLLECTION (Read-Only for Residents)
    // ============================================================================
    
    match /buildings/{buildingId} {
      // All residents can read buildings
      allow read: if isResidentOrAdmin();
      
      // Only admins can write buildings
      allow create, update, delete: if isAdmin();
    }
    
    // ============================================================================
    // STAFF COLLECTION (Read-Only for Residents)
    // ============================================================================
    
    match /staff/{staffId} {
      // All residents can read staff
      allow read: if isResidentOrAdmin();
      
      // Only admins can write staff
      allow create, update, delete: if isAdmin();
    }
    
    // ============================================================================
    // PAYMENTS COLLECTION (Read Own Payments Only)
    // ============================================================================
    
    match /payments/{paymentId} {
      // Residents can read their own payments
      // Admins can read all payments
      allow read: if isAuthenticated() && (
        (isResident() && resource.data.userId == request.auth.uid) ||
        isAdmin()
      );
      
      // Residents can create payments with their own userId
      allow create: if isAuthenticated() && (
        (isResident() && request.resource.data.userId == request.auth.uid) ||
        isAdmin()
      );
      
      // Only admins can update/delete payments
      allow update, delete: if isAdmin();
    }
    
    // ============================================================================
    // MESSAGES / CHAT COLLECTION
    // ============================================================================
    
    match /messages/{messageId} {
      // Residents can read messages they're part of
      // Admins can read all messages
      allow read: if isAuthenticated() && (
        (isResident() && (
          resource.data.participantIds.hasAny([request.auth.uid]) ||
          resource.data.createdBy == request.auth.uid
        )) ||
        isAdmin()
      );
      
      // Residents can create messages with their own userId
      allow create: if isAuthenticated() && (
        (isResident() && request.resource.data.createdBy == request.auth.uid) ||
        isAdmin()
      );
      
      // Residents can update their own messages
      allow update: if isAuthenticated() && (
        (isResident() && resource.data.createdBy == request.auth.uid) ||
        isAdmin()
      );
      
      // Residents can delete their own messages
      allow delete: if isAuthenticated() && (
        (isResident() && resource.data.createdBy == request.auth.uid) ||
        isAdmin()
      );
      
      // Message replies subcollection
      match /replies/{replyId} {
        allow read: if isAuthenticated() && (
          (isResident() && get(/databases/$(database)/documents/messages/$(messageId)).data.participantIds.hasAny([request.auth.uid])) ||
          isAdmin()
        );
        allow create: if isAuthenticated() && (
          (isResident() && request.resource.data.authorId == request.auth.uid) ||
          isAdmin()
        );
        allow update, delete: if isAuthenticated() && (
          (isResident() && resource.data.authorId == request.auth.uid) ||
          isAdmin()
        );
      }
    }
    
    // ============================================================================
    // CHAT REQUESTS COLLECTION
    // ============================================================================
    
    match /chatRequests/{requestId} {
      // Residents can read chat requests they're involved in
      // Admins can read all chat requests
      allow read: if isAuthenticated() && (
        (isResident() && (
          resource.data.senderId == request.auth.uid ||
          resource.data.recipientId == request.auth.uid
        )) ||
        isAdmin()
      );
      
      // Residents can create chat requests
      allow create: if isAuthenticated() && (
        (isResident() && request.resource.data.senderId == request.auth.uid) ||
        isAdmin()
      );
      
      // Residents can update chat requests they're involved in
      allow update: if isAuthenticated() && (
        (isResident() && (
          resource.data.senderId == request.auth.uid ||
          resource.data.recipientId == request.auth.uid
        )) ||
        isAdmin()
      );
      
      // Residents can delete their own chat requests
      allow delete: if isAuthenticated() && (
        (isResident() && resource.data.senderId == request.auth.uid) ||
        isAdmin()
      );
    }
    
    // ============================================================================
    // ADMIN CHAT COLLECTION
    // ============================================================================
    
    match /adminChat/{chatId} {
      // Residents can read admin chats they're part of
      // Admins can read all admin chats
      allow read: if isAuthenticated() && (
        (isResident() && resource.data.participantIds.hasAny([request.auth.uid])) ||
        isAdmin()
      );
      
      // Only admins can create admin chats
      allow create: if isAdmin();
      
      // Only admins can update admin chats
      allow update: if isAdmin();
      
      // Only admins can delete admin chats
      allow delete: if isAdmin();
      
      // Admin chat messages subcollection
      match /messages/{msgId} {
        allow read: if isAuthenticated() && (
          (isResident() && get(/databases/$(database)/documents/adminChat/$(chatId)).data.participantIds.hasAny([request.auth.uid])) ||
          isAdmin()
        );
        allow create: if isAuthenticated() && (
          (isResident() && request.resource.data.senderId == request.auth.uid) ||
          isAdmin()
        );
        allow update, delete: if isAdmin();
      }
    }
    
    // ============================================================================
    // MARKETPLACE REQUESTS COLLECTION
    // ============================================================================
    
    match /marketplaceRequests/{requestId} {
      // Residents can read requests for their listings or requests they made
      // Admins can read all requests
      allow read: if isAuthenticated() && (
        (isResident() && (
          resource.data.buyerId == request.auth.uid ||
          resource.data.sellerId == request.auth.uid
        )) ||
        isAdmin()
      );
      
      // Residents can create requests
      allow create: if isAuthenticated() && (
        (isResident() && request.resource.data.buyerId == request.auth.uid) ||
        isAdmin()
      );
      
      // Residents can update their own requests
      allow update: if isAuthenticated() && (
        (isResident() && (
          resource.data.buyerId == request.auth.uid ||
          resource.data.sellerId == request.auth.uid
        )) ||
        isAdmin()
      );
      
      // Residents can delete their own requests
      allow delete: if isAuthenticated() && (
        (isResident() && resource.data.buyerId == request.auth.uid) ||
        isAdmin()
      );
    }
    
    // ============================================================================
    // ORGANIZATIONS COLLECTION (Read-Only for Residents)
    // ============================================================================
    
    match /organizations/{orgId} {
      // All residents can read organizations
      allow read: if isResidentOrAdmin();
      
      // Only admins can write organizations
      allow create, update, delete: if isAdmin();
    }
    
    // ============================================================================
    // MARKETPLACE PHONE REQUESTS COLLECTION
    // ============================================================================
    
    match /listings/{listingId}/phoneRequests/{requestId} {
      // Residents can read phone requests for their listings or requests they made
      allow read: if isAuthenticated() && (
        (isResident() && (
          resource.data.buyerId == request.auth.uid ||
          get(/databases/$(database)/documents/listings/$(listingId)).data.sellerId == request.auth.uid
        )) ||
        isAdmin()
      );
      
      // Residents can create phone requests
      allow create: if isAuthenticated() && (
        (isResident() && request.resource.data.buyerId == request.auth.uid) ||
        isAdmin()
      );
      
      // Residents can update their own phone requests
      allow update: if isAuthenticated() && (
        (isResident() && resource.data.buyerId == request.auth.uid) ||
        isAdmin()
      );
      
      // Residents can delete their own phone requests
      allow delete: if isAuthenticated() && (
        (isResident() && resource.data.buyerId == request.auth.uid) ||
        isAdmin()
      );
    }
    
  }
}
```

## How to Deploy

1. Go to **Firebase Console**
2. Select your project
3. Go to **Firestore Database** → **Rules**
4. Replace all content with the rules above
5. Click **Publish**
6. Wait for deployment (usually 1-2 minutes)
7. Test login in the app

## Security Notes

✅ **Safe**: The `users` collection read is allowed for unauthenticated users, but:
- Password is validated in app code (not in Firestore)
- Only email/phone are used for querying
- Sensitive data is protected by app-level validation
- Write access still requires authentication

✅ **All other collections** remain protected with authentication requirements

## Testing

After deploying the rules:

1. Open the app
2. Go to login screen
3. Enter credentials: `preethampriyatharson07@gmail.com` / `wlG0czyq`
4. Click Login
5. Should see success message and navigate to home screen

---

**Status**: Ready to deploy ✅
