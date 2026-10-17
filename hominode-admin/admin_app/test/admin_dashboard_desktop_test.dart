import 'package:admin_app/admin_dashboard_desktop_content.dart';
import 'package:admin_app/desktop/admin_desktop_design.dart';
import 'package:admin_app/navigation/admin_module_destinations.dart';
import 'package:admin_app/services/dashboard_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('desktop registry uses the desktop dashboard presentation', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            final dashboard = adminModuleDestinations.firstWhere(
              (destination) => destination.id == AdminModuleId.dashboard,
            );
            expect(
              dashboard.builder(context),
              isA<AdminDashboardDesktopContent>(),
            );
            return const SizedBox();
          },
        ),
      ),
    );
  });

  testWidgets('desktop dashboard renders real supplied statistics densely', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1126, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final stats = DashboardStats(
      totalResidents: 248,
      totalFlats: 164,
      pendingVisitors: 7,
      pendingComplaints: 3,
      monthlyCollection: 125000,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AdminDashboardDesktopContent(
          statsStream: Stream.value(stats),
          communityName: 'Hominode Heights',
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('admin-desktop-dashboard')), findsOneWidget);
    expect(find.text('Admin Dashboard'), findsOneWidget);
    expect(find.text('Hominode Heights'), findsOneWidget);
    expect(find.text('248'), findsWidgets);
    expect(find.text('164'), findsWidgets);
    expect(find.text('7'), findsWidgets);
    expect(find.text('3'), findsWidgets);
    expect(find.text('₹1.3L'), findsWidgets);
    expect(find.byIcon(Icons.menu_rounded), findsNothing);
    expect(find.text('Welcome back,'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final width in <double>[800, 1126, 1200, 1680]) {
    testWidgets('desktop dashboard lays out at ${width.toInt()}px workspace', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: AdminDashboardDesktopContent(
            statsStream: Stream.value(
              DashboardStats(
                totalResidents: 248,
                totalFlats: 164,
                pendingVisitors: 7,
                pendingComplaints: 3,
                monthlyCollection: 125000,
              ),
            ),
            communityName: 'Hominode Heights',
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.text('Quick Actions'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();

      expect(find.text('Quick Actions'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('dashboard wraps long community names at enlarged text scale', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const community = 'Green Wave Residences with a long community name';
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.8)),
          child: child!,
        ),
        home: AdminDashboardDesktopContent(
          statsStream: Stream.value(
            DashboardStats(
              totalResidents: 248,
              totalFlats: 164,
              pendingVisitors: 7,
              pendingComplaints: 3,
              monthlyCollection: 125000,
            ),
          ),
          communityName: community,
        ),
      ),
    );
    await tester.pump();

    final communityText = tester.widget<Text>(find.text(community));
    expect(communityText.maxLines, isNull);
    expect(communityText.softWrap, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('admin quick action keeps its full label on a narrow card', (
    tester,
  ) async {
    const label = 'Resident Registration and Apartment Management';
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.8)),
          child: child!,
        ),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 148,
              child: AdminDesktopActionTile(
                label: label,
                icon: Icons.people_outline,
                onTap: () {},
              ),
            ),
          ),
        ),
      ),
    );

    final actionLabel = tester.widget<Text>(find.text(label));
    expect(actionLabel.maxLines, isNull);
    expect(actionLabel.softWrap, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'desktop dashboard stays readable at narrow width and large text',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.8)),
            child: child!,
          ),
          home: AdminDashboardDesktopContent(
            statsStream: Stream.value(
              DashboardStats(
                totalResidents: 248,
                totalFlats: 164,
                pendingVisitors: 7,
                pendingComplaints: 3,
                monthlyCollection: 125000,
              ),
            ),
            communityName: 'Green Wave Residences with a long community name',
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('admin-desktop-dashboard')), findsOneWidget);
    },
  );
}
