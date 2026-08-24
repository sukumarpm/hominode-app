# Edit Building Feature

## Overview
The edit building functionality allows admins to modify existing building details while preserving occupancy data.

## How It Works

### User Flow:
1. Click the **pencil icon** (edit button) on any building card
2. Modal opens with **pre-filled form** showing current building data
3. Title changes to "Edit Building"
4. Subtitle changes to "Update building or tower details"
5. Modify any fields (name, floors, flats per floor)
6. See **Total Flats** update automatically
7. Click "Update Building" button
8. Building updates in the list
9. Success message: "Building {name} updated successfully"

### Key Features:

#### ✅ Pre-filled Form
- Building name is pre-populated
- Floors value is pre-filled
- Flats per floor is pre-filled
- Form is immediately valid (can save without changes)

#### ✅ Smart Occupancy Preservation
When editing a building, the system intelligently handles occupancy:

**Example:**
- Original: Tower A with 40 flats (35 occupied, 5 vacant, 75% occupancy)
- Edit to: 50 flats (12 floors × 4 flats + 2 extra)
- Result: 35 occupied, 15 vacant, 70% occupancy

**Logic:**
```dart
// Preserves existing occupied count
final occupied = oldBuilding.occupied;
final newTotalFlats = buildingModel.totalFlats;

// Recalculates vacant and occupancy rate
final vacant = newTotalFlats - occupied;
final occupancyRate = (occupied / newTotalFlats) * 100;

// Safety check: if new total < occupied, cap occupied at new total
if (occupied > newTotalFlats) {
  occupied = newTotalFlats;
  vacant = 0;
  occupancyRate = 100;
}
```

#### ✅ Visual Differences (Edit vs Add)
| Feature | Add Mode | Edit Mode |
|---------|----------|-----------|
| Title | "Add New Building" | "Edit Building" |
| Subtitle | "Configure your new building..." | "Update building or tower details" |
| Button | "Add Building" | "Update Building" |
| Form | Empty fields | Pre-filled with current data |
| Success Color | Green (#10B981) | Blue (#2563EB) |

#### ✅ Validation
- Same validation rules as add mode
- Name: minimum 2 characters
- Floors: positive integer
- Flats per floor: positive integer
- Real-time validation
- Button disabled if invalid

## Code Implementation

### Modal Changes:
```dart
AddBuildingModal.show(
  context,
  existingBuilding: BuildingModel(...), // Pass existing data
  onSave: (updatedBuilding) {
    // Handle update
  },
);
```

### Edit Handler:
```dart
void _handleEditBuilding(Building building, int index) {
  AddBuildingModal.show(
    context,
    existingBuilding: BuildingModel(
      name: building.name,
      floors: building.floors,
      flatsPerFloor: building.flatsPerFloor,
      totalFlats: building.totalFlats,
    ),
    onSave: (updatedBuilding) {
      _editBuilding(index, updatedBuilding);
      // Show success message
    },
  );
}
```

### Update Logic:
```dart
void _editBuilding(int index, BuildingModel buildingModel) {
  setState(() {
    final oldBuilding = buildings[index];
    final occupied = oldBuilding.occupied;
    final newTotalFlats = buildingModel.totalFlats;
    
    // Recalculate occupancy metrics
    final vacant = newTotalFlats - occupied;
    final occupancyRate = (occupied / newTotalFlats) * 100;
    
    buildings[index] = Building(
      name: buildingModel.name,
      floors: buildingModel.floors,
      flatsPerFloor: buildingModel.flatsPerFloor,
      totalFlats: newTotalFlats,
      occupied: occupied > newTotalFlats ? newTotalFlats : occupied,
      vacant: vacant < 0 ? 0 : vacant,
      occupancyRate: occupancyRate.round(),
    );
  });
}
```

## Use Cases

### 1. Rename Building
- Change "Tower A" to "Building A"
- Occupancy data unchanged
- Total flats unchanged

### 2. Add More Floors
- Change from 10 to 12 floors
- Total flats increases (40 → 48)
- Occupied stays same (35)
- Vacant increases (5 → 13)
- Occupancy rate decreases (75% → 73%)

### 3. Reduce Flats per Floor
- Change from 4 to 3 flats per floor
- Total flats decreases (40 → 30)
- If occupied > new total, occupied is capped
- Occupancy rate recalculated

### 4. Complete Redesign
- Change all values
- System handles all calculations
- Preserves as much occupancy data as possible

## Testing Checklist

- [ ] Edit icon opens modal with pre-filled data
- [ ] Modal title shows "Edit Building"
- [ ] All fields are pre-populated correctly
- [ ] Form is valid on open (can save immediately)
- [ ] Changes are reflected in the list
- [ ] Occupancy data is preserved correctly
- [ ] Total flats recalculates when floors/flats change
- [ ] Success message shows updated building name
- [ ] Cancel button closes without saving
- [ ] X button closes without saving
- [ ] Multiple edits work correctly
- [ ] Edit after add works correctly

## Future Enhancements

- [ ] Add confirmation dialog for major changes
- [ ] Show diff of changes before saving
- [ ] Add undo/redo functionality
- [ ] Track edit history
- [ ] Add validation for occupied > total flats scenario
- [ ] Add warning when reducing total flats below occupied
