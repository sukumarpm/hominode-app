# 🔍 Firestore Troubleshooting Guide

## Common Issues & Solutions

### Issue 1: Permission Denied Errors

**Error**: `[cloud_firestore/permission-denied] The caller does not have permission`

**Causes**:
- Firestore rules not deployed
- User not authenticated
- buildingId mismatch
- Query doesn't match rules

**Solutions**:

1. **Check rules are deployed**
   - Firebase Console → Firestore → Rules
   - Verify rules show your code
   - Check "Last published" timestamp

2. **Check user is authenticated**
   ```dart
   final user = FirebaseAuth.instance.currentUser;
   print('User: ${user?.uid}');
   ```

3. **Check buildingId exists**
   ```dart
   final userDoc = await FirebaseFirestore.instance
       .collection('users')
       .doc(uid)
       .get();
   print('BuildingId: ${userDoc.get('buildingId')}');
   ```

4. **Check query matches rules**
   - Rules filter by `buildingId`
   - Query must include `where('buildingId', isEqualTo: buildingId)`

---

### Issue 2: Empty Screens

**Problem**: Screen shows "No data" even though data exists

**Causes**:
- buildingId is null
- Query filter is wrong
- Data doesn't exist in Firestore
- User not authenticated

**Solutions**:

1. **Check buildingId**
   ```dart
   final uid = FirebaseAuth.instance.currentUser?.uid;
   final userDoc = await FirebaseFirestore.instance
       .collection('users')
       .doc(uid)
       .get();
   
   if (!userDoc.exists) {
     print('User document not found');
     return;
   }
   
   final buildingId = userDoc.get('buildingId');
   print('BuildingId: $buildingId');
   ```

2. **Check data exists**
   - Firebase Console → Firestore → Collections
   - Verify documents exist in amenities, bookings, etc.
   - Check buildingId matches user's buildingId

3. **Check query**
   ```dart
   // WRONG - no filter
   _firestore.collection('amenities').snapshots()
   
   // CORRECT - filter by buildingId
   _firestore
       .collection('amenities')
       .where('buildingId', isEqualTo: buildingId)
       .snapshots()
   ```

---

### Issue 3: Data Not Loading

**Problem**: StreamBuilder shows loading spinner forever

**Causes**:
- Query is too slow
- Firestore indexes missing
- Network connection issue
- Query has error

**Solutions**:

1. **Check for errors**
   ```dart
   StreamBuilder<List<Amenity>>(
     stream: _service.streamAmenities(),
     builder: (context, snapshot) {
       if (snapshot.hasError) {
         print('Error: ${snapshot.error}');
         return Text('Error: ${snapshot.error}');
       }
       // ...
     },
   )
   ```

2. **Create Firestore indexes**
   - Firebase Console → Firestore → Indexes
   - Create composite indexes for queries with multiple filters
   - Example: `amenities` collection with `buildingId` + `isActive`

3. **Check network**
   ```dart
   // Add timeout
   _firestore
       .collection('amenities')
       .where('buildingId', isEqualTo: buildingId)
       .snapshots()
       .timeout(Duration(seconds: 10))
   ```

4. **Simplify query**
   ```dart
   // Start simple
   _firestore.collection('amenities').snapshots()
   
   // Then add filters one by one
   .where('buildingId', isEqualTo: buildingId)
   .where('isActive', isEqualTo: true)
   ```

---

### Issue 4: Incorrect Booking Logic

**Problem**: Bookings show wrong data or don't filter correctly

**Causes**:
- Missing userId filter
- Missing buildingId filter
- Wrong field names
- Data structure mismatch

**Solutions**:

1. **Check booking structure**
   ```json
   {
     "userId": "user123",
     "amenityId": "amenity456",
     "buildingId": "building789",
     "bookingDate": "2024-03-29T10:30:00Z",
     "status": "confirmed"
   }
   ```

2. **Check query filters**
   ```dart
   // WRONG - shows all bookings
   _firestore.collection('bookings').snapshots()
   
   // CORRECT - shows user's bookings
   _firestore
       .collection('bookings')
       .where('userId', isEqualTo: uid)
       .snapshots()
   ```

3. **Check field names**
   ```dart
   // Make sure field names match exactly
   final userId = doc.get('userId');  // Not 'user_id'
   final amenityId = doc.get('amenityId');  // Not 'amenity_id'
   ```

---

### Issue 5: Amenities Not Showing

**Problem**: Amenities screen is empty

**Causes**:
- No amenities in Firestore
- buildingId mismatch
- isActive is false
- Query filter wrong

**Solutions**:

1. **Check amenities exist**
   - Firebase Console → Firestore → amenities collection
   - Verify documents exist
   - Check buildingId matches user's buildingId

2. **Check isActive flag**
   ```dart
   // Make sure isActive is true
   _firestore
       .collection('amenities')
       .where('buildingId', isEqualTo: buildingId)
       .where('isActive', isEqualTo: true)
       .snapshots()
   ```

3. **Check buildingId**
   ```dart
   // Verify user's buildingId
   final userDoc = await _firestore.collection('users').doc(uid).get();
   final userBuildingId = userDoc.get('buildingId');
   
   // Verify amenity's buildingId
   final amenityDoc = await _firestore.collection('amenities').doc(amenityId).get();
   final amenityBuildingId = amenityDoc.get('buildingId');
   
   print('User building: $userBuildingId');
   print('Amenity building: $amenityBuildingId');
   ```

---

### Issue 6: Access Restricted Not Showing

**Problem**: User logs in but doesn't see access restricted screen

**Causes**:
- buildingId is not null (even if empty)
- Login service not checking buildingId
- Navigation not working

**Solutions**:

1. **Check buildingId is null**
   ```dart
   final buildingId = userDoc.get('buildingId') as String?;
   
   if (buildingId == null || buildingId.isEmpty) {
     // Show access restricted
   }
   ```

2. **Check login service**
   ```dart
   // Make sure login service returns isAccessRestricted
   if (result.isAccessRestricted) {
     Navigator.of(context).pushReplacementNamed('/access-restricted');
   }
   ```

3. **Check navigation**
   ```dart
   // Make sure route exists
   routes: {
     '/access-restricted': (context) => AccessRestrictedScreen(),
     '/home': (context) => HomeScreen(),
   }
   ```

---

### Issue 7: Slow Performance

**Problem**: Screens load slowly

**Causes**:
- Missing Firestore indexes
- Too many documents
- Network latency
- Inefficient queries

**Solutions**:

1. **Create indexes**
   - Firebase Console → Firestore → Indexes
   - Create composite indexes for multi-field queries
   - Example: `buildingId` + `isActive` + `createdAt`

2. **Limit results**
   ```dart
   _firestore
       .collection('amenities')
       .where('buildingId', isEqualTo: buildingId)
       .limit(50)  // Limit to 50 documents
       .snapshots()
   ```

3. **Add pagination**
   ```dart
   _firestore
       .collection('amenities')
       .where('buildingId', isEqualTo: buildingId)
       .orderBy('createdAt', descending: true)
       .limit(20)
       .snapshots()
   ```

4. **Use caching**
   ```dart
   // Cache user's buildingId
   String? _cachedBuildingId;
   
   Future<String?> getUserBuildingId() async {
     if (_cachedBuildingId != null) {
       return _cachedBuildingId;
     }
     
     final userDoc = await _firestore.collection('users').doc(uid).get();
     _cachedBuildingId = userDoc.get('buildingId');
     return _cachedBuildingId;
   }
   ```

---

## Debugging Checklist

- [ ] Firestore rules deployed and published
- [ ] User authenticated (check Firebase Auth)
- [ ] User document exists in Firestore
- [ ] buildingId is set in user document
- [ ] buildingId is not null or empty
- [ ] Query includes buildingId filter
- [ ] Data exists in Firestore with matching buildingId
- [ ] Field names match exactly (case-sensitive)
- [ ] Firestore indexes created for multi-field queries
- [ ] Network connection is working
- [ ] StreamBuilder has error handling
- [ ] UI shows loading/empty/error states

---

## Debug Logging

Add this to your services:

```dart
void _debugLog(String message) {
  print('🔵 [${DateTime.now().toIso8601String()}] $message');
}

void _debugError(String message, dynamic error) {
  print('❌ [${DateTime.now().toIso8601String()}] $message: $error');
}

// Usage
_debugLog('Fetching amenities for building: $buildingId');
_debugError('Error fetching amenities', e);
```

---

## Quick Fixes

| Problem | Quick Fix |
|---------|-----------|
| Permission denied | Deploy Firestore rules |
| Empty screens | Check buildingId in user document |
| Data not loading | Check Firestore indexes |
| Slow performance | Add limit() to queries |
| Wrong data | Check query filters |
| Access restricted not showing | Check buildingId is null |

---

## Support

If issues persist:

1. Check Firebase Console logs
2. Enable Firestore debug logging
3. Check network tab in DevTools
4. Verify Firestore rules syntax
5. Test with Firebase emulator

**All issues should be resolved!** 🚀

