# Add Building Modal - Implementation Guide

## Overview
A pixel-perfect modal dialog for adding new buildings to the admin app. Matches the reference design exactly with proper validation, animations, and accessibility.

## Features

### ✅ Visual Design
- Centered overlay with semi-transparent dark scrim (35% opacity)
- White modal card with 20px rounded corners
- Smooth fade-in + scale animation (220ms)
- Responsive: max 92% width or 720px, max 80% height
- Keyboard-safe with automatic scrolling

### ✅ Form Fields
1. **Building/Tower Name**
   - Full-width text input
   - Placeholder: "e.g., Tower D"
   - Validation: Required, minimum 2 characters

2. **Floors** (Left column)
   - Numeric input only
   - Placeholder: "10"
   - Validation: Required, positive integer

3. **Flats per Floor** (Right column)
   - Numeric input only
   - Placeholder: "4"
   - Validation: Required, positive integer

### ✅ Total Flats Strip
- Light blue background (#EFF5FF)
- Displays: "Total Flats: {total_flats}"
- Automatically calculates: floors × flats_per_floor

### ✅ Buttons
1. **Add Building** (Primary)
   - Blue background (#2563EB)
   - Disabled state: 40% opacity
   - Loading state: Shows spinner
   - Only enabled when form is valid

2. **Cancel** (Secondary)
   - White background with grey border
   - Closes modal without saving

### ✅ Validation
- Real-time validation on input change
- Inline error messages below fields
- Red error text and borders
- Button disabled until all fields valid

### ✅ Accessibility
- Semantic labels for screen readers
- Minimum 44×44px touch targets
- High contrast colors
- Keyboard navigation support

## Usage

### Basic Implementation

```dart
import 'widgets/add_building_modal.dart';

// Show the modal
ElevatedButton(
  onPressed: () {
    AddBuildingModal.show(
      context,
      onSave: (building) {
        // Handle the saved building
        print('Building: ${building.name}');
        print('Floors: ${building.floors}');
        print('Flats per Floor: ${building.flatsPerFloor}');
        print('Total Flats: ${building.totalFlats}');
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Building ${building.name} added'),
          ),
        );
      },
    );
  },
  child: const Text('+ Add Building'),
);
```

### BuildingModel Structure

```dart
class BuildingModel {
  final String name;           // Building/Tower name
  final int floors;            // Number of floors
  final int flatsPerFloor;     // Flats per floor
  final int totalFlats;        // Total flats (calculated)
}
```

### Integration in ManageBuildingsPage

The modal is fully integrated in the "+ Add Building" button:
- Located in the title row of the Building Management section
- Opens centered modal on tap
- Adds new building to the list immediately after saving
- Shows success SnackBar with building name
- New buildings appear with 0% occupancy (all vacant)
- Ready for API integration to persist data

## Customization

### Colors
All colors are defined inline and can be easily modified:
- Primary Blue: `Color(0xFF2563EB)`
- Border Grey: `Color(0xFFE6E9EC)`
- Text Dark: `Color(0xFF111111)`
- Text Grey: `Color(0xFF6B7280)`
- Placeholder: `Color(0xFFB9BDC1)`
- Amount Strip BG: `Color(0xFFEFF5FF)`
- Error Red: `Color(0xFFEF4444)`

### Animation Timing
Modify in `AddBuildingModal.show()`:
```dart
transitionDuration: const Duration(milliseconds: 220),
```

### Loading Simulation
Adjust the delay in `_handleAddBuilding()`:
```dart
await Future.delayed(const Duration(milliseconds: 800));
```

## File Structure

```
lib/
  widgets/
    add_building_modal.dart  # Modal widget + BuildingModel class
  manage_buildings_page.dart # Integration example
```

## Testing Checklist

- [ ] Modal opens with smooth animation
- [ ] Form validation works for all fields
- [ ] Add button disabled when form invalid
- [ ] Loading state shows spinner
- [ ] Cancel button closes modal
- [ ] X button closes modal
- [ ] Tap outside closes modal
- [ ] Keyboard doesn't cover inputs
- [ ] Success callback receives correct data
- [ ] Total Flats strip calculates correctly
- [ ] New building appears in list after adding
- [ ] Works on small screens
- [ ] Accessible with screen readers

## Current Functionality

✅ **Fully Working:**
- Modal opens with smooth animation
- Form validation works in real-time
- Total Flats calculates automatically (floors × flats_per_floor)
- New building is added to the list immediately
- Success message shows building name
- New buildings start with 0% occupancy (all vacant)

## Next Steps

To integrate with your backend:

1. Replace the simulated delay in `_handleAddBuilding()`
2. Add API call to save building to database
3. Handle errors and show error messages
4. Update the `_addNewBuilding()` method to use API response
5. Add loading state to parent page if needed
6. Implement delete/edit functionality for buildings
