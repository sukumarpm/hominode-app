// lib/src/services/admin_data_service.dart
// Admin Data Service - Centralized admin data fetching with flow functions

import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_data_service.dart';

class AdminDataService {
  static final AdminDataService _instance = AdminDataService._internal();

  factory AdminDataService() {
    return _instance;
  }

  AdminDataService._internal();

  static AdminDataService get instance => _instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final UserDataService _userDataService = UserDataService.instance;

  /// Get all admin statistics following flow function pattern
  Future<AdminStatistics?> getAllAdminStatistics() async {
    try {
      print('\n═══════════════════════════════════════════════════');
      print('📊 GET ALL ADMIN STATISTICS');
      print('═══════════════════════════════════════════════════\n');

      // STEP 1: Verify user is admin
      print('📋 STEP 1: Verify User is Admin');
      final isAdmin = await _userDataService.isAdmin();
      
      if (!isAdmin) {
        print('❌ User is not admin - access denied\n');
        return null;
      }
      print('✅ User is admin - access granted\n');

      // STEP 2: Get current user data
      print('📋 STEP 2: Get Current User Data');
      final userData = await _userDataService.getCurrentUserData();
      
      if (userData == null) {
        print('❌ No user data found\n');
        return null;
      }

      final buildingId = userData['buildingId'];
      print('✅ Building ID: $buildingId\n');

      // STEP 3: Fetch building statistics
      print('📋 STEP 3: Fetch Building Statistics');
      final buildingStats = await _fetchBuildingStatistics(buildingId);
      print('✅ Building stats fetched\n');

      // STEP 4: Fetch resident statistics
      print('📋 STEP 4: Fetch Resident Statistics');
      final residentStats = await _fetchResidentStatistics(buildingId);
      print('✅ Resident stats fetched\n');

      // STEP 5: Fetch complaint statistics
      print('📋 STEP 5: Fetch Complaint Statistics');
      final complaintStats = await _fetchComplaintStatistics(buildingId);
      print('✅ Complaint stats fetched\n');

      // STEP 6: Fetch visitor statistics
      print('📋 STEP 6: Fetch Visitor Statistics');
      final visitorStats = await _fetchVisitorStatistics(buildingId);
      print('✅ Visitor stats fetched\n');

      // STEP 7: Compile all statistics
      print('📋 STEP 7: Compile All Statistics');
      final statistics = AdminStatistics(
        buildingId: buildingId,
        totalResidents: residentStats['total'] ?? 0,
        totalFlats: buildingStats['totalFlats'] ?? 0,
        totalComplaints: complaintStats['total'] ?? 0,
        openComplaints: complaintStats['open'] ?? 0,
        totalVisitors: visitorStats['total'] ?? 0,
        pendingVisitors: visitorStats['pending'] ?? 0,
        monthlyCollection: buildingStats['monthlyCollection'] ?? 0.0,
      );

      print('✅ Statistics compiled:');
      print('   Total Residents: ${statistics.totalResidents}');
      print('   Total Flats: ${statistics.totalFlats}');
      print('   Total Complaints: ${statistics.totalComplaints}');
      print('   Open Complaints: ${statistics.openComplaints}');
      print('   Total Visitors: ${statistics.totalVisitors}');
      print('   Pending Visitors: ${statistics.pendingVisitors}');
      print('   Monthly Collection: ₹${statistics.monthlyCollection}\n');

      print('═══════════════════════════════════════════════════');
      print('✅ ADMIN STATISTICS FETCHED SUCCESSFULLY');
      print('═══════════════════════════════════════════════════\n');

      return statistics;
    } catch (e) {
      print('❌ Error fetching admin statistics: $e\n');
      return null;
    }
  }

  /// Fetch building statistics
  Future<Map<String, dynamic>> _fetchBuildingStatistics(String buildingId) async {
    try {
      final buildingDoc = await _firestore
          .collection('buildings')
          .doc(buildingId)
          .get();

      if (!buildingDoc.exists) {
        return {'totalFlats': 0, 'monthlyCollection': 0.0};
      }

      final data = buildingDoc.data() ?? {};
      return {
        'totalFlats': data['totalFlats'] ?? 0,
        'monthlyCollection': (data['monthlyCollection'] ?? 0).toDouble(),
      };
    } catch (e) {
      print('⚠️  Error fetching building statistics: $e');
      return {'totalFlats': 0, 'monthlyCollection': 0.0};
    }
  }

  /// Fetch resident statistics
  Future<Map<String, dynamic>> _fetchResidentStatistics(String buildingId) async {
    try {
      final query = await _firestore
          .collection('users')
          .where('buildingId', isEqualTo: buildingId)
          .where('role', isEqualTo: 'resident')
          .count()
          .get();

      return {'total': query.count};
    } catch (e) {
      print('⚠️  Error fetching resident statistics: $e');
      return {'total': 0};
    }
  }

  /// Fetch complaint statistics
  Future<Map<String, dynamic>> _fetchComplaintStatistics(String buildingId) async {
    try {
      final totalQuery = await _firestore
          .collection('complaints')
          .where('buildingId', isEqualTo: buildingId)
          .count()
          .get();

      final openQuery = await _firestore
          .collection('complaints')
          .where('buildingId', isEqualTo: buildingId)
          .where('status', isEqualTo: 'open')
          .count()
          .get();

      return {
        'total': totalQuery.count,
        'open': openQuery.count,
      };
    } catch (e) {
      print('⚠️  Error fetching complaint statistics: $e');
      return {'total': 0, 'open': 0};
    }
  }

  /// Fetch visitor statistics
  Future<Map<String, dynamic>> _fetchVisitorStatistics(String buildingId) async {
    try {
      final totalQuery = await _firestore
          .collection('visitors')
          .where('buildingId', isEqualTo: buildingId)
          .count()
          .get();

      final pendingQuery = await _firestore
          .collection('visitors')
          .where('buildingId', isEqualTo: buildingId)
          .where('status', isEqualTo: 'pending')
          .count()
          .get();

      return {
        'total': totalQuery.count,
        'pending': pendingQuery.count,
      };
    } catch (e) {
      print('⚠️  Error fetching visitor statistics: $e');
      return {'total': 0, 'pending': 0};
    }
  }

  /// Get pending visitors for approval
  Future<List<Map<String, dynamic>>> getPendingVisitors(String buildingId) async {
    try {
      print('📋 Fetching pending visitors for building: $buildingId');
      
      final query = await _firestore
          .collection('visitors')
          .where('buildingId', isEqualTo: buildingId)
          .where('status', isEqualTo: 'pending')
          .orderBy('createdAt', descending: true)
          .get();

      print('✅ Found ${query.docs.length} pending visitors');
      
      return query.docs
          .map((doc) => {
                'id': doc.id,
                ...doc.data(),
              })
          .toList();
    } catch (e) {
      print('❌ Error fetching pending visitors: $e');
      return [];
    }
  }

  /// Approve visitor
  Future<bool> approveVisitor(String visitorId) async {
    try {
      print('📋 Approving visitor: $visitorId');
      
      await _firestore
          .collection('visitors')
          .doc(visitorId)
          .update({
            'status': 'approved',
            'approvedAt': DateTime.now(),
          });

      print('✅ Visitor approved successfully');
      return true;
    } catch (e) {
      print('❌ Error approving visitor: $e');
      return false;
    }
  }

  /// Reject visitor
  Future<bool> rejectVisitor(String visitorId, String reason) async {
    try {
      print('📋 Rejecting visitor: $visitorId');
      print('   Reason: $reason');
      
      await _firestore
          .collection('visitors')
          .doc(visitorId)
          .update({
            'status': 'rejected',
            'rejectionReason': reason,
            'rejectedAt': DateTime.now(),
          });

      print('✅ Visitor rejected successfully');
      return true;
    } catch (e) {
      print('❌ Error rejecting visitor: $e');
      return false;
    }
  }
}

/// Admin Statistics Model
class AdminStatistics {
  final String buildingId;
  final int totalResidents;
  final int totalFlats;
  final int totalComplaints;
  final int openComplaints;
  final int totalVisitors;
  final int pendingVisitors;
  final double monthlyCollection;

  AdminStatistics({
    required this.buildingId,
    required this.totalResidents,
    required this.totalFlats,
    required this.totalComplaints,
    required this.openComplaints,
    required this.totalVisitors,
    required this.pendingVisitors,
    required this.monthlyCollection,
  });

  /// Get resolved complaints count
  int get resolvedComplaints => totalComplaints - openComplaints;

  /// Get approved visitors count
  int get approvedVisitors => totalVisitors - pendingVisitors;

  /// Get collection percentage
  double get collectionPercentage {
    if (totalFlats == 0) return 0;
    return (monthlyCollection / (totalFlats * 1000)) * 100; // Assuming 1000 per flat
  }
}
