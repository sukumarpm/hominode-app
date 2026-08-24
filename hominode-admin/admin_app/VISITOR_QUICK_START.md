# Visitor Management - Quick Start Guide

## ✅ Status: READY TO TEST

## What Was Fixed

1. **Firestore Index Error**: Removed composite index requirements by sorting in memory
2. **No Data Issue**: Created test data tools to populate sample visitors
3. **Added Debug Tools**: Purple debug button to easily create/clear test data

## Quick Test Steps

### 1. Run the App
```bash
flutter run
```

### 2. Navigate to Visitor Management
- Tap on "Visitor Management" from the dashboard or navigation

### 3. Create Test Data
- You'll see TWO floating buttons:
  - **Blue "Scan QR"** (right) - Normal QR scanner
  - **Purple bug icon** (left) - **DEBUG BUTTON** ← Use this!
  
- Tap the **purple debug button**
- Select **"Create All Sample Data"**
- Wait for success message

### 4. Verify Tabs
- **Pending Tab**: Should show 3 visitors waiting for approval
- **Active Tab**: Should show 2 visitors currently inside
- **History Tab**: Should show 3 completed visits

### 5. Test Actions
- **Pending Tab**: Tap "Approve" → visitor moves to Active
- **Pending Tab**: Tap "Reject" → visitor disappears
- **Active Tab**: Tap "Mark Exit" → visitor moves to History

### 6. Test Search
- Type visitor name, flat number, or phone in search bar
- Results filter in real-time

## What You'll See

### Pending Tab (3 visitors)
```
John Doe
+91 98765 43210
Visiting: Amit Kumar | Unit: A-101
Purpose: Personal Visit
[Reject] [Approve]
```

### Active Tab (2 visitors)
```
David Lee
+91 98765 43213
Visiting: Sneha Patel | Unit: B-202
Purpose: Guest
Entered: 9:30 AM
[Mark Exit]
```

### History Tab (3 visitors)
```
Robert Brown
C-302 • Courier
Entry: 10:00 AM | Exit: 11:00 AM
Duration: 1h 0m
```

## Debug Button Options

1. **Create All Sample Data** ← Use this first
   - Creates 3 pending + 2 active + 3 history visitors
   
2. **Create Pending Visitors**
   - Creates only 3 pending visitors
   
3. **Clear All Visitors**
   - Deletes everything (asks for confirmation)

## Remove Debug Button Later

Once testing is complete, remove the debug button:

1. Open `lib/visitor_management_screen.dart`
2. Remove line: `import 'widgets/visitor_debug_button.dart';`
3. Replace the `floatingActionButton: Stack(...)` section with:

```dart
floatingActionButton: FloatingActionButton.extended(
  onPressed: _onQRScannerTap,
  backgroundColor: const Color(0xFF2563EB),
  elevation: 4,
  icon: const Icon(Icons.qr_code_scanner, color: Colors.white, size: 20),
  label: const Text('Scan QR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
),
```

## Troubleshooting

### "No data appears"
→ Tap purple debug button → "Create All Sample Data"

### "Still see Firestore error"
→ Check Firestore rules allow read/write to `visitors` collection

### "Debug button doesn't appear"
→ Hot restart app (not just hot reload)

### "Can't find debug button"
→ Look for purple bug icon on LEFT side (blue QR button is on right)

## Real Production Use

After testing, visitors will be created by:
1. **Resident App**: Residents request visitor entry
2. **Admin App**: You approve/reject requests
3. **Gate Scanner**: QR code check-in/check-out

The test data is just for initial testing!

## Files Created

- `lib/services/visitor_test_data.dart` - Test data service
- `lib/widgets/visitor_debug_button.dart` - Debug UI button
- `VISITOR_MANAGEMENT_FIX_COMPLETE.md` - Detailed documentation
- `VISITOR_QUICK_START.md` - This file

## Files Modified

- `lib/services/visitor_service.dart` - Fixed Firestore queries
- `lib/visitor_management_screen.dart` - Added debug button

## Success Checklist

- [ ] App runs without errors
- [ ] Visitor Management screen opens
- [ ] Purple debug button visible
- [ ] "Create All Sample Data" works
- [ ] Pending tab shows 3 visitors
- [ ] Active tab shows 2 visitors
- [ ] History tab shows 3 visitors
- [ ] Approve button works
- [ ] Reject button works
- [ ] Mark Exit button works
- [ ] Search filters work
- [ ] Real-time updates work

## Next Steps

1. ✅ Test with sample data (use debug button)
2. ⏳ Verify all functionality works
3. ⏳ Remove debug button
4. ⏳ Test with real visitor requests from resident app
5. ⏳ Deploy to production

---

**Need Help?** Check `VISITOR_MANAGEMENT_FIX_COMPLETE.md` for detailed documentation.
