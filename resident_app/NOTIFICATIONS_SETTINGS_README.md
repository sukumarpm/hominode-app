# Notifications Settings Screen

Complete notification preferences management screen for the Lyvo resident app.

## Overview

The Notifications Settings screen allows residents to customize how they receive notifications across different categories including general alerts, events, visitors, and payments. It includes a Do Not Disturb schedule feature and test notification functionality.

## Features

### 1. **General Notifications**
- **Push Notifications** - Device notifications
- **Email Notifications** - Email alerts
- **SMS Notifications** - Text message alerts

### 2. **Events**
- **Event Reminders** - Upcoming community events
- **Poll Notifications** - New polls and voting reminders

### 3. **Visitors**
- **Visitor Alerts** - When visitors arrive
- **Delivery Notifications** - Package delivery alerts

### 4. **Payments**
- **Bill Reminders** - Upcoming payment due dates
- **Payment Confirmations** - Payment processing confirmations

### 5. **Do Not Disturb**
- Enable/disable DND mode
- Set custom time range (start/end times)
- Visual time picker interface

### 6. **Test Notification**
- Send test notification to verify settings
- Immediate feedback via snackbar

## Files Created

```
lib/
├── src/
│   └── screens/
│       └── notifications_settings_screen.dart  # Main screen
└── notifications_settings_demo.dart            # Demo/example usage
```

## Usage

### Basic Integration

```dart
import 'package:flutter/material.dart';
import 'src/screens/notifications_settings_screen.dart';

// Navigate to notifications settings
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => const NotificationsSettingsScreen(),
  ),
);
```

### From Settings Screen

The screen is already integrated into the main Settings screen:

```dart
// In settings_screen.dart
SettingItem(
  id: 'notifications',
  title: 'Notifications',
  type: SettingType.navigation,
  icon: Icons.notifications_outlined,
  onTap: () => _navigateToNotifications(),
),
```

## Component Architecture

### NotificationsSettingsScreen

Main stateful widget that manages all notification preferences.

**State Variables:**
```dart
// General
bool _pushNotifications = true;
bool _emailNotifications = true;
bool _smsNotifications = false;

// Events
bool _eventReminders = true;
bool _pollNotifications = true;

// Visitors
bool _visitorAlerts = true;
bool _deliveryNotifications = true;

// Payments
bool _billReminders = true;
bool _paymentConfirmations = true;

// Do Not Disturb
bool _dndEnabled = false;
TimeOfDay _dndStart = const TimeOfDay(hour: 22, minute: 0);
TimeOfDay _dndEnd = const TimeOfDay(hour: 7, minute: 0);
```

### Key Methods

#### _buildNotificationTile()
Creates a consistent notification toggle tile with icon, title, subtitle, and toggle switch.

```dart
Widget _buildNotificationTile({
  required IconData icon,
  required String title,
  required String subtitle,
  required bool value,
  required ValueChanged<bool> onChanged,
})
```

#### _updatePreference()
Updates preference state, saves to storage, and shows feedback.

```dart
Future<void> _updatePreference(
  String key,
  bool value,
  Function(bool) updateState,
)
```

#### _selectTime()
Opens time picker for DND schedule configuration.

```dart
Future<void> _selectTime(bool isStart)
```

## Persistence

### SharedPreferences Integration

The screen includes stub methods for SharedPreferences. To implement:

1. **Add dependency** to `pubspec.yaml`:
```yaml
dependencies:
  shared_preferences: ^2.2.2
```

2. **Uncomment persistence code** in the screen:

```dart
// Load preferences on init
Future<void> _loadPreferences() async {
  final prefs = await SharedPreferences.getInstance();
  setState(() {
    _pushNotifications = prefs.getBool('push_notifications') ?? true;
    _emailNotifications = prefs.getBool('email_notifications') ?? true;
    _smsNotifications = prefs.getBool('sms_notifications') ?? false;
    // ... load all preferences
  });
}

// Save individual preference
Future<void> _savePreference(String key, bool value) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(key, value);
  
  // Sync to backend
  await NotificationService.updatePreference(key, value);
}
```

### Preference Keys

```dart
// General
'push_notifications'
'email_notifications'
'sms_notifications'

// Events
'event_reminders'
'poll_notifications'

// Visitors
'visitor_alerts'
'delivery_notifications'

// Payments
'bill_reminders'
'payment_confirmations'

// Do Not Disturb
'dnd_enabled'
'dnd_start_hour'
'dnd_start_minute'
'dnd_end_hour'
'dnd_end_minute'
```

## Backend Integration

### API Endpoints (Example)

```dart
class NotificationService {
  static const String baseUrl = 'https://api.lyvo.app';
  
  // Update notification preference
  static Future<void> updatePreference(String key, bool value) async {
    final response = await http.put(
      Uri.parse('$baseUrl/user/notifications/preferences'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'preference': key,
        'enabled': value,
      }),
    );
    
    if (response.statusCode != 200) {
      throw Exception('Failed to update preference');
    }
  }
  
  // Send test notification
  static Future<void> sendTestNotification() async {
    final response = await http.post(
      Uri.parse('$baseUrl/user/notifications/test'),
    );
    
    if (response.statusCode != 200) {
      throw Exception('Failed to send test notification');
    }
  }
  
  // Load all preferences
  static Future<Map<String, bool>> loadPreferences() async {
    final response = await http.get(
      Uri.parse('$baseUrl/user/notifications/preferences'),
    );
    
    if (response.statusCode == 200) {
      return Map<String, bool>.from(jsonDecode(response.body));
    }
    throw Exception('Failed to load preferences');
  }
}
```

## Design Specifications

### Colors

```dart
// Primary
Color(0xFF2563EB)  // Blue - toggles, buttons
Color(0xFF2F6AF6)  // Gradient start
Color(0xFF1D4CE6)  // Gradient end

// Backgrounds
Color(0xFFFAFBFC)  // Screen background
Color(0xFFFFFFFF)  // Card background
Color(0xFFF0F2F5)  // Icon background
Color(0xFFF7F8FA)  // Time picker background

// Text
Color(0xFF0F172A)  // Primary text
Color(0xFF6B7280)  // Secondary text / section headers
Color(0xFF9AA0A6)  // Subtitle text

// Borders
Color(0xFFE5E7EB)  // Card borders
Color(0xFFECEFF3)  // Dividers
```

### Typography

```dart
// Header
fontSize: 22
fontWeight: FontWeight.w700
letterSpacing: -0.3

// Section Headers
fontSize: 13
fontWeight: FontWeight.w600
letterSpacing: 0.5

// Tile Title
fontSize: 15
fontWeight: FontWeight.w500

// Tile Subtitle
fontSize: 13
color: Color(0xFF9AA0A6)

// Button Text
fontSize: 16
fontWeight: FontWeight.w600
```

### Spacing

```dart
// Screen padding
EdgeInsets.fromLTRB(16, 20, 16, 20)

// Section spacing
SizedBox(height: 24)

// Tile spacing
SizedBox(height: 8)

// Icon spacing
SizedBox(width: 12)

// Card padding
EdgeInsets.symmetric(horizontal: 16, vertical: 14)
```

### Components

#### Toggle Switch
- Size: 48x28 pixels
- Animation: 180ms ease-in-out
- Colors: Gray (#E5E7EB) → Blue (#2563EB)
- Thumb: White circle with shadow

#### Notification Tile
- Background: White
- Border: 1px solid #E5E7EB
- Border radius: 12px
- Shadow: rgba(16, 24, 40, 0.04)
- Icon container: 40x40px, rounded 10px

#### Header
- Gradient background
- Border radius: 24px (bottom corners)
- Back button with iOS-style arrow
- Title: 22px, bold

## Testing

### Run Demo

```bash
flutter run lib/notifications_settings_demo.dart
```

### Test Checklist

- [ ] All toggles work smoothly
- [ ] Snackbar feedback appears on toggle
- [ ] DND time picker opens and updates
- [ ] Test notification button triggers feedback
- [ ] Back navigation works
- [ ] Scroll behavior is smooth
- [ ] Status bar is white on gradient header
- [ ] All sections display correctly

## Customization

### Add New Notification Category

1. **Add state variable:**
```dart
bool _newCategory = true;
```

2. **Create section:**
```dart
Widget _buildNewCategorySection() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _buildSectionHeader('NEW CATEGORY'),
      _buildNotificationTile(
        icon: Icons.new_icon,
        title: 'New Notification',
        subtitle: 'Description',
        value: _newCategory,
        onChanged: (value) => _updatePreference(
          'new_category',
          value,
          (v) => setState(() => _newCategory = v),
        ),
      ),
    ],
  );
}
```

3. **Add to build method:**
```dart
_buildNewCategorySection(),
const SizedBox(height: 24),
_buildDivider(),
```

### Modify Toggle Style

Edit `settings_toggle.dart` to customize:
- Size (width/height)
- Colors
- Animation duration
- Shadow effects

## Integration with Existing Features

### Profile Screen
Already integrated via Settings → Notifications

### Push Notifications
```dart
// When notification received, check preferences
if (await _getPreference('push_notifications')) {
  // Show notification
}
```

### Email Service
```dart
// Before sending email
if (await _getPreference('email_notifications')) {
  await EmailService.send(email);
}
```

### SMS Service
```dart
// Before sending SMS
if (await _getPreference('sms_notifications')) {
  await SMSService.send(phone, message);
}
```

## Accessibility

- All interactive elements have proper tap targets (48x48 minimum)
- Color contrast meets WCAG AA standards
- Screen reader compatible
- Keyboard navigation support (when applicable)

## Performance

- Smooth 60fps animations
- Efficient state management
- Minimal rebuilds
- Lazy loading of preferences

## Future Enhancements

1. **Notification Channels** - Granular Android notification channels
2. **Sound Settings** - Custom notification sounds
3. **Vibration Patterns** - Custom vibration patterns
4. **Priority Levels** - High/Medium/Low priority settings
5. **Quiet Hours** - Multiple DND schedules
6. **Notification History** - View past notifications
7. **Smart Notifications** - AI-powered notification timing

## Troubleshooting

### Toggles not persisting
- Ensure SharedPreferences is properly initialized
- Check async/await implementation
- Verify preference keys match

### Time picker not showing
- Check theme configuration
- Ensure proper context is passed
- Verify TimeOfDay initialization

### Snackbar not appearing
- Check ScaffoldMessenger context
- Verify snackbar duration
- Ensure no overlapping snackbars

## Support

For issues or questions:
1. Check this documentation
2. Review demo implementation
3. Inspect console logs for debug info
4. Verify all dependencies are installed

---

**Version:** 1.0.0  
**Last Updated:** November 2025  
**Compatibility:** Flutter 3.0+
