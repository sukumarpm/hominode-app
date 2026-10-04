import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'admin_service.dart';

typedef BillingV2FinancialReportCallable =
    Future<Map<String, dynamic>> Function(Map<String, dynamic> payload);

class ReportsServiceException implements Exception {
  final String userMessage;
  final String technicalMessage;

  ReportsServiceException(this.userMessage, this.technicalMessage);

  @override
  String toString() => 'ReportsServiceException($technicalMessage)';
}

String formatInrMinorUnitsForReports(int minorUnits) {
  if (minorUnits < 0) return 'Unavailable';
  final rupees = minorUnits ~/ 100;
  final paise = minorUnits % 100;
  final formattedRupees = _formatIndianDigitGroups(rupees);
  return '₹$formattedRupees.${paise.toString().padLeft(2, '0')}';
}

String _formatIndianDigitGroups(int value) {
  final digits = value.toString();
  if (digits.length <= 3) return digits;
  final head = digits.substring(0, digits.length - 3);
  final tail = digits.substring(digits.length - 3);
  final parts = <String>[];
  int index = head.length;
  while (index > 2) {
    parts.insert(0, head.substring(index - 2, index));
    index -= 2;
  }
  if (index > 0) {
    parts.insert(0, head.substring(0, index));
  }
  return '${parts.join(',')},$tail';
}

class ReportsService {
  ReportsService({
    FirebaseFirestore? firestore,
    AdminService? adminService,
    FirebaseFunctions? functions,
    BillingV2FinancialReportCallable? financialReportCallable,
    String? Function()? currentAdminIdProvider,
    String Function()? currentCommunityIdProvider,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _adminService = adminService,
       _functions = functions,
       _financialReportCallable = financialReportCallable,
       _currentAdminIdProvider = currentAdminIdProvider,
       _currentCommunityIdProvider = currentCommunityIdProvider;

  final FirebaseFirestore _firestore;
  final AdminService? _adminService;
  final FirebaseFunctions? _functions;
  final BillingV2FinancialReportCallable? _financialReportCallable;
  final String? Function()? _currentAdminIdProvider;
  final String Function()? _currentCommunityIdProvider;

  FirebaseFunctions get _regionalFunctions =>
      _functions ?? FirebaseFunctions.instanceFor(region: 'asia-southeast1');

  String? _currentAdminId() {
    final provider = _currentAdminIdProvider;
    if (provider != null) return provider();
    final service = _adminService;
    return service?.getCurrentAdminId() ?? AdminService().getCurrentAdminId();
  }

  String _requireCurrentCommunityId() {
    final provider = _currentCommunityIdProvider;
    if (provider != null) return provider();
    final service = _adminService;
    return service?.requireCurrentCommunityId() ??
        AdminService().requireCurrentCommunityId();
  }

  String _toBillingPeriod(int year, int month) {
    if (month < 1 || month > 12) {
      throw ArgumentError.value(month, 'month', 'Month must be 1-12.');
    }
    final yyyy = year.toString().padLeft(4, '0');
    final mm = month.toString().padLeft(2, '0');
    return '$yyyy-$mm';
  }

  int _requiredNonNegativeInt(Object? value, String fieldName) {
    if (value is! int || value < 0) {
      throw FormatException('Invalid integer field: $fieldName');
    }
    return value;
  }

  Map<String, dynamic> _requiredMap(Object? value, String fieldName) {
    if (value is! Map) {
      throw FormatException('Invalid object field: $fieldName');
    }
    return Map<String, dynamic>.from(value);
  }

  Future<Map<String, dynamic>> _callBillingV2FinancialReport(
    Map<String, dynamic> payload,
  ) async {
    final callable = _financialReportCallable;
    if (callable != null) {
      return callable(payload);
    }
    final response = await _regionalFunctions
        .httpsCallable('getBillingV2FinancialReport')
        .call(payload);
    final data = response.data;
    if (data is! Map) {
      throw const FormatException('Financial report response is invalid.');
    }
    return Map<String, dynamic>.from(data);
  }

  // ============================================================================
  // FINANCIAL REPORTS
  // ============================================================================

  /// Get financial summary for a specific month
  Future<FinancialSummary> getFinancialSummary({
    required int year,
    required int month,
  }) async {
    final billingPeriod = _toBillingPeriod(year, month);
    try {
      final adminId = _currentAdminId();
      if (adminId == null) throw Exception('Admin not logged in');

      print('ReportsService: Fetching financial summary for $year-$month');

      final report = await _callBillingV2FinancialReport({
        'communityId': _requireCurrentCommunityId(),
        'billingPeriod': billingPeriod,
      });

      if (report['success'] != true) {
        throw const FormatException(
          'Financial report response is not successful.',
        );
      }

      final liabilitySummary = _requiredMap(
        report['liabilitySummary'],
        'liabilitySummary',
      );
      final collectionActivity = _requiredMap(
        report['collectionActivity'],
        'collectionActivity',
      );
      final creditPosition = _requiredMap(
        report['creditPosition'],
        'creditPosition',
      );
      final methodSummary = _requiredMap(
        collectionActivity['methods'],
        'collectionActivity.methods',
      );
      final upi = _requiredMap(methodSummary['upi'], 'methods.upi');
      final cash = _requiredMap(methodSummary['cash'], 'methods.cash');
      final bankTransfer = _requiredMap(
        methodSummary['bank_transfer'],
        'methods.bank_transfer',
      );
      final cheque = _requiredMap(methodSummary['cheque'], 'methods.cheque');
      final statusCounts = _requiredMap(
        liabilitySummary['statusCounts'],
        'liabilitySummary.statusCounts',
      );

      final totalBilledMinor = _requiredNonNegativeInt(
        liabilitySummary['billedMinor'],
        'billedMinor',
      );
      final collectionsReceivedMinor = _requiredNonNegativeInt(
        collectionActivity['totalReceivedMinor'],
        'totalReceivedMinor',
      );
      final outstandingMinor = _requiredNonNegativeInt(
        liabilitySummary['outstandingMinor'],
        'outstandingMinor',
      );
      final overdueOutstandingMinor = _requiredNonNegativeInt(
        liabilitySummary['overdueOutstandingMinor'],
        'overdueOutstandingMinor',
      );
      final availableCreditMinor = _requiredNonNegativeInt(
        creditPosition['totalAvailableCreditMinor'],
        'totalAvailableCreditMinor',
      );
      final creditAppliedMinor = _requiredNonNegativeInt(
        liabilitySummary['creditAppliedMinor'],
        'creditAppliedMinor',
      );

      print(
        'ReportsService: Financial summary loaded for $billingPeriod '
        '(billed=$totalBilledMinor, received=$collectionsReceivedMinor)',
      );

      return FinancialSummary(
        totalRevenue: collectionsReceivedMinor / 100,
        maintenanceRevenue: 0,
        utilitiesRevenue: 0,
        parkingRevenue: 0,
        otherRevenue: 0,
        totalBills: _requiredNonNegativeInt(
          liabilitySummary['billsCount'],
          'billsCount',
        ),
        paidBills: _requiredNonNegativeInt(
          statusCounts['paid'],
          'statusCounts.paid',
        ),
        pendingBills: _requiredNonNegativeInt(
          statusCounts['pending'],
          'statusCounts.pending',
        ),
        partiallyPaidBills: _requiredNonNegativeInt(
          statusCounts['partially_paid'],
          'statusCounts.partially_paid',
        ),
        overdueBills: _requiredNonNegativeInt(
          statusCounts['overdue'],
          'statusCounts.overdue',
        ),
        totalBilledMinor: totalBilledMinor,
        collectionsReceivedMinor: collectionsReceivedMinor,
        outstandingMinor: outstandingMinor,
        overdueOutstandingMinor: overdueOutstandingMinor,
        availableCreditMinor: availableCreditMinor,
        creditAppliedMinor: creditAppliedMinor,
        transactionCount: _requiredNonNegativeInt(
          collectionActivity['transactionCount'],
          'transactionCount',
        ),
        upiCollection: PaymentMethodSummary(
          count: _requiredNonNegativeInt(upi['count'], 'methods.upi.count'),
          totalMinor: _requiredNonNegativeInt(
            upi['totalMinor'],
            'methods.upi.totalMinor',
          ),
        ),
        cashCollection: PaymentMethodSummary(
          count: _requiredNonNegativeInt(cash['count'], 'methods.cash.count'),
          totalMinor: _requiredNonNegativeInt(
            cash['totalMinor'],
            'methods.cash.totalMinor',
          ),
        ),
        bankTransferCollection: PaymentMethodSummary(
          count: _requiredNonNegativeInt(
            bankTransfer['count'],
            'methods.bank_transfer.count',
          ),
          totalMinor: _requiredNonNegativeInt(
            bankTransfer['totalMinor'],
            'methods.bank_transfer.totalMinor',
          ),
        ),
        chequeCollection: PaymentMethodSummary(
          count: _requiredNonNegativeInt(
            cheque['count'],
            'methods.cheque.count',
          ),
          totalMinor: _requiredNonNegativeInt(
            cheque['totalMinor'],
            'methods.cheque.totalMinor',
          ),
        ),
        accountsCount: _requiredNonNegativeInt(
          creditPosition['accountsCount'],
          'accountsCount',
        ),
        residentsWithCreditCount: _requiredNonNegativeInt(
          creditPosition['residentsWithCreditCount'],
          'residentsWithCreditCount',
        ),
        month: month,
        year: year,
      );
    } on FirebaseFunctionsException catch (e) {
      print(
        'ReportsService ERROR: Financial report callable failed: ${e.code} ${e.message}',
      );
      throw ReportsServiceException(
        'Financial report is unavailable right now. Please try again shortly.',
        'functions_error:${e.code}:${e.message}',
      );
    } on FormatException catch (e) {
      print('ReportsService ERROR: Invalid financial report payload: $e');
      throw ReportsServiceException(
        'Financial report data is temporarily unavailable. Please try again.',
        'format_error:$e',
      );
    } on ReportsServiceException {
      rethrow;
    } catch (e) {
      print('ReportsService ERROR: Failed to fetch financial summary: $e');
      throw ReportsServiceException(
        'Financial report is unavailable right now. Please try again shortly.',
        'unexpected_error:$e',
      );
    }
  }

  /// Get monthly revenue trends (last 6 months)
  Future<List<MonthlyRevenue>> getMonthlyRevenueTrends() async {
    final adminId = _currentAdminId();
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
  }

  // ============================================================================
  // OCCUPANCY REPORTS
  // ============================================================================

  /// Get occupancy summary
  Future<OccupancySummary> getOccupancySummary() async {
    try {
      final adminId = _currentAdminId();
      if (adminId == null) throw Exception('Admin not logged in');

      print('ReportsService: Fetching occupancy summary');

      // Get all flats
      final flatsSnapshot = await _firestore
          .collection('flats')
          .where('communityId', isEqualTo: _requireCurrentCommunityId())
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
      throw ReportsServiceException(
        'Occupancy report is unavailable right now. Please try again shortly.',
        'occupancy_summary_error:$e',
      );
    }
  }

  /// Get building-wise occupancy
  Future<List<BuildingOccupancy>> getBuildingOccupancy() async {
    try {
      final adminId = _currentAdminId();
      if (adminId == null) throw Exception('Admin not logged in');

      print('ReportsService: Fetching building-wise occupancy');

      // Get all buildings
      final buildingsSnapshot = await _firestore
          .collection('buildings')
          .where('communityId', isEqualTo: _requireCurrentCommunityId())
          .get();

      final List<BuildingOccupancy> buildingOccupancies = [];

      for (var buildingDoc in buildingsSnapshot.docs) {
        final buildingData = buildingDoc.data();
        final buildingName = buildingData['buildingName'] ?? 'Unknown';
        final buildingId = buildingDoc.id;

        // Get flats for this building
        final flatsSnapshot = await _firestore
            .collection('flats')
            .where('communityId', isEqualTo: _requireCurrentCommunityId())
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
      throw ReportsServiceException(
        'Building occupancy is unavailable right now. Please try again shortly.',
        'building_occupancy_error:$e',
      );
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
      final adminId = _currentAdminId();
      if (adminId == null) throw Exception('Admin not logged in');

      print('ReportsService: Fetching complaints summary for $year-$month');

      // Get start and end dates for the month
      final startDate = DateTime(year, month, 1);
      final endDate = DateTime(year, month + 1, 0, 23, 59, 59);

      // Fetch complaints for the month
      final complaintsSnapshot = await _firestore
          .collection('complaints')
          .where('communityId', isEqualTo: _requireCurrentCommunityId())
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
      throw ReportsServiceException(
        'Complaints report is unavailable right now. Please try again shortly.',
        'complaints_summary_error:$e',
      );
    }
  }

  /// Get monthly complaints trends (last 6 months)
  Future<List<MonthlyComplaints>> getMonthlyComplaintsTrends() async {
    try {
      final adminId = _currentAdminId();
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
      throw ReportsServiceException(
        'Complaint trends are unavailable right now. Please try again shortly.',
        'complaints_trends_error:$e',
      );
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
      final adminId = _currentAdminId();
      if (adminId == null) throw Exception('Admin not logged in');

      // Get start and end dates for the month
      final startDate = DateTime(year, month, 1);
      final endDate = DateTime(year, month + 1, 0, 23, 59, 59);

      // Fetch parcels for the month
      final parcelsSnapshot = await _firestore
          .collection('parcels')
          .where('communityId', isEqualTo: _requireCurrentCommunityId())
          .where(
            'receivedAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
          )
          .where('receivedAt', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .get();

      return parcelsSnapshot.docs.length;
    } catch (e) {
      print('ReportsService ERROR: Failed to fetch deliveries count: $e');
      throw ReportsServiceException(
        'Deliveries are unavailable right now. Please try again shortly.',
        'deliveries_count_error:$e',
      );
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
  final int partiallyPaidBills;
  final int overdueBills;
  final int totalBilledMinor;
  final int collectionsReceivedMinor;
  final int creditAppliedMinor;
  final int outstandingMinor;
  final int overdueOutstandingMinor;
  final int availableCreditMinor;
  final int transactionCount;
  final PaymentMethodSummary upiCollection;
  final PaymentMethodSummary cashCollection;
  final PaymentMethodSummary bankTransferCollection;
  final PaymentMethodSummary chequeCollection;
  final int accountsCount;
  final int residentsWithCreditCount;
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
    required this.partiallyPaidBills,
    required this.overdueBills,
    required this.totalBilledMinor,
    required this.collectionsReceivedMinor,
    required this.creditAppliedMinor,
    required this.outstandingMinor,
    required this.overdueOutstandingMinor,
    required this.availableCreditMinor,
    required this.transactionCount,
    required this.upiCollection,
    required this.cashCollection,
    required this.bankTransferCollection,
    required this.chequeCollection,
    required this.accountsCount,
    required this.residentsWithCreditCount,
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
      partiallyPaidBills: 0,
      overdueBills: 0,
      totalBilledMinor: 0,
      collectionsReceivedMinor: 0,
      creditAppliedMinor: 0,
      outstandingMinor: 0,
      overdueOutstandingMinor: 0,
      availableCreditMinor: 0,
      transactionCount: 0,
      upiCollection: const PaymentMethodSummary(count: 0, totalMinor: 0),
      cashCollection: const PaymentMethodSummary(count: 0, totalMinor: 0),
      bankTransferCollection: const PaymentMethodSummary(
        count: 0,
        totalMinor: 0,
      ),
      chequeCollection: const PaymentMethodSummary(count: 0, totalMinor: 0),
      accountsCount: 0,
      residentsWithCreditCount: 0,
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

  String get formattedTotalBilled =>
      formatInrMinorUnitsForReports(totalBilledMinor);

  String get formattedCollectionsReceived =>
      formatInrMinorUnitsForReports(collectionsReceivedMinor);

  String get formattedOutstanding =>
      formatInrMinorUnitsForReports(outstandingMinor);

  String get formattedOverdueOutstanding =>
      formatInrMinorUnitsForReports(overdueOutstandingMinor);

  String get formattedAvailableCredit =>
      formatInrMinorUnitsForReports(availableCreditMinor);

  String get formattedCreditApplied =>
      formatInrMinorUnitsForReports(creditAppliedMinor);
}

class PaymentMethodSummary {
  final int count;
  final int totalMinor;

  const PaymentMethodSummary({required this.count, required this.totalMinor});

  String get formattedTotal => formatInrMinorUnitsForReports(totalMinor);
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
