import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hominode_notifications/hominode_notifications.dart';
import 'package:security_app/models/attendance_model.dart';
import 'package:security_app/screens/profile_screen.dart';
import 'package:security_app/screens/security_notifications_screen.dart';
import 'package:security_app/services/security_inbox_service.dart';
import 'security_inbox_service_test.dart' show InboxTestAuth, notice;

class _Inbox implements SecurityInbox {
  Stream<List<SecurityInboxNotification>>? source;
  List<SecurityInboxNotification> rows = [notice()];
  Completer<void>? pending;
  Object? error;
  int writes = 0, watches = 0;
  @override
  Stream<List<SecurityInboxNotification>> watch() {
    watches++;
    return source?.map((rows) => rows) ?? Stream.value(rows);
  }

  @override
  Future<void> markRead(SecurityInboxNotification notification) async {
    writes++;
    if (error != null) throw error!;
    await pending?.future;
  }
}

AttendanceModel attendance({
  String status = 'checked_in',
  DateTime? checkout,
  String staff = 'guard-a',
}) => AttendanceModel(
  id: 'a1',
  staffId: staff,
  staffName: 'Officer A',
  gateName: 'Main Gate',
  checkInTime: DateTime(2026, 11, 9),
  status: status,
  checkOutTime: checkout,
);

void main() {
  setUpAll(() async {
    var directory = File(Platform.resolvedExecutable).parent;
    while (!File(
      '${directory.path}/bin/cache/artifacts/material_fonts/Roboto-Regular.ttf',
    ).existsSync()) {
      if (directory.parent.path == directory.path) {
        throw StateError('Flutter Roboto font not found');
      }
      directory = directory.parent;
    }
    final fonts = FontLoader('Roboto');
    for (final font in ['Roboto-Regular.ttf', 'Roboto-Medium.ttf']) {
      fonts.addFont(
        Future.value(
          ByteData.sublistView(
            File(
              '${directory.path}/bin/cache/artifacts/material_fonts/$font',
            ).readAsBytesSync(),
          ),
        ),
      );
    }
    await fonts.load();
  });

  Future<void> mount(
    WidgetTester tester,
    Widget home, {
    double width = 393,
    double scale = 1,
    bool settle = true,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, width == 393 ? 852 : 1280);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: home,
      ),
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
  }

  testWidgets(
    'Notifications opens an inbox and P0/P1 options remain accessible',
    (tester) async {
      await mount(
        tester,
        ProfileScreen(
          authService: InboxTestAuth(),
          inbox: _Inbox(),
          attendanceStream: (_) => Stream.value(null),
        ),
      );
      expect(find.text('Change Password'), findsNothing);
      expect(find.text('Help & Support'), findsOneWidget);
      expect(find.text('Request Account Deletion'), findsOneWidget);
      await tester.ensureVisible(find.text('Notifications'));
      await tester.tap(find.text('Notifications'));
      await tester.pumpAndSettle();
      expect(find.byType(SecurityNotificationsScreen), findsOneWidget);
      expect(find.text('Community update'), findsOneWidget);
      expect(find.textContaining('Coming soon'), findsNothing);
    },
  );

  testWidgets(
    'full message, timestamp, and read state render; success waits for confirmation',
    (tester) async {
      final inbox = _Inbox()..pending = Completer<void>();
      await mount(tester, SecurityNotificationsScreen(inbox: inbox));
      expect(find.text('Please review your assignment.'), findsOneWidget);
      expect(find.textContaining('Nov 9, 2026'), findsOneWidget);
      expect(find.text('Unread'), findsOneWidget);
      await tester.tap(find.text('Mark as read'));
      await tester.pump();
      expect(find.text('Read'), findsNothing);
      expect(find.text('Please wait…'), findsOneWidget);
      await tester.tap(find.text('Please wait…'));
      expect(inbox.writes, 1);
      inbox.pending!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Read'), findsOneWidget);
      expect(find.text('Mark as read'), findsNothing);
    },
  );

  testWidgets('failed read update leaves unread and supports retry', (
    tester,
  ) async {
    final inbox = _Inbox()
      ..error = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
      );
    await mount(tester, SecurityNotificationsScreen(inbox: inbox));
    await tester.tap(find.text('Mark as read'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Notification access denied'), findsOneWidget);
    expect(find.text('Unread'), findsOneWidget);
    inbox.error = null;
    await tester.tap(find.text('Mark as read'));
    await tester.pumpAndSettle();
    expect(find.text('Read'), findsOneWidget);
  });

  testWidgets('loading, empty, errors and retry clear any previous content', (
    tester,
  ) async {
    final controller =
        StreamController<List<SecurityInboxNotification>>.broadcast();
    addTearDown(controller.close);
    final inbox = _Inbox()..source = controller.stream;
    await mount(
      tester,
      SecurityNotificationsScreen(inbox: inbox),
      settle: false,
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    controller.add([]);
    await tester.pumpAndSettle();
    expect(find.text('No notifications yet.'), findsOneWidget);
    controller.add([notice()]);
    await tester.pumpAndSettle();
    expect(find.text('Community update'), findsOneWidget);
    controller.addError(
      FirebaseException(plugin: 'cloud_firestore', code: 'failed-precondition'),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('indexes'), findsOneWidget);
    expect(find.text('Community update'), findsNothing);
    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(inbox.watches, 2);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    controller.add([notice()]);
    await tester.pumpAndSettle();
    expect(find.text('Community update'), findsOneWidget);
  });

  testWidgets('SOS inbox action reuses a canonical notification payload', (
    tester,
  ) async {
    final inbox = _Inbox()
      ..rows = [
        notice(
          id: 'sos-notification',
          overrides: {'type': 'sos', 'sourceEntityId': 'SOS-1'},
        ),
      ];
    HominodeNotificationPayload? opened;
    await mount(
      tester,
      SecurityNotificationsScreen(
        inbox: inbox,
        onNotificationTap: (payload) async {
          opened = payload;
        },
      ),
    );
    expect(find.text('Emergency SOS'), findsOneWidget);
    await tester.tap(find.text('Open SOS alert'));
    await tester.pumpAndSettle();
    expect(opened?.type, 'notification');
    expect(opened?.entityId, 'sos-notification');
    expect(opened?.communityId, 'C1');
    expect(inbox.writes, 0);
  });

  testWidgets(
    'duty follows attendance independently of active account and assignments',
    (tester) async {
      final controller = StreamController<AttendanceModel?>.broadcast();
      addTearDown(controller.close);
      await mount(
        tester,
        ProfileScreen(
          authService: InboxTestAuth(),
          attendanceStream: (_) => controller.stream,
        ),
      );
      expect(find.text('Active'), findsOneWidget);
      expect(find.text('Not assigned'), findsWidgets);
      expect(find.text('Checking attendance…'), findsOneWidget);
      expect(find.text('On Duty'), findsNothing);
      controller.add(null);
      await tester.pumpAndSettle();
      expect(find.text('Not Checked In'), findsOneWidget);
      controller.add(attendance());
      await tester.pumpAndSettle();
      expect(find.text('On Duty'), findsOneWidget);
      controller.add(attendance(checkout: DateTime(2026, 11, 9, 17)));
      await tester.pumpAndSettle();
      expect(find.text('Not Checked In'), findsOneWidget);
      for (final record in [
        attendance(status: 'checked_out'),
        attendance(staff: 'guard-b'),
      ]) {
        controller.add(record);
        await tester.pumpAndSettle();
        expect(find.text('On Duty'), findsNothing);
      }
      controller.addError(Exception('unavailable'));
      await tester.pumpAndSettle();
      expect(find.text('Unavailable — retry'), findsOneWidget);
      expect(find.text('On Duty'), findsNothing);
      await tester.ensureVisible(find.text('Retry duty status'));
      await tester.tap(find.text('Retry duty status'));
      await tester.pumpAndSettle();
      controller.add(attendance());
      await tester.pumpAndSettle();
      expect(find.text('On Duty'), findsOneWidget);
    },
  );

  for (final width in [393.0, 600.0, 800.0]) {
    for (final scale in [1.0, 1.3, 1.5]) {
      testWidgets('Profile and inbox fit width $width at text scale $scale', (
        tester,
      ) async {
        await mount(
          tester,
          ProfileScreen(
            authService: InboxTestAuth(),
            attendanceStream: (_) => Stream.value(null),
          ),
          width: width,
          scale: scale,
        );
        expect(find.text('Not Checked In'), findsOneWidget);
        expect(tester.takeException(), isNull);
        final inbox = _Inbox()
          ..rows = [
            notice(
              overrides: {
                'title':
                    'Emergency assistance requested at the community entrance',
                'message':
                    'Please assist the resident at the main gate. This is a longer notification message that must remain fully readable on phones and tablets.',
                'type': 'sos',
                'sourceEntityId': 'SOS-1',
              },
            ),
          ];
        await mount(
          tester,
          SecurityNotificationsScreen(inbox: inbox),
          width: width,
          scale: scale,
        );
        expect(find.text('Unread'), findsOneWidget);
        await tester.ensureVisible(find.text('Open SOS alert'));
        expect(tester.takeException(), isNull);
      });
    }
  }
}
