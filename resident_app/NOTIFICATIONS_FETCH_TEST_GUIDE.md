# Notifications Firestore Fetch - Test Guide

## Overview
The notifications screen now fetches data from the Firestore `notices` collection. This guide helps you test and verify the integration.

## Firestore Field Mapping

The service handles field name variations between admin app and resident app:

### Date Fields
| Admin App Field | Resident App Field | Fallback |
|----------------|-------------------|----------|
| `publishedAt` | `publishDate` | `createdAt` |
| `expiresAt` | `expiryDate` | none |

### Status Fields
| Admin App Field | Resident App Field | Logic |
|----------------|-------------------|-------|
| `status: "published"` | `isActive: true` | Either works |
| `isActive: true` | `isActive: true` | Either works |

### All Supported Fields
```javascript
{
  // Required fields
  "title": "Notice Title",
  "content": "Notice content",
  
  // Date fields (flexible)
  "publishedAt": Timestamp,      // OR "publishDate"
  "expiresAt": Timestamp,        // OR "expiryDate" (optional)
  "createdAt": Timestamp,
  "updatedAt": Timestamp,
  
  // Status fields (flexible)
  "status": "published",         // OR "isActive": true
  
  // Optional fields
  "category": "general",         // general, maintenance, event, urgent
  "priority": "medium",          // low, medium, high
  "authorId": "user_id",
  "authorName": "Admin Name",
  "attachments": [],
  "targetFlats": [],             // Empty = all flats
  "isUrgent": false,
  "requiresAcknowledgment": false
}
```

## Testing Steps

### Step 1: Run the App

```bash
cd resident_app
flutter run -d ZA222LQT6V
```

### Step 2: Navigate to Notifications

1. App opens on Dashboard/Home screen
2. Tap the notification bell icon (top right)
3. Should navigate to Notifications screen

### Step 3: Check Console Logs

Watch for these logs in the console:

```
🔵 Loading notifications from Firestore...
🔵 Fetching notices from Firestore...
🔵 User flat ID: A101
🔵 Found 1 notices in Firestore
📄 Processing notice: zWP8ShX7KdKvMG4MATBq
   Data: {title: null, content: ewgdnfnnnf, ...}
✅ Added notice (all flats): Notice
✅ Loaded 1 notifications
```

### Step 4: Verify Display

The notification should show:
- Icon based on category (blue notification icon for general)
- Title (or "Notice" if title is missing)
- Content preview (first 2 lines)
- Relative time ("Just now", "5m ago", etc.)
- Blue background if unread

### Step 5: Test Notice Detail

1. Tap on a notification
2. Should open dialog with full content
3. Should mark as read (blue background removed)
4. Should move to "Read" tab

## Current Firestore Data

Based on the screenshot, you have one notice:

```javascript
{
  "id": "zWP8ShX7KdKvMG4MATBq",
  "authorId": "YGr4SFyweKadjzuHNqTdZcPB9Z2",
  "authorName": "sahyon",
  "content": "ewgdnfnnnf",
  "createdAt": "20 February 2026 at 22:59:12 UTC+5:30",
  "expiresAt": "28 February 2026 at 00:00:00 UTC+5:30",
  "isUrgent": false,
  "priority": "medium",
  "publishedAt": "20 February 2026 at 22:59:12 UTC+5:30",
  "requiresAcknowledgment": false,
  "status": "published"
}
```

### Issues with This Notice:
1. ❌ Missing `title` field → Will show as "Notice"
2. ✅ Has `status: "published"` → Will be shown
3. ✅ Has `publishedAt` → Will be parsed correctly
4. ✅ Has `expiresAt` → Will check expiry
5. ✅ Missing `targetFlats` → Will show to all users

## Expected Behavior

### Scenario 1: Notice Shows Up
✅ Notice appears in "All" tab
✅ Notice appears in "Unread" tab
✅ Shows "Notice" as title (since title field is missing)
✅ Shows "ewgdnfnnnf" as content
✅ Shows relative time
✅ Has blue background (unread)

### Scenario 2: Tap Notice
✅ Opens dialog with full content
✅ Marks as read
✅ Blue background removed
✅ Moves to "Read" tab

### Scenario 3: Pull to Refresh
✅ Shows loading indicator
✅ Refetches from Firestore
✅ Updates list

## Troubleshooting

### Issue: No Notifications Showing

**Check Console Logs:**
```
🔵 Found 0 notices in Firestore
```

**Possible Causes:**
1. No notices in Firestore
2. All notices are expired
3. All notices have `status != "published"` and `isActive != true`
4. User not logged in

**Solution:**
- Check Firebase Console for notices
- Verify `status` or `isActive` field
- Check `expiresAt` / `expiryDate` is in future
- Verify user is logged in

### Issue: Notice Shows But No Title

**Console Log:**
```
✅ Added notice (all flats): Notice
```

**Cause:**
- `title` field is missing in Firestore

**Solution:**
- Add `title` field to notice document in Firebase Console

### Issue: Error Parsing Notice

**Console Log:**
```
❌ Error parsing notice zWP8ShX7KdKvMG4MATBq: ...
```

**Possible Causes:**
1. Invalid timestamp format
2. Missing required fields
3. Type mismatch

**Solution:**
- Check console for full error message
- Verify field types in Firestore
- Ensure timestamps are Firestore Timestamp type

### Issue: Notice Not Targeted to User

**Console Log:**
```
⏭️ Skipping notice (not targeted to user): Notice Title
```

**Cause:**
- Notice has `targetFlats` array that doesn't include user's flat

**Solution:**
- Set `targetFlats: []` for all users
- Or add user's flat ID to `targetFlats` array

## Adding Test Notices

### Method 1: Firebase Console

1. Open Firebase Console
2. Go to Firestore Database
3. Select `notices` collection
4. Click "Add document"
5. Use this structure:

```javascript
{
  "title": "Test Notice",
  "content": "This is a test notification from Firebase Console",
  "category": "general",
  "priority": "medium",
  "authorId": "admin123",
  "authorName": "Admin",
  "attachments": [],
  "publishedAt": <current timestamp>,
  "expiresAt": <future timestamp or null>,
  "status": "published",
  "targetFlats": [],
  "createdAt": <current timestamp>,
  "updatedAt": <current timestamp>
}
```

### Method 2: Admin App

Use the admin app to create notices (recommended for production).

## Field Recommendations

For best compatibility, admin app should include:

### Required Fields:
- `title` - Notice title
- `content` - Notice content
- `publishedAt` - Publication timestamp
- `status` - Set to "published"
- `createdAt` - Creation timestamp
- `updatedAt` - Update timestamp

### Recommended Fields:
- `category` - For icon display
- `priority` - For urgency indication
- `authorId` - For tracking
- `authorName` - For display
- `targetFlats` - For targeting (empty = all)

### Optional Fields:
- `expiresAt` - Auto-hide after date
- `attachments` - File attachments
- `isUrgent` - Urgent flag
- `requiresAcknowledgment` - Require user action

## Success Criteria

✅ Notifications fetch from Firestore `notices` collection
✅ Handles both `publishedAt` and `publishDate` fields
✅ Handles both `status: "published"` and `isActive: true`
✅ Shows notices with missing `title` field
✅ Filters expired notices
✅ Supports targeted and broadcast notices
✅ Marks notices as read
✅ Tracks read/unread status
✅ Pull-to-refresh works
✅ Real-time updates (optional)

## Console Log Reference

### Successful Fetch:
```
🔵 Loading notifications from Firestore...
🔵 Fetching notices from Firestore...
🔵 User flat ID: A101
🔵 Found 1 notices in Firestore
📄 Processing notice: zWP8ShX7KdKvMG4MATBq
   Data: {authorId: ..., content: ..., status: published}
✅ Added notice (all flats): Test Notice
✅ Returning 1 notices
✅ Loaded 1 notifications
```

### No Notices:
```
🔵 Loading notifications from Firestore...
🔵 Fetching notices from Firestore...
🔵 Found 0 notices in Firestore
✅ Returning 0 notices
✅ Loaded 0 notifications
```

### Error:
```
🔵 Loading notifications from Firestore...
❌ Error fetching notices: [error message]
   Stack trace: [stack trace]
```

---
**Status**: ✅ Ready for Testing
**Collection**: `notices`
**Field Compatibility**: Flexible (handles admin app variations)
**Date**: February 20, 2026
