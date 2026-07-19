# Vehicle Modal UI Standardization

## Overview
Updated the Add/Edit Vehicle modal to match the same UI flow and design pattern as the Add/Edit Family Member modal for consistency across the app.

## Changes Made

### 1. Modal Layout
- **Before**: Two-button footer (Cancel + Save)
- **After**: Single full-width action button at the bottom of the form
- Removed the separate footer container with border
- Integrated the action button directly into the scrollable content area

### 2. Header Styling
- Updated header padding: `fromLTRB(24, 20, 12, 16)`
- Centered modal title with consistent typography
- Font size: 22px, weight: 600
- Close button styling matches family member modal

### 3. Form Field Styling
- Label font size: 16px (was 14px)
- Label color: `#111827` (was `#374151`)
- Spacing between label and field: 10px (was 8px)
- Field border radius: 12px (was 10px)
- Field background: White (was `#F9FAFB`)
- Border color: `#E6E9EC` (was `#E5E7EB`)
- Hint text color: `#B9BDC1` (was `#9CA3AF`)
- Consistent padding: 16px horizontal and vertical

### 4. Spacing
- Consistent 20px spacing between form fields (was 16px)
- 24px spacing before photo upload section
- 32px spacing before action button

### 5. Action Button
- Full-width button (54px height)
- Disabled state with 40% opacity
- Form validation: Button disabled until required fields are filled
- Dynamic text: "Add Vehicle" or "Update Vehicle"
- Consistent styling with family member modal

### 6. Photo Upload Section
- Label text changed from "Attach bike Image (optional)" to "Attach photo (optional)"
- Maintains consistent styling with family member modal

### 7. Modal Container
- Added shadow for depth: `BoxShadow` with 15% opacity, 24px blur
- Max width constraint: 720px for larger screens
- Responsive width: 92% of screen width on smaller devices
- Wrapped in `Material` widget for proper rendering

## Benefits
- **Consistency**: Both modals now follow the same design pattern
- **Better UX**: Single action button is clearer and more mobile-friendly
- **Form Validation**: Button is disabled until required fields are filled
- **Visual Hierarchy**: Improved spacing and typography for better readability
- **Accessibility**: Larger touch targets and clearer visual feedback

## Usage
The modal works exactly the same way programmatically:

```dart
AddEditVehicleModal.show(
  context,
  onSave: (vehicle) {
    // Handle save
  },
);

// For editing
AddEditVehicleModal.show(
  context,
  vehicle: existingVehicle,
  onSave: (vehicle) {
    // Handle update
  },
);
```

## Testing
- Verify modal opens with proper animation
- Test form validation (required fields)
- Test photo upload functionality
- Test both add and edit modes
- Verify close button and backdrop dismiss behavior
- Test on different screen sizes
