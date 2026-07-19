# Home Screen Organization Name - Complete ✅

## Summary
The home screen (Dashboard) now displays the real organization name from Firestore instead of the hardcoded "Your Apartment" text.

## Screens Updated

### 1. Dashboard Screen (Home Screen) ✅
**File**: `lib/dashboard_screen.dart`

**Location**: Top header section with user greeting

**Before**:
```
┌─────────────────────────────────┐
│  Hi, Preetham! 👋               │
│                                  │
│  ┌──────────────────────────┐   │
│  │ Your Apartment           │   │  ← Hardcoded
│  │ t202                     │   │
│  └──────────────────────────┘   │
└─────────────────────────────────┘
```

**After**:
```
┌─────────────────────────────────┐
│  Hi, Preetham! 👋               │
│                                  │
│  ┌──────────────────────────┐   │
│  │ Skyline Society          │   │  ← Dynamic from Firestore
│  │ t202                     │   │
│  └──────────────────────────┘   │
└─────────────────────────────────┘
```

### 2. Profile Screen ✅
**File**: `lib/profile_screen.dart`

**Location**: Header section below avatar

**Before**:
```
┌─────────────────────────────────┐
│  [Avatar]  Preetham              │
│            +91 98765 43210       │
│                                  │
│  ┌──────────────────────────┐   │
│  │ Your Apartment           │   │  ← Hardcoded
│  │ t202                     │   │
│  └──────────────────────────┘   │
└─────────────────────────────────┘
```

**After**:
```
┌─────────────────────────────────┐
│  [Avatar]  Preetham              │
│            +91 98765 43210       │
│                                  │
│  ┌──────────────────────────┐   │
│  │ Skyline Society          │   │  ← Dynamic from Firestore
│  │ t202                     │   │
│  └──────────────────────────┘   │
└─────────────────────────────────┘
```

## Implementation Details

### Data Flow
```
1. User logs in
   ↓
2. Dashboard/Profile screen loads
   ↓
3. Fetch user ID from SharedPreferences
   ↓
4. OrganizationService.getOrganizationNameForUser(userId)
   ↓
5. Get user's building name from users collection
   ↓
6. Query admins collection where buildingName matches
   ↓
7. Extract organizationName from admin document
   ↓
8. Display in UI (or "Your Apartment" as fallback)
```

### Code Changes

**Dashboard Screen**:
```dart
// Added imports
import 'src/services/organization_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Added service instance
final _organizationService = OrganizationService();

// Added state variable
String _organizationName = 'Your Apartment'; // Default fallback

// Updated _loadDashboardData() method
String organizationName = 'Your Apartment';
if (userId != null) {
  organizationName = await _organizationService.getOrganizationNameForUser(userId);
}

setState(() {
  _organizationName = organizationName;
  // ... other state updates
});

// Updated UI
Text(
  _organizationName, // Dynamic organization name
  style: TextStyle(
    color: Colors.white.withOpacity(0.8),
    fontSize: 12,
  ),
),
```

**Profile Screen**:
```dart
// Same pattern as Dashboard Screen
// Added imports, service instance, state variable
// Updated _loadUserProfile() method
// Updated UI to use _organizationName
```

## Firestore Structure

### Required Collections

**admins Collection**:
```javascript
admins/{adminId}
{
  "buildingName": "Skyline Towers",
  "organizationName": "Skyline Residents Society",
  "email": "admin@skyline.com",
  "phone": "+91 98765 43210"
}
```

**users Collection**:
```javascript
users/{userId}
{
  "name": "Preetham",
  "buildingName": "Skyline Towers",  // Must match admin's buildingName
  "flatLabel": "t202",
  "email": "preetham@example.com",
  "phone": "+91 98765 43210"
}
```

## Testing

### Test Case 1: Organization Name Found
1. Create admin document with buildingName and organizationName
2. Create user with matching buildingName
3. Login as user
4. Check Dashboard:
   - ✅ Shows organization name instead of "Your Apartment"
5. Check Profile:
   - ✅ Shows organization name instead of "Your Apartment"

### Test Case 2: Organization Name Not Found
1. User has buildingName but no matching admin
2. Login as user
3. Check Dashboard:
   - ✅ Shows "Your Apartment" (fallback)
4. Check Profile:
   - ✅ Shows "Your Apartment" (fallback)

### Test Case 3: No Building Name
1. User document has no buildingName or buildingId
2. Login as user
3. Check Dashboard:
   - ✅ Shows "Your Apartment" (fallback)
4. Check Profile:
   - ✅ Shows "Your Apartment" (fallback)

## Performance

### Caching
- Organization name is cached after first fetch
- Subsequent loads use cached value
- Cache cleared on logout

### Parallel Loading
- Dashboard fetches organization name in parallel with other data
- No blocking or delays in UI rendering

## Error Handling

All error scenarios return "Your Apartment" as fallback:
- Admin document not found
- Organization name field empty
- Building name not found
- Firestore query error
- Network error

## Logging

Console logs for debugging:
```
📥 Fetching organization name for user: user123
✅ User building name: Skyline Towers
📥 Fetching organization name for building: Skyline Towers
✅ Organization name fetched: Skyline Residents Society
✅ Dashboard: Organization name: Skyline Residents Society
```

## Files Modified
1. `lib/src/services/organization_service.dart` (NEW)
2. `lib/dashboard_screen.dart` (Home Screen)
3. `lib/profile_screen.dart`

## Status
✅ **COMPLETE** - Home screen (Dashboard) and Profile screen now display real organization name from Firestore

## Notes
- The Dashboard screen IS the home screen in this app
- Both Dashboard and Profile screens have been updated
- Fallback to "Your Apartment" ensures app never breaks
- Organization name updates automatically when user data changes
