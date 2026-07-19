# Add Expected Visitor Modal

## Overview
Pixel-perfect centered modal overlay for adding expected visitors with form validation and date/time pickers.

## Features Implemented
✅ Centered modal with dimmed background overlay
✅ Rounded corners (20px) with soft shadow
✅ Close button (X) in top-right corner
✅ Form validation with disabled state
✅ Four input fields: Name, Purpose, Date, Time
✅ Date picker integration
✅ Time picker integration
✅ Primary CTA button (Add Visitor)
✅ Success snackbar on submission
✅ Keyboard-aware scrolling
✅ Responsive design (90% screen width)

## Modal Components

### 1. Header
- **Title:** "Add Expected Visitor"
  - Font: 22pt SemiBold
  - Color: #1E293B
  - Centered alignment
- **Close Button:**
  - Icon: X (close)
  - Size: 28px
  - Color: #64748B
  - Tap area: 48x48px (accessible)
  - Position: Top-right

### 2. Form Fields

#### Visitor Name
- **Label:** "Visitor Name" (18pt SemiBold)
- **Input:** Single-line text field
- **Placeholder:** "Enter name"
- **Validation:** Required

#### Purpose
- **Label:** "Purpose" (18pt SemiBold)
- **Input:** Single-line text field
- **Placeholder:** "e.g., Personal visit"
- **Validation:** Required

#### Date & Time Row
Two side-by-side fields with equal width:

**Date Field:**
- **Label:** "Date" (18pt SemiBold)
- **Placeholder:** "dd-mm-yyyy"
- **Behavior:** Opens DatePicker on tap
- **Format:** DD-MM-YYYY
- **Validation:** Required

**Time Field:**
- **Label:** "Time" (18pt SemiBold)
- **Placeholder:** "-- / --"
- **Behavior:** Opens TimePicker on tap
- **Format:** HH:MM AM/PM
- **Validation:** Required

### 3. Primary Button
- **Text:** "Add Visitor"
- **Font:** 18pt SemiBold
- **Color:** White on Primary Blue (#2563EB)
- **Height:** 56px
- **Width:** Full width
- **Border Radius:** 12px
- **States:**
  - Enabled: Full opacity when all fields valid
  - Disabled: 50% opacity when fields incomplete

## Design Specifications

### Colors
```dart
const kPrimary = Color(0xFF2563EB);           // Primary blue
const kModalBackground = Color(0xFFFFFFFF);   // White
const kInputBorder = Color(0xFFE6E6E6);       // Light gray border
const kPlaceholder = Color(0xFFBDBDBD);       // Placeholder text
const kDimOverlay = Color(0x5C000000);        // Dim background (36% opacity)
```

### Spacing
```dart
const kRadius = 20.0;           // Modal corner radius
const kInputRadius = 12.0;      // Input field corner radius
const kSpacing = 16.0;          // Standard spacing
const kLargeSpacing = 24.0;     // Large spacing between sections
```

### Typography
- **Modal Title:** 22pt SemiBold, #1E293B
- **Field Labels:** 18pt SemiBold, #1E293B
- **Input Text:** 15pt Regular, #1E293B
- **Placeholder:** 15pt Regular, #BDBDBD
- **Button Text:** 18pt SemiBold, White

### Layout
- **Modal Width:** 90% of screen width
- **Modal Padding:** 24px all around
- **Input Padding:** 16px horizontal, 16px vertical
- **Button Height:** 56px
- **Button Padding:** 18px vertical

## Form Validation

### Validation Rules
All fields are required:
1. Visitor Name must not be empty
2. Purpose must not be empty
3. Date must be selected
4. Time must be selected

### Visual States
- **Valid Field:** Normal border (#E6E6E6)
- **Focused Field:** Blue border (#2563EB, 2px)
- **Button Enabled:** Full opacity, clickable
- **Button Disabled:** 50% opacity, not clickable

### Validation Logic
```dart
bool _isFormValid = _nameController.text.isNotEmpty &&
    _purposeController.text.isNotEmpty &&
    _selectedDate != null &&
    _selectedTime != null;
```

## Date & Time Pickers

### Date Picker
- Opens native Flutter DatePicker
- Initial date: Today
- First date: Today
- Last date: 1 year from today
- Theme: Primary blue accent
- Format: DD-MM-YYYY

### Time Picker
- Opens native Flutter TimePicker
- Initial time: Current time
- Theme: Primary blue accent
- Format: HH:MM AM/PM (12-hour format)

## Usage

### Opening the Modal
```dart
// From FAB or any button
showAddExpectedVisitorModal(context);
```

### From Visitor Management Screen
The FAB in the Visitor Management screen automatically opens this modal:
```dart
FloatingActionButton(
  onPressed: () => showAddExpectedVisitorModal(context),
  child: Icon(Icons.add),
)
```

### Handling Submission
Currently shows success snackbar and closes modal. To integrate with backend:

```dart
void _handleAddVisitor() {
  if (_isFormValid) {
    // Create visitor object
    final visitor = {
      'name': _nameController.text,
      'purpose': _purposeController.text,
      'date': _selectedDate,
      'time': _selectedTime,
    };
    
    // Call API
    // await visitorService.addVisitor(visitor);
    
    Navigator.pop(context);
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Visitor added successfully'),
        backgroundColor: Color(0xFF10B981),
      ),
    );
  }
}
```

## Keyboard Handling

The modal uses `SingleChildScrollView` to handle keyboard appearance:
- When keyboard opens, modal scrolls to keep active field visible
- Modal repositions automatically
- No content is hidden behind keyboard

## Accessibility Features

✅ All tap targets >= 44x44px
✅ Sufficient color contrast (WCAG compliant)
✅ Clear labels for all inputs
✅ Focus states for keyboard navigation
✅ Semantic structure for screen readers

## File Structure
```
lib/
├── add_expected_visitor_modal.dart  # Modal widget
└── visitor_management_screen.dart   # Opens modal from FAB
```

## Integration Steps

1. **Import the modal:**
```dart
import 'add_expected_visitor_modal.dart';
```

2. **Call from button:**
```dart
onPressed: () => showAddExpectedVisitorModal(context),
```

3. **Handle submission:**
Modify `_handleAddVisitor()` method to integrate with your backend API.

## Customization

### Changing Colors
Update constants at top of file:
```dart
const kPrimary = Color(0xFF2563EB);  // Change primary color
const kInputBorder = Color(0xFFE6E6E6);  // Change border color
```

### Adding Fields
Add new field after existing ones:
```dart
_buildLabeledTextField(
  label: 'Phone Number',
  placeholder: 'Enter phone',
  controller: _phoneController,
),
```

### Custom Validation
Modify `_validateForm()` method:
```dart
void _validateForm() {
  setState(() {
    _isFormValid = _nameController.text.isNotEmpty &&
        _purposeController.text.isNotEmpty &&
        _selectedDate != null &&
        _selectedTime != null &&
        _phoneController.text.length == 10;  // Add custom validation
  });
}
```

## Future Enhancements
- Add visitor photo upload
- Add phone number field with validation
- Add ID proof upload
- Add vehicle number field
- Add multiple visitor support
- Add recurring visitor option
- Add visitor type selection (Personal/Professional/Delivery)
- Add pre-approval workflow
- Add visitor history lookup
- Add contact sync integration

## Testing Checklist
- [ ] Modal opens centered on screen
- [ ] Background is dimmed correctly
- [ ] Close button closes modal
- [ ] All fields accept input
- [ ] Date picker opens and selects date
- [ ] Time picker opens and selects time
- [ ] Button is disabled when fields empty
- [ ] Button is enabled when all fields filled
- [ ] Form submits successfully
- [ ] Success message appears
- [ ] Modal closes after submission
- [ ] Keyboard doesn't hide inputs
- [ ] Modal is responsive on different screen sizes

## Notes
- Modal uses `showDialog` with custom `Dialog` widget
- Background dim uses `barrierColor` property
- Form validation updates in real-time
- Date/Time pickers use Flutter's native widgets
- Success feedback uses `SnackBar`
- All spacing matches reference design exactly
