import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'billing_service.dart';
import 'visitor_lifecycle.dart';

class _DashboardSnapshots {
  const _DashboardSnapshots({required this.users, required this.visitors});

  final QuerySnapshot<Map<String, dynamic>> users;
  final QuerySnapshot<Map<String, dynamic>> visitors;
}

class DashboardService {
  DashboardService({
    FirebaseFirestore? firestore,
    BillingService? billingService,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _billingService = billingService ?? BillingService();
  final FirebaseFirestore _firestore;
  final BillingService _billingService;

  // Visitor decisions and gate transitions must refresh Home counts even when
  // the resident roster has not changed. Retain the existing financial reads.
  Stream<_DashboardSnapshots> _dashboardChanges(String communityId) {
    late StreamController<_DashboardSnapshots> controller;
    final subscriptions = <StreamSubscription<dynamic>>[];
    QuerySnapshot<Map<String, dynamic>>? users;
    QuerySnapshot<Map<String, dynamic>>? visitors;
    void refresh() {
      final currentUsers = users;
      final currentVisitors = visitors;
      if (currentUsers != null && currentVisitors != null) {
        controller.add(
          _DashboardSnapshots(users: currentUsers, visitors: currentVisitors),
        );
      }
    }

    controller = StreamController<_DashboardSnapshots>(
      onListen: () {
        subscriptions.add(
          _firestore
              .collection('users')
              .where('role', isEqualTo: 'resident')
              .where('communityId', isEqualTo: communityId)
              .snapshots()
              .listen((snapshot) {
                users = snapshot;
                refresh();
              }, onError: controller.addError),
        );
        subscriptions.add(
          _firestore
              .collection('visitors')
              .where('communityId', isEqualTo: communityId)
              .snapshots()
              .listen((snapshot) {
                visitors = snapshot;
                refresh();
              }, onError: controller.addError),
        );
      },
      onCancel: () async {
        for (final subscription in subscriptions) {
          await subscription.cancel();
        }
      },
    );
    return controller.stream;
  }

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
        .snapshots()
        .map(
          (snapshot) => pendingVisitorCount(
            snapshot.docs.map((doc) => doc.data()),
            communityId,
          ),
        );
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
    return _dashboardChanges(communityId).asyncMap((snapshots) async {
      final totalResidents = snapshots.users.docs.length;
      final reads = await Future.wait([
        _firestore
            .collection('flats')
            .where('communityId', isEqualTo: communityId)
            .get(),
        _firestore
            .collection('complaints')
            .where('communityId', isEqualTo: communityId)
            .get(),
        _firestore
            .collection('bills')
            .where('communityId', isEqualTo: communityId)
            .get(),
      ]);
      final totalFlats = reads[0].docs.length;
      final complaintsSnapshot = reads[1];
      final billsSnapshot = reads[2];

      final pendingVisitors = pendingVisitorCount(
        snapshots.visitors.docs.map((doc) => doc.data()),
        communityId,
      );
      final pendingComplaints = complaintsSnapshot.docs.where((doc) {
        final data = doc.data();
        final status = data['status'] as String?;
        return status == 'pending' || status == 'in-progress';
      }).length;

      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

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

/// Reuses a dashboard feed across widget rebuilds while switching feeds when
/// the selected community changes.
class DashboardStatsStreamCache {
  DashboardStatsStreamCache(this._createStream);

  final Stream<DashboardStats> Function(String communityId) _createStream;
  String? _communityId;
  Stream<DashboardStats>? _stream;

  Stream<DashboardStats> forCommunity(String communityId) {
    if (_stream == null || _communityId != communityId) {
      _communityId = communityId;
      _stream = _createStream(communityId);
    }
    return _stream!;
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
