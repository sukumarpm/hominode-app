import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'visitor_policy_service.dart';

import 'admin_service.dart';
import 'visitor_lifecycle.dart';
export 'visitor_lifecycle.dart';

abstract interface class VisitorWorkflowService {
  Stream<List<VisitorModel>> getPendingVisitors();
  Stream<List<VisitorModel>> getActiveVisitors();
  Stream<List<VisitorModel>> getHistoryVisitors();
  Future<void> approveVisitor(String visitorId, {int? expectedRevision});
  Future<void> rejectVisitor(String visitorId, {int? expectedRevision});
  Future<void> revokeVisitor(String visitorId, {int? expectedRevision});
  Stream<String?> watchVisitorHostResidentType(VisitorModel visitor);
  Future<void> checkOutVisitor(String visitorId);
}

class VisitorService implements VisitorWorkflowService {
  VisitorService({
    FirebaseFirestore? firestore,
    AdminService? adminService,
    VisitorPolicyCallable? callable,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _adminService = adminService ?? AdminService(),
       _callable = callable;
  final FirebaseFirestore _firestore;
  final AdminService _adminService;
  final VisitorPolicyCallable? _callable;
  final String _collection = 'visitors';

  /// Get visitor by ID
  Future<VisitorModel?> getVisitorById(String visitorId) async {
    try {
      print('VisitorService: Fetching visitor by ID - $visitorId');
      final communityId = _adminService.requireCurrentCommunityId();
      final doc = await _firestore
          .collection(_collection)
          .doc(visitorId)
          .get(const GetOptions(source: Source.server));
      if (doc.data()?['communityId'] != communityId ||
          _adminService.requireCurrentCommunityId() != communityId) {
        throw StateError('Visitor is outside your community.');
      }

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
    final communityId = _adminService.requireCurrentCommunityId();
    return _firestore
        .collection(_collection)
        .where('communityId', isEqualTo: communityId)
        .snapshots()
        .map((snapshot) {
          print('VisitorService: Received ${snapshot.docs.length} visitors');
          final visitors = snapshot.docs
              .where((doc) => doc.data()['communityId'] == communityId)
              .map((doc) {
                final data = doc.data();
                return VisitorModel.fromFirestore(doc.id, data);
              })
              .toList();

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

  /// Expected includes invitations awaiting a decision and already approved ones.
  @override
  Stream<List<VisitorModel>> getPendingVisitors() => getVisitors().map(
    (rows) => rows
        .where((row) => visitorBelongsInExpectedQueue(row.lifecycleData))
        .toList(),
  );

  @override
  Stream<List<VisitorModel>> getActiveVisitors() => getVisitors().map(
    (rows) => rows
        .where((row) => visitorBelongsInActiveQueue(row.lifecycleData))
        .toList(),
  );

  @override
  Stream<List<VisitorModel>> getHistoryVisitors() => getVisitors().map(
    (rows) => rows
        .where((row) => visitorBelongsInHistoryQueue(row.lifecycleData))
        .toList(),
  );

  Stream<int> getPendingVisitorsCount() => getVisitors().map(
    (rows) => rows
        .where((row) => visitorBelongsInPendingQueue(row.lifecycleData))
        .length,
  );

  /// Admin cannot create a Resident invitation by supplying a resident ID.
  /// A walk-in workflow requires a separate server-authorized contract.
  @Deprecated(
    'Resident invitations must be created by the authenticated Resident.',
  )
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

  @override
  Future<void> approveVisitor(String visitorId, {int? expectedRevision}) =>
      _decide(visitorId, 'approve', expectedRevision);

  @override
  Future<void> rejectVisitor(String visitorId, {int? expectedRevision}) =>
      _decide(visitorId, 'reject', expectedRevision);

  @override
  Future<void> revokeVisitor(String visitorId, {int? expectedRevision}) =>
      _decide(visitorId, 'revoke', expectedRevision);

  @override
  Stream<String?> watchVisitorHostResidentType(VisitorModel visitor) {
    final community = _adminService.requireCurrentCommunityId();
    if (visitor.residentId.isEmpty || visitor.communityId != community) {
      return Stream.value(null);
    }
    return _firestore
        .collection('users')
        .doc(visitor.residentId)
        .snapshots()
        .map((doc) {
          final data = doc.data();
          if (_adminService.requireCurrentCommunityId() != community ||
              data?['uid'] != visitor.residentId ||
              data?['role'] != 'resident' ||
              data?['communityId'] != community)
            return null;
          final types =
              ['residentType', 'ownershipType', 'declaredResidentType']
                  .map((key) => data?[key])
                  .whereType<String>()
                  .map((value) => value.trim().toLowerCase())
                  .where((value) => value.isNotEmpty)
                  .toSet();
          if (types.length != 1 ||
              !const {'owner', 'tenant'}.contains(types.single))
            return null;
          return types.single;
        });
  }

  Future<void> _decide(
    String visitorId,
    String action,
    int? expectedRevision,
  ) async {
    if (_adminService.getCurrentAdminId() == null) {
      throw StateError('Admin not authenticated');
    }
    final community = _adminService.requireCurrentCommunityId();
    final snapshot = await _firestore
        .collection(_collection)
        .doc(visitorId)
        .get(const GetOptions(source: Source.server));
    final data = snapshot.data();
    if (data == null ||
        data['communityId'] != community ||
        _adminService.requireCurrentCommunityId() != community) {
      throw StateError('Visitor is outside your current community.');
    }
    final payload = <String, dynamic>{
      'communityId': community,
      'visitorId': visitorId,
      'action': action,
      'expectedRevision':
          expectedRevision ?? data['authorizationRevision'] ?? 0,
    };
    if (_callable != null) {
      await _callable('decideVisitorInvitation', payload);
    } else {
      await FirebaseFunctions.instanceFor(
        region: 'asia-southeast1',
      ).httpsCallable('decideVisitorInvitation').call(payload);
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
  final String? gateEntryDenialReason;
  final String? authorizationState;
  final int authorizationRevision;
  final int? authorizationPolicyRevision;
  final String? authorizationActorUid;
  final bool authorizationManaged;
  final bool compatibilityIssued;
  final bool bringingPet;
  final String? gateAccessStatus;
  final String? communityId;

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
    this.gateEntryDenialReason,
    this.authorizationState,
    this.authorizationRevision = 0,
    this.authorizationPolicyRevision,
    this.authorizationActorUid,
    this.authorizationManaged = false,
    this.compatibilityIssued = false,
    this.bringingPet = false,
    this.gateAccessStatus,
    this.communityId,
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
          (data['expectedArrival'] ?? data['expectedTime'] as Timestamp?)
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
      gateEntryDenialReason: data['gateEntryDenialReason'] as String?,
      authorizationState: data['authorizationState'] as String?,
      authorizationRevision:
          (data['authorizationRevision'] as num?)?.toInt() ?? 0,
      authorizationPolicyRevision: (data['authorizationPolicyRevision'] as num?)
          ?.toInt(),
      authorizationActorUid: data['authorizationActorUid'] as String?,
      authorizationManaged: data['authorizationManaged'] == true,
      compatibilityIssued:
          (data['visitorPolicySnapshot'] as Map?)?['enforced'] == false,
      bringingPet: data['bringingPet'] == true,
      gateAccessStatus: data['gateAccessStatus'] as String?,
      communityId: data['communityId'] as String?,
    );
  }

  Map<String, dynamic> get lifecycleData => {
    'status': status,
    'isApproved': isApproved,
    'actualArrival': actualArrival ?? checkInTime,
    'departure': departure ?? checkOutTime,
    'authorizationState': authorizationState,
    'authorizationManaged': authorizationManaged,
    'authorizationPolicyRevision': authorizationPolicyRevision,
    'authorizationActorUid': authorizationActorUid,
    'approvedBy': approvedBy,
    'approvedAt': approvedAt,
    'visitorPolicySnapshot': {'enforced': compatibilityIssued ? false : null},
    'gateAccessStatus': gateAccessStatus,
    'communityId': communityId,
  };

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
