import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:admin_app/models/building_deletion.dart';
import 'package:admin_app/services/complaint_service.dart';
import 'package:admin_app/widgets/building_deletion_dialog.dart';

const safe = BuildingDeletionCheck(
  canDelete: true,
  buildingName: 'Tower A',
  unitCount: 12,
);

Future<void> openDialog(
  WidgetTester tester, {
  required Future<BuildingDeletionCheck> Function() validate,
  required Future<void> Function() delete,
  Stream<bool>? buildings,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Column(
            children: [
              StreamBuilder<bool>(
                stream: buildings,
                initialData: true,
                builder: (_, snapshot) => snapshot.data == true
                    ? const Text('Visible building')
                    : const Text('No buildings'),
              ),
              TextButton(
                onPressed: () async {
                  final deleted = await showBuildingDeletionDialog(
                    context: context,
                    buildingName: 'Tower A',
                    validate: validate,
                    delete: delete,
                  );
                  if (context.mounted && deleted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Deleted successfully')),
                    );
                  }
                },
                child: const Text('Open deletion'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open deletion'));
  await tester.pump();
}

void main() {
  test(
    'retained complaint label remains readable independently of the deleted unit',
    () {
      final complaint = ComplaintModel.fromMap('complaint', {
        'flatId': 'canonical-unit',
        'flatLabel': 'Villa-03',
        'status': 'resolved',
      });
      expect(complaint.flatLabel, 'Villa-03');
      expect(complaint.flatId, 'canonical-unit');
      expect(complaint.toMap()['flatLabel'], 'Villa-03');
    },
  );
  testWidgets(
    'preflight must finish before destructive confirmation becomes available',
    (tester) async {
      final preflight = Completer<BuildingDeletionCheck>();
      await openDialog(
        tester,
        validate: () => preflight.future,
        delete: () async {},
      );
      expect(find.text('Checking Tower A…'), findsOneWidget);
      expect(find.text('Delete'), findsNothing);
      preflight.complete(safe);
      await tester.pumpAndSettle();
      expect(find.text('Delete Tower A?'), findsOneWidget);
      expect(find.textContaining('12 unused units'), findsOneWidget);
      expect(
        find.textContaining(
          'Historical resident/security records will not be deleted',
        ),
        findsOneWidget,
      );
      final button = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Delete'),
      );
      expect(
        button.style!.foregroundColor!.resolve({}),
        const Color(0xFFEF4444),
      );
    },
  );

  testWidgets(
    'blocked preflight shows custom unit reasons with no Delete button',
    (tester) async {
      var deletes = 0;
      await openDialog(
        tester,
        validate: () async => const BuildingDeletionCheck(
          canDelete: false,
          buildingName: 'Tower A',
          unitCount: 12,
          reasons: ['Villa-03 — Reserved', '2 active resident assignments'],
          conflictCount: 2,
        ),
        delete: () async {
          deletes++;
        },
      );
      await tester.pumpAndSettle();
      expect(find.text('Cannot delete Tower A'), findsOneWidget);
      expect(find.text('Villa-03 — Reserved'), findsOneWidget);
      expect(find.text('Delete'), findsNothing);
      expect(deletes, 0);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Visible building'), findsOneWidget);
      expect(find.text('Deleted successfully'), findsNothing);
    },
  );

  testWidgets(
    'saving disables duplicate submission and success follows server and stream',
    (tester) async {
      final deletion = Completer<void>();
      final buildings = StreamController<bool>.broadcast();
      addTearDown(buildings.close);
      var deletes = 0;
      await openDialog(
        tester,
        validate: () async => safe,
        delete: () {
          deletes++;
          return deletion.future;
        },
        buildings: buildings.stream,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pump();
      await tester.tap(find.text('Deleting…'));
      await tester.pump();
      expect(deletes, 1);
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Cancel'))
            .onPressed,
        isNull,
      );
      expect(find.text('Deleted successfully'), findsNothing);
      expect(find.text('Visible building'), findsOneWidget);
      buildings.add(false);
      deletion.complete();
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('No buildings'), findsOneWidget);
      expect(find.text('Deleted successfully'), findsOneWidget);
    },
  );

  testWidgets(
    'new reservation at final delete shows clean conflict and leaves building visible',
    (tester) async {
      await openDialog(
        tester,
        validate: () async => safe,
        delete: () async {
          throw FirebaseFunctionsException(
            code: 'failed-precondition',
            message: 'Cannot delete Tower A. A-102 — Reserved.',
          );
        },
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(
        find.text('Cannot delete Tower A. A-102 — Reserved.'),
        findsOneWidget,
      );
      expect(find.textContaining('FirebaseFunctionsException'), findsNothing);
      expect(find.text('Delete'), findsNothing);
      expect(find.text('Visible building'), findsOneWidget);
      expect(find.text('Deleted successfully'), findsNothing);
    },
  );

  for (final preflightError in [true, false]) {
    testWidgets(
      'unexpected ${preflightError ? 'preflight' : 'delete'} errors do not expose raw server details',
      (tester) async {
        Future<BuildingDeletionCheck> validate() async {
          if (preflightError) {
            throw FirebaseFunctionsException(
              code: 'internal',
              message: 'sensitive internal error',
            );
          }
          return safe;
        }

        await openDialog(
          tester,
          validate: validate,
          delete: () async => throw Exception('sensitive internal error'),
        );
        await tester.pumpAndSettle();
        if (!preflightError) {
          await tester.tap(find.text('Delete'));
          await tester.pumpAndSettle();
        }
        expect(
          find.text(
            'Unable to complete building deletion. Please refresh and try again.',
          ),
          findsOneWidget,
        );
        expect(find.textContaining('sensitive internal error'), findsNothing);
        expect(find.textContaining('FirebaseFunctionsException'), findsNothing);
        expect(find.text('Visible building'), findsOneWidget);
      },
    );
  }
}
