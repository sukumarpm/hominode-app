import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/notification_models.dart';
import 'admin_service.dart';

/// Firestore-backed Notification Service
/// Implements flow function pattern with multi-tenancy support
class NotificationFirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AdminService _adminService = AdminService();
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'asia-southeast1',
  );
  static const String _collection = 'notifications';

  // ============================================================================
  // NOTIFICATION CREATION
  // ============================================================================

  /// Create a new notification
  Future<String> createNotification({
    required String title,
    required String message,
    required NotificationType type,
    required NotificationPriority priority,
    required String recipientId, // residentId or adminId
    String? actionUrl,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      print('🔵 NOTIFICATION CREATION: Starting...');

      // STEP 1: Validate Admin Authentication
      print('🔐 STEP 1: Validating admin authentication...');
      final adminId = _adminService.getCurrentAdminId();
      if (adminId == null) {
        throw Exception('Admin not logged in');
      }
      print('✅ STEP 1 PASSED: Admin authenticated');

      // STEP 2: Validate Notification Data
      print('📋 STEP 2: Validating notification data...');
      if (title.isEmpty || message.isEmpty) {
        throw Exception('Title and message are required');
      }
      print('✅ STEP 2 PASSED: Data validated');

      // STEP 3: Ask the trusted backend to resolve and validate the recipient.
      print('📝 STEP 3: Sending trusted notification request...');
      final sourceEntityId = _sourceEntityId(metadata);
      final result = await _functions.httpsCallable('sendNotification').call({
        'communityId': _adminService.requireCurrentCommunityId(),
        'recipientUid': recipientId,
        'title': title,
        'message': message,
        'category': type.name,
        'priority': priority.name,
        if (sourceEntityId != null) 'sourceEntityId': sourceEntityId,
      });
      final response = result.data;
      final notificationId = response is Map
          ? response['notificationId'] as String?
          : null;
      if (notificationId == null || notificationId.isEmpty) {
        throw StateError('Notification sender returned no notification ID.');
      }

      print('✅ STEP 3 PASSED: Notification created');

      // STEP 4: Log Completion
      print('🔔 STEP 4: Logging completion...');
      print('✅ NOTIFICATION CREATION: COMPLETE');

      // STEP 5: Return Result
      return notificationId;
    } catch (e) {
      print('❌ ERROR: $e');
      throw Exception('Failed to create notification: $e');
    }
  }

  String? _sourceEntityId(Map<String, dynamic>? metadata) {
    if (metadata == null) return null;
    const allowedKeys = [
      'entityId',
      'visitorId',
      'complaintId',
      'billId',
      'paymentId',
      'maintenanceId',
      'bookingId',
      'slotId',
      'violationId',
      'vehicleId',
    ];
    for (final key in allowedKeys) {
      final value = metadata[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    return null;
  }

  // ============================================================================
  // NOTIFICATION RETRIEVAL
  // ============================================================================

  /// Get all notifications for admin
  Stream<List<NotificationFirestoreModel>> getNotifications() {
    final adminId = _adminService.getCurrentAdminId();
    if (adminId == null) return Stream.value([]);

    return _firestore
        .collection(_collection)
        .where(
          'communityId',
          isEqualTo: _adminService.requireCurrentCommunityId(),
        )
        .where('recipientId', isEqualTo: adminId)
        .where('audience', isEqualTo: 'admin')
        .where('role', isEqualTo: 'admin')
        .where('appId', isEqualTo: 'admin')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => NotificationFirestoreModel.fromFirestore(doc))
              .toList();
        });
  }

  /// Get unread notifications count
  Stream<int> getUnreadCount() {
    final adminId = _adminService.getCurrentAdminId();
    if (adminId == null) return Stream.value(0);

    return _firestore
        .collection(_collection)
        .where(
          'communityId',
          isEqualTo: _adminService.requireCurrentCommunityId(),
        )
        .where('recipientId', isEqualTo: adminId)
        .where('audience', isEqualTo: 'admin')
        .where('role', isEqualTo: 'admin')
        .where('appId', isEqualTo: 'admin')
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  /// Get notifications by type
  Stream<List<NotificationFirestoreModel>> getNotificationsByType(
    NotificationType type,
  ) {
    final adminId = _adminService.getCurrentAdminId();
    if (adminId == null) return Stream.value([]);

    final typeString = type.toString().split('.').last;

    return _firestore
        .collection(_collection)
        .where(
          'communityId',
          isEqualTo: _adminService.requireCurrentCommunityId(),
        )
        .where('recipientId', isEqualTo: adminId)
        .where('audience', isEqualTo: 'admin')
        .where('role', isEqualTo: 'admin')
        .where('appId', isEqualTo: 'admin')
        .where('type', isEqualTo: typeString)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => NotificationFirestoreModel.fromFirestore(doc))
              .toList();
        });
  }

  /// Get notifications by priority
  Stream<List<NotificationFirestoreModel>> getNotificationsByPriority(
    NotificationPriority priority,
  ) {
    final adminId = _adminService.getCurrentAdminId();
    if (adminId == null) return Stream.value([]);

    final priorityString = priority.toString().split('.').last;

    return _firestore
        .collection(_collection)
        .where(
          'communityId',
          isEqualTo: _adminService.requireCurrentCommunityId(),
        )
        .where('recipientId', isEqualTo: adminId)
        .where('audience', isEqualTo: 'admin')
        .where('role', isEqualTo: 'admin')
        .where('appId', isEqualTo: 'admin')
        .where('priority', isEqualTo: priorityString)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => NotificationFirestoreModel.fromFirestore(doc))
              .toList();
        });
  }

  // ============================================================================
  // NOTIFICATION UPDATES
  // ============================================================================

  /// Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      print('🔵 MARK NOTIFICATION AS READ: Starting...');

      // STEP 1: Validate Admin
      print('🔐 STEP 1: Validating admin...');
      final adminId = _adminService.getCurrentAdminId();
      if (adminId == null) throw Exception('Admin not logged in');
      print('✅ STEP 1 PASSED');

      // STEP 2: Validate notification exists
      print('📋 STEP 2: Validating notification...');
      final doc = await _firestore
          .collection(_collection)
          .doc(notificationId)
          .get();
      if (!doc.exists) throw Exception('Notification not found');
      print('✅ STEP 2 PASSED');

      // STEP 3: Update notification
      print('📝 STEP 3: Marking as read...');
      await _firestore.collection(_collection).doc(notificationId).update({
        'isRead': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('✅ STEP 3 PASSED');

      print('✅ MARK NOTIFICATION AS READ: COMPLETE');
    } catch (e) {
      print('❌ ERROR: $e');
      throw Exception('Failed to mark notification as read: $e');
    }
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead() async {
    try {
      print('🔵 MARK ALL NOTIFICATIONS AS READ: Starting...');

      // STEP 1: Validate Admin
      print('🔐 STEP 1: Validating admin...');
      final adminId = _adminService.getCurrentAdminId();
      if (adminId == null) throw Exception('Admin not logged in');
      print('✅ STEP 1 PASSED');

      // STEP 2: Get unread notifications
      print('📋 STEP 2: Fetching unread notifications...');
      final snapshot = await _firestore
          .collection(_collection)
          .where(
            'communityId',
            isEqualTo: _adminService.requireCurrentCommunityId(),
          )
          .where('recipientId', isEqualTo: adminId)
          .where('audience', isEqualTo: 'admin')
          .where('role', isEqualTo: 'admin')
          .where('appId', isEqualTo: 'admin')
          .where('isRead', isEqualTo: false)
          .get();
      print(
        '✅ STEP 2 PASSED: Found ${snapshot.docs.length} unread notifications',
      );

      // STEP 3: Update all to read
      print('📝 STEP 3: Marking all as read...');
      final batch = _firestore.batch();
      for (var doc in snapshot.docs) {
        batch.update(doc.reference, {
          'isRead': true,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
      print('✅ STEP 3 PASSED');

      print('✅ MARK ALL NOTIFICATIONS AS READ: COMPLETE');
    } catch (e) {
      print('❌ ERROR: $e');
      throw Exception('Failed to mark all as read: $e');
    }
  }

  // ============================================================================
  // NOTIFICATION DELETION
  // ============================================================================

  /// Delete notification
  Future<void> deleteNotification(String notificationId) async {
    try {
      print('🔵 DELETE NOTIFICATION: Starting...');

      // STEP 1: Validate Admin
      print('🔐 STEP 1: Validating admin...');
      final adminId = _adminService.getCurrentAdminId();
      if (adminId == null) throw Exception('Admin not logged in');
      print('✅ STEP 1 PASSED');

      // STEP 2: Validate notification exists
      print('📋 STEP 2: Validating notification...');
      final doc = await _firestore
          .collection(_collection)
          .doc(notificationId)
          .get();
      if (!doc.exists) throw Exception('Notification not found');
      print('✅ STEP 2 PASSED');

      // STEP 3: Delete notification
      print('📝 STEP 3: Deleting notification...');
      await _firestore.collection(_collection).doc(notificationId).delete();
      print('✅ STEP 3 PASSED');

      print('✅ DELETE NOTIFICATION: COMPLETE');
    } catch (e) {
      print('❌ ERROR: $e');
      throw Exception('Failed to delete notification: $e');
    }
  }

  /// Clear all notifications
  Future<void> clearAllNotifications() async {
    try {
      print('🔵 CLEAR ALL NOTIFICATIONS: Starting...');

      // STEP 1: Validate Admin
      print('🔐 STEP 1: Validating admin...');
      final adminId = _adminService.getCurrentAdminId();
      if (adminId == null) throw Exception('Admin not logged in');
      print('✅ STEP 1 PASSED');

      // STEP 2: Get all notifications
      print('📋 STEP 2: Fetching all notifications...');
      final snapshot = await _firestore
          .collection(_collection)
          .where(
            'communityId',
            isEqualTo: _adminService.requireCurrentCommunityId(),
          )
          .where('recipientId', isEqualTo: adminId)
          .where('audience', isEqualTo: 'admin')
          .where('role', isEqualTo: 'admin')
          .where('appId', isEqualTo: 'admin')
          .get();
      print('✅ STEP 2 PASSED: Found ${snapshot.docs.length} notifications');

      // STEP 3: Delete all
      print('📝 STEP 3: Deleting all notifications...');
      final batch = _firestore.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      print('✅ STEP 3 PASSED');

      print('✅ CLEAR ALL NOTIFICATIONS: COMPLETE');
    } catch (e) {
      print('❌ ERROR: $e');
      throw Exception('Failed to clear notifications: $e');
    }
  }

  // ============================================================================
  // NOTIFICATION TRIGGERS (Called from other services)
  // ============================================================================

  /// Trigger visitor approval notification
  Future<void> notifyVisitorApproved({
    required String visitorName,
    required String residentId,
  }) async {
    try {
      await createNotification(
        title: 'Visitor Approved',
        message: '$visitorName has been approved to visit.',
        type: NotificationType.visitor,
        priority: NotificationPriority.medium,
        recipientId: residentId,
        metadata: {'visitorName': visitorName},
      );
    } catch (e) {
      print('Error notifying visitor approval: $e');
    }
  }

  /// Trigger complaint notification
  Future<void> notifyComplaintUpdate({
    required String complaintTitle,
    required String newStatus,
    required String residentId,
  }) async {
    try {
      await createNotification(
        title: 'Complaint Updated',
        message: '$complaintTitle status changed to $newStatus',
        type: NotificationType.complaint,
        priority: NotificationPriority.high,
        recipientId: residentId,
        metadata: {'complaintTitle': complaintTitle, 'status': newStatus},
      );
    } catch (e) {
      print('Error notifying complaint update: $e');
    }
  }

  /// Trigger payment notification
  Future<void> notifyPaymentReceived({
    required double amount,
    required String residentId,
  }) async {
    try {
      await createNotification(
        title: 'Payment Received',
        message: 'Payment of ₹$amount has been received.',
        type: NotificationType.payment,
        priority: NotificationPriority.medium,
        recipientId: residentId,
        metadata: {'amount': amount},
      );
    } catch (e) {
      print('Error notifying payment: $e');
    }
  }

  /// Trigger maintenance notification
  Future<void> notifyMaintenanceScheduled({
    required String maintenanceType,
    required DateTime scheduledDate,
    required String residentId,
  }) async {
    try {
      await createNotification(
        title: 'Maintenance Scheduled',
        message:
            '$maintenanceType maintenance scheduled for ${scheduledDate.toString().split(' ')[0]}',
        type: NotificationType.maintenance,
        priority: NotificationPriority.high,
        recipientId: residentId,
        metadata: {'type': maintenanceType, 'date': scheduledDate.toString()},
      );
    } catch (e) {
      print('Error notifying maintenance: $e');
    }
  }

  /// Trigger security alert notification
  Future<void> notifySecurityAlert({
    required String alertType,
    required String description,
    required String residentId,
  }) async {
    try {
      await createNotification(
        title: 'Security Alert',
        message: '$alertType: $description',
        type: NotificationType.security,
        priority: NotificationPriority.urgent,
        recipientId: residentId,
        metadata: {'alertType': alertType, 'description': description},
      );
    } catch (e) {
      print('Error notifying security alert: $e');
    }
  }

  /// Trigger parking violation notification
  Future<void> notifyParkingViolation({
    required String vehicleNumber,
    required String violationType,
    required String residentId,
  }) async {
    try {
      await createNotification(
        title: 'Parking Violation',
        message: 'Vehicle $vehicleNumber has a $violationType violation.',
        type: NotificationType.general,
        priority: NotificationPriority.high,
        recipientId: residentId,
        metadata: {
          'vehicleNumber': vehicleNumber,
          'violationType': violationType,
        },
      );
    } catch (e) {
      print('Error notifying parking violation: $e');
    }
  }
}

// ============================================================================
// MODEL
// ============================================================================

class NotificationFirestoreModel {
  final String id;
  final String title;
  final String message;
  final String type;
  final String priority;
  final String recipientId;
  final bool isRead;
  final String? actionUrl;
  final Map<String, dynamic> metadata;
  final DateTime? createdAt;

  NotificationFirestoreModel({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.priority,
    required this.recipientId,
    required this.isRead,
    this.actionUrl,
    this.metadata = const {},
    this.createdAt,
  });

  factory NotificationFirestoreModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return NotificationFirestoreModel(
      id: doc.id,
      title: data['title'] ?? '',
      message: data['message'] ?? '',
      type: data['type'] ?? 'general',
      priority: data['priority'] ?? 'medium',
      recipientId: data['recipientId'] ?? '',
      isRead: data['isRead'] ?? false,
      actionUrl: data['actionUrl'],
      metadata: data['metadata'] ?? {},
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
