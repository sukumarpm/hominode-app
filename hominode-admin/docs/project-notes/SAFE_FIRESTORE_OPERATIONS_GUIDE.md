# Safe Firestore Operations Guide

## Problem Summary

Firestore "not-found" errors occur when:
1. Updating documents that don't exist
2. Deleting documents that don't exist
3. No existence checks before operations
4. Sequential updates (not atomic)
5. Poor error handling

## Solution Pattern

### Pattern 1: Safe Update with Existence Check

```dart
// ❌ WRONG - Will crash if document doesn't exist
await _firestore.collection('users').doc(userId).update({...});

// ✅ CORRECT - Check existence first
final doc = await _firestore.collection('users').doc(userId).get();
if (!doc.exists) {
  throw Exception('Document not found');
}
await _firestore.collection('users').doc(userId).update({...});
```

### Pattern 2: Safe Query and Update

```dart
// ❌ WRONG - Assumes document exists
final doc = await _firestore.collection('flats').doc(flatId).get();
await _firestore.collection('flats').doc(flatId).update({...});

// ✅ CORRECT - Query by field, check results
final query = await _firestore
    .collection('flats')
    .where('flatId', isEqualTo: flatId)
    .limit(1)
    .get();

if (query.docs.isEmpty) {
  throw Exception('Flat not found');
}

final docRef = query.docs.first.reference;
await docRef.update({...});
```

### Pattern 3: Batch Operations for Consistency

```dart
// ❌ WRONG - Sequential updates (not atomic)
await _firestore.collection('users').doc(userId).update({...});
await _firestore.collection('flats').doc(flatId).update({...});

// ✅ CORRECT - Batch operation (atomic)
final batch = _firestore.batch();

batch.update(
  _firestore.collection('users').doc(userId),
  {...},
);

batch.update(
  _firestore.collection('flats').doc(flatId),
  {...},
);

await batch.commit();
```

### Pattern 4: Graceful Error Handling

```dart
// ❌ WRONG - Generic error
try {
  await _firestore.collection('users').doc(userId).update({...});
} catch (e) {
  print('Error: $e');
}

// ✅ CORRECT - Detailed error handling
try {
  print('[Step 1] Checking if document exists...');
  final doc = await _firestore.collection('users').doc(userId).get();
  if (!doc.exists) {
    throw Exception('User not found');
  }
  
  print('[Step 2] Updating document...');
  await _firestore.collection('users').doc(userId).update({...});
  print('✅ Update successful');
  
} catch (e) {
  print('❌ Error: $e');
  print('Stack trace: ${StackTrace.current}');
  throw Exception('Failed to update user: $e');
}
```

### Pattern 5: Verification After Update

```dart
// ❌ WRONG - No verification
await _firestore.collection('users').doc(userId).update({...});
print('✅ Done');

// ✅ CORRECT - Verify update
await _firestore.collection('users').doc(userId).update({...});

final verify = await _firestore.collection('users').doc(userId).get();
if (verify.exists) {
  final data = verify.data()!;
  print('✅ Verification successful');
  print('   Updated field: ${data['fieldName']}');
}
```

## Complete Safe Operation Example

```dart
Future<void> safeRemoveUserFromFlat(String userId) async {
  try {
    // STEP 1: Check if user exists
    print('[Step 1] Checking if user exists...');
    final userDoc = await _firestore.collection('users').doc(userId).get();
    if (!userDoc.exists) {
      throw Exception('User not found');
    }
    
    final userData = userDoc.data()!;
    final flatId = userData['flatId'] as String?;
    print('✅ User found: ${userData['name']}');
    
    // STEP 2: If no flat assigned, return early
    if (flatId == null || flatId.isEmpty) {
      print('✅ User has no flat assigned');
      return;
    }
    
    // STEP 3: Query for flat by flatId field
    print('[Step 2] Querying for flat...');
    final flatQuery = await _firestore
        .collection('flats')
        .where('flatId', isEqualTo: flatId)
        .limit(1)
        .get();
    
    if (flatQuery.docs.isEmpty) {
      print('⚠️  Flat not found, updating user only...');
      
      // Update user even if flat doesn't exist
      await _firestore.collection('users').doc(userId).update({
        'flatId': null,
        'flatLabel': null,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return;
    }
    
    final flatDocRef = flatQuery.docs.first.reference;
    print('✅ Flat found');
    
    // STEP 4: Use batch for atomic updates
    print('[Step 3] Creating batch operation...');
    final batch = _firestore.batch();
    
    batch.update(
      _firestore.collection('users').doc(userId),
      {
        'flatId': null,
        'flatLabel': null,
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );
    
    batch.update(
      flatDocRef,
      {
        'residentId': null,
        'residentName': null,
        'status': 'vacant',
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );
    
    // STEP 5: Commit batch
    print('[Step 4] Committing batch...');
    await batch.commit();
    print('✅ Batch committed');
    
    // STEP 6: Verify updates
    print('[Step 5] Verifying updates...');
    final verifyUser = await _firestore.collection('users').doc(userId).get();
    final verifyFlat = await flatDocRef.get();
    
    if (verifyUser.exists && verifyFlat.exists) {
      print('✅ Verification successful');
      print('   User flatId: ${verifyUser.data()!['flatId']}');
      print('   Flat status: ${verifyFlat.data()!['status']}');
    }
    
  } catch (e) {
    print('❌ Error: $e');
    print('Stack trace: ${StackTrace.current}');
    throw Exception('Failed to remove user from flat: $e');
  }
}
```

## Best Practices

### 1. Always Check Existence
```dart
// Before any update/delete operation
final doc = await _firestore.collection('...').doc(id).get();
if (!doc.exists) {
  // Handle gracefully
}
```

### 2. Use Batch for Related Updates
```dart
// When updating multiple related documents
final batch = _firestore.batch();
batch.update(doc1, {...});
batch.update(doc2, {...});
await batch.commit();
```

### 3. Query by Field, Not Document ID
```dart
// When you have a field value, not document ID
final query = await _firestore
    .collection('flats')
    .where('flatId', isEqualTo: flatId)
    .limit(1)
    .get();

if (query.docs.isNotEmpty) {
  final docRef = query.docs.first.reference;
  await docRef.update({...});
}
```

### 4. Verify After Update
```dart
// Confirm update was successful
await docRef.update({...});
final verify = await docRef.get();
if (verify.exists) {
  print('✅ Update verified');
}
```

### 5. Detailed Error Handling
```dart
// Provide context for debugging
try {
  // operation
} catch (e) {
  print('❌ Error: $e');
  print('Stack trace: ${StackTrace.current}');
  throw Exception('Failed to [operation]: $e');
}
```

## Common Mistakes to Avoid

| ❌ Wrong | ✅ Correct |
|---------|-----------|
| Update without checking existence | Check existence first |
| Sequential updates | Use batch operations |
| Generic error messages | Detailed error context |
| No verification | Verify after update |
| Assume document exists | Query and check results |
| No logging | Step-by-step logging |

## Testing Checklist

- [ ] Test with existing document
- [ ] Test with non-existing document
- [ ] Test with null/empty values
- [ ] Test batch operations
- [ ] Test error handling
- [ ] Test verification
- [ ] Check logs are helpful
- [ ] Verify no crashes

## Files Updated

- `admin_app/lib/services/user_service.dart`
  - `removeUserFromFlat()` - Safe implementation
  - `assignUserToFlat()` - Safe implementation with batch

## Status

✅ All safe patterns implemented
✅ Code compiles without errors
✅ Comprehensive error handling
✅ Detailed logging for debugging
✅ Batch operations for consistency

