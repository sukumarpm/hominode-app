// lib/src/services/notification_preferences_service.dart
// Service for managing notification preferences

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hominode_notifications/hominode_notifications.dart';

/// Service to manage notification preferences
/// Handles local storage and provides helper methods
class NotificationPreferencesService {
  // Singleton pattern
  static final NotificationPreferencesService _instance =
      NotificationPreferencesService._internal();
  factory NotificationPreferencesService() => _instance;
  NotificationPreferencesService._internal()
    : _currentUid = (() => FirebaseAuth.instance.currentUser?.uid),
      _refreshRegistration =
          HominodePushNotifications.instance.refreshRegistration;

  @visibleForTesting
  NotificationPreferencesService.forTesting({
    required String? Function() currentUid,
    required Future<void> Function() refreshRegistration,
  }) : _currentUid = currentUid,
       _refreshRegistration = refreshRegistration;
  final String? Function() _currentUid;
  final Future<void> Function() _refreshRegistration;

  // Defaults; persisted values are scoped to the signed-in resident.
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
    final uid = _currentUid();
    if (uid == null) return Map<String, dynamic>.from(_preferences);
    final store = await SharedPreferences.getInstance();
    return {
      for (final entry in _preferences.entries)
        entry.key: store.get('notifications/$uid/${entry.key}') ?? entry.value,
    };
  }

  /// Check if push notifications are enabled
  Future<bool> isPushEnabled() async {
    return (await getAllPreferences())[_pushNotifications] as bool? ?? true;
  }

  /// Check if email notifications are enabled
  Future<bool> isEmailEnabled() async {
    return (await getAllPreferences())[_emailNotifications] as bool? ?? true;
  }

  /// Check if SMS notifications are enabled
  Future<bool> isSMSEnabled() async {
    return (await getAllPreferences())[_smsNotifications] as bool? ?? false;
  }

  /// Check if event reminders are enabled
  Future<bool> areEventRemindersEnabled() async {
    return (await getAllPreferences())[_eventReminders] as bool? ?? true;
  }

  /// Check if poll notifications are enabled
  Future<bool> arePollNotificationsEnabled() async {
    return (await getAllPreferences())[_pollNotifications] as bool? ?? true;
  }

  /// Check if visitor alerts are enabled
  Future<bool> areVisitorAlertsEnabled() async {
    return (await getAllPreferences())[_visitorAlerts] as bool? ?? true;
  }

  /// Check if delivery notifications are enabled
  Future<bool> areDeliveryNotificationsEnabled() async {
    return (await getAllPreferences())[_deliveryNotifications] as bool? ?? true;
  }

  /// Check if bill reminders are enabled
  Future<bool> areBillRemindersEnabled() async {
    return (await getAllPreferences())[_billReminders] as bool? ?? true;
  }

  /// Check if payment confirmations are enabled
  Future<bool> arePaymentConfirmationsEnabled() async {
    return (await getAllPreferences())[_paymentConfirmations] as bool? ?? true;
  }

  /// Check if Do Not Disturb is currently active
  Future<bool> isInDoNotDisturb() async {
    final preferences = await getAllPreferences();
    final dndEnabled = preferences[_dndEnabled] as bool? ?? false;

    if (!dndEnabled) return false;

    final now = TimeOfDay.now();
    final startHour = preferences[_dndStartHour] as int? ?? 22;
    final startMinute = preferences[_dndStartMinute] as int? ?? 0;
    final endHour = preferences[_dndEndHour] as int? ?? 7;
    final endMinute = preferences[_dndEndMinute] as int? ?? 0;

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
    if (_preferences[key] is! bool) {
      throw ArgumentError('Invalid notification preference.');
    }
    final uid = _currentUid();
    if (uid == null) {
      throw StateError('Sign in to update notification preferences.');
    }
    final store = await SharedPreferences.getInstance();
    final path = 'notifications/$uid/$key';
    final old = store.getBool(path);
    await store.setBool(path, value);
    try {
      if (key != _emailNotifications && key != _smsNotifications) {
        await _refreshRegistration();
      }
    } catch (_) {
      if (old == null) {
        await store.remove(path);
      } else {
        await store.setBool(path, old);
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> registrationPreferences() async {
    final values = await getAllPreferences();
    return {
      for (final key in [
        'push_notifications',
        'event_reminders',
        'dnd_enabled',
        'dnd_start_hour',
        'dnd_start_minute',
        'dnd_end_hour',
        'dnd_end_minute',
      ])
        key: values[key],
      'timezone_offset_minutes': DateTime.now().timeZoneOffset.inMinutes,
    };
  }

  /// Save DND times and synchronize the existing registered device.
  Future<void> saveTimePreference(String key, int value) async {
    if (![
          _dndStartHour,
          _dndEndHour,
          _dndStartMinute,
          _dndEndMinute,
        ].contains(key) ||
        value < 0 ||
        value > (key.endsWith('hour') ? 23 : 59)) {
      throw ArgumentError('Invalid notification time.');
    }
    final uid = _currentUid();
    if (uid == null) {
      throw StateError('Sign in to update notification preferences.');
    }
    final store = await SharedPreferences.getInstance();
    final path = 'notifications/$uid/$key';
    final old = store.getInt(path);
    await store.setInt(path, value);
    try {
      await _refreshRegistration();
    } catch (_) {
      if (old == null) {
        await store.remove(path);
      } else {
        await store.setInt(path, old);
      }
      rethrow;
    }
  }

  Future<void> resetToDefaults() async {
    for (final entry in _preferences.entries) {
      if (entry.value is bool) {
        await savePreference(entry.key, entry.value as bool);
      } else {
        await saveTimePreference(entry.key, entry.value as int);
      }
    }
  }
}

/// Notification types for categorization
enum NotificationType { general, event, poll, visitor, delivery, bill, payment }

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
