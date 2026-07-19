# Organization Name Display - Complete ✅

## Feature Implemented
Dynamic organization name display based on building name from Firestore `admins` collection.

## Changes Made

### 1. Created Organization Service
**File**: `lib/src/services/organization_service.dart`

Fetches organization name from Firestore following this flow:
```
User Document (users collection)
  ↓
Get buildingName or buildingId
  ↓
Query admins collection where buildingName matches
  ↓
Return organizationName from admin document
  ↓
Display in UI (replaces "Your Apartment")
```

**Key Features**:
- Singleton pattern for efficient reuse
- Caching to avoid repeated Firestore queries
- Supports both `buildingName` field and `buildingId` lookup
- Fallback to "Your Apartment" if organization name not found
- Comprehensive error handling

### 2. Updated Profile Screen
**File**: `lib/profile_screen.dart`

**Changes**:
- Added `OrganizationService` import and instance
- Added `_organizationName` state variable (default: "Your Apartment")
- Updated `_loadUserProfile()` to fetch organization name
- Changed "Your Apartment" label to dynamic `_organizationName`

**Display Location**:
```
┌─────────────────────────────────┐
│  [Avatar]  Preetham              │
│            +91 98765 43210       │
│                                  │
│  ┌──────────────────────────┐   │
│  │ [Organization Name]      │   │  ← Dynamic from admins collection
│  │ t202                     │   │  ← Flat number
│  └──────────────────────────┘   │
└─────────────────────────────────┘
```

### 3. Updated Dashboard Screen
**File**: `lib/dashboard_screen.dart`

**Changes**:
- Added `OrganizationService` import and instance
- Added `_organizationName` state variable (default: "Your Apartment")
- Updated `_loadDashboardData()` to fetch organization name
- Changed "Your Apartment" label to dynamic `_organizationName`

**Display Location**:
```
┌─────────────────────────────────┐
│  Hi, Preetham! 👋               │
│                                  │
│  ┌──────────────────────────┐   │
│  │ [Organization Name]      │   │  ← Dynamic from admins collection
│  │ t202                     │   │  ← Flat number
│  └──────────────────────────┘   │
└─────────────────────────────────┘
```

## Firestore Structure Required

### admins Collection
```javascript
admins/{adminId}
{
  "buildingName": "Skyline Towers",      // Building identifier
  "organizationName": "Skyline Society", // Organization name to display
  "email": "admin@skyline.com",
  "phone": "+91 98765 43210",
  // ... other admin fields
}
```

### users Collection
```javascript
users/{userId}
{
  "name": "Preetham",
  "buildingName": "Skyline Towers",  // Option 1: Direct building name
  // OR
  "buildingId": "building123",       // Option 2: Building ID reference
  "flatLabel": "t202",
  // ... other user fields
}
```

### buildings Collection (if using buildingId)
```javascript
buildings/{buildingId}
{
  "name": "Skyline Towers",  // Building name
  "address": "123 Main St",
  // ... other building fields
}
```

## Flow Function Logic

### Step 1: Get User's Building Name
```dart
// From user document
String? buildingName = userData['buildingName'];

// OR from building document via buildingId
if (buildingName == null && userData['buildingId'] != null) {
  final buildingDoc = await firestore
      .collection('buildings')
      .doc(userData['buildingId'])
      .get();
  buildingName = buildingDoc.data()?['name'];
}
```

### Step 2: Query Admins Collection
```dart
final querySnapshot = await firestore
    .collection('admins')
    .where('buildingName', isEqualTo: buildingName)
    .limit(1)
    .get();
```

### Step 3: Extract Organization Name
```dart
if (querySnapshot.docs.isNotEmpty) {
  final adminData = querySnapshot.docs.first.data();
  final organizationName = adminData['organizationName'];
  return organizationName ?? 'Your Apartment'; // Fallback
}
```

### Step 4: Display in UI
```dart
Text(
  _organizationName, // "Skyline Society" or "Your Apartment"
  style: TextStyle(
    color: Colors.white.withOpacity(0.8),
    fontSize: 12,
  ),
),
```

## Testing

### Test Case 1: Organization Name Found
1. Create admin document:
   ```javascript
   admins/admin1
   {
     "buildingName": "Skyline Towers",
     "organizationName": "Skyline Residents Society"
   }
   ```

2. Create user with matching building:
   ```javascript
   users/user1
   {
     "name": "Preetham",
     "buildingName": "Skyline Towers",
     "flatLabel": "t202"
   }
   ```

3. Login and check:
   - ✅ Dashboard shows: "Skyline Residents Society" instead of "Your Apartment"
   - ✅ Profile shows: "Skyline Residents Society" instead of "Your Apartment"

### Test Case 2: Organization Name Not Found
1. User has building name but no matching admin:
   ```javascript
   users/user2
   {
     "name": "John",
     "buildingName": "Unknown Building",
     "flatLabel": "A101"
   }
   ```

2. Check:
   - ✅ Dashboard shows: "Your Apartment" (fallback)
   - ✅ Profile shows: "Your Apartment" (fallback)

### Test Case 3: Using Building ID
1. Create building document:
   ```javascript
   buildings/building123
   {
     "name": "Green Valley Apartments"
   }
   ```

2. Create admin with building name:
   ```javascript
   admins/admin2
   {
     "buildingName": "Green Valley Apartments",
     "organizationName": "Green Valley HOA"
   }
   ```

3. Create user with buildingId:
   ```javascript
   users/user3
   {
     "name": "Sarah",
     "buildingId": "building123",
     "flatLabel": "B205"
   }
   ```

4. Check:
   - ✅ Service fetches building name from buildings collection
   - ✅ Service queries admins with building name
   - ✅ Dashboard shows: "Green Valley HOA"
   - ✅ Profile shows: "Green Valley HOA"

## Performance Optimization

### Caching
- Organization name is cached after first fetch
- Cache key: building name
- Cache cleared on logout or manual refresh

### Efficient Queries
- Uses `.limit(1)` to fetch only one admin document
- Parallel data fetching in dashboard for faster load times

## Error Handling

### Scenarios Covered
1. **No admin found**: Returns "Your Apartment" fallback
2. **Organization name empty**: Returns "Your Apartment" fallback
3. **Building name missing**: Returns "Your Apartment" fallback
4. **Firestore error**: Returns "Your Apartment" fallback
5. **User not found**: Returns "Your Apartment" fallback

### Logging
All operations are logged with emoji prefixes:
- 📥 Fetching data
- ✅ Success
- ⚠️  Warning (fallback used)
- ❌ Error

## Files Modified
1. `lib/src/services/organization_service.dart` (NEW)
2. `lib/profile_screen.dart`
3. `lib/dashboard_screen.dart`

## Status
✅ **COMPLETE** - Organization name now displays dynamically based on building name from admins collection

## Next Steps
1. Test with real Firestore data
2. Verify organization name displays correctly
3. Ensure fallback works when admin not found
4. Test with different building configurations
