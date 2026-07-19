# Chat with Technician - Dynamic Technician Data

## Overview
The chat feature now dynamically displays the assigned technician's name and phone number from the complaint data, instead of using hardcoded values.

## Changes Made

### 1. Updated Complaint Model
**File**: `lib/src/models/complaint.dart`

Added `technicianPhone` field to store the technician's contact number:

```dart
class Complaint {
  final String? assignedTo;          // Technician name
  final String? technicianPhone;     // NEW: Technician phone number
  
  // Constructor and JSON methods updated
}
```

### 2. Updated Mock Data
**File**: `lib/src/services/complaints_service.dart`

Added phone numbers to mock complaints:

```dart
Complaint(
  id: 'complaint_1',
  title: 'Water Leakage in Bathroom',
  assignedTo: 'Ramesh Kumar',
  technicianPhone: '+91 98765 43210',  // NEW
),
```

### 3. Updated Complaint Detail Modal
**File**: `lib/src/modals/complaint_detail_modal.dart`

Now checks if technician is assigned and passes actual data to chat:

```dart
Future<void> _handleChatPressed() async {
  // Check if technician is assigned
  if (widget.complaint.assignedTo == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('No technician assigned yet. Please wait for assignment.'),
      ),
    );
    return;
  }

  // Navigate with actual technician data
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => ChatWithTechnicianScreen(
        chatId: 'complaint_${widget.complaint.id}',
        technicianName: widget.complaint.assignedTo!,      // Dynamic name
        technicianRole: _getTechnicianRole(...),
        technicianPhone: widget.complaint.technicianPhone, // Dynamic phone
      ),
    ),
  );
}
```

### 4. Updated Chat Screen
**File**: `lib/src/screens/chat_with_technician_screen.dart`

Added phone number parameter and displays it in the header:

```dart
class ChatWithTechnicianScreen extends StatefulWidget {
  final String technicianName;
  final String technicianRole;
  final String? technicianPhone;  // NEW
  
  // ...
}

// Header now shows:
// - Technician Name (e.g., "Ramesh Kumar")
// - Technician Role (e.g., "Plumbing Technician")
// - Phone Number with icon (e.g., "📞 +91 98765 43210")
```

## Behavior

### When Technician is Assigned
1. User taps complaint card
2. Complaint detail modal opens
3. User taps "Chat With Technician"
4. Chat screen opens showing:
   - **Name**: From `complaint.assignedTo` (e.g., "Ramesh Kumar")
   - **Role**: Auto-determined from complaint category (e.g., "Plumbing Technician")
   - **Phone**: From `complaint.technicianPhone` (e.g., "+91 98765 43210")

### When No Technician is Assigned
1. User taps "Chat With Technician"
2. SnackBar appears: "No technician assigned yet. Please wait for assignment."
3. Modal stays open, chat doesn't open

## Example Data Flow

```
Complaint Data:
{
  "id": "complaint_1",
  "title": "Water Leakage in Bathroom",
  "category": "plumbing",
  "assignedTo": "Ramesh Kumar",
  "technicianPhone": "+91 98765 43210"
}

↓

Chat Screen Header:
┌─────────────────────────────────┐
│ 👤 Ramesh Kumar            ✕    │
│    Plumbing Technician          │
│    📞 +91 98765 43210           │
└─────────────────────────────────┘
```

## Testing

### Test Case 1: Assigned Technician
1. Open complaint "Water Leakage in Bathroom" (has Ramesh Kumar assigned)
2. Tap "Chat With Technician"
3. ✅ Chat opens with "Ramesh Kumar" and "+91 98765 43210"

### Test Case 2: No Technician
1. Open complaint "Hallway Light Not Working" (no technician assigned)
2. Tap "Chat With Technician"
3. ✅ SnackBar shows "No technician assigned yet"

### Test Case 3: Different Technicians
1. Open complaint "Lift Maintenance Required" (has Suresh Patel assigned)
2. Tap "Chat With Technician"
3. ✅ Chat opens with "Suresh Patel" and "+91 98765 43211"

## Backend Integration

When integrating with your real API, ensure the complaint response includes:

```json
{
  "id": "complaint_123",
  "title": "Water Leakage",
  "category": "plumbing",
  "status": "in-progress",
  "assignedTo": "Ramesh Kumar",
  "technicianPhone": "+91 98765 43210",
  "technicianId": "tech_001",
  "technicianAvatar": "https://example.com/avatars/ramesh.jpg"
}
```

Optional enhancements:
- Add `technicianId` for unique identification
- Add `technicianAvatar` for profile picture
- Add `technicianEmail` for additional contact
- Add `technicianRating` to show technician rating

## Summary

✅ Chat now shows actual assigned technician name  
✅ Phone number displayed in header with icon  
✅ Handles cases where no technician is assigned  
✅ Different complaints show different technicians  
✅ Role auto-determined from complaint category  
✅ All changes backward compatible with existing code
