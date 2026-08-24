# Resident Service Migration Guide

## Overview
This guide helps you migrate from the old `UserService` to the new production-ready `ResidentService` with full Firebase Authentication integration.

## Key Differences

| Feature | Old UserService | New ResidentService |
|---------|----------------|---------------------|
| Firebase Auth | ❌ No (stored password in Firestore) | ✅ Yes (creates real Auth users) |
| Document ID | Auto-generated | UID from Firebase Auth |
| Error Handling | Basic | Comprehensive with rollback |
| Data Verification | None | Full verification after operations |
| Rollback | None | Automatic rollback on failure |
| Logging | Minimal | Comprehensive step-by-step |
| Production Ready | ❌ No | ✅ Yes |

## Migration Steps

### Step 1: Import New Service

**Before:**
```dart
import 'package:admin_app/services/user_service.dart';
```

**After:**
```dart
import 'package:admin_app/services/resident_service.dart';
```

### Step 2: Update Service Instance

**Before:**
```dart
final UserService _userService = UserService();
```

**After:**
```dart
final ResidentService _residentService = ResidentService();
```

### Step 3: Update Create Resident Calls

**Before:**
```dart
final userId = await _userService.createUser(
  name: name,
  phone: phone,
  password: password,
  email: email,
  buildingId: buildingId,
  buildingName: buildingName,
  familyMembers: familyMembers,
);
```

**After:**
```dart
final uid = await _residentService.createResident(
  name: name,
  email: email,  // ✅ Now required (not optional)
  phone: phone,
  password: password,
  buildingId: buildingId,
  buildingName: buildingName,
  familyMembers: familyMembers,
);
```

**Key Changes:**
- Method renamed: `createUser()` → `createResident()`
- Email is now required (not optional)
- Returns UID from Firebase Auth
- Creates real Firebase Auth user

### Step 4: Update Assign Resident Calls

**Before:**
```dart
await _userService.assignUserToFlat(
  userId: userId,
  flatId: flatId,
  flatLabel: flatLabel,
  buildingId: buildingId,
  buildingName: buildingName,
  ownershipType: ownershipType,
);
```

**After:**
```dart
await _residentService.assignResidentToFlat(
  residentUid: uid,  // ✅ Parameter renamed
  flatId: flatId,
  flatLabel: flatLabel,
  buildingId: buildingId,
  buildingName: buildingName,
  ownershipType: ownershipType,
);
```

**Key Changes:**
- Method renamed: `assignUserToFlat()` → `assignResidentToFlat()`
- Parameter renamed: `userId` → `residentUid`
- Includes automatic rollback on failure

### Step 5: Update Model References

**Before:**
```dart
UserModel user = await _userService.getUserById(userId);
```

**After:**
```dart
ResidentModel resident = await _residentService.getResidentByUid(uid);
```

**Key Changes:**
- Model renamed: `UserModel` → `ResidentModel`
- Method renamed: `getUserById()` → `getResidentByUid()`
- Parameter renamed: `userId` → `uid`

## Example: Complete Widget Migration

### Before (Old UserService)

```dart
class AddResidentModal extends StatefulWidget {
  // ... widget code
}

class _AddResidentModalState extends State<AddResidentModal> {
  final UserService _userService = UserService();
  
  Future<void> _createResident() async {
    try {
      final userId = await _userService.createUser(
        name: _nameController.text,
        phone: _phoneController.text,
        password: _passwordController.text,
        email: _emailController.text.isEmpty ? null : _emailController.text,
        buildingId: widget.buildingId,
        buildingName: widget.buildingName,
        familyMembers: _familyMembers,
      );
      
      // Assign to flat if needed
      if (widget.flatId != null) {
        await _userService.assignUserToFlat(
          userId: userId,
          flatId: widget.flatId!,
          flatLabel: widget.flatLabel!,
          buildingId: widget.buildingId,
          buildingName: widget.buildingName,
          ownershipType: _ownershipType,
        );
      }
      
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Resident created successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create resident: $e')),
      );
    }
  }
}
```

### After (New ResidentService)

```dart
class AddResidentModal extends StatefulWidget {
  // ... widget code
}

class _AddResidentModalState extends State<AddResidentModal> {
  final ResidentService _residentService = ResidentService();
  
  Future<void> _createResident() async {
    try {
      // Email is now required
      if (_emailController.text.isEmpty) {
        throw Exception('Email is required');
      }
      
      final uid = await _residentService.createResident(
        name: _nameController.text,
        email: _emailController.text,  // ✅ Required
        phone: _phoneController.text,
        password: _passwordController.text,
        buildingId: widget.buildingId,
        buildingName: widget.buildingName,
        familyMembers: _familyMembers,
      );
      
      // Assign to flat if needed
      if (widget.flatId != null) {
        await _residentService.assignResidentToFlat(
          residentUid: uid,  // ✅ Parameter renamed
          flatId: widget.flatId!,
          flatLabel: widget.flatLabel!,
          buildingId: widget.buildingId,
          buildingName: widget.buildingName,
          ownershipType: _ownershipType,
        );
      }
      
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Resident created successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create resident: $e')),
      );
    }
  }
}
```

## Files That Need Migration

### Priority 1: Core Services
- [ ] `lib/widgets/add_resident_modal.dart`
- [ ] `lib/widgets/add_resident_modal_simplified.dart`
- [ ] `lib/widgets/add_resident_modal_clean.dart`
- [ ] `lib/widgets/assign_resident_modal.dart`
- [ ] `lib/widgets/flat_details_modal.dart`
- [ ] `lib/widgets/flat_occupancy_grid_stateful.dart`
- [ ] `lib/manage_buildings_page.dart`

### Priority 2: Screens
- [ ] `lib/admin_residents_page_firestore.dart`
- [ ] `lib/edit_resident_screen.dart`
- [ ] `lib/unassigned_users_screen.dart`

### Priority 3: Other Services
- [ ] Any other files importing `user_service.dart`

## Testing After Migration

### Test 1: Create Resident
1. Open admin app
2. Navigate to resident creation screen
3. Fill in all fields (including email)
4. Click "Create Resident"
5. Check Firebase Console:
   - ✅ Firebase Authentication has new user
   - ✅ Firestore users/{uid} document exists
   - ✅ Document ID matches Auth UID
   - ✅ All fields are present

### Test 2: Assign Resident
1. Create a resident (or use existing)
2. Navigate to flat occupancy grid
3. Click on vacant flat
4. Assign the resident
5. Check Firestore:
   - ✅ users/{uid} has flatId, flatLabel
   - ✅ flats/{flatId} has residentId, residentName, residentUid
   - ✅ Flat status is "occupied"

### Test 3: Error Handling
1. Try to create resident with existing email
2. Verify error message is shown
3. Check that no partial data is created
4. Try to assign to non-existent flat
5. Verify rollback works correctly

## Common Issues & Solutions

### Issue 1: Email Required Error
**Problem**: Old code allowed email to be optional
**Solution**: Make email required in UI, validate before calling service

```dart
// Add validation
if (_emailController.text.isEmpty) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Email is required')),
  );
  return;
}
```

### Issue 2: Admin Gets Logged Out
**Problem**: Creating Firebase Auth user logs out admin
**Solution**: Service handles this automatically by signing out new user

```dart
// Service automatically handles this:
await _auth.signOut(); // Signs out newly created user
// Admin re-authenticates automatically
```

### Issue 3: Parameter Name Changes
**Problem**: `userId` parameter no longer exists
**Solution**: Use `residentUid` instead

```dart
// Old
userId: userId

// New
residentUid: uid
```

### Issue 4: Model Property Changes
**Problem**: `UserModel` properties don't match `ResidentModel`
**Solution**: Update property references

```dart
// Old
user.id

// New
resident.uid
```

## Rollback Plan

If you need to rollback to old service:

1. Revert import changes
2. Revert service instance changes
3. Revert method call changes
4. Keep old `user_service.dart` file

**Note**: New residents created with `ResidentService` will have Firebase Auth accounts. Old residents won't. You may need data migration.

## Data Migration (Optional)

If you have existing residents without Firebase Auth accounts:

```dart
// Migration script (run once)
Future<void> migrateExistingResidents() async {
  final residents = await _firestore
      .collection('users')
      .where('role', isEqualTo: 'resident')
      .get();
  
  for (var doc in residents.docs) {
    final data = doc.data();
    
    // Skip if already has uid field
    if (data.containsKey('uid')) continue;
    
    try {
      // Create Firebase Auth account
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: data['email'],
        password: data['password'], // Stored password
      );
      
      // Update document with uid
      await doc.reference.update({
        'uid': userCredential.user!.uid,
      });
      
      print('✅ Migrated resident: ${data['name']}');
    } catch (e) {
      print('❌ Failed to migrate ${data['name']}: $e');
    }
  }
}
```

## Summary

✅ **Import new service**
✅ **Update service instances**
✅ **Update method calls**
✅ **Update parameter names**
✅ **Update model references**
✅ **Test thoroughly**
✅ **Verify Firebase Auth integration**

The new `ResidentService` provides production-ready functionality with proper Firebase Authentication integration, error handling, and rollback mechanisms!
