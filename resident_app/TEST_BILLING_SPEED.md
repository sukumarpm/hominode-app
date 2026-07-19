# Test Billing Speed - Quick Guide

## Run the App

```bash
cd resident_app
flutter run
```

## Test Scenarios

### Test 1: First Load (Fresh Data)
```
1. Login: 7010678124 / 121456
2. Navigate to Bills tab
3. Watch console output
4. Note the loading time

Expected Console:
🔍 BillService: Fetching flat for user: <userId>
✅ BillService: Found flat ID: 1202 (cached)
📋 BillService: Fetching pending bill for flat: 1202
✅ BillService: Found current bill (cached)
📋 Fetching payment history for flat: 1202
✅ Fetched X payment history records (cached)

Expected Time: ~800ms
```

### Test 2: Cached Load (Super Fast)
```
1. Navigate to Home tab
2. Navigate back to Bills tab (within 30 seconds)
3. Watch console output
4. Note the instant display

Expected Console:
⚡ BillService: Returning cached current bill
⚡ BillService: Returning cached payment history

Expected Time: ~50ms (instant!)
```

### Test 3: Cache Expiry
```
1. Stay on Bills tab
2. Wait 31 seconds
3. Navigate away and back
4. Watch console output

Expected Console:
📋 BillService: Fetching pending bill...
(Fresh data fetched)

Expected Time: ~800ms
```

### Test 4: After Payment
```
1. Pay a bill
2. Watch console output
3. Verify data refreshes

Expected Console:
✅ Bill paid successfully: <billId> (cache cleared)
📋 BillService: Fetching pending bill...
(Fresh data fetched automatically)

Expected Time: ~800ms
```

---

## Performance Indicators

### ⚡ Fast (Cached)
```
Console shows:
⚡ Returning cached current bill
⚡ Returning cached payment history

Screen:
- Data appears instantly
- No loading spinner
```

### 🔄 Fresh Fetch
```
Console shows:
📋 Fetching pending bill...
✅ Found current bill (cached)

Screen:
- Brief loading spinner
- Data appears in ~800ms
```

---

## What to Look For

### Good Performance ✅
- First load: < 1 second
- Cached load: Instant (< 100ms)
- Smooth transitions
- No lag or freezing

### Issues to Report ❌
- First load: > 2 seconds
- Cached load: > 500ms
- Screen freezes
- Data doesn't display

---

## Console Log Guide

| Log Message | Meaning | Speed |
|-------------|---------|-------|
| `⚡ Returning cached` | Using cache | Instant |
| `📋 Fetching pending bill` | Fresh fetch | ~800ms |
| `✅ Found current bill (cached)` | Data cached | Fast |
| `(cache cleared)` | Cache invalidated | Next load fresh |

---

## Quick Commands

### Run App
```bash
cd resident_app
flutter run
```

### Hot Reload (after code changes)
```
Press 'r' in terminal
```

### Hot Restart
```
Press 'R' in terminal
```

---

**Expected Result**: Bills load instantly on cached loads, fast on fresh loads
**Status**: Ready for testing
