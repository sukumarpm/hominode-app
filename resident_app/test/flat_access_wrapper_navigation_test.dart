import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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

  testWidgets(
    'initial cached profile verification shows progress until Home is authorized',
    (tester) async {
      final controller = StreamController<AccessControlResult>.broadcast();
      addTearDown(controller.close);
      await tester.pumpWidget(
        MaterialApp(
          home: FlatAccessWrapper(
            accessStream: controller.stream,
            child: const Text('Home'),
          ),
        ),
      );
      controller.add(AccessControlResult.verifying());
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Home'), findsNothing);
      expect(find.text('Retry'), findsNothing);
      controller.add(
        AccessControlResult.granted(
          flatId: 'flat',
          buildingId: 'building',
          userData: const {},
        ),
      );
      await tester.pump();
      expect(find.text('Home'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Retry'), findsNothing);
    },
  );

  testWidgets(
    'server confirmation timeout offers retry and never unlocks cached Home',
    (tester) async {
      final controller = StreamController<AccessControlResult>.broadcast();
      addTearDown(controller.close);
      await tester.pumpWidget(
        withEnglishLocalization(
          (context) => localizedMaterialApp(
            context,
            home: FlatAccessWrapper(
              accessStream: controller.stream,
              verificationTimeout: const Duration(seconds: 2),
              child: const Text('Home'),
            ),
          ),
        ),
      );
      await tester.pump();
      controller.add(AccessControlResult.verifying());
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('Home'), findsNothing);
      await tester.tap(find.text('Retry'));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      controller.add(
        AccessControlResult.granted(
          flatId: 'flat',
          buildingId: 'building',
          userData: const {},
        ),
      );
      await tester.pump();
      expect(find.text('Home'), findsOneWidget);
    },
  );

  test(
    'Firestore authorization failures stay distinct from transient network failures',
    () {
      final denied = FlatAccessControlService.failureResult(
        FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'),
      );
      expect(denied.hasAccess, false);
      expect(denied.isTransient, false);
      final network = FlatAccessControlService.failureResult(
        FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
      );
      expect(network.hasAccess, false);
      expect(network.isTransient, true);
    },
  );

  testWidgets(
    'permission-denied during Home verification remains blocked without a network retry message',
    (tester) async {
      final controller = StreamController<AccessControlResult>.broadcast();
      addTearDown(controller.close);
      await tester.pumpWidget(
        withEnglishLocalization(
          (context) => localizedMaterialApp(
            context,
            home: FlatAccessWrapper(
              accessStream: controller.stream,
              child: const Text('Home'),
            ),
          ),
        ),
      );
      await tester.pump();
      controller.add(AccessControlResult.verifying());
      await tester.pump();
      controller.addError(
        FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Home'), findsNothing);
      expect(find.text('Retry'), findsNothing);
      expect(
        find.text(
          'Your community membership could not be verified. Please contact your community administrator.',
        ),
        findsOneWidget,
      );
    },
  );
}
