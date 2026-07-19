# ✅ Add Staff Modal - Centered Overlay Design

## 🎨 Design Update Complete

The Add Staff modal has been updated from a bottom sheet to a **centered overlay dialog** matching the exact design specifications.

## 📐 Design Specifications

### Modal Container
- **Position**: Centered on screen
- **Background**: White (#FFFFFF)
- **Border Radius**: 16px
- **Shadow**: Subtle elevation with 20px blur
- **Scrim**: rgba(0,0,0,0.32) - semi-transparent dark overlay
- **Animation**: Scale + fade (200ms ease-out)

### Typography
- **Title**: 20px, Bold, Center-aligned, #0F1724
- **Labels**: 16px, Semi-bold, Left-aligned, #0F1724
- **Input Text**: 15px, Regular, #0F1724
- **Placeholder**: 15px, Regular, #A8A8A8
- **Button**: 17px, Semi-bold, White

### Colors
- **Primary Blue**: #2563EB (button background)
- **Background**: #FFFFFF (modal surface)
- **Border**: #E6E9EE (input borders)
- **Text Primary**: #0F1724 (labels, input text)
- **Text Placeholder**: #A8A8A8 (hints)
- **Close Icon**: #9E9E9E

### Spacing
- **Modal Padding**: 20px all sides
- **Title to Content**: 24px
- **Between Fields**: 18px
- **Label to Input**: 10px
- **Input Padding**: 16px horizontal, 16px vertical
- **Button Height**: 56px

### Form Fields

1. **Full Name**
   - Label: "Full Name"
   - Placeholder: "Enter name"
   - Type: Text input

2. **Role**
   - Label: "Role"
   - Placeholder: "Select Category"
   - Type: Dropdown
   - Options: Maid, Driver, Cook, Gardener, Security, Other
   - Icon: Down arrow (keyboard_arrow_down)

3. **Phone Number**
   - Label: "Phone Number"
   - Placeholder: "+91 1234567890"
   - Type: Phone input

4. **Schedule**
   - Label: "Schedule"
   - Placeholder: "e.g., Mon-sat, 8:00 AM"
   - Type: Text input

5. **Attach Photo (Optional)**
   - Label: "Attach photo (optional)"
   - Button: "Upload photo" with download icon
   - Type: File picker button

6. **Submit Button**
   - Text: "Add Staff" (or "Update Staff" for edit mode)
   - Full width, 56px height
   - Primary blue background

## 🎯 Behavior

### Opening Animation
- Modal scales from 0.96 to 1.0
- Fades in from 0 to 1 opacity
- Duration: 200ms with ease-out curve

### Closing
- Tap outside modal → closes
- Tap X icon → closes
- Submit form → closes after save

### Validation
- All fields except photo are required
- Phone number format validation
- Empty field error messages

## 🚀 Usage

### Show Modal
```dart
showAddStaffModal(
  context,
  onSaved: (staff) {
    // Handle saved staff
    print('Staff added: ${staff.name}');
  },
);
```

### Edit Existing Staff
```dart
showAddStaffModal(
  context,
  existingStaff: currentStaff,
  onSaved: (updatedStaff) {
    // Handle updated staff
    print('Staff updated: ${updatedStaff.name}');
  },
);
```

## 📱 Responsive Design

- **Max Width**: 500px (prevents modal from being too wide on tablets)
- **Horizontal Padding**: 20px from screen edges
- **Scrollable**: Content scrolls if keyboard appears or screen is small
- **Keyboard Aware**: Modal adjusts when keyboard opens

## ✨ Key Features

✅ Centered overlay (not bottom sheet)
✅ Dark scrim background
✅ Smooth scale + fade animation
✅ Pixel-perfect spacing and typography
✅ Exact color matching
✅ Close button in top-right
✅ Full form validation
✅ Photo upload placeholder
✅ Loading state on submit
✅ Responsive and scrollable

## 🎨 Visual Comparison

**Before**: Bottom sheet modal sliding from bottom
**After**: Centered dialog with scale animation and dark scrim

## 📝 Implementation Details

### File Location
`lib/src/modals/add_staff_modal.dart`

### Key Changes
1. Changed from `showModalBottomSheet` to `showDialog`
2. Wrapped content in `Dialog` widget instead of bottom sheet container
3. Updated all spacing to match screenshot (18px between fields, 10px label-to-input)
4. Updated typography sizes and weights
5. Changed colors to exact hex values from design
6. Added photo upload section with icon
7. Increased button height to 56px
8. Centered title text
9. Updated border colors and styles

### Dependencies
- No additional dependencies required
- Uses standard Flutter Material widgets
- Photo picker can be added with `image_picker` package

## 🎉 Status

**✅ COMPLETE** - Modal now matches the centered overlay design exactly as shown in the screenshot.

---

**Updated:** January 2025
**Design**: Centered Overlay
**Status**: Production Ready
