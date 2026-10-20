import 'dart:ui' as ui;
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resident_app/events_announcements_screen.dart';
import 'package:resident_app/src/models/announcement_model.dart';
import 'package:resident_app/src/models/event_model.dart';
import 'package:resident_app/src/services/announcements_events_service.dart';
import 'package:resident_app/src/widgets/resident_visitor_page_background.dart';

import 'localization_test_app.dart';
import 'package:resident_app/src/screens/notifications_screen.dart';
import 'package:resident_app/src/services/notice_firestore_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class _FakeAnnouncementsEventsService implements AnnouncementsEventsService {
  _FakeAnnouncementsEventsService({
    List<AnnouncementModel> announcements = const [],
    List<EventModel> events = const [],
    this.allowed = false,
  }) : _announcements = announcements,
       _events = events;

  final List<AnnouncementModel> _announcements;
  final List<EventModel> _events;
  final bool allowed;
  int entitlementChecks = 0;
  Future<EventModel?> Function(String)? detailLoader;

  @override
  Future<EventModel?> getEvent(String id) async => detailLoader != null
      ? detailLoader!(id)
      : _events.where((event) => event.id == id).firstOrNull;

  @override
  Future<String?> currentCommunityId() async => 'community-test';

  @override
  Future<bool> eventsAllowed(String communityId) async {
    entitlementChecks++;
    return allowed;
  }

  @override
  Stream<List<AnnouncementModel>> streamAnnouncements() =>
      Stream.value(_announcements);

  @override
  Stream<List<EventModel>> streamEvents() => Stream.value(_events);

  @override
  Future<int> getVisibleEventsCount(String communityId) async => _events.length;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initializeTestLocalization);

  Future<void> pumpScreen(
    WidgetTester tester, {
    required Widget screen,
    required double width,
    required double textScale,
    bool rtl = false,
    Locale locale = const Locale('en'),
  }) async {
    tester.view.physicalSize = Size(width, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      withResidentLocalization(
        (context) => ScreenUtilInit(
          designSize: const Size(390, 844),
          minTextAdapt: true,
          builder: (_, _) => localizedMaterialApp(
            context,
            home: MediaQuery(
              data: MediaQueryData(
                size: Size(width, 820),
                textScaler: TextScaler.linear(textScale),
              ),
              child: Directionality(
                textDirection: rtl
                    ? ui.TextDirection.rtl
                    : ui.TextDirection.ltr,
                child: screen,
              ),
            ),
          ),
        ),
        startLocale: locale,
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Basic Announcements use the shared background and glass card', (
    tester,
  ) async {
    final service = _FakeAnnouncementsEventsService(
      announcements: [
        AnnouncementModel(
          id: 'announcement-1',
          title: 'Community water maintenance',
          description:
              'Water service will pause briefly while the community system is inspected.',
          category: 'Community',
          priority: 'medium',
          status: 'active',
          createdAt: DateTime(2026, 10, 14),
          updatedAt: DateTime(2026, 10, 14),
        ),
      ],
    );
    await pumpScreen(
      tester,
      screen: EventsAnnouncementsScreen(
        announcementsOnly: true,
        service: service,
      ),
      width: 320,
      textScale: 1.6,
      rtl: true,
    );

    expect(find.text('Announcements'), findsOneWidget);
    expect(find.text('Community water maintenance'), findsOneWidget);
    expect(find.byType(ResidentVisitorPageBackground), findsOneWidget);
    expect(service.entitlementChecks, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Tamil announcements empty state uses localized UI labels', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      screen: EventsAnnouncementsScreen(
        announcementsOnly: true,
        service: _FakeAnnouncementsEventsService(),
      ),
      width: 320,
      textScale: 1.5,
      locale: const Locale('ta'),
    );

    expect(find.text('அறிவிப்புகள்'), findsOneWidget);
    expect(find.text('அறிவிப்புகள் இல்லை'), findsOneWidget);
    expect(
      find.text('புதுப்பிப்புகளுக்கு பின்னர் பார்க்கவும்'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('event presentation retains uploaded community image', (
    tester,
  ) async {
    const imageUrl = 'https://community.example/event-photo.jpg';
    final service = _FakeAnnouncementsEventsService(
      allowed: true,
      events: [
        EventModel(
          id: 'event-1',
          title: 'Community gathering',
          description:
              'Join neighbors for an evening together at the central garden.',
          category: 'Community',
          priority: 'low',
          status: 'upcoming',
          eventDate: DateTime(2026, 11, 3, 18),
          location: 'Central garden',
          imageUrls: const [imageUrl],
          totalCapacity: 80,
          createdAt: DateTime(2026, 10, 14),
          updatedAt: DateTime(2026, 10, 14),
        ),
      ],
    );
    await pumpScreen(
      tester,
      screen: EventsAnnouncementsScreen(eventsOnly: true, service: service),
      width: 320,
      textScale: 1.6,
      rtl: true,
    );

    expect(find.text('Community gathering'), findsOneWidget);
    final uploadedImage = tester.widget<Image>(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is NetworkImage &&
            (widget.image as NetworkImage).url == imageUrl,
      ),
    );
    expect(uploadedImage.fit, BoxFit.cover);
    expect(find.byType(ResidentVisitorPageBackground), findsOneWidget);
    expect(service.entitlementChecks, 0);
    await tester.tap(find.text('Community gathering'));
    await tester.pumpAndSettle();
    expect(
      find.byType(EventsAnnouncementsScreen, skipOffstage: false),
      findsNWidgets(2),
    );
    expect(find.text('Community gathering'), findsOneWidget);
    expect(find.textContaining('Central garden'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'notification deep link shows loading and a retryable missing event',
    (tester) async {
      final request = Completer<EventModel?>();
      final service = _FakeAnnouncementsEventsService();
      service.detailLoader = (_) => request.future;
      // Pump without settling while the authorized lookup is pending.
      await tester.pumpWidget(
        withEnglishLocalization(
          (context) => ScreenUtilInit(
            designSize: const Size(390, 844),
            builder: (_, _) => localizedMaterialApp(
              context,
              home: EventsAnnouncementsScreen(
                eventsOnly: true,
                eventId: 'missing',
                service: service,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      request.complete(null);
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(TextButton), findsOneWidget);
      service.detailLoader = (_) async =>
          throw StateError('synthetic access failure');
      await tester.tap(find.byType(TextButton));
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'opening an event inbox item marks it read and opens the correct image-less details',
    (tester) async {
      final date = DateTime(2026, 11, 3);
      final service = _FakeAnnouncementsEventsService(
        allowed: true,
        events: [
          EventModel(
            id: 'event-inbox',
            title: 'Inbox event details',
            description: 'Synthetic event description',
            category: 'Community',
            priority: 'low',
            status: 'upcoming',
            eventDate: date,
            location: 'Community hall',
            createdAt: date,
            updatedAt: date,
          ),
        ],
      );
      final notice = NoticeFirestoreService.eventNotice(
        'event-notification',
        {
          'recipientId': 'resident',
          'communityId': 'community',
          'audience': 'resident',
          'role': 'resident',
          'appId': 'resident',
          'type': 'event',
          'eventType': 'community_event_created',
          'title': 'New community event',
          'createdAt': Timestamp.fromDate(date),
          'data': {'route': 'events', 'eventId': 'event-inbox'},
        },
        'resident',
        'community',
      )!;
      String? marked;
      await pumpScreen(
        tester,
        screen: NotificationsScreen(
          eventsService: service,
          loadNotifications: () async => [notice],
          markRead: (id) async {
            marked = id;
          },
        ),
        width: 390,
        textScale: 1.3,
      );
      await tester.tap(find.text('New community event'));
      await tester.pumpAndSettle();
      expect(marked, 'notification:event-notification');
      expect(find.text('Inbox event details'), findsOneWidget);
      expect(find.text('Synthetic event description'), findsOneWidget);
      expect(find.textContaining('Community hall'), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('pushed Announcements route exposes a Back action', (
    tester,
  ) async {
    final service = _FakeAnnouncementsEventsService();
    tester.view.physicalSize = const Size(390, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      withEnglishLocalization(
        (context) => ScreenUtilInit(
          designSize: const Size(390, 844),
          minTextAdapt: true,
          builder: (_, _) => localizedMaterialApp(
            context,
            home: Builder(
              builder: (homeContext) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.push<void>(
                    homeContext,
                    MaterialPageRoute<void>(
                      builder: (_) => EventsAnnouncementsScreen(
                        announcementsOnly: true,
                        service: service,
                      ),
                    ),
                  ),
                  child: const Text('Open Announcements'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open Announcements'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Back'), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Open Announcements'), findsOneWidget);
  });
}
