# ⚡ Amenities Not Showing - Quick Fix

## Run This Command First
```bash
cd resident_app
flutter run lib/test_amenities_fetch.dart
```

This will tell you exactly what's wrong.

---

## Most Common Issues

### 1. No Amenities in Firestore ❌
**Fix**: Add amenities to Firestore

Go to Firebase Console → Firestore → Create collection `amenities`

Add a document:
```json
{
  "name": "Swimming Pool",
  "price": "₹500/hour",
  "adminId": "COPY_FROM_USER_DOCUMENT",
  "isActive": true,
  "iconName": "pool",
  "backgroundColor": "#D6EBFF",
  "iconColor": "#0A64FF"
}
```

### 2. AdminId Mismatch ❌
**Fix**: Update amenity documents

1. Open Firebase Console → Firestore
2. Open your user document → Copy the `adminId` value
3. Open each amenity document → Set `adminId` to the copied value

### 3. User Has No AdminId ❌
**Fix**: Add adminId to user document

1. Open Firebase Console → Firestore → users collection
2. Find your user document
3. Add field: `adminId` = `"some_admin_id"`

---

## Test Results Meaning

### ✅ Good Output
```
✅ User logged in: abc123
✅ User has adminId: admin_xyz
✅ Fetched 4 amenities for admin admin_xyz
```
→ Everything working! If still not showing, restart the app.

### ❌ Bad Output #1
```
Total documents in collection: 0
```
→ No amenities in Firestore. Add them (see above).

### ❌ Bad Output #2
```
Total documents in collection: 5
Amenities for this admin: 0
```
→ AdminId mismatch. Update amenity documents.

### ❌ Bad Output #3
```
⚠️ User has no adminId assigned
```
→ Add adminId to user document.

---

## Emergency Bypass (For Testing Only)

If you just want to see amenities without fixing adminId:

**Edit**: `lib/src/services/booking_firestore_service.dart`

**Find** (line ~60):
```dart
.where('adminId', isEqualTo: adminId)
```

**Delete that line** (keep the isActive line)

**Result**:
```dart
final snapshot = await _firestore
    .collection(amenitiesCollection)
    .where('isActive', isEqualTo: true)  // Only this line
    .get();
```

Save and hot reload. Amenities should appear.

---

## Quick Checklist

Before asking for help, verify:

- [ ] Ran the test script
- [ ] Amenities exist in Firestore
- [ ] Amenities have `isActive: true`
- [ ] Amenities have `adminId` field
- [ ] User has `adminId` field
- [ ] Both adminIds match
- [ ] Restarted the app

---

## Need More Help?

See full diagnostic guide: `AMENITIES_DIAGNOSTIC_GUIDE.md`
