// lib/src/services/notifications_data_service.dart
// Mock data service for notifications

import 'package:flutter/material.dart';
import '../models/notification_item.dart';

class NotificationsDataService {
  // Mock data - replace with real API calls
  static List<NotificationItem> getMockNotifications() {
    return [
      NotificationItem(
        id: '1',
        title: 'Upcoming Event: Holi Celebration',
        description: 'Join us for Holi celebration on March 25th at 5:00 PM in the clubhouse',
        timestamp: '2 hours ago',
        type: NotificationType.event,
        isRead: false,
        icon: Icons.calendar_today,
        iconBgColor: const Color(0xFFE1BEE7), // Purple
      ),
      NotificationItem(
        id: '2',
        title: 'Water Supply Maintenance',
        description: 'Water supply will be interrupted on Nov 3rd from 10 AM to 2 PM for maintenance work.',
        timestamp: 'Oct 30, 2025',
        type: NotificationType.maintenance,
        isRead: false,
        icon: Icons.water_drop_outlined,
        iconBgColor: const Color(0xFFFFE0B2), // Orange
      ),
      NotificationItem(
        id: '3',
        title: 'Package Delivered',
        description: 'Your Amazon package has been delivered to the security office. Please collect it.',
        timestamp: 'Yesterday',
        type: NotificationType.delivery,
        isRead: true,
        icon: Icons.local_shipping_outlined,
        iconBgColor: const Color(0xFFC8E6C9), // Green
      ),
      NotificationItem(
        id: '4',
        title: 'Maintenance Bill Due',
        description: 'Your maintenance bill for November is due on Nov 5th. Amount: ₹5,500',
        timestamp: '2 days ago',
        type: NotificationType.payment,
        isRead: true,
        icon: Icons.payment,
        iconBgColor: const Color(0xFFFFCDD2), // Red
      ),
      NotificationItem(
        id: '5',
        title: 'Visitor Approved',
        description: 'Your visitor Amit Kumar has been approved by security and is on the way.',
        timestamp: '3 days ago',
        type: NotificationType.security,
        isRead: true,
        icon: Icons.person_add_outlined,
        iconBgColor: const Color(0xFFB3E5FC), // Light Blue
      ),
      NotificationItem(
        id: '6',
        title: 'Community Meeting',
        description: 'Monthly community meeting scheduled for Nov 10th at 7:00 PM in the clubhouse.',
        timestamp: '4 days ago',
        type: NotificationType.announcement,
        isRead: true,
        icon: Icons.groups_outlined,
        iconBgColor: const Color(0xFFF8BBD0), // Pink
      ),
      NotificationItem(
        id: '7',
        title: 'Gym Reopening',
        description: 'The community gym will reopen on Nov 1st after renovation. New timings: 6 AM - 10 PM',
        timestamp: '5 days ago',
        type: NotificationType.announcement,
        isRead: true,
        icon: Icons.fitness_center,
        iconBgColor: const Color(0xFFD1C4E9), // Light Purple
      ),
      NotificationItem(
        id: '8',
        title: 'Power Outage Notice',
        description: 'Scheduled power outage on Nov 2nd from 9 AM to 11 AM for electrical maintenance.',
        timestamp: '1 week ago',
        type: NotificationType.maintenance,
        isRead: true,
        icon: Icons.power_off,
        iconBgColor: const Color(0xFFFFE082), // Yellow
      ),
    ];
  }

  // Filter notifications by read status
  static List<NotificationItem> filterNotifications(
    List<NotificationItem> notifications,
    String filter,
  ) {
    switch (filter) {
      case 'Unread':
        return notifications.where((n) => !n.isRead).toList();
      case 'Read':
        return notifications.where((n) => n.isRead).toList();
      case 'All':
      default:
        return notifications;
    }
  }

  // Mark notification as read
  static Future<void> markAsRead(String notificationId) async {
    // TODO: Implement API call to mark notification as read
    await Future.delayed(const Duration(milliseconds: 300));
  }

  // Delete notification
  static Future<void> deleteNotification(String notificationId) async {
    // TODO: Implement API call to delete notification
    await Future.delayed(const Duration(milliseconds: 300));
  }
}
