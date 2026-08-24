# Widget Migration Examples

## Overview
This document provides exact code examples for migrating widgets from `UserService` to `ResidentService`.

## Example 1: Add Resident Modal (Create & Assign)

### File: `lib/widgets/add_resident_modal.dart`

**BEFORE:**
```dart
import '../services/user_service.dart';

class _AddResidentModalState extends State<AddResidentModal> {
  final UserService _userService = UserService();
  
  Future<void> _handleCreateAndAssign() async {
    try {
      // Create user
      final userId = await _userService.createUser(
        name: _nameController.text,
        phone: _phoneController.text,
        password: _generatedPassword,
        email: _emailController.text.isEmpty ? null : _emailController.text,
        buildingId: widget.buildingId,
        buildingName: widget.buildingName,
        familyMembers: _familyMembers,
      );
      
      // Assign to flat
      await _userService.assignUserToFlat(
        userId: userId,
        flatId: widget.flatId,
        flatLabel: widget.flatLabel,
        buildingId: widget.buildingId,
        buildingName: widget.buildingName,
        ownershipType: _selectedOwnershipType,
      );
      
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Resident created and assigned')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }
}
```

**AFTER:**
```dart
import '../services/resident_service.dart';

class _AddResidentModalState extends State<AddResidentModal> {
  final ResidentService _residentService = ResidentService();
  
  Future<void> _handleCreateAndAssign() async {
    try {
      // Validate email is provided
      if (_emailController.text.isEmpty) {
        throw Exception('Email is required');
      }
      
      // Create resident
      final uid = await _residentService.createResident(
        name: _nameController.text,
        email: _emailController.text,  // ✅ Required
        phone: _phoneController.text,
        password: _generatedPassword,
        buildingId: widget.buildingId,
        buildingName: widget.buildingName,
        familyMembers: _familyMembers,
      );
      
      // Assign to flat
      await _residentService.assignResidentToFlat(
        residentUid: uid,  // ✅ Parameter renamed
        flatId: widget.flatId,
        flatLabel: widget.flatLabel,
        buildingId: widget.buildingId,
        buildingName: widget.buildingName,
        ownershipType: _selectedOwnershipType,
      );
      
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Resident created and assigned')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }
}
```

**Key Changes:**
1. Import changed: `user_service.dart` → `resident_service.dart`
2. Service changed: `UserService` → `ResidentService`
3. Method changed: `createUser()` → `createResident()`
4. Email validation added (required)
5. Parameter changed: `userId` → `residentUid`
6. Method changed: `assignUserToFlat()` → `assignResidentToFlat()`

---

## Example 2: Assign Resident Modal (Select Existing)

### File: `lib/widgets/assign_resident_modal.dart`

**BEFORE:**
```dart
import '../services/user_service.dart';

class _AssignResidentModalState extends State<AssignResidentModal> {
  final UserService _userService = UserService();
  List<UserModel> _residents = [];
  
  @override
  void initState() {
    super.initState();
    _loadResidents();
  }
  
  Future<void> _loadResidents() async {
    _userService.getAllResidentsWithStatus().listen((residents) {
      setState(() {
        _residents = residents;
      });
    });
  }
  
  Future<void> _handleAssign(UserModel resident) async {
    try {
      await _userService.assignUserToFlat(
        userId: resident.id,
        flatId: widget.flatId,
        flatLabel: widget.flatLabel,
        buildingId: widget.buildingId,
        buildingName: widget.buildingName,
        ownershipType: _selectedOwnershipType,
      );
      
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Resident assigned')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }
}
```

**AFTER:**
```dart
import '../services/resident_service.dart';

class _AssignResidentModalState extends State<AssignResidentModal> {
  final ResidentService _residentService = ResidentService();
  List<ResidentModel> _residents = [];  // ✅ Model changed
  
  @override
  void initState() {
    super.initState();
    _loadResidents();
  }
  
  Future<void> _loadResidents() async {
    _residentService.getResidents().listen((residents) {  // ✅ Method changed
      setState(() {
        _residents = residents;
      });
    });
  }
  
  Future<void> _handleAssign(ResidentModel resident) async {  // ✅ Model changed
    try {
      await _residentService.assignResidentToFlat(  // ✅ Method changed
        residentUid: resident.uid,  // ✅ Property changed
        flatId: widget.flatId,
        flatLabel: widget.flatLabel,
        buildingId: widget.buildingId,
        buildingName: widget.buildingName,
        ownershipType: _selectedOwnershipType,
      );
      
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Resident assigned')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }
}
```

**Key Changes:**
1. Service changed: `UserService` → `ResidentService`
2. Model changed: `UserModel` → `ResidentModel`
3. Method changed: `getAllResidentsWithStatus()` → `getResidents()`
4. Property changed: `resident.id` → `resident.uid`
5. Parameter changed: `userId` → `residentUid`
6. Method changed: `assignUserToFlat()` → `assignResidentToFlat()`

---

## Example 3: Flat Details Modal

### File: `lib/widgets/flat_details_modal.dart`

**BEFORE:**
```dart
import '../services/user_service.dart';

class _FlatDetailsModalState extends State<FlatDetailsModal> {
  final UserService _userService = UserService();
  
  Future<void> _handleAssignNew() async {
    try {
      final userId = await _userService.createUser(
        name: _nameController.text,
        phone: _phoneController.text,
        password: _passwordController.text,
        email: _emailController.text,
        familyMembers: _familyMembers,
      );
      
      await _userService.assignUserToFlat(
        userId: userId,
        flatId: widget.unit.id,
        flatLabel: widget.unit.id,
        buildingId: widget.buildingId,
        buildingName: widget.buildingName,
        ownershipType: _ownershipType,
      );
      
      widget.onStatusChange?.call(FlatStatus.occupied);
      Navigator.pop(context);
    } catch (e) {
      print('Error: $e');
    }
  }
}
```

**AFTER:**
```dart
import '../services/resident_service.dart';

class _FlatDetailsModalState extends State<FlatDetailsModal> {
  final ResidentService _residentService = ResidentService();
  
  Future<void> _handleAssignNew() async {
    try {
      // Validate email
      if (_emailController.text.isEmpty) {
        throw Exception('Email is required');
      }
      
      final uid = await _residentService.createResident(
        name: _nameController.text,
        email: _emailController.text,  // ✅ Required
        phone: _phoneController.text,
        password: _passwordController.text,
        familyMembers: _familyMembers,
      );
      
      await _residentService.assignResidentToFlat(
        residentUid: uid,  // ✅ Parameter renamed
        flatId: widget.unit.id,
        flatLabel: widget.unit.id,
        buildingId: widget.buildingId,
        buildingName: widget.buildingName,
        ownershipType: _ownershipType,
      );
      
      widget.onStatusChange?.call(FlatStatus.occupied);
      Navigator.pop(context);
    } catch (e) {
      print('Error: $e');
    }
  }
}
```

---

## Example 4: Manage Buildings Page

### File: `lib/manage_buildings_page.dart`

**BEFORE:**
```dart
import 'services/user_service.dart';

class _ManageBuildingsPageState extends State<ManageBuildingsPage> {
  final UserService _userService = UserService();
  
  Future<void> _handleCreateAndAssign() async {
    final userId = await _userService.createUser(
      name: request.name,
      phone: request.phone,
      password: request.generatedPassword,
      email: request.email,
      familyMembers: request.familyMembers,
      buildingId: building.id,
      buildingName: building.name,
    );
    
    await _userService.assignUserToFlat(
      userId: userId,
      flatId: request.flatId,
      flatLabel: unit.id,
      buildingId: building.id,
      buildingName: building.name,
      ownershipType: request.ownershipType,
    );
  }
}
```

**AFTER:**
```dart
import 'services/resident_service.dart';

class _ManageBuildingsPageState extends State<ManageBuildingsPage> {
  final ResidentService _residentService = ResidentService();
  
  Future<void> _handleCreateAndAssign() async {
    final uid = await _residentService.createResident(
      name: request.name,
      email: request.email,  // ✅ Required
      phone: request.phone,
      password: request.generatedPassword,
      familyMembers: request.familyMembers,
      buildingId: building.id,
      buildingName: building.name,
    );
    
    await _residentService.assignResidentToFlat(
      residentUid: uid,  // ✅ Parameter renamed
      flatId: request.flatId,
      flatLabel: unit.id,
      buildingId: building.id,
      buildingName: building.name,
      ownershipType: request.ownershipType,
    );
  }
}
```

---

## Example 5: Unassigned Users Screen

### File: `lib/unassigned_users_screen.dart`

**BEFORE:**
```dart
import 'services/user_service.dart';

class _UnassignedUsersScreenState extends State<UnassignedUsersScreen> {
  final UserService _userService = UserService();
  
  Stream<List<UserModel>> _getUnassignedUsers() {
    return _userService.getUsers().map((users) {
      return users.where((user) => user.flatId == null).toList();
    });
  }
  
  Future<void> _assignUser(UserModel user, String flatId) async {
    await _userService.assignUserToFlat(
      userId: user.id,
      flatId: flatId,
      flatLabel: flatLabel,
      buildingId: buildingId,
      buildingName: buildingName,
    );
  }
}
```

**AFTER:**
```dart
import 'services/resident_service.dart';

class _UnassignedUsersScreenState extends State<UnassignedUsersScreen> {
  final ResidentService _residentService = ResidentService();
  
  Stream<List<ResidentModel>> _getUnassignedUsers() {  // ✅ Model changed
    return _residentService.getResidents().map((residents) {  // ✅ Method changed
      return residents.where((resident) => resident.flatId == null).toList();
    });
  }
  
  Future<void> _assignUser(ResidentModel resident, String flatId) async {  // ✅ Model changed
    await _residentService.assignResidentToFlat(  // ✅ Method changed
      residentUid: resident.uid,  // ✅ Property changed
      flatId: flatId,
      flatLabel: flatLabel,
      buildingId: buildingId,
      buildingName: buildingName,
    );
  }
}
```

---

## Common Patterns

### Pattern 1: Email Validation
```dart
// Add before creating resident
if (_emailController.text.isEmpty) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Email is required')),
  );
  return;
}
```

### Pattern 2: Error Handling
```dart
try {
  await _residentService.createResident(...);
} catch (e) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('Failed to create resident: $e'),
      backgroundColor: Colors.red,
    ),
  );
}
```

### Pattern 3: Loading State
```dart
setState(() => _isLoading = true);
try {
  await _residentService.createResident(...);
} finally {
  if (mounted) {
    setState(() => _isLoading = false);
  }
}
```

---

## Quick Migration Checklist

For each widget file:

- [ ] Change import: `user_service.dart` → `resident_service.dart`
- [ ] Change service: `UserService` → `ResidentService`
- [ ] Change model: `UserModel` → `ResidentModel`
- [ ] Change method: `createUser()` → `createResident()`
- [ ] Change method: `assignUserToFlat()` → `assignResidentToFlat()`
- [ ] Change parameter: `userId` → `residentUid`
- [ ] Change property: `user.id` → `resident.uid`
- [ ] Add email validation (required)
- [ ] Test the widget
- [ ] Verify in Firebase Console

---

## Summary

✅ **Import changes**: `user_service.dart` → `resident_service.dart`
✅ **Service changes**: `UserService` → `ResidentService`
✅ **Model changes**: `UserModel` → `ResidentModel`
✅ **Method changes**: `createUser()` → `createResident()`
✅ **Method changes**: `assignUserToFlat()` → `assignResidentToFlat()`
✅ **Parameter changes**: `userId` → `residentUid`
✅ **Property changes**: `user.id` → `resident.uid`
✅ **Email validation**: Now required

Follow these patterns for all widgets that use resident management!
