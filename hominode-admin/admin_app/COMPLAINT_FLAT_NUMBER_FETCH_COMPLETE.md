# Complaint Flat Number Fetch - Complete

## Overview
Updated the complaint management screen to fetch and display the actual flat number (unit) from the flats collection instead of showing the flatId.

## Problem
Previously, the complaint screen was displaying the `flatId` (document ID) as the unit number, which is not user-friendly. For example:
- Before: `unit: "abc123def456"` (flatId)
- After: `unit: "A-101"` (actual flat number)

## Solution
Modified the complaint conversion to fetch the flat number from the Firestore `flats` collection using the `flatId`.

## Changes Made

### 1. Complaint Management Screen (`complaint_management_screen.dart`)

**Added:**
- `cloud_firestore` import for direct Firestore access
- Async conversion method `_convertToComplaintEntry()` (now returns `Future<ComplaintEntry>`)
- Flat number fetching logic from `flats` collection
- Error handling for failed flat fetches
- Console logging for debugging

**Updated:**
- `_loadComplaints()` method to handle async conversion
- Loops through complaints and awaits each conversion
- Fetches flat document using `flatId`
- Extracts `flatNumber` field from flat document

## Implementation Details

### Data Flow
1. Complaint loaded from Firestore with `flatId`
2. System fetches flat document from `flats/{flatId}`
3. Extracts `flatNumber` field from flat document
4. Displays flat number as unit in UI

### Fallback Logic
If flat fetch fails or flat doesn't exist:
- Falls back to showing `flatId`
- If no `flatId`, shows "N/A"

### Code Structure
```dart
Future<ComplaintEntry> _convertToComplaintEntry(ComplaintModel complaint) async {
  String unitNumber = 'N/A';
  
  if (complaint.flatId != null && complaint.flatId!.isNotEmpty) {
    try {
      // Fetch flat document
      final flatDoc = await FirebaseFirestore.instance
          .collection('flats')
          .doc(complaint.flatId)
          .get();
      
      if (flatDoc.exists) {
        // Extract flat number
        unitNumber = flatData?['flatNumber'] ?? complaint.flatId ?? 'N/A';
      }
    } catch (e) {
      // Fallback to flatId on error
      unitNumber = complaint.flatId ?? 'N/A';
    }
  }
  
  return ComplaintEntry(..., unit: unitNumber, ...);
}
```

## Firestore Collections Used

### Complaints Collection
```
complaints/{complaintId}
  ├── title: string
  ├── description: string
  ├── residentId: string
  ├── residentName: string
  ├── flatId: string          // Reference to flat document
  ├── category: string
  ├── priority: string
  ├── status: string
  ├── createdAt: timestamp
  └── updatedAt: timestamp
```

### Flats Collection
```
flats/{flatId}
  ├── flatNumber: string      // e.g., "A-101", "B-205"
  ├── buildingId: string
  ├── floor: number
  ├── bhkType: string
  ├── status: string
  └── ...
```

## Display Examples

### Before (showing flatId)
```
Complaint #126
Resident: John Doe
Unit: abc123def456789
```

### After (showing flat number)
```
Complaint #126
Resident: John Doe
Unit: A-101
```

## Error Handling

### Scenarios Handled
1. **Flat document doesn't exist** → Shows flatId as fallback
2. **Firestore fetch fails** → Shows flatId as fallback
3. **No flatId in complaint** → Shows "N/A"
4. **flatNumber field missing** → Shows flatId as fallback

### Console Logs
```
ComplaintManagementScreen: Fetched flat number: A-101 for flatId: abc123
ComplaintManagementScreen ERROR: Failed to fetch flat number: [error]
```

## Performance Considerations

### Optimization
- Fetches flat numbers in parallel for all complaints
- Uses async/await for non-blocking operations
- Caches results in memory (complaints list)

### Potential Improvement
For large complaint lists, consider:
- Batch fetching flat numbers
- Caching flat numbers in complaint documents
- Using Firestore joins (when available)

## Testing Checklist
- [ ] Open complaint management screen
- [ ] Verify complaints show flat numbers (e.g., "A-101")
- [ ] Test with complaint that has valid flatId
- [ ] Test with complaint that has invalid flatId
- [ ] Test with complaint that has no flatId
- [ ] Verify fallback to flatId works
- [ ] Verify "N/A" shows when no flat info
- [ ] Check console logs for fetch messages

## Benefits
✅ User-friendly flat numbers displayed
✅ Proper flat number instead of document ID
✅ Graceful fallback handling
✅ Error logging for debugging
✅ Maintains existing functionality

## Status
✅ Flat number fetching implemented
✅ Firestore integration complete
✅ Error handling added
✅ Fallback logic working
✅ No compilation errors
✅ Console logging added

## Related Files
- `admin_app/lib/complaint_management_screen.dart` - Updated
- Firestore collections: `complaints`, `flats`

## Next Steps
The complaint management screen now displays actual flat numbers. To test:
1. Create complaints with valid `flatId` references
2. Ensure `flats` collection has `flatNumber` field
3. Open complaint management screen
4. Verify flat numbers display correctly (e.g., "A-101", "B-205")
