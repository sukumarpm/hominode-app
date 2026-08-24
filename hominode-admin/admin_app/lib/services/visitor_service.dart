import 'package:cloud_firestore/cloud_firestore.dart';
import 'admin_service.dart';
import 'notification_firestore_service.dart';
import '../models/notification_models.dart';

class VisitorService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AdminService _adminService = AdminService();
  final NotificationFirestoreService _notificationService =
      NotificationFirestoreService();
  final String _collection = 'visitors';

  /// Get visitor by ID
  Future<VisitorModel?> getVisitorById(String visitorId) async {
    try {
      print('VisitorService: Fetching visitor by ID - $visitorId');
      final doc = await _firestore.collection(_collection).doc(visitorId).get();

      if (doc.exists) {
        final data = doc.data();
        if (data != null) {
          print(
            'VisitorService: Visitor found - ${data['visitorName'] ?? data['hostName']}',
          );
          return VisitorModel.fromFirestore(doc.id, data);
        }
      }

      print('VisitorService: Visitor not found - $visitorId');
      return null;
    } catch (e) {
      print('VisitorService ERROR: Failed to fetch visitor: $e');
      return null;
    }
  }

  /// Get all visitors (real-time stream) filtered by adminId
  Stream<List<VisitorModel>> getVisitors() {
    final adminId = _adminService.getCurrentAdminId();
    if (adminId == null) return Stream.value([]);

    print(
      'VisitorService: Fetching all visitors from Firestore for admin: $adminId',
    );
    return _firestore
        .collection(_collection)
        .where(
          'communityId',
          isEqualTo: _adminService.requireCurrentCommunityId(),
        )
        .snapshots()
        .map((snapshot) {
          print('VisitorService: Received ${snapshot.docs.length} visitors');
          final visitors = snapshot.docs.map((doc) {
            final data = doc.data();
            return VisitorModel.fromFirestore(doc.id, data);
          }).toList();

          // Sort in memory to avoid index requirement
          visitors.sort((a, b) {
            if (a.createdAt == null && b.createdAt == null) return 0;
            if (a.createdAt == null) return 1;
            if (b.createdAt == null) return -1;
            return b.createdAt!.compareTo(a.createdAt!);
          });

          return visitors;
        })
        .handleError((error) {
          print('VisitorService ERROR: $error');
          throw Exception('Failed to fetch visitors: $error');
        });
  }

  /// Get pending visitors (real-time stream) filtered by adminId
  Stream<List<VisitorModel>> getPendingVisitors() {
    final adminId = _adminService.getCurrentAdminId();
    if (adminId == null) return Stream.value([]);

    print('VisitorService: Fetching pending visitors for admin: $adminId');
    return _firestore
        .collection(_collection)
        .where(
          'communityId',
          isEqualTo: _adminService.requireCurrentCommunityId(),
        )
        .where('isApproved', isEqualTo: false)
        .snapshots()
        .map((snapshot) {
          print(
            'VisitorService: Received ${snapshot.docs.length} pending visitors',
          );
          final visitors = snapshot.docs.map((doc) {
            final data = doc.data();
            return VisitorModel.fromFirestore(doc.id, data);
          }).toList();

          // Sort in memory instead of using orderBy to avoid index requirement
          visitors.sort((a, b) {
            if (a.createdAt == null && b.createdAt == null) return 0;
            if (a.createdAt == null) return 1;
            if (b.createdAt == null) return -1;
            return b.createdAt!.compareTo(a.createdAt!);
          });

          return visitors;
        });
  }

  /// Get active visitors (checked-in, real-time stream) filtered by adminId
  Stream<List<VisitorModel>> getActiveVisitors() {
    final adminId = _adminService.getCurrentAdminId();
    if (adminId == null) return Stream.value([]);

    print('VisitorService: Fetching active visitors for admin: $adminId');
    return _firestore
        .collection(_collection)
        .where(
          'communityId',
          isEqualTo: _adminService.requireCurrentCommunityId(),
        )
        .where('isApproved', isEqualTo: true)
        .where('actualArrival', isNotEqualTo: null)
        .where('departure', isEqualTo: null)
        .snapshots()
        .map((snapshot) {
          print(
            'VisitorService: Received ${snapshot.docs.length} active visitors',
          );

          // Log each visitor's departure status
          for (var doc in snapshot.docs) {
            final data = doc.data();
            print('  - Visitor ${doc.id}: departure = ${data['departure']}');
          }

          final visitors = snapshot.docs.map((doc) {
            final data = doc.data();
            return VisitorModel.fromFirestore(doc.id, data);
          }).toList();

          // Sort in memory by checkInTime
          visitors.sort((a, b) {
            if (a.checkInTime == null && b.checkInTime == null) return 0;
            if (a.checkInTime == null) return 1;
            if (b.checkInTime == null) return -1;
            return b.checkInTime!.compareTo(a.checkInTime!);
          });

          return visitors;
        });
  }

  /// Get history visitors (checked-out, real-time stream) filtered by adminId
  Stream<List<VisitorModel>> getHistoryVisitors() {
    final adminId = _adminService.getCurrentAdminId();
    if (adminId == null) return Stream.value([]);

    print('VisitorService: Fetching history visitors for admin: $adminId');
    return _firestore
        .collection(_collection)
        .where(
          'communityId',
          isEqualTo: _adminService.requireCurrentCommunityId(),
        )
        .where('departure', isNotEqualTo: null)
        .snapshots()
        .map((snapshot) {
          print(
            'VisitorService: Received ${snapshot.docs.length} history visitors',
          );
          final visitors = snapshot.docs.map((doc) {
            final data = doc.data();
            return VisitorModel.fromFirestore(doc.id, data);
          }).toList();

          // Sort in memory by checkOutTime and limit to 50
          visitors.sort((a, b) {
            if (a.checkOutTime == null && b.checkOutTime == null) return 0;
            if (a.checkOutTime == null) return 1;
            if (b.checkOutTime == null) return -1;
            return b.checkOutTime!.compareTo(a.checkOutTime!);
          });

          // Limit to recent 50 records
          return visitors.take(50).toList();
        });
  }

  /// Get pending visitors count filtered by adminId
  Stream<int> getPendingVisitorsCount() {
    final adminId = _adminService.getCurrentAdminId();
    if (adminId == null) return Stream.value(0);

    return _firestore
        .collection(_collection)
        .where(
          'communityId',
          isEqualTo: _adminService.requireCurrentCommunityId(),
        )
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  /// Create visitor request (from resident app)
  Future<String> createVisitorRequest({
    required String visitorName,
    required String phone,
    required String residentId,
    required String residentName,
    required String flatId,
    required String flatLabel,
    required String purpose,
    DateTime? expectedTime,
    String? buildingId,
  }) async {
    try {
      print('VisitorService: Creating visitor request - $visitorName');

      // Get admin ID from building if not provided
      String? adminId;
      String? finalBuildingId = buildingId;

      if (buildingId != null) {
        try {
          final buildingDoc = await _firestore
              .collection('buildings')
              .doc(buildingId)
              .get();
          if (buildingDoc.exists) {
            adminId = buildingDoc.data()?['adminId'];
            finalBuildingId = buildingId;
          }
        } catch (e) {
          print('VisitorService WARNING: Could not fetch building admin: $e');
        }
      }

      // If no admin found, try to get from current admin (fallback)
      adminId ??= _adminService.getCurrentAdminId();

      final docRef = await _firestore.collection(_collection).add({
        'visitorName': visitorName,
        'phone': phone,
        'residentId': residentId,
        'residentName': residentName,
        'flatId': flatId,
        'flatLabel': flatLabel,
        'purpose': purpose,
        'expectedTime': expectedTime != null
            ? Timestamp.fromDate(expectedTime)
            : null,
        'status': 'pending',
        // Multi-tenancy fields
        'adminId': adminId,
        'communityId': _adminService.requireCurrentCommunityId(),
        'buildingId': finalBuildingId,
        'buildingIds': finalBuildingId != null ? [finalBuildingId] : [],
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('VisitorService: Visitor request created with ID: ${docRef.id}');
      print(
        'VisitorService: Stored adminId: $adminId, buildingId: $finalBuildingId',
      );
      return docRef.id;
    } catch (e) {
      print('VisitorService ERROR: Failed to create visitor request: $e');
      throw Exception('Failed to create visitor request: $e');
    }
  }

  /// Approve visitor (admin action) with flow function
  Future<void> approveVisitor(String visitorId) async {
    try {
      print('🔵 VISITOR APPROVAL FLOW: Starting...');

      // STEP 1: Validate Admin Authentication
      print('🔐 STEP 1: Validating admin authentication...');
      final adminId = _adminService.getCurrentAdminId();
      if (adminId == null) {
        throw Exception('Admin not authenticated');
      }
      print('✅ STEP 1 PASSED: Admin authenticated');

      // STEP 2: Validate Visitor Request
      print('📋 STEP 2: Validating visitor request...');
      final visitorDoc = await _firestore
          .collection(_collection)
          .doc(visitorId)
          .get();
      if (!visitorDoc.exists) {
        throw Exception('Visitor request not found');
      }
      final visitorData = visitorDoc.data();
      if (visitorData == null) {
        throw Exception('Visitor data is empty');
      }
      print('✅ STEP 2 PASSED: Visitor request validated');

      // STEP 3: Approve Visitor
      print('✅ STEP 3: Approving visitor...');
      await _firestore.collection(_collection).doc(visitorId).update({
        'isApproved': true,
        'approvedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('✅ STEP 3 PASSED: Visitor approved');

      // STEP 4: Notify Resident
      print('🔔 STEP 4: Notifying resident...');
      final residentId = visitorData['residentId'] ?? '';
      final visitorName = visitorData['visitorName'] ?? 'Visitor';

      if (residentId.isNotEmpty) {
        try {
          await _notificationService.createNotification(
            title: 'Visitor Approved',
            message: '$visitorName has been approved to visit',
            type: NotificationType.visitor,
            priority: NotificationPriority.high,
            recipientId: residentId,
            metadata: {'visitorId': visitorId, 'visitorName': visitorName},
          );
        } catch (notificationError) {
          print(
            '⚠️ STEP 4 WARNING: Failed to send notification: $notificationError',
          );
        }
      }
      print('✅ STEP 4 PASSED: Resident notified');

      // STEP 5: Return Result
      print('✅ VISITOR APPROVAL FLOW: COMPLETE');
    } catch (e) {
      print('❌ ERROR: $e');
      throw Exception('Failed to approve visitor: $e');
    }
  }

  /// Reject visitor (admin action) with flow function
  Future<void> rejectVisitor(String visitorId) async {
    try {
      print('🔵 VISITOR REJECTION FLOW: Starting...');

      // STEP 1: Validate Admin Authentication
      print('🔐 STEP 1: Validating admin authentication...');
      final adminId = _adminService.getCurrentAdminId();
      if (adminId == null) {
        throw Exception('Admin not authenticated');
      }
      print('✅ STEP 1 PASSED: Admin authenticated');

      // STEP 2: Validate Visitor Request
      print('📋 STEP 2: Validating visitor request...');
      final visitorDoc = await _firestore
          .collection(_collection)
          .doc(visitorId)
          .get();
      if (!visitorDoc.exists) {
        throw Exception('Visitor request not found');
      }
      final visitorData = visitorDoc.data();
      if (visitorData == null) {
        throw Exception('Visitor data is empty');
      }
      print('✅ STEP 2 PASSED: Visitor request validated');

      // STEP 3: Reject Visitor
      print('✅ STEP 3: Rejecting visitor...');
      await _firestore.collection(_collection).doc(visitorId).update({
        'isApproved': false,
        'rejectedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('✅ STEP 3 PASSED: Visitor rejected');

      // STEP 4: Notify Resident
      print('🔔 STEP 4: Notifying resident...');
      final residentId = visitorData['residentId'] ?? '';
      final visitorName = visitorData['visitorName'] ?? 'Visitor';

      if (residentId.isNotEmpty) {
        try {
          await _notificationService.createNotification(
            title: 'Visitor Rejected',
            message: '$visitorName\'s visit request has been rejected',
            type: NotificationType.visitor,
            priority: NotificationPriority.high,
            recipientId: residentId,
            metadata: {'visitorId': visitorId, 'visitorName': visitorName},
          );
        } catch (notificationError) {
          print(
            '⚠️ STEP 4 WARNING: Failed to send notification: $notificationError',
          );
        }
      }
      print('✅ STEP 4 PASSED: Resident notified');

      // STEP 5: Return Result
      print('✅ VISITOR REJECTION FLOW: COMPLETE');
    } catch (e) {
      print('❌ ERROR: $e');
      throw Exception('Failed to reject visitor: $e');
    }
  }

  /// Check-in visitor (gate/admin action)
  Future<void> checkInVisitor(String visitorId) async {
    try {
      print('VisitorService: Checking in visitor - $visitorId');
      await _firestore.collection(_collection).doc(visitorId).update({
        'isApproved': true,
        'actualArrival': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('VisitorService: Visitor checked in successfully');
    } catch (e) {
      print('VisitorService ERROR: Failed to check in visitor: $e');
      throw Exception('Failed to check in visitor: $e');
    }
  }

  /// Check-out visitor (mark exit)
  Future<void> checkOutVisitor(String visitorId) async {
    try {
      print('VisitorService: Checking out visitor - $visitorId');

      await _firestore.collection(_collection).doc(visitorId).update({
        'departure': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('VisitorService: Visitor checked out successfully - $visitorId');

      // Verify the update
      final doc = await _firestore.collection(_collection).doc(visitorId).get();
      final data = doc.data();
      print('VisitorService: Verified departure field - ${data?['departure']}');
    } catch (e) {
      print('VisitorService ERROR: Failed to check out visitor: $e');
      throw Exception('Failed to check out visitor: $e');
    }
  }

  /// Delete visitor record
  Future<void> deleteVisitor(String visitorId) async {
    try {
      await _firestore.collection(_collection).doc(visitorId).delete();
      print('VisitorService: Visitor deleted - $visitorId');
    } catch (e) {
      print('VisitorService ERROR: Failed to delete visitor: $e');
      throw Exception('Failed to delete visitor: $e');
    }
  }
}

// ============================================================================
// VISITOR MODEL
// ============================================================================

class VisitorModel {
  final String id;
  final String visitorName;
  final String phone;
  final String residentId;
  final String residentName;
  final String flatId;
  final String flatLabel;
  final String purpose;
  final DateTime? expectedTime;
  final String status; // For compatibility
  final DateTime? createdAt;
  final DateTime? approvedAt;
  final DateTime? rejectedAt;
  final DateTime? checkInTime;
  final DateTime? checkOutTime;
  final DateTime? updatedAt;

  // Additional fields from your Firestore structure
  final bool isApproved;
  final DateTime? actualArrival;
  final DateTime? departure;
  final String? approvedBy;

  VisitorModel({
    required this.id,
    required this.visitorName,
    required this.phone,
    required this.residentId,
    required this.residentName,
    required this.flatId,
    required this.flatLabel,
    required this.purpose,
    this.expectedTime,
    required this.status,
    this.createdAt,
    this.approvedAt,
    this.rejectedAt,
    this.checkInTime,
    this.checkOutTime,
    this.updatedAt,
    this.isApproved = false,
    this.actualArrival,
    this.departure,
    this.approvedBy,
  });

  factory VisitorModel.fromFirestore(String id, Map<String, dynamic> data) {
    // Map your Firestore fields to the model
    final isApproved = data['isApproved'] ?? false;
    final actualArrival = (data['actualArrival'] as Timestamp?)?.toDate();
    final departure = (data['departure'] as Timestamp?)?.toDate();

    // Determine status based on your fields
    String status;
    if (departure != null) {
      status = 'checked-out';
    } else if (actualArrival != null && isApproved) {
      status = 'active';
    } else if (isApproved) {
      status = 'approved';
    } else {
      status = 'pending';
    }

    return VisitorModel(
      id: id,
      visitorName: data['visitorName'] ?? data['hostName'] ?? '',
      phone: data['phone'] ?? data['phoneNumber'] ?? '',
      residentId: data['residentId'] ?? data['hostUserId'] ?? '',
      residentName: data['residentName'] ?? data['hostName'] ?? '',
      flatId: data['flatId'] ?? '',
      flatLabel: data['flatLabel'] ?? '',
      purpose: data['purpose'] ?? '',
      expectedTime:
          (data['expectedTime'] ?? data['expectedArrival'] as Timestamp?)
              ?.toDate(),
      status: status,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      approvedAt: (data['approvedAt'] as Timestamp?)?.toDate(),
      rejectedAt: (data['rejectedAt'] as Timestamp?)?.toDate(),
      checkInTime: (data['checkInTime'] ?? data['actualArrival'] as Timestamp?)
          ?.toDate(),
      checkOutTime: (data['checkOutTime'] ?? data['departure'] as Timestamp?)
          ?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      isApproved: isApproved,
      actualArrival: actualArrival,
      departure: departure,
      approvedBy: data['approvedBy'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'visitorName': visitorName,
      'phone': phone,
      'residentId': residentId,
      'residentName': residentName,
      'flatId': flatId,
      'flatLabel': flatLabel,
      'purpose': purpose,
      'expectedTime': expectedTime != null
          ? Timestamp.fromDate(expectedTime!)
          : null,
      'status': status,
      'isApproved': isApproved,
      'actualArrival': actualArrival != null
          ? Timestamp.fromDate(actualArrival!)
          : null,
      'departure': departure != null ? Timestamp.fromDate(departure!) : null,
    };
  }

  String get formattedCreatedAt {
    if (createdAt == null) return '';
    return '${createdAt!.year}-${createdAt!.month.toString().padLeft(2, '0')}-${createdAt!.day.toString().padLeft(2, '0')}';
  }
}
