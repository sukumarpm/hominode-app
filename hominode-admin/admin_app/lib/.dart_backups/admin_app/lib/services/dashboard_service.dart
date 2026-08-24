import 'package:cloud_firestore/cloud_firestore.dart';
import 'billing_service.dart';

class DashboardService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final BillingService _billingService = BillingService();

  // Get total residents count filtered by adminId
  Stream<int> getTotalResidentsCount(String communityId) {
    return _firestore
        .collection('users')
        .where('role', isEqualTo: 'resident')
        .where('communityId', isEqualTo: communityId)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  // Get total flats count filtered by adminId
  Stream<int> getTotalFlatsCount(String communityId) {
    return _firestore
        .collection('flats')
        .where('communityId', isEqualTo: communityId)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  // Get pending visitors count filtered by adminId
  Stream<int> getPendingVisitorsCount(String communityId) {
    return _firestore
        .collection('visitors')
        .where('communityId', isEqualTo: communityId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  // Get pending complaints count filtered by adminId
  Stream<int> getPendingComplaintsCount(String communityId) {
    return _firestore
        .collection('complaints')
        .where('communityId', isEqualTo: communityId)
        .where('status', whereIn: ['pending', 'in-progress'])
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  // Get this month's collection using BillingService (filtered by adminId)
  Stream<double> getThisMonthCollection(String communityId) {
    return _billingService.getThisMonthCollection(communityId);
  }

  // Get dashboard statistics (combined) filtered by adminId
  Stream<DashboardStats> getDashboardStats(String communityId) {
    return _firestore
        .collection('users')
        .where('role', isEqualTo: 'resident')
        .where('communityId', isEqualTo: communityId)
        .snapshots()
        .asyncMap((usersSnapshot) async {
          // Filter by adminId in memory
          final totalResidents = usersSnapshot.docs.length;

          // Get total flats
          final flatsSnapshot = await _firestore
              .collection('flats')
              .where('communityId', isEqualTo: communityId)
              .get();
          // Filter by adminId in memory
          final totalFlats = flatsSnapshot.docs.length;

          // Get pending visitors
          final visitorsSnapshot = await _firestore
              .collection('visitors')
              .where('communityId', isEqualTo: communityId)
              .get();
          // Filter by adminId and status in memory
          final pendingVisitors = visitorsSnapshot.docs.where((doc) {
            final data = doc.data();
            return data['status'] == 'pending';
          }).length;

          // Get pending complaints
          final complaintsSnapshot = await _firestore
              .collection('complaints')
              .where('communityId', isEqualTo: communityId)
              .get();
          // Filter by adminId and status in memory
          final pendingComplaints = complaintsSnapshot.docs.where((doc) {
            final data = doc.data();
            final status = data['status'] as String?;
            return status == 'pending' || status == 'in-progress';
          }).length;

          // Get this month's collection
          final now = DateTime.now();
          final startOfMonth = DateTime(now.year, now.month, 1);
          final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

          final billsSnapshot = await _firestore
              .collection('bills')
              .where('communityId', isEqualTo: communityId)
              .get();

          double monthlyCollection = 0;
          for (var doc in billsSnapshot.docs) {
            final data = doc.data();

            // Filter by adminId, status, and date in memory
            if (data['status'] != 'paid') continue;

            final paidAt = data['paidAt'] as Timestamp?;
            if (paidAt == null) continue;

            final paidDate = paidAt.toDate();
            if (paidDate.isBefore(startOfMonth) || paidDate.isAfter(endOfMonth)) {
              continue;
            }
            monthlyCollection += (data['amount'] as num?)?.toDouble() ?? 0;
          }

          return DashboardStats(
            totalResidents: totalResidents,
            totalFlats: totalFlats,
            pendingVisitors: pendingVisitors,
            pendingComplaints: pendingComplaints,
            monthlyCollection: monthlyCollection,
          );
        });
  }
}

// Dashboard Statistics Model
class DashboardStats {
  final int totalResidents;
  final int totalFlats;
  final int pendingVisitors;
  final int pendingComplaints;
  final double monthlyCollection;

  DashboardStats({
    required this.totalResidents,
    required this.totalFlats,
    required this.pendingVisitors,
    required this.pendingComplaints,
    required this.monthlyCollection,
  });

  String get formattedCollection {
    if (monthlyCollection >= 100000) {
      return '₹${(monthlyCollection / 100000).toStringAsFixed(1)}L';
    } else if (monthlyCollection >= 1000) {
      return '₹${(monthlyCollection / 1000).toStringAsFixed(1)}K';
    } else {
      return '₹${monthlyCollection.toStringAsFixed(0)}';
    }
  }
}
