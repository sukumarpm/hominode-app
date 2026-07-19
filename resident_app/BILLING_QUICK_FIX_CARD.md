# Billing Quick Fix Card

## Run & Check

```bash
cd resident_app
flutter run
```

Login: `7010678124` / `121456`
Navigate: Bills tab
Watch: Console output

---

## Console Patterns & Fixes

### ✅ Pattern: Success
```
✅ Found flat ID: 1202
   Query result: 1 documents
✅ Found current bill
```
**Action**: None - working!

---

### ❌ Pattern: No FlatId
```
⚠️ No flat assigned to user
```
**Fix**: Add `flatId: "1202"` to user document

---

### ❌ Pattern: Mismatch
```
✅ Found flat ID: 1402
   Query result: 0 documents
   Total bills for flat 1402: 0
```
**Fix**: Change user's flatId to "1202" OR bill's flatId to "1402"

---

### ❌ Pattern: Wrong Status
```
   Query result: 0 documents
   Total bills for flat 1202: 1
   status: paid
```
**Fix**: Change bill status to "pending"

---

## Firebase Console Fixes

### Add FlatId to User
```
users → <your user> → Edit
Add: flatId (string) = "1202"
Add: flatLabel (string) = "1202"
```

### Change Bill Status
```
bills → dKoTQtdVuiNkBqLWZmQP → Edit
Change: status = "pending"
```

---

**Docs**: `BILLING_ISSUE_RESOLUTION.md`
