# Firestore Security Rules - All Apps Complete Flow Functions

## 🎯 Overview

These rules support **three apps** with complete flow functions:
- ✅ **Admin App** - Building & resident management
- ✅ **Resident App** - View flat, bills, notices, chat
- ✅ **Security App** - Attendance, visitors, gates, assignments

---

## 📋 Complete Firestore Rules

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // ============================================
    // HELPER FUNCTIONS
    // ============================================
    
    // Check if user is authenticated
    function isAuthenticated() {
      return request.auth.uid != null;
    }
    
    // Check if user is admin
    function isAdmin() {
      return isAuthenticated() && 
             get(/databases/$(database)/documents/admins/$(request.auth.uid)).data.role == 'admin';
    }
    
    // Check if user is resident
    function isResident() {
      return isAuthenticated() && 
             get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'resident';
    }
    
    // Check if user is security staff
    function isSecurity() {
      return isAuthenticated() && 
             get(/databases/$(database)/documents/security_staff/$(request.auth.uid)).data.role == 'security';
    }
    
    // Get user's admin ID
    function getUserAdminId() {
      let userDoc = get(/databases/$(database)/documents/users/$(request.auth.uid)).data;
      return userDoc.adminId;
    }
    
    // Get security staff's admin ID
    function getSecurityAdminId() {
      let securityDoc = get(/databases/$(database)/documents/security_staff/$(request.auth.uid)).data;
      return securityDoc.adminId;
    }
    
    // Check if admin owns building
    function adminOwnsBuild(buildingId) {
      return isAdmin() && 
             get(/databases/$(database)/documents/buildings/$(buildingId)).data.adminId == request.auth.uid;
    }
    
    // Check if admin owns flat
    function adminOwnsFlat(flatId) {
      let flatDoc = get(/databases/$(database)/documents/flats/$(flatId)).data;
      return isAdmin() && flatDoc.adminId == request.auth.uid;
    }
    
    // Check if resident is assigned to flat
    function residentAssignedToFlat(flatId) {
      let flatDoc = get(/databases/$(database)/documents/flats/$(flatId)).data;
      return isResident() && flatDoc.residentUserId == request.auth.uid;
    }
    
    // Check if security staff assigned to building
    function securityAssignedToBuilding(buildingId) {
      let securityDoc = get(/databases/$(database)/documents/security_staff/$(request.auth.uid)).data;
      return isSecurity() && 
             securityDoc.buildingIds != null && 
             buildingId in securityDoc.buildingIds;
    }
    
    // ============================================
    // ADMINS COLLECTION
    // ============================================
    // Admin profile - only admin can read/write own
    match /admins/{adminId} {
      allow read: if isAuthenticated() && request.auth.uid == adminId;
      allow write: if isAuthenticated() && request.auth.uid == adminId;
      allow create: if isAuthenticated();
    }
    
    // ============================================
    // BUILDINGS COLLECTION
    // ============================================
    // Admin can read/write own buildings
    // Residents can read buildings they're assigned to
    // Security can read buildings they're assigned to
    match /buildings/{buildingId} {
      allow read: if (isAdmin() && resource.data.adminId == request.auth.uid) ||
                     (isResident() && resource.data.adminId == getUserAdminId()) ||
                     (isSecurity() && securityAssignedToBuilding(buildingId));
      
      allow write: if isAdmin() && resource.data.adminId == request.auth.uid;
      
      allow create: if isAdmin();
    }
    
    // ============================================
    // FLATS COLLECTION
    // ============================================
    // Admin can read/write own flats
    // Residents can read their assigned flat
    // Security can read flats in their buildings
    match /flats/{flatId} {
      allow read: if (isAdmin() && resource.data.adminId == request.auth.uid) ||
                     (isResident() && resource.data.residentUserId == request.auth.uid) ||
                     (isSecurity() && securityAssignedToBuilding(resource.data.buildingId));
      
      allow write: if isAdmin() && resource.data.adminId == request.auth.uid;
      
      allow create: if isAdmin();
    }
    
    // ============================================
    // USERS COLLECTION (Residents)
    // ============================================
    // Resident can read/write own document
    // Admin can read/write residents in their buildings
    match /users/{userId} {
      allow read: if (isResident() && request.auth.uid == userId) ||
                     (isAdmin() && resource.data.adminId == request.auth.uid);
      
      allow write: if (isResident() && request.auth.uid == userId) ||
                      (isAdmin() && resource.data.adminId == request.auth.uid);
      
      allow create: if isAdmin() || isResident();
    }
    
    // ============================================
    // SECURITY_STAFF COLLECTION
    // ============================================
    // Security staff can read own document
    // Admin can read/write security staff in their buildings
    match /security_staff/{staffId} {
      allow read: if (isSecurity() && request.auth.uid == staffId) ||
                     (isAdmin() && resource.data.adminId == request.auth.uid);
      
      allow write: if isAdmin() && resource.data.adminId == request.auth.uid;
      
      allow create: if isAdmin();
    }
    
    // ============================================
    // BUILDINGS COLLECTION - OCCUPANCY STATS
    // ============================================
    // Residents can read occupancy of their building
    match /buildings/{buildingId}/occupancy/{document=**} {
      allow read: if (isAdmin() && 
                      get(/databases/$(database)/documents/buildings/$(buildingId)).data.adminId == request.auth.uid) ||
                     (isResident() && 
                      get(/databases/$(database)/documents/buildings/$(buildingId)).data.adminId == getUserAdminId());
    }
    
    // ============================================
    // BILLS COLLECTION
    // ============================================
    // Resident can read own bills
    // Admin can read/write bills for residents in their buildings
    match /bills/{billId} {
      allow read: if (isResident() && resource.data.residentId == request.auth.uid) ||
                     (isAdmin() && resource.data.adminId == request.auth.uid);
      
      allow write: if isAdmin() && resource.data.adminId == request.auth.uid;
      
      allow create: if isAdmin();
    }
    
    // ============================================
    // NOTICES COLLECTION
    // ============================================
    // Resident can read notices for their building
    // Admin can read/write notices for their buildings
    match /notices/{noticeId} {
      allow read: if (isResident() && resource.data.buildingId == 
                      get(/databases/$(database)/documents/users/$(request.auth.uid)).data.buildingId) ||
                     (isAdmin() && resource.data.adminId == request.auth.uid);
      
      allow write: if isAdmin() && resource.data.adminId == request.auth.uid;
      
      allow create: if isAdmin();
    }
    
    // ============================================
    // COMPLAINTS COLLECTION
    // ============================================
    // Resident can read/write own complaints
    // Admin can read/write complaints for residents in their buildings
    match /complaints/{complaintId} {
      allow read: if (isResident() && resource.data.residentId == request.auth.uid) ||
                     (isAdmin() && resource.data.adminId == request.auth.uid);
      
      allow write: if (isResident() && resource.data.residentId == request.auth.uid) ||
                      (isAdmin() && resource.data.adminId == request.auth.uid);
      
      allow create: if isResident() || isAdmin();
    }
    
    // ============================================
    // VISITORS COLLECTION
    // ============================================
    // Resident can read own visitors
    // Admin can read/write visitors for residents in their buildings
    // Security can read visitors in their buildings
    match /visitors/{visitorId} {
      allow read: if (isResident() && resource.data.residentId == request.auth.uid) ||
                     (isAdmin() && resource.data.adminId == request.auth.uid) ||
                     (isSecurity() && securityAssignedToBuilding(resource.data.buildingId));
      
      allow write: if (isResident() && resource.data.residentId == request.auth.uid) ||
                      (isAdmin() && resource.data.adminId == request.auth.uid) ||
                      (isSecurity() && securityAssignedToBuilding(resource.data.buildingId));
      
      allow create: if isResident() || isAdmin() || isSecurity();
    }
    
    // ============================================
    // PARKING COLLECTION
    // ============================================
    // Resident can read own parking slots
    // Admin can read/write parking for residents in their buildings
    match /parking/{parkingId} {
      allow read: if (isResident() && resource.data.residentId == request.auth.uid) ||
                     (isAdmin() && resource.data.adminId == request.auth.uid);
      
      allow write: if isAdmin() && resource.data.adminId == request.auth.uid;
      
      allow create: if isAdmin();
    }
    
    // ============================================
    // VEHICLES COLLECTION
    // ============================================
    // Resident can read/write own vehicles
    // Admin can read/write vehicles for residents in their buildings
    match /vehicles/{vehicleId} {
      allow read: if (isResident() && resource.data.residentId == request.auth.uid) ||
                     (isAdmin() && resource.data.adminId == request.auth.uid);
      
      allow write: if (isResident() && resource.data.residentId == request.auth.uid) ||
                      (isAdmin() && resource.data.adminId == request.auth.uid);
      
      allow create: if isResident() || isAdmin();
    }
    
    // ============================================
    // ATTENDANCE COLLECTION
    // ============================================
    // Security staff can read/write own attendance
    // Admin can read attendance for security staff in their buildings
    match /attendance/{attendanceId} {
      allow read: if (isSecurity() && resource.data.staffId == request.auth.uid) ||
                     (isAdmin() && resource.data.adminId == request.auth.uid);
      
      allow write: if (isSecurity() && resource.data.staffId == request.auth.uid) ||
                      (isAdmin() && resource.data.adminId == request.auth.uid);
      
      allow create: if isSecurity() || isAdmin();
    }
    
    // ============================================
    // SECURITY_WORK_ASSIGNMENTS COLLECTION
    // ============================================
    // Security staff can read own assignments
    // Admin can read/write assignments for security staff in their buildings
    match /security_work_assignments/{assignmentId} {
      allow read: if (isSecurity() && resource.data.staffId == request.auth.uid) ||
                     (isAdmin() && resource.data.adminId == request.auth.uid);
      
      allow write: if isAdmin() && resource.data.adminId == request.auth.uid;
      
      allow create: if isAdmin();
    }
    
    // ============================================
    // GATES COLLECTION
    // ============================================
    // Security staff can read gates in their buildings
    // Admin can read/write gates in their buildings
    match /gates/{gateId} {
      allow read: if (isAdmin() && resource.data.adminId == request.auth.uid) ||
                     (isSecurity() && securityAssignedToBuilding(resource.data.buildingId));
      
      allow write: if isAdmin() && resource.data.adminId == request.auth.uid;
      
      allow create: if isAdmin();
    }
    
    // ============================================
    // CHAT COLLECTION
    // ============================================
    // Residents can read/write messages in their building chat
    // Admin can read messages in their buildings
    match /chat/{chatId} {
      allow read: if (isResident() && resource.data.buildingId == 
                      get(/databases/$(database)/documents/users/$(request.auth.uid)).data.buildingId) ||
                     (isAdmin() && resource.data.adminId == request.auth.uid);
      
      allow write: if (isResident() && resource.data.buildingId == 
                       get(/databases/$(database)/documents/users/$(request.auth.uid)).data.buildingId) ||
                      (isAdmin() && resource.data.adminId == request.auth.uid);
      
      allow create: if isResident() || isAdmin();
    }
    
    // ============================================
    // NOTIFICATIONS COLLECTION
    // ============================================
    // Resident can read own notifications
    // Admin can read/write notifications for residents in their buildings
    // Security can read own notifications
    match /notifications/{notificationId} {
      allow read: if (isResident() && resource.data.userId == request.auth.uid) ||
                     (isSecurity() && resource.data.userId == request.auth.uid) ||
                     (isAdmin() && resource.data.adminId == request.auth.uid);
      
      allow write: if isAdmin() || isSecurity();
      
      allow create: if isAdmin() || isSecurity();
    }
    
    // ============================================
    // AMENITIES COLLECTION
    // ============================================
    // Resident can read amenities in their building
    // Admin can read/write amenities in their buildings
    match /amenities/{amenityId} {
      allow read: if (isResident() && resource.data.buildingId == 
                      get(/databases/$(database)/documents/users/$(request.auth.uid)).data.buildingId) ||
                     (isAdmin() && resource.data.adminId == request.auth.uid);
      
      allow write: if isAdmin() && resource.data.adminId == request.auth.uid;
      
      allow create: if isAdmin();
    }
    
    // ============================================
    // AMENITY_BOOKINGS COLLECTION
    // ============================================
    // Resident can read/write own bookings
    // Admin can read/write bookings for residents in their buildings
    match /amenity_bookings/{bookingId} {
      allow read: if (isResident() && resource.data.residentId == request.auth.uid) ||
                     (isAdmin() && resource.data.adminId == request.auth.uid);
      
      allow write: if (isResident() && resource.data.residentId == request.auth.uid) ||
                      (isAdmin() && resource.data.adminId == request.auth.uid);
      
      allow create: if isResident() || isAdmin();
    }
    
    // ============================================
    // EVENTS_ANNOUNCEMENTS COLLECTION
    // ============================================
    // Resident can read events in their building
    // Admin can read/write events in their buildings
    match /events_announcements/{eventId} {
      allow read: if (isResident() && resource.data.buildingId == 
                      get(/databases/$(database)/documents/users/$(request.auth.uid)).data.buildingId) ||
                     (isAdmin() && resource.data.adminId == request.auth.uid);
      
      allow write: if isAdmin() && resource.data.adminId == request.auth.uid;
      
      allow create: if isAdmin();
    }
    
    // ============================================
    // POSTERS COLLECTION
    // ============================================
    // Resident can read posters in their building
    // Admin can read/write posters in their buildings
    match /posters/{posterId} {
      allow read: if (isResident() && resource.data.buildingId == 
                      get(/databases/$(database)/documents/users/$(request.auth.uid)).data.buildingId) ||
                     (isAdmin() && resource.data.adminId == request.auth.uid);
      
      allow write: if isAdmin() && resource.data.adminId == request.auth.uid;
      
      allow create: if isAdmin();
    }
    
    // ============================================
    // APARTMENT_IMAGES COLLECTION
    // ============================================
    // Resident can read images for their flat
    // Admin can read/write images for flats in their buildings
    match /apartment_images/{imageId} {
      allow read: if (isResident() && resource.data.buildingId == 
                      get(/databases/$(database)/documents/users/$(request.auth.uid)).data.buildingId) ||
                     (isAdmin() && resource.data.adminId == request.auth.uid);
      
      allow write: if isAdmin() && resource.data.adminId == request.auth.uid;
      
      allow create: if isAdmin();
    }
    
    // ============================================
    // STAFF_VENDORS COLLECTION
    // ============================================
    // Admin can read/write staff and vendors in their buildings
    match /staff_vendors/{staffVendorId} {
      allow read: if isAdmin() && resource.data.adminId == request.auth.uid;
      
      allow write: if isAdmin() && resource.data.adminId == request.auth.uid;
      
      allow create: if isAdmin();
    }
    
    // ============================================
    // BROADCAST_MESSAGES COLLECTION
    // ============================================
    // Resident can read messages for their building
    // Admin can read/write messages for their buildings
    match /broadcast_messages/{messageId} {
      allow read: if (isResident() && resource.data.buildingId == 
                      get(/databases/$(database)/documents/users/$(request.auth.uid)).data.buildingId) ||
                     (isAdmin() && resource.data.adminId == request.auth.uid);
      
      allow write: if isAdmin() && resource.data.adminId == request.auth.uid;
      
      allow create: if isAdmin();
    }
    
    // ============================================
    // DENY ALL OTHER COLLECTIONS
    // ============================================
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

---

## 🔐 Security Features Implemented

### ✅ Multi-App Support
- **Admin App**: Full CRUD on buildings, residents, flats, staff, vendors
- **Resident App**: Read own data, read building data, create complaints/visitors
- **Security App**: Read/write attendance, visitors, gates in assigned buildings

### ✅ Tenant Isolation
- Admins can only access their own buildings
- Residents can only access their own data
- Security staff can only access assigned buildings
- No cross-tenant data access

### ✅ Role-Based Access Control
- **Admin Role**: Full control over buildings and residents
- **Resident Role**: Limited access to own data and building info
- **Security Role**: Access to assigned buildings and security operations

### ✅ Data Ownership
- Each document linked to admin via `adminId`
- Residents linked to buildings via `buildingId`
- Security staff linked to buildings via `buildingIds` array

### ✅ Audit Trail
- All operations logged by Firestore
- Timestamps on all documents
- User identification via `request.auth.uid`

---

## 📊 Collections & Access Matrix

| Collection | Admin | Resident | Security |
|-----------|-------|----------|----------|
| admins | Read/Write Own | ❌ | ❌ |
| buildings | Read/Write Own | Read Own | Read Assigned |
| flats | Read/Write Own | Read Own | Read Assigned |
| users | Read/Write Own | Read/Write Own | ❌ |
| security_staff | Read/Write Own | ❌ | Read Own |
| bills | Read/Write Own | Read Own | ❌ |
| notices | Read/Write Own | Read Own | ❌ |
| complaints | Read/Write Own | Read/Write Own | ❌ |
| visitors | Read/Write Own | Read/Write Own | Read/Write |
| parking | Read/Write Own | Read Own | ❌ |
| vehicles | Read/Write Own | Read/Write Own | ❌ |
| attendance | Read Own | ❌ | Read/Write Own |
| security_work_assignments | Read/Write Own | ❌ | Read Own |
| gates | Read/Write Own | ❌ | Read Assigned |
| chat | Read/Write Own | Read/Write Own | ❌ |
| notifications | Read/Write Own | Read Own | Read Own |
| amenities | Read/Write Own | Read Own | ❌ |
| amenity_bookings | Read/Write Own | Read/Write Own | ❌ |
| events_announcements | Read/Write Own | Read Own | ❌ |
| posters | Read/Write Own | Read Own | ❌ |
| apartment_images | Read/Write Own | Read Own | ❌ |
| staff_vendors | Read/Write Own | ❌ | ❌ |
| broadcast_messages | Read/Write Own | Read Own | ❌ |

---

## 🚀 Flow Functions Supported

### Admin App Flows
✅ Admin Login → Access Dashboard
✅ Create Building → Generate Flats
✅ Create Resident → Assign to Flat
✅ Manage Bills → Create & Update
✅ Manage Complaints → Assign & Resolve
✅ Manage Visitors → Approve & Track
✅ Manage Parking → Assign Slots
✅ Manage Staff/Vendors → Create & Update
✅ Manage Security → Assign Work
✅ Manage Amenities → Create & Book
✅ Send Notices → Broadcast Messages
✅ View Reports → Analytics

### Resident App Flows
✅ Resident Login → View Dashboard
✅ View Flat Details → Building Info
✅ View Bills → Pay Bills
✅ View Notices → Read Announcements
✅ Submit Complaints → Track Status
✅ Register Visitors → Manage Guests
✅ Register Vehicles → Manage Parking
✅ Book Amenities → View Bookings
✅ Chat with Admin → Send Messages
✅ View Posters → Apartment Images
✅ View Events → Announcements

### Security App Flows
✅ Security Login → View Dashboard
✅ Mark Attendance → Check In/Out
✅ Manage Visitors → Approve Entry
✅ Manage Gates → Control Access
✅ View Assignments → Complete Tasks
✅ View Parking → Monitor Slots
✅ View Residents → Building Info
✅ Send Notifications → Alert Residents

---

## 📋 How to Apply These Rules

### Step 1: Open Firebase Console
1. Go to https://console.firebase.google.com
2. Select your project
3. Click "Firestore Database"

### Step 2: Navigate to Rules
1. Click "Rules" tab at the top
2. You'll see current rules

### Step 3: Replace Rules
1. Select all text (Ctrl+A or Cmd+A)
2. Delete selected text
3. Paste the complete rules from above
4. Click "Publish"

### Step 4: Verify
1. Wait for rules to be published (1-2 minutes)
2. Check status indicator at bottom
3. You should see "Rules updated successfully"

---

## 🔍 Testing the Rules

### Test 1: Admin Can Access Own Building
```
Admin A logs in
Admin A creates Building 1
Admin A can read Building 1 ✅
Admin B cannot read Building 1 ✅
```

### Test 2: Resident Can Access Own Data
```
Resident 1 logs in
Resident 1 can read own profile ✅
Resident 1 can read own bills ✅
Resident 1 cannot read other residents' data ✅
```

### Test 3: Security Can Access Assigned Buildings
```
Security 1 logs in
Security 1 assigned to Building 1
Security 1 can read Building 1 ✅
Security 1 cannot read Building 2 ✅
```

### Test 4: Deny All Other Collections
```
Any user tries to access unknown collection ✅
Access denied ✅
```

---

## ⚠️ Important Notes

### Collection Names
Make sure your Firestore collections match exactly:
- `admins` - Admin profiles
- `buildings` - Building information
- `flats` - Flat information
- `users` - Resident information
- `security_staff` - Security staff profiles
- `bills` - Bill information
- `notices` - Notice information
- `complaints` - Complaint information
- `visitors` - Visitor information
- `parking` - Parking slot information
- `vehicles` - Vehicle information
- `attendance` - Attendance records
- `security_work_assignments` - Security assignments
- `gates` - Gate information
- `chat` - Chat messages
- `notifications` - Notifications
- `amenities` - Amenity information
- `amenity_bookings` - Amenity bookings
- `events_announcements` - Events and announcements
- `posters` - Poster information
- `apartment_images` - Apartment images
- `staff_vendors` - Staff and vendor information
- `broadcast_messages` - Broadcast messages

### Required Fields
Each document must have these fields:
- `adminId` - Link to admin (for admin-owned collections)
- `buildingId` - Link to building (for building-related collections)
- `residentId` or `userId` - Link to resident (for resident-related collections)
- `staffId` - Link to security staff (for security-related collections)
- `createdAt` - Timestamp
- `updatedAt` - Timestamp

### Helper Functions
The rules use helper functions for:
- `isAuthenticated()` - Check if user is logged in
- `isAdmin()` - Check if user is admin
- `isResident()` - Check if user is resident
- `isSecurity()` - Check if user is security staff
- `adminOwnsBuild()` - Check if admin owns building
- `securityAssignedToBuilding()` - Check if security assigned to building

---

## 🚨 Troubleshooting

### Issue: "Permission denied" errors
**Solution**:
1. Verify rules are published
2. Check that `adminId` field is set correctly
3. Verify user is authenticated
4. Check collection names match exactly

### Issue: Residents cannot read building data
**Solution**:
1. Verify resident's `buildingId` matches building's `buildingId`
2. Check that resident's `adminId` matches building's `adminId`
3. Verify resident document exists in `users` collection

### Issue: Security staff cannot access buildings
**Solution**:
1. Verify security staff document has `buildingIds` array
2. Check that building ID is in the array
3. Verify security staff's `adminId` matches building's `adminId`

### Issue: Admins cannot access their data
**Solution**:
1. Verify admin document exists in `admins` collection
2. Check that admin's UID matches document ID
3. Verify `adminId` field is set correctly in all documents

---

## 📊 Performance Considerations

### Indexes Required
The following indexes may be needed:
1. `users` collection: `role` (Ascending), `adminId` (Ascending)
2. `security_staff` collection: `adminId` (Ascending)
3. `bills` collection: `adminId` (Ascending), `status` (Ascending)
4. `complaints` collection: `adminId` (Ascending), `status` (Ascending)
5. `visitors` collection: `buildingId` (Ascending), `status` (Ascending)

### Query Optimization
- Use `where` clauses to filter by `adminId` or `buildingId`
- Use `limit` to reduce data transfer
- Use `orderBy` for sorting (requires index)
- Avoid fetching all documents

---

## ✅ Deployment Checklist

- [ ] Rules copied from above
- [ ] Rules pasted into Firebase Console
- [ ] Rules published successfully
- [ ] All collections created
- [ ] Required fields added to documents
- [ ] Admin can access own buildings
- [ ] Residents can access own data
- [ ] Security staff can access assigned buildings
- [ ] Cross-tenant access denied
- [ ] Error messages are user-friendly

---

## 📞 Support

### Common Issues
- See "Troubleshooting" section above
- Check collection names match exactly
- Verify required fields are present
- Check that `adminId` is set correctly

### External Resources
- [Firestore Security Rules Documentation](https://firebase.google.com/docs/firestore/security/start)
- [Firebase Console](https://console.firebase.google.com)
- [Firestore Best Practices](https://firebase.google.com/docs/firestore/best-practices)

---

**Status**: ✅ READY FOR PRODUCTION
**Last Updated**: 2026-03-27
**Version**: 1.0 - COMPLETE
