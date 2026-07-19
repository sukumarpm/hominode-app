# Firestore Security Rules - Fixed Version

## Complete Working Rules

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // ============================================================================
    // HELPER FUNCTIONS
    // ============================================================================
    
    function isAuthenticated() {
      return request.auth != null;
    }
    
    function getUserData() {
      return get(/databases/$(database)/documents/users/$(request.auth.uid)).data;
    }
    
    function isResident() {
      return isAuthenticated() && getUserData().role == 'resident';
    }
    
    function isAdmin() {
      return isAuthenticated() && getUserData().role == 'admin';
    }
    
    function isResidentOrAdmin() {
      return isResident() || isAdmin();
    }
    
    function getUserFlatId() {
      return getUserData().flatId;
    }
    
    function isOwnFlat(flatId) {
      return flatId == getUserFlatId();
    }
    
    function isOwner(userId) {
      return userId == request.auth.uid;
    }
    
    // ============================================================================
    // USERS COLLECTION
    // ============================================================================
    
    match /users/{userId} {
      allow read: if isAuthenticated() && (
        (isResident() && userId == request.auth.uid) ||
        isAdmin()
      );
      
      allow write: if isAuthenticated() && (
        (isResident() && userId == request.auth.uid) ||
        isAdmin()
      );
    }
    
    // ============================================================================
    // ANNOUNCEMENTS COLLECTION
    // ============================================================================
    
    match /announcements/{announcementId} {
      allow read: if isAuthenticated() && (
        (isResident() && resource.data.status == 'active') ||
        isAdmin()
      );
      
      allow create, update, delete: if isAdmin();
    }
    
    // ============================================================================
    // EVENTS COLLECTION
    // ============================================================================
    
    match /events/{eventId} {
      allow read: if isAuthenticated() && (
        (isResident() && resource.data.status == 'published') ||
        isAdmin()
      );
      
      allow create, update, delete: if isAdmin();
    }
    
    // ============================================================================
    // NOTICES COLLECTION
    // ============================================================================
    
    match /notices/{noticeId} {
      allow read: if isAuthenticated() && (
        (isResident() && (resource.data.status == 'published' || resource.data.isActive == true)) ||
        isAdmin()
      );
      
      allow create, update, delete: if isAdmin();
      
      match /readBy/{userId} {
        allow read, write: if isAuthenticated() && userId == request.auth.uid;
      }
    }
    
    // ============================================================================
    // FLATS COLLECTION
    // ============================================================================
    
    match /flats/{flatId} {
      allow read: if isAuthenticated() && (
        (isResident() && isOwnFlat(flatId)) ||
        isAdmin()
      );
      
      allow create, update, delete: if isAdmin();
    }
    
    // ============================================================================
    // BILLS COLLECTION
    // ============================================================================
    
    match /bills/{billId} {
      allow read: if isAuthenticated() && (
        (isResident() && (
          resource.data.userId == request.auth.uid ||
          resource.data.flatId == getUserFlatId()
        )) ||
        isAdmin()
      );
      
      allow create, update, delete: if isAdmin();
    }
    
    // ============================================================================
    // COMPLAINTS COLLECTION
    // ============================================================================
    
    match /complaints/{complaintId} {
      allow read: if isAuthenticated() && (
        (isResident() && resource.data.userId == request.auth.uid) ||
        isAdmin()
      );
      
      allow create: if isAuthenticated() && (
        (isResident() && request.resource.data.userId == request.auth.uid) ||
        isAdmin()
      );
      
      allow update: if isAuthenticated() && (
        (isResident() && resource.data.userId == request.auth.uid) ||
        isAdmin()
      );
      
      allow delete: if isAuthenticated() && (
        (isResident() && resource.data.userId == request.auth.uid) ||
        isAdmin()
      );
      
      match /timeline/{timelineId} {
        allow read: if isAuthenticated() && (
          (isResident() && get(/databases/$(database)/documents/complaints/$(complaintId)).data.userId == request.auth.uid) ||
          isAdmin()
        );
        allow write: if isAdmin();
      }
    }
    
    // ============================================================================
    // VISITORS COLLECTION
    // ============================================================================
    
    match /visitors/{visitorId} {
      allow read: if isAuthenticated() && (
        (isResident() && resource.data.flatId == getUserFlatId()) ||
        isAdmin()
      );
      
      allow create: if isAuthenticated() && (
        (isResident() && request.resource.data.flatId == getUserFlatId()) ||
        isAdmin()
      );
      
      allow update: if isAuthenticated() && (
        (isResident() && resource.data.flatId == getUserFlatId()) ||
        isAdmin()
      );
      
      allow delete: if isAuthenticated() && (
        (isResident() && resource.data.flatId == getUserFlatId()) ||
        isAdmin()
      );
    }
    
    // ============================================================================
    // POSTS COLLECTION
    // ============================================================================
    
    match /posts/{postId} {
      allow read: if isResidentOrAdmin();
      
      allow create: if isAuthenticated() && (
        (isResident() && request.resource.data.authorId == request.auth.uid) ||
        isAdmin()
      );
      
      allow update: if isAuthenticated() && (
        (isResident() && resource.data.authorId == request.auth.uid) ||
        isAdmin()
      );
      
      allow delete: if isAuthenticated() && (
        (isResident() && resource.data.authorId == request.auth.uid) ||
        isAdmin()
      );
      
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
    // LISTINGS COLLECTION
    // ============================================================================
    
    match /listings/{listingId} {
      allow read: if isResidentOrAdmin();
      
      allow create: if isAuthenticated() && (
        (isResident() && request.resource.data.sellerId == request.auth.uid) ||
        isAdmin()
      );
      
      allow update: if isAuthenticated() && (
        (isResident() && resource.data.sellerId == request.auth.uid) ||
        isAdmin()
      );
      
      allow delete: if isAuthenticated() && (
        (isResident() && resource.data.sellerId == request.auth.uid) ||
        isAdmin()
      );
      
      match /phoneRequests/{requestId} {
        allow read: if isAuthenticated() && (
          (isResident() && (
            resource.data.buyerId == request.auth.uid ||
            get(/databases/$(database)/documents/listings/$(listingId)).data.sellerId == request.auth.uid
          )) ||
          isAdmin()
        );
        
        allow create: if isAuthenticated() && (
          (isResident() && request.resource.data.buyerId == request.auth.uid) ||
          isAdmin()
        );
        
        allow update: if isAuthenticated() && (
          (isResident() && resource.data.buyerId == request.auth.uid) ||
          isAdmin()
        );
        
        allow delete: if isAuthenticated() && (
          (isResident() && resource.data.buyerId == request.auth.uid) ||
          isAdmin()
        );
      }
    }
    
    // ============================================================================
    // AMENITIES COLLECTION
    // ============================================================================
    
    match /amenities/{amenityId} {
      allow read: if isResidentOrAdmin();
      allow create, update, delete: if isAdmin();
    }
    
    // ============================================================================
    // BOOKINGS COLLECTION
    // ============================================================================
    
    match /bookings/{bookingId} {
      allow read: if isAuthenticated() && (
        (isResident() && resource.data.userId == request.auth.uid) ||
        isAdmin()
      );
      
      allow create: if isAuthenticated() && (
        (isResident() && request.resource.data.userId == request.auth.uid) ||
        isAdmin()
      );
      
      allow update: if isAuthenticated() && (
        (isResident() && resource.data.userId == request.auth.uid) ||
        isAdmin()
      );
      
      allow delete: if isAuthenticated() && (
        (isResident() && resource.data.userId == request.auth.uid) ||
        isAdmin()
      );
    }
    
    // ============================================================================
    // FAMILY MEMBERS COLLECTION
    // ============================================================================
    
    match /familyMembers/{memberId} {
      allow read: if isAuthenticated() && (
        (isResident() && resource.data.flatId == getUserFlatId()) ||
        isAdmin()
      );
      
      allow create: if isAuthenticated() && (
        (isResident() && request.resource.data.flatId == getUserFlatId()) ||
        isAdmin()
      );
      
      allow update: if isAuthenticated() && (
        (isResident() && resource.data.flatId == getUserFlatId()) ||
        isAdmin()
      );
      
      allow delete: if isAuthenticated() && (
        (isResident() && resource.data.flatId == getUserFlatId()) ||
        isAdmin()
      );
    }
    
    // ============================================================================
    // VEHICLES COLLECTION
    // ============================================================================
    
    match /vehicles/{vehicleId} {
      allow read: if isAuthenticated() && (
        (isResident() && resource.data.flatId == getUserFlatId()) ||
        isAdmin()
      );
      
      allow create: if isAuthenticated() && (
        (isResident() && request.resource.data.flatId == getUserFlatId()) ||
        isAdmin()
      );
      
      allow update: if isAuthenticated() && (
        (isResident() && resource.data.flatId == getUserFlatId()) ||
        isAdmin()
      );
      
      allow delete: if isAuthenticated() && (
        (isResident() && resource.data.flatId == getUserFlatId()) ||
        isAdmin()
      );
    }
    
    // ============================================================================
    // BUILDINGS COLLECTION
    // ============================================================================
    
    match /buildings/{buildingId} {
      allow read: if isResidentOrAdmin();
      allow create, update, delete: if isAdmin();
    }
    
    // ============================================================================
    // STAFF COLLECTION
    // ============================================================================
    
    match /staff/{staffId} {
      allow read: if isResidentOrAdmin();
      allow create, update, delete: if isAdmin();
    }
    
    // ============================================================================
    // PAYMENTS COLLECTION
    // ============================================================================
    
    match /payments/{paymentId} {
      allow read: if isAuthenticated() && (
        (isResident() && resource.data.userId == request.auth.uid) ||
        isAdmin()
      );
      
      allow create: if isAuthenticated() && (
        (isResident() && request.resource.data.userId == request.auth.uid) ||
        isAdmin()
      );
      
      allow update, delete: if isAdmin();
    }
    
    // ============================================================================
    // MESSAGES COLLECTION
    // ============================================================================
    
    match /messages/{messageId} {
      allow read: if isAuthenticated() && (
        (isResident() && (
          resource.data.participantIds.hasAny([request.auth.uid]) ||
          resource.data.createdBy == request.auth.uid
        )) ||
        isAdmin()
      );
      
      allow create: if isAuthenticated() && (
        (isResident() && request.resource.data.createdBy == request.auth.uid) ||
        isAdmin()
      );
      
      allow update: if isAuthenticated() && (
        (isResident() && resource.data.createdBy == request.auth.uid) ||
        isAdmin()
      );
      
      allow delete: if isAuthenticated() && (
        (isResident() && resource.data.createdBy == request.auth.uid) ||
        isAdmin()
      );
      
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
      allow read: if isAuthenticated() && (
        (isResident() && (
          resource.data.senderId == request.auth.uid ||
          resource.data.recipientId == request.auth.uid
        )) ||
        isAdmin()
      );
      
      allow create: if isAuthenticated() && (
        (isResident() && request.resource.data.senderId == request.auth.uid) ||
        isAdmin()
      );
      
      allow update: if isAuthenticated() && (
        (isResident() && (
          resource.data.senderId == request.auth.uid ||
          resource.data.recipientId == request.auth.uid
        )) ||
        isAdmin()
      );
      
      allow delete: if isAuthenticated() && (
        (isResident() && resource.data.senderId == request.auth.uid) ||
        isAdmin()
      );
    }
    
    // ============================================================================
    // ADMIN CHAT COLLECTION
    // ============================================================================
    
    match /adminChat/{chatId} {
      allow read: if isAuthenticated() && (
        (isResident() && resource.data.participantIds.hasAny([request.auth.uid])) ||
        isAdmin()
      );
      
      allow create: if isAdmin();
      allow update: if isAdmin();
      allow delete: if isAdmin();
      
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
      allow read: if isAuthenticated() && (
        (isResident() && (
          resource.data.buyerId == request.auth.uid ||
          resource.data.sellerId == request.auth.uid
        )) ||
        isAdmin()
      );
      
      allow create: if isAuthenticated() && (
        (isResident() && request.resource.data.buyerId == request.auth.uid) ||
        isAdmin()
      );
      
      allow update: if isAuthenticated() && (
        (isResident() && (
          resource.data.buyerId == request.auth.uid ||
          resource.data.sellerId == request.auth.uid
        )) ||
        isAdmin()
      );
      
      allow delete: if isAuthenticated() && (
        (isResident() && resource.data.buyerId == request.auth.uid) ||
        isAdmin()
      );
    }
    
    // ============================================================================
    // ORGANIZATIONS COLLECTION
    // ============================================================================
    
    match /organizations/{orgId} {
      allow read: if isResidentOrAdmin();
      allow create, update, delete: if isAdmin();
    }
    
    // ============================================================================
    // DEFAULT DENY ALL
    // ============================================================================
    
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

## Key Fixes Applied

1. **Removed `.get()` method** - Firestore rules don't support `.get()` on map objects
2. **Simplified field access** - Using direct property access instead of `.get('field', default)`
3. **Kept `hasAny()` method** - This is valid for array fields in Firestore rules
4. **Removed invalid syntax** - Removed `let` statements and ternary operators that aren't supported

## How to Deploy

1. Go to Firebase Console
2. Navigate to Firestore Database → Rules
3. Copy all rules from the code block above
4. Click "Publish"

## Status

✅ **Fixed and Ready to Deploy**
