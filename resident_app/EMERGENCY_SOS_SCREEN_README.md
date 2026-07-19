# Emergency SOS Screen - Implementation Guide

## Overview
Pixel-perfect implementation of the Emergency SOS screen that displays emergency contact numbers with direct call functionality.

## Features
- ✅ Gradient header with back navigation
- ✅ Warning box for emergency usage guidelines
- ✅ 5 Emergency contact cards (Security, Fire, Medical, Police, Maintenance)
- ✅ **Confirmation dialog** - Pixel-perfect modal when tapping cards
- ✅ Direct phone dialer integration
- ✅ Scrollable list with bouncing physics
- ✅ Exact color palette and typography matching reference design

## File Structure
```
lib/
└── src/
    ├── screens/
    │   └── emergency_sos_screen.dart
    └── modals/
        └── emergency_call_dialog.dart
```

## Integration

### 1. Add Dependency
The screen uses `url_launcher` for phone call functionality. Already added to `pubspec.yaml`:

```yaml
dependencies:
  url_launcher: ^6.2.5
```

Run:
```bash
flutter pub get
```

### 2. Navigation from Dashboard
The Emergency SOS button in `dashboard_screen.dart` now navigates to this screen:

```dart
import 'src/screens/emergency_sos_screen.dart';

// In Emergency button onTap:
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => const EmergencySosScreen(),
  ),
);
```

## Design Specifications

### Color Palette
- **Header Gradient**: `#FF7A68` → `#FF3D35` (top-left to bottom-right)
- **Background**: `#F7F7F7`
- **Card Background**: `#FFFFFF`
- **Warning Box**: `#FFECEC`
- **Warning Text**: `#D32F2F`
- **Text Primary**: `#111111`
- **Text Secondary**: `#9E9E9E`
- **Phone Icon**: `#A3A3A3`

### Header Standardization
The header follows the app's standardized pattern:
- Left-aligned back button with IconButton
- Title positioned next to back button (not centered)
- Consistent padding: `fromLTRB(8, 16, 16, 20)`
- Font size: 20pt (standardized across app)
- White status bar icons via `SystemUiOverlayStyle.light`

### Emergency Contact Colors
- **Security**: Blue `#2563EB`
- **Fire**: Red `#E53935`
- **Medical**: Green `#34A853`
- **Police**: Orange `#FF6A00`
- **Maintenance**: Purple `#9C27B0`

### Typography
- **Header Title**: 20pt, Semibold (standardized)
- **Emergency Title**: 17pt, Semibold
- **Emergency Subtitle**: 14pt, Regular
- **Phone Number**: 15pt, Medium
- **Warning Title**: 16pt, Bold
- **Warning Subtitle**: 14pt, Regular

### Layout
- **Header**: Rounded bottom corners (24px radius), left-aligned title
- **Warning Box**: 12px border radius, no shadow
- **Emergency Cards**: 16px border radius, 64px icon containers
- **Spacing**: 20px page padding, 12px between cards
- **SafeArea**: Applied at Scaffold level for consistent behavior

## Emergency Contacts Data

The screen includes 5 pre-configured emergency contacts:

1. **Security** - For security emergencies (+91 98765 00001)
2. **Fire** - Fire emergency (101)
3. **Medical** - Medical Emergency (102)
4. **Police** - Police Emergency (100)
5. **Maintenance** - Maintenance Emergency (+91 98765 00002)

## Customization

### Update Emergency Contacts
Edit the `_emergencyContacts` list in `emergency_sos_screen.dart`:

```dart
final List<EmergencyContact> _emergencyContacts = [
  const EmergencyContact(
    title: 'Your Title',
    subtitle: 'Your Subtitle',
    contact: '+91 XXXXX XXXXX',
    iconColor: Color(0xFF2563EB),
    icon: Icons.your_icon,
  ),
];
```

### Modify Warning Message
Update the warning box text in `_buildWarningBox()` method.

## Platform Configuration

### Android
Add to `android/app/src/main/AndroidManifest.xml`:
```xml
<queries>
  <intent>
    <action android:name="android.intent.action.DIAL" />
  </intent>
</queries>
```

### iOS
Add to `ios/Runner/Info.plist`:
```xml
<key>LSApplicationQueriesSchemes</key>
<array>
  <string>tel</string>
</array>
```

## Usage Example

```dart
// Navigate to Emergency SOS screen
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => const EmergencySosScreen(),
  ),
);
```

## Features in Detail

### Phone Call Functionality
- Tapping the phone icon triggers the device's native dialer
- Uses `url_launcher` package for cross-platform compatibility
- Handles errors gracefully with debug logging

### Scrolling Behavior
- Bouncing physics for iOS-like feel
- Smooth scrolling with proper padding
- Fixed header that doesn't scroll

### Responsive Design
- Optimized for iPhone 13 (390px width)
- Adapts to different screen sizes
- Maintains visual consistency across devices

## Testing

Test the following scenarios:
1. ✅ Navigation from dashboard Emergency button
2. ✅ Back button returns to dashboard
3. ✅ Phone icon opens dialer with correct number
4. ✅ Scrolling works smoothly
5. ✅ All colors match reference design
6. ✅ Typography is consistent

## Notes

- The warning message "3 items are running low on stock" is kept as per the reference image
- All spacing and sizing match the reference pixel-perfectly
- Icons use Material Icons for consistency
- Status bar is light (white icons) due to gradient header

## Maintenance

To update emergency contacts:
1. Edit `_emergencyContacts` list
2. Add/remove `EmergencyContact` objects
3. Ensure icon colors match your design system

---

**Status**: ✅ Complete and Production Ready
**Last Updated**: November 19, 2025


## Emergency Call Confirmation Dialog

### Overview
When tapping any emergency contact card (or the phone icon), a centered modal dialog appears asking for confirmation before making the call.

### Dialog Features
- **Three-layer nested icon design** - Outer grey (#F5F6FA), inner grey (#F1F2F6), colored center
- **Dynamic content** - Icon, color, title, phone number, and description change per emergency type
- **Call Now button** - Blue (#2563EB) with phone icon, triggers native dialer
- **Cancel button** - White with grey border, dismisses dialog
- **Close icon** - Top-right X button for quick dismissal
- **Dimmed background** - 50% black overlay behind modal

### Dialog Specifications
- **Modal Width**: Full width with 24px padding
- **Border Radius**: 22px
- **Icon Container**: 200x200px with three nested layers
- **Button Height**: 54px
- **Animation**: Smooth fade-in with Material dialog transition

### Usage Example
```dart
// Automatically shown when tapping emergency cards
// Or manually trigger:
showEmergencyCallDialog(
  context,
  title: 'Security Emergency',
  phoneNumber: '+91 98765 00001',
  description: 'For security emergencies',
  icon: Icons.shield_outlined,
  iconColor: Color(0xFF2563EB),
);
```

### Color Variations by Emergency Type
- **Security**: Blue #2563EB
- **Fire**: Red #E53935
- **Medical**: Green #34A853
- **Police**: Orange #FF6A00
- **Maintenance**: Purple #9C27B0

---

**Status**: ✅ Complete with Confirmation Dialog
**Last Updated**: November 19, 2025
