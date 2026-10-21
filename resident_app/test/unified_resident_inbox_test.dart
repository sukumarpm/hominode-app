import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resident_app/src/models/notice_model.dart';
import 'package:resident_app/src/services/notice_firestore_service.dart';
import 'package:resident_app/src/services/resident_notification_router.dart';
import 'package:resident_app/src/screens/notifications_screen.dart';
import 'localization_test_app.dart';

Map<String, dynamic> canonical({
  String type = 'payment',
  bool deleted = false,
}) => {
  'recipientId': 'r',
  'communityId': 'C',
  'audience': 'resident',
  'role': 'resident',
  'appId': 'resident',
  'type': type,
  'title': 'New Bill Created',
  'message': 'Open your bill',
  'sourceEntityId': 'bill-a',
  'createdAt': Timestamp.fromDate(DateTime(2026, 10, 21)),
  if (deleted) 'deletedAt': Timestamp.now(),
};
NoticeModel notice(String id) => NoticeModel(
  id: id,
  title: id,
  content: 'Synthetic notice',
  authorId: 'a',
  authorName: 'Admin',
  publishDate: DateTime(2026),
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initializeTestLocalization);
  test(
    'canonical bill, event and notice adapters preserve own-recipient visibility and discard soft-deleted entries',
    () {
      final bill = NoticeFirestoreService.eventNotice(
        'bill-notification',
        canonical(),
        'r',
        'C',
      )!;
      expect(bill.billId, 'bill-a');
      expect(bill.opensBilling, true);
      expect(bill.category, 'billing');
      expect(
        ResidentNotificationRouter.destinationForNotification(canonical()),
        ResidentNotificationDestination.billing,
      );
      final event = {
        ...canonical(type: 'event'),
        'eventType': 'community_event_created',
        'data': {'route': 'events', 'eventId': 'event-a'},
      };
      expect(
        NoticeFirestoreService.eventNotice('event', event, 'r', 'C')?.eventId,
        'event-a',
      );
      expect(
        NoticeFirestoreService.eventNotice(
          'notice',
          canonical(type: 'announcement'),
          'r',
          'C',
        )?.category,
        'announcement',
      );
      expect(
        NoticeFirestoreService.eventNotice(
          'deleted',
          canonical(deleted: true),
          'r',
          'C',
        ),
        isNull,
      );
      expect(
        NoticeFirestoreService.eventNotice(
          'foreign',
          canonical(),
          'other',
          'C',
        ),
        isNull,
      );
      expect(
        NoticeFirestoreService.eventNotice('foreign', canonical(), 'r', 'D'),
        isNull,
      );
      expect(
        ResidentNotificationRouter.isAuthorizedNotification(
          uid: 'r',
          payloadCommunityId: 'C',
          profile: {
            'uid': 'r',
            'role': 'resident',
            'communityId': 'C',
            'isActive': true,
            'approvalStatus': 'approved',
          },
          notification: canonical(deleted: true),
        ),
        false,
      );
    },
  );
  test(
    'unified unread totals exclude dismissed items and update after reading or bulk deletion',
    () async {
      final records = <String, Map<String, dynamic>>{
        'bill': canonical(),
        'event': {
          ...canonical(type: 'event'),
          'eventType': 'community_event_created',
          'data': {'route': 'events', 'eventId': 'event'},
        },
      };
      var sharedVisible = true;
      final read = <String>{};
      final service = NoticeFirestoreService.forTesting(
        notices: () async => [
          if (sharedVisible) notice('shared'),
          ...records.entries
              .map(
                (entry) => NoticeFirestoreService.eventNotice(
                  entry.key,
                  entry.value,
                  'r',
                  'C',
                ),
              )
              .whereType<NoticeModel>(),
        ],
        isRead: (id) async => read.contains(id),
      );
      expect(await service.getUnreadCount(), 3);
      read.add('notification:bill');
      expect(await service.getUnreadCount(), 2);
      records['event']!['deletedAt'] = Timestamp.now();
      sharedVisible =
          false; // own notice receipt contains a dismissal tombstone
      expect(await service.getUnreadCount(), 0);
      expect(records.length, 2); // source records are retained
    },
  );

  Future<void> mount(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      withEnglishLocalization(
        (context) => ScreenUtilInit(
          designSize: const Size(390, 844),
          builder: (_, _) => localizedMaterialApp(context, home: screen),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'single deletion confirms and removes only the selected inbox row',
    (tester) async {
      final deleted = <String>[];
      await mount(
        tester,
        NotificationsScreen(
          loadNotifications: () async => [notice('first'), notice('second')],
          deleteNotifications: (ids) async {
            deleted.addAll(ids);
          },
        ),
      );
      await tester.tap(find.byKey(const ValueKey('delete/first')));
      await tester.pumpAndSettle();
      expect(deleted, isEmpty);
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pumpAndSettle();
      expect(deleted, ['first']);
      expect(find.text('first'), findsNothing);
      expect(find.text('second'), findsOneWidget);
    },
  );
  testWidgets(
    'bulk selection deletes multiple rows and cancel performs no writes',
    (tester) async {
      final deleted = <String>[];
      await mount(
        tester,
        NotificationsScreen(
          loadNotifications: () async => [
            notice('first'),
            notice('second'),
            notice('third'),
          ],
          deleteNotifications: (ids) async {
            deleted.addAll(ids);
          },
        ),
      );
      await tester.tap(find.byIcon(Icons.checklist));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Checkbox).at(0));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Checkbox).at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(deleted, isEmpty);
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pumpAndSettle();
      expect(deleted, ['first', 'second']);
      expect(find.text('third'), findsOneWidget);
      expect(find.byType(Checkbox), findsNothing);
    },
  );
  testWidgets('delete failure keeps rows available and exits loading state', (
    tester,
  ) async {
    await mount(
      tester,
      NotificationsScreen(
        loadNotifications: () async => [notice('first')],
        deleteNotifications: (_) async {
          throw StateError('synthetic denial');
        },
      ),
    );
    await tester.tap(find.byKey(const ValueKey('delete/first')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(find.text('first'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Error. Retry'), findsOneWidget);
  });
  testWidgets(
    'bill inbox tap records read state and opens the exact bill target',
    (tester) async {
      String? read, target;
      final bill = NoticeFirestoreService.eventNotice(
        'bill-note',
        canonical(),
        'r',
        'C',
      )!;
      await mount(
        tester,
        NotificationsScreen(
          loadNotifications: () async => [bill],
          markRead: (id) async {
            read = id;
          },
          billingBuilder: (id) {
            target = id;
            return const Scaffold(body: Text('Authorized bill route'));
          },
        ),
      );
      await tester.tap(find.text('New Bill Created'));
      await tester.pumpAndSettle();
      expect(read, 'notification:bill-note');
      expect(target, 'bill-a');
      expect(find.text('Authorized bill route'), findsOneWidget);
    },
  );
}
