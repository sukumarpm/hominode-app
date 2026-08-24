// lib/src/services/admin_statistics_service.dart
// Admin statistics service for dashboard

import 'package:cloud_firestore/cloud_firestore.dart';

class AdminStatisticsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Stream total residents count
  Stream<int> streamTotalResidents() {
    return _firestore
        .collection('users')
        .where('role', isEqualTo: 'resident')
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  /// Stream total flats count
  Stream<int> streamTotalFlats() {
    return _firestore
        .collection('flats')
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  /// Stream pending visitors count
  Stream<int> streamPendingVisitors() {
    return _firestore
        .collection('visitors')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  /// Stream pending complaints count
  Stream<int> streamPendingComplaints() {
    return _firestore
        .collection('complaints')
        .where('status', whereIn: ['pending', 'in_progress'])
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  /// Stream this month's collection (sum of paid bills)
  Stream<double> streamMonthlyCollection() {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    return _firestore
        .collection('bills')
        .where('status', isEqualTo: 'paid')
        .where('paidAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
        .where('paidAt', isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth))
        .snapshots()
        .map((snapshot) {
      double total = 0;
      for (var doc in snapshot.docs) {
        final data = doc.data();
        total += (data['amount'] as num?)?.toDouble() ?? 0;
      }
      return total;
    });
  }

  /// Get all statistics at once
  Future<Map<String, dynamic>> getAllStatistics() async {
    try {
      // Get residents count
      final residentsSnapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'resident')
          .get();

      // Get flats count
      final flatsSnapshot = await _firestore
          .collection('flats')
          .get();

      // Get pending visitors count
      final visitorsSnapshot = await _firestore
          .collection('visitors')
          .where('status', isEqualTo: 'pending')
          .get();

      // Get pending complaints count
      final complaintsSnapshot = await _firestore
          .collection('complaints')
          .where('status', whereIn: ['pending', 'in_progress'])
          .get();

      // Get this month's collection
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

      final billsSnapshot = await _firestore
          .collection('bills')
          .where('status', isEqualTo: 'paid')
          .where('paidAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
          .where('paidAt', isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth))
          .get();

      double monthlyCollection = 0;
      for (var doc in billsSnapshot.docs) {
        final data = doc.data();
        monthlyCollection += (data['amount'] as num?)?.toDouble() ?? 0;
      }

      return {
        'totalResidents': residentsSnapshot.docs.length,
        'totalFlats': flatsSnapshot.docs.length,
        'pendingVisitors': visitorsSnapshot.docs.length,
        'pendingComplaints': complaintsSnapshot.docs.length,
        'monthlyCollection': monthlyCollection,
      };
    } catch (e) {
      print('❌ Error fetching statistics: $e');
      return {
        'totalResidents': 0,
        'totalFlats': 0,
        'pendingVisitors': 0,
        'pendingComplaints': 0,
        'monthlyCollection': 0.0,
      };
    }
  }

  /// Get pending visitors list
  Future<List<Map<String, dynamic>>> getPendingVisitors() async {
    try {
      final snapshot = await _firestore
          .collection('visitors')
          .where('status', isEqualTo: 'pending')
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      print('❌ Error fetching pending visitors: $e');
      return [];
    }
  }

  /// Approve visitor
  Future<bool> approveVisitor(String visitorId) async {
    try {
      await _firestore.collection('visitors').doc(visitorId).update({
        'status': 'approved',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('✅ Visitor approved: $visitorId');
      return true;
    } catch (e) {
      print('❌ Error approving visitor: $e');
      return false;
    }
  }
}
