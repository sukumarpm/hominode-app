import 'dart:async';

import 'package:admin_app/widgets/create_event_modal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> open(
  WidgetTester tester,
  Future<void> Function(Map<String, dynamic>) submit,
) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, _) => MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showCreateEventModal(context, onSubmit: submit),
              child: const Text('Open event'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open event'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextFormField).first, 'Gathering');
}

void main() {
  testWidgets(
    'failed save keeps the form and entered details, then retry succeeds',
    (tester) async {
      var calls = 0;
      await open(tester, (data) async {
        calls++;
        expect(data['title'], 'Gathering');
        expect(data.containsKey('localImagePath'), isFalse);
        if (calls == 1) throw StateError('Synthetic denied upload');
      });
      await tester.tap(find.text('Create & Notify All'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Could not save the event and photo. Your details are kept. Please retry.',
        ),
        findsOneWidget,
      );
      expect(find.text('Gathering'), findsOneWidget);
      await tester.tap(find.text('Create & Notify All'));
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(find.byType(CreateEventModal), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'pending upload prevents duplicate submit and premature dismissal',
    (tester) async {
      final pending = Completer<void>();
      var calls = 0;
      await open(tester, (_) {
        calls++;
        return pending.future;
      });
      await tester.tap(find.text('Create & Notify All'));
      await tester.pump();
      expect(find.text('Saving…'), findsOneWidget);
      expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNull,
      );
      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();
      expect(find.byType(CreateEventModal), findsOneWidget);
      expect(calls, 1);
      pending.complete();
      await tester.pumpAndSettle();
      expect(find.byType(CreateEventModal), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
