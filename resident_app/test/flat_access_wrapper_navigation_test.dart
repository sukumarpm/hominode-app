import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resident_app/src/services/flat_access_control_service.dart';
import 'package:resident_app/src/widgets/flat_access_wrapper.dart';
import 'localization_test_app.dart';

void main() {
  setUpAll(initializeTestLocalization);

  testWidgets(
    'parent navigation rebuild keeps the live access stream subscribed',
    (tester) async {
      var listenCount = 0;
      final controller = StreamController<AccessControlResult>.broadcast(
        onListen: () => listenCount++,
      );
      addTearDown(controller.close);
      var rebuildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) => Scaffold(
              body: Column(
                children: [
                  Expanded(
                    child: FlatAccessWrapper(
                      accessStream: controller.stream,
                      child: const Text('Facilities page'),
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() => rebuildCount++),
                    child: const Text('Switch tab'),
                  ),
                  Text('$rebuildCount'),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      controller.add(
        AccessControlResult.granted(
          flatId: 'fixture-flat',
          buildingId: 'fixture-building',
          userData: const {'role': 'resident'},
        ),
      );
      await tester.pump();
      expect(find.text('Facilities page'), findsOneWidget);

      await tester.tap(find.text('Switch tab'));
      await tester.pump();
      expect(listenCount, 1);
      expect(find.text('Facilities page'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('transient membership verification results offer a retry', (
    tester,
  ) async {
    final controller = StreamController<AccessControlResult>.broadcast();
    addTearDown(controller.close);
    await tester.pumpWidget(
      withEnglishLocalization(
        (context) => localizedMaterialApp(
          context,
          home: FlatAccessWrapper(
            accessStream: controller.stream,
            child: const Text('Resident destination'),
          ),
        ),
      ),
    );
    await tester.pump();
    controller.add(
      AccessControlResult.error(
        message: 'synthetic temporary failure',
        isTransient: true,
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        'A temporary service error prevented verification. Please try again.',
      ),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pump();
    controller.add(
      AccessControlResult.granted(
        flatId: 'fixture-flat',
        buildingId: 'fixture-building',
        userData: const {'role': 'resident'},
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Resident destination'), findsOneWidget);
    expect(
      find.text(
        'A temporary service error prevented verification. Please try again.',
      ),
      findsNothing,
    );
    expect(find.text('Retry'), findsNothing);
  });

  testWidgets('membership validation failures are distinct from service errors', (
    tester,
  ) async {
    final controller = StreamController<AccessControlResult>.broadcast();
    addTearDown(controller.close);
    await tester.pumpWidget(
      withEnglishLocalization(
        (context) => localizedMaterialApp(
          context,
          home: FlatAccessWrapper(
            accessStream: controller.stream,
            child: const Text('Resident destination'),
          ),
        ),
      ),
    );
    await tester.pump();
    controller.add(AccessControlResult.error(message: 'private detail'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Your community membership could not be verified. Please contact your community administrator.',
      ),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsNothing);
    expect(find.text('private detail'), findsNothing);
  });
}
