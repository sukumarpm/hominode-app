import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resident_app/src/widgets/resident_floating_bottom_navigation.dart';

const _items = [
  ResidentNavigationItem(
    icon: Icons.home_outlined,
    activeIcon: Icons.home,
    label: 'Home',
  ),
  ResidentNavigationItem(
    icon: Icons.event_outlined,
    activeIcon: Icons.event,
    label: 'Facilities',
  ),
  ResidentNavigationItem(
    icon: Icons.groups_outlined,
    activeIcon: Icons.groups,
    label: 'Community',
  ),
  ResidentNavigationItem(
    icon: Icons.credit_card_outlined,
    activeIcon: Icons.credit_card,
    label: 'Payments',
  ),
  ResidentNavigationItem(
    icon: Icons.apps_outlined,
    activeIcon: Icons.apps,
    label: 'More',
  ),
];

void main() {
  testWidgets('tab changes stay compact while switching all destinations', (
    tester,
  ) async {
    _setViewport(tester, 390, 844);
    var selected = -1;
    await tester.pumpWidget(
      _host(width: 390, textScale: 1, onSelected: (index) => selected = index),
    );
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Facilities'), findsOneWidget);
    expect(find.text('Community'), findsOneWidget);
    expect(find.text('Payments'), findsOneWidget);
    expect(find.text('More'), findsOneWidget);
    final barFinder = find.byKey(
      const ValueKey('resident-floating-navigation'),
    );
    final barRect = tester.getRect(barFinder);
    expect(barRect.height, lessThan(100));

    for (final item in _items.asMap().entries) {
      await tester.tap(
        find.byKey(ValueKey('resident-nav-button-${item.value.label}')),
      );
      await tester.pumpAndSettle();
      expect(selected, item.key);
      if (item.key < 4) {
        expect(find.text('${item.value.label} page'), findsOneWidget);
      }

      final buttonRect = tester.getRect(
        find.byKey(ValueKey('resident-nav-button-${item.value.label}')),
      );
      expect(buttonRect.height, lessThan(80));
      expect(barRect.contains(buttonRect.center), isTrue);
      final activeLabel = _items[item.key].label;
      final activeCapsule = find.byKey(
        ValueKey('resident-nav-active-$activeLabel'),
      );
      final capsuleRect = tester.getRect(activeCapsule);
      final activeButtonRect = tester.getRect(
        find.byKey(ValueKey('resident-nav-button-$activeLabel')),
      );
      expect(capsuleRect.height, lessThanOrEqualTo(36));
      expect(activeButtonRect.contains(capsuleRect.center), isTrue);
      expect(barRect.contains(capsuleRect.center), isTrue);
      final activeText = tester.widget<Text>(find.text(activeLabel));
      expect(activeText.style?.color, const Color(0xFF172B4D));
      for (final other in _items.asMap().entries.where(
        (entry) => entry.key != item.key,
      )) {
        final inactiveText = tester.widget<Text>(find.text(other.value.label));
        expect(inactiveText.style?.color, const Color(0xFF52627A));
      }
      expect(tester.takeException(), isNull);
    }

    // Explicitly cover the Home -> Facilities -> Home navigation loop.
    await tester.tap(find.byKey(const ValueKey('resident-nav-button-Home')));
    await tester.pumpAndSettle();
    expect(find.text('Home page'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('resident-nav-button-Facilities')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Facilities page'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('resident-nav-button-Home')));
    await tester.pumpAndSettle();
    expect(selected, 0);
    expect(find.text('Home page'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('navigation wraps at narrow width with enlarged text and RTL', (
    tester,
  ) async {
    _setViewport(tester, 320, 720);
    await tester.pumpWidget(
      _host(
        width: 320,
        textScale: 1.7,
        direction: TextDirection.rtl,
        items: const [
          ResidentNavigationItem(
            icon: Icons.home_outlined,
            activeIcon: Icons.home,
            label: 'الرئيسية',
          ),
          ResidentNavigationItem(
            icon: Icons.event_outlined,
            activeIcon: Icons.event,
            label: 'المرافق والحجوزات',
          ),
          ResidentNavigationItem(
            icon: Icons.groups_outlined,
            activeIcon: Icons.groups,
            label: 'المجتمع',
          ),
          ResidentNavigationItem(
            icon: Icons.credit_card_outlined,
            activeIcon: Icons.credit_card,
            label: 'المدفوعات',
          ),
          ResidentNavigationItem(
            icon: Icons.apps_outlined,
            activeIcon: Icons.apps,
            label: 'المزيد',
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('المرافق والحجوزات'), findsOneWidget);
    expect(
      tester
          .getRect(find.byKey(const ValueKey('resident-floating-navigation')))
          .height,
      lessThan(150),
    );
    expect(tester.takeException(), isNull);
  });
}

Widget _host({
  required double width,
  required double textScale,
  ValueChanged<int>? onSelected,
  TextDirection direction = TextDirection.ltr,
  List<ResidentNavigationItem> items = _items,
}) {
  var selectedIndex = 0;
  return ScreenUtilInit(
    designSize: const Size(390, 844),
    builder: (_, _) => MaterialApp(
      home: Directionality(
        textDirection: direction,
        child: MediaQuery(
          data: MediaQueryData(
            size: Size(width, 700),
            textScaler: TextScaler.linear(textScale),
          ),
          child: StatefulBuilder(
            builder: (context, setState) => Scaffold(
              body: IndexedStack(
                index: selectedIndex.clamp(0, 3),
                children: const [
                  Center(child: Text('Home page')),
                  Center(child: Text('Facilities page')),
                  Center(child: Text('Community page')),
                  Center(child: Text('Payments page')),
                ],
              ),
              bottomNavigationBar: ResidentFloatingBottomNavigation(
                key: const ValueKey('resident-floating-navigation'),
                items: items,
                selectedIndex: selectedIndex,
                onSelected: (index) {
                  setState(() => selectedIndex = index);
                  onSelected?.call(index);
                },
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

void _setViewport(WidgetTester tester, double width, double height) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}
