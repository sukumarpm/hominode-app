# Notifications Settings - Quick Integration Guide

## ✅ What's Been Created

1. **NotificationsSettingsScreen** - Full-featured notification preferences screen
2. **Demo App** - Standalone demo to test the feature
3. **Integration** - Already connected to Settings screen
4. **Documentation** - Complete README with all details

## 🚀 Quick Start

### 1. Test the Feature

Run the demo to see it in action:

```bash
flutter run lib/notifications_settings_demo.dart
```

### 2. Access from Settings

The screen is already integrated! Navigate:
```
Profile → Settings → Notifications
```

### 3. Add SharedPreferences (Required)

Add to `pubspec.yaml`:
```yaml
dependencies:
  shared_preferences: ^2.2.2
```

Then run:
```bash
flutter pub get
```

### 4. Enable Persistence

Uncomment the SharedPreferences code in `notifications_settings_screen.dart`:

**In `_loadPreferences()` method:**
```dart
Future<void> _loadPreferences() async {
  final prefs = await SharedPreferences.getInstance();
  setState(() {
    _pushNotifications = prefs.getBool('push_notifications') ?? true;
    _emailNotifications = prefs.getBool('email_notifications') ?? true;
    _smsNotifications = prefs.getBool('sms_notifications') ?? false;
    _eventReminders = prefs.getBool('event_reminders') ?? true;
    _pollNotifications = prefs.getBool('poll_notifications') ?? true;
    _visitorAlerts = prefs.getBool('visitor_alerts') ?? true;
    _deliveryNotifications = prefs.getBool('delivery_notifications') ?? true;
    _billReminders = prefs.getBool('bill_reminders') ?? true;
    _paymentConfirmations = prefs.getBool('payment_confirmations') ?? true;
    _dndEnabled = prefs.getBool('dnd_enabled') ?? false;
    _dndStart = TimeOfDay(
      hour: prefs.getInt('dnd_start_hour') ?? 22,
      minute: prefs.getInt('dnd_start_minute') ?? 0,
    );
    _dndEnd = TimeOfDay(
      hour: prefs.getInt('dnd_end_hour') ?? 7,
      minute: prefs.getInt('dnd_end_minute') ?? 0,
    );
  });
}
```

**In `_savePreference()` method:**
```dart
Future<void> _savePreference(String key, bool value) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(key, value);
  
  // TODO: Sync to backend
  // await NotificationService.updatePreference(key, value);
}
```

**In `_saveTimePreference()` method:**
```dart
Future<void> _saveTimePreference(String key, int value) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setInt(key, value);
}
```

## 🎨 Features Included

### Notification Categories

✅ **General**
- Push Notifications
- Email Notifications  
- SMS Notifications

✅ **Events**
- Event Reminders
- Poll Notifications

✅ **Visitors**
- Visitor Alerts
- Delivery Notifications

✅ **Payments**
- Bill Reminders
- Payment Confirmations

✅ **Do Not Disturb**
- Enable/Disable toggle
- Custom time range picker
- Visual time display

✅ **Test Notification**
- Send test notification button
- Immediate feedback

## 🔧 Backend Integration

### Create Notification Service

Create `lib/src/services/notification_service.dart`:

```dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  static const String baseUrl = 'YOUR_API_BASE_URL';
  
  // Update preference on backend
  static Future<void> updatePreference(String key, bool value) async {
    try {
      final token = await _getAuthToken();
      final response = await http.put(
        Uri.parse('$baseUrl/api/user/notifications/preferences'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'preference': key,
          'enabled': value,
        }),
      );
      
      if (response.statusCode != 200) {
        print('Failed to update preference: ${response.body}');
      }
    } catch (e) {
      print('Error updating preference: $e');
    }
  }
  
  // Send test notification
  static Future<void> sendTestNotification() async {
    try {
      final token = await _getAuthToken();
      final response = await http.post(
        Uri.parse('$baseUrl/api/user/notifications/test'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );
      
      if (response.statusCode != 200) {
        print('Failed to send test notification: ${response.body}');
      }
    } catch (e) {
      print('Error sending test notification: $e');
    }
  }
  
  // Load preferences from backend
  static Future<Map<String, dynamic>> loadPreferences() async {
    try {
      final token = await _getAuthToken();
      final response = await http.get(
        Uri.parse('$baseUrl/api/user/notifications/preferences'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print('Error loading preferences: $e');
    }
    return {};
  }
  
  static Future<String> _getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token') ?? '';
  }
}
```

### Update Screen to Use Service

In `notifications_settings_screen.dart`, replace TODO comments:

```dart
// In _savePreference()
await NotificationService.updatePreference(key, value);

// In _sendTestNotification()
await NotificationService.sendTestNotification();

// In _loadPreferences()
final backendPrefs = await NotificationService.loadPreferences();
// Merge with local preferences
```

## 📱 Using Preferences in Your App

### Check Before Sending Notifications

```dart
import 'package:shared_preferences/shared_preferences.dart';

Future<bool> shouldSendPushNotification() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool('push_notifications') ?? true;
}

Future<bool> shouldSendEmail() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool('email_notifications') ?? true;
}

Future<bool> shouldSendSMS() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool('sms_notifications') ?? false;
}

// Check DND status
Future<bool> isInDoNotDisturb() async {
  final prefs = await SharedPreferences.getInstance();
  final dndEnabled = prefs.getBool('dnd_enabled') ?? false;
  
  if (!dndEnabled) return false;
  
  final now = TimeOfDay.now();
  final startHour = prefs.getInt('dnd_start_hour') ?? 22;
  final startMinute = prefs.getInt('dnd_start_minute') ?? 0;
  final endHour = prefs.getInt('dnd_end_hour') ?? 7;
  final endMinute = prefs.getInt('dnd_end_minute') ?? 0;
  
  // Check if current time is within DND range
  // Implementation depends on your DND logic
  return _isTimeInRange(now, startHour, startMinute, endHour, endMinute);
}
```

### Example: Sending Event Notification

```dart
Future<void> sendEventNotification(Event event) async {
  final prefs = await SharedPreferences.getInstance();
  
  // Check if event reminders are enabled
  if (prefs.getBool('event_reminders') ?? true) {
    // Check if in DND mode
    if (!await isInDoNotDisturb()) {
      // Send push notification
      if (prefs.getBool('push_notifications') ?? true) {
        await PushNotificationService.send(
          title: 'Upcoming Event',
          body: event.title,
        );
      }
      
      // Send email
      if (prefs.getBool('email_notifications') ?? true) {
        await EmailService.send(
          subject: 'Event Reminder: ${event.title}',
          body: event.description,
        );
      }
    }
  }
}
```

## 🎯 Testing Checklist

- [ ] Run demo app successfully
- [ ] Navigate from Settings → Notifications
- [ ] Toggle all switches - verify smooth animation
- [ ] Check snackbar feedback appears
- [ ] Open DND time picker
- [ ] Select start and end times
- [ ] Verify time display updates
- [ ] Click "Send Test Notification"
- [ ] Verify feedback message
- [ ] Navigate back to Settings
- [ ] Re-open Notifications - verify state persists (after SharedPreferences)

## 🔍 Verification

### Check Integration

1. **Settings Screen** - Notifications option should be visible
2. **Navigation** - Tapping should open Notifications Settings
3. **UI** - Should match app's blue gradient theme
4. **Toggles** - Should animate smoothly (180ms)
5. **Feedback** - Snackbars should appear on changes

### Console Output

When testing, you should see:
```
💾 Saved push_notifications: true
💾 Saved email_notifications: false
🔔 Test Notification Sent
Push: true
Email: false
SMS: false
```

## 📚 Additional Resources

- **Full Documentation**: `NOTIFICATIONS_SETTINGS_README.md`
- **Demo App**: `lib/notifications_settings_demo.dart`
- **Main Screen**: `lib/src/screens/notifications_settings_screen.dart`
- **Toggle Component**: `lib/src/components/settings_toggle.dart`

## 🐛 Common Issues

### Issue: Preferences not persisting
**Solution**: Ensure SharedPreferences code is uncommented and `flutter pub get` was run

### Issue: Time picker not themed correctly
**Solution**: Theme is already configured in `_selectTime()` method

### Issue: Navigation not working
**Solution**: Import is already added to `settings_screen.dart`

### Issue: Toggles not animating
**Solution**: `SettingsToggle` component is already implemented with animations

## ✨ Next Steps

1. **Add SharedPreferences** dependency
2. **Uncomment persistence code**
3. **Create backend API endpoints**
4. **Implement NotificationService**
5. **Test with real notifications**
6. **Add analytics tracking** (optional)

## 🎉 You're Done!

The Notifications Settings screen is fully functional and ready to use. Just add SharedPreferences and connect to your backend API.

---

**Need Help?** Check `NOTIFICATIONS_SETTINGS_README.md` for detailed documentation.
