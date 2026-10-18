import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resident_app/src/widgets/resident_notification_button.dart';

void main() {
  testWidgets(
    'empty inbox hides badge; unread count caps and clears after read; tap preserved',
    (tester) async {
      final stream = StreamController<int>();
      addTearDown(stream.close);
      var taps = 0;
      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(390, 844),
          builder: (_, _) => MaterialApp(
            home: Scaffold(
              body: ResidentNotificationButton(
                unreadCounts: stream.stream,
                onTap: () => taps++,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('notification-unread-count')),
        findsNothing,
      );
      stream.add(4);
      await tester.pumpAndSettle();
      expect(find.text('4'), findsOneWidget);
      stream.add(120);
      await tester.pumpAndSettle();
      expect(find.text('99+'), findsOneWidget);
      stream.add(0);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('notification-unread-count')),
        findsNothing,
      );
      await tester.tap(find.byIcon(Icons.notifications_none_rounded));
      expect(taps, 1);
      stream.addError(StateError('permission-denied'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('notification-unread-count')),
        findsNothing,
      );
      await tester.pumpWidget(const SizedBox());
      expect(stream.hasListener, false);
    },
  );
}
