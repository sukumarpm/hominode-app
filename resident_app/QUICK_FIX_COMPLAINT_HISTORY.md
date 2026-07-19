# Quick Fix: Complaint History Tab

## Problem
✗ Resolved complaints not moving to History tab
✗ Staying in Active tab as "Pending"

## Solution
✓ Enhanced status parsing to support multiple values
✓ Now recognizes: `resolved`, `closed`, `isResolved: true`

## What Changed

### File: `lib/src/services/complaint_firestore_service.dart`

**Status Mapping:**
- `resolved` → `completed` ✅
- `closed` → `completed` ✅
- `isResolved: true` → `completed` ✅
- `resolvedAt: <any>` → `completed` ✅

## Test Now

```bash
flutter run -d ZA222LQT6V
```

1. Open Complaints & Requests
2. Tap History tab
3. **Expected**: Resolved complaints appear

## Console Logs

Look for:
```
📊 Status string: "resolved"
✅ Mapped to: completed
```

## Status Flow

```
Pending → Active Tab
In Progress → Active Tab
Completed/Resolved → History Tab ✅
```

---
**Status**: ✅ Fixed
**Files**: 1 modified
**Impact**: Complaints now move to History when resolved
