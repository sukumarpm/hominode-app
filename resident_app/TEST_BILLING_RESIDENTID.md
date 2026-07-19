# 🧪 Test Billing with residentId

## Quick Test

### 1. Check User Document
```dart
// Verify user has residentId
final doc = await FirebaseFirestore.instance
    .collection('users')
    .doc(userId)
    .get();

print('User residentId: ${doc.data()?['residentId']}');
```

**Expected**: Should print a residentId (e.g., "RES001")

---

### 2. Check Bill Documents
```dart
// Verify bills have matching residentId
final bills = await FirebaseFirestore.instance
    .collection('bills')
    .where('residentId', isEqualTo: 'RES001')
    .get();

print('Found ${bills.docs.length} bills');
for (var doc in bills.docs) {
  print('- ${doc.data()['month']}: ₹${doc.data()['amount']}');
}
```

**Expected**: Should find bills with matching residentId

---

### 3. Run the App
```bash
flutter run
```

**Expected Console Output**:
```
✅ BillService: Found residentId: RES001
📋 BillService: Fetching bills by residentId
   residentId: RES001
   ✓ Applied .where("residentId", isEqualTo: "RES001")
✅ BillService: Fetched 2 bills by residentId
📡 Streamed 2 bills by residentId
```

---

## If No Data Shows

### Issue 1: User Missing residentId
```
⚠️ BillService: No residentId assigned to user
```

**Fix**: Add residentId to user document
```dart
await FirebaseFirestore.instance
    .collection('users')
    .doc(userId)
    .update({'residentId': 'RES001'});
```

---

### Issue 2: Bills Missing residentId
```
✅ Found residentId: RES001
ℹ️ Fetched 0 bills by residentId
```

**Fix**: Add residentId to bill documents
```dart
await FirebaseFirestore.instance
    .collection('bills')
    .doc(billId)
    .update({'residentId': 'RES001'});
```

---

### Issue 3: residentId Mismatch
```
User residentId: RES001
Bill residentId: RES002  ← Mismatch!
```

**Fix**: Ensure exact match (case-sensitive)
```dart
// Update bill to match user
await FirebaseFirestore.instance
    .collection('bills')
    .doc(billId)
    .update({'residentId': 'RES001'});
```

---

## Test Credentials

```
Email: preethampriyatharson07@gmail.com
Password: DvgIDLEy
```

---

## Expected Firestore Structure

### User Document (users/{userId})
```json
{
  "name": "Preetham Priyatharson",
  "email": "preethampriyatharson07@gmail.com",
  "residentId": "RES001"  ← MUST HAVE
}
```

### Bill Document (bills/{billId})
```json
{
  "residentId": "RES001",  ← MUST MATCH USER
  "amount": 850,
  "status": "pending",
  "month": "January 2025"
}
```

---

## Success Checklist

- [ ] User document has `residentId` field
- [ ] Bill documents have `residentId` field
- [ ] residentId values match exactly (case-sensitive)
- [ ] Console shows "Found residentId: XXX"
- [ ] Console shows "Fetched X bills by residentId"
- [ ] Billing screen displays bills

---

## Quick Commands

### Check in Firebase Console
1. Open Firebase Console
2. Go to Firestore Database
3. Check `users/{userId}` has `residentId`
4. Check `bills` collection has matching `residentId`

### Test Query in Firebase Console
1. Select `bills` collection
2. Add filter: `residentId == RES001`
3. Should return bills

---

## Status

✅ Implementation complete
🧪 Ready for testing
📋 Verify Firestore data structure
