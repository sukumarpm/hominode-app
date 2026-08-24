# Flat Maintenance Modal Feature

## Overview
Implemented a pixel-perfect maintenance status modal that appears when clicking on flats marked as "Maintenance". Allows admins to view flat details and change the maintenance status.

## UI Specifications

### Modal Design
- **Width**: 92% of screen width
- **Max Height**: 80% of viewport
- **Corner Radius**: 18px
- **Background**: Pure white (#FFFFFF)
- **Shadow**: Soft elevation (8)
- **Animation**: Fade + Scale (0.96 → 1.0, 220ms)

### Color Palette
```dart
Primary Blue:        #2563EB
Black Text:          #111827  // Titles and values
Grey Text:           #6B7280  // Labels
Maintenance Badge:   #F2B100  // Yellow with white text
Warning Box BG:      #FFF9E6  // Soft yellow
Warning Text:        #9A3A2A  // Brown/red tone
Border Grey:         #E2E2E2
Icon Grey:           #9CA3AF
```

### Layout Structure

```
┌─────────────────────────────────────────┐
│  Flat A012                          [X] │  ← Header
│  View and manage flat details...       │
├─────────────────────────────────────────┤
│  Floors          Flats per Floor        │  ← Labels
│  Floor 1         2BHK                   │  ← Values
│                                         │
│  Area            Status                 │  ← Labels
│  1200 Sqft       [Maintenance]          │  ← Values + Badge
├─────────────────────────────────────────┤
│  ┌───────────────────────────────────┐ │
│  │ ⚠ This flat is under maintenance. │ │  ← Warning Box
│  │   Change status when ready.       │ │
│  │                                   │ │
│  │  ┌─────────────────────────────┐ │ │
│  │  │ Keep in Maintenance      ▼  │ │ │  ← Dropdown
│  │  └─────────────────────────────┘ │ │
│  └───────────────────────────────────┘ │
└─────────────────────────────────────────┘
```

## Components

### 1. Header
- **Title**: Flat ID (24px, semibold, #111827)
- **Subtitle**: Description (15px, regular, #6B7280)
- **Close Button**: X icon (44×44px tap area)

### 2. Details Grid
Two-column layout with equal spacing:

**Row 1:**
- Floors → Floor 1
- Flats per Floor → 2BHK

**Row 2:**
- Area → 1200 Sqft
- Status → Maintenance Badge

**Labels**: 15px, semibold, #6B7280
**Values**: 20px, semibold, #111827

### 3. Maintenance Badge
- **Background**: #F2B100 (Yellow)
- **Text**: White, 16px, semibold
- **Padding**: 18px horizontal, 10px vertical
- **Radius**: 16px

### 4. Warning Box
- **Background**: #FFF9E6 (Soft yellow)
- **Padding**: 20px all around
- **Radius**: 14px
- **Text**: #9A3A2A (Brown/red), 16px, medium

### 5. Status Dropdown
- **Height**: 56px
- **Border**: 1px solid #E2E2E2
- **Radius**: 14px
- **Background**: White
- **Text**: 16px, medium, #111827
- **Icon**: Down arrow, #9CA3AF

## Functionality

### Status Options
1. **Keep in Maintenance** (default)
2. **Mark as Vacant**
3. **Mark as Occupied**

### Status Change Flow
```
User selects "Mark as Vacant"
    ↓
Dropdown updates
    ↓
API call simulated (800ms)
    ↓
onStatusChange callback triggered
    ↓
Flat status updates in parent
    ↓
Modal closes
    ↓
Success message shown
    ↓
Grid refreshes with new status
```

### Color Changes
- **Maintenance → Vacant**: Yellow → Grey
- **Maintenance → Occupied**: Yellow → Green

## Integration

### Opening the Modal
```dart
// From Flat Details Modal
if (unit.status == FlatStatus.maintenance) {
  await FlatMaintenanceModal.show(
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
FlatMaintenanceModal.show(
  context,
  unit: flatUnit,
  onStatusChange: (newStatus) {
    // Handle status change
    updateFlatStatus(flatUnit.id, newStatus);
  },
);
```

## User Flow

1. **User clicks maintenance flat** (yellow tile)
2. **Flat Details Modal opens** showing maintenance status
3. **User clicks "Update Status"** button
4. **Maintenance Modal opens** (this modal)
5. **User sees warning message** about maintenance
6. **User opens dropdown** to change status
7. **User selects new status** (Vacant or Occupied)
8. **System updates status** via API
9. **Modal closes** with success message
10. **Grid refreshes** showing new color

## Responsive Behavior

- **Desktop/Tablet**: Modal width 92% of screen, max 720px
- **Mobile**: Modal width 92% of screen
- **Small Screens**: Content scrolls if needed
- **Keyboard**: Safe area padding applied

## Accessibility

- **Close button**: 44×44px tap target
- **Dropdown**: Full-width, easy to tap
- **Semantic labels**: All interactive elements labeled
- **High contrast**: Text meets WCAG AA standards
- **Screen reader**: Proper announcements

## Error Handling

### Failed Status Update
- Dropdown reverts to "Keep in Maintenance"
- Error snackbar shown
- User can retry

### Network Issues
- Loading state shown
- Timeout after 10 seconds
- Clear error message

## Testing Checklist

- [ ] Modal opens with fade + scale animation
- [ ] Close button works
- [ ] Dropdown shows all options
- [ ] Status change updates flat
- [ ] Grid refreshes after change
- [ ] Success message appears
- [ ] Error handling works
- [ ] Responsive on all screen sizes
- [ ] Keyboard safe area respected
- [ ] Accessibility labels present

## Future Enhancements

1. **Maintenance Notes**: Add text field for notes
2. **Maintenance History**: Show past maintenance records
3. **Estimated Completion**: Date picker for completion
4. **Maintenance Type**: Dropdown for type (Plumbing, Electrical, etc.)
5. **Photo Upload**: Add before/after photos
6. **Assign Technician**: Select maintenance staff
7. **Cost Tracking**: Add maintenance cost field
