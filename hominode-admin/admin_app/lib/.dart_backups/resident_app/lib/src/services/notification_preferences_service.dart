// lib/src/services/notification_preferences_service.dart
// Service for managing notification preferences

// import 'package:shared_preferences/shared_preferences.dart'; // Uncomment when ready to use
import 'package:flutter/material.dart';

/// Service to manage notification preferences
/// Handles local storage and provides helper methods
class NotificationPreferencesService {
  // Singleton pattern
  static final NotificationPreferencesService _instance =
      NotificationPreferencesService._internal();
  factory NotificationPreferencesService() => _instance;
  NotificationPreferencesService._internal();

  // In-memory storage (replace with SharedPreferences when ready)
  final Map<String, dynamic> _preferences = {
    'push_notifications': true,
    'email_notifications': true,
    'sms_notifications': false,
    'event_reminders': true,
    'poll_notifications': true,
    'visitor_alerts': true,
    'delivery_notifications': true,
    'bill_reminders': true,
    'payment_confirmations': true,
    'dnd_enabled': false,
    'dnd_start_hour': 22,
    'dnd_start_minute': 0,
    'dnd_end_hour': 7,
    'dnd_end_minute': 0,
  };

  // Preference keys
  static const String _pushNotifications = 'push_notifications';
  static const String _emailNotifications = 'email_notifications';
  static const String _smsNotifications = 'sms_notifications';
  static const String _eventReminders = 'event_reminders';
  static const String _pollNotifications = 'poll_notifications';
  static const String _visitorAlerts = 'visitor_alerts';
  static const String _deliveryNotifications = 'delivery_notifications';
  static const String _billReminders = 'bill_reminders';
  static const String _paymentConfirmations = 'payment_confirmations';
  static const String _dndEnabled = 'dnd_enabled';
  static const String _dndStartHour = 'dnd_start_hour';
  static const String _dndStartMinute = 'dnd_start_minute';
  static const String _dndEndHour = 'dnd_end_hour';
  static const String _dndEndMinute = 'dnd_end_minute';

  /// Get all notification preferences
  Future<Map<String, dynamic>> getAllPreferences() async {
    // TODO: Replace with SharedPreferences when ready
    // final prefs = await SharedPreferences.getInstance();
    return Map<String, dynamic>.from(_preferences);
  }

  /// Check if push notifications are enabled
  Future<bool> isPushEnabled() async {
    return _preferences[_pushNotifications] as bool? ?? true;
  }

  /// Check if email notifications are enabled
  Future<bool> isEmailEnabled() async {
    return _preferences[_emailNotifications] as bool? ?? true;
  }

  /// Check if SMS notifications are enabled
  Future<bool> isSMSEnabled() async {
    return _preferences[_smsNotifications] as bool? ?? false;
  }

  /// Check if event reminders are enabled
  Future<bool> areEventRemindersEnabled() async {
    return _preferences[_eventReminders] as bool? ?? true;
  }

  /// Check if poll notifications are enabled
  Future<bool> arePollNotificationsEnabled() async {
    return _preferences[_pollNotifications] as bool? ?? true;
  }

  /// Check if visitor alerts are enabled
  Future<bool> areVisitorAlertsEnabled() async {
    return _preferences[_visitorAlerts] as bool? ?? true;
  }

  /// Check if delivery notifications are enabled
  Future<bool> areDeliveryNotificationsEnabled() async {
    return _preferences[_deliveryNotifications] as bool? ?? true;
  }

  /// Check if bill reminders are enabled
  Future<bool> areBillRemindersEnabled() async {
    return _preferences[_billReminders] as bool? ?? true;
  }

  /// Check if payment confirmations are enabled
  Future<bool> arePaymentConfirmationsEnabled() async {
    return _preferences[_paymentConfirmations] as bool? ?? true;
  }

  /// Check if Do Not Disturb is currently active
  Future<bool> isInDoNotDisturb() async {
    final dndEnabled = _preferences[_dndEnabled] as bool? ?? false;

    if (!dndEnabled) return false;

    final now = TimeOfDay.now();
    final startHour = _preferences[_dndStartHour] as int? ?? 22;
    final startMinute = _preferences[_dndStartMinute] as int? ?? 0;
    final endHour = _preferences[_dndEndHour] as int? ?? 7;
    final endMinute = _preferences[_dndEndMinute] as int? ?? 0;

    return _isTimeInRange(
      now,
      TimeOfDay(hour: startHour, minute: startMinute),
      TimeOfDay(hour: endHour, minute: endMinute),
    );
  }

  /// Check if current time is within DND range
  bool _isTimeInRange(TimeOfDay current, TimeOfDay start, TimeOfDay end) {
    final currentMinutes = current.hour * 60 + current.minute;
    final startMinutes = start.hour * 60 + start.minute;
    final endMinutes = end.hour * 60 + end.minute;

    // Handle overnight range (e.g., 22:00 to 07:00)
    if (startMinutes > endMinutes) {
      return currentMinutes >= startMinutes || currentMinutes <= endMinutes;
    }

    // Handle same-day range (e.g., 13:00 to 17:00)
    return currentMinutes >= startMinutes && currentMinutes <= endMinutes;
  }

  /// Check if notification should be sent based on type and preferences
  Future<bool> shouldSendNotification(NotificationType type) async {
    // Check DND first
    if (await isInDoNotDisturb()) {
      return false;
    }

    // Check specific notification type
    switch (type) {
      case NotificationType.event:
        return await areEventRemindersEnabled();
      case NotificationType.poll:
        return await arePollNotificationsEnabled();
      case NotificationType.visitor:
        return await areVisitorAlertsEnabled();
      case NotificationType.delivery:
        return await areDeliveryNotificationsEnabled();
      case NotificationType.bill:
        return await areBillRemindersEnabled();
      case NotificationType.payment:
        return await arePaymentConfirmationsEnabled();
      case NotificationType.general:
        return await isPushEnabled();
    }
  }

  /// Save a boolean preference
  Future<void> savePreference(String key, bool value) async {
    _preferences[key] = value;
    
    // TODO: Replace with SharedPreferences when ready
    // final prefs = await SharedPreferences.getInstance();
    // await prefs.setBool(key, value);

    // TODO: Sync to backend
    // await _syncToBackend(key, value);
  }

  /// Save a time preference
  Future<void> saveTimePreference(String key, int value) async {
    _preferences[key] = value;
    
    // TODO: Replace with SharedPreferences when ready
    // final prefs = await SharedPreferences.getInstance();
    // await prefs.setInt(key, value);

    // TODO: Sync to backend
    // await _syncToBackend(key, value);
  }

  /// Reset all preferences to defaults
  Future<void> resetToDefaults() async {
    _preferences[_pushNotifications] = true;
    _preferences[_emailNotifications] = true;
    _preferences[_smsNotifications] = false;
    _preferences[_eventReminders] = true;
    _preferences[_pollNotifications] = true;
    _preferences[_visitorAlerts] = true;
    _preferences[_deliveryNotifications] = true;
    _preferences[_billReminders] = true;
    _preferences[_paymentConfirmations] = true;
    _preferences[_dndEnabled] = false;
    _preferences[_dndStartHour] = 22;
    _preferences[_dndStartMinute] = 0;
    _preferences[_dndEndHour] = 7;
    _preferences[_dndEndMinute] = 0;
  }

  /// Sync preferences to backend (stub - implement with your API)
  Future<void> _syncToBackend(String key, dynamic value) async {
    // TODO: Implement backend sync
    // Example:
    // final response = await http.put(
    //   Uri.parse('$baseUrl/api/user/notifications/preferences'),
    //   body: jsonEncode({'preference': key, 'value': value}),
    // );
    print('Syncing to backend: $key = $value');
  }
}

/// Notification types for categorization
enum NotificationType {
  general,
  event,
  poll,
  visitor,
  delivery,
  bill,
  payment,
}

/// Extension to get notification channel for each type
extension NotificationTypeExtension on NotificationType {
  String get channelId {
    switch (this) {
      case NotificationType.general:
        return 'general_notifications';
      case NotificationType.event:
        return 'event_notifications';
      case NotificationType.poll:
        return 'poll_notifications';
      case NotificationType.visitor:
        return 'visitor_notifications';
      case NotificationType.delivery:
        return 'delivery_notifications';
      case NotificationType.bill:
        return 'bill_notifications';
      case NotificationType.payment:
        return 'payment_notifications';
    }
  }

  String get channelName {
    switch (this) {
      case NotificationType.general:
        return 'General Notifications';
      case NotificationType.event:
        return 'Event Reminders';
      case NotificationType.poll:
        return 'Poll Notifications';
      case NotificationType.visitor:
        return 'Visitor Alerts';
      case NotificationType.delivery:
        return 'Delivery Notifications';
      case NotificationType.bill:
        return 'Bill Reminders';
      case NotificationType.payment:
        return 'Payment Confirmations';
    }
  }

  String get channelDescription {
    switch (this) {
      case NotificationType.general:
        return 'General app notifications';
      case NotificationType.event:
        return 'Reminders for upcoming community events';
      case NotificationType.poll:
        return 'Notifications about new polls and voting';
      case NotificationType.visitor:
        return 'Alerts when visitors arrive';
      case NotificationType.delivery:
        return 'Notifications for package deliveries';
      case NotificationType.bill:
        return 'Reminders for upcoming bill payments';
      case NotificationType.payment:
        return 'Confirmations when payments are processed';
    }
  }
}
