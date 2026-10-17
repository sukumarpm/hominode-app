import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resident_app/src/widgets/resident_home_quick_actions.dart';

const items = [
  ResidentHomeAction(
    icon: Icons.people,
    label: 'Visitors',
    iconColor: Colors.blue,
    backgroundColor: Colors.white,
    onTap: _noop,
  ),
  ResidentHomeAction(
    icon: Icons.campaign,
    label: 'Announcements',
    iconColor: Colors.blue,
    backgroundColor: Colors.white,
    onTap: _noop,
  ),
  ResidentHomeAction(
    icon: Icons.credit_card,
    label: 'Payments',
    iconColor: Colors.blue,
    backgroundColor: Colors.white,
    onTap: _noop,
  ),
  ResidentHomeAction(
    icon: Icons.shield,
    label: 'Security',
    iconColor: Colors.blue,
    backgroundColor: Colors.white,
    onTap: _noop,
  ),
];

void main() {
  testWidgets('quick actions adapt to narrow width and larger text', (
    tester,
  ) async {
    _setViewport(tester, 320);
    await tester.pumpWidget(_host(width: 320, textScale: 1.6));
    await tester.pumpAndSettle();

    final narrowFirst = tester.getTopLeft(find.text('Visitors'));
    final narrowSecond = tester.getTopLeft(find.text('Announcements'));
    final narrowThird = tester.getTopLeft(find.text('Payments'));
    expect(narrowSecond.dy, greaterThan(narrowFirst.dy));
    expect(narrowThird.dy, greaterThan(narrowFirst.dy));
    expect(narrowThird.dy, greaterThan(narrowSecond.dy));
    expect(find.text('Announcements'), findsOneWidget);
    expect(tester.takeException(), isNull);

    _setViewport(tester, 390);
    await tester.pumpWidget(_host(width: 390, textScale: 1));
    await tester.pumpAndSettle();
    final wideFirst = tester.getTopLeft(find.text('Visitors'));
    final wideSecond = tester.getTopLeft(find.text('Announcements'));
    final wideThird = tester.getTopLeft(find.text('Payments'));
    final wideFourth = tester.getTopLeft(find.text('Security'));
    expect(wideFirst.dy, wideSecond.dy);
    expect(wideThird.dy, greaterThan(wideFirst.dy));
    expect(wideThird.dy, wideFourth.dy);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Announcements remains one intact word at iPhone width', (
    tester,
  ) async {
    _setViewport(tester, 390);
    await tester.pumpWidget(_host(width: 390, textScale: 1));
    await tester.pumpAndSettle();

    final label = find.text('Announcements');
    expect(label, findsOneWidget);
    _expectSingleLine(tester, label);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Announcements and Arabic labels fit with enlarged text in RTL', (
    tester,
  ) async {
    _setViewport(tester, 375);
    await tester.pumpWidget(_host(width: 375, textScale: 1.6));
    await tester.pumpAndSettle();

    final english = find.text('Announcements');
    expect(english, findsOneWidget);
    _expectSingleLine(tester, english);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      _host(
        width: 375,
        textScale: 1.6,
        direction: TextDirection.rtl,
        actions: [
          ResidentHomeAction(
            icon: Icons.campaign,
            label: 'الإعلانات',
            iconColor: Colors.blue,
            backgroundColor: Colors.white,
            onTap: _noop,
          ),
          ...items.where((item) => item.label != 'Announcements'),
        ],
      ),
    );
    await tester.pumpAndSettle();

    final arabic = find.text('الإعلانات');
    expect(arabic, findsOneWidget);
    _expectSingleLine(tester, arabic);
    expect(tester.takeException(), isNull);
  });

  testWidgets('long localized quick action wraps in RTL at large text scale', (
    tester,
  ) async {
    const label = 'طلبات الخدمات والصيانة المجتمعية';
    _setViewport(tester, 320);
    await tester.pumpWidget(
      _host(
        width: 320,
        textScale: 1.8,
        direction: TextDirection.rtl,
        actions: [
          ResidentHomeAction(
            icon: Icons.build,
            label: label,
            iconColor: Colors.blue,
            backgroundColor: Colors.white,
            onTap: _noop,
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    final actionText = tester.widget<Text>(find.text(label));
    expect(actionText.maxLines, isNull);
    expect(actionText.overflow, isNull);
    expect(tester.takeException(), isNull);
  });
}

Widget _host({
  required double width,
  required double textScale,
  List<ResidentHomeAction> actions = items,
  TextDirection direction = TextDirection.ltr,
}) => ScreenUtilInit(
  designSize: const Size(390, 844),
  builder: (_, _) => MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: MediaQuery(
          data: MediaQueryData(
            size: Size(width, 720),
            textScaler: TextScaler.linear(textScale),
          ),
          child: Directionality(
            textDirection: direction,
            child: Center(
              child: SizedBox(
                width: width,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: ResidentHomeQuickActions(
                    items: actions,
                    title: direction == TextDirection.rtl
                        ? 'إجراءات المجتمع السريعة'
                        : 'Quick access',
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  ),
);

void _noop() {}

void _setViewport(WidgetTester tester, double width) {
  tester.view.physicalSize = Size(width, 720);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void _expectSingleLine(WidgetTester tester, Finder finder) {
  final text = tester.widget<Text>(finder);
  final renderParagraph = tester.renderObject<RenderParagraph>(finder);
  final context = tester.element(finder);
  final painter = TextPainter(
    text: TextSpan(text: text.data, style: text.style),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
  )..layout(maxWidth: renderParagraph.size.width);
  expect(painter.computeLineMetrics(), hasLength(1));
}
