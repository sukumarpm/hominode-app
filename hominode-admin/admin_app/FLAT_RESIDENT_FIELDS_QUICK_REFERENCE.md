# Flat Resident Fields - Quick Reference

## Flat Document Structure

### Resident-Related Fields
Every flat document in the `flats` collection has these resident fields:

```javascript
{
  // Flat identification
  "id": "abc123",
  "flatId": "A101",
  "flatLabel": "A101",
  "buildingId": "building_xyz",
  "buildingName": "Tower A",
  
  // Resident information (3 fields - must be kept in sync)
  "residentId": "user_abc123",      // User document ID
  "residentName": "John Doe",       // Resident's full name
  "residentUserId": "user_abc123",  // User document ID (duplicate for consistency)
  
  // Status
  "status": "occupied",  // vacant | occupied | maintenance
  
  // Other fields...
}
```

## Field Definitions

### residentId
- **Type**: String (nullable)
- **Purpose**: Stores the user document ID from the `users` collection
- **Example**: `"user_abc123xyz"`
- **When null**: Flat is vacant

### residentName
- **Type**: String (nullable)
- **Purpose**: Stores the resident's full name for quick display
- **Example**: `"John Doe"`
- **When null**: Flat is vacant

### residentUserId
- **Type**: String (nullable)
- **Purpose**: Duplicate of `residentId` for consistency with `user_service`
- **Example**: `"user_abc123xyz"`
- **When null**: Flat is vacant

## Why Three Fields?

### Historical Context
- Originally, `user_service.dart` created the pattern of storing 3 fields
- `flat_service.dart` was only storing 2 fields
- This caused data inconsistency

### Current Implementation
- Both services now store all 3 fields
- Ensures data consistency regardless of which service updates the flat
- Provides redundancy for lookups

## Service Methods

### FlatService Methods

#### assignResident()
```dart
await flatService.assignResident(
  flatId: 'flat_123',
  residentName: 'John Doe',
  residentId: 'user_abc',
);
```
**Updates**:
- `residentId` → user ID
- `residentName` → user name
- `residentUserId` → user ID
- `status` → "occupied"

#### removeResident()
```dart
await flatService.removeResident('flat_123');
```
**Updates**:
- `residentId` → null
- `residentName` → null
- `residentUserId` → null
- `status` → "vacant"

#### updateFlatStatus()
```dart
await flatService.updateFlatStatus(
  flatId: 'flat_123',
  status: 'occupied',
  residentName: 'John Doe',
  residentId: 'user_abc',
);
```
**Updates**:
- `residentId` → provided value
- `residentName` → provided value
- `residentUserId` → provided value
- `status` → provided status

### UserService Methods

#### assignUserToFlat()
```dart
await userService.assignUserToFlat(
  userId: 'user_abc',
  flatId: 'flat_123',
  flatLabel: 'A101',
  buildingId: 'building_xyz',
  buildingName: 'Tower A',
  ownershipType: 'Owner',
);
```
**Updates flat document**:
- `residentId` → resident's unique ID (from user doc)
- `residentName` → user's name
- `residentUserId` → user document ID
- `status` → "occupied"

#### removeUserFromFlat()
```dart
await userService.removeUserFromFlat('user_abc');
```
**Updates flat document**:
- `residentId` → null
- `residentName` → null
- `residentUserId` → null
- `status` → "vacant"

## Data Flow Examples

### Example 1: Assign Existing Resident
```
1. User clicks "Assign Resident" on flat A101
2. Selects existing user "John Doe" (ID: user_abc123)
3. System calls:
   a. userService.assignUserToFlat(userId: 'user_abc123', ...)
      → Updates users/user_abc123 with flat details
      → Updates flats/flat_123 with resident details
   b. flatService.assignResident(flatId: 'flat_123', residentId: 'user_abc123', ...)
      → Updates flats/flat_123 (redundant but ensures consistency)

Result in flats/flat_123:
{
  "residentId": "user_abc123",
  "residentName": "John Doe",
  "residentUserId": "user_abc123",
  "status": "occupied"
}
```

### Example 2: Add New Resident
```
1. User clicks "Assign Resident" on flat A101
2. Fills form to create new resident
3. System calls:
   a. userService.createUser(name: 'Jane Smith', ...)
      → Creates new user document (ID: user_xyz789)
   b. userService.assignUserToFlat(userId: 'user_xyz789', ...)
      → Updates users/user_xyz789 with flat details
      → Updates flats/flat_123 with resident details
   c. flatService.assignResident(flatId: 'flat_123', residentId: 'user_xyz789', ...)
      → Updates flats/flat_123 (ensures consistency)

Result in flats/flat_123:
{
  "residentId": "user_xyz789",
  "residentName": "Jane Smith",
  "residentUserId": "user_xyz789",
  "status": "occupied"
}
```

### Example 3: Remove Resident
```
1. User changes flat status to "Vacant"
2. System calls:
   a. userService.removeUserFromFlat('user_abc123')
      → Updates users/user_abc123 (removes flat assignment)
      → Updates flats/flat_123 (clears resident data)
   b. flatService.removeResident('flat_123')
      → Updates flats/flat_123 (ensures all fields cleared)

Result in flats/flat_123:
{
  "residentId": null,
  "residentName": null,
  "residentUserId": null,
  "status": "vacant"
}
```

## Debugging Tips

### Check Flat Document
```dart
final flatDoc = await FirebaseFirestore.instance
    .collection('flats')
    .doc(flatId)
    .get();

print('Resident Data:');
print('  residentId: ${flatDoc.data()?['residentId']}');
print('  residentName: ${flatDoc.data()?['residentName']}');
print('  residentUserId: ${flatDoc.data()?['residentUserId']}');
print('  status: ${flatDoc.data()?['status']}');
```

### Expected Console Output
When assigning a resident:
```
🔵 FlatService.assignResident() called
   - flatId: flat_123
   - residentName: John Doe
   - residentId: user_abc123
✅ Flat document updated successfully
   - residentName: John Doe
   - residentId: user_abc123
   - residentUserId: user_abc123
```

## Common Issues

### Issue: Fields showing null after assignment
**Cause**: Old code didn't set `residentUserId`
**Solution**: ✅ Fixed - all methods now set all 3 fields

### Issue: Inconsistent data between services
**Cause**: Different field structures
**Solution**: ✅ Fixed - both services use same structure

### Issue: Data not persisting
**Cause**: Check Firestore rules, network connection
**Solution**: Verify rules allow write access, check console logs

## Status
✅ All services synchronized
✅ All fields maintained consistently
✅ Debug logging added
✅ Ready for production use
