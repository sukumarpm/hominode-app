# Flat Details Modal - Quick Reference

## 🚀 Quick Start

### Import
```dart
import 'widgets/flat_details_modal.dart';
import 'widgets/flat_occupancy_grid_modal.dart'; // For FlatUnit
```

### Show Modal
```dart
FlatDetailsModal.show(
  context,
  unit: FlatUnit(
    id: 'A101',
    type: '3BHK',
    status: FlatStatus.vacant,
    floor: 10,
    area: '1500 Sqft',
  ),
  onAssignResident: () {
    // Your action here
  },
);
```

## 📋 FlatUnit Model

```dart
class FlatUnit {
  final String id;           // Required: "A101"
  final String type;         // Required: "3BHK", "2BHK"
  final String? residentName; // Optional: "John Doe"
  final FlatStatus status;   // Required: vacant/occupied/maintenance
  final int floor;           // Required: 10
  final String area;         // Required: "1500 Sqft"
}
```

## 🎨 Status Types

```dart
enum FlatStatus {
  vacant,      // Grey pill, "Assign Resident" button
  occupied,    // Green pill, "View Resident Details" button
  maintenance  // Yellow pill, "Update Status" button
}
```

## 🔧 Common Use Cases

### 1. From Flat Grid
```dart
FlatOccupancyGridModal.show(
  context,
  towerName: 'Tower A',
  data: floorData,
  onFlatTap: (unit) {
    FlatDetailsModal.show(
      context,
      unit: unit,
      onAssignResident: () {
        // Handle action
      },
    );
  },
);
```

### 2. Direct Call
```dart
ElevatedButton(
  onPressed: () {
    FlatDetailsModal.show(
      context,
      unit: myFlatUnit,
      onAssignResident: () {
        Navigator.pop(context);
        // Navigate to assign resident page
      },
    );
  },
  child: Text('View Flat Details'),
);
```

### 3. With Navigation
```dart
onAssignResident: () {
  Navigator.pop(context); // Close modal
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => AssignResidentPage(flatId: unit.id),
    ),
  );
}
```

## 🎯 Key Features

| Feature | Description |
|---------|-------------|
| **Responsive** | Adapts to screen size (max 720px) |
| **Animated** | Smooth scale + fade (220ms) |
| **Scrollable** | Works on small screens |
| **Accessible** | WCAG AA compliant |
| **Dynamic** | Content changes with status |
| **Loading State** | Built-in spinner (600ms) |

## 🎨 Customization Points

### Colors (in modal file)
```dart
Primary Blue:     Color(0xFF2563EB)
Dark Text:        Color(0xFF111827)
Grey Text:        Color(0xFF6B7280)
```

### Sizing
```dart
Max Width:        720px
Max Height:       85% of screen
Button Height:    56px
```

### Animation
```dart
Duration:         220ms
Scale Range:      0.96 → 1.0
Curve:            Curves.easeOut
```

## ⚠️ Important Notes

1. **Required Fields**: All FlatUnit fields except `residentName` are required
2. **Callback**: `onAssignResident` is optional but recommended
3. **Navigation**: Modal doesn't auto-close; handle in callback
4. **Loading**: Built-in 600ms loading simulation (remove in production)

## 🐛 Troubleshooting

### Modal doesn't appear
- Check context is valid
- Ensure FlatUnit has all required fields
- Verify no navigation conflicts

### Button doesn't work
- Check callback is provided
- Verify no errors in callback function
- Check loading state isn't stuck

### Layout issues
- Ensure parent has proper constraints
- Check screen size isn't too small
- Verify no conflicting modals

## 📱 Testing

### Test Cases
```dart
// Vacant flat
FlatDetailsModal.show(context, unit: vacantFlat, ...);

// Occupied flat
FlatDetailsModal.show(context, unit: occupiedFlat, ...);

// Maintenance flat
FlatDetailsModal.show(context, unit: maintenanceFlat, ...);
```

### Example Data
```dart
final vacantFlat = FlatUnit(
  id: 'A101',
  type: '3BHK',
  status: FlatStatus.vacant,
  floor: 10,
  area: '1500 Sqft',
);

final occupiedFlat = FlatUnit(
  id: 'B205',
  type: '2BHK',
  residentName: 'John Doe',
  status: FlatStatus.occupied,
  floor: 5,
  area: '1200 Sqft',
);
```

## 🔗 Related Files

- `lib/widgets/flat_details_modal.dart` - Main widget
- `lib/widgets/flat_occupancy_grid_modal.dart` - FlatUnit model
- `lib/manage_buildings_page.dart` - Integration example
- `FLAT_DETAILS_MODAL_GUIDE.md` - Detailed guide
- `FLAT_DETAILS_VISUAL_SPEC.md` - Design specs

## 📚 Next Steps

1. Implement assign resident flow
2. Connect to backend API
3. Add edit functionality
4. Implement status updates
5. Add maintenance history

## 💡 Tips

- Use semantic labels for accessibility
- Test on different screen sizes
- Handle loading states properly
- Provide user feedback after actions
- Keep callbacks simple and fast
