import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/security_user_model.dart';

class ShiftTime {
  final int hour;
  final int minute;

  ShiftTime({required this.hour, required this.minute});

  @override
  String toString() =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Check if user is within shift timing
  bool isWithinShiftTiming(String? shiftTiming) {
    if (shiftTiming == null || shiftTiming.isEmpty) {
      return false;
    }

    try {
      // Parse shift timing format: "HH:MM - HH:MM" or "Morning Shift (6 AM - 2 PM)"
      final now = DateTime.now();
      final currentTime = ShiftTime(hour: now.hour, minute: now.minute);

      // Extract times from various formats
      final times = _parseShiftTiming(shiftTiming);
      if (times == null) return false;

      final startTime = times['start'] as ShiftTime;
      final endTime = times['end'] as ShiftTime;

      // Convert to minutes for easier comparison
      final currentMinutes = currentTime.hour * 60 + currentTime.minute;
      final startMinutes = startTime.hour * 60 + startTime.minute;
      final endMinutes = endTime.hour * 60 + endTime.minute;

      // Handle overnight shifts (e.g., 10 PM - 6 AM)
      if (startMinutes > endMinutes) {
        return currentMinutes >= startMinutes || currentMinutes < endMinutes;
      }

      return currentMinutes >= startMinutes && currentMinutes < endMinutes;
    } catch (e) {
      print('Error checking shift timing: $e');
      return false;
    }
  }

  /// Parse shift timing string and return start and end times
  Map<String, ShiftTime>? _parseShiftTiming(String shiftTiming) {
    try {
      // Try to extract times from format like "6 AM - 2 PM" or "06:00 - 14:00"
      final regex = RegExp(
        r'(\d{1,2}):?(\d{2})?\s*(AM|PM|am|pm)?\s*-\s*(\d{1,2}):?(\d{2})?\s*(AM|PM|am|pm)?',
      );
      final match = regex.firstMatch(shiftTiming);

      if (match != null) {
        final startHour = int.parse(match.group(1)!);
        final startMinute = int.parse(match.group(2) ?? '0');
        final startPeriod = match.group(3)?.toUpperCase() ?? '';

        final endHour = int.parse(match.group(4)!);
        final endMinute = int.parse(match.group(5) ?? '0');
        final endPeriod = match.group(6)?.toUpperCase() ?? '';

        // Convert to 24-hour format
        int start24Hour = startHour;
        int end24Hour = endHour;

        if (startPeriod == 'PM' && startHour != 12) {
          start24Hour = startHour + 12;
        } else if (startPeriod == 'AM' && startHour == 12) {
          start24Hour = 0;
        }

        if (endPeriod == 'PM' && endHour != 12) {
          end24Hour = endHour + 12;
        } else if (endPeriod == 'AM' && endHour == 12) {
          end24Hour = 0;
        }

        return {
          'start': ShiftTime(hour: start24Hour, minute: startMinute),
          'end': ShiftTime(hour: end24Hour, minute: endMinute),
        };
      }
    } catch (e) {
      print('Error parsing shift timing: $e');
    }
    return null;
  }

  /// Get shift status notification
  Map<String, dynamic> getShiftStatusNotification(SecurityUserModel user) {
    final isWithinShift = isWithinShiftTiming(user.shiftTiming);
    final shiftTiming = user.shiftTiming ?? 'No Shift Assigned';

    if (isWithinShift) {
      return {
        'type': 'shift_active',
        'title': 'Shift Active',
        'message': 'You are currently within your shift: $shiftTiming',
        'icon': 'schedule',
        'color': 'success',
        'priority': 'low',
      };
    } else {
      return {
        'type': 'shift_inactive',
        'title': 'Outside Shift Hours',
        'message': 'Your shift is: $shiftTiming',
        'icon': 'schedule',
        'color': 'warning',
        'priority': 'medium',
      };
    }
  }

  /// Get gate assignment notification
  Map<String, dynamic> getGateAssignmentNotification(SecurityUserModel user) {
    final gate = user.displayGate;

    if (gate == 'Not Assigned') {
      return {
        'type': 'gate_not_assigned',
        'title': 'Gate Not Assigned',
        'message': 'Please contact admin to assign a gate',
        'icon': 'location_on',
        'color': 'error',
        'priority': 'high',
      };
    } else {
      return {
        'type': 'gate_assigned',
        'title': 'Gate Assignment',
        'message': 'You are assigned to: $gate',
        'icon': 'location_on',
        'color': 'success',
        'priority': 'low',
      };
    }
  }

  /// Get all notifications for user based on flow function
  List<Map<String, dynamic>> getUserNotifications(SecurityUserModel user) {
    final notifications = <Map<String, dynamic>>[];

    // Add gate assignment notification
    notifications.add(getGateAssignmentNotification(user));

    // Add shift status notification
    notifications.add(getShiftStatusNotification(user));

    // Sort by priority (high > medium > low)
    const priorityOrder = {'high': 0, 'medium': 1, 'low': 2};
    notifications.sort((a, b) {
      final priorityA = priorityOrder[a['priority']] ?? 3;
      final priorityB = priorityOrder[b['priority']] ?? 3;
      return priorityA.compareTo(priorityB);
    });

    return notifications;
  }

  /// Log notification event to Firestore
  Future<void> logNotification(
    String userId,
    String notificationType,
    String message,
  ) async {
    try {
      await _firestore.collection('notifications').add({
        'userId': userId,
        'type': notificationType,
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      });
    } catch (e) {
      print('Error logging notification: $e');
    }
  }

  /// Get unread notifications for user
  Stream<QuerySnapshot> getUnreadNotifications(String userId) {
    return _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .where('read', isEqualTo: false)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  /// Mark notification as read
  Future<void> markNotificationAsRead(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).update({
        'read': true,
      });
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }
}
