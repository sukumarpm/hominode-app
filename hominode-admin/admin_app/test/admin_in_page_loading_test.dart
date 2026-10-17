import 'dart:async';

import 'package:admin_app/amenities_management_screen.dart';
import 'package:admin_app/events_announcements_screen.dart';
import 'package:admin_app/desktop/admin_desktop_page_frame.dart';
import 'package:admin_app/services/admin_service.dart';
import 'package:admin_app/services/amenity_service.dart';
import 'package:admin_app/services/event_announcement_service.dart';
import 'package:admin_app/services/subscription_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hominode_entitlements/hominode_entitlements.dart';

class TestAdminService implements AdminService {
  String? adminId = 'admin-1';
  Future<Map<String, dynamic>?> Function() profile = () async => {
    'name': 'Maya Rao',
  };
  @override
  String? getCurrentAdminId() => adminId;
  @override
  String requireCurrentCommunityId() => 'community-1';
  @override
  Future<Map<String, dynamic>?> getAdminProfile() => profile();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class TestSubscriptionService implements SubscriptionService {
  Future<HominodeEntitlement?> Function() load = () async => entitlement(false);
  @override
  Future<HominodeEntitlement?> getEntitlement(String communityId) => load();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

HominodeEntitlement entitlement(bool premium) => HominodeEntitlement(
  communityId: 'community-1',
  planId: premium ? 'plus' : 'essential',
  status: HominodeSubscriptionStatus.active,
  features: {'facilityBooking': premium, 'events': premium},
  limits: const {},
);

class TestAmenityService implements AmenityService {
  Stream<List<AmenityModel>> Function() load = () => Stream.value([]);
  int bookingLoads = 0;
  bool failBookings = false;
  @override
  Stream<List<AmenityModel>> getAmenities() => load();
  @override
  Future<Map<DateTime, List<AmenityBookingModel>>> getBookingsGroupedByDate({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    bookingLoads++;
    if (failBookings) throw StateError('Offline');
    return {};
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class TestEventService implements EventAnnouncementService {
  Stream<List<EventModel>> Function() events = () => Stream.value([]);
  Stream<List<AnnouncementModel>> Function() announcements = () =>
      Stream.value([]);
  int eventLoads = 0;
  @override
  Stream<List<EventModel>> getEvents() {
    eventLoads++;
    return events();
  }

  @override
  Stream<List<AnnouncementModel>> getAnnouncements() => announcements();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget app(Widget child, {bool desktop = false}) => ScreenUtilInit(
  designSize: const Size(390, 844),
  minTextAdapt: true,
  builder: (context, _) => MaterialApp(
    home: desktop
        ? Scaffold(body: AdminDesktopPresentationScope(child: child))
        : child,
  ),
);

Future<void> mobile(
  WidgetTester tester,
  Widget child, {
  bool desktop = false,
}) async {
  tester.view.physicalSize = desktop
      ? const Size(1200, 1000)
      : const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(app(child, desktop: desktop));
}

void main() {
  late TestAdminService admin;
  late TestSubscriptionService subscription;
  late TestAmenityService amenities;
  late TestEventService events;
  setUp(() {
    admin = TestAdminService();
    subscription = TestSubscriptionService();
    amenities = TestAmenityService();
    events = TestEventService();
  });
  AmenitiesManagementScreen amenityScreen() => AmenitiesManagementScreen(
    amenityService: amenities,
    adminService: admin,
    subscriptionService: subscription,
  );
  EventsAnnouncementsScreen eventScreen({
    bool eventsOnly = false,
    bool announcementsOnly = false,
  }) => EventsAnnouncementsScreen(
    service: events,
    adminService: admin,
    subscriptionService: subscription,
    eventsOnly: eventsOnly,
    announcementsOnly: announcementsOnly,
  );

  for (final desktop in [false, true]) {
    testWidgets(
      'Amenities shell appears during entitlement loading, desktop=$desktop',
      (tester) async {
        final pending = Completer<HominodeEntitlement?>();
        subscription.load = () => pending.future;
        await mobile(tester, amenityScreen(), desktop: desktop);
        expect(
          find.text(desktop ? 'Amenities' : 'Amenities Management'),
          findsWidgets,
        );
        expect(find.text('Loading amenities…'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        pending.complete(entitlement(false));
        await tester.pumpAndSettle();
        expect(find.text('No amenities yet'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
    testWidgets(
      'Events shell appears during profile loading, desktop=$desktop',
      (tester) async {
        final pending = Completer<Map<String, dynamic>?>();
        admin.profile = () => pending.future;
        await mobile(tester, eventScreen(), desktop: desktop);
        expect(find.text('Events'), findsWidgets);
        expect(find.text('Loading community communications…'), findsOneWidget);
        pending.complete({'name': 'Maya Rao'});
        await tester.pumpAndSettle();
        expect(find.text('No announcements yet'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'Amenities shows actual supplied amenity and keeps shell during data loading',
    (tester) async {
      final controller = StreamController<List<AmenityModel>>();
      addTearDown(controller.close);
      amenities.load = () => controller.stream;
      await mobile(tester, amenityScreen());
      await tester.pump();
      expect(find.text('Amenities Management'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      controller.add([
        AmenityModel.fromFirestore('gym', {
          'name': 'Community Gym',
          'type': 'gym',
          'isFree': true,
        }),
      ]);
      await tester.pumpAndSettle();
      expect(find.text('Community Gym'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Amenities failure retries the data stream', (tester) async {
    amenities.load = () => Stream.error(StateError('Offline'));
    await mobile(tester, amenityScreen());
    await tester.pumpAndSettle();
    expect(find.text('Unable to load amenities.'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    amenities.load = () => Stream.value([]);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('No amenities yet'), findsOneWidget);
  });

  for (final failure in [false, true]) {
    testWidgets(
      'Amenities booking fails closed, verification failure=$failure',
      (tester) async {
        if (failure) {
          subscription.load = () async => throw StateError('Offline');
        }
        await mobile(tester, amenityScreen());
        await tester.pumpAndSettle();
        expect(find.text('No amenities yet'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsNothing);
        await tester.tap(find.text('Bookings'));
        await tester.pumpAndSettle();
        expect(find.text('Facility booking unavailable'), findsOneWidget);
        expect(amenities.bookingLoads, 0);
        if (failure) {
          await tester.tap(find.text('OK'));
          await tester.pumpAndSettle();
          subscription.load = () async => entitlement(true);
          await tester.tap(find.text('Retry'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Bookings'));
          await tester.pumpAndSettle();
          expect(amenities.bookingLoads, 1);
        }
      },
    );
  }

  testWidgets('Bookings data failure leaves loading and supports retry', (
    tester,
  ) async {
    subscription.load = () async => entitlement(true);
    amenities.failBookings = true;
    await mobile(tester, amenityScreen());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bookings'));
    await tester.pumpAndSettle();
    expect(find.text('Unable to load bookings.'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    amenities.failBookings = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Unable to load bookings.'), findsNothing);
    expect(amenities.bookingLoads, 2);
  });

  testWidgets(
    'Events initialization failure provides retry without infinite spinner',
    (tester) async {
      admin.profile = () async => null;
      await mobile(tester, eventScreen());
      await tester.pumpAndSettle();
      expect(
        find.text('Unable to load community communications.'),
        findsOneWidget,
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);
      admin.profile = () async => {'name': 'Maya Rao'};
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('No announcements yet'), findsOneWidget);
    },
  );

  testWidgets('Events successful stream displays actual event', (tester) async {
    subscription.load = () async => entitlement(true);
    final controller = StreamController<List<EventModel>>();
    addTearDown(controller.close);
    events.events = () => controller.stream;
    await mobile(tester, eventScreen(eventsOnly: true));
    await tester.pump();
    await tester.pump();
    expect(find.text('Events'), findsWidgets);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    controller.add([
      EventModel.fromFirestore('event-1', {'title': 'Community Sports Day'}),
    ]);
    await tester.pumpAndSettle();
    expect(find.text('Community Sports Day'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final failure in [false, true]) {
    testWidgets(
      'Essential announcements stay available and Events fail closed, error=$failure',
      (tester) async {
        if (failure) {
          subscription.load = () async => throw StateError('Offline');
        }
        events.announcements = () => Stream.value([
          AnnouncementModel.fromFirestore('notice', {
            'title': 'Water supply update',
          }),
        ]);
        await mobile(tester, eventScreen());
        await tester.pumpAndSettle();
        expect(find.text('Water supply update'), findsOneWidget);
        expect(events.eventLoads, 0);
        await tester.tap(find.text('Events').last);
        await tester.pumpAndSettle();
        expect(find.text('Events unavailable'), findsOneWidget);
        expect(events.eventLoads, 0);
      },
    );
  }

  testWidgets(
    'Events-only entitlement failure has retry and never reads premium data',
    (tester) async {
      subscription.load = () async => throw StateError('Offline');
      await mobile(tester, eventScreen(eventsOnly: true));
      await tester.pumpAndSettle();
      expect(find.text('Unable to verify Events access.'), findsOneWidget);
      expect(events.eventLoads, 0);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      subscription.load = () async => entitlement(true);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('No events yet'), findsOneWidget);
    },
  );

  for (final announcementsOnly in [false, true]) {
    testWidgets(
      'Communications stream errors support retry, announcements=$announcementsOnly',
      (tester) async {
        subscription.load = () async => entitlement(true);
        events.events = () => Stream.error(StateError('Offline'));
        events.announcements = () => Stream.error(StateError('Offline'));
        await mobile(
          tester,
          eventScreen(
            eventsOnly: !announcementsOnly,
            announcementsOnly: announcementsOnly,
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.text(
            'Unable to load ${announcementsOnly ? 'announcements' : 'events'}.',
          ),
          findsOneWidget,
        );
        expect(find.byType(CircularProgressIndicator), findsNothing);
        events.events = () => Stream.value([]);
        events.announcements = () => Stream.value([]);
        await tester.tap(find.text('Retry'));
        await tester.pumpAndSettle();
        expect(
          find.text('No ${announcementsOnly ? 'announcements' : 'events'} yet'),
          findsOneWidget,
        );
      },
    );
  }

  testWidgets('Unauthenticated Events does not read community data', (
    tester,
  ) async {
    admin.adminId = null;
    await mobile(tester, eventScreen(eventsOnly: true));
    await tester.pumpAndSettle();
    expect(
      find.text('Unable to load community communications.'),
      findsOneWidget,
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(events.eventLoads, 0);
  });

  testWidgets(
    'Events profile timeout provides retry instead of infinite spinner',
    (tester) async {
      final pending = Completer<Map<String, dynamic>?>();
      admin.profile = () => pending.future;
      await mobile(tester, eventScreen());
      await tester.pump(const Duration(seconds: 21));
      await tester.pump();
      expect(
        find.text('Unable to load community communications.'),
        findsOneWidget,
      );
      expect(find.text('Retry'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      pending.complete({'name': 'Maya Rao'});
      await tester.pumpAndSettle();
      expect(events.eventLoads, 0);
    },
  );

  testWidgets('Entitlement timeout provides retry and keeps booking closed', (
    tester,
  ) async {
    final pending = Completer<HominodeEntitlement?>();
    subscription.load = () => pending.future;
    await mobile(tester, amenityScreen());
    await tester.pump(const Duration(seconds: 21));
    await tester.pump();
    expect(
      find.textContaining('Unable to verify facility booking access.'),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsOneWidget);
    pending.complete(entitlement(true));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bookings'));
    await tester.pumpAndSettle();
    expect(find.text('Facility booking unavailable'), findsOneWidget);
  });
}
