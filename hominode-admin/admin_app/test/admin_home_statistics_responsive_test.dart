import 'dart:async';
import 'dart:io';

import 'package:admin_app/billing_screen.dart';
import 'package:admin_app/complaint_management_screen.dart';
import 'package:admin_app/services/dashboard_service.dart';
import 'package:admin_app/visitor_management_screen.dart';
import 'package:admin_app/widgets/admin_home_statistics.dart';
import 'package:admin_app/widgets/admin_home_quick_actions_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

const _labels = [
  'Total\nResidents',
  'Total Flats',
  'Pending\nVisitors',
  'Pending\nComplaints',
  'This Month\nCollection',
];
const _footers = [
  'Active users',
  'All units',
  'Awaiting\napproval',
  'Needs\nattention',
  'Paid bills',
];

DashboardStats _stats({double collection = 125000}) => DashboardStats(
  totalResidents: 248,
  totalFlats: 164,
  pendingVisitors: 7,
  pendingComplaints: 3,
  monthlyCollection: collection,
);

class _Routes extends NavigatorObserver {
  final pushed = <Route<dynamic>>[];
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      pushed.add(route);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    // Use the same mobile glyph metrics as the app, rather than square Ahem.
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
    final loader = FontLoader('Roboto');
    for (final font in ['Roboto-Regular.ttf', 'Roboto-Medium.ttf']) {
      final bytes = File(
        '${directory.path}/bin/cache/artifacts/material_fonts/$font',
      ).readAsBytesSync();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
  });

  Future<void> mount(
    WidgetTester tester,
    Size size, {
    double scale = 1,
    Stream<DashboardStats>? stream,
    _Routes? routes,
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
          navigatorObservers: [if (routes != null) routes],
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: AdminHomeStatistics(
                statsStream: stream ?? Stream.value(_stats()),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  void expectFullText(WidgetTester tester, String value) {
    final finder = find.text(value);
    expect(finder, findsOneWidget);
    final paragraph = tester.renderObject<RenderParagraph>(finder);
    expect(paragraph.didExceedMaxLines, isFalse, reason: value);
    final text = tester.widget<Text>(finder);
    final context = tester.element(finder);
    final painter = TextPainter(
      text: TextSpan(
        text: value,
        style: DefaultTextStyle.of(context).style.merge(text.style),
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      textAlign: text.textAlign ?? TextAlign.start,
    )..layout(maxWidth: paragraph.size.width);
    expect(
      paragraph.size.height,
      greaterThanOrEqualTo(painter.height - 0.01),
      reason: value,
    );
    painter.dispose();
    final card = find.ancestor(of: finder, matching: find.byType(Ink));
    final bounds = tester.getRect(card);
    final textBounds = tester.getRect(finder);
    expect(
      textBounds.left,
      greaterThanOrEqualTo(bounds.left - 0.01),
      reason: value,
    );
    expect(
      textBounds.right,
      lessThanOrEqualTo(bounds.right + 0.01),
      reason: value,
    );
    expect(
      textBounds.bottom,
      lessThanOrEqualTo(bounds.bottom + 0.01),
      reason: value,
    );
  }

  for (final size in [
    const Size(393, 852),
    const Size(600, 960),
    const Size(800, 1280),
  ]) {
    for (final scale in [1.0, 1.3, 1.5]) {
      testWidgets(
        'five complete statistics at ${size.width}x${size.height}, scale $scale',
        (tester) async {
          await mount(tester, size, scale: scale);
          expect(tester.takeException(), isNull);
          final cards = find.byType(Ink);
          expect(cards, findsNWidgets(5));
          final bounds = tester.getRect(cards.first);
          for (var i = 0; i < 5; i++) {
            final rect = tester.getRect(cards.at(i));
            expect(rect.top, closeTo(bounds.top, 0.01));
            expect(rect.bottom, closeTo(bounds.bottom, 0.01));
            expect(rect.width, closeTo(bounds.width, 0.01));
            expect(rect.left, greaterThanOrEqualTo(0));
            expect(rect.right, lessThanOrEqualTo(size.width));
            expectFullText(tester, _labels[i]);
            expectFullText(tester, _footers[i]);
            final label = tester.getRect(find.text(_labels[i]));
            final footer = tester.getRect(find.text(_footers[i]));
            expect(footer.top, greaterThanOrEqualTo(label.bottom));
          }
          for (final value in ['248', '164', '7', '3', '₹1.3L']) {
            expect(find.text(value), findsOneWidget);
          }
          if (size.width == 393 && scale == 1) {
            expect(bounds.height, closeTo(150 * size.height / 844, 0.01));
          }
        },
      );
    }
  }

  testWidgets('loading and updated statistics use the supplied stream', (
    tester,
  ) async {
    final controller = StreamController<DashboardStats>();
    addTearDown(controller.close);
    await mount(tester, const Size(600, 960), stream: controller.stream);
    expect(find.text('—'), findsNWidgets(5));
    controller.add(_stats());
    await tester.pumpAndSettle();
    expect(find.text('248'), findsOneWidget);
    expect(find.text('₹1.3L'), findsOneWidget);
    controller.add(_stats(collection: 7300));
    await tester.pumpAndSettle();
    expect(find.text('₹7.3K'), findsOneWidget);
    expect(find.text('₹1.3L'), findsNothing);
    for (final text in [..._labels, ..._footers]) {
      expectFullText(tester, text);
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('statistics keep their existing navigation destinations', (
    tester,
  ) async {
    final routes = _Routes();
    await mount(tester, const Size(600, 960), routes: routes);
    for (var i = 0; i < 2; i++) {
      final tile = find.ancestor(
        of: find.text(_labels[i]),
        matching: find.byType(InkWell),
      );
      expect(tester.widget<InkWell>(tile).onTap, isNull);
    }
    for (var i = 2; i < 5; i++) {
      await tester.tap(find.text(_labels[i]));
      final route = routes.pushed.last as MaterialPageRoute;
      final destination = route.builder(
        tester.element(find.byType(AdminHomeStatistics)),
      );
      expect(
        destination,
        [
          isA<VisitorManagementScreen>(),
          isA<ComplaintManagementScreen>(),
          isA<BillingScreen>(),
        ][i - 2],
      );
      // Inspect the real route before rendering it; no Firebase-backed screen
      // or backend operation is started by this layout/navigation test.
      route.navigator!.removeRoute(route);
      await tester.pumpAndSettle();
    }
    expect(tester.takeException(), isNull);
  });

  for (final size in [
    const Size(393, 852),
    const Size(600, 960),
    const Size(800, 1280),
  ]) {
    for (final scale in [1.0, 1.3, 1.5]) {
      testWidgets('Quick Actions fit content at ${size.width} / $scale', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final calls = <int>[];
        final labels = List.generate(
          7,
          (i) =>
              i == 0 ? 'Approve Visitor and Review Registration' : 'Action $i',
        );
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
              home: Scaffold(
                body: SingleChildScrollView(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 15.w),
                    child: AdminHomeQuickActionsGrid(
                      children: [
                        for (var i = 0; i < labels.length; i++)
                          Material(
                            key: ValueKey('action-$i'),
                            child: InkWell(
                              onTap: () => calls.add(i),
                              child: Ink(
                                padding: const EdgeInsets.all(8),
                                child: Column(
                                  children: [
                                    SizedBox(
                                      height: 70.w,
                                      child: const Icon(
                                        Icons.apartment_rounded,
                                      ),
                                    ),
                                    Flexible(
                                      child: Center(
                                        child: Text(
                                          labels[i],
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ),
                                    const Icon(Icons.chevron_right_rounded),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        for (var i = 0; i < labels.length; i++) {
          final tile = find.byKey(ValueKey('action-$i'));
          final bounds = tester.getRect(tile);
          final first = tester.getRect(
            find.byKey(ValueKey('action-${i < 4 ? 0 : 4}')),
          );
          expect(bounds.top, closeTo(first.top, 0.01));
          expect(bounds.height, closeTo(first.height, 0.01));
          expect(bounds.right, lessThanOrEqualTo(size.width));
          expectFullText(tester, labels[i]);
        }
        expect(
          tester.getRect(find.byKey(const ValueKey('action-4'))).top,
          greaterThan(
            tester.getRect(find.byKey(const ValueKey('action-0'))).bottom,
          ),
        );
        await tester.tap(find.text(labels[0]));
        expect(calls, [0]);
      });
    }
  }
}
