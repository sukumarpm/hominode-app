# Quick Fix: Resident Data Not Showing

## Problem

"No registered residents found" in Assign Resident modal

## Root Cause

The system only shows **unassigned** residents (residents without a flat).

## Quick Solution

### Option 1: Create New Unassigned Resident

1. Open Firebase Console
2. Go to Firestore → `users` collection
3. Click "Add document"
4. Add these fields:

```
residentId: "RES%17"
name: "Test User"
phone: "+91 9876543210"
email: "test@example.com"
role: "resident"
flatId: null          ← IMPORTANT: Must be null
flatLabel: null       ← IMPORTANT: Must be null
status: "active"
familyMembers: 1
```

5. Save
6. Refresh the app

### Option 2: Unassign Existing Resident

1. Open Firebase Console
2. Go to Firestore → `users` collection
3. Find a resident (e.g., sukumar)
4. Edit the document
5. Set `flatId` to `null`
6. Set `flatLabel` to `null`
7. Save
8. Refresh the app

## Verification

Run the app and check console:

```
✅ Available residents: 1
   - Test User (+91 9876543210) - Status: active
```

If you see this, the resident will appear in the modal!

## Why This Happens

The "Assign Resident" modal is designed to show only **available** (unassigned) residents. This prevents assigning the same resident to multiple flats.

**Logic**:
- `flatId: null` → Available (shows in modal)
- `flatId: "t401"` → Assigned (does NOT show in modal)

## For Billing

Billing works differently - it needs residents **with** flatId:

```javascript
// For Assign Modal (unassigned)
{
  residentId: "RES%17",
  name: "Test User",
  flatId: null,        ← Must be null
  role: "resident"
}

// For Billing (assigned)
{
  residentId: "RES%16",
  name: "sukumar",
  flatId: "t401",      ← Must have value
  role: "resident"
}
```

## Summary

✅ Assign Modal: Shows residents with `flatId: null`
✅ Billing: Uses residents with `flatId: "t401"`
✅ Both: Fetch `residentId` from `data['residentId']` field

