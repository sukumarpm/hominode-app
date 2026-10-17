import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resident_app/src/models/family_member.dart';
import 'package:resident_app/src/models/vehicle.dart';
import 'package:resident_app/src/screens/notifications_settings_screen.dart';
import 'package:resident_app/src/widgets/family_card.dart';
import 'package:resident_app/src/widgets/vehicle_card.dart';

void main() {
  testWidgets('family details card remains readable on a narrow screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, _) => MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
            child: Scaffold(
              backgroundColor: const Color(0xFFF4F7FB),
              body: SingleChildScrollView(
                child: FamilyCard(
                  member: FamilyMember(
                    id: 'member-1',
                    name: 'A long family member name',
                    relation: 'Parent',
                    age: 72,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('A long family member name'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('vehicle details card remains readable with enlarged RTL text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, _) => MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Scaffold(
                body: SingleChildScrollView(
                  child: VehicleCard(
                    vehicle: Vehicle(
                      id: 'vehicle-1',
                      name: 'سيارة العائلة الرئيسية',
                      type: 'سيارة دفع رباعي',
                      plateNumber: 'ABC-1234',
                      color: 'Silver',
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('سيارة العائلة الرئيسية'), findsOneWidget);
    expect(find.text('سيارة دفع رباعي • ABC-1234'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'notification preferences remain readable across narrow and RTL layouts',
    (tester) async {
      for (final width in [320.0, 390.0]) {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1;
        await tester.pumpWidget(
          ScreenUtilInit(
            designSize: const Size(390, 844),
            builder: (_, _) => MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(
                  size: Size(width, 800),
                  textScaler: const TextScaler.linear(1.6),
                ),
                child: const Directionality(
                  textDirection: TextDirection.rtl,
                  child: NotificationsSettingsScreen(),
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();
        expect(find.text('Notification Settings'), findsOneWidget);
        expect(find.text('Push Notifications'), findsOneWidget);
        expect(find.text('Email Notifications'), findsOneWidget);
        final layoutError = tester.takeException();
        expect(layoutError, isNull, reason: 'layout width: $width');
      }
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    },
  );
}
