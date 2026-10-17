import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resident_app/src/widgets/resident_home_summary_navigation.dart';
import 'package:resident_app/src/widgets/resident_home_summary_view_all.dart';
import 'package:resident_app/src/widgets/resident_navigation_back.dart';

void main() {
  for (final scenario in [
    (label: 'Upcoming Visitor', destination: 'Visitor Management'),
    (label: 'Due Payment', destination: 'Billing and Payments'),
  ]) {
    for (final hasSummaryData in [false, true]) {
      testWidgets('${scenario.label} View all navigates with '
          '${hasSummaryData ? 'data' : 'an empty summary'}', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  Text(hasSummaryData ? 'Summary item' : 'Empty summary'),
                  ResidentHomeSummaryViewAll(
                    label: 'View all',
                    onPressed: () {
                      final context = tester.element(
                        find.byType(ResidentHomeSummaryViewAll),
                      );
                      Widget destination(BuildContext _) => Scaffold(
                        body: Center(child: Text(scenario.destination)),
                      );
                      if (scenario.label == 'Upcoming Visitor') {
                        openResidentHomeVisitors(
                          context,
                          destinationBuilder: destination,
                        );
                      } else {
                        openResidentHomeBilling(
                          context,
                          destinationBuilder: destination,
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        );

        await tester.tap(find.text('View all'));
        await tester.pumpAndSettle();

        expect(find.text(scenario.destination), findsOneWidget);
      });
    }
  }

  testWidgets('Due Payment keeps the main Payments tab navigation', (
    tester,
  ) async {
    var selectedIndex = -1;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ResidentHomeSummaryViewAll(
              label: 'View all',
              onPressed: () => openResidentHomeBilling(
                context,
                onTabChange: (index) => selectedIndex = index,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('View all'));
    expect(selectedIndex, 3);
    expect(find.text('Billing and Payments'), findsNothing);
  });

  testWidgets('Home Billing summary route returns to Home with Back', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => openResidentHomeBillingRoute(
                context,
                destinationBuilder: (_) => Scaffold(
                  body: Column(
                    children: [
                      const Text('Maintenance & Billing'),
                      const ResidentNavigationBackButton(),
                    ],
                  ),
                ),
              ),
              child: const Text('Due Payment View all'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Due Payment View all'));
    await tester.pumpAndSettle();
    expect(find.text('Maintenance & Billing'), findsOneWidget);
    await tester.tap(find.byType(ResidentNavigationBackButton));
    await tester.pumpAndSettle();
    expect(find.text('Due Payment View all'), findsOneWidget);
  });

  testWidgets('root Back action falls back to authenticated Home route', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        routes: {'/home': (_) => const Scaffold(body: Text('Home route'))},
        home: const Scaffold(body: ResidentNavigationBackButton()),
      ),
    );

    await tester.tap(find.byType(ResidentNavigationBackButton));
    await tester.pumpAndSettle();
    expect(find.text('Home route'), findsOneWidget);
  });

  testWidgets('system Back pops a pushed destination to Home', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.push<void>(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const ResidentNavigationBackHandler(
                    child: Scaffold(body: Text('Pushed destination')),
                  ),
                ),
              ),
              child: const Text('Open destination'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open destination'));
    await tester.pumpAndSettle();
    expect(find.text('Pushed destination'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Open destination'), findsOneWidget);
  });

  testWidgets('system Back uses Home fallback when Billing is root', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        routes: {'/home': (_) => const Scaffold(body: Text('Home route'))},
        home: const ResidentNavigationBackHandler(
          child: Scaffold(body: Text('Root Billing')),
        ),
      ),
    );

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Home route'), findsOneWidget);
  });
}
