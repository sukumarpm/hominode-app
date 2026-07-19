# Billing Troubleshooting Flowchart

## Start Here: Run the App

```
1. Run: flutter run
2. Login: 7010678124 / 121456
3. Tap: Bills tab
4. Watch: Console output
```

---

## Decision Tree

```
┌─────────────────────────────────────────────────────────────┐
│ What do you see in the console?                             │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
        ┌───────────────────┴───────────────────┐
        │                                       │
        ▼                                       ▼
┌───────────────────┐                  ┌───────────────────┐
│ ❌ No user        │                  │ ✅ Found flat ID  │
│    logged in      │                  │    1202           │
└───────────────────┘                  └───────────────────┘
        │                                       │
        ▼                                       ▼
   LOGIN FIRST                         ┌───────────────────┐
   Phone: 7010678124                   │ Query result:     │
   Password: 121456                    │ ? documents       │
                                       └───────────────────┘
                                                │
                    ┌───────────────────────────┼───────────────────────────┐
                    │                           │                           │
                    ▼                           ▼                           ▼
            ┌───────────────┐          ┌───────────────┐          ┌───────────────┐
            │ 0 documents   │          │ 1 document    │          │ Multiple docs │
            └───────────────┘          └───────────────┘          └───────────────┘
                    │                           │                           │
                    ▼                           ▼                           ▼
            ┌───────────────┐          ┌───────────────┐          ┌───────────────┐
            │ NO BILLS      │          │ ✅ SUCCESS!   │          │ ✅ SUCCESS!   │
            │ FOUND         │          │ Bill displays │          │ Shows latest  │
            └───────────────┘          └───────────────┘          └───────────────┘
                    │
                    ▼
        ┌───────────────────────┐
        │ Check Debug Output:   │
        │ "Total bills for      │
        │  flat 1202: ?"        │
        └───────────────────────┘
                    │
        ┌───────────┴───────────┐
        │                       │
        ▼                       ▼
┌───────────────┐       ┌───────────────┐
│ Total: 0      │       │ Total: 1+     │
└───────────────┘       └───────────────┘
        │                       │
        ▼                       ▼
┌───────────────┐       ┌───────────────┐
│ ISSUE 1:      │       │ ISSUE 2:      │
│ FlatId        │       │ Bill Status   │
│ Mismatch      │       │ Not "pending" │
└───────────────┘       └───────────────┘
```

---

## Issue 1: FlatId Mismatch

### Symptoms
```
Console shows:
✅ Found flat ID: 1402
📋 Fetching bills for flat: 1402
   Query result: 0 documents
   Debug: Total bills for flat 1402: 0
```

But your bill has `flatId: "1202"`

### Root Cause
User's flatId ≠ Bill's flatId

### Fix
Choose ONE option:

**Option A: Update User's FlatId to 1202**
```
Firebase Console → users → <your user> → Edit
Change: flatId from "1402" to "1202"
Change: flatLabel from "1402" to "1202"
```

**Option B: Update Bill's FlatId to 1402**
```
Firebase Console → bills → dKoTQtdVuiNkBqLWZmQP → Edit
Change: flatId from "1202" to "1402"
Change: flatLabel from "1202" to "1402"
```

---

## Issue 2: Bill Status Not "pending"

### Symptoms
```
Console shows:
✅ Found flat ID: 1202
📋 Fetching bills for flat: 1202
   Query result: 0 documents
   Debug: Total bills for flat 1202: 1
   Debug: Bill statuses:
      - dKoTQtdVuiNkBqLWZmQP:
         status: paid  ← Wrong!
```

### Root Cause
Bill status is not "pending"

### Fix
```
Firebase Console → bills → dKoTQtdVuiNkBqLWZmQP → Edit
Change: status to "pending" (lowercase)
```

---

## Issue 3: No FlatId in User

### Symptoms
```
Console shows:
🔍 Fetching flat for user: <userId>
⚠️ No flat assigned to user
   User data: [uid, name, email, phone, ...]
❌ Cannot fetch bills - No flat assigned
```

### Root Cause
User document missing `flatId` field

### Fix
```
Firebase Console → users → <your user> → Edit
Add field: flatId (string) = "1202"
Add field: flatLabel (string) = "1202"
```

---

## Issue 4: No User Logged In

### Symptoms
```
Console shows:
❌ No user logged in
```

### Root Cause
Not logged in or session expired

### Fix
```
1. Restart app
2. Login with:
   Phone: 7010678124
   Password: 121456
3. Navigate to Bills tab
```

---

## Verification Steps

After applying fix:

### Step 1: Restart App
```bash
# Stop app (Ctrl+C)
# Run again
flutter run
```

### Step 2: Login
```
Phone: 7010678124
Password: 121456
```

### Step 3: Check Console
```
Expected output:
✅ Found flat ID: 1202
📋 Fetching bills for flat: 1202
   Query result: 1 documents
✅ Found current bill: dKoTQtdVuiNkBqLWZmQP
   Amount: 6000
   Status: pending
```

### Step 4: Check Screen
```
Expected display:
┌─────────────────────────────┐
│ February Bill    [Pending]  │
│ ₹6000                       │
│ Due Date: Feb 28, 2026      │
│ [Pay Now]                   │
└─────────────────────────────┘
```

---

## Quick Reference

### Console Log Patterns

| Pattern | Meaning | Action |
|---------|---------|--------|
| `❌ No user logged in` | Not logged in | Login |
| `⚠️ No flat assigned` | Missing flatId | Add flatId to user |
| `Query result: 0` + `Total: 0` | FlatId mismatch | Update flatId |
| `Query result: 0` + `Total: 1+` | Wrong status | Change to "pending" |
| `Query result: 1` | ✅ Success | Should display |

### Data Verification

| Field | Location | Expected Value | Type |
|-------|----------|----------------|------|
| flatId | users doc | "1202" | string |
| flatId | bills doc | "1202" | string |
| status | bills doc | "pending" | string |
| amount | bills doc | 6000 | number |

---

## Still Not Working?

### Run Debug Script
```bash
cd resident_app
flutter run lib/test_billing_debug.dart
```

This will show:
- ✅ Current user UID
- ✅ User's flatId
- ✅ All bills for that flat
- ✅ Each bill's details
- ✅ Pending vs paid bills

### Check Firestore Rules
```
Firebase Console → Firestore Database → Rules

Ensure users can read bills:
match /bills/{billId} {
  allow read: if request.auth != null;
}
```

---

## Summary

1. ✅ Run app and check console
2. ✅ Match console output to patterns above
3. ✅ Apply corresponding fix
4. ✅ Restart and verify

The console logs are your guide - they tell you exactly what's wrong!

---

**Status**: Ready for Troubleshooting
**Priority**: HIGH
**Next**: Run app and follow flowchart
