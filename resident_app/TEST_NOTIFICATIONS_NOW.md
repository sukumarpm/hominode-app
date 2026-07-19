# Test Notifications Now - Quick Guide

## What Was Fixed

Fixed two critical issues preventing notifications from displaying correctly:

1. **Type Field**: Admin app uses `type` field, resident app was reading `category` field
2. **Priority Field**: Admin app uses `priority: "urgent"`, resident app was checking for `"high"` only

## Test Steps

### 1. Stop and Restart App

```bash
# In your terminal where the app is running:
# Press 'q' to quit

# Then run again:
flutter run -d ZA222LQT6V
```

**IMPORTANT**: Must be a FULL restart, not hot reload (R) or hot restart (r)!

### 2. Navigate to Notifications

1. App opens on Dashboard/Home screen
2. Look at top right corner
3. Tap the bell icon 🔔

### 3. What You Should See

**All (2) tab should show:**

```
┌─────────────────────────────────────────┐
│ 🔧  my jkjkj              [URGENT]     │
│     nnbbnnnm                            │
│     5m ago                              │
└─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│ 🔔  Notice                              │
│     ewgdnfnnnf                          │
│     10m ago                             │
└─────────────────────────────────────────┘
```

### 4. Verify Details

For "my jkjkj" notice:
- ✅ Orange wrench icon (maintenance type)
- ✅ Red "URGENT" badge
- ✅ Title: "my jkjkj"
- ✅ Content: "nnbbnnnm"

For second notice:
- ✅ Blue bell icon (general/no type)
- ✅ No badge (medium priority)
- ✅ Title: "Notice"
- ✅ Content: "ewgdnfnnnf"

### 5. Test Interaction

1. Tap on "my jkjkj" notice
2. Should open dialog with full content
3. Notice background changes from blue to white (marked as read)
4. Check "Read (1)" tab - should show the notice you tapped

## Console Output to Check

When you tap the bell icon, look for these logs:

```
========================================
🔵 NOTIFICATIONS SCREEN: Loading notifications
========================================
🔵 Fetching notices from Firestore...
🔵 Found 2 total notices in Firestore
📄 Processing notice: Dsr9719ZE3BszQ2QeiGFwV
   status: published
   category/type: maintenance          ← Should show "maintenance"
✅ Added notice: my jkjkj
📄 Processing notice: zWP8ShX7KdKvMG4MATBq
   status: published
   category/type: general              ← Should show "general"
✅ Added notice: Notice
✅ Returning 2 notices
✅ UI updated with 2 notifications
========================================
```

## If Still Not Showing

### Check 1: Did you do FULL restart?
- Not hot reload (R)
- Not hot restart (r)
- Must quit (q) and run again

### Check 2: Are you logged in?
- Make sure you're logged in with: `preethampriyatharson07@gmail.com`
- Password: `teste123`

### Check 3: Check console for errors
Look for any red error messages in the console

### Check 4: Firestore Rules
In Firebase Console, check that rules allow reading notices:
```javascript
match /notices/{noticeId} {
  allow read: if request.auth != null;
}
```

## What Changed in Code

### File 1: `lib/src/services/notice_firestore_service.dart`
- Now reads `type` field first, then falls back to `category`
- Added logging to show which category/type value was found

### File 2: `lib/src/screens/notifications_screen.dart`
- URGENT badge now shows for both `priority: "high"` AND `priority: "urgent"`

## Expected Result

✅ 2 notifications visible
✅ "my jkjkj" shows orange wrench icon
✅ "my jkjkj" shows red URGENT badge
✅ Both notices show title and content
✅ Tap to view full content works
✅ Read/unread tracking works

---
**Action**: Stop app (q), then run again
**Navigate**: Home → Bell icon (top right)
**Expected**: 2 notifications with proper icons and badges

