# Flat Details Modal - Implementation Guide

## Overview
A pixel-perfect "Flat Details – Vacant" overlay modal that appears when an admin taps a flat tile in the Flat Occupancy Grid. The modal displays comprehensive flat information and provides actions based on the flat's status.

## Features Implemented

### ✅ Visual Design (Pixel-Perfect Match)
- **Centered overlay** with semi-transparent scrim (rgba(0, 0, 0, 0.35))
- **White dialog container** with 18px corner radius
- **Responsive sizing**: max 92% of screen width, capped at 720px
- **Max height**: 85% of screen with scrollable content
- **Smooth animations**: Scale (0.96 → 1.0) + fade-in over 220ms

### ✅ Header Section
- **Title**: Flat ID (e.g., "Flat A101") - 24sp, bold, centered
- **Subtitle**: Descriptive text - 15sp, grey, centered
- **Close button**: Top-right X icon with 44×44px touch area

### ✅ Details Grid (Two-Column Layout)
Four rows displaying:
1. **Floors** (left) | **Flats per Floor** (right)
2. Floor value | Type value (e.g., "3BHK")
3. **Area** (left) | **Status** (right)
4. Area value | Status pill

**Styling**:
- Labels: 15sp, semibold, grey (#6B7280)
- Values: 20sp, semibold, dark (#111827)
- Status pill: Rounded (16px), grey background (#D1D5DB), dark text

### ✅ Info Banner
- **Full-width** light blue background (#EEF4FF)
- **16px corner radius** with 18px padding
- **Dynamic text** based on flat status:
  - Vacant: "This flat is currently vacant. You can assign a resident or change its status."
  - Occupied: "This flat is currently occupied. View resident details or update information."
  - Maintenance: "This flat is under maintenance. Update status when work is complete."
- **Blue text** (#2563EB), 16sp

### ✅ Primary Action Button
- **Full-width** button (56px height)
- **Blue background** (#2563EB) with 14px corner radius
- **Dynamic label** based on status:
  - Vacant: "Assign Resident"
  - Occupied: "View Resident Details"
  - Maintenance: "Update Status"
- **Loading state**: Shows CircularProgressIndicator (600ms simulation)
- **Disabled state**: 40% opacity when loading

### ✅ Accessibility
- Semantic labels for all interactive elements
- Minimum 44×44px touch targets
- High contrast text/background ratios
- BouncingScrollPhysics for smooth scrolling

## File Structure

```
lib/widgets/
├── flat_details_modal.dart          # New modal widget
├── flat_occupancy_grid_modal.dart   # Updated with floor & area fields
└── ...
```

## Usage Example

### Opening the Modal from Flat Tile

```dart
// Inside flat tile onTap handler
FlatDetailsModal.show(
  context,
  unit: unit, // FlatUnit with id, type, status, floor, area
  onAssignResident: () {
    // TODO: Open Assign Resident flow
    print('Assign Resident for flat ${unit.id}');
    Navigator.of(context).pop(); // Close modal
  },
);
```

### FlatUnit Model (Updated)

```dart
class FlatUnit {
  final String id;           // e.g., "A101"
  final String type;         // e.g., "3BHK"
  final String? residentName;
  final FlatStatus status;   // occupied, vacant, maintenance
  final int floor;           // e.g., 10
  final String area;         // e.g., "1500 Sqft"
  
  FlatUnit({
    required this.id,
    required this.type,
    this.residentName,
    required this.status,
    required this.floor,
    required this.area,
  });
}
```

## Integration Points

### 1. Manage Buildings Page
The modal is triggered from the Flat Occupancy Grid:

```dart
void _showFlatOccupancyGrid(Building building) {
  final mockData = _generateMockOccupancyData(building);
  
  FlatOccupancyGridModal.show(
    context,
    towerName: building.name,
    data: mockData,
    onFlatTap: (unit) {
      FlatDetailsModal.show(
        context,
        unit: unit,
        onAssignResident: () {
          // TODO: Implement assign resident flow
        },
      );
    },
  );
}
```

### 2. Mock Data Generation
Updated to include floor and area:

```dart
flats.add(FlatUnit(
  id: 'A101',
  type: '3BHK',
  residentName: status == FlatStatus.occupied ? 'Resident ...' : null,
  status: status,
  floor: 10,
  area: '1500 Sqft',
));
```

## TODO / Future Enhancements

### Backend Integration
- [ ] Load real flat data from API
- [ ] Update flat status via API
- [ ] Assign resident functionality
- [ ] Fetch resident details for occupied flats

### Assign Resident Flow
- [ ] Create "Assign Resident" modal/page
- [ ] Resident search/selection interface
- [ ] Move-in date picker
- [ ] Lease agreement upload
- [ ] Update flat status after assignment

### Additional Features
- [ ] Edit flat details (area, type)
- [ ] View maintenance history
- [ ] Add notes/comments
- [ ] Upload flat photos
- [ ] View lease documents (for occupied flats)

## Design Specifications

### Colors
- Primary Blue: `#2563EB`
- Dark Text: `#111827`
- Grey Text: `#6B7280`
- Light Grey: `#9CA3AF`
- Border Grey: `#E5E7EB`
- Status Vacant: `#D1D5DB` (bg), `#374151` (text)
- Status Occupied: `#10B981` (bg), white (text)
- Status Maintenance: `#FBBF24` (bg), `#78350F` (text)
- Info Banner: `#EEF4FF` (bg), `#2563EB` (text)

### Typography
- Title: 24sp, FontWeight.w700
- Subtitle: 15sp, FontWeight.w400
- Labels: 15sp, FontWeight.w600
- Values: 20sp, FontWeight.w600
- Button: 18sp, FontWeight.w600
- Banner: 16sp, FontWeight.w500

### Spacing
- Modal padding: 24px horizontal, 16-24px vertical
- Section spacing: 24px
- Row spacing: 16px
- Corner radius: 18px (modal), 16px (banner/pill), 14px (button)

## Testing Checklist

- [x] Modal opens with smooth animation
- [x] Close button dismisses modal
- [x] Back gesture dismisses modal
- [x] All text displays correctly
- [x] Status pill shows correct color/text
- [x] Info banner text matches status
- [x] Button label matches status
- [x] Button shows loading state
- [x] Callback fires on button tap
- [x] Responsive on different screen sizes
- [x] Scrollable on small screens
- [x] Accessibility labels present
- [x] Touch targets meet 44×44px minimum

## Screenshots Reference
The implementation matches the uploaded reference image:
`/mnt/data/View and manage flat details, resident information, and status..png`

All spacing, colors, typography, and layout match the design 1:1.
