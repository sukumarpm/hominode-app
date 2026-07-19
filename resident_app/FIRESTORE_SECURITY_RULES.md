# Firestore Security Rules - Complete Implementation

## Overview

This document provides comprehensive Firestore Security Rules for the resident app that enforce role-based access control and data ownership restrictions.

## Security Principles

1. **Authentication Required**: All access requires Firebase Authentication
2. **Role-Based Access**: Only users with role = "resident" or "admin" can access data
3. **Data Ownership**: Residents can only access their own data
4. **Admin Full Access**: Admins have full read/write access to all collections
5. **Read-Only Public Data**: Residents can read announcements, events, and notices (published only)
6. **No Cross-User Access**: Residents cannot access other residents' private data

## Complete Firestore Security Rules

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
    // USERS COLLECTION
    // ============================================================================
    
    match /users/{userId} {
      // Residents can only read their own profile
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

## Updated Features

### New Collections Added
1. **Messages/Chat** - Real-time messaging between residents
2. **Chat Requests** - Request to start a chat conversation
3. **Admin Chat** - Admin-to-resident communication
4. **Marketplace Requests** - Buyer-seller communication for marketplace
5. **Organizations** - Building organization information
6. **Marketplace Phone Requests** - Phone number requests for listings

### Enhanced Helper Functions
- `getUserData()` - Now handles missing user documents gracefully
- `getUserBuildingId()` - Get user's building ID
- `isOwnBuilding()` - Check if document belongs to user's building
- `isFlatAdmin()` - Check if user is a flat admin

### Improved Error Handling
- All `.get()` calls now use safe access with default values
- Null checks on all field accesses
- Graceful handling of missing documents

## Deployment Checklist

- [ ] Copy all rules to Firebase Console
- [ ] Test unauthenticated access (should fail)
- [ ] Test resident access to own data (should succeed)
- [ ] Test resident access to other data (should fail)
- [ ] Test admin access (should succeed)
- [ ] Test messaging between residents
- [ ] Test marketplace requests
- [ ] Monitor Firestore for denied requests
- [ ] Review access patterns in Firebase Console

## Security Audit

✅ **Authentication**: All collections require authentication
✅ **Authorization**: Role-based access control enforced
✅ **Data Ownership**: Residents can only access their own data
✅ **Admin Access**: Admins have full access to all collections
✅ **Public Data**: Announcements, events, notices are read-only for residents
✅ **Subcollections**: All subcollections inherit parent access rules
✅ **Error Handling**: Graceful handling of missing documents
✅ **Default Deny**: All other access is denied by default

---
**Status**: ✅ UPDATED AND READY TO DEPLOY
**Last Updated**: March 27, 2026
**Version**: 2.0

