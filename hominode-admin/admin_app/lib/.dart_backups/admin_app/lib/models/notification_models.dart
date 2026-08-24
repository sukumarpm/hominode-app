import 'package:flutter/material.dart';

enum NotificationType {
  visitor,
  complaint,
  payment,
  maintenance,
  announcement,
  event,
  security,
  general,
}

enum NotificationPriority {
  low,
  medium,
  high,
  urgent,
}

class NotificationModel {
  final String id;
  final String title;
  final String message;
  final NotificationType type;
  final NotificationPriority priority;
  final DateTime timestamp;
  final bool isRead;
  final String? actionUrl;
  final Map<String, dynamic>? metadata;

  NotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.priority,
    required this.timestamp,
    this.isRead = false,
    this.actionUrl,
    this.metadata,
  });

  NotificationModel copyWith({
    String? id,
    String? title,
    String? message,
    NotificationType? type,
    NotificationPriority? priority,
    DateTime? timestamp,
    bool? isRead,
    String? actionUrl,
    Map<String, dynamic>? metadata,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      type: type ?? this.type,
      priority: priority ?? this.priority,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      actionUrl: actionUrl ?? this.actionUrl,
      metadata: metadata ?? this.metadata,
    );
  }

  // Get icon based on notification type
  IconData get icon {
    switch (type) {
      case NotificationType.visitor:
        return Icons.person_add;
      case NotificationType.complaint:
        return Icons.report_problem;
      case NotificationType.payment:
        return Icons.payment;
      case NotificationType.maintenance:
        return Icons.build;
      case NotificationType.announcement:
        return Icons.campaign;
      case NotificationType.event:
        return Icons.event;
      case NotificationType.security:
        return Icons.security;
      case NotificationType.general:
        return Icons.notifications;
    }
  }

  // Get color based on notification type
  Color get color {
    switch (type) {
      case NotificationType.visitor:
        return const Color(0xFF10B981);
      case NotificationType.complaint:
        return const Color(0xFFEF4444);
      case NotificationType.payment:
        return const Color(0xFF2563EB);
      case NotificationType.maintenance:
        return const Color(0xFFF59E0B);
      case NotificationType.announcement:
        return const Color(0xFF8B5CF6);
      case NotificationType.event:
        return const Color(0xFF06B6D4);
      case NotificationType.security:
        return const Color(0xFFDC2626);
      case NotificationType.general:
        return const Color(0xFF6B7280);
    }
  }

  // Get background color based on notification type
  Color get backgroundColor {
    switch (type) {
      case NotificationType.visitor:
        return const Color(0xFFD1FAE5);
      case NotificationType.complaint:
        return const Color(0xFFFEE2E2);
      case NotificationType.payment:
        return const Color(0xFFDBEAFE);
      case NotificationType.maintenance:
        return const Color(0xFFFEF3C7);
      case NotificationType.announcement:
        return const Color(0xFFEDE9FE);
      case NotificationType.event:
        return const Color(0xFFCFFAFE);
      case NotificationType.security:
        return const Color(0xFFFEE2E2);
      case NotificationType.general:
        return const Color(0xFFF3F4F6);
    }
  }

  // Get priority color
  Color get priorityColor {
    switch (priority) {
      case NotificationPriority.low:
        return const Color(0xFF10B981);
      case NotificationPriority.medium:
        return const Color(0xFFF59E0B);
      case NotificationPriority.high:
        return const Color(0xFFEF4444);
      case NotificationPriority.urgent:
        return const Color(0xFFDC2626);
    }
  }

  // Get formatted time
  String get formattedTime {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }
}

// Sample notification data
class NotificationData {
  static List<NotificationModel> getSampleNotifications() {
    final now = DateTime.now();
    
    return [
      NotificationModel(
        id: '1',
        title: 'New Visitor Request',
        message: 'John Doe wants to visit A-204. Approval required.',
        type: NotificationType.visitor,
        priority: NotificationPriority.medium,
        timestamp: now.subtract(const Duration(minutes: 5)),
        metadata: {'flatNumber': 'A-204', 'visitorName': 'John Doe'},
      ),
      NotificationModel(
        id: '2',
        title: 'High Priority Complaint',
        message: 'Water leakage reported in B-301. Immediate attention required.',
        type: NotificationType.complaint,
        priority: NotificationPriority.urgent,
        timestamp: now.subtract(const Duration(minutes: 15)),
        metadata: {'complaintId': 'C-927', 'flatNumber': 'B-301'},
      ),
      NotificationModel(
        id: '3',
        title: 'Payment Received',
        message: 'Monthly maintenance payment received from C-102.',
        type: NotificationType.payment,
        priority: NotificationPriority.low,
        timestamp: now.subtract(const Duration(hours: 1)),
        isRead: true,
        metadata: {'amount': '₹5,500', 'flatNumber': 'C-102'},
      ),
      NotificationModel(
        id: '4',
        title: 'Maintenance Scheduled',
        message: 'Elevator maintenance scheduled for tomorrow 10 AM.',
        type: NotificationType.maintenance,
        priority: NotificationPriority.medium,
        timestamp: now.subtract(const Duration(hours: 2)),
        metadata: {'location': 'Building A', 'time': '10:00 AM'},
      ),
      NotificationModel(
        id: '5',
        title: 'New Announcement',
        message: 'Society meeting scheduled for next Sunday.',
        type: NotificationType.announcement,
        priority: NotificationPriority.medium,
        timestamp: now.subtract(const Duration(hours: 4)),
        isRead: true,
      ),
      NotificationModel(
        id: '6',
        title: 'Security Alert',
        message: 'Unauthorized vehicle detected in parking area.',
        type: NotificationType.security,
        priority: NotificationPriority.high,
        timestamp: now.subtract(const Duration(hours: 6)),
        metadata: {'location': 'Parking Area B', 'vehicleNumber': 'KA01AB1234'},
      ),
      NotificationModel(
        id: '7',
        title: 'Event Reminder',
        message: 'Diwali celebration tomorrow at 6 PM in community hall.',
        type: NotificationType.event,
        priority: NotificationPriority.low,
        timestamp: now.subtract(const Duration(days: 1)),
        isRead: true,
      ),
      NotificationModel(
        id: '8',
        title: 'Visitor Exit',
        message: 'Visitor has exited from D-405.',
        type: NotificationType.visitor,
        priority: NotificationPriority.low,
        timestamp: now.subtract(const Duration(days: 1, hours: 2)),
        isRead: true,
        metadata: {'flatNumber': 'D-405', 'visitorName': 'Sarah Wilson'},
      ),
    ];
  }
}