import 'dart:async';

import 'package:admin_app/services/building_service.dart';
import 'package:admin_app/services/flat_service.dart';
import 'package:admin_app/widgets/add_building_modal.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

final building = BuildingModel(
  id: 'building-a',
  name: 'Tower A',
  floors: 3,
  flatsPerFloor: 3,
  totalFlats: 9,
  occupied: 1,
  vacant: 8,
  occupancyRate: 11,
);
final units = List.generate(
  9,
  (index) => FlatModel(
    id: 'canonical-$index',
    flatId: index == 0 ? 'Villa-03' : 'A-${index + 1}',
    buildingId: 'building-a',
    buildingName: 'Tower A',
    floor: index ~/ 3 + 1,
    flatNumber: index % 3 + 1,
    type: index == 0 ? '5BHK' : '3BHK',
    area: '1200 Sqft',
    status: 'vacant',
  ),
);

Future<void> showEditor(
  WidgetTester tester,
  FutureOr<void> Function(BuildingInput) onSave,
) async {
  tester.view.physicalSize = const Size(1000, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(1000, 1800),
      builder: (context, child) => MaterialApp(
        home: Scaffold(
          body: AddBuildingModal(
            existingBuilding: building,
            existingFlats: units,
            isEditMode: true,
            onSave: onSave,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> save(WidgetTester tester) async {
  final button = find.widgetWithText(ElevatedButton, 'Update Building');
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pump();
}

void main() {
  testWidgets(
    'edit prefills dimensions and actual custom unit labels/configurations',
    (tester) async {
      await showEditor(tester, (_) {});
      final fields = tester
          .widgetList<EditableText>(find.byType(EditableText))
          .toList();
      expect(fields.map((field) => field.controller.text), [
        'Tower A',
        '3',
        '3',
      ]);
      expect(fields.every((field) => !field.readOnly), isTrue);
      // Bottom floor can be below the independently scrolling BHK grid viewport.
      expect(find.text('Villa-03', skipOffstage: false), findsOneWidget);
      expect(find.text('5BHK', skipOffstage: false), findsWidgets);
    },
  );

  testWidgets('expansion sends full input and only new-position BHK defaults', (
    tester,
  ) async {
    BuildingInput? submitted;
    final pending = Completer<void>();
    await showEditor(tester, (input) {
      submitted = input;
      return pending.future;
    });
    await tester.enterText(find.byType(TextFormField).at(0), 'Renamed Tower');
    await tester.enterText(find.byType(TextFormField).at(1), '4');
    await save(tester);
    expect(submitted!.name, 'Renamed Tower');
    expect(submitted!.floors, 4);
    expect(submitted!.flatsPerFloor, 3);
    expect(submitted!.totalFlats, 12);
    expect(submitted!.flatBhkConfig, {
      'pos:4:1': '2BHK',
      'pos:4:2': '2BHK',
      'pos:4:3': '2BHK',
    });
    pending.completeError(Exception('test failure'));
    await tester.pumpAndSettle();
  });

  testWidgets('reduction preserves BHK and does not submit removed positions', (
    tester,
  ) async {
    BuildingInput? submitted;
    await showEditor(tester, (input) {
      submitted = input;
      throw Exception('keep open');
    });
    await tester.enterText(find.byType(TextFormField).at(2), '2');
    await tester.pump();
    expect(find.text('1x5BHK, 5x3BHK'), findsOneWidget);
    await save(tester);
    expect(submitted!.totalFlats, 6);
    expect(submitted!.flatBhkConfig, isEmpty);
  });

  testWidgets(
    'explicit Same for All updates existing units using canonical IDs',
    (tester) async {
      BuildingInput? submitted;
      await showEditor(tester, (input) {
        submitted = input;
        throw Exception('keep open');
      });
      await tester.tap(find.text('Same for All'));
      await tester.pump();
      await tester.tap(find.text('4BHK'));
      await save(tester);
      expect(submitted!.flatBhkConfig, {
        for (final unit in units) 'doc:${unit.id}': '4BHK',
      });
    },
  );

  testWidgets('explicit custom configuration targets one canonical document', (
    tester,
  ) async {
    BuildingInput? submitted;
    await showEditor(tester, (input) {
      submitted = input;
      throw Exception('keep open');
    });
    final unit = find.text('A-9');
    await tester.ensureVisible(unit);
    await tester.tap(unit);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, '1BHK'));
    await tester.pumpAndSettle();
    await save(tester);
    expect(submitted!.flatBhkConfig, {'doc:canonical-8': '1BHK'});
  });

  testWidgets(
    'saving disables duplicate submission; service conflict remains visible and retryable',
    (tester) async {
      var calls = 0;
      final pending = Completer<void>();
      await showEditor(tester, (_) {
        calls++;
        return pending.future;
      });
      await save(tester);
      final button = find.byType(ElevatedButton);
      expect(tester.widget<ElevatedButton>(button).onPressed, isNull);
      await tester.tap(button);
      await tester.pump();
      expect(calls, 1);
      pending.completeError(
        FirebaseFunctionsException(
          code: 'failed-precondition',
          message:
              'Cannot reduce building layout. Units A-103 and A-203 are occupied or reserved.',
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Cannot reduce building layout. Units A-103 and A-203 are occupied or reserved.',
        ),
        findsOneWidget,
      );
      expect(find.text('Edit Building'), findsOneWidget);
      expect(tester.widget<ElevatedButton>(button).onPressed, isNotNull);
    },
  );

  testWidgets(
    'invalid and oversized dimensions do not generate an unbounded grid or submit',
    (tester) async {
      await showEditor(tester, (_) => fail('invalid layout submitted'));
      await tester.enterText(find.byType(TextFormField).at(1), '999999');
      await tester.pump();
      expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNull,
      );
      await tester.enterText(find.byType(TextFormField).at(1), '0');
      await tester.pump();
      expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNull,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
