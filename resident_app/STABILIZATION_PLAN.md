# Flutter + Firebase App Stabilization Plan

## CRITICAL FIXES (Do First)

### 1. Security Issues
- [ ] Remove plaintext passwords from Firestore
- [ ] Move Cloudinary credentials to backend/environment
- [ ] Implement proper password hashing (bcrypt)
- [ ] Add Firestore security rules for role-based access

### 2. Null Safety & Type Casting
- [ ] Add null checks to all user data access
- [ ] Fix unsafe type casting in services
- [ ] Add validation for required fields before use
- [ ] Implement proper error handling

### 3. Firestore Collections Standardization
```
users/
  {userId}
    - email
    - phone
    - name
    - role (resident|admin|staff)
    - buildingId
    - flatId
    - authUid (Firebase Auth UID)
    - createdAt
    - updatedAt

buildings/
  {buildingId}
    - name
    - address
    - organizationId
    - createdAt

flats/
  {flatId}
    - buildingId
    - flatNumber
    - residents[] (array of userIds)
    - createdAt

complaints/
  {complaintId}
    - userId
    - buildingId
    - flatId
    - title
    - description
    - category
    - status (pending|assigned|in_progress|completed)
    - assignedStaffId
    - images[]
    - createdAt
    - updatedAt

bookings/
  {bookingId}
    - userId
    - buildingId
    - amenityId
    - date
    - timeSlot
    - status (pending|confirmed|cancelled)
    - numberOfPeople
    - createdAt

amenities/
  {amenityId}
    - buildingId
    - name
    - type
    - maxCapacity
    - timeSlots[]
    - isFree
    - price
    - createdAt

chats/
  {chatId}
    - participantIds[]
    - buildingId
    - flatId
    - lastMessage
    - lastMessageTime
    - createdAt
    - updatedAt
    messages/
      {messageId}
        - senderId
        - text
        - timestamp
        - read

marketplaces/
  {listingId}
    - userId
    - buildingId
    - title
    - price
    - images[]
    - status (active|sold|deleted)
    - createdAt
    phoneRequests/
      {requestId}
        - requesterId
        - requesterPhone
        - timestamp
```

### 4. Global Validation Service
Create `lib/src/services/validation_service.dart`:
- Check user exists
- Check buildingId exists
- Check flatId exists
- Restrict access if invalid
- Validate role permissions

### 5. Firestore Query Fixes
- [ ] Simplify queries (avoid multiple where + orderBy)
- [ ] Filter locally instead of in Firestore
- [ ] Create required indexes
- [ ] Add error handling for index errors

### 6. Real-time Streaming
- [ ] Convert all screens to StreamBuilder
- [ ] Add connection state monitoring
- [ ] Implement automatic reconnection
- [ ] Cancel streams on logout

### 7. Module-Specific Fixes
- [ ] Parking: Assign slot using vehicleId
- [ ] Amenities: Hide past time slots, limit capacity
- [ ] Marketplace: Show correct buyer requests to seller
- [ ] Posters: Upload to Cloudinary, store URL
- [ ] Admin delete: Remove building → unassign users
- [ ] Chat: Real-time messaging with timestamp

## Implementation Order
1. Validation Service (foundation)
2. Security fixes (passwords, credentials)
3. Null safety (prevent crashes)
4. Firestore queries (performance)
5. Real-time streaming (UX)
6. Module-specific fixes (features)
7. Admin operations (management)
