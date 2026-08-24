# Mark Exit - Debug Guide

## How to Test and Check Logs

### Step 1: Open Active Tab
1. Go to Visitor Management
2. Switch to Active tab
3. Note the visitor count (e.g., "Active: 1")

### Step 2: Click Mark Exit
1. Find a visitor in Active tab
2. Click "Mark Exit" button
3. Watch for success message: "bot bala marked as exited"

### Step 3: Check Logs
Open your terminal/logcat and look for these logs:

```
I/flutter: VisitorService: Checking out visitor - [visitor_id]
I/flutter: VisitorService: Visitor checked out successfully - [visitor_id]
I/flutter: VisitorService: Verified departure field - Timestamp(...)
I/flutter: VisitorService: Received 0 active visitors  ← Should be 0 now
I/flutter: VisitorService: Received 1 history visitors  ← Should increment
```

### Step 4: Verify Active Tab
1. Stay on Active tab
2. Wait 1-2 seconds
3. Visitor should disappear
4. Count should decrement

### Step 5: Check History Tab
1. Switch to History tab
2. Visitor should appear
3. Count should increment
4. Entry and exit times should be shown

---

## Expected Behavior

### Immediately After "Mark Exit"
```
✅ Success message appears
✅ Firestore update completes
✅ Logs show "Visitor checked out successfully"
```

### Within 1-2 Seconds
```
✅ Active stream receives update
✅ Visitor disappears from Active tab
✅ Active count decrements
✅ History stream receives update
✅ Visitor appears in History tab
✅ History count increments
```

---

## If Visitor Still Shows in Active

### Check Logs For:
```
I/flutter: VisitorService: Received 1 active visitors
I/flutter:   - Visitor [id]: departure = null  ← Should NOT be null!
```

If you see `departure = null` after clicking "Mark Exit", it means:
- Firestore update failed
- OR you're looking at cached data

### Solution 1: Check Firestore Console
1. Open Firebase Console
2. Go to Firestore Database
3. Find the visitor document
4. Check if `departure` field exists and has a timestamp

### Solution 2: Force Refresh
Try switching tabs:
1. Go to Pending tab
2. Wait 1 second
3. Go back to Active tab
4. Visitor should be gone

---

## Common Issues

### Issue 1: Visitor Still in Active After 5+ Seconds
**Cause**: Firestore update failed or query cache issue
**Solution**: Check Firestore console to verify `departure` field is set

### Issue 2: Visitor in Both Active and History
**Cause**: Impossible with current queries - one excludes `departure`, other requires it
**Solution**: Clear app cache and restart

### Issue 3: Visitor Disappears but Count Doesn't Update
**Cause**: State update issue
**Solution**: Already fixed with `WidgetsBinding.instance.addPostFrameCallback`

---

## Test Commands

### View Logs (Windows)
```powershell
flutter run -d ZA222LQT6V
# Watch the console output
```

### Filter Logs for Visitor Service
```powershell
# In another terminal
adb logcat | findstr "VisitorService"
```

---

## What to Report

If the issue persists, please provide:

1. **Logs** from the moment you click "Mark Exit"
2. **Screenshot** of Active tab before clicking
3. **Screenshot** of Active tab 5 seconds after clicking
4. **Screenshot** of History tab after clicking
5. **Firestore Console** screenshot showing the visitor document

This will help identify if it's:
- A Firestore update issue
- A query caching issue
- A UI refresh issue
- A stream subscription issue
