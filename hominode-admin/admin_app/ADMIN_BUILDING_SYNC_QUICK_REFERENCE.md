# Admin Building Sync - Quick Reference

## Overview
Buildings are stored in TWO places:
1. `buildings` collection (primary)
2. `admins/{adminId}` document (synchronized copy)

## Admin Document Structure

```javascript
admins/{adminId} {
  // Profile
  "name": "John Doe",
  "email": "john@example.com",
  
  // Buildings array (NEW)
  "buildings": [
    {
      "buildingId": "building_123",
      "buildingName": "Tower A",
      "floors": 10,
      "flatsPerFloor": 4,
      "totalFlats": 40,
      "occupied": 25,
      "vacant": 15,
      "occupancyRate": 62,
      "addedAt": Timestamp,
      "updatedAt": Timestamp
    }
  ],
  
  // Building IDs array (NEW)
  "buildingIds": ["building_123", "building_456"]
}
```

## When Data is Synced

| Action | buildings collection | admins document |
|--------|---------------------|-----------------|
| Add building | ✅ Created | ✅ Added to arrays |
| Update building | ✅ Updated | ✅ Updated in array |
| Delete building | ✅ Deleted | ✅ Removed from arrays |
| Assign resident | ✅ Occupancy updated | ✅ Occupancy synced |
| Remove resident | ✅ Occupancy updated | ✅ Occupancy synced |

## Key Methods

### BuildingService.addBuilding()
- Creates building in `buildings` collection
- Adds building to admin's `buildings` array
- Adds building ID to admin's `buildingIds` array

### BuildingService.updateBuilding()
- Updates building in `buildings` collection
- Updates building in admin's `buildings` array

### BuildingService.deleteBuilding()
- Deletes building from `buildings` collection
- Removes building from admin's `buildings` array
- Removes building ID from admin's `buildingIds` array

### BuildingService.syncOccupancyFromFlats()
- Updates occupancy in `buildings` collection
- Syncs occupancy to admin's `buildings` array

## Benefits
✅ Admin has direct access to their buildings
✅ No need to query buildings collection
✅ Occupancy stats always in sync
✅ Multi-tenancy enforced at document level

## Testing Checklist
- [ ] Add building → Check both locations
- [ ] Assign resident → Check occupancy synced
- [ ] Update building → Check both locations
- [ ] Delete building → Check removed from both

## Status
✅ COMPLETE - All operations synchronized
