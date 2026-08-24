# Quick Setup Guide - Multi-Tenancy

## Step 1: Create Admin Document in Firestore

1. Open Firebase Console → Firestore Database
2. Go to `admins` collection (create if doesn't exist)
3. Add document with your Firebase Auth UID as document ID

```javascript
// Document ID: YOUR_FIREBASE_AUTH_UID (from Authentication tab)
{
  "name": "Your Name",
  "email": "your@email.com",
  "phone": "1234567890",
  "organization": "Your Property Name",
  "role": "admin",
  "buildingIds": [],
  "createdAt": {current timestamp},
  "updatedAt": {current timestamp}
}
```

## Step 2: Login to App

- Use your Firebase Auth credentials
- App will fetch data from `admins` collection
- Dashboard will show your organization name

## Step 3: Create Your First Building

- Go to Manage Buildings
- Click "Add Building"
- Fill in details
- Save

**What happens:**
- Building is created with your `adminId`
- Building ID is added to your `buildingIds` array
- You can now see this building in the list

## Step 4: Verify Multi-Tenancy

Check Firestore console:

### Your Admin Document
```javascript
{
  ...
  "buildingIds": ["building_id_1"]  // ← Building ID added
}
```

### Your Building Document
```javascript
{
  ...
  "adminId": "your_firebase_auth_uid"  // ← Linked to you
}
```

## Step 5: Test Data Isolation

1. Create second admin account
2. Login as second admin
3. Create building for second admin
4. Logout and login as first admin
5. Verify you only see your buildings

## Current Status

✅ **Working:**
- Admin profile (fetch from `admins` collection)
- Dashboard (shows organization name)
- Building creation (links to admin)
- Building list (filtered by admin)

⏳ **To Be Updated:**
- Dashboard stats (filter by buildings)
- Residents list (filter by buildings)
- Flats list (filter by buildings)
- Bills (filter by buildings)
- Complaints (filter by buildings)
- Visitors (filter by buildings)

## Quick Test

```dart
// Test if admin has buildings
final adminService = AdminService();
final buildingIds = await adminService.getAdminBuildingIds();
print('My buildings: $buildingIds');

// Test if building list is filtered
final buildings = await adminService.getAdminBuildings();
print('I can see ${buildings.length} buildings');
```

## Troubleshooting

**Problem:** Can't see any buildings
**Solution:** Check if your admin document has `buildingIds` array

**Problem:** See all buildings (not filtered)
**Solution:** Make sure BuildingService is using the updated code

**Problem:** Dashboard shows "Loading..."
**Solution:** Check if admin document exists in `admins` collection

## Next Steps

See `MULTI_TENANCY_COMPLETE_IMPLEMENTATION.md` for:
- Complete architecture
- Updating other services
- Security rules
- Full implementation guide
