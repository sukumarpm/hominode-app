import 'package:cloud_firestore/cloud_firestore.dart';
import 'admin_service.dart';
import 'notification_firestore_service.dart';
import '../models/notification_models.dart';

class ComplaintService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AdminService _adminService = AdminService();
  final NotificationFirestoreService _notificationService =
      NotificationFirestoreService();
  final String _collection = 'complaints';

  // Get all complaints filtered by adminId
  Stream<List<ComplaintModel>> getComplaints() {
    final adminId = _adminService.getCurrentAdminId();
    if (adminId == null) return Stream.value([]);

    return _firestore
        .collection(_collection)
        .where(
          'communityId',
          isEqualTo: _adminService.requireCurrentCommunityId(),
        )
        .snapshots()
        .map((snapshot) {
          final complaints = snapshot.docs.map((doc) {
            final data = doc.data();
            return ComplaintModel.fromMap(doc.id, data);
          }).toList();

          // Sort in memory to avoid index requirement
          complaints.sort((a, b) {
            if (a.createdAt == null && b.createdAt == null) return 0;
            if (a.createdAt == null) return 1;
            if (b.createdAt == null) return -1;
            return b.createdAt!.compareTo(a.createdAt!);
          });

          return complaints;
        });
  }

  // Get pending complaints (not resolved) filtered by adminId
  Stream<List<ComplaintModel>> getPendingComplaints() {
    final adminId = _adminService.getCurrentAdminId();
    if (adminId == null) return Stream.value([]);

    return _firestore
        .collection(_collection)
        .where(
          'communityId',
          isEqualTo: _adminService.requireCurrentCommunityId(),
        )
        .where('status', whereIn: ['pending', 'in-progress'])
        .snapshots()
        .map((snapshot) {
          final complaints = snapshot.docs.map((doc) {
            final data = doc.data();
            return ComplaintModel.fromMap(doc.id, data);
          }).toList();

          // Sort in memory to avoid index requirement
          complaints.sort((a, b) {
            if (a.createdAt == null && b.createdAt == null) return 0;
            if (a.createdAt == null) return 1;
            if (b.createdAt == null) return -1;
            return b.createdAt!.compareTo(a.createdAt!);
          });

          return complaints;
        });
  }

  // Get pending complaints count filtered by adminId
  Stream<int> getPendingComplaintsCount() {
    final adminId = _adminService.getCurrentAdminId();
    if (adminId == null) return Stream.value(0);

    return _firestore
        .collection(_collection)
        .where(
          'communityId',
          isEqualTo: _adminService.requireCurrentCommunityId(),
        )
        .where('status', whereIn: ['pending', 'in-progress'])
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  // Update complaint status with flow function
  Future<void> updateComplaintStatus(String complaintId, String status) async {
    try {
      print('🔵 COMPLAINT STATUS UPDATE FLOW: Starting...');

      // STEP 1: Validate Admin Authentication
      print('🔐 STEP 1: Validating admin authentication...');
      final adminId = _adminService.getCurrentAdminId();
      if (adminId == null) {
        throw Exception('Admin not authenticated');
      }
      print('✅ STEP 1 PASSED: Admin authenticated');

      // STEP 2: Validate Complaint Data
      print('📋 STEP 2: Validating complaint data...');
      final complaintDoc = await _firestore
          .collection(_collection)
          .doc(complaintId)
          .get();
      if (!complaintDoc.exists) {
        throw Exception('Complaint not found');
      }
      final complaintData = complaintDoc.data();
      if (complaintData == null) {
        throw Exception('Complaint data is empty');
      }
      print('✅ STEP 2 PASSED: Complaint validated');

      // STEP 3: Update Complaint Status
      print('📝 STEP 3: Updating complaint status...');
      await _firestore.collection(_collection).doc(complaintId).update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('✅ STEP 3 PASSED: Status updated');

      // STEP 4: Notify Resident
      print('🔔 STEP 4: Notifying resident...');
      final residentId = complaintData['residentId'] ?? '';
      final complaintTitle = complaintData['title'] ?? 'Complaint';

      if (residentId.isNotEmpty) {
        try {
          await _notificationService.createNotification(
            title: 'Complaint Status Updated',
            message: '$complaintTitle status is now $status',
            type: NotificationType.complaint,
            priority: NotificationPriority.high,
            recipientId: residentId,
            metadata: {
              'complaintId': complaintId,
              'status': status,
              'title': complaintTitle,
            },
          );
        } catch (notificationError) {
          print(
            '⚠️ STEP 4 WARNING: Failed to send notification: $notificationError',
          );
        }
      }
      print('✅ STEP 4 PASSED: Resident notified');

      // STEP 5: Return Result
      print('✅ COMPLAINT STATUS UPDATE FLOW: COMPLETE');
    } catch (e) {
      print('❌ ERROR: $e');
      throw Exception('Failed to update complaint status: $e');
    }
  }

  // Update complaint assigned staff/vendor with flow function
  Future<void> updateComplaintAssignment(
    String complaintId,
    String assignedTo,
  ) async {
    try {
      print('🔵 COMPLAINT ASSIGNMENT FLOW: Starting...');

      // STEP 1: Validate Admin Authentication
      print('🔐 STEP 1: Validating admin authentication...');
      final adminId = _adminService.getCurrentAdminId();
      if (adminId == null) {
        throw Exception('Admin not authenticated');
      }
      print('✅ STEP 1 PASSED: Admin authenticated');

      // STEP 2: Validate Complaint Data
      print('📋 STEP 2: Validating complaint data...');
      final complaintDoc = await _firestore
          .collection(_collection)
          .doc(complaintId)
          .get();
      if (!complaintDoc.exists) {
        throw Exception('Complaint not found');
      }
      final complaintData = complaintDoc.data();
      if (complaintData == null) {
        throw Exception('Complaint data is empty');
      }
      print('✅ STEP 2 PASSED: Complaint validated');

      // STEP 3: Update Complaint Assignment
      print('📝 STEP 3: Updating complaint assignment...');
      await _firestore.collection(_collection).doc(complaintId).update({
        'assignedTo': assignedTo,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('✅ STEP 3 PASSED: Assignment updated');

      // STEP 4: Notify Resident
      print('🔔 STEP 4: Notifying resident...');
      final residentId = complaintData['residentId'] ?? '';
      final complaintTitle = complaintData['title'] ?? 'Complaint';

      if (residentId.isNotEmpty) {
        try {
          await _notificationService.createNotification(
            title: 'Complaint Assigned',
            message: '$complaintTitle has been assigned to $assignedTo',
            type: NotificationType.complaint,
            priority: NotificationPriority.high,
            recipientId: residentId,
            metadata: {
              'complaintId': complaintId,
              'assignedTo': assignedTo,
              'title': complaintTitle,
            },
          );
        } catch (notificationError) {
          print(
            '⚠️ STEP 4 WARNING: Failed to send notification: $notificationError',
          );
        }
      }
      print('✅ STEP 4 PASSED: Resident notified');

      // STEP 5: Return Result
      print('✅ COMPLAINT ASSIGNMENT FLOW: COMPLETE');
    } catch (e) {
      print('❌ ERROR: $e');
      throw Exception('Failed to update complaint assignment: $e');
    }
  }

  // Update complaint status and assignment together with flow function
  Future<void> updateComplaintStatusAndAssignment(
    String complaintId,
    String status,
    String assignedTo,
  ) async {
    try {
      print('🔵 COMPLAINT UPDATE FLOW: Starting...');

      // STEP 1: Validate Admin Authentication
      print('🔐 STEP 1: Validating admin authentication...');
      final adminId = _adminService.getCurrentAdminId();
      if (adminId == null) {
        throw Exception('Admin not authenticated');
      }
      print('✅ STEP 1 PASSED: Admin authenticated');

      // STEP 2: Validate Complaint Data
      print('📋 STEP 2: Validating complaint data...');
      final complaintDoc = await _firestore
          .collection(_collection)
          .doc(complaintId)
          .get();
      if (!complaintDoc.exists) {
        throw Exception('Complaint not found');
      }
      final complaintData = complaintDoc.data();
      if (complaintData == null) {
        throw Exception('Complaint data is empty');
      }
      print('✅ STEP 2 PASSED: Complaint validated');

      // STEP 3: Update Complaint
      print('📝 STEP 3: Updating complaint status and assignment...');
      await _firestore.collection(_collection).doc(complaintId).update({
        'status': status,
        'assignedTo': assignedTo,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('✅ STEP 3 PASSED: Complaint updated');

      // STEP 4: Notify Resident
      print('🔔 STEP 4: Notifying resident...');
      final residentId = complaintData['residentId'] ?? '';
      final complaintTitle = complaintData['title'] ?? 'Complaint';

      if (residentId.isNotEmpty) {
        await _firestore.collection('notifications').add({
          'communityId': _adminService.requireCurrentCommunityId(),
          'residentId': residentId,
          'title': 'Complaint Updated',
          'message':
              '$complaintTitle status is now $status and assigned to $assignedTo',
          'type': 'complaint_updated',
          'complaintId': complaintId,
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      print('✅ STEP 4 PASSED: Resident notified');

      // STEP 5: Return Result
      print('✅ COMPLAINT UPDATE FLOW: COMPLETE');
    } catch (e) {
      print('❌ ERROR: $e');
      throw Exception('Failed to update complaint: $e');
    }
  }
}

// Complaint Model
class ComplaintModel {
  final String id;
  final String title;
  final String description;
  final String category;
  final String priority;
  final String status; // pending, in-progress, resolved
  final String residentId;
  final String? residentName;
  final String? flatId;
  final String? assignedTo;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  ComplaintModel({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.priority,
    required this.status,
    required this.residentId,
    this.residentName,
    this.flatId,
    this.assignedTo,
    this.createdAt,
    this.updatedAt,
  });

  factory ComplaintModel.fromMap(String id, Map<String, dynamic> data) {
    return ComplaintModel(
      id: id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      category: data['category'] ?? '',
      priority: data['priority'] ?? 'low',
      status: data['status'] ?? 'pending',
      residentId: data['residentId'] ?? '',
      residentName: data['residentName'],
      flatId: data['flatId'],
      assignedTo: data['assignedTo'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'category': category,
      'priority': priority,
      'status': status,
      'residentId': residentId,
      'residentName': residentName,
      'flatId': flatId,
      'assignedTo': assignedTo,
    };
  }
}
