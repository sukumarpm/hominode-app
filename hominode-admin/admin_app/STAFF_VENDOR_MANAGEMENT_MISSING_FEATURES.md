# Staff & Vendor Management - Firestore Integration Status

## ✅ COMPLETED FEATURES

### Vendor Management
1. **Service Layer** (`lib/services/staff_vendor_service.dart`)
   - ✅ `addVendor()` - Add new vendor to Firestore
   - ✅ `getVendors()` - Real-time stream of all vendors
   - ✅ `getVendorById()` - Fetch single vendor by ID
   - ✅ `updateVendor()` - Update vendor details
   - ✅ `deleteVendor()` - Delete vendor from Firestore
   - ✅ `VendorModel` class with Firestore serialization

2. **Add Vendor Modal** (`lib/widgets/add_vendor_modal.dart`)
   - ✅ Fully integrated with Firestore
   - ✅ Saves vendor data to `vendors` collection
   - ✅ Returns success/failure status
   - ✅ Shows loading state during save

3. **Vendor List Screen** (`lib/staff_vendors_screen.dart`)
   - ✅ Uses StreamBuilder for real-time updates
   - ✅ Displays vendors from Firestore
   - ✅ Search functionality
   - ✅ Empty state handling
   - ✅ Error state handling
   - ✅ Navigation to vendor details

4. **Vendor Details Screen** (`lib/vendor_details_screen.dart`)
   - ✅ Fetches vendor by ID from Firestore
   - ✅ Displays complete vendor information
   - ✅ Edit functionality (passes vendor to modal)
   - ✅ Delete functionality (calls service.deleteVendor)
   - ✅ Loading and error states

### Staff Management
1. **Service Layer** (`lib/services/staff_vendor_service.dart`)
   - ✅ `addStaffMember()` - Add new staff to Firestore
   - ✅ `getStaffMembers()` - Real-time stream of all staff
   - ✅ `updateStaffMember()` - Update staff details
   - ✅ `deleteStaffMember()` - Delete staff from Firestore
   - ✅ `StaffMember` class with Firestore serialization

2. **Add Staff Dialog** (`lib/widgets/add_staff_member_dialog.dart`)
   - ✅ Fully integrated with Firestore
   - ✅ Saves staff data to `staff` collection
   - ✅ Returns success/failure status
   - ✅ Shows loading state during save
   - ✅ Validation for all required fields

---

## ⚠️ PENDING FEATURES

### Staff Management UI Integration

#### 1. Staff List Tab (HIGH PRIORITY)
**File:** `lib/staff_vendors_screen.dart`

**Current State:** Uses demo data from `StaffMember.getSampleStaff()`

**Required Changes:**
```dart
// Replace demo data with StreamBuilder
StreamBuilder<List<StaffMember>>(
  stream: _service.getStaffMembers(),
  builder: (context, snapshot) {
    // Handle loading, error, and data states
    // Display staff cards with real data
  },
)
```

**Tasks:**
- [ ] Add StreamBuilder for staff tab (similar to vendors tab)
- [ ] Remove demo data calls
- [ ] Add search functionality for staff
- [ ] Add empty state for no staff
- [ ] Add error handling
- [ ] Update navigation to pass `staffId` instead of `StaffMember` object

#### 2. Staff Details Screen (MEDIUM PRIORITY)
**File:** `lib/staff_details_screen.dart`

**Current State:** Receives full `StaffMember` object as parameter

**Required Changes:**
```dart
// Change constructor to accept staffId
class StaffDetailsScreen extends StatefulWidget {
  final String staffId;  // Changed from StaffMember object
  
  const StaffDetailsScreen({
    Key? key,
    required this.staffId,
  }) : super(key: key);
}

// Use FutureBuilder to fetch staff data
FutureBuilder<StaffMember?>(
  future: _service.getStaffMemberById(staffId),
  builder: (context, snapshot) {
    // Display staff details
  },
)
```

**Tasks:**
- [ ] Add `getStaffMemberById()` method to `StaffVendorService`
- [ ] Change screen to accept `staffId` parameter
- [ ] Use FutureBuilder to fetch staff data
- [ ] Update edit functionality to use Firestore
- [ ] Update delete functionality to use Firestore
- [ ] Add loading and error states

#### 3. Model Alignment (MEDIUM PRIORITY)
**Issue:** Service model vs UI model mismatch

**Service Model** (`StaffVendorService.StaffMember`):
```dart
- id, name, role, phone
- email, address (optional)
- joiningDate, salary (optional)
- status, createdAt, updatedAt
```

**UI Model** (`models/staff_models.dart`):
```dart
- All above fields PLUS:
- shift, checkedIn, checkedOut
- emergencyContact, emergencyContactPhone
- skills, rating, totalTasks, completedTasks
- profileImage
```

**Options:**
1. **Extend Service Model** (Recommended)
   - Add missing fields to Firestore schema
   - Update `StaffMember` class in service
   - Migrate existing data if any

2. **Simplify UI Model**
   - Remove advanced fields from UI
   - Use only basic fields from service
   - Add advanced features later

**Tasks:**
- [ ] Decide on model alignment strategy
- [ ] Update Firestore schema if extending
- [ ] Update service model class
- [ ] Update UI to match chosen model

#### 4. Edit Staff Modal (LOW PRIORITY)
**File:** `lib/widgets/edit_staff_member_dialog.dart` (may not exist)

**Tasks:**
- [ ] Create edit staff dialog (similar to add staff)
- [ ] Pre-populate fields with existing data
- [ ] Call `updateStaffMember()` on save
- [ ] Handle validation and errors

---

## 📊 FIRESTORE COLLECTIONS

### `staff` Collection (Current Schema)
```javascript
{
  name: String,
  role: String,
  phone: String,
  email: String (optional),
  address: String (optional),
  joiningDate: Timestamp (optional),
  salary: Number (optional),
  status: String,  // "active" or "inactive"
  createdAt: Timestamp,
  updatedAt: Timestamp
}
```

### `staff` Collection (Extended Schema - If Needed)
```javascript
{
  // Basic Info
  name: String,
  role: String,
  phone: String,
  email: String (optional),
  address: String (optional),
  
  // Employment Details
  joiningDate: Timestamp (optional),
  salary: Number (optional),
  shift: String (optional),  // "Morning", "Evening", "Night", "Full Day"
  status: String,  // "active", "inactive"
  
  // Attendance
  checkedIn: String (optional),
  checkedOut: String (optional),
  
  // Emergency Contact
  emergencyContact: String (optional),
  emergencyContactPhone: String (optional),
  
  // Skills & Performance
  skills: Array<String> (optional),
  rating: Number (default: 0.0),
  totalTasks: Number (default: 0),
  completedTasks: Number (default: 0),
  
  // Media
  profileImage: String (optional),
  
  // Timestamps
  createdAt: Timestamp,
  updatedAt: Timestamp
}
```

### `vendors` Collection (Complete)
```javascript
{
  businessName: String,
  category: String,
  contactPerson: String,
  phone: String,
  email: String (optional),
  address: String (optional),
  contractStartDate: Timestamp (optional),
  contractEndDate: Timestamp (optional),
  services: Array<String>,
  rating: Number,
  totalServices: Number,
  status: String,
  createdAt: Timestamp,
  updatedAt: Timestamp
}
```

---

## 🚀 IMPLEMENTATION PRIORITY

### Phase 1: Critical (Do First)
1. ✅ Vendor Firestore integration (COMPLETE)
2. ✅ Add Staff Dialog Firestore integration (COMPLETE)
3. ⚠️ Staff List Tab StreamBuilder integration (IN PROGRESS)

### Phase 2: Important (Do Next)
4. Staff Details Screen Firestore integration
5. Add `getStaffMemberById()` to service
6. Model alignment decision and implementation

### Phase 3: Enhancement (Do Later)
7. Edit Staff Modal creation
8. Advanced staff features (attendance, tasks, etc.)
9. Staff performance tracking

---

## 📝 QUICK REFERENCE

### Adding Staff Member
```dart
final staffId = await StaffVendorService().addStaffMember(
  name: 'John Doe',
  role: 'Security',
  phone: '+91 12345 67890',
  email: 'john@example.com',
  address: '123 Street',
  joiningDate: DateTime.now(),
  salary: 15000.0,
);
```

### Getting Staff List (Stream)
```dart
StreamBuilder<List<StaffMember>>(
  stream: StaffVendorService().getStaffMembers(),
  builder: (context, snapshot) {
    if (snapshot.hasData) {
      final staff = snapshot.data!;
      // Display staff list
    }
  },
)
```

### Updating Staff
```dart
await StaffVendorService().updateStaffMember(
  staffId,
  {
    'name': 'Updated Name',
    'phone': '+91 98765 43210',
    'status': 'inactive',
  },
);
```

### Deleting Staff
```dart
await StaffVendorService().deleteStaffMember(staffId);
```

---

## ✅ TESTING CHECKLIST

### Vendor Management
- [x] Add vendor → Appears in list immediately
- [x] Edit vendor → Changes reflect in list
- [x] Delete vendor → Removed from list
- [x] Search vendors → Filters correctly
- [x] View vendor details → Shows correct data

### Staff Management
- [x] Add staff → Saves to Firestore
- [ ] Staff list → Shows real data from Firestore
- [ ] Edit staff → Updates Firestore
- [ ] Delete staff → Removes from Firestore
- [ ] Search staff → Filters correctly
- [ ] View staff details → Shows correct data

---

## 🔧 NEXT STEPS

1. **Update Staff List Tab** in `staff_vendors_screen.dart`
   - Replace demo data with StreamBuilder
   - Use `_service.getStaffMembers()`
   - Add search, empty state, error handling

2. **Add `getStaffMemberById()` method** to `StaffVendorService`
   ```dart
   Future<StaffMember?> getStaffMemberById(String staffId) async {
     final doc = await _firestore.collection('staff').doc(staffId).get();
     if (doc.exists && doc.data() != null) {
       return StaffMember.fromFirestore(doc.id, doc.data()!);
     }
     return null;
   }
   ```

3. **Update Staff Details Screen** to fetch from Firestore
   - Change parameter to `staffId`
   - Use FutureBuilder
   - Update edit/delete methods

4. **Test Complete Flow**
   - Add staff → View in list → View details → Edit → Delete
   - Verify all data persists in Firestore
   - Check real-time updates work correctly
