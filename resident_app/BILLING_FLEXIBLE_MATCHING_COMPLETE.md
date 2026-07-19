# Billing - Flexible Matching System ✅

## Overview

The billing service now supports **flexible matching** - it can fetch bills if ANY of these fields match:
- flatId
- residentId  
- residentName

This ensures bills are fetched correctly regardless of which identifier is available in the Firestore data.

---

## How It Works

### Step 1: Get User Identifiers
```dart
_getUserIdentifiers()
    ↓
Query: users collection
    WHERE document ID == current user UID
    ↓
Extract:
  - flatId
  - residentId
  - residentName
```

### Step 2: Fetch Bills with Flexible Matching
```dart
getCurrentBill()
    ↓
Query: bills collection
    WHERE status == "pending"
    ↓
Filter results:
  IF bill.flatId == user.flatId → MATCH ✓
  OR bill.residentId == user.residentId → MATCH ✓
  OR bill.residentName == user.residentName → MATCH ✓
    ↓
Return: Matching bills
```

---

## Matching Logic

### Priority Order
The service checks for matches in this order:

1. **flatId** (Primary) - Most reliable identifier
2. **residentId** (Secondary) - Unique resident identifier
3. **residentName** (Tertiary) - Name-based matching

### Match Examples

#### Example 1: Match by flatId
```
User Document:
  flatId: "1202"
  residentId: "RES68429"
  name: "Preetham"

Bill Document:
  flatId: "1202"  ← MATCH! ✓
  residentId: "RES99999"
  residentName: "Someone Else"

Result: Bill fetched (matched by flatId)
```

#### Example 2: Match by residentId
```
User Document:
  flatId: null
  residentId: "RES68429"
  name: "Preetham"

Bill Document:
  flatId: "9999"
  residentId: "RES68429"  ← MATCH! ✓
  residentName: "Someone Else"

Result: Bill fetched (matched by residentId)
```

#### Example 3: Match by residentName
```
User Document:
  flatId: null
  residentId: null
  name: "Preetham"

Bill Document:
  flatId: "9999"
  residentId: "RES99999"
  residentName: "Preetham"  ← MATCH! ✓

Result: Bill fetched (matched by residentName)
```

#### Example 4: Multiple Matches
```
User Document:
  flatId: "1202"
  residentId: "RES68429"
  name: "Preetham"

Bill Document:
  flatId: "1202"  ← MATCH! ✓
  residentId: "RES68429"  ← MATCH! ✓
  residentName: "Preetham"  ← MATCH! ✓

Result: Bill fetched (matched by all three)
```

#### Example 5: No Match
```
User Document:
  flatId: "1202"
  residentId: "RES68429"
  name: "Preetham"

Bill Document:
  flatId: "9999"  ← No match
  residentId: "RES99999"  ← No match
  residentName: "Someone Else"  ← No match

Result: Bill NOT fetched
```

---

## Code Implementation

### Get User Identifiers
```dart
Future<Map<String, String?>> _getUserIdentifiers() async {
  final userData = await _userDataService.getCurrentUserData();
  
  return {
    'flatId': userData['flatId'] as String?,
    'residentId': userData['residentId'] as String?,
    'residentName': userData['name'] as String?,
  };
}
```

### Flexible Matching Filter
```dart
final matchingBills = snapshot.docs.where((doc) {
  final data = doc.data();
  
  // Match by flatId
  if (identifiers['flatId'] != null && 
      data['flatId'] == identifiers['flatId']) {
    return true;
  }
  
  // Match by residentId
  if (identifiers['residentId'] != null && 
      data['residentId'] == identifiers['residentId']) {
    return true;
  }
  
  // Match by residentName
  if (identifiers['residentName'] != null && 
      data['residentName'] == identifiers['residentName']) {
    return true;
  }
  
  return false;
}).toList();
```

---

## Console Logs

### With All Identifiers
```
📋 BillService: Fetching pending bill with identifiers:
   flatId: 1202
   residentId: RES68429
   residentName: Preetham
   ✓ Matched by flatId: 1202
✅ BillService: Found current bill (cached)
   Amount: 6000
   Month: February
```

### With Partial Identifiers
```
📋 BillService: Fetching pending bill with identifiers:
   flatId: null
   residentId: RES68429
   residentName: Preetham
   ✓ Matched by residentId: RES68429
✅ BillService: Found current bill (cached)
   Amount: 6000
   Month: February
```

### No Match Found
```
📋 BillService: Fetching pending bill with identifiers:
   flatId: 1202
   residentId: RES68429
   residentName: Preetham
ℹ️ BillService: No pending bills found
```

---

## Firestore Data Structure

### User Document (users collection)
```
users/
  {userId}/
    flatId: "1202"           ← Used for matching
    residentId: "RES68429"   ← Used for matching
    name: "Preetham"         ← Used for matching (as residentName)
    phone: "7010678124"
    email: "..."
```

### Bill Document (bills collection)
```
bills/
  {billId}/
    flatId: "1202"           ← Matched against user.flatId
    residentId: "RES68429"   ← Matched against user.residentId
    residentName: "Preetham" ← Matched against user.name
    amount: 6000
    status: "pending"
    month: "February"
    chargeBreakdown: { ... }
```

---

## Benefits

### 1. Flexibility
- Works with any combination of identifiers
- No single point of failure
- Handles missing or incomplete data

### 2. Reliability
- Multiple fallback options
- Increases chance of successful match
- Reduces "No bills found" errors

### 3. Data Migration Friendly
- Works with old data (only flatId)
- Works with new data (all identifiers)
- No breaking changes required

### 4. Multi-Tenant Support
- Same flat, multiple residents
- Different flats, same resident
- Flexible data models

---

## Testing Scenarios

### Test 1: All Identifiers Present
```
User:
  flatId: "1202"
  residentId: "RES68429"
  name: "Preetham"

Bill:
  flatId: "1202"
  residentId: "RES68429"
  residentName: "Preetham"

Expected: ✅ Bill fetched (matched by all)
```

### Test 2: Only flatId
```
User:
  flatId: "1202"
  residentId: null
  name: null

Bill:
  flatId: "1202"
  residentId: "RES99999"
  residentName: "Someone"

Expected: ✅ Bill fetched (matched by flatId)
```

### Test 3: Only residentId
```
User:
  flatId: null
  residentId: "RES68429"
  name: null

Bill:
  flatId: "9999"
  residentId: "RES68429"
  residentName: "Someone"

Expected: ✅ Bill fetched (matched by residentId)
```

### Test 4: Only name
```
User:
  flatId: null
  residentId: null
  name: "Preetham"

Bill:
  flatId: "9999"
  residentId: "RES99999"
  residentName: "Preetham"

Expected: ✅ Bill fetched (matched by name)
```

### Test 5: No Match
```
User:
  flatId: "1202"
  residentId: "RES68429"
  name: "Preetham"

Bill:
  flatId: "9999"
  residentId: "RES99999"
  residentName: "Someone"

Expected: ❌ No bills found
```

---

## Performance Considerations

### Query Strategy
```
1. Fetch all bills with status filter
2. Filter in memory by matching identifiers
3. Sort and cache results
```

### Why This Approach?
- Firestore doesn't support OR queries across different fields
- In-memory filtering is fast for reasonable data sizes
- Caching minimizes repeated queries
- Flexible and maintainable

### Optimization
- Results are cached for 30 seconds
- Subsequent loads are instant
- Only fetches when cache expires

---

## Migration Guide

### From Old System (flatId only)
```
No changes needed!
Old bills with only flatId will still work.
```

### Adding residentId
```
1. Add residentId to user documents
2. Add residentId to bill documents
3. System automatically uses it for matching
```

### Adding residentName
```
1. Ensure user.name field exists
2. Add residentName to bill documents
3. System automatically uses it for matching
```

---

## Error Handling

### No Identifiers
```
Console:
❌ BillService: Cannot fetch bills - No user identifiers

Cause: User document missing all identifier fields
Fix: Add at least one identifier to user document
```

### Partial Match
```
Console:
📋 BillService: Fetching pending bill with identifiers:
   flatId: 1202
   residentId: null
   residentName: null
   ✓ Matched by flatId: 1202
✅ BillService: Found current bill

Result: Works fine with partial identifiers
```

---

## Summary

The billing service now supports flexible matching:

✅ **Matches by flatId** (primary)
✅ **Matches by residentId** (secondary)
✅ **Matches by residentName** (tertiary)
✅ **Works with any combination**
✅ **Backward compatible**
✅ **Performance optimized**

This ensures bills are fetched correctly according to the flow function, regardless of which identifiers are available in your Firestore data.

---

## Files Modified

1. ✅ `lib/src/services/bill_firestore_service.dart`
   - Added `_getUserIdentifiers()` method
   - Updated `getCurrentBill()` with flexible matching
   - Updated `getPaymentHistory()` with flexible matching
   - Updated `getBills()` with flexible matching
   - Updated `streamBills()` with flexible matching

---

**Status**: ✅ Complete
**Matching**: Flexible (flatId OR residentId OR residentName)
**Performance**: Optimized with caching
**Backward Compatible**: Yes
