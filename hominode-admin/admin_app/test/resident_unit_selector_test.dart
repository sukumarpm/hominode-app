import 'package:admin_app/widgets/resident_unit_selector.dart';
import 'package:admin_app/models/unit_schema.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const buildings = [
  ResidentBuildingOption(id: 'b', name: 'Tower B'),
  ResidentBuildingOption(id: 'empty', name: 'Empty Tower'),
  ResidentBuildingOption(id: 'a', name: 'Tower A'),
];
const units = [
  ResidentUnitOption(buildingId: 'b', flatId: 'b101', label: '101'),
  ResidentUnitOption(buildingId: 'a', flatId: 'a10', label: 'A10'),
  ResidentUnitOption(buildingId: 'a', flatId: 'a2', label: 'A2'),
  ResidentUnitOption(buildingId: 'a', flatId: 'a101', label: '101'),
];

Future<void> open(WidgetTester tester, {bool empty = false}) async {
  String? buildingId;
  ResidentUnitOption? unit;
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Form(
          child: StatefulBuilder(
            builder: (context, setState) => ResidentUnitSelector(
              buildings: empty ? [] : buildings,
              units: empty ? [] : units,
              buildingId: buildingId,
              unit: unit,
              onChanged: (b, u) => setState(() {
                buildingId = b;
                unit = u;
              }),
            ),
          ),
        ),
      ),
    ),
  );
}

Future<void> selectBuilding(WidgetTester tester, String name) async {
  await tester.tap(find.byKey(const ValueKey('resident-building')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(name).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'building dropdown sorts names and filters naturally sorted units',
    (tester) async {
      await open(tester);
      final buildingsField = tester.widget<DropdownButton<String>>(
        find.descendant(
          of: find.byKey(const ValueKey('resident-building')),
          matching: find.byType(DropdownButton<String>),
        ),
      );
      expect(buildingsField.items!.map((i) => (i.child as Text).data), [
        'Empty Tower',
        'Tower A',
        'Tower B',
      ]);
      await selectBuilding(tester, 'Tower A');
      final field = tester.widget<DropdownButton<ResidentUnitOption>>(
        find.descendant(
          of: find.byKey(const ValueKey('resident-unit')),
          matching: find.byType(DropdownButton<ResidentUnitOption>),
        ),
      );
      expect(field.items!.map((i) => i.value!.label), ['101', 'A2', 'A10']);
      expect(field.items!.any((i) => i.value!.buildingId == 'b'), false);
    },
  );

  testWidgets(
    'global partial search distinguishes duplicate labels and syncs both dropdowns',
    (tester) async {
      await open(tester);
      await selectBuilding(tester, 'Tower A');
      await tester.enterText(
        find.byKey(const ValueKey('resident-unit-search')),
        '01',
      );
      await tester.pump();
      expect(find.text('Tower A · 101'), findsOneWidget);
      expect(find.text('Tower B · 101'), findsOneWidget);
      await tester.tap(find.text('Tower B · 101'));
      await tester.pumpAndSettle();
      expect(
        tester
            .state<FormFieldState<String>>(
              find.byKey(const ValueKey('resident-building')),
            )
            .value,
        'b',
      );
      expect(
        tester
            .state<FormFieldState<ResidentUnitOption>>(
              find.byKey(const ValueKey('resident-unit')),
            )
            .value
            ?.flatId,
        'b101',
      );
      await selectBuilding(tester, 'Tower A');
      expect(
        tester
            .state<FormFieldState<ResidentUnitOption>>(
              find.byKey(const ValueKey('resident-unit')),
            )
            .value,
        isNull,
      );
    },
  );

  testWidgets(
    'no buildings, no eligible units and no search matches have explicit messages',
    (tester) async {
      await open(tester, empty: true);
      expect(find.text('No buildings available'), findsOneWidget);
      await open(tester);
      await selectBuilding(tester, 'Empty Tower');
      expect(find.text('No eligible units in this building'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('resident-unit-search')),
        'missing',
      );
      await tester.pump();
      expect(find.text('No matching eligible units'), findsOneWidget);
    },
  );

  testWidgets('stale unit not in eligible options fails validation', (
    tester,
  ) async {
    final form = GlobalKey<FormState>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Form(
            key: form,
            child: ResidentUnitSelector(
              buildings: buildings,
              units: [],
              buildingId: 'a',
              unit: units.first,
              onChanged: (_, _) {},
            ),
          ),
        ),
      ),
    );
    expect(form.currentState!.validate(), false);
    await tester.pump();
    expect(find.text('Select an eligible unit.'), findsOneWidget);
  });

  testWidgets(
    'many global matches scroll within a bounded mobile suggestion list',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ResidentUnitSelector(
              buildings: buildings,
              units: List.generate(
                120,
                (i) => ResidentUnitOption(
                  buildingId: i < 60 ? 'a' : 'b',
                  flatId: 'unit-$i',
                  label: '101-$i',
                ),
              ),
              buildingId: 'a',
              unit: null,
              onChanged: (_, _) {},
            ),
          ),
        ),
      );
      await tester.enterText(
        find.byKey(const ValueKey('resident-unit-search')),
        '101',
      );
      await tester.pump();
      final suggestions = find.byKey(
        const ValueKey('resident-unit-suggestions'),
      );
      expect(tester.getSize(suggestions).height, lessThanOrEqualTo(200));
      await tester.drag(suggestions, const Offset(0, -500));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'availability guard excludes occupied, reserved, inactive and shared/ambiguous units',
    () {
      expect(isUnitAvailableForNewResident({'status': 'vacant'}), true);
      for (final changes in [
        {'status': 'occupied'},
        {'status': 'reserved'},
        {'isActive': false},
        {'residentUserId': 'resident'},
        {'residentUid': 'legacy'},
        {'residentId': 'old'},
        {
          'residentIds': ['one', 'two'],
        },
        {'residentIds': 'malformed'},
        {'reservedOnboardingId': 'pending'},
      ]) {
        expect(
          isUnitAvailableForNewResident({'status': 'vacant', ...changes}),
          false,
        );
      }
    },
  );
}
