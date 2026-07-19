# Complaint Status - Debug Guide

## Problem
Status not updating even though staff is assigned in Firestore.

## Debug Logging Added

I've added comprehensive logging to track exactly what's happening with the status field.

### What to Check

#### 1. Run the App and Check Console

When you open the Complaints screen, you'll see logs like this:

```
🔄 Setting up real-time complaint updates...
🔍 Parsing complaint: dAONdk0i0cHokqz8w3ma
📊 Raw status from Firestore: pending
📊 Assigned to: preetham
📊 Staff ID: staff123
📊 Status string: "pending"
  Comparing: "pending" with "pending"
✅ Parsed status: ComplaintStatus.pending
🎯 Final complaint status: ComplaintStatus.pending
---
🔄 Real-time update received: 1 complaints
  - dAONdk0i0cHokqz8w3ma: ComplaintStatus.pending (preetham)
✅ UI updated with 1 complaints
```

#### 2. What the Logs Tell You

**If you see:**
```
📊 Raw status from Firestore: pending
```
**Problem**: Firestore document has `status: "pending"` even though staff is assigned.
**Solution**: Update Firestore document to `status: "inProgress"`

**If you see:**
```
📊 Raw status from Firestore: inProgress
✅ Parsed status: ComplaintStatus.inProgress
```
**Good**: Status is correct in Firestore and parsed correctly.

**If you see:**
```
⚠️ Status not found, defaulting to pending
```
**Problem**: Status value in Firestore doesn't match enum values.
**Solution**: Check Firestore - status must be exactly "pending", "inProgress", or "completed"

### 3. Check Firestore Document

The logs will show you exactly what's in Firestore:

```
📊 Raw status from Firestore: [value from database]
📊 Assigned to: [staff name]
📊 Staff ID: [staff id]
```

Compare this with what you expect.

## Expected Flow

### When Staff is Assigned

**Firestore should have:**
```json
{
  "status": "inProgress",  ← Must be this
  "assignedTo": "preetham",
  "assignedStaffId": "staff123"
}
```

**Console should show:**
```
📊 Raw status from Firestore: inProgress
✅ Parsed status: ComplaintStatus.inProgress
🎯 Final complaint status: ComplaintStatus.inProgress
  - dAONdk0i0cHokqz8w3ma: ComplaintStatus.inProgress (preetham)
```

**App should show:**
- 🟠 Orange "In Progress" badge
- Staff details card
- Timeline with 4 steps

### When Status is Wrong

**Firestore has:**
```json
{
  "status": "pending",  ← Wrong!
  "assignedTo": "preetham",
  "assignedStaffId": "staff123"
}
```

**Console shows:**
```
📊 Raw status from Firestore: pending
✅ Parsed status: ComplaintStatus.pending
🎯 Final complaint status: ComplaintStatus.pending
  - dAONdk0i0cHokqz8w3ma: ComplaintStatus.pending (preetham)
```

**App shows:**
- 🔴 Red "Pending" badge
- No staff details
- "Waiting for staff assignment"

## How to Fix

### Option 1: Update Firestore Manually

1. Open Firebase Console
2. Go to Firestore Database
3. Find complaint document
4. Change `status` from `"pending"` to `"inProgress"`
5. Save
6. Watch console logs - should see real-time update:

```
🔄 Real-time update received: 1 complaints
📊 Raw status from Firestore: inProgress
✅ Parsed status: ComplaintStatus.inProgress
  - dAONdk0i0cHokqz8w3ma: ComplaintStatus.inProgress (preetham)
✅ UI updated with 1 complaints
```

### Option 2: Fix Admin Panel

Update admin panel to set status when assigning:

```dart
await FirebaseFirestore.instance
    .collection('complaints')
    .doc(complaintId)
    .update({
  'assignedTo': staffName,
  'assignedStaffId': staffId,
  'status': 'inProgress',  // ← Add this
});
```

## Real-time Updates

The app now uses real-time updates, so:
- ✅ No need to pull to refresh
- ✅ Changes appear automatically
- ✅ Status updates instantly when Firestore changes

### Test Real-time Updates

1. Open app on Complaints screen
2. Open Firebase Console in browser
3. Change status in Firestore
4. Watch console logs in app
5. See UI update automatically!

## Debugging Steps

### Step 1: Check Console Logs

Look for:
```
📊 Raw status from Firestore: [what value?]
```

This tells you exactly what's in Firestore.

### Step 2: Verify Firestore

Open Firebase Console and check:
- Does `status` field exist?
- What is its value?
- Is it exactly "pending", "inProgress", or "completed"?

### Step 3: Check Enum Matching

The status string must match enum names exactly:

| Firestore Value | Enum Name | Display |
|----------------|-----------|---------|
| `"pending"` | `ComplaintStatus.pending` | Pending (Red) |
| `"inProgress"` | `ComplaintStatus.inProgress` | In Progress (Orange) |
| `"completed"` | `ComplaintStatus.completed` | Completed (Green) |

### Step 4: Test Update

1. Change status in Firestore
2. Check console logs
3. Verify UI updates

## Common Issues

### Issue 1: Status is "in_progress" (with underscore)

**Problem**: Firestore has `"in_progress"` but enum is `"inProgress"`
**Solution**: Change to `"inProgress"` (camelCase)

### Issue 2: Status is "In Progress" (with space)

**Problem**: Firestore has `"In Progress"` but enum is `"inProgress"`
**Solution**: Change to `"inProgress"` (no spaces, camelCase)

### Issue 3: Status field missing

**Problem**: Firestore document doesn't have `status` field
**Solution**: Add `status: "inProgress"` to document

### Issue 4: Status is null

**Problem**: Firestore has `status: null`
**Solution**: Set `status: "inProgress"`

## Console Log Examples

### Correct (Working)
```
🔍 Parsing complaint: dAONdk0i0cHokqz8w3ma
📊 Raw status from Firestore: inProgress
📊 Assigned to: preetham
📊 Staff ID: staff123
📊 Status string: "inProgress"
  Comparing: "pending" with "inProgress"
  Comparing: "inProgress" with "inProgress"
✅ Parsed status: ComplaintStatus.inProgress
🎯 Final complaint status: ComplaintStatus.inProgress
```

### Incorrect (Not Working)
```
🔍 Parsing complaint: dAONdk0i0cHokqz8w3ma
📊 Raw status from Firestore: pending
📊 Assigned to: preetham
📊 Staff ID: staff123
📊 Status string: "pending"
  Comparing: "pending" with "pending"
✅ Parsed status: ComplaintStatus.pending
🎯 Final complaint status: ComplaintStatus.pending
```

## Quick Test

### Test 1: Check Current Status

1. Open app
2. Look at console logs
3. Find line: `📊 Raw status from Firestore:`
4. What does it say?

### Test 2: Update and Verify

1. Change status in Firestore to "inProgress"
2. Watch console logs
3. Should see:
   ```
   🔄 Real-time update received
   📊 Raw status from Firestore: inProgress
   ✅ Parsed status: ComplaintStatus.inProgress
   ```
4. UI should update automatically

## Summary

The debug logs will tell you:
1. What status value is in Firestore
2. How it's being parsed
3. What the final complaint status is
4. When real-time updates occur

Use these logs to identify exactly where the problem is:
- If "Raw status" is wrong → Fix Firestore
- If "Parsed status" is wrong → Check enum matching
- If "Final status" is wrong → Check complaint model

The app code is correct - it just needs the right data from Firestore!
