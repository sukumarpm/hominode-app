# App Settings Screen - Complete ✅

## Overview
A simplified, modern settings screen that matches the reference images exactly with 5 main sections: Notifications, Appearance, Account Settings, Preferences, and About.

## Design Specifications

### Header
- **Background**: Blue (`#3B82F6`)
- **Title**: "Settings" (20px, weight 600, white)
- **Back button**: White arrow icon
- **No rounded corners** (flat design)

### Card Style
- **Background**: White (`#FFFFFF`)
- **Border radius**: 16px
- **Shadow**: `rgba(0, 0, 0, 0.04)` blur 8px, offset (0, 2)
- **Spacing**: 16px between cards
- **Padding**: 16px all around

### Section Icons
- **Size**: 40x40px
- **Border radius**: 10px
- **Background colors**:
  - Notifications: Light blue (`#DBEAFE`)
  - Appearance: Light purple (`#F3E8FF`)
- **Icon colors**:
  - Notifications: Blue (`#3B82F6`)
  - Appearance: Purple (`#9333EA`)

### Typography
- **Section title**: 16px, weight 600, `#111827`
- **Row title**: 15px, weight 600/500, `#111827`
- **Subtitle**: 13px, regular, `#9CA3AF`
- **Trailing text**: 14px, `#9CA3AF`

### Toggle Switch
- **Active color**: Blue (`#3B82F6`)
- **Active track**: Light blue (`#DBEAFE`)
- **Size**: Standard Material switch

## Sections

### 1. Notifications
**Icon**: Bell icon in light blue circle

Contains:
- **Push Notifications**
  - Subtitle: "Get notified about updates"
  - Toggle switch
- **Email Notifications**
  - Subtitle: "Receive emails about bills"
  - Toggle switch

### 2. Appearance
**Icon**: Moon icon in light purple circle

Contains:
- **Dark Mode**
  - Subtitle: "Enable dark theme"
  - Toggle switch
  - Applies theme change across entire app

### 3. Account Settings
**Section title only** (no icon)

Contains:
- **Edit Profile**
  - Icon: Person outline
  - Opens edit profile modal
- **Change Password**
  - Icon: Lock outline
  - Navigates to change password screen

### 4. Preferences
**Section title only** (no icon)

Contains:
- **Language**
  - Icon: Globe
  - Shows current language: "English"
  - Navigates to language selection

### 5. About
**Section title only** (no icon)

Contains:
- **Help & Support**
  - Icon: Help outline
  - Shows support dialog
- **Terms & Conditions**
  - Icon: Document outline
  - Shows terms dialog
- **Privacy Policy**
  - Icon: Privacy tip outline
  - Shows privacy dialog
- **About App**
  - Icon: Info outline
  - Shows version: "v1.0.0"
  - Shows about dialog

## Usage

### Navigate to Settings
```dart
import 'package:your_app/src/screens/app_settings_screen.dart';

Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => const AppSettingsScreen(),
  ),
);
```

### From Profile Screen
```dart
// In profile screen settings option
ListTile(
  leading: Icon(Icons.settings),
  title: Text('Settings'),
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AppSettingsScreen(),
      ),
    );
  },
)
```

## Features

### Toggle Settings
- **Push Notifications**: Enable/disable push notifications
- **Email Notifications**: Enable/disable email notifications
- **Dark Mode**: Toggle between light and dark theme

### Navigation
- **Edit Profile**: Opens modal to edit user profile
- **Change Password**: Navigate to password change screen
- **Language**: Navigate to language selection screen
- **Help & Support**: Shows support contact dialog
- **Terms & Conditions**: Shows terms dialog
- **Privacy Policy**: Shows privacy policy dialog
- **About App**: Shows app information dialog

## Integration Points

### 1. Edit Profile Modal
```dart
void _navigateToEditProfile() {
  final currentProfile = UserProfile.mock();
  showEditProfileModal(
    context,
    currentProfile: currentProfile,
    onSaved: (updatedProfile) {
      // Handle profile update
    },
  );
}
```

### 2. Change Password Screen
```dart
void _navigateToChangePassword() {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => const ChangePasswordScreen(),
    ),
  );
}
```

### 3. Language Settings
```dart
void _navigateToLanguage() {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => const LanguageSettingsScreen(),
    ),
  );
}
```

### 4. Dark Mode Toggle
```dart
void _toggleDarkMode(bool value) {
  // Update theme provider
  final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
  themeProvider.setDarkMode(value);
  
  // Save to SharedPreferences
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('dark_mode', value);
}
```

## Settings Persistence

### Save Settings
```dart
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _savePushNotificationSetting(bool value) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('push_notifications', value);
}

Future<void> _saveEmailNotificationSetting(bool value) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('email_notifications', value);
}
```

### Load Settings
```dart
Future<void> _loadSettings() async {
  final prefs = await SharedPreferences.getInstance();
  setState(() {
    _pushNotifications = prefs.getBool('push_notifications') ?? true;
    _emailNotifications = prefs.getBool('email_notifications') ?? false;
    _darkMode = prefs.getBool('dark_mode') ?? false;
  });
}
```

## Dialogs

### Help & Support Dialog
Shows contact information:
- Email: support@residentapp.com
- Phone: +91 1800 123 4567
- 24/7 availability message

### Terms & Conditions Dialog
Displays:
- Last updated date
- Acceptance of terms
- Use license
- Privacy policy reference
- Modification rights

### Privacy Policy Dialog
Displays:
- Information collection
- Usage of information
- Information sharing policy
- Data security measures
- User rights

### About App Dialog
Shows:
- App icon (80x80px blue rounded square)
- App name: "Resident App"
- Version: "1.0.0"
- Description
- Copyright notice

## Color Palette

```dart
// Primary Colors
const primaryBlue = Color(0xFF3B82F6);
const primaryPurple = Color(0xFF9333EA);

// Background Colors
const lightBlue = Color(0xFFDBEAFE);
const lightPurple = Color(0xFFF3E8FF);
const background = Color(0xFFF5F5F5);
const cardBackground = Color(0xFFFFFFFF);

// Text Colors
const textPrimary = Color(0xFF111827);
const textSecondary = Color(0xFF9CA3AF);
const textTertiary = Color(0xFF6B7280);

// Border Colors
const divider = Color(0xFFE5E7EB);

// Status Colors
const success = Color(0xFF22C55E);
const error = Color(0xFFEF4444);
```

## Responsive Design

### Mobile (< 600px)
- Full width cards
- 16px horizontal padding
- Stacked layout

### Tablet (600px - 900px)
- Max width: 600px
- Centered content
- Same card style

### Desktop (> 900px)
- Max width: 720px
- Centered content
- Larger touch targets

## Accessibility

### Features
- Minimum 44px touch targets
- Proper semantic labels
- Screen reader support
- High contrast text
- Keyboard navigation

### Implementation
```dart
Semantics(
  label: 'Push Notifications Toggle',
  hint: 'Enable or disable push notifications',
  child: Switch(...),
)
```

## Testing

### Widget Tests
```dart
testWidgets('Settings screen displays all sections', (tester) async {
  await tester.pumpWidget(
    MaterialApp(home: AppSettingsScreen()),
  );
  
  expect(find.text('Notifications'), findsOneWidget);
  expect(find.text('Appearance'), findsOneWidget);
  expect(find.text('Account Settings'), findsOneWidget);
  expect(find.text('Preferences'), findsOneWidget);
  expect(find.text('About'), findsOneWidget);
});
```

## Dependencies

```yaml
dependencies:
  flutter:
    sdk: flutter
  provider: ^6.1.1              # Theme management
  shared_preferences: ^2.2.2    # Settings persistence
```

## File Structure

```
lib/
└── src/
    ├── screens/
    │   ├── app_settings_screen.dart       # NEW simplified settings
    │   ├── settings_screen.dart           # OLD comprehensive settings
    │   ├── notifications_settings_screen.dart
    │   ├── language_settings_screen.dart
    │   └── change_password_screen.dart
    ├── modals/
    │   └── edit_profile_modal.dart
    ├── providers/
    │   └── theme_provider.dart
    └── services/
        └── locale_provider.dart
```

## Differences from Old Settings Screen

### Old Settings Screen (`settings_screen.dart`)
- 6 sections with many options
- More comprehensive
- Includes: Family Members, Vehicles, Biometric, Two-Factor, Payments, Bookings, etc.
- Logout button at bottom
- More complex navigation

### New Settings Screen (`app_settings_screen.dart`)
- 5 sections (simplified)
- Matches reference images exactly
- Focus on core settings only
- Cleaner, more modern UI
- Better for mobile experience

## When to Use Which

### Use `AppSettingsScreen` (NEW)
- From Profile screen settings option
- For end-user settings
- Mobile-first experience
- Simplified interface

### Use `SettingsScreen` (OLD)
- From admin/power user menu
- For comprehensive settings
- Desktop/tablet experience
- Advanced features needed

## Future Enhancements

- [ ] Add search functionality
- [ ] Add settings backup/restore
- [ ] Add notification preferences detail
- [ ] Add theme customization options
- [ ] Add haptic feedback
- [ ] Add settings sync across devices
- [ ] Add biometric authentication toggle
- [ ] Add data usage settings

---

**Status**: ✅ Complete
**Last Updated**: November 19, 2025
**Version**: 1.0.0
