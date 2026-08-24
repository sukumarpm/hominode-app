# Resident Service Quick Reference

## 🚀 Quick Start

```dart
import 'package:admin_app/services/resident_service.dart';

final residentService = ResidentService();
```

## 📝 Create Resident

```dart
try {
  final uid = await residentService.createResident(
    name: 'John Doe',
    email: 'john@example.com',  // Required
    phone: '1234567890',
    password: 'SecurePass123',
    buildingId: 'building123',
    buildingName: 'Tower A',
    familyMembers: 4,
  );
  
  print('✅ Created with UID: $uid');
} catch (e) {
  print('❌ Error: $e');
}
```

## 🏠 Assign to Flat

```dart
try {
  await residentService.assignResidentToFlat(
    residentUid: uid,
    flatId: 'flat123',
    flatLabel: 'A101',
    buildingId: 'building123',
    buildingName: 'Tower A',
    ownershipType: 'Owner',
  );
  
  print('✅ Assigned successfully');
} catch (e) {
  print('❌ Error: $e');
}
```

## 📊 Get Residents

```dart
// Stream of all residents for current admin
Stream<List<ResidentModel>> residents = residentService.getResidents();

// Get specific resident
ResidentModel? resident = await residentService.getResidentByUid(uid);
```

## 🔑 Key Points

✅ **Email is required** (not optional)
✅ **Returns UID** from Firebase Auth
✅ **Creates real Auth users**
✅ **Automatic rollback** on failure
✅ **Comprehensive logging**
✅ **Production ready**

## 📋 Required Fields

### Create Resident
- `name` (String) - Required
- `email` (String) - Required
- `phone` (String) - Required
- `password` (String) - Required
- `buildingId` (String?) - Optional
- `buildingName` (String?) - Optional
- `familyMembers` (int) - Default: 1

### Assign to Flat
- `residentUid` (String) - Required
- `flatId` (String) - Required
- `flatLabel` (String) - Required
- `buildingId` (String?) - Optional
- `buildingName` (String?) - Optional
- `ownershipType` (String?) - Optional

## 🎯 What Gets Stored

### In users/{uid}
```
✅ uid
✅ residentId (auto-generated)
✅ name
✅ email
✅ phone
✅ role: "resident"
✅ flatId (null initially)
✅ flatLabel (null initially)
✅ buildingId
✅ buildingName
✅ organization
✅ adminEmail
✅ adminName
✅ adminPhone
✅ adminId
✅ familyMembers
✅ status: "active"
✅ createdAt
✅ updatedAt
```

### In flats/{flatId} (after assignment)
```
✅ residentId
✅ residentName
✅ residentUid
✅ status: "occupied"
✅ ownershipType
✅ updatedAt
```

## ⚠️ Error Handling

All methods throw exceptions on failure:

```dart
try {
  await residentService.createResident(...);
} catch (e) {
  // Handle error
  // Automatic rollback already performed
  print('Error: $e');
}
```

## 🔄 Rollback Behavior

### Create Resident
- If Firestore creation fails → Firebase Auth user may need manual cleanup

### Assign Resident
- If any update fails → Automatic rollback to original state
- Both documents restored to previous values

## 📱 Firebase Console Verification

### After Creating Resident
1. Firebase Authentication → Users → Check for new user
2. Firestore → users → Check document with UID
3. Verify all fields are present

### After Assigning Resident
1. Firestore → users/{uid} → Check flatId, flatLabel
2. Firestore → flats/{flatId} → Check residentId, residentName, residentUid
3. Verify flat status is "occupied"

## 🆚 vs Old UserService

| Feature | Old | New |
|---------|-----|-----|
| Firebase Auth | ❌ | ✅ |
| Document ID | Auto | UID |
| Email | Optional | Required |
| Rollback | ❌ | ✅ |
| Verification | ❌ | ✅ |
| Logging | Minimal | Comprehensive |

## 💡 Tips

1. **Always provide email** - It's required for Firebase Auth
2. **Use try-catch** - All methods can throw exceptions
3. **Check logs** - Comprehensive logging helps debugging
4. **Verify in console** - Check Firebase Console after operations
5. **Trust rollback** - Failed operations are automatically rolled back

## 📚 Full Documentation

- `PRODUCTION_RESIDENT_FLOW_IMPLEMENTATION.md` - Complete implementation details
- `RESIDENT_SERVICE_MIGRATION_GUIDE.md` - Migration from old service

---

**Status**: ✅ Production Ready
**Version**: 1.0
**Last Updated**: February 27, 2026
