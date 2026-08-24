import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../models/notification_models.dart';
import 'admin_tenant_context.dart';

class NotificationService extends ChangeNotifier {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  List<NotificationModel> _notifications = [];
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StreamSubscription? _notificationSubscription;

  List<NotificationModel> get notifications => _notifications;

  // Get unread notifications count
  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  // Get notifications by type
  List<NotificationModel> getNotificationsByType(NotificationType type) {
    return _notifications.where((n) => n.type == type).toList();
  }

  // Get notifications by priority
  List<NotificationModel> getNotificationsByPriority(
    NotificationPriority priority,
  ) {
    return _notifications.where((n) => n.priority == priority).toList();
  }

  // Initialize with REAL data from Firestore
  void initializeNotifications() {
    try {
      print('🔵 NOTIFICATIONS INIT: Starting...');

      // STEP 1: Validate Admin Authentication
      print('🔐 STEP 1: Validating admin authentication...');
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('⚠️ STEP 1 WARNING: No user logged in');
        _notifications = [];
        notifyListeners();
        return;
      }
      print('✅ STEP 1 PASSED: Admin authenticated');
      final communityId = AdminTenantContext.instance.requireCommunityId();

      // STEP 2: Set up real-time listener for Firestore notifications
      print('📋 STEP 2: Setting up Firestore listener...');
      _notificationSubscription = _firestore
          .collection('notifications')
          .where('communityId', isEqualTo: communityId)
          .orderBy('timestamp', descending: true)
          .limit(50)
          .snapshots()
          .listen(
            (snapshot) {
              print('✅ STEP 2 PASSED: Firestore listener active');

              // STEP 3: Transform Firestore data to NotificationModel
              print('📝 STEP 3: Transforming notification data...');
              _notifications = snapshot.docs.map((doc) {
                final data = doc.data();
                return NotificationModel(
                  id: doc.id,
                  title: data['title'] ?? 'Notification',
                  message: data['message'] ?? '',
                  type: _parseNotificationType(data['type'] ?? 'general'),
                  priority: _parseNotificationPriority(
                    data['priority'] ?? 'medium',
                  ),
                  timestamp:
                      (data['timestamp'] as Timestamp?)?.toDate() ??
                      DateTime.now(),
                  isRead: data['isRead'] ?? false,
                  actionUrl: data['actionUrl'],
                  metadata: data['metadata'],
                );
              }).toList();
              print('✅ STEP 3 PASSED: Data transformed');

              // STEP 4: Sort and notify listeners
              print('🔔 STEP 4: Sorting and notifying...');
              _sortNotifications();
              notifyListeners();
              print('✅ NOTIFICATIONS INIT: COMPLETE');
            },
            onError: (error) {
              print('❌ ERROR: $error');
              _notifications = [];
              notifyListeners();
            },
          );
    } catch (e) {
      print('❌ ERROR: $e');
      _notifications = [];
      notifyListeners();
    }
  }

  NotificationType _parseNotificationType(String type) {
    try {
      return NotificationType.values.firstWhere(
        (e) => e.name == type.toLowerCase(),
        orElse: () => NotificationType.general,
      );
    } catch (e) {
      return NotificationType.general;
    }
  }

  NotificationPriority _parseNotificationPriority(String priority) {
    try {
      return NotificationPriority.values.firstWhere(
        (e) => e.name == priority.toLowerCase(),
        orElse: () => NotificationPriority.medium,
      );
    } catch (e) {
      return NotificationPriority.medium;
    }
  }

  // Add new notification to Firestore
  Future<void> addNotification(NotificationModel notification) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final communityId = AdminTenantContext.instance.requireCommunityId();

      await _firestore.collection('notifications').add({
        'adminId': user.uid,
        'communityId': communityId,
        'title': notification.title,
        'message': notification.message,
        'type': notification.type.name,
        'priority': notification.priority.name,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'actionUrl': notification.actionUrl,
        'metadata': notification.metadata,
      });
    } catch (e) {
      print('Error adding notification: $e');
    }
  }

  // Mark notification as read in Firestore
  Future<void> markAsRead(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).update({
        'isRead': true,
      });
    } catch (e) {
      print('Error marking as read: $e');
    }
  }

  // Mark all notifications as read in Firestore
  Future<void> markAllAsRead() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final batch = _firestore.batch();
      for (final notification in _notifications.where((n) => !n.isRead)) {
        batch.update(
          _firestore.collection('notifications').doc(notification.id),
          {'isRead': true},
        );
      }
      await batch.commit();
    } catch (e) {
      print('Error marking all as read: $e');
    }
  }

  // Delete notification from Firestore
  Future<void> deleteNotification(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).delete();
    } catch (e) {
      print('Error deleting notification: $e');
    }
  }

  // Clear all notifications from Firestore
  Future<void> clearAllNotifications() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final batch = _firestore.batch();
      for (final notification in _notifications) {
        batch.delete(
          _firestore.collection('notifications').doc(notification.id),
        );
      }
      await batch.commit();
    } catch (e) {
      print('Error clearing notifications: $e');
    }
  }

  // Sort notifications by timestamp (newest first) and priority
  void _sortNotifications() {
    _notifications.sort((a, b) {
      // First sort by read status (unread first)
      if (a.isRead != b.isRead) {
        return a.isRead ? 1 : -1;
      }

      // Then by priority (urgent first)
      final priorityOrder = {
        NotificationPriority.urgent: 0,
        NotificationPriority.high: 1,
        NotificationPriority.medium: 2,
        NotificationPriority.low: 3,
      };

      final aPriority = priorityOrder[a.priority] ?? 3;
      final bPriority = priorityOrder[b.priority] ?? 3;

      if (aPriority != bPriority) {
        return aPriority.compareTo(bPriority);
      }

      // Finally by timestamp (newest first)
      return b.timestamp.compareTo(a.timestamp);
    });
  }

  // Get notifications grouped by date
  Map<String, List<NotificationModel>> getGroupedNotifications() {
    final Map<String, List<NotificationModel>> grouped = {};
    final now = DateTime.now();

    for (final notification in _notifications) {
      final difference = now.difference(notification.timestamp);
      String dateKey;

      if (difference.inDays == 0) {
        dateKey = 'Today';
      } else if (difference.inDays == 1) {
        dateKey = 'Yesterday';
      } else if (difference.inDays < 7) {
        dateKey = '${difference.inDays} days ago';
      } else {
        dateKey =
            '${notification.timestamp.day}/${notification.timestamp.month}/${notification.timestamp.year}';
      }

      if (!grouped.containsKey(dateKey)) {
        grouped[dateKey] = [];
      }
      grouped[dateKey]!.add(notification);
    }

    return grouped;
  }

  // Dispose listener
  @override
  void dispose() {
    _notificationSubscription?.cancel();
    super.dispose();
  }
}
