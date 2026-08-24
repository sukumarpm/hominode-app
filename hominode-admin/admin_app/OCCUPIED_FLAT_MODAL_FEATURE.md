# Occupied Flat Details Modal - Feature Documentation

## Overview
Pixel-perfect modal for viewing and managing occupied flat details, including resident information and status management options.

## UI Specifications

### Modal Design
- **Width**: 92% of screen width
- **Corner Radius**: 18px
- **Background**: Pure white (#FFFFFF)
- **Shadow**: Soft elevated modal shadow
- **Animation**: Fade + Scale (0.95 → 1.0, 220ms, ease-out)

### Color Palette
```dart
Primary Blue:        #2563EB
Success Green:       #15B34A  // Occupied badge
Grey Label:          #6B7280
Black Text:          #111827
Info Card BG:        #F5F7FA
Border Grey:         #E5E7EB
Remove Red:          #D32F2F  // Confirmation
```

## Layout Structure

```
┌─────────────────────────────────────────┐
│  Flat A012                          [X] │  ← Header
│  View and manage flat details...       │
├─────────────────────────────────────────┤
│  Floors          Flats per Floor        │  ← Details Grid
│  Floor 1         2BHK                   │
│                                         │
│  Area            Status                 │
│  1200 Sqft       [Occupied]             │  ← Green badge
├─────────────────────────────────────────┤
│  ┌───────────────────────────────────┐ │
│  │ Resident Information              │ │  ← Info Card
│  │                                   │ │
│  │ Name :           Resident A011    │ │
│  │ ID :             RES5171          │ │
│  │ Type ;           [Tenant]         │ │  ← Badge
│  └───────────────────────────────────┘ │
├─────────────────────────────────────────┤
│  ┌──────────────┐  ┌─────────────────┐ │
│  │ 🗑 Remove    │  │ Occupied      ▼ │ │  ← Action Buttons
│  └──────────────┘  └─────────────────┘ │
└─────────────────────────────────────────┘
```

## Components

### 1. Header
- **Title**: Flat ID (24px, semibold, #111827)
- **Subtitle**: Description (14px, regular, #6B7280)
- **Close Button**: X icon (44×44px tap area)

### 2. Details Grid
Two-column layout:
- **Floors** → Floor 1
- **Flats per Floor** → 2BHK
- **Area** → 1200 Sqft
- **Status** → Occupied badge (green)

### 3. Occupied Badge
- **Background**: #15B34A (Green)
- **Text**: White, 16px, semibold
- **Padding**: 20px horizontal, 10px vertical
- **Radius**: 16px

### 4. Resident Information Card
- **Background**: #F5F7FA (Light grey)
- **Padding**: 20px all around
- **Radius**: 14px
- **Title**: "Resident Information" (16px, semibold, grey)

**Fields**:
- **Name**: Resident A011
- **ID**: RES5171
- **Type**: Tenant (badge style)

### 5. Action Buttons Row
Two equal-width buttons:

**Remove Button**:
- Outline style
- White background
- Grey border (#E5E7EB)
- Delete icon + text
- 56px height

**Status Dropdown**:
- White background
- Grey border (#E5E7EB)
- Down arrow icon
- 56px height
- Options: Occupied, Vacant, Maintenance

## Functionality

### View Resident Details
```
User clicks occupied flat (green)
    ↓
Flat Details Modal opens
    ↓
User clicks "View Details" button
    ↓
Occupied Flat Modal opens
    ↓
Shows resident information
    ↓
User can manage status or remove resident
```

### Remove Resident
```
User clicks "Remove" button
    ↓
Confirmation dialog appears
    ↓
User confirms removal
    ↓
API call to remove resident
    ↓
Status updates: Occupied → Vacant
    ↓
Tile color changes: Green → Grey
    ↓
Modal closes
    ↓
Success message shown
```

### Change Status
```
User opens status dropdown
    ↓
Selects new status (Vacant/Maintenance)
    ↓
API call to update status
    ↓
Status updates accordingly
    ↓
Tile color changes
    ↓
Modal closes
    ↓
Success message shown
```

## Status Transitions

### From Occupied
```
Occupied → Vacant (via Remove or Dropdown)
Occupied → Maintenance (via Dropdown)
```

## Integration

### Opening the Modal
```dart
// From Flat Details Modal
if (unit.status == FlatStatus.occupied) {
  await FlatOccupiedModal.show(
    context,
    unit: unit,
    onStatusChange: (newStatus) {
      widget.onStatusChange?.call(newStatus);
      Navigator.of(context).pop();
    },
  );
}
```

### Direct Usage
```dart
FlatOccupiedModal.show(
  context,
  unit: flatUnit,
  onStatusChange: (newStatus) {
    updateFlatStatus(flatUnit.id, newStatus);
  },
  onRemoveResident: () {
    // Handle resident removal
  },
);
```

## User Flow

1. **User clicks occupied flat** (green tile)
2. **Flat Details Modal opens** showing basic info
3. **User clicks "View Details"** button
4. **Occupied Modal opens** with full resident info
5. **User can**:
   - View resident details
   - Remove resident (with confirmation)
   - Change status via dropdown
6. **Status updates** automatically
7. **Grid refreshes** with new color

## Confirmation Dialog

### Remove Resident
```
┌─────────────────────────────────┐
│  Remove Resident                │
│                                 │
│  Are you sure you want to       │
│  remove Resident A011 from      │
│  Flat A012?                     │
│                                 │
│  [Cancel]  [Remove]             │
└─────────────────────────────────┘
```

## Error Handling

### Failed Removal
- Revert UI state
- Show error snackbar
- Allow retry

### Failed Status Update
- Revert dropdown selection
- Show error snackbar
- Allow retry

## Responsive Behavior

- **Desktop/Tablet**: Modal width 92% of screen
- **Mobile**: Modal width 92% of screen
- **Small Screens**: Content scrolls if needed
- **Keyboard**: Safe area padding applied

## Accessibility

- **Remove button**: Clear label and icon
- **Dropdown**: Keyboard navigable
- **Confirmation**: Clear action buttons
- **Screen reader**: Proper announcements
- **Touch targets**: All ≥ 44×44px

## Testing Checklist

- [ ] Modal opens with animation
- [ ] Resident information displays correctly
- [ ] Remove button shows confirmation
- [ ] Removal updates status to vacant
- [ ] Dropdown shows all options
- [ ] Status change updates grid
- [ ] Colors update correctly
- [ ] Error handling works
- [ ] Responsive on all screens
- [ ] Accessibility labels present

## Summary

The occupied flat modal provides a complete interface for viewing resident details and managing occupied flats, with options to remove residents or change status, all while maintaining the LYVO admin UI design system.
