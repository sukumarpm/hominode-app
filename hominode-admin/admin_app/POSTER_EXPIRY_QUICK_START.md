# Poster Expiry Feature - Quick Start Guide

## What's New

The poster management system now supports expiry dates and times. Admins can set when posters should expire, and residents will only see active posters.

## How to Use

### For Admins

#### Creating a Poster with Expiry

1. **Open Admin App** → Navigate to Quick Access
2. **Click "Manage Posters"** → Opens Admin Posters Management Screen
3. **Click "Create Poster"** → Opens centered overlay modal
4. **Fill the form**:
   - **Poster Title**: Enter title (required)
   - **Category**: Select from dropdown (General, Maintenance, Event, Announcement, Safety)
   - **Description**: Enter details (optional)
   - **Expiry Date**: Click date picker, select date (optional)
   - **Expiry Time**: Click time picker, select time (optional, defaults to 23:59)
   - **Upload Poster Image**: Click to select image (required)
5. **Click "Create & Publish"** → Poster created and saved

#### Viewing Posters with Expiry Info

1. **Open Admin Posters Management Screen**
2. **View poster cards** showing:
   - Poster image
   - Title and status badge
   - Description
   - Category badge
   - **Expiry date** (if set) - hover for full date and time
   - Created time
   - Delete button

#### Expired Poster Indicators

- **Red "Expired" badge** on poster image
- **Red border** around poster card
- **Red status badge** showing "expired"
- **Red expiry date text** for easy identification

### For Residents

#### Viewing Posters

1. **Open Resident App** → Navigate to Home Screen
2. **Scroll to Posters section** or **Click "View All Posters"**
3. **Browse carousel** of active posters
4. **Swipe left/right** to view different posters
5. **See indicators** showing current poster number

#### What You See

- Only **active, non-expired posters** are displayed
- Expired posters are **automatically hidden**
- No manual refresh needed
- Updates in real-time

## Expiry Date/Time Format

### Date Format
- **Format**: dd-mm-yyyy
- **Example**: 25-03-2026 (March 25, 2026)
- **Selection**: Use date picker (no manual typing)

### Time Format
- **Format**: HH:MM (24-hour)
- **Example**: 18:30 (6:30 PM)
- **Default**: 23:59 (11:59 PM) if not specified
- **Selection**: Use time picker (no manual typing)

## Example Scenarios

### Scenario 1: Create Poster Valid for 7 Days
1. Today: March 25, 2026
2. Set Expiry Date: April 1, 2026
3. Set Expiry Time: 23:59
4. Poster visible for 7 days, then automatically hidden

### Scenario 2: Create Poster Without Expiry
1. Leave Expiry Date empty
2. Leave Expiry Time empty
3. Poster never expires (always visible)

### Scenario 3: Create Urgent Poster (Expires Today)
1. Set Expiry Date: Today (March 25, 2026)
2. Set Expiry Time: 18:00 (6:00 PM)
3. Poster visible until 6:00 PM today

## Troubleshooting

### Poster Not Showing in Resident View
- **Check**: Is poster expired? (Check admin screen)
- **Check**: Is resident in correct building?
- **Check**: Is poster status "active"?
- **Solution**: Delete and recreate poster

### Expiry Date Not Saving
- **Check**: Did you select a date using the date picker?
- **Check**: Is the date in valid format (dd-mm-yyyy)?
- **Solution**: Use the date picker instead of typing

### Expired Poster Still Visible
- **Check**: Refresh the app
- **Check**: Check the exact expiry time
- **Solution**: Wait a few seconds for real-time update

## Key Features

✅ **Centered Modal UI** - Matches CreateEventModal pattern
✅ **Date Picker** - Easy date selection (dd-mm-yyyy)
✅ **Time Picker** - Easy time selection (HH:MM)
✅ **Real-time Filtering** - Residents see only active posters
✅ **Visual Indicators** - Expired posters clearly marked
✅ **Optional Expiry** - Posters can be permanent
✅ **Flow Function Logging** - Full audit trail
✅ **Multi-tenancy** - Building-based filtering

## Files Involved

- `admin_app/lib/widgets/cloudinary_poster_upload_modal.dart` - Upload modal UI
- `admin_app/lib/services/cloudinary_poster_service.dart` - Backend service
- `admin_app/lib/admin_posters_management_screen.dart` - Admin view
- `admin_app/lib/resident_posters_carousel_screen.dart` - Resident view

## Testing Checklist

### Admin Testing
- [ ] Create poster with expiry date and time
- [ ] Create poster without expiry
- [ ] View expiry info in management screen
- [ ] See "Expired" badge on expired posters
- [ ] Delete expired poster
- [ ] Hover over expiry date to see tooltip

### Resident Testing
- [ ] View only non-expired posters
- [ ] Expired posters not visible
- [ ] Carousel works smoothly
- [ ] No errors when no posters available

### Edge Cases
- [ ] Create poster expiring today
- [ ] Create poster expiring in future
- [ ] Create poster without expiry
- [ ] Multiple posters with different expiry dates

## Support

For issues or questions:
1. Check the detailed documentation: `POSTER_EXPIRY_FEATURE_COMPLETE.md`
2. Review flow function logs in console
3. Verify Firestore data structure
4. Check Cloudinary configuration

---

**Status**: ✅ Complete and Ready for Testing
**Last Updated**: March 25, 2026
