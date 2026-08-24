# Admin Collection - Quick Reference

## What Changed?

Admin profile data now uses the `admins` collection instead of `users` collection.

## Collection Usage

### `admins` Collection
- **Purpose**: Store admin/staff profiles
- **Used by**: Admin App only
- **Document ID**: Firebase Auth UID
- **Fields**: name, email, phone, organization, role, buildingIds

### `users` Collection
- **Purpose**: Store resident profiles
- **Used by**: Both Admin App and Resident App
- **Document ID**: Auto-generated or Firebase Auth UID
- **Fields**: name, email, phone, residentId, flatId, role, etc.

## Files Updated

1. **Edit Profile Modal** (`lib/widgets/edit_profile_modal.dart`)
   - Reads from: `admins` collection
   - Writes to: `admins` collection

2. **Dashboard** (`lib/admin_dashboard_page.dart`)
   - Reads from: `admins` collection
   - Displays: Admin name, role, organization

3. **Profile Screen** (`lib/profile_screen.dart`)
   - Reads from: `admins` collection
   - Displays: Admin profile information

## Quick Test

1. Login as admin
2. Go to Profile → Edit Profile
3. Update your name or organization
4. Save changes
5. Check Firestore console → `admins` collection
6. Verify your changes are saved there

## Data Structure

```javascript
// admins/{adminUid}
{
  "name": "Admin Name",
  "email": "admin@example.com",
  "phone": "1234567890",
  "organization": "Harmony Heights",
  "role": "admin",
  "buildingIds": [],
  "createdAt": Timestamp,
  "updatedAt": Timestamp
}
```

## Important Notes

- ✅ Admin data is now separate from resident data
- ✅ Dashboard displays organization name from `admins` collection
- ✅ Profile edit saves to `admins` collection
- ✅ All admin screens fetch from `admins` collection
- ⚠️ Make sure admin documents exist in `admins` collection
- ⚠️ Use same document ID as Firebase Auth UID

## Migration Required?

If you have existing admin data in `users` collection, you need to:
1. Copy admin documents from `users` to `admins` collection
2. Keep the same document ID (Firebase Auth UID)
3. See `ADMIN_DATA_COLLECTION_MIGRATION_COMPLETE.md` for migration script

## Status: ✅ COMPLETE

All admin profile functionality now uses the `admins` collection.
