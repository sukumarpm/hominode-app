import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resident_app/src/models/notice_model.dart';
import 'package:resident_app/src/screens/notifications_screen.dart';
import 'package:resident_app/src/services/notice_firestore_service.dart';
import 'localization_test_app.dart';

NoticeModel item(String id, {bool? read, bool bill = false}) => NoticeModel(
  id: id,
  isRead: read,
  opensBilling: bill,
  billId: bill ? 'bill-a' : null,
  title: id,
  content: 'A community notification',
  authorId: 'a',
  authorName: 'Community management with a long display name',
  publishDate: DateTime(2026),
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initializeTestLocalization);
  Future<void> mount(
    WidgetTester tester,
    List<NoticeModel> notices,
    Future<void> Function(String) write, {
    double width = 390,
    double scale = 1,
  }) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      withEnglishLocalization(
        (context) => ScreenUtilInit(
          designSize: const Size(390, 844),
          builder: (_, __) => MaterialApp(
            locale: context.locale,
            supportedLocales: context.supportedLocales,
            localizationsDelegates: context.localizationDelegates,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: NotificationsScreen(
              loadNotifications: () async => notices,
              markRead: write,
              billingBuilder: (_) => const Scaffold(body: Text('Bill target')),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'read/unread tint, dot and accessible state do not mark the whole inbox',
    (tester) async {
      final semantics = tester.ensureSemantics();

      var writes = 0;
      await mount(
        tester,
        [item('Unread item', read: false), item('Read item', read: true)],
        (_) async {
          writes++;
        },
      );
      expect(writes, 0);
      expect(
        find.byKey(const ValueKey('notification-unread/Unread item')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('notification-unread/Read item')),
        findsNothing,
      );
      final unread = tester.widget<Container>(
        find.byKey(const ValueKey('notification-card/Unread item')),
      );
      final read = tester.widget<Container>(
        find.byKey(const ValueKey('notification-card/Read item')),
      );
      expect(
        (unread.decoration as BoxDecoration).color,
        const Color(0xFFEEF5FF),
      );
      expect(
        (unread.decoration as BoxDecoration).color,
        isNot((read.decoration as BoxDecoration).color),
      );
      expect(find.bySemanticsLabel(RegExp('Unread')), findsWidgets);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );
  testWidgets(
    'awaits confirmation before styling/navigation and duplicate taps write once',
    (tester) async {
      final pending = Completer<void>();
      var writes = 0;
      await mount(
        tester,
        [item('Bill notification', read: false, bill: true)],
        (_) {
          writes++;
          return pending.future;
        },
      );
      await tester.tap(find.text('Bill notification'));
      await tester.pump();
      await tester.tap(find.text('Bill notification'));
      await tester.pump();
      expect(writes, 1);
      expect(find.text('Bill target'), findsNothing);
      expect(
        find.byKey(const ValueKey('notification-unread/Bill notification')),
        findsOneWidget,
      );
      pending.complete();
      await tester.pumpAndSettle();
      expect(find.text('Bill target'), findsOneWidget);
      Navigator.of(tester.element(find.text('Bill target'))).pop();
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('notification-unread/Bill notification')),
        findsNothing,
      );
      await tester.tap(find.text('Bill notification'));
      await tester.pumpAndSettle();
      expect(writes, 1);
    },
  );
  testWidgets('opening already-read item does not invent a read transition', (
    tester,
  ) async {
    var writes = 0;
    await mount(tester, [item('Already read', read: true)], (_) async {
      writes++;
    });
    await tester.tap(find.text('Already read'));
    await tester.pumpAndSettle();
    expect(writes, 0);
    expect(find.byType(AlertDialog), findsOneWidget);
  });
  testWidgets(
    'failure preserves unread state and offers retry; success updates state',
    (tester) async {
      var fail = true, writes = 0;
      await mount(tester, [item('Retry notice', read: false)], (_) async {
        writes++;
        if (fail) throw StateError('permission-denied');
      });
      await tester.tap(find.text('Retry notice'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(
        find.text('Could not mark this notification as read. Please retry.'),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('notification-unread/Retry notice')),
        findsOneWidget,
      );
      fail = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(writes, 2);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(
        find.byKey(const ValueKey('notification-unread/Retry notice')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('long title/author fits at 320px with enlarged text', (
    tester,
  ) async {
    await mount(
      tester,
      [
        item(
          'An unread notification with a long title that wraps across lines',
          read: false,
        ),
      ],
      (_) async {},
      width: 320,
      scale: 1.8,
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('late receipt completion after disposal is ignored', (
    tester,
  ) async {
    final pending = Completer<void>();
    await mount(tester, [item('Pending', read: false)], (_) => pending.future);
    await tester.tap(find.text('Pending'));
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    pending.complete();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  test(
    'existing receipt contracts persist mixed-source 10→9→8 counts; repeats stay at 8',
    () async {
      final store = _Store();
      final auth = _Auth(_User('r'));
      final notices = [
        for (var n = 0; n < 10; n++)
          item(n < 3 ? 'notice-$n' : 'notification:n$n'),
      ];
      bool isRead(String id) {
        if (id.startsWith('notification:')) {
          return store.docs['notifications/${id.substring(13)}']?['isRead'] ==
              true;
        }
        return store.docs.containsKey('notices/$id/readBy/r');
      }

      final service = NoticeFirestoreService.forTesting(
        auth: auth,
        writeReadReceipt: store.write,
        notices: () async => notices,
        isRead: (id) async => isRead(id),
      );
      final counts = <int>[];
      final subscription = service.streamUnreadCount().listen(counts.add);
      addTearDown(subscription.cancel);
      await Future<void>.delayed(Duration.zero);
      expect(counts.last, 10);
      expect(await service.getUnreadCount(), 10);
      await service.markAsRead('notice-0');
      await Future<void>.delayed(Duration.zero);
      expect(counts.last, 9);
      expect(
        store.docs['notices/notice-0/readBy/r']!.keys,
        unorderedEquals(['readAt', 'userId']),
      );
      expect(store.docs['notices/notice-0/readBy/r']!['userId'], 'r');
      expect(await service.getUnreadCount(), 9);
      await service.markAsRead('notification:n3');
      expect(
        store.docs['notifications/n3']!.keys,
        unorderedEquals(['isRead', 'readAt']),
      );
      expect(await service.getUnreadCount(), 8);
      await Future<void>.delayed(Duration.zero);
      expect(counts.last, 8);
      await service.markAsRead('notification:n3');
      expect(await service.getUnreadCount(), 8);
      expect(store.docs.containsKey('notices/notice-0'), false);
    },
  );
  test(
    'failed or signed-out writes propagate without reducing unread count',
    () async {
      final store = _Store()..fail = true;
      final auth = _Auth(_User('r'));
      final service = NoticeFirestoreService.forTesting(
        auth: auth,
        writeReadReceipt: store.write,
        notices: () async => [item('notification:n')],
        isRead: (_) async => false,
      );
      await expectLater(
        service.markAsRead('notification:n'),
        throwsA(isA<StateError>()),
      );
      expect(await service.getUnreadCount(), 1);
      expect(
        store.docs.values.every(
          (data) => data.length == 1 && data['isRead'] == false,
        ),
        true,
      );
      auth.currentUser = null;
      await expectLater(
        service.markAsRead('notice'),
        throwsA(isA<StateError>()),
      );
      expect(
        store.docs.values.every(
          (data) => data.length == 1 && data['isRead'] == false,
        ),
        true,
      );
    },
  );
  test(
    'read snapshot survives copies without entering shared document writes',
    () {
      final notice = item('notice', read: true);
      expect(notice.copyWith(title: 'Updated').isRead, true);
      expect(notice.copyWith(isRead: false).isRead, false);
      expect(notice.toMap().containsKey('isRead'), false);
      final event = NoticeFirestoreService.eventNotice(
        'event',
        {
          'recipientId': 'r',
          'communityId': 'C',
          'audience': 'resident',
          'role': 'resident',
          'appId': 'resident',
          'type': 'announcement',
          'isRead': true,
        },
        'r',
        'C',
      );
      expect(event?.isRead, true);
    },
  );
}

class _User extends Fake implements User {
  _User(this.uid);
  @override
  final String uid;
}

class _Auth extends Fake implements FirebaseAuth {
  _Auth(this.currentUser);
  @override
  User? currentUser;
  @override
  Stream<User?> idTokenChanges() => Stream.value(currentUser);
}

class _Store {
  final docs = <String, Map<String, dynamic>>{
    for (var n = 3; n < 10; n++) 'notifications/n$n': {'isRead': false},
  };
  bool fail = false;
  Future<void> write(
    String path,
    Map<String, dynamic> data,
    bool canonical,
  ) async {
    if (fail) throw StateError('permission-denied');
    if (canonical && !docs.containsKey(path)) throw StateError('not-found');
    docs[path] = {...?docs[path], ...data};
  }
}
