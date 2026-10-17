import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resident_app/src/screens/amenities_booking_screen.dart';
import 'package:resident_app/src/services/booking_firestore_service.dart';

import 'localization_test_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initializeTestLocalization);

  testWidgets('Tamil facility card localizes availability, fee and action', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final amenity = AmenityModel(
      id: 'facility_fixture',
      communityId: 'community_fixture',
      name: 'Clubhouse',
      type: 'Community',
      isFree: true,
      timeSlots: const [],
      isAvailable: true,
      hasExplicitPricingMode: true,
      pricingMode: 'free',
      pricePerDay: 0,
    );

    await tester.pumpWidget(
      withResidentLocalization(
        (context) => ScreenUtilInit(
          designSize: const Size(390, 844),
          minTextAdapt: true,
          builder: (_, _) => localizedMaterialApp(
            context,
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(320, 760),
                textScaler: TextScaler.linear(1.6),
              ),
              child: Scaffold(
                body: SingleChildScrollView(
                  child: AmenityCard(amenity: amenity),
                ),
              ),
            ),
          ),
        ),
        startLocale: const Locale('ta'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Clubhouse'), findsOneWidget);
    expect(find.text('கிடைக்கிறது'), findsOneWidget);
    // The same translated value appears in both the price line and free chip.
    expect(find.text('இலவசம்'), findsNWidgets(2));
    expect(find.text('நேர இடங்கள் இல்லை'), findsOneWidget);
    expect(
      find.text('விவரங்களைப் பார்த்து முன்பதிவு செய்யவும்'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
