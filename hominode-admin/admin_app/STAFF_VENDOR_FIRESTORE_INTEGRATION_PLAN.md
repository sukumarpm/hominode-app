# Staff & Vendor Management - Firestore Integration Plan

## STATUS: Service Created - Implementation Needed

---

## What Was Created

### ✅ StaffVendorService (`lib/services/staff_vendor_service.dart`)
Complete Firestore service with:
- Staff member CRUD operations
- Vendor CRUD operations
- Real-time streams
- Data models (StaffMember, VendorModel)

---

## Implementation Steps

### Step 1: Update Add Vendor Modal ✅ SERVICE READY

**File**: `lib/widgets/add_vendor_modal.dart`

**Changes Needed**:
```dart
// Add import
import '../services/staff_vendor_service.dart';

// Add service instance
final StaffVendorService _service = StaffVendorService();

// Update _handleAddVendor method
Future<void> _handleAddVendor() async {
  if (!_formKey.currentState!.validate()) {
    return;
  }

  if (selectedCategory == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please select a category')),
    );
    return;
  }

  setState(() {
    isLoading = true;
  });

  try {
    // Save to Firestore
    await _service.addVendor(
      businessName: _businessNameController.text.trim(),
      category: selectedCategory!,
      contactPerson: _contactPersonController.text.trim(),
      phone: _phoneController.text.trim(),
    );

    setState(() {
      isLoading = false;
    });

    Navigator.of(context).pop(true); // Return true for success

  } catch (e) {
    setState(() {
      isLoading = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Failed to add vendor: $e'),
        backgroundColor: const Color(0xFFEF4444),
      ),
    );
  }
}
```

### Step 2: Update Staff Vendors Screen

**File**: `lib/staff_vendors_screen.dart`

**Changes Needed**:

1. **Add imports**:
```dart
import 'services/staff_vendor_service.dart';
```

2. **Replace demo data with Firestore stream**:
```dart
class _StaffVendorsScreenState extends State<StaffVendorsScreen> {
  int selectedTabIndex = 2;
  final List<String> tabs = ['Staff', 'Attendance', 'Vendors'];
  
  // Remove: late List<Vendor> vendors;
  // Remove: late List<Vendor> filteredVendors;
  
  final TextEditingController _searchController = TextEditingController();
  final StaffVendorService _service = StaffVendorService();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    // Remove: vendors = Vendor.getSampleVendors();
    // Remove: filteredVendors = vendors;
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }
}
```

3. **Update vendor list to use StreamBuilder**:
```dart
// In build method, replace the vendor list with:
StreamBuilder<List<VendorModel>>(
  stream: _service.getVendors(),
  builder: (context, snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Center(child: CircularProgressIndicator());
    }

    if (snapshot.hasError) {
      return Center(
        child: Text('Error: ${snapshot.error}'),
      );
    }

    final vendors = snapshot.data ?? [];
    
    // Filter vendors based on search
    final filteredVendors = _searchQuery.isEmpty
        ? vendors
        : vendors.where((vendor) {
            return vendor.businessName.toLowerCase().contains(_searchQuery) ||
                   vendor.category.toLowerCase().contains(_searchQuery) ||
                   vendor.contactPerson.toLowerCase().contains(_searchQuery) ||
                   vendor.phone.contains(_searchQuery);
          }).toList();

    if (filteredVendors.isEmpty) {
      return Center(
        child: Text(_searchQuery.isEmpty 
            ? 'No vendors added yet' 
            : 'No vendors found'),
      );
    }

    return ListView.builder(
      itemCount: filteredVendors.length,
      itemBuilder: (context, index) {
        return _buildVendorCard(filteredVendors[index]);
      },
    );
  },
)
```

4. **Update _showAddVendorModal**:
```dart
void _showAddVendorModal(BuildContext context) {
  showDialog(
    context: context,
    barrierColor: const Color(0x59000000),
    builder: (BuildContext context) {
      return const AddVendorModal();
    },
  ).then((result) {
    if (result == true) {
      // No need to manually refresh - StreamBuilder handles it automatically
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vendor added successfully'),
          backgroundColor: Color(0xFF16A34A),
          duration: Duration(seconds: 2),
        ),
      );
    }
  });
}
```

5. **Update vendor card to use VendorModel**:
```dart
Widget _buildVendorCard(VendorModel vendor) {
  // Update all references from Vendor to VendorModel
  // businessName, category, contactPerson, phone, etc.
}
```

### Step 3: Update Vendor Details Screen

**File**: `lib/vendor_details_screen.dart`

**Changes Needed**:
1. Accept vendor ID instead of Vendor object
2. Fetch vendor details from Firestore
3. Display real-time data

```dart
class VendorDetailsScreen extends StatelessWidget {
  final String vendorId;
  final StaffVendorService _service = StaffVendorService();

  const VendorDetailsScreen({
    Key? key,
    required this.vendorId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<VendorModel?>(
      future: _service.getVendorById(vendorId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError || snapshot.data == null) {
          return Scaffold(
            body: Center(
              child: Text('Error loading vendor details'),
            ),
          );
        }

        final vendor = snapshot.data!;
        
        // Build UI with vendor data
        return Scaffold(
          // ... existing UI code
        );
      },
    );
  }
}
```

### Step 4: Add Staff Member Modal (Similar to Vendor)

**File**: `lib/widgets/add_staff_member_dialog.dart`

**Changes Needed**:
```dart
import '../services/staff_vendor_service.dart';

final StaffVendorService _service = StaffVendorService();

Future<void> _handleAddStaff() async {
  // Validate form
  if (!_formKey.currentState!.validate()) {
    return;
  }

  setState(() {
    isLoading = true;
  });

  try {
    await _service.addStaffMember(
      name: _nameController.text.trim(),
      role: selectedRole!,
      phone: _phoneController.text.trim(),
      email: _emailController.text.trim(),
      // ... other fields
    );

    setState(() {
      isLoading = false;
    });

    Navigator.of(context).pop(true);

  } catch (e) {
    setState(() {
      isLoading = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Failed to add staff: $e'),
        backgroundColor: const Color(0xFFEF4444),
      ),
    );
  }
}
```

---

## Firestore Collections Structure

### `staff` Collection
```javascript
{
  name: String,
  role: String,  // e.g., "Security Guard", "Cleaner", "Maintenance"
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

### `vendors` Collection
```javascript
{
  businessName: String,
  category: String,  // "Plumbing", "Electrician", etc.
  contactPerson: String,
  phone: String,
  email: String (optional),
  address: String (optional),
  contractStartDate: Timestamp (optional),
  contractEndDate: Timestamp (optional),
  services: Array<String>,
  rating: Number,
  totalServices: Number,
  status: String,  // "active" or "inactive"
  createdAt: Timestamp,
  updatedAt: Timestamp
}
```

---

## Benefits of This Implementation

### ✅ Real-Time Updates
- Vendors/Staff appear immediately after adding
- Changes sync across all devices
- No manual refresh needed

### ✅ No Demo Data
- All data from Firestore
- Production-ready
- Scalable

### ✅ Proper Data Flow
- Add Vendor → Firestore → Stream → UI Update
- Add Staff → Firestore → Stream → UI Update
- Edit/Delete → Firestore → Stream → UI Update

### ✅ Error Handling
- Try-catch blocks
- User-friendly error messages
- Loading states

---

## Testing Steps

### Test 1: Add Vendor
1. Open Staff & Vendors screen
2. Switch to Vendors tab
3. Click "Add Vendor" button
4. Fill in details:
   - Business Name: "Test Plumbing"
   - Category: "Plumbing"
   - Contact Person: "John Doe"
   - Phone: "+91 98765 43210"
5. Click "Add Vendor"
6. **Expected**: Vendor appears in list immediately

### Test 2: Search Vendor
1. Add multiple vendors
2. Type in search box
3. **Expected**: List filters in real-time

### Test 3: View Vendor Details
1. Click on a vendor card
2. **Expected**: Opens details screen with full information

### Test 4: Add Staff Member
1. Switch to Staff tab
2. Click "Add Staff" button
3. Fill in details
4. Click "Add Staff"
5. **Expected**: Staff member appears in list

---

## Summary

✅ **Service Created**: `StaffVendorService` with full CRUD operations
✅ **Models Defined**: `StaffMember` and `VendorModel`
✅ **Real-Time Streams**: Automatic UI updates
✅ **Error Handling**: Comprehensive try-catch blocks

**Next Steps**:
1. Update `add_vendor_modal.dart` with Firestore integration
2. Update `staff_vendors_screen.dart` to use StreamBuilder
3. Update `vendor_details_screen.dart` to fetch from Firestore
4. Update `add_staff_member_dialog.dart` with Firestore integration
5. Test all flows

**Status**: 🔧 SERVICE READY - IMPLEMENTATION NEEDED IN UI FILES
