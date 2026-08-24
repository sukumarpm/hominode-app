# Assign Resident Modal - Quick Reference

## 🚀 Quick Start

### Import
```dart
import 'widgets/assign_resident_modal.dart';
```

### Show Modal
```dart
AssignResidentModal.show(
  context,
  flatId: 'A101',
  flatLabel: 'A101',
  loadResidents: () async {
    // Fetch residents from API
    return await api.getResidents();
  },
  onAssign: (request) async {
    // Assign resident via API
    await api.assignResident(request);
  },
);
```

## 📋 Data Models

### ResidentSummary
```dart
class ResidentSummary {
  final String id;           // Required: "1"
  final String name;         // Required: "John Doe"
  final String? flatLabel;   // Optional: "A101"
}
```

### AssignResidentRequest
```dart
class AssignResidentRequest {
  final String flatId;        // "A101"
  final String residentId;    // "1"
  final String ownershipType; // "Owner", "Tenant", "Lease"
}
```

## 🎯 Common Use Cases

### 1. From Flat Details Modal (Automatic)
```dart
// Already integrated in flat_details_modal.dart
// Automatically opens when tapping "Assign Resident" on vacant flat
```

### 2. Direct Call with API
```dart
AssignResidentModal.show(
  context,
  flatId: flat.id,
  flatLabel: flat.id,
  loadResidents: () async {
    final response = await http.get('/api/residents');
    return (response.data as List)
        .map((json) => ResidentSummary(
          id: json['id'],
          name: json['name'],
          flatLabel: json['flatLabel'],
        ))
        .toList();
  },
  onAssign: (request) async {
    await http.post('/api/flats/${request.flatId}/assign', {
      'residentId': request.residentId,
      'ownershipType': request.ownershipType,
    });
  },
);
```

### 3. With Mock Data (Testing)
```dart
AssignResidentModal.show(
  context,
  flatId: 'A101',
  flatLabel: 'A101',
  loadResidents: () async {
    await Future.delayed(Duration(milliseconds: 500));
    return [
      ResidentSummary(id: '1', name: 'John Doe'),
      ResidentSummary(id: '2', name: 'Jane Smith'),
    ];
  },
  onAssign: (request) async {
    await Future.delayed(Duration(milliseconds: 800));
    print('Assigned ${request.residentId} to ${request.flatId}');
  },
);
```

## 🎨 Features

| Feature | Description |
|---------|-------------|
| **Segmented Control** | Switch between "Select Existing" and "Add New" |
| **Resident Dropdown** | Select from registered residents |
| **Ownership Dropdown** | Choose Owner, Tenant, or Lease |
| **Form Validation** | Button disabled until form valid |
| **Loading States** | Shows spinner during API calls |
| **Error Handling** | Displays error banners |
| **Empty State** | Shows message when no residents |
| **Keyboard Safe** | Adjusts for keyboard |

## 🎯 Validation Rules

### Required Fields
- ✅ Resident must be selected
- ✅ Ownership type must be selected

### Button States
- **Disabled**: Form invalid or submitting
- **Enabled**: All fields valid
- **Loading**: Showing spinner during submission

## ⚠️ Important Notes

1. **Callbacks**: Both `loadResidents` and `onAssign` are optional
2. **Mock Data**: If `loadResidents` is null, uses mock data
3. **Auto-Close**: Modal closes on successful assignment
4. **Error Display**: Errors shown in red banner at top
5. **Add New**: Currently shows placeholder (TODO)

## 🔧 Customization

### Ownership Types
Edit in `assign_resident_modal.dart`:
```dart
final ownershipTypes = ['Owner', 'Tenant', 'Lease', 'Company'];
```

### Mock Residents
Edit in `_loadResidents()`:
```dart
_residents = [
  ResidentSummary(id: '1', name: 'John Doe'),
  ResidentSummary(id: '2', name: 'Jane Smith'),
  // Add more...
];
```

## 🐛 Troubleshooting

### Modal doesn't open
- Check context is valid
- Verify flatId and flatLabel are provided
- Check for navigation conflicts

### Dropdown empty
- Verify `loadResidents` returns data
- Check API response format
- Look for errors in console

### Button stays disabled
- Ensure resident is selected
- Verify ownership type is set
- Check form validation logic

### Assignment fails
- Check `onAssign` callback
- Verify API endpoint
- Check request format

## 📱 Testing

### Test Empty State
```dart
loadResidents: () async => [],
```

### Test Loading State
```dart
loadResidents: () async {
  await Future.delayed(Duration(seconds: 3));
  return residents;
}
```

### Test Error State
```dart
loadResidents: () async {
  throw Exception('Failed to load');
}
```

### Test Assignment Error
```dart
onAssign: (request) async {
  throw Exception('Assignment failed');
}
```

## 🔗 Related Files

- `lib/widgets/assign_resident_modal.dart` - Main widget
- `lib/widgets/flat_details_modal.dart` - Calls this modal
- `ASSIGN_RESIDENT_MODAL_GUIDE.md` - Detailed guide

## 💡 Tips

- Use semantic labels for accessibility
- Test on different screen sizes
- Handle loading states properly
- Provide clear error messages
- Keep callbacks simple and fast
- Always close modal on success
- Show success feedback to user

## 📊 Flow

```
Flat Details Modal
       ↓
Tap "Assign Resident"
       ↓
Assign Resident Modal Opens
       ↓
Select Resident from Dropdown
       ↓
Select Ownership Type
       ↓
Tap "Assign Resident" Button
       ↓
Loading State (spinner)
       ↓
API Call Success
       ↓
Modal Closes
       ↓
Success SnackBar
```

## 🎨 Design Specs

### Colors
- Primary Blue: `#2563EB`
- Dark Text: `#111827`
- Grey Text: `#6B7280`
- Placeholder: `#9CA3AF`
- Border: `#E5E7EB`

### Sizing
- Max Width: `720px`
- Max Height: `85%`
- Dropdown: `52px`
- Button: `56px`

### Animation
- Duration: `220ms`
- Scale: `0.96 → 1.0`
- Curve: `Curves.easeOut`
