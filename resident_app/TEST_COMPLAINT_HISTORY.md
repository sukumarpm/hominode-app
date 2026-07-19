# Test Guide: Complaint History Tab Fix

## Quick Test Steps

### 1. Check Console Logs
Run the app and watch the console for status parsing logs:

```bash
flutter run -d ZA222LQT6V
```

When complaints load, you should see:
```
🔄 Real-time update received: X complaints
📊 Status string: "resolved"
📊 isResolved: null
📊 resolvedAt: null
✅ Mapped to: completed
✅ Final parsed status: ComplaintStatus.completed
```

### 2. Verify Existing Resolved Complaints

1. Open resident app
2. Navigate to Complaints & Requests
3. Tap on "History" tab
4. **Expected**: Should see the complaint that was marked as resolved in admin app

### 3. Test Real-Time Movement

**Setup:**
- Keep resident app open on Active tab
- Have admin app ready

**Steps:**
1. Note a complaint in Active tab
2. In admin app, mark that complaint as resolved
3. Watch resident app (don't touch it)
4. **Expected**: Complaint should disappear from Active tab within 1-2 seconds
5. Switch to History tab
6. **Expected**: Complaint should appear in History tab

### 4. Verify Status Badge

1. Open a resolved complaint from History tab
2. **Expected**: Status badge should show "Completed" (green)
3. **Expected**: Timeline should show all steps as completed (green dots)

### 5. Check Firestore Console

To understand what status value the admin app is using:

1. Open Firebase Console: https://console.firebase.google.com
2. Select project: `lyvo-app`
3. Go to Firestore Database
4. Open `complaints` collection
5. Find the resolved complaint (ID: `RiblyyvogCmYYzgtScrv8`)
6. Check these fields:
   - `status` - What value? (pending/resolved/completed/closed?)
   - `isResolved` - Does this field exist? (true/false?)
   - `resolvedAt` - Does this field exist? (timestamp?)

## Expected Results

### Active Tab Should Show:
- Complaints with `status: "pending"`
- Complaints with `status: "inProgress"` or `"in_progress"` or `"assigned"`
- Count: Pending + In Progress

### History Tab Should Show:
- Complaints with `status: "completed"`
- Complaints with `status: "resolved"`
- Complaints with `status: "closed"`
- Complaints with `isResolved: true`
- Complaints with `resolvedAt` field present
- Count: Completed

## Troubleshooting

### Issue: Resolved complaint still in Active tab

**Check Console Logs:**
```
📊 Status string: "???"
```

If you see an unexpected status value, the fix should handle it. If not, add it to the mapping.

**Check Firestore:**
- Verify the complaint document has been updated
- Check if `status` field exists
- Check if `isResolved` or `resolvedAt` fields exist

### Issue: No complaints in History tab

**Possible Causes:**
1. No complaints have been resolved yet
2. Admin app hasn't updated Firestore
3. Status field has unexpected value

**Solution:**
Check console logs to see what status values are being received.

### Issue: Complaint appears in both tabs

This shouldn't happen with the current logic. If it does:
1. Check console logs for the complaint ID
2. Verify filtering logic in `complaints_screen.dart`
3. Check if complaint is being duplicated in Firestore

## Status Value Reference

The resident app now recognizes these status values:

| Firestore Value | Mapped To | Tab |
|----------------|-----------|-----|
| `pending` | pending | Active |
| `open` | pending | Active |
| `null` | pending | Active |
| `inProgress` | inProgress | Active |
| `in_progress` | inProgress | Active |
| `in-progress` | inProgress | Active |
| `assigned` | inProgress | Active |
| `completed` | completed | History |
| `resolved` | completed | History |
| `closed` | completed | History |
| `isResolved: true` | completed | History |
| `resolvedAt: <any>` | completed | History |

## Success Criteria

✅ Resolved complaints appear in History tab
✅ Active complaints appear in Active tab
✅ Complaints move from Active to History when resolved
✅ Real-time updates work (no refresh needed)
✅ Status badges show correct colors
✅ Timeline shows correct completion status
✅ Console logs show correct status mapping

---
**Test Date**: February 20, 2026
**Tester**: [Your Name]
**Result**: [ ] Pass / [ ] Fail
**Notes**: 
