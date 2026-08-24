# Flow Function Fixes Required - Multi-Tenancy Implementation

## AUDIT RESULTS

### ✅ COMPLETED (Following Flow Function)
1. **Buildings** - Stores adminId + admin details, filters by adminId
2. **Flats** - Stores adminId + admin details, filters by adminId  
3. **Residents (Users)** - Stores adminId + admin details, filters by adminId
4. **Communication Center** - Filters by adminId

### ❌ NEEDS FIXING (NOT Following Flow Function)

#### 1. Billing Service
**Current Issues:**
- `addBill()` does NOT store adminId or admin details
- `getBills()` queries ALL bills without filtering by admin
- `generateMonthlyBills()` queries ALL residents without filtering by admin
- Multi-tenancy broken - admins can see other admins' bills

**Required Changes:**
- Add adminId, adminName, adminEmail, adminPhone, organization to bill documents
- Update `addBill()` to accept and store admin details
- Update `generateMonthlyBills()` to filter residents by adminId
- Update `getBills()` to filter by adminId
- Update BillModel to include admin fields

#### 2. Complaint Service  
**Current Issues:**
- Does NOT store adminId or admin details
- `getComplaints()` queries ALL complaints without filtering
- `getPendingComplaints()` queries ALL complaints without filtering
- Multi-tenancy broken - admins can see other admins' complaints

**Required Changes:**
- Add adminId, adminName, adminEmail, adminPhone, organization to complaint documents
- Add method to create complaints with admin details
- Update `getComplaints()` to filter by adminId
- Update `getPendingComplaints()` to filter by adminId
- Update ComplaintModel to include admin fields

#### 3. Visitor Service
**Current Issues:**
- `createVisitorRequest()` does NOT store adminId or admin details
- `getVisitors()` queries ALL visitors without filtering
- `getPendingVisitors()`, `getActiveVisitors()`, `getHistoryVisitors()` query ALL without filtering
- Multi-tenancy broken - admins can see other admins' visitors

**Required Changes:**
- Add adminId, adminName, adminEmail, adminPhone, organization to visitor documents
- Update `createVisitorRequest()` to accept and store admin details
- Update all get methods to filter by adminId
- Update VisitorModel to include admin fields

#### 4. Staff/Vendor Service
**Current Issues:**
- `addStaffMember()` does NOT store adminId or admin details
- `addVendor()` does NOT store adminId or admin details
- `getStaffMembers()` queries ALL staff without filtering
- `getVendors()` queries ALL vendors without filtering
- Multi-tenancy broken - admins can see other admins' staff/vendors

**Required Changes:**
- Add adminId, adminName, adminEmail, adminPhone, organization to staff/vendor documents
- Update `addStaffMember()` to accept and store admin details
- Update `addVendor()` to accept and store admin details
- Update `getStaffMembers()` to filter by adminId
- Update `getVendors()` to filter by adminId
- Update StaffMember and Vendor models to include admin fields

#### 5. Notice Service
**Status:** Need to audit
**Required:** Check if stores adminId and filters by admin

#### 6. Event/Announcement Service
**Status:** Need to audit
**Required:** Check if stores adminId and filters by admin

## IMPLEMENTATION PLAN

### Phase 1: Billing Service (PRIORITY)
1. Update BillModel to include admin fields
2. Update `addBill()` to accept admin details
3. Update `generateMonthlyBills()` to filter by adminId
4. Update `getBills()` to filter by adminId
5. Test multi-tenancy isolation

### Phase 2: Complaint Service
1. Update ComplaintModel to include admin fields
2. Add `createComplaint()` method with admin details
3. Update all query methods to filter by adminId
4. Test multi-tenancy isolation

### Phase 3: Visitor Service
1. Update VisitorModel to include admin fields
2. Update `createVisitorRequest()` to store admin details
3. Update all query methods to filter by adminId
4. Test multi-tenancy isolation

### Phase 4: Staff/Vendor Service
1. Update StaffMember and Vendor models to include admin fields
2. Update add methods to store admin details
3. Update all query methods to filter by adminId
4. Test multi-tenancy isolation

### Phase 5: Notice & Event Services
1. Audit both services
2. Apply same pattern if needed
3. Test multi-tenancy isolation

## FLOW FUNCTION PATTERN (REFERENCE)

### When Creating Data:
```dart
// 1. Get admin details from AdminService
final adminProfile = await AdminService().getAdminProfile(adminId);

// 2. Store in Firestore with admin details
await _firestore.collection('collection_name').add({
  // ... other fields
  'adminId': adminId,
  'adminName': adminProfile['name'],
  'adminEmail': adminProfile['email'],
  'adminPhone': adminProfile['phone'],
  'organization': adminProfile['organization'],
  'createdAt': FieldValue.serverTimestamp(),
});
```

### When Querying Data:
```dart
// Filter by adminId to ensure multi-tenancy
Stream<List<Model>> getData(String adminId) {
  return _firestore
      .collection('collection_name')
      .where('adminId', isEqualTo: adminId)
      .snapshots()
      .map((snapshot) => /* map to models */);
}
```

## NEXT STEPS
1. Start with Billing Service (highest priority)
2. Fix one service at a time
3. Test each fix before moving to next
4. Document changes in separate completion files
