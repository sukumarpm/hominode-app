import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'admin_tenant_context.dart';

class GateModel {
  final String id;
  final String gateName;
  final String gateType;
  final String workingStatus;
  final String? shiftTime;
  final String? assignedSecurityId;
  final String? assignedSecurityName;
  final String? assignedShiftTiming;
  final String? assignedSpecialInstructions;
  final DateTime? assignedAt;
  final String adminId;
  final String? buildingId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  GateModel({
    required this.id,
    required this.gateName,
    required this.gateType,
    required this.workingStatus,
    this.shiftTime,
    this.assignedSecurityId,
    this.assignedSecurityName,
    this.assignedShiftTiming,
    this.assignedSpecialInstructions,
    this.assignedAt,
    required this.adminId,
    this.buildingId,
    this.createdAt,
    this.updatedAt,
  });

  factory GateModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return GateModel(
      id: doc.id,
      gateName: data['gateName'] ?? '',
      gateType: data['gateType'] ?? '',
      workingStatus: data['workingStatus'] ?? 'Inactive',
      shiftTime: data['shiftTime'],
      assignedSecurityId: data['assignedSecurityId'],
      assignedSecurityName: data['assignedSecurityName'],
      assignedShiftTiming: data['assignedShiftTiming'],
      assignedSpecialInstructions: data['assignedSpecialInstructions'],
      assignedAt: (data['assignedAt'] as Timestamp?)?.toDate(),
      adminId: data['adminId'] ?? '',
      buildingId: data['buildingId'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'gateName': gateName,
      'gateType': gateType,
      'workingStatus': workingStatus,
      'shiftTime': shiftTime,
      'assignedSecurityId': assignedSecurityId,
      'assignedSecurityName': assignedSecurityName,
      'assignedShiftTiming': assignedShiftTiming,
      'assignedSpecialInstructions': assignedSpecialInstructions,
      'assignedAt': assignedAt != null ? Timestamp.fromDate(assignedAt!) : null,
      'adminId': adminId,
      'buildingId': buildingId,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}

class GateStats {
  final int total;
  final int active;
  final int inactive;
  final int maintenance;

  GateStats({
    required this.total,
    required this.active,
    required this.inactive,
    required this.maintenance,
  });
}

class GateService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _currentAdminId => _auth.currentUser?.uid;

  // Get all gates for current admin
  Stream<List<GateModel>> getGates() {
    if (_currentAdminId == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('gates')
        .where(
          'communityId',
          isEqualTo: AdminTenantContext.instance.requireCommunityId(),
        )
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => GateModel.fromFirestore(doc)).toList(),
        );
  }

  // Get gate by ID
  Future<GateModel?> getGateById(String gateId) async {
    try {
      final doc = await _firestore.collection('gates').doc(gateId).get();
      if (doc.exists) {
        return GateModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('Error fetching gate: $e');
      return null;
    }
  }

  // Add new gate
  Future<bool> addGate({
    required String gateName,
    required String gateType,
    required String workingStatus,
    String? shiftTime,
    String? buildingId,
  }) async {
    try {
      if (_currentAdminId == null) {
        print('Error: No admin logged in');
        return false;
      }

      final gateData = {
        'gateName': gateName,
        'gateType': gateType,
        'workingStatus': workingStatus,
        'shiftTime': shiftTime,
        'assignedSecurityId': null,
        'assignedSecurityName': null,
        'adminId': _currentAdminId,
        'communityId': AdminTenantContext.instance.requireCommunityId(),
        'buildingId': buildingId,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('gates').add(gateData);
      print('✅ Gate added successfully');
      return true;
    } catch (e) {
      print('❌ Error adding gate: $e');
      return false;
    }
  }

  // Update gate
  Future<bool> updateGate({
    required String gateId,
    required String gateName,
    required String gateType,
    required String workingStatus,
    String? shiftTime,
  }) async {
    try {
      await _firestore.collection('gates').doc(gateId).update({
        'gateName': gateName,
        'gateType': gateType,
        'workingStatus': workingStatus,
        'shiftTime': shiftTime,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('✅ Gate updated successfully');
      return true;
    } catch (e) {
      print('❌ Error updating gate: $e');
      return false;
    }
  }

  // Delete gate
  Future<bool> deleteGate(String gateId) async {
    try {
      await _firestore.collection('gates').doc(gateId).delete();
      print('✅ Gate deleted successfully');
      return true;
    } catch (e) {
      print('❌ Error deleting gate: $e');
      return false;
    }
  }

  // Assign security to gate with full assignment details
  Future<bool> assignSecurityToGate({
    required String gateId,
    required String securityId,
    required String securityName,
    required String shiftTiming,
    String? specialInstructions,
  }) async {
    try {
      await _firestore.collection('gates').doc(gateId).update({
        'assignedSecurityId': securityId,
        'assignedSecurityName': securityName,
        'assignedShiftTiming': shiftTiming,
        'assignedSpecialInstructions': specialInstructions,
        'assignedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('✅ Security assigned to gate successfully');
      return true;
    } catch (e) {
      print('❌ Error assigning security to gate: $e');
      return false;
    }
  }

  // Remove security from gate
  Future<bool> removeSecurityFromGate(String gateId) async {
    try {
      await _firestore.collection('gates').doc(gateId).update({
        'assignedSecurityId': null,
        'assignedSecurityName': null,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('✅ Security removed from gate successfully');
      return true;
    } catch (e) {
      print('❌ Error removing security from gate: $e');
      return false;
    }
  }

  // Get gate statistics
  Future<GateStats> getGateStats() async {
    try {
      if (_currentAdminId == null) {
        return GateStats(total: 0, active: 0, inactive: 0, maintenance: 0);
      }

      final snapshot = await _firestore
          .collection('gates')
          .where(
            'communityId',
            isEqualTo: AdminTenantContext.instance.requireCommunityId(),
          )
          .get();

      int total = snapshot.docs.length;
      int active = 0;
      int inactive = 0;
      int maintenance = 0;

      for (var doc in snapshot.docs) {
        final status = doc.data()['workingStatus'] as String?;
        if (status == 'Active') {
          active++;
        } else if (status == 'Inactive') {
          inactive++;
        } else if (status == 'Maintenance') {
          maintenance++;
        }
      }

      return GateStats(
        total: total,
        active: active,
        inactive: inactive,
        maintenance: maintenance,
      );
    } catch (e) {
      print('Error fetching gate stats: $e');
      return GateStats(total: 0, active: 0, inactive: 0, maintenance: 0);
    }
  }
}
