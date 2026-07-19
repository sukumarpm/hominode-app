# Test Flexible Matching - Quick Guide

## What Changed

The billing service now fetches bills if **ANY** of these match:
- flatId
- residentId
- residentName

---

## Test Scenarios

### Scenario 1: Match by flatId
```
Setup in Firebase Console:

User Document (users collection):
  flatId: "1202"
  residentId: "RES68429"
  name: "Preetham"

Bill Document (bills collection):
  flatId: "1202"  ← This matches!
  residentId: "DIFFERENT"
  residentName: "Different Name"
  status: "pending"
  amount: 6000

Expected Result:
✅ Bill displays
Console shows: "✓ Matched by flatId: 1202"
```

### Scenario 2: Match by residentId
```
Setup in Firebase Console:

User Document:
  flatId: "DIFFERENT"
  residentId: "RES68429"
  name: "Preetham"

Bill Document:
  flatId: "DIFFERENT"
  residentId: "RES68429"  ← This matches!
  residentName: "Different Name"
  status: "pending"
  amount: 6000

Expected Result:
✅ Bill displays
Console shows: "✓ Matched by residentId: RES68429"
```

### Scenario 3: Match by residentName
```
Setup in Firebase Console:

User Document:
  flatId: "DIFFERENT"
  residentId: "DIFFERENT"
  name: "Preetham"

Bill Document:
  flatId: "DIFFERENT"
  residentId: "DIFFERENT"
  residentName: "Preetham"  ← This matches!
  status: "pending"
  amount: 6000

Expected Result:
✅ Bill displays
Console shows: "✓ Matched by residentName: Preetham"
```

### Scenario 4: Multiple Matches
```
Setup in Firebase Console:

User Document:
  flatId: "1202"
  residentId: "RES68429"
  name: "Preetham"

Bill Document:
  flatId: "1202"  ← Matches!
  residentId: "RES68429"  ← Matches!
  residentName: "Preetham"  ← Matches!
  status: "pending"
  amount: 6000

Expected Result:
✅ Bill displays
Console shows all three matches
```

---

## Quick Test

### Step 1: Run App
```bash
cd resident_app
flutter run
```

### Step 2: Login
```
Phone: 7010678124
Password: 121456
```

### Step 3: Navigate to Bills Tab

### Step 4: Check Console Output
```
Expected logs:
📋 BillService: Fetching pending bill with identifiers:
   flatId: 1202
   residentId: RES68429
   residentName: Preetham
   ✓ Matched by flatId: 1202
✅ BillService: Found current bill (cached)
```

---

## Console Log Patterns

### Success - Matched by flatId
```
   ✓ Matched by flatId: 1202
✅ BillService: Found current bill
```

### Success - Matched by residentId
```
   ✓ Matched by residentId: RES68429
✅ BillService: Found current bill
```

### Success - Matched by residentName
```
   ✓ Matched by residentName: Preetham
✅ BillService: Found current bill
```

### No Match
```
ℹ️ BillService: No pending bills found
```

---

## Verify in Firebase Console

### Check User Document
```
Firebase Console → Firestore → users → <your user>

Should have:
✅ flatId: "1202"
✅ residentId: "RES68429"
✅ name: "Preetham"
```

### Check Bill Document
```
Firebase Console → Firestore → bills → <bill id>

Should have at least ONE of:
✅ flatId: "1202" (matches user.flatId)
OR
✅ residentId: "RES68429" (matches user.residentId)
OR
✅ residentName: "Preetham" (matches user.name)
```

---

## Summary

The system now works if ANY identifier matches:
- ✅ flatId matches → Bill fetched
- ✅ residentId matches → Bill fetched
- ✅ residentName matches → Bill fetched
- ✅ Multiple match → Bill fetched
- ❌ None match → No bills found

**Status**: Ready for testing
**Flexibility**: High
**Backward Compatible**: Yes
