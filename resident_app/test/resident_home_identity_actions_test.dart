import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resident_app/src/screens/emergency_sos_screen.dart';
import 'package:resident_app/src/widgets/resident_home_identity_actions.dart';

import 'localization_test_app.dart';
import '../../packages/hominode_sos/test/sos_test_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(initializeTestLocalization);

  testWidgets('Home logo uses the approved asset without distortion', (
    tester,
  ) async {
    await tester.pumpWidget(
      withEnglishLocalization(
        (context) => localizedMaterialApp(
          context,
          home: const Scaffold(body: ResidentHomeLogo()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final logo = tester.widget<Image>(
      find.byKey(const ValueKey('resident-home-logo')),
    );
    expect((logo.image as AssetImage).assetName, 'lib/assets/Resident_New.png');
    expect(logo.fit, BoxFit.contain);
    expect(logo.width, 50);
    expect(logo.height, 50);
    expect(tester.takeException(), isNull);
  });

  for (final layout in [
    (width: 320.0, textScale: 1.0, rtl: false),
    (width: 390.0, textScale: 1.7, rtl: false),
    (width: 320.0, textScale: 1.7, rtl: true),
  ]) {
    testWidgets('SOS opens the existing interface without sending an alert '
        '(${layout.width}px, scale ${layout.textScale}, rtl ${layout.rtl})', (
      tester,
    ) async {
      tester.view.physicalSize = Size(layout.width, 760);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final client = TestSosClient();
      addTearDown(client.dispose);

      var locationCaptures = 0;
      await tester.pumpWidget(
        withResidentLocalization(
          (context) => MaterialApp(
            locale: context.locale,
            supportedLocales: context.supportedLocales,
            localizationsDelegates: context.localizationDelegates,
            // Apply the test conditions above the Navigator so they also
            // reach the emergency page after navigation.
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(layout.textScale)),
              child: Directionality(
                textDirection: layout.rtl
                    ? ui.TextDirection.rtl
                    : ui.TextDirection.ltr,
                child: child!,
              ),
            ),
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: layout.width - 32,
                  child: ResidentHomeEmergencySosButton(
                    screenBuilder: (_) => EmergencySosScreen(
                      client: client,
                      captureLocation: () async {
                        locationCaptures++;
                        return null;
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
          startLocale: Locale(layout.rtl ? 'ar' : 'en'),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(layout.rtl ? 'نداء الطوارئ SOS' : 'Emergency SOS'),
        findsOneWidget,
      );
      expect(
        tester
            .getSize(find.byKey(const ValueKey('resident-home-emergency-sos')))
            .height,
        greaterThanOrEqualTo(48),
      );
      final homeContext = tester.element(
        find.byKey(const ValueKey('resident-home-emergency-sos')),
      );
      expect(
        Localizations.localeOf(homeContext),
        Locale(layout.rtl ? 'ar' : 'en'),
      );
      expect(MediaQuery.sizeOf(homeContext).width, layout.width);
      expect(MediaQuery.textScalerOf(homeContext).scale(1), layout.textScale);
      expect(
        Directionality.of(homeContext),
        layout.rtl ? ui.TextDirection.rtl : ui.TextDirection.ltr,
      );
      expect(client.triggers, 0);
      expect(tester.takeException(), isNull);
      await tester.tap(
        find.byKey(const ValueKey('resident-home-emergency-sos')),
      );
      await tester.pumpAndSettle();

      expect(find.byType(EmergencySosScreen), findsOneWidget);
      final emergencyContext = tester.element(find.byType(EmergencySosScreen));
      expect(MediaQuery.sizeOf(emergencyContext).width, layout.width);
      expect(
        MediaQuery.textScalerOf(emergencyContext).scale(1),
        layout.textScale,
      );
      expect(
        Directionality.of(emergencyContext),
        layout.rtl ? ui.TextDirection.rtl : ui.TextDirection.ltr,
      );
      expect(client.contextCalls, greaterThan(0));
      expect(client.triggers, 0);
      expect(client.actions, 0);
      expect(client.requestIds, isEmpty);
      expect(locationCaptures, 0);
      expect(tester.takeException(), isNull);

      Navigator.of(emergencyContext).pop();
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('resident-home-emergency-sos')),
        findsOneWidget,
      );
      expect(client.triggers, 0);
    });
  }
}
