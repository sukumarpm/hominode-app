import 'package:admin_app/reports_analytics_screen.dart';
import 'package:admin_app/services/reports_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

class _ReportsService extends ReportsService {
  _ReportsService({
    this.occupancy,
    this.buildings = const [],
    this.complaints,
    this.trends = const [],
    this.occupancyError,
    this.complaintsError,
    this.financialError,
    this.deliveryError,
  }) : super(
         firestore: FakeFirebaseFirestore(),
         currentAdminIdProvider: () => 'admin-1',
         currentCommunityIdProvider: () => 'community-1',
       );

  final OccupancySummary? occupancy;
  final List<BuildingOccupancy> buildings;
  final ComplaintsSummary? complaints;
  final List<MonthlyComplaints> trends;
  final Object? occupancyError;
  final Object? complaintsError;
  final Object? financialError;
  final Object? deliveryError;

  @override
  Future<FinancialSummary> getFinancialSummary({
    required int year,
    required int month,
  }) async {
    if (financialError != null) throw financialError!;
    return FinancialSummary.empty(month: month, year: year);
  }

  @override
  Future<OccupancySummary> getOccupancySummary() async {
    if (occupancyError != null) throw occupancyError!;
    return occupancy ?? OccupancySummary.empty();
  }

  @override
  Future<List<BuildingOccupancy>> getBuildingOccupancy() async {
    if (occupancyError != null) throw occupancyError!;
    return buildings;
  }

  @override
  Future<ComplaintsSummary> getComplaintsSummary({
    required int year,
    required int month,
  }) async {
    if (complaintsError != null) throw complaintsError!;
    return complaints ?? ComplaintsSummary.empty(month: month, year: year);
  }

  @override
  Future<List<MonthlyComplaints>> getMonthlyComplaintsTrends() async {
    if (complaintsError != null) throw complaintsError!;
    return trends;
  }

  @override
  Future<int> getDeliveriesCount({
    required int year,
    required int month,
  }) async {
    if (deliveryError != null) throw deliveryError!;
    return 0;
  }
}

Widget _app(ReportsService service) => ScreenUtilInit(
  designSize: const Size(390, 844),
  minTextAdapt: true,
  splitScreenMode: true,
  builder: (_, __) =>
      MaterialApp(home: ReportsAnalyticsScreen(reportsService: service)),
);

Future<void> _showTab(WidgetTester tester, String tab) async {
  final tabFinder = find.descendant(
    of: find.byType(SegmentedTabBar),
    matching: find.text(tab),
  );
  await tester.ensureVisible(tabFinder);
  await tester.pumpAndSettle();
  await tester.tap(tabFinder);
  await tester.pumpAndSettle();
}

void _configureViewport(
  WidgetTester tester, {
  Size size = const Size(390, 844),
}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  testWidgets('occupancy shows summary and building occupancy counts', (
    tester,
  ) async {
    _configureViewport(tester);

    await tester.pumpWidget(
      _app(
        _ReportsService(
          occupancy: OccupancySummary(
            totalFlats: 10,
            occupiedFlats: 6,
            vacantFlats: 3,
            maintenanceFlats: 1,
            occupancyRate: 60,
          ),
          buildings: [
            BuildingOccupancy(
              buildingName: 'Tower A',
              totalFlats: 5,
              occupiedFlats: 4,
              occupancyRate: 80,
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _showTab(tester, 'Occupancy');

    expect(find.text('60.0%'), findsOneWidget);
    expect(find.text('Occupied'), findsOneWidget);
    expect(find.text('6'), findsOneWidget);
    expect(find.text('Vacant'), findsOneWidget);
    expect(find.text('Maintenance'), findsOneWidget);
    expect(find.text('Tower A'), findsOneWidget);
    expect(find.text('Occupied 4 of 5'), findsOneWidget);
    expect(find.text('80.0%'), findsOneWidget);
  });

  testWidgets('occupancy errors are visible and do not look like zero data', (
    tester,
  ) async {
    _configureViewport(tester);
    await tester.pumpWidget(
      _app(
        _ReportsService(
          occupancyError: ReportsServiceException(
            'Occupancy report is unavailable right now. Please try again shortly.',
            'private technical details',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _showTab(tester, 'Occupancy');

    expect(find.text('Occupancy data unavailable'), findsOneWidget);
    expect(
      find.text(
        'Occupancy report is unavailable right now. Please try again shortly.',
      ),
      findsOneWidget,
    );
    expect(find.text('private technical details'), findsNothing);
    expect(find.text('0.0%'), findsNothing);
  });

  testWidgets(
    'complaints shows statuses, category breakdown and supplied trends',
    (tester) async {
      _configureViewport(tester);
      await tester.pumpWidget(
        _app(
          _ReportsService(
            complaints: ComplaintsSummary(
              totalComplaints: 8,
              resolvedComplaints: 3,
              pendingComplaints: 3,
              inProgressComplaints: 2,
              resolutionRate: 37.5,
              categoryBreakdown: {'Water': 3, 'Noise': 3, 'Lift': 2},
              month: DateTime.now().month,
              year: DateTime.now().year,
            ),
            trends: [
              MonthlyComplaints(
                month: 'April',
                year: 2030,
                totalComplaints: 4,
                resolvedComplaints: 2,
              ),
              MonthlyComplaints(
                month: 'May',
                year: 2030,
                totalComplaints: 0,
                resolvedComplaints: 0,
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _showTab(tester, 'Complaints');

      expect(find.text('37.5%'), findsOneWidget);
      expect(find.text('Total complaints'), findsOneWidget);
      expect(find.text('Resolved'), findsWidgets);
      expect(find.text('In progress'), findsOneWidget);
      expect(find.text('Pending'), findsOneWidget);
      expect(find.text('April\n2030'), findsOneWidget);
      expect(find.text('May\n2030'), findsOneWidget);
      expect(find.text('No complaint trend data available.'), findsNothing);
      final noise = tester.getTopLeft(find.text('Noise')).dy;
      final water = tester.getTopLeft(find.text('Water')).dy;
      final lift = tester.getTopLeft(find.text('Lift')).dy;
      expect(noise, lessThan(water));
      expect(water, lessThan(lift));
    },
  );

  testWidgets('empty occupancy and complaints show explicit empty states', (
    tester,
  ) async {
    _configureViewport(tester);
    await tester.pumpWidget(_app(_ReportsService()));
    await tester.pumpAndSettle();

    await _showTab(tester, 'Occupancy');
    expect(find.text('No building occupancy data available.'), findsOneWidget);

    await _showTab(tester, 'Complaints');
    expect(
      find.text('No complaint categories for this period.'),
      findsOneWidget,
    );
    expect(find.text('No complaint trend data available.'), findsOneWidget);
  });

  testWidgets('complaints errors stay within complaints analytics', (
    tester,
  ) async {
    _configureViewport(tester);
    await tester.pumpWidget(
      _app(
        _ReportsService(
          complaintsError: ReportsServiceException(
            'Complaints report is unavailable right now. Please try again shortly.',
            'private technical details',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _showTab(tester, 'Complaints');

    expect(find.text('Complaints data unavailable'), findsOneWidget);
    expect(
      find.text(
        'Complaints report is unavailable right now. Please try again shortly.',
      ),
      findsOneWidget,
    );
    expect(find.text('private technical details'), findsNothing);
    expect(find.text('0.0%'), findsNothing);

    await _showTab(tester, 'Financial');
    expect(find.text('Billing V2 Summary'), findsOneWidget);
  });

  testWidgets('occupancy and complaints export says it is unavailable', (
    tester,
  ) async {
    _configureViewport(tester);
    await tester.pumpWidget(_app(_ReportsService()));
    await tester.pumpAndSettle();
    await _showTab(tester, 'Occupancy');

    await tester.ensureVisible(find.text('Export').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Export').first);
    await tester.pumpAndSettle();

    expect(
      find.text('Export is not available yet for this report.'),
      findsOneWidget,
    );
    expect(find.textContaining('Generating PDF'), findsNothing);
  });

  testWidgets('real zero deliveries and 25 percent occupancy remain visible', (
    tester,
  ) async {
    _configureViewport(tester);
    await tester.pumpWidget(
      _app(
        _ReportsService(
          occupancy: OccupancySummary(
            totalFlats: 12,
            occupiedFlats: 3,
            vacantFlats: 9,
            maintenanceFlats: 0,
            occupancyRate: 25,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('kpi-occupancy')),
        matching: find.text('25.0%'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('kpi-deliveries')),
        matching: find.text('0'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('unavailable KPI sources show a dash and secondary status', (
    tester,
  ) async {
    _configureViewport(tester);
    await tester.pumpWidget(
      _app(
        _ReportsService(
          financialError: ReportsServiceException('safe', 'financial failure'),
          occupancyError: ReportsServiceException('safe', 'occupancy failure'),
          complaintsError: ReportsServiceException(
            'safe',
            'complaints failure',
          ),
          deliveryError: ReportsServiceException('safe', 'delivery failure'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (final key in [
      'kpi-collections',
      'kpi-occupancy',
      'kpi-resolved-issues',
      'kpi-deliveries',
    ]) {
      final card = find.byKey(ValueKey(key));
      expect(
        find.descendant(of: card, matching: find.text('—')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: card, matching: find.text('Unavailable')),
        findsOneWidget,
      );
      if (key == 'kpi-deliveries') {
        expect(
          find.descendant(of: card, matching: find.text('0')),
          findsNothing,
        );
      }
    }
  });

  testWidgets('KPI cards have equal height and fit a narrow phone viewport', (
    tester,
  ) async {
    _configureViewport(tester, size: const Size(320, 720));
    await tester.pumpWidget(_app(_ReportsService()));
    await tester.pumpAndSettle();

    final heights = [
      'kpi-collections',
      'kpi-occupancy',
      'kpi-resolved-issues',
      'kpi-deliveries',
    ].map((key) => tester.getSize(find.byKey(ValueKey(key))).height).toSet();

    expect(heights, hasLength(1));
    expect(tester.takeException(), isNull);
  });
}
