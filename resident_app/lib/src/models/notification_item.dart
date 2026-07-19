// lib/src/models/notification_item.dart
// Notification item model

import 'package:flutter/material.dart';

enum NotificationType {
  event,
  maintenance,
  delivery,
  payment,
  security,
  announcement,
}

class NotificationItem {
  final String id;
  final String title;
  final String description;
  final String timestamp;
  final NotificationType type;
  final bool isRead;
  final IconData icon;
  final Color iconBgColor;

  NotificationItem({
    required this.id,
    required this.title,
    required this.description,
    required this.timestamp,
    required this.type,
    this.isRead = false,
    required this.icon,
    required this.iconBgColor,
  });

  NotificationItem copyWith({
    String? id,
    String? title,
    String? description,
    String? timestamp,
    NotificationType? type,
    bool? isRead,
    IconData? icon,
    Color? iconBgColor,
  }) {
    return NotificationItem(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      timestamp: timestamp ?? this.timestamp,
      type: type ?? this.type,
      isRead: isRead ?? this.isRead,
      icon: icon ?? this.icon,
      iconBgColor: iconBgColor ?? this.iconBgColor,
    );
  }
}
