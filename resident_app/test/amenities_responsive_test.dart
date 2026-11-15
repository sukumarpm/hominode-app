import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resident_app/src/models/booking.dart';
import 'package:resident_app/src/screens/amenities_booking_screen.dart';
import 'package:resident_app/src/services/booking_firestore_service.dart';
import 'package:resident_app/src/widgets/facility_information.dart';

import 'localization_test_app.dart';

final _amenities = [
  AmenityModel(
    id: 'pool',
    name: 'Swimming Pool',
    type: 'Recreation',
    buildingName: 'Clubhouse',
    description:
        'A shared pool with separate lanes for swimming and family recreation. Please follow the posted safety guidelines.',
    isFree: false,
    hasExplicitPricingMode: true,
    pricePerDay: 250,
    timeSlots: const ['6:00 AM - 9:00 AM', '4:00 PM - 7:00 PM'],
    isAvailable: true,
    maxCapacity: 25,
    bookingDurations: const ['1 hour', '2 hours'],
    hasSubscriptionPackages: true,
    subscriptionPackages: const {'Monthly': 2000},
  ),
  AmenityModel(
    id: 'gym',
    name: 'Fitness Centre',
    type: 'Fitness',
    isFree: true,
    hasExplicitPricingMode: true,
    timeSlots: const [],
    isAvailable: true,
  ),
  AmenityModel(
    id: 'hall',
    name: 'Community Events and Celebration Hall',
    type: 'Community',
    buildingName: 'North Residential Tower',
    description: 'A space for community events and celebrations.',
    isFree: false,
    timeSlots: const ['9:00 AM - 9:00 PM'],
    isAvailable: false,
    bookingDurations: const ['Full day'],
  ),
];

class _Bookings extends Fake implements BookingFirestoreService {
  @override
  Stream<List<AmenityModel>> streamAmenitiesRealtime() =>
      Stream.value(_amenities);

  @override
  Stream<List<BookingModel>> streamMyBookingsRealtime() => Stream.value([]);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await initializeTestLocalization();
    // Exercise mobile typography rather than the square Ahem test glyphs.
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
  setUp(resetTestLocalizationPreferences);

  Future<void> mount(WidgetTester tester, Size size, {double scale = 1}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      withEnglishLocalization(
        (context) => ScreenUtilInit(
          designSize: const Size(390, 844),
          minTextAdapt: true,
          splitScreenMode: true,
          builder: (_, _) => localizedMaterialApp(
            context,
            home: MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: AmenitiesBookingScreen(bookingService: _Bookings()),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder card(int index) => find.byType(AmenityCard).at(index);
  Finder action(int index) => find.descendant(
    of: card(index),
    matching: find.text('View details & book'),
  );

  for (final size in [
    const Size(393, 852),
    const Size(600, 960),
    const Size(800, 1280),
    const Size(1280, 800),
  ]) {
    for (final scale in [1.0, 1.5]) {
      testWidgets(
        'amenities at ${size.width}x${size.height}, text scale $scale',
        (tester) async {
          await mount(tester, size, scale: scale);
          expect(tester.takeException(), isNull);
          expect(find.byType(AmenityCard), findsNWidgets(3));
          final rectangles = [
            for (var i = 0; i < 3; i++) tester.getRect(card(i)),
          ];
          final tablet = size.width >= 600;
          for (var i = 0; i < 3; i++) {
            expect(rectangles[i].left, greaterThanOrEqualTo(0));
            expect(rectangles[i].right, lessThanOrEqualTo(size.width));
            expect(rectangles[i].width, closeTo(rectangles.first.width, 0.01));
            expect(tester.widget<AmenityCard>(card(i)).tabletLayout, tablet);
            expect(action(i), findsOneWidget);
            final actionBounds = tester.getRect(action(i));
            expect(actionBounds.left, greaterThanOrEqualTo(rectangles[i].left));
            expect(actionBounds.right, lessThanOrEqualTo(rectangles[i].right));
            expect(
              actionBounds.bottom,
              lessThanOrEqualTo(rectangles[i].bottom),
            );
            expect(tester.widget<AmenityCard>(card(i)).onTap, isNotNull);
          }
          if (tablet) {
            expect(rectangles[0].top, closeTo(rectangles[1].top, 0.01));
            expect(rectangles[0].height, closeTo(rectangles[1].height, 0.01));
            expect(rectangles[1].left - rectangles[0].right, closeTo(20, 0.01));
            expect(rectangles[2].top - rectangles[0].bottom, closeTo(20, 0.01));
            expect(rectangles[2].left, rectangles[0].left);
            expect(
              tester.getRect(action(0)).bottom,
              closeTo(tester.getRect(action(1)).bottom, 0.01),
            );
            expect(
              tester.widget<Text>(find.text('Swimming Pool')).style!.fontSize,
              18,
            );
            final image = find.descendant(
              of: card(0),
              matching: find.byType(FacilityImage),
            );
            final imageSize = tester.getSize(image);
            expect(imageSize.width / imageSize.height, closeTo(2, 0.01));
            expect(
              rectangles[0].width,
              closeTo(((size.width.clamp(0, 1120) - 48) - 20) / 2, 0.01),
            );
            // The normal-sized title fits on one line in both tablet columns.
            if (scale == 1) {
              final title = tester.renderObject<RenderParagraph>(
                find.text('Swimming Pool'),
              );
              expect(title.size.height, lessThan(30));
            }
          } else {
            expect(rectangles[0].left, closeTo(rectangles[1].left, 0.01));
            expect(rectangles[1].top, greaterThan(rectangles[0].bottom));
            expect(rectangles[2].top, greaterThan(rectangles[1].bottom));
            expect(
              rectangles.first.width,
              closeTo(size.width - 40 * size.width / 390, 0.01),
            );
          }
          // The final, odd-numbered card and its action remain scroll-reachable.
          await tester.ensureVisible(action(2));
          await tester.pumpAndSettle();
          expect(
            tester.getRect(action(2)).bottom,
            lessThanOrEqualTo(size.height),
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'resizing across the tablet breakpoint preserves all facilities',
    (tester) async {
      await mount(tester, const Size(800, 1280));
      expect(tester.getRect(card(0)).top, tester.getRect(card(1)).top);
      tester.view.physicalSize = const Size(599, 960);
      await tester.pumpAndSettle();
      expect(tester.widget<AmenityCard>(card(0)).tabletLayout, isFalse);
      expect(
        tester.getRect(card(1)).top,
        greaterThan(tester.getRect(card(0)).bottom),
      );
      tester.view.physicalSize = const Size(600, 960);
      await tester.pumpAndSettle();
      expect(tester.widget<AmenityCard>(card(0)).tabletLayout, isTrue);
      expect(tester.getRect(card(0)).top, tester.getRect(card(1)).top);
      expect(find.byType(AmenityCard), findsNWidgets(3));
      expect(tester.takeException(), isNull);
    },
  );
}
