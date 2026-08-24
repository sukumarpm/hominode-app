# Poster Expiry Feature - Complete Implementation

## Overview
The poster management system now includes a complete expiry feature that allows admins to set when posters should expire. Residents will only see active (non-expired) posters in their carousel view.

## Features Implemented

### 1. Admin Upload Modal (UI Pattern)
**File**: `admin_app/lib/widgets/cloudinary_poster_upload_modal.dart`

The poster upload modal now matches the CreateEventModal UI pattern with:
- ✅ Centered overlay dialog (not bottom sheet)
- ✅ Dark overlay background (Colors.black.withOpacity(0.4))
- ✅ Header with title, subtitle, and close button
- ✅ Form fields with proper labels and validation
- ✅ **NEW**: Expiry Date picker (dd-mm-yyyy format)
- ✅ **NEW**: Expiry Time picker (HH:MM format)
- ✅ Image upload with preview
- ✅ Create button at bottom
- ✅ Proper spacing and styling matching CreateEventModal

**Key Fields**:
- Poster Title (required)
- Category (dropdown: General, Maintenance, Event, Announcement, Safety)
- Description (optional)
- **Expiry Date** (optional, date picker)
- **Expiry Time** (optional, time picker, defaults to 23:59)
- Upload Poster Image (required)

### 2. Cloudinary Poster Service (Backend)
**File**: `admin_app/lib/services/cloudinary_poster_service.dart`

#### Updated `createPoster()` Method
```dart
Future<String> createPoster({
  required String title,
  required String description,
  required File imageFile,
  String? category,
  String? expiryDate,      // NEW: dd-mm-yyyy format
  String? expiryTime,      // NEW: HH:MM format
}) async
```

**Flow Function Pattern** (6 steps):
1. 🔐 Validate admin authentication
2. 📋 Validate input data
3. 📤 Upload image to Cloudinary
4. 📋 Parse expiry date and time
5. 💾 Save poster to Firestore with expiry data
6. 🔔 Log completion

**Firestore Document Structure**:
```json
{
  "title": "string",
  "description": "string",
  "category": "string",
  "imageUrl": "string",
  "adminId": "string",
  "adminName": "string",
  "buildingIds": ["string"],
  "status": "active",
  "expiryDate": "dd-mm-yyyy",           // NEW
  "expiryTime": "HH:MM",                // NEW
  "expiryDateTime": Timestamp,          // NEW: Parsed DateTime for filtering
  "createdAt": Timestamp,
  "updatedAt": Timestamp
}
```

#### Updated `getPostersForBuilding()` Method
**Flow Function Pattern** (3 steps):
1. ✅ Validate building ID
2. 📋 Fetch active posters from Firestore
3. 🔄 Filter by building ID AND expiry status in memory

**Expiry Logic**:
- Compares current time with `expiryDateTime`
- Only returns posters where `expiryDateTime` is NULL or AFTER current time
- Automatically hides expired posters from residents

#### Updated `PosterModel` Class
Added new fields:
```dart
final String? expiryDate;        // dd-mm-yyyy format
final String? expiryTime;        // HH:MM format
final DateTime? expiryDateTime;  // Parsed DateTime for comparison
```

### 3. Admin Posters Management Screen
**File**: `admin_app/lib/admin_posters_management_screen.dart`

**Enhanced Poster Card Display**:
- ✅ Shows expiry date and time in tooltip
- ✅ Displays "Expired" badge on expired posters (red)
- ✅ Changes border color to red for expired posters
- ✅ Shows expiry status in the status badge
- ✅ Highlights expiry date in red if poster is expired

**Card Features**:
- Poster image with optional "Expired" badge overlay
- Title and status badge
- Description
- Category badge
- Expiry date display with tooltip showing full date and time
- Created time (relative)
- Delete button

### 4. Resident Posters Carousel Screen
**File**: `admin_app/lib/resident_posters_carousel_screen.dart`

**Automatic Expiry Filtering**:
- Residents only see active, non-expired posters
- Expired posters are automatically hidden
- No manual refresh needed (real-time via StreamBuilder)

**Display Features**:
- Carousel view with page indicators
- Only shows valid posters
- Sorted by creation date (newest first)

## Data Flow

### Admin Creates Poster with Expiry
```
1. Admin clicks "Create Poster" button
2. Modal opens (centered overlay)
3. Admin fills form:
   - Title, Category, Description
   - Selects expiry date (date picker)
   - Selects expiry time (time picker)
   - Uploads image
4. Admin clicks "Create & Publish"
5. Modal passes expiry data to service:
   - expiryDate: "dd-mm-yyyy"
   - expiryTime: "HH:MM"
6. Service parses dates and creates DateTime object
7. Poster saved to Firestore with:
   - expiryDate (string)
   - expiryTime (string)
   - expiryDateTime (Timestamp for filtering)
8. Admin sees poster in management screen with expiry info
```

### Resident Views Posters
```
1. Resident opens Posters screen
2. Service fetches all active posters
3. Filters by:
   - Building ID match
   - Status = "active"
   - expiryDateTime > current time
4. Only non-expired posters displayed in carousel
5. Expired posters automatically hidden
```

## Expiry Date/Time Format

### Date Format
- **Input**: dd-mm-yyyy (from date picker)
- **Storage**: "dd-mm-yyyy" (string) + Timestamp (for filtering)
- **Example**: "25-03-2026"

### Time Format
- **Input**: HH:MM (from time picker)
- **Storage**: "HH:MM" (string)
- **Default**: "23:59" (if not specified)
- **Example**: "18:30"

### DateTime Parsing
```dart
// Example: "25-03-2026" + "18:30"
final dateParts = "25-03-2026".split('-');
final day = 25, month = 3, year = 2026;
final hour = 18, minute = 30;
final expiryDateTime = DateTime(2026, 3, 25, 18, 30);
```

## Expiry Validation

### Admin Side
- Expiry date is optional
- If provided, must be today or in the future
- Time defaults to 23:59 if not specified

### Resident Side
- Automatic filtering in real-time
- No manual refresh needed
- Expired posters silently hidden

## UI/UX Enhancements

### Admin Management Screen
- **Expired Badge**: Red "Expired" badge on poster image
- **Border Highlight**: Red border for expired posters
- **Status Badge**: Shows "expired" instead of "active"
- **Expiry Tooltip**: Hover to see full expiry date and time
- **Visual Distinction**: Expired posters clearly marked

### Resident Carousel
- Only sees active posters
- No indication of expiry (clean experience)
- Automatic updates when posters expire

## Flow Function Compliance

### Create Poster Flow
```
🔵 CLOUDINARY POSTER SERVICE: Starting poster creation...
🔐 STEP 1: Validating admin authentication...
✅ STEP 1 PASSED: Admin authenticated - [adminId]
📋 STEP 2: Validating input data...
✅ STEP 2 PASSED: Input data validated
📤 STEP 3A: Uploading image to Cloudinary...
✅ STEP 3A PASSED: Image uploaded to Cloudinary - [imageUrl]
📋 STEP 4: Parsing expiry date and time...
✅ STEP 4 PASSED: Expiry datetime parsed - [expiryDateTime]
💾 STEP 5: Saving poster to Firestore...
✅ STEP 5 PASSED: Poster saved - [posterId]
🔔 STEP 6: Logging completion...
✅ CLOUDINARY POSTER SERVICE: Poster creation COMPLETE
```

### Get Posters for Building Flow
```
🔵 CLOUDINARY POSTER SERVICE: Fetching posters for building - [buildingId]
✅ STEP 1 PASSED: Building ID validated
📋 STEP 2: Fetching active posters...
✅ STEP 2 PASSED: Received [count] posters
🔄 STEP 3: Filter by building ID and expiry status
✅ STEP 3 PASSED: Filtered [count] active posters for building
```

## Testing Checklist

### Admin Features
- [ ] Create poster with expiry date and time
- [ ] Create poster without expiry (should work)
- [ ] View poster in management screen with expiry info
- [ ] See "Expired" badge on expired posters
- [ ] Delete expired poster
- [ ] Verify expiry date displays in tooltip

### Resident Features
- [ ] View only non-expired posters in carousel
- [ ] Expired posters not visible
- [ ] Carousel updates when poster expires
- [ ] No errors when no posters available

### Edge Cases
- [ ] Create poster with today's date and past time (should expire immediately)
- [ ] Create poster with future date
- [ ] Create poster without expiry date (should never expire)
- [ ] Multiple posters with different expiry dates

## Configuration

### Cloudinary Setup
- Cloud Name: `dailyccofb`
- Upload Preset: (User to configure in Cloudinary dashboard)
- Folder: `posters`

### Firestore Rules
Ensure Firestore rules allow:
- Admins to create/update/delete posters
- Residents to read posters for their building

## Files Modified

1. **admin_app/lib/services/cloudinary_poster_service.dart**
   - Updated `createPoster()` to accept expiry parameters
   - Updated `getPostersForBuilding()` to filter expired posters
   - Updated `PosterModel` with expiry fields

2. **admin_app/lib/widgets/cloudinary_poster_upload_modal.dart**
   - Added expiry date picker field
   - Added expiry time picker field
   - Updated `_uploadPoster()` to pass expiry data

3. **admin_app/lib/admin_posters_management_screen.dart**
   - Enhanced `_buildPosterCard()` to show expiry info
   - Added "Expired" badge display
   - Added expiry date tooltip

4. **admin_app/lib/resident_posters_carousel_screen.dart**
   - No changes needed (filtering handled in service)

## Next Steps (Optional Enhancements)

1. **Auto-Delete Expired Posters**: Add Cloud Function to delete expired posters
2. **Expiry Notifications**: Notify admins when posters are about to expire
3. **Extend Expiry**: Allow admins to extend poster expiry date
4. **Expiry History**: Track when posters expired
5. **Bulk Expiry**: Set expiry for multiple posters at once

## Summary

The poster expiry feature is now fully implemented with:
- ✅ UI matching CreateEventModal pattern
- ✅ Date/time picker for expiry selection
- ✅ Backend support for storing and filtering expiry
- ✅ Real-time filtering for residents
- ✅ Visual indicators for expired posters in admin view
- ✅ Flow function compliance with proper logging
- ✅ Multi-tenancy support (building-based filtering)
- ✅ Zero compilation errors

All files compile successfully and are ready for testing.
