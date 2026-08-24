import 'package:cloud_firestore/cloud_firestore.dart';
import 'admin_service.dart';

class ReportsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AdminService _adminService = AdminService();

  // ============================================================================
  // FINANCIAL REPORTS
  // ============================================================================

  /// Get financial summary for a specific month
  Future<FinancialSummary> getFinancialSummary({
    required int year,
    required int month,
  }) async {
    try {
      final adminId = _adminService.getCurrentAdminId();
      if (adminId == null) throw Exception('Admin not logged in');

      print('ReportsService: Fetching financial summary for $year-$month');

      // Get start and end dates for the month
      final startDate = DateTime(year, month, 1);
      final endDate = DateTime(year, month + 1, 0, 23, 59, 59);

      // Fetch bills for the month
      final billsSnapshot = await _firestore
          .collection('bills')
          .where(
            'communityId',
            isEqualTo: _adminService.requireCurrentCommunityId(),
          )
          .where(
            'createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
          )
          .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .get();

      double totalRevenue = 0;
      double maintenanceRevenue = 0;
      double utilitiesRevenue = 0;
      double parkingRevenue = 0;
      double otherRevenue = 0;
      int totalBills = billsSnapshot.docs.length;
      int paidBills = 0;
      int pendingBills = 0;

      for (var doc in billsSnapshot.docs) {
        final data = doc.data();
        final amount = (data['totalAmount'] ?? 0).toDouble();
        final status = data['status'] ?? 'pending';
        final billType = data['billType'] ?? 'Maintenance';

        if (status == 'paid') {
          totalRevenue += amount;
          paidBills++;

          // Categorize revenue
          if (billType.toLowerCase().contains('maintenance')) {
            maintenanceRevenue += amount;
          } else if (billType.toLowerCase().contains('utility') ||
              billType.toLowerCase().contains('water') ||
              billType.toLowerCase().contains('electricity')) {
            utilitiesRevenue += amount;
          } else if (billType.toLowerCase().contains('parking')) {
            parkingRevenue += amount;
          } else {
            otherRevenue += amount;
          }
        } else {
          pendingBills++;
        }
      }

      print(
        'ReportsService: Financial summary - Revenue: ₹$totalRevenue, Bills: $totalBills',
      );

      return FinancialSummary(
        totalRevenue: totalRevenue,
        maintenanceRevenue: maintenanceRevenue,
        utilitiesRevenue: utilitiesRevenue,
        parkingRevenue: parkingRevenue,
        otherRevenue: otherRevenue,
        totalBills: totalBills,
        paidBills: paidBills,
        pendingBills: pendingBills,
        month: month,
        year: year,
      );
    } catch (e) {
      print('ReportsService ERROR: Failed to fetch financial summary: $e');
      return FinancialSummary.empty(month: month, year: year);
    }
  }

  /// Get monthly revenue trends (last 6 months)
  Future<List<MonthlyRevenue>> getMonthlyRevenueTrends() async {
    try {
      final adminId = _adminService.getCurrentAdminId();
      if (adminId == null) throw Exception('Admin not logged in');

      final List<MonthlyRevenue> trends = [];
      final now = DateTime.now();

      for (int i = 5; i >= 0; i--) {
        final targetDate = DateTime(now.year, now.month - i, 1);
        final summary = await getFinancialSummary(
          year: targetDate.year,
          month: targetDate.month,
        );

        trends.add(
          MonthlyRevenue(
            month: _getMonthName(targetDate.month),
            year: targetDate.year,
            revenue: summary.totalRevenue,
          ),
        );
      }

      return trends;
    } catch (e) {
      print('ReportsService ERROR: Failed to fetch revenue trends: $e');
      return [];
    }
  }

  // ============================================================================
  // OCCUPANCY REPORTS
  // ============================================================================

  /// Get occupancy summary
  Future<OccupancySummary> getOccupancySummary() async {
    try {
      final adminId = _adminService.getCurrentAdminId();
      if (adminId == null) throw Exception('Admin not logged in');

      print('ReportsService: Fetching occupancy summary');

      // Get all flats
      final flatsSnapshot = await _firestore
          .collection('flats')
          .where(
            'communityId',
            isEqualTo: _adminService.requireCurrentCommunityId(),
          )
          .get();

      int totalFlats = flatsSnapshot.docs.length;
      int occupiedFlats = 0;
      int vacantFlats = 0;
      int maintenanceFlats = 0;

      for (var doc in flatsSnapshot.docs) {
        final data = doc.data();
        final status = (data['status'] ?? 'vacant').toString().toLowerCase();

        if (status == 'occupied') {
          occupiedFlats++;
        } else if (status == 'maintenance') {
          maintenanceFlats++;
        } else {
          vacantFlats++;
        }
      }

      final occupancyRate = totalFlats > 0
          ? (occupiedFlats / totalFlats) * 100
          : 0.0;

      print(
        'ReportsService: Occupancy - Total: $totalFlats, Occupied: $occupiedFlats, Rate: $occupancyRate%',
      );

      return OccupancySummary(
        totalFlats: totalFlats,
        occupiedFlats: occupiedFlats,
        vacantFlats: vacantFlats,
        maintenanceFlats: maintenanceFlats,
        occupancyRate: occupancyRate,
      );
    } catch (e) {
      print('ReportsService ERROR: Failed to fetch occupancy summary: $e');
      return OccupancySummary.empty();
    }
  }

  /// Get building-wise occupancy
  Future<List<BuildingOccupancy>> getBuildingOccupancy() async {
    try {
      final adminId = _adminService.getCurrentAdminId();
      if (adminId == null) throw Exception('Admin not logged in');

      print('ReportsService: Fetching building-wise occupancy');

      // Get all buildings
      final buildingsSnapshot = await _firestore
          .collection('buildings')
          .where(
            'communityId',
            isEqualTo: _adminService.requireCurrentCommunityId(),
          )
          .get();

      final List<BuildingOccupancy> buildingOccupancies = [];

      for (var buildingDoc in buildingsSnapshot.docs) {
        final buildingData = buildingDoc.data();
        final buildingName = buildingData['buildingName'] ?? 'Unknown';
        final buildingId = buildingDoc.id;

        // Get flats for this building
        final flatsSnapshot = await _firestore
            .collection('flats')
            .where(
              'communityId',
              isEqualTo: _adminService.requireCurrentCommunityId(),
            )
            .where('buildingId', isEqualTo: buildingId)
            .get();

        int totalFlats = flatsSnapshot.docs.length;
        int occupiedFlats = 0;

        for (var flatDoc in flatsSnapshot.docs) {
          final flatData = flatDoc.data();
          final status = (flatData['status'] ?? 'vacant')
              .toString()
              .toLowerCase();
          if (status == 'occupied') {
            occupiedFlats++;
          }
        }

        final occupancyRate = totalFlats > 0
            ? (occupiedFlats / totalFlats) * 100
            : 0.0;

        buildingOccupancies.add(
          BuildingOccupancy(
            buildingName: buildingName,
            totalFlats: totalFlats,
            occupiedFlats: occupiedFlats,
            occupancyRate: occupancyRate,
          ),
        );
      }

      return buildingOccupancies;
    } catch (e) {
      print('ReportsService ERROR: Failed to fetch building occupancy: $e');
      return [];
    }
  }

  // ============================================================================
  // COMPLAINTS REPORTS
  // ============================================================================

  /// Get complaints summary for a specific month
  Future<ComplaintsSummary> getComplaintsSummary({
    required int year,
    required int month,
  }) async {
    try {
      final adminId = _adminService.getCurrentAdminId();
      if (adminId == null) throw Exception('Admin not logged in');

      print('ReportsService: Fetching complaints summary for $year-$month');

      // Get start and end dates for the month
      final startDate = DateTime(year, month, 1);
      final endDate = DateTime(year, month + 1, 0, 23, 59, 59);

      // Fetch complaints for the month
      final complaintsSnapshot = await _firestore
          .collection('complaints')
          .where(
            'communityId',
            isEqualTo: _adminService.requireCurrentCommunityId(),
          )
          .where(
            'createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
          )
          .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .get();

      int totalComplaints = complaintsSnapshot.docs.length;
      int resolvedComplaints = 0;
      int pendingComplaints = 0;
      int inProgressComplaints = 0;

      // Category counts
      Map<String, int> categoryCount = {};

      for (var doc in complaintsSnapshot.docs) {
        final data = doc.data();
        final status = (data['status'] ?? 'pending').toString().toLowerCase();
        final category = data['category'] ?? 'Other';

        // Count by status
        if (status == 'resolved') {
          resolvedComplaints++;
        } else if (status == 'in-progress') {
          inProgressComplaints++;
        } else {
          pendingComplaints++;
        }

        // Count by category
        categoryCount[category] = (categoryCount[category] ?? 0) + 1;
      }

      final resolutionRate = totalComplaints > 0
          ? (resolvedComplaints / totalComplaints) * 100
          : 0.0;

      print(
        'ReportsService: Complaints - Total: $totalComplaints, Resolved: $resolvedComplaints, Rate: $resolutionRate%',
      );

      return ComplaintsSummary(
        totalComplaints: totalComplaints,
        resolvedComplaints: resolvedComplaints,
        pendingComplaints: pendingComplaints,
        inProgressComplaints: inProgressComplaints,
        resolutionRate: resolutionRate,
        categoryBreakdown: categoryCount,
        month: month,
        year: year,
      );
    } catch (e) {
      print('ReportsService ERROR: Failed to fetch complaints summary: $e');
      return ComplaintsSummary.empty(month: month, year: year);
    }
  }

  /// Get monthly complaints trends (last 6 months)
  Future<List<MonthlyComplaints>> getMonthlyComplaintsTrends() async {
    try {
      final adminId = _adminService.getCurrentAdminId();
      if (adminId == null) throw Exception('Admin not logged in');

      final List<MonthlyComplaints> trends = [];
      final now = DateTime.now();

      for (int i = 5; i >= 0; i--) {
        final targetDate = DateTime(now.year, now.month - i, 1);
        final summary = await getComplaintsSummary(
          year: targetDate.year,
          month: targetDate.month,
        );

        trends.add(
          MonthlyComplaints(
            month: _getMonthName(targetDate.month),
            year: targetDate.year,
            totalComplaints: summary.totalComplaints,
            resolvedComplaints: summary.resolvedComplaints,
          ),
        );
      }

      return trends;
    } catch (e) {
      print('ReportsService ERROR: Failed to fetch complaints trends: $e');
      return [];
    }
  }

  // ============================================================================
  // DELIVERIES REPORTS
  // ============================================================================

  /// Get deliveries count for a specific month
  Future<int> getDeliveriesCount({
    required int year,
    required int month,
  }) async {
    try {
      final adminId = _adminService.getCurrentAdminId();
      if (adminId == null) throw Exception('Admin not logged in');

      // Get start and end dates for the month
      final startDate = DateTime(year, month, 1);
      final endDate = DateTime(year, month + 1, 0, 23, 59, 59);

      // Fetch parcels for the month
      final parcelsSnapshot = await _firestore
          .collection('parcels')
          .where(
            'communityId',
            isEqualTo: _adminService.requireCurrentCommunityId(),
          )
          .where(
            'receivedAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
          )
          .where('receivedAt', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .get();

      return parcelsSnapshot.docs.length;
    } catch (e) {
      print('ReportsService ERROR: Failed to fetch deliveries count: $e');
      return 0;
    }
  }

  // ============================================================================
  // HELPER METHODS
  // ============================================================================

  String _getMonthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[month - 1];
  }
}

// ============================================================================
// DATA MODELS
// ============================================================================

class FinancialSummary {
  final double totalRevenue;
  final double maintenanceRevenue;
  final double utilitiesRevenue;
  final double parkingRevenue;
  final double otherRevenue;
  final int totalBills;
  final int paidBills;
  final int pendingBills;
  final int month;
  final int year;

  FinancialSummary({
    required this.totalRevenue,
    required this.maintenanceRevenue,
    required this.utilitiesRevenue,
    required this.parkingRevenue,
    required this.otherRevenue,
    required this.totalBills,
    required this.paidBills,
    required this.pendingBills,
    required this.month,
    required this.year,
  });

  factory FinancialSummary.empty({required int month, required int year}) {
    return FinancialSummary(
      totalRevenue: 0,
      maintenanceRevenue: 0,
      utilitiesRevenue: 0,
      parkingRevenue: 0,
      otherRevenue: 0,
      totalBills: 0,
      paidBills: 0,
      pendingBills: 0,
      month: month,
      year: year,
    );
  }

  String get formattedRevenue {
    if (totalRevenue >= 100000) {
      return '₹${(totalRevenue / 100000).toStringAsFixed(1)}L';
    } else if (totalRevenue >= 1000) {
      return '₹${(totalRevenue / 1000).toStringAsFixed(1)}K';
    } else {
      return '₹${totalRevenue.toStringAsFixed(0)}';
    }
  }
}

class MonthlyRevenue {
  final String month;
  final int year;
  final double revenue;

  MonthlyRevenue({
    required this.month,
    required this.year,
    required this.revenue,
  });

  double get revenueInLakhs => revenue / 100000;
}

class OccupancySummary {
  final int totalFlats;
  final int occupiedFlats;
  final int vacantFlats;
  final int maintenanceFlats;
  final double occupancyRate;

  OccupancySummary({
    required this.totalFlats,
    required this.occupiedFlats,
    required this.vacantFlats,
    required this.maintenanceFlats,
    required this.occupancyRate,
  });

  factory OccupancySummary.empty() {
    return OccupancySummary(
      totalFlats: 0,
      occupiedFlats: 0,
      vacantFlats: 0,
      maintenanceFlats: 0,
      occupancyRate: 0.0,
    );
  }

  String get formattedOccupancyRate => '${occupancyRate.toStringAsFixed(1)}%';
}

class BuildingOccupancy {
  final String buildingName;
  final int totalFlats;
  final int occupiedFlats;
  final double occupancyRate;

  BuildingOccupancy({
    required this.buildingName,
    required this.totalFlats,
    required this.occupiedFlats,
    required this.occupancyRate,
  });
}

class ComplaintsSummary {
  final int totalComplaints;
  final int resolvedComplaints;
  final int pendingComplaints;
  final int inProgressComplaints;
  final double resolutionRate;
  final Map<String, int> categoryBreakdown;
  final int month;
  final int year;

  ComplaintsSummary({
    required this.totalComplaints,
    required this.resolvedComplaints,
    required this.pendingComplaints,
    required this.inProgressComplaints,
    required this.resolutionRate,
    required this.categoryBreakdown,
    required this.month,
    required this.year,
  });

  factory ComplaintsSummary.empty({required int month, required int year}) {
    return ComplaintsSummary(
      totalComplaints: 0,
      resolvedComplaints: 0,
      pendingComplaints: 0,
      inProgressComplaints: 0,
      resolutionRate: 0.0,
      categoryBreakdown: {},
      month: month,
      year: year,
    );
  }

  String get formattedResolutionRate => '${resolutionRate.toStringAsFixed(1)}%';
}

class MonthlyComplaints {
  final String month;
  final int year;
  final int totalComplaints;
  final int resolvedComplaints;

  MonthlyComplaints({
    required this.month,
    required this.year,
    required this.totalComplaints,
    required this.resolvedComplaints,
  });
}
