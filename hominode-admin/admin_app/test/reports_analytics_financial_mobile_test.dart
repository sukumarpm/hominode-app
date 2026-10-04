import 'package:admin_app/reports_analytics_screen.dart';
import 'package:admin_app/services/reports_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeReportsService extends ReportsService {
  _FakeReportsService({
    this.financialSummary,
    this.financialError,
  }) : super(
         firestore: FakeFirebaseFirestore(),
         currentAdminIdProvider: () => 'admin-1',
         currentCommunityIdProvider: () => 'community-1',
       );

  final FinancialSummary? financialSummary;
  final Object? financialError;

  @override
  Future<FinancialSummary> getFinancialSummary({
    required int year,
    required int month,
  }) async {
    if (financialError != null) throw financialError!;
    return financialSummary ?? FinancialSummary.empty(month: month, year: year);
  }

  @override
  Future<List<MonthlyRevenue>> getMonthlyRevenueTrends() async {
    return [
      MonthlyRevenue(month: 'Dec', year: 2029, revenue: 1000),
      MonthlyRevenue(month: 'Jan', year: 2030, revenue: 1200),
    ];
  }

  @override
  Future<OccupancySummary> getOccupancySummary() async {
    return OccupancySummary.empty();
  }

  @override
  Future<List<BuildingOccupancy>> getBuildingOccupancy() async {
    return [];
  }

  @override
  Future<ComplaintsSummary> getComplaintsSummary({
    required int year,
    required int month,
  }) async {
    return ComplaintsSummary.empty(month: month, year: year);
  }

  @override
  Future<List<MonthlyComplaints>> getMonthlyComplaintsTrends() async {
    return [];
  }

  @override
  Future<int> getDeliveriesCount({required int year, required int month}) async {
    return 0;
  }
}

class _FlakyFinancialReportsService extends _FakeReportsService {
  _FlakyFinancialReportsService({required FinancialSummary initialSummary})
    : super(financialSummary: initialSummary);

  int _financialSummaryCallCount = 0;

  @override
  Future<FinancialSummary> getFinancialSummary({
    required int year,
    required int month,
  }) async {
    _financialSummaryCallCount += 1;
    if (_financialSummaryCallCount == 1) {
      return super.getFinancialSummary(year: year, month: month);
    }
    throw ReportsServiceException(
      'Financial report is unavailable right now. Please try again shortly.',
      'test-sequenced-failure',
    );
  }
}

class _TrendTrackingReportsService extends _FakeReportsService {
  _TrendTrackingReportsService({required FinancialSummary summary})
    : super(financialSummary: summary);

  int monthlyRevenueTrendsCallCount = 0;

  @override
  Future<List<MonthlyRevenue>> getMonthlyRevenueTrends() async {
    monthlyRevenueTrendsCallCount += 1;
    return super.getMonthlyRevenueTrends();
  }
}

Widget _testApp(ReportsService service) {
  return ScreenUtilInit(
    designSize: const Size(390, 844),
    minTextAdapt: true,
    splitScreenMode: true,
    builder: (_, __) => MaterialApp(
      home: ReportsAnalyticsScreen(reportsService: service),
    ),
  );
}

FinancialSummary _summary() {
  return FinancialSummary(
    totalRevenue: 3000,
    maintenanceRevenue: 0,
    utilitiesRevenue: 0,
    parkingRevenue: 0,
    otherRevenue: 0,
    totalBills: 12,
    paidBills: 3,
    pendingBills: 4,
    partiallyPaidBills: 3,
    overdueBills: 2,
    totalBilledMinor: 450000,
    collectionsReceivedMinor: 300000,
    creditAppliedMinor: 10000,
    outstandingMinor: 160000,
    overdueOutstandingMinor: 60000,
    availableCreditMinor: 25000,
    transactionCount: 11,
    upiCollection: const PaymentMethodSummary(count: 5, totalMinor: 170000),
    cashCollection: const PaymentMethodSummary(count: 3, totalMinor: 70000),
    bankTransferCollection: const PaymentMethodSummary(
      count: 2,
      totalMinor: 50000,
    ),
    chequeCollection: const PaymentMethodSummary(count: 1, totalMinor: 10000),
    accountsCount: 8,
    residentsWithCreditCount: 2,
    month: 1,
    year: 2030,
  );
}

Future<void> _pickDifferentYear(WidgetTester tester) async {
  final currentYear = DateTime.now().year;
  final targetYear = (currentYear - 1).toString();

  await tester.tap(find.byIcon(Icons.calendar_month));
  await tester.pumpAndSettle();

  final yearFinder = find.text(targetYear);
  if (yearFinder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      yearFinder,
      120,
      scrollable: find.byType(Scrollable).last,
    );
  }

  await tester.tap(yearFinder.first);
  await tester.pumpAndSettle();
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('desktop-only financial report entries are listed', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_testApp(_FakeReportsService(financialSummary: _summary())));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Desktop-only financial reports'),
      300,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('Desktop-only financial reports'), findsOneWidget);
    expect(find.text('Detailed collections report'), findsOneWidget);

    for (final label in [
      'Outstanding / overdue report',
      'Payment-method report',
      'Resident credit report',
      'Resident statement',
    ]) {
      await tester.scrollUntilVisible(
        find.text(label),
        120,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets('tapping desktop-only report shows web-desktop guidance', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_testApp(_FakeReportsService(financialSummary: _summary())));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Detailed collections report'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    final tileFinder = find.ancestor(
      of: find.text('Detailed collections report'),
      matching: find.byType(ListTile),
    );
    await tester.ensureVisible(tileFinder);
    final tile = tester.widget<ListTile>(tileFinder.first);
    tile.onTap!.call();
    await tester.pumpAndSettle();

    expect(
      find.textContaining(
        'Please open Admin Web/Desktop to view or export this report.',
      ),
      findsOneWidget,
    );
    expect(find.widgetWithText(TextButton, 'OK'), findsOneWidget);
  });

  testWidgets('financial backend error is shown safely and not zeroed silently', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _testApp(
        _FakeReportsService(
          financialError: ReportsServiceException(
            'Financial report is unavailable right now. Please try again shortly.',
            'test-error',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Financial report is unavailable right now. Please try again shortly.'),
      findsOneWidget,
    );
    expect(find.text('Unavailable'), findsWidgets);
    expect(find.text('₹0'), findsNothing);
  });

  testWidgets(
    'successful financial summary is cleared after a subsequent failed period load',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _testApp(_FlakyFinancialReportsService(initialSummary: _summary())),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('4,500'), findsOneWidget);

      await _pickDifferentYear(tester);

      expect(
        find.text('Financial report is unavailable right now. Please try again shortly.'),
        findsOneWidget,
      );
      expect(find.textContaining('4,500'), findsNothing);
      expect(find.text('Unavailable'), findsWidgets);
    },
  );

  testWidgets(
    'financial export shows desktop guidance and skips generating PDF path',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _testApp(_FakeReportsService(financialSummary: _summary())),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Export'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('currently available in Hominode Admin Web/Desktop'),
        findsOneWidget,
      );
      expect(find.textContaining('Generating PDF report for'), findsNothing);
    },
  );

  testWidgets(
    'financial mobile screen does not request monthly financial trends',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final service = _TrendTrackingReportsService(summary: _summary());

      await tester.pumpWidget(_testApp(service));
      await tester.pumpAndSettle();

      expect(service.monthlyRevenueTrendsCallCount, 0);

      await _pickDifferentYear(tester);

      expect(service.monthlyRevenueTrendsCallCount, 0);
    },
  );
}
