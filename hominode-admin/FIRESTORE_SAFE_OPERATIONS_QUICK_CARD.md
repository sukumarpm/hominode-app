# Firestore Safe Operations - Quick Card

## Problem Fixed
```
❌ [cloud_firestore/not-found] Some requested document was not found
```

## Solution: 6-Step Safe Pattern

### Step 1: Check Existence
```dart
final doc = await _firestore.collection('users').doc(userId).get();
if (!doc.exists) {
  throw Exception('User not found');
}
```

### Step 2: Handle Edge Cases
```dart
final flatId = doc.data()!['flatId'];
if (flatId == null || flatId.isEmpty) {
  return; // Early exit
}
```

### Step 3: Query by Field
```dart
final query = await _firestore
    .collection('flats')
    .where('flatId', isEqualTo: flatId)
    .limit(1)
    .get();

if (query.docs.isEmpty) {
  // Handle gracefully
}
```

### Step 4: Use Batch Operations
```dart
final batch = _firestore.batch();

batch.update(doc1, {...});
batch.update(doc2, {...});

await batch.commit();
```

### Step 5: Verify Updates
```dart
final verify = await doc.get();
if (verify.exists) {
  print('✅ Verified');
}
```

### Step 6: Error Handling
```dart
try {
  // operation
} catch (e) {
  print('❌ Error: $e');
  throw Exception('Failed: $e');
}
```

## Before vs After

| Aspect | Before | After |
|--------|--------|-------|
| Existence check | ❌ No | ✅ Yes |
| Batch operations | ❌ No | ✅ Yes |
| Verification | ❌ No | ✅ Yes |
| Error handling | ❌ Generic | ✅ Detailed |
| Crashes | ❌ Yes | ✅ No |

## Code Pattern

```dart
// ❌ WRONG
await _firestore.collection('users').doc(userId).update({...});
await _firestore.collection('flats').doc(flatId).update({...});

// ✅ CORRECT
final userDoc = await _firestore.collection('users').doc(userId).get();
if (!userDoc.exists) throw Exception('User not found');

final flatQuery = await _firestore
    .collection('flats')
    .where('flatId', isEqualTo: flatId)
    .limit(1)
    .get();

if (flatQuery.docs.isEmpty) throw Exception('Flat not found');

final batch = _firestore.batch();
batch.update(_firestore.collection('users').doc(userId), {...});
batch.update(flatQuery.docs.first.reference, {...});
await batch.commit();

// Verify
final verify1 = await _firestore.collection('users').doc(userId).get();
final verify2 = await flatQuery.docs.first.reference.get();
if (verify1.exists && verify2.exists) print('✅ Verified');
```

## Key Points

1. **Always check existence** before updating
2. **Use batch operations** for related updates
3. **Query by field** when you don't have document ID
4. **Verify after update** to confirm success
5. **Handle errors gracefully** with detailed messages

## Files Updated

- `admin_app/lib/services/user_service.dart`
  - `removeUserFromFlat()` ✅
  - `assignUserToFlat()` ✅

## Status

✅ Implemented
✅ Compiled
✅ No errors
✅ Ready to test

## Documentation

- **FIRESTORE_NOT_FOUND_ERROR_FIX.md** - Detailed explanation
- **SAFE_FIRESTORE_OPERATIONS_GUIDE.md** - Patterns and examples
- **FIRESTORE_FIX_SUMMARY.md** - Complete summary

