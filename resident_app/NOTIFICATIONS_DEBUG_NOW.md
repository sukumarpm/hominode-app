# Notifications Debug Guide - URGENT

## Issue
Notifications screen shows "No notifications" even though there's a notice in Firestore.

## What I Fixed

1. Removed `orderBy` clause that might require a Firestore index
2. Added extensive logging to see exactly what's happening
3. Improved error handling for date parsing

## Run This Now

```bash
cd resident_app
flutter run -d ZA222LQT6V
```

## Watch Console Logs

When you tap the notification bell icon, you should see these logs:

### Expected Logs:

```
🔵 Loading notifications from Firestore...
🔵 Fetching notices from Firestore...
🔵 User flat ID: [your flat ID or null]
🔵 Querying notices collection...
🔵 Found 1 total notices in Firestore
📄 Processing notice: zWP8ShX7KdKvMG4MATBq
   Raw data keys: [authorId, authorName, content, createdAt, expiresAt, isUrgent, priority, publishedAt, requiresAcknowledgment, status]
   status: published
   isActive: null
   publishedAt: [timestamp]
   expiresAt: [timestamp]
✅ Added notice (all flats): Notice
✅ Returning 1 notices
✅ Loaded 1 notifications
```

## What to Look For

### Scenario 1: No Logs at All
**Problem**: Service not being called
**Check**: Is the notifications screen actually loading?

### Scenario 2: "No user logged in"
```
❌ No user logged in
```
**Problem**: User not authenticated
**Solution**: Make sure you're logged in

### Scenario 3: "Found 0 total notices"
```
🔵 Found 0 total notices in Firestore
```
**Problem**: Query not finding notices
**Solution**: Check Firestore rules, verify collection name is "notices"

### Scenario 4: Notice Found But Skipped
```
📄 Processing notice: zWP8ShX7KdKvMG4MATBq
⏭️ Skipping inactive notice
```
**Problem**: Status check failing
**Check**: What does the log say about status and isActive?

### Scenario 5: Error Parsing Notice
```
❌ Error parsing notice zWP8ShX7KdKvMG4MATBq: [error]
```
**Problem**: Field type mismatch or missing field
**Check**: Full error message in console

## Quick Fixes

### Fix 1: Check Firestore Rules
Make sure your Firestore rules allow reading notices:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /notices/{noticeId} {
      allow read: if request.auth != null;
    }
  }
}
```

### Fix 2: Verify Collection Name
In Firebase Console, verify the collection is named exactly "notices" (lowercase, plural).

### Fix 3: Check Notice Document
Your notice should have at least:
- `status: "published"` OR `isActive: true`
- `content: "some text"`
- `publishedAt` OR `createdAt` (Timestamp)

## Send Me Console Output

Copy and paste the ENTIRE console output when you tap the notification bell, starting from:
```
🔵 Loading notifications from Firestore...
```

This will help me see exactly what's happening!

## Alternative: Test with Simple Query

If nothing works, let's test if we can read from Firestore at all. Run this in your terminal:

```bash
flutter run -d ZA222LQT6V
```

Then in the app, try navigating to any other screen that fetches from Firestore (like Complaints or Events) to verify Firestore connection is working.

---
**Status**: ⚠️ DEBUGGING
**Next Step**: Check console logs and send output
