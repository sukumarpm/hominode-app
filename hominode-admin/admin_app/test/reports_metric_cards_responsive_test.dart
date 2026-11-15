import 'dart:io';

import 'package:admin_app/reports_analytics_screen.dart';
import 'package:admin_app/services/reports_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

const _titles = [
  'Collections Received',
  'Occupancy Rate',
  'Resolved Issues',
  'Deliveries',
];
const _values = ['₹34.5K', '92.0%', '37', '128'];
const _icons = [
  Icons.account_balance_wallet,
  Icons.home,
  Icons.check_circle,
  Icons.local_shipping,
];
const _colors = [
  Color(0xFF0E4778),
  Color(0xFF10B981),
  Color(0xFF8B5CF6),
  Color(0xFFF59E0B),
];

class _Reports extends Fake implements ReportsService {
  @override
  Future<FinancialSummary> getFinancialSummary({
    required int year,
    required int month,
  }) async => FinancialSummary.empty(month: month, year: year);
  @override
  Future<OccupancySummary> getOccupancySummary() async =>
      OccupancySummary.empty();
  @override
  Future<List<BuildingOccupancy>> getBuildingOccupancy() async => [];
  @override
  Future<ComplaintsSummary> getComplaintsSummary({
    required int year,
    required int month,
  }) async => ComplaintsSummary.empty(month: month, year: year);
  @override
  Future<List<MonthlyComplaints>> getMonthlyComplaintsTrends() async => [];
  @override
  Future<List<MonthlyRevenue>> getMonthlyRevenueTrends() async => [];
  @override
  Future<int> getDeliveriesCount({
    required int year,
    required int month,
  }) async => 0;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    // Use mobile glyph metrics to check full label height and wrapping.
    var directory = File(Platform.resolvedExecutable).parent;
    while (!File(
      '${directory.path}/bin/cache/artifacts/material_fonts/Roboto-Regular.ttf',
    ).existsSync()) {
      final parent = directory.parent;
      if (parent.path == directory.path) {
        throw StateError('Flutter Roboto font not found');
      }
      directory = parent;
    }
    final fonts = FontLoader('Roboto');
    for (final font in ['Roboto-Regular.ttf', 'Roboto-Medium.ttf']) {
      final bytes = File(
        '${directory.path}/bin/cache/artifacts/material_fonts/$font',
      ).readAsBytesSync();
      fonts.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await fonts.load();
  });

  Future<void> mount(
    WidgetTester tester,
    Size size,
    Widget child, {
    double scale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        minTextAdapt: true,
        splitScreenMode: true,
        builder: (_, _) => MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: child,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Widget card(int index, bool unavailable) => AnalyticsKpiCard(
    key: ValueKey('metric-$index'),
    title: _titles[index],
    value: unavailable ? '—' : _values[index],
    growth: index == 2 ? '84.0%' : '+0%',
    isPositive: true,
    showGrowth: index != 0,
    isUnavailable: unavailable,
    icon: _icons[index],
    color: _colors[index],
  );

  void expectFullLabel(WidgetTester tester, Finder finder) {
    final text = tester.widget<Text>(finder);
    final paragraph = tester.renderObject<RenderParagraph>(finder);
    final context = tester.element(finder);
    final painter = TextPainter(
      text: TextSpan(
        text: text.data,
        style: DefaultTextStyle.of(context).style.merge(text.style),
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(maxWidth: paragraph.size.width);
    expect(paragraph.didExceedMaxLines, isFalse);
    expect(paragraph.size.height, greaterThanOrEqualTo(painter.height - 0.01));
    painter.dispose();
    final card = find.ancestor(
      of: finder,
      matching: find.byType(AnalyticsKpiCard),
    );
    final bounds = tester.getRect(card);
    final label = tester.getRect(finder);
    expect(label.left, greaterThanOrEqualTo(bounds.left));
    expect(label.right, lessThanOrEqualTo(bounds.right));
    expect(label.bottom, lessThanOrEqualTo(bounds.bottom));
  }

  for (final size in [
    const Size(393, 852),
    const Size(600, 960),
    const Size(800, 1280),
  ]) {
    for (final scale in [1.0, 1.3, 1.5]) {
      for (final unavailable in [false, true]) {
        testWidgets(
          'metrics fit ${size.width}x${size.height}, scale $scale, unavailable $unavailable',
          (tester) async {
            await mount(
              tester,
              size,
              Builder(
                builder: (_) => Scaffold(
                  body: SingleChildScrollView(
                    child: Padding(
                      padding: EdgeInsets.all(20.w),
                      child: Column(
                        children: [
                          for (var row = 0; row < 2; row++) ...[
                            if (row > 0) SizedBox(height: 16.h),
                            IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(child: card(row * 2, unavailable)),
                                  SizedBox(width: 16.w),
                                  Expanded(
                                    child: card(row * 2 + 1, unavailable),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              scale: scale,
            );
            expect(tester.takeException(), isNull);
            for (var index = 0; index < 4; index++) {
              final metric = find.byKey(ValueKey('metric-$index'));
              final bounds = tester.getRect(metric);
              final sibling = tester.getRect(
                find.byKey(
                  ValueKey('metric-${index.isEven ? index + 1 : index - 1}'),
                ),
              );
              expect(bounds.top, closeTo(sibling.top, 0.01));
              expect(bounds.bottom, closeTo(sibling.bottom, 0.01));
              expect(bounds.width, closeTo(sibling.width, 0.01));
              expect(bounds.left, greaterThanOrEqualTo(0));
              expect(bounds.right, lessThanOrEqualTo(size.width));
              expectFullLabel(tester, find.text(_titles[index]));
              expect(
                find.descendant(
                  of: metric,
                  matching: find.byIcon(_icons[index]),
                ),
                findsOneWidget,
              );
              expect(
                tester.widget<AnalyticsKpiCard>(metric).color,
                _colors[index],
              );
              expect(
                find.descendant(
                  of: metric,
                  matching: find.text(unavailable ? '—' : _values[index]),
                ),
                findsOneWidget,
              );
              if (unavailable) {
                expectFullLabel(
                  tester,
                  find.descendant(
                    of: metric,
                    matching: find.text('Unavailable'),
                  ),
                );
              } else if (index != 0) {
                expect(
                  find.descendant(
                    of: metric,
                    matching: find.text(index == 2 ? '84.0%' : '+0%'),
                  ),
                  findsOneWidget,
                );
              }
              if (size.width == 393 && scale == 1) {
                expect(bounds.height, closeTo(168 * size.height / 844, 0.01));
              }
            }
            await tester.ensureVisible(find.text('Deliveries'));
            await tester.pumpAndSettle();
            expect(
              tester.getRect(find.text('Deliveries')).bottom,
              lessThanOrEqualTo(size.height),
            );
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }

  for (final size in [
    const Size(393, 852),
    const Size(600, 960),
    const Size(800, 1280),
  ]) {
    testWidgets('actual Reports screen retains two columns at ${size.width}', (
      tester,
    ) async {
      await mount(
        tester,
        size,
        ReportsAnalyticsScreen(reportsService: _Reports()),
      );
      expect(tester.takeException(), isNull);
      final keys = [
        'kpi-collections',
        'kpi-occupancy',
        'kpi-resolved-issues',
        'kpi-deliveries',
      ];
      final cards = [
        for (final key in keys) tester.getRect(find.byKey(ValueKey(key))),
      ];
      expect(cards[0].top, closeTo(cards[1].top, 0.01));
      expect(cards[0].bottom, closeTo(cards[1].bottom, 0.01));
      expect(cards[2].top, closeTo(cards[3].top, 0.01));
      expect(cards[2].bottom, closeTo(cards[3].bottom, 0.01));
      expect(cards[2].top, greaterThan(cards[0].bottom));
      for (final title in _titles) {
        expectFullLabel(tester, find.text(title));
      }
    });
  }
}
