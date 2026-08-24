# Building Management - Quick Reference Guide

## Access the Module

**From Dashboard:**
- Tap "Add Building" quick action button
- OR tap "Buildings" in bottom navigation

**Direct Navigation:**
```dart
Navigator.push(
  context,
  MaterialPageRoute(builder: (context) => const ManageBuildingsPage()),
);
```

## Quick Actions

### Add New Building
1. Tap "Add Building" button (top-right)
2. Enter building name (e.g., "Tower A")
3. Enter number of floors (e.g., 10)
4. Enter flats per floor (e.g., 4)
5. Review total flats (auto-calculated: 40)
6. Tap "Add Building"
7. ✅ Building created with 40 flats auto-generated

**Keyboard Shortcuts:**
- Tab: Move to next field
- Enter: Submit form (if valid)
- Esc: Close modal

### Edit Building
1. Find building in list
2. Tap edit icon (pencil)
3. Modify fields as needed
4. Tap "Update Building"
5. ✅ Building updated

**Note:** Editing preserves existing occupancy data

### Delete Building
1. Find building in list
2. Tap delete icon (trash)
3. Confirm deletion in dialog
4. ✅ Building and all flats deleted

**Warning:** This action cannot be undone!

### View Flat Occupancy
1. Find building in list
2. Tap grid icon
3. View all flats organized by floor
4. Tap any flat for details
5. Assign residents or change status

## Building Card Information

Each card shows:
```
┌─────────────────────────────────┐
│ 🏢 Tower A                  ⚙️📝🗑️│
│ 10 Floors • 4 Flats/Floor        │
│                                  │
│ ┌──────┐ ┌──────┐ ┌──────┐     │
│ │Total │ │Occup.│ │Vacant│     │
│ │  40  │ │  32  │ │   8  │     │
│ └──────┘ └──────┘ └──────┘     │
│                                  │
│ Occupancy Rate          80%      │
│ ████████████████░░░░             │
└─────────────────────────────────┘
```

**Icons:**
- ⚙️ Grid View - View flat occupancy
- 📝 Edit - Edit building details
- 🗑️ Delete - Delete building

## Form Validation

### Building Name
- ✅ Valid: "Tower A", "Building 1", "Block C"
- ❌ Invalid: "", "A" (too short)

### Floors
- ✅ Valid: 1, 5, 10, 20
- ❌ Invalid: 0, -5, "abc"

### Flats per Floor
- ✅ Valid: 1, 2, 4, 8
- ❌ Invalid: 0, -2, "xyz"

## Common Scenarios

### Scenario 1: Add First Building
```
1. Open Building Management
2. See "No buildings yet" message
3. Tap "Add Building"
4. Enter: Name="Tower A", Floors=10, Flats=4
5. Total Flats shows: 40
6. Tap "Add Building"
7. Success! 40 flats auto-generated
```

### Scenario 2: Edit Building Configuration
```
1. Building has 10 floors, 4 flats/floor (40 total)
2. Need to change to 12 floors
3. Tap edit icon
4. Change Floors to 12
5. Total Flats updates to: 48
6. Tap "Update Building"
7. Success! Occupancy data preserved
```

### Scenario 3: Delete Unused Building
```
1. Building "Tower D" was added by mistake
2. No residents assigned yet
3. Tap delete icon
4. Confirm deletion
5. Success! Building and 40 flats removed
```

### Scenario 4: View and Manage Flats
```
1. Tap grid icon on "Tower A"
2. See all 40 flats in grid view
3. Floor 10 at top, Floor 1 at bottom
4. Green = Vacant, Blue = Occupied
5. Tap flat "A1001" (Floor 10, Flat 1)
6. See flat details
7. Assign resident or change status
```

## Service Usage

### In Your Code

```dart
final BuildingService _buildingService = BuildingService();

// Get all buildings (real-time)
StreamBuilder<List<BuildingModel>>(
  stream: _buildingService.getBuildings(),
  builder: (context, snapshot) {
    final buildings = snapshot.data ?? [];
    // Display buildings
  },
)

// Add building
await _buildingService.addBuilding(
  name: 'Tower A',
  floors: 10,
  flatsPerFloor: 4,
  totalFlats: 40,
);

// Update building
await _buildingService.updateBuilding(
  id: buildingId,
  name: 'Tower A (Updated)',
  floors: 12,
  flatsPerFloor: 4,
  totalFlats: 48,
);

// Delete building
await _buildingService.deleteBuilding(buildingId);

// Sync occupancy
await _buildingService.syncOccupancyFromFlats(buildingId);
```

## Flat Naming Convention

Flats are auto-named based on:
- First letter of building name
- Floor number
- Flat number (zero-padded)

**Examples:**
```
Building: "Tower A"
Floor 1, Flat 1 → "A101"
Floor 1, Flat 2 → "A102"
Floor 10, Flat 1 → "A1001"
Floor 10, Flat 4 → "A1004"

Building: "Block B"
Floor 5, Flat 3 → "B503"
```

## Occupancy Statistics

### Calculation
```
Total Flats = Floors × Flats per Floor
Occupied = Count of flats with status="occupied"
Vacant = Total Flats - Occupied
Occupancy Rate = (Occupied / Total Flats) × 100
```

### Auto-Update Triggers
- Resident assigned to flat → Occupied +1, Vacant -1
- Resident removed from flat → Occupied -1, Vacant +1
- Flat status changed → Recalculate stats
- Building edited → Recalculate stats

## Troubleshooting

### Building Not Appearing
- Check internet connection
- Verify Firestore rules allow read access
- Check Firebase console for data
- Refresh the page

### Cannot Add Building
- Verify all fields are filled
- Check validation errors below fields
- Ensure positive numbers for floors/flats
- Check Firestore rules allow write access

### Flats Not Generated
- Check Firestore console for flats collection
- Verify FlatService is working
- Check for error messages in console
- Try adding building again

### Occupancy Stats Wrong
- Tap grid icon to view actual flat statuses
- Use sync function to recalculate
- Check flat statuses in Firestore
- Verify resident assignments

### Delete Not Working
- Check if building has residents assigned
- Verify Firestore rules allow delete
- Check for error messages
- Try again after a moment

## Best Practices

1. **Naming Convention**: Use consistent naming (Tower A, Tower B, etc.)
2. **Plan Ahead**: Calculate total flats before adding
3. **Verify Data**: Check occupancy grid after adding
4. **Regular Sync**: Sync occupancy stats periodically
5. **Backup**: Export building data regularly (future feature)

## Keyboard Navigation

- **Tab**: Move between fields
- **Shift+Tab**: Move backwards
- **Enter**: Submit form (when valid)
- **Escape**: Close modal
- **Space**: Toggle buttons

## Accessibility

- All buttons have semantic labels
- Form fields have proper labels
- Error messages are announced
- Color is not the only indicator
- Keyboard navigation supported

## Performance Tips

1. **Batch Operations**: Add multiple buildings in sequence
2. **Lazy Loading**: Flat grid loads on-demand
3. **Real-time Updates**: No need to refresh manually
4. **Efficient Queries**: Buildings ordered by creation date
5. **Optimistic UI**: Immediate feedback before server response

## Integration with Other Modules

### Dashboard
- Total flats count includes all buildings
- Quick action button navigates here
- Real-time stats update

### Residents
- Assign residents via flat occupancy grid
- Resident count affects occupancy stats
- Flat assignments tracked

### Billing
- Bills can be filtered by building
- Building name shown in bill details
- Flat-based billing supported

## Color Coding

- **Green** (#10B981): Success, Vacant flats
- **Blue** (#2563EB): Primary actions, Occupied flats
- **Yellow** (#F4A100): Warnings, Vacant stats
- **Red** (#EF4444): Errors, Delete actions
- **Orange** (#F97316): Maintenance status

## Data Persistence

- All data stored in Firestore
- Real-time synchronization
- Automatic backup by Firebase
- No local storage required
- Works across devices

## Security

- Firestore security rules enforced
- Admin authentication required
- Write operations logged
- Audit trail maintained
- Role-based access control
