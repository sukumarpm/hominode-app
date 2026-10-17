import 'package:cloud_firestore/cloud_firestore.dart';

import 'admin_service.dart';

abstract interface class VisitorWorkflowService {
  Stream<List<VisitorModel>> getPendingVisitors();
  Stream<List<VisitorModel>> getActiveVisitors();
  Stream<List<VisitorModel>> getHistoryVisitors();
  Future<void> approveVisitor(String visitorId);
  Future<void> rejectVisitor(String visitorId);
  Future<void> checkOutVisitor(String visitorId);
}

class VisitorService implements VisitorWorkflowService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AdminService _adminService = AdminService();
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
  @override
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
          final visitors = snapshot.docs
              .where((doc) => visitorBelongsInPendingQueue(doc.data()))
              .map((doc) {
                final data = doc.data();
                return VisitorModel.fromFirestore(doc.id, data);
              })
              .toList();

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
  @override
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
        .snapshots()
        .map((snapshot) {
          final activeDocs = snapshot.docs
              .where((doc) => visitorBelongsInActiveQueue(doc.data()))
              .toList();

          print(
            'VisitorService: Received ${activeDocs.length} active visitors',
          );

          // Log each visitor's departure status
          for (var doc in activeDocs) {
            final data = doc.data();
            print('  - Visitor ${doc.id}: departure = ${data['departure']}');
          }

          final visitors = activeDocs.map((doc) {
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
  @override
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
        .snapshots()
        .map((snapshot) {
          final historyDocs = snapshot.docs
              .where((doc) => visitorBelongsInHistoryQueue(doc.data()))
              .toList();

          print(
            'VisitorService: Received ${historyDocs.length} history visitors',
          );

          final visitors = historyDocs.map((doc) {
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

  /// Admin cannot create a Resident invitation by supplying a resident ID.
  /// A walk-in workflow requires a separate server-authorized contract.
  @Deprecated('Resident invitations must be created by the authenticated Resident.')
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
    throw UnsupportedError(
      'Admin cannot create a visitor invitation on behalf of a Resident. '
      'The authenticated Resident must create the invitation. Admin walk-ins '
      'require a separate server-authorized gate-entry workflow.',
    );
  }

  /// Approve visitor (admin action) with flow function
  @override
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
        'status': 'approved',
        'approvedBy': adminId,
        'isApproved': true,
        'approvedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('✅ STEP 3 PASSED: Visitor approved');

      // The server-side visitor transition trigger owns host notifications.
      print('✅ VISITOR APPROVAL FLOW: COMPLETE');
    } catch (e) {
      print('❌ ERROR: $e');
      throw Exception('Failed to approve visitor: $e');
    }
  }

  /// Reject visitor (admin action) with flow function
  @override
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
      await _firestore
          .collection(_collection)
          .doc(visitorId)
          .update(rejectedVisitorUpdate(adminId: adminId));
      print('✅ STEP 3 PASSED: Visitor rejected');

      // The server-side visitor transition trigger owns host notifications.
      print('✅ VISITOR REJECTION FLOW: COMPLETE');
    } catch (e) {
      print('❌ ERROR: $e');
      throw Exception('Failed to reject visitor: $e');
    }
  }

  @override
  Future<void> checkOutVisitor(String visitorId) async {
    final actorId = _adminService.getCurrentAdminId();
    if (actorId == null) {
      throw Exception('Admin not authenticated');
    }
    await _firestore.collection(_collection).doc(visitorId).update({
      'status': 'completed',
      'departure': FieldValue.serverTimestamp(),
      'checkedOutBy': actorId,
      'updatedAt': FieldValue.serverTimestamp(),
    });
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
    final isApproved = data['isApproved'] ?? false;
    final actualArrival = (data['actualArrival'] as Timestamp?)?.toDate();
    final departure = (data['departure'] as Timestamp?)?.toDate();
    final status = canonicalVisitorStatus(data);

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

Map<String, dynamic> rejectedVisitorUpdate({required String adminId}) {
  return {
    'status': 'rejected',
    'isApproved': false,
    'rejectedBy': adminId,
    'rejectedAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
  };
}

bool visitorBelongsInPendingQueue(Map<String, dynamic> data) {
  final status = canonicalVisitorStatus(data);
  return (status == 'expected' || status == 'pending') &&
      data['isApproved'] != true &&
      data['actualArrival'] == null &&
      data['departure'] == null;
}

bool visitorBelongsInActiveQueue(Map<String, dynamic> data) {
  return canonicalVisitorStatus(data) == 'inside' &&
      data['isApproved'] == true &&
      data['actualArrival'] != null &&
      data['departure'] == null;
}

bool visitorBelongsInHistoryQueue(Map<String, dynamic> data) {
  return canonicalVisitorStatus(data) == 'departed' &&
      data['departure'] != null;
}

String canonicalVisitorStatus(Map<String, dynamic> data) {
  final rawStatus = _normalizedVisitorStatusValue(
    data['status'] ?? data['visitStatus'] ?? data['approvalStatus'],
  );
  final isApproved = data['isApproved'] == true;
  final hasArrival = data['actualArrival'] != null;
  final hasDeparture = data['departure'] != null;

  if (rawStatus == 'rejected' || rawStatus == 'cancelled') {
    return rawStatus;
  }
  if (rawStatus == 'departed' || hasDeparture) {
    return 'departed';
  }
  if (rawStatus == 'inside') {
    return 'inside';
  }
  if (hasArrival && isApproved) {
    return 'inside';
  }
  if (isApproved || rawStatus == 'approved') {
    return 'approved';
  }
  if (rawStatus == 'expected' || rawStatus == 'pending') {
    return rawStatus;
  }
  return 'pending';
}

String _normalizedVisitorStatusValue(Object? value) {
  final normalized = value?.toString().trim().toLowerCase() ?? '';
  if (normalized.isEmpty) {
    return '';
  }
  if (normalized == 'pendingapproval' || normalized == 'pending_approval') {
    return 'pending';
  }
  if (normalized == 'canceled') {
    return 'cancelled';
  }
  if (normalized == 'checked_in' ||
      normalized == 'arrived' ||
      normalized == 'entered' ||
      normalized == 'inside') {
    return 'inside';
  }
  if (normalized == 'completed' ||
      normalized == 'departed' ||
      normalized == 'checked_out' ||
      normalized == 'checked-out' ||
      normalized == 'exited') {
    return 'departed';
  }
  return normalized;
}
