# Flat Occupancy Grid Feature

## Overview
The Flat Occupancy Grid modal provides a visual representation of all flats in a building, showing their occupancy status at a glance.

## Features

### ✅ Visual Design
- Full-screen centered modal with dark scrim (35% opacity)
- White card with 20px rounded corners
- Smooth fade-in + scale animation (220ms)
- Responsive: max 92% width or 720px, max 90% height
- Vertically scrollable content

### ✅ Components

#### 1. Header
- **Title**: "{Tower Name} - Flat Occupancy Grid" (22sp, bold)
- **Subtitle**: "Visual representation of all flats. Click on any flat to view or edit details."
- **Close Button**: X icon in top-right corner

#### 2. View Toggle (Segmented Control)
- Two modes: Grid View / List View
- Light grey background (#F3F4F6)
- White active pill with shadow
- Smooth animated transition
- 28px border radius

#### 3. Status Legend
- Three status indicators:
  - **Occupied**: Green (#10B981)
  - **Vacant**: Grey (#D1D5DB)
  - **Maintenance**: Yellow (#FBBF24)
- Small colored squares with labels

#### 4. Search & Filter Row
- **Search Field**: 
  - Placeholder: "Search by flat or resident"
  - Search icon on left
  - Real-time filtering
  - 3/4 width
- **Status Filter**:
  - Dropdown with options: All, Occupied, Vacant, Maintenance
  - 1/4 width
  - Combines with search

#### 5. Floor Sections
- **Floor Label**: White pill with border
  - Text: "Floor {number}"
  - 15sp, semibold
  - 12px margin below

#### 6. Flat Tiles (Grid View)
- **2-column grid layout**
- **Tile Design**:
  - 16px border radius
  - 14px padding
  - 12px spacing between tiles
  - Color-coded by status
- **Tile Content**:
  - Line 1: Flat ID (e.g., "A101") - bold
  - Line 2: Flat type (e.g., "2BHK") - semibold
  - Line 3: Resident name or "Vacant" - regular
- **Colors**:
  - Occupied: Bright green (#10B981) with white text
  - Vacant: Light grey (#E5E7EB) with dark text
  - Maintenance: Amber (#FBBF24) with white text

#### 7. List View
- **Full-width list items**
- **Item Design**:
  - Same color coding as grid
  - Horizontal layout
  - Left: Flat ID and type
  - Right: Resident name
  - 16px padding

### ✅ Interactions

#### Search Functionality
- Real-time filtering as user types
- Searches in:
  - Flat ID (e.g., "A101")
  - Resident name
- Case-insensitive
- Updates grid/list immediately

#### Status Filter
- Dropdown menu with 4 options:
  - All (default)
  - Occupied
  - Vacant
  - Maintenance
- Combines with search filter
- Updates view immediately

#### View Toggle
- Switch between Grid and List views
- Maintains search and filter state
- Smooth animated transition
- Same data, different layout

#### Flat Tile Tap
- Tappable with ripple effect
- Calls `onFlatTap(unit)` callback
- Shows SnackBar with flat info (placeholder)
- TODO: Open flat details page

## Data Models

### FlatUnit
```dart
class FlatUnit {
  final String id;              // "A101"
  final String type;            // "2BHK", "3BHK"
  final String? residentName;   // "Resident ..." or null
  final FlatStatus status;      // occupied, vacant, maintenance
}
```

### FloorOccupancy
```dart
class FloorOccupancy {
  final int floorNumber;        // 1, 2, 3, etc.
  final List<FlatUnit> flats;   // List of flats on this floor
}
```

### FlatStatus (Enum)
```dart
enum FlatStatus {
  occupied,
  vacant,
  maintenance,
}
```

## Usage

### Opening the Modal

```dart
// From building card grid icon
IconButton(
  icon: const Icon(Icons.grid_view),
  onPressed: () {
    FlatOccupancyGridModal.show(
      context,
      towerName: 'Tower A',
      data: occupancyData,
      onFlatTap: (unit) {
        // Handle flat tap
        print('Flat ${unit.id} tapped');
      },
    );
  },
);
```

### Mock Data Generation

```dart
List<FloorOccupancy> _generateMockOccupancyData(Building building) {
  final floors = <FloorOccupancy>[];
  
  for (int floor = building.floors; floor >= 1; floor--) {
    final flats = <FlatUnit>[];
    
    for (int flat = 1; flat <= building.flatsPerFloor; flat++) {
      flats.add(FlatUnit(
        id: 'A${floor}0$flat',
        type: '2BHK',
        residentName: 'Resident Name',
        status: FlatStatus.occupied,
      ));
    }
    
    floors.add(FloorOccupancy(
      floorNumber: floor,
      flats: flats,
    ));
  }
  
  return floors;
}
```

## User Flow

### Grid View Flow:
1. User clicks grid icon on building card
2. Modal opens with animation
3. Shows all floors in descending order (Floor 5, 4, 3, 2, 1)
4. Each floor shows flats in 2-column grid
5. Flats are color-coded by status
6. User can:
   - Search for specific flat or resident
   - Filter by status
   - Switch to list view
   - Tap any flat to see details
   - Close modal

### List View Flow:
1. User toggles to "List View"
2. Layout changes to full-width list items
3. Same data, different presentation
4. Each item shows flat info horizontally
5. All search/filter functionality works the same

### Search Flow:
1. User types in search field
2. Results filter in real-time
3. Only matching flats shown
4. Empty floors are hidden
5. "No flats found" message if no matches

### Filter Flow:
1. User clicks status dropdown
2. Selects status (Occupied/Vacant/Maintenance)
3. Grid updates to show only selected status
4. Combines with search if active
5. "All" option shows everything

## Colors

| Element | Color | Hex | Usage |
|---------|-------|-----|-------|
| Occupied | Green | #10B981 | Flat tile background |
| Vacant | Grey | #E5E7EB | Flat tile background |
| Maintenance | Yellow | #FBBF24 | Flat tile background |
| Title | Dark | #111827 | Header text |
| Subtitle | Grey | #6B7280 | Description text |
| Border | Light Grey | #E5E7EB | Borders and dividers |
| Toggle BG | Light Grey | #F3F4F6 | Inactive toggle background |
| Primary Blue | Blue | #2563EB | Focus states |

## Accessibility

- ✅ Semantic labels for all interactive elements
- ✅ Minimum 44×44px touch targets
- ✅ High contrast text on colored backgrounds
- ✅ Screen reader support
- ✅ Keyboard navigation
- ✅ Clear visual feedback on interactions

## Performance

### Optimizations:
- Uses `GridView.builder` for efficient rendering
- `shrinkWrap: true` with `NeverScrollableScrollPhysics` for nested scrolling
- Filters data before rendering
- Smooth animations with `AnimatedContainer`
- Efficient state management

### Scalability:
- Handles buildings with many floors
- Efficient search algorithm
- Lazy loading ready (TODO)
- Pagination ready (TODO)

## Testing Checklist

- [ ] Modal opens with smooth animation
- [ ] Close button closes modal
- [ ] Tap outside closes modal
- [ ] View toggle switches between grid and list
- [ ] Search filters flats in real-time
- [ ] Status filter works correctly
- [ ] Search + filter combination works
- [ ] Flat tiles show correct colors
- [ ] Flat tiles show correct information
- [ ] Tapping flat shows SnackBar
- [ ] Grid layout is responsive
- [ ] List layout displays correctly
- [ ] Scrolling works smoothly
- [ ] Empty state shows "No flats found"
- [ ] Works with different building sizes
- [ ] Works on small screens
- [ ] Works on large screens

## Future Enhancements

### TODO: Real Data Integration
```dart
// Load from API
Future<List<FloorOccupancy>> loadOccupancyData(String buildingId) async {
  final response = await http.get('/api/buildings/$buildingId/occupancy');
  return parseOccupancyData(response.body);
}
```

### TODO: Flat Details Page
```dart
void _showFlatDetails(FlatUnit unit) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => FlatDetailsPage(flatId: unit.id),
    ),
  );
}
```

### Planned Features:
- [ ] Flat details page
- [ ] Edit flat information
- [ ] Assign/remove residents
- [ ] Change flat status
- [ ] View flat history
- [ ] Export occupancy report
- [ ] Print occupancy grid
- [ ] Bulk status update
- [ ] Drag-and-drop to change status
- [ ] Real-time updates via WebSocket
- [ ] Occupancy analytics
- [ ] Vacancy alerts

## Summary

The Flat Occupancy Grid provides a comprehensive visual overview of all flats in a building with:
- ✅ Color-coded status indicators
- ✅ Dual view modes (Grid/List)
- ✅ Real-time search and filtering
- ✅ Smooth animations
- ✅ Responsive design
- ✅ Ready for real data integration

Perfect for admins to quickly assess building occupancy and manage flats efficiently!
