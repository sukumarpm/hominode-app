import 'dart:async';

import 'package:admin_app/models/unit_schema.dart';
import 'package:admin_app/services/building_service.dart';
import 'package:admin_app/services/flat_service.dart';
import 'package:admin_app/widgets/add_building_modal.dart';
import 'package:admin_app/widgets/flat_occupancy_grid_modal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> mount(
  WidgetTester tester,
  Widget child, {
  bool settle = true,
}) async {
  tester.view.physicalSize = const Size(1000, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(1000, 1800),
      builder: (context, _) => MaterialApp(home: Scaffold(body: child)),
    ),
  );
  if (settle) await tester.pumpAndSettle();
}

void main() {
  test(
    'legacy normalization defaults to apartments and never mutates maps',
    () {
      final legacy = <String, dynamic>{'flatId': 'A001'};
      expect(
        HousingStructureType.fromValue(null),
        HousingStructureType.apartmentBuilding,
      );
      expect(HousingUnitType.fromValue(null), HousingUnitType.apartment);
      expect(visibleUnitLabel(legacy, 'canonical'), 'A001');
      expect(
        visibleUnitLabel({
          'flatLabel': 'Villa-03',
          'flatId': 'A001',
        }, 'canonical'),
        'Villa-03',
      );
      expect(visibleUnitLabel({'unitId': 'RH-07'}, 'canonical'), 'RH-07');
      expect(legacy, {'flatId': 'A001'});
    },
  );

  for (final type in [
    HousingStructureType.villaCluster,
    HousingStructureType.rowHouseCluster,
    HousingStructureType.townhouseCluster,
  ]) {
    testWidgets('create ${type.label} uses a count without floors', (
      tester,
    ) async {
      BuildingInput? saved;
      await mount(
        tester,
        AddBuildingModal(
          onSave: (input) {
            saved = input;
            throw Exception('keep editor open');
          },
        ),
      );
      await tester.enterText(find.byType(TextFormField).first, 'New Homes');
      await tester.tap(
        find.byType(DropdownButtonFormField<HousingStructureType>),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(type.label).last);
      await tester.pumpAndSettle();
      expect(find.text('Floors'), findsNothing);
      expect(find.text(type.countLabel), findsOneWidget);
      await tester.enterText(find.byType(TextFormField).last, '4');
      await tester.pump();
      final save = find.widgetWithText(ElevatedButton, 'Add Building');
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(saved!.structureType, type);
      expect(saved!.unitType, type.defaultUnitType);
      expect(saved!.floors, 0);
      expect(saved!.flatsPerFloor, 0);
      expect(saved!.totalFlats, 4);
      expect(saved!.flatBhkConfig.keys, [
        'index:1',
        'index:2',
        'index:3',
        'index:4',
      ]);
    });
  }

  testWidgets(
    'existing villa prefill/expansion preserves canonical BHK keys and custom labels',
    (tester) async {
      BuildingInput? saved;
      final building = BuildingModel(
        id: 'b',
        name: 'Villas',
        structureType: HousingStructureType.villaCluster,
        floors: 0,
        flatsPerFloor: 0,
        totalFlats: 2,
        occupied: 0,
        vacant: 2,
        occupancyRate: 0,
      );
      final units = List.generate(
        2,
        (i) => FlatModel(
          id: 'canonical-$i',
          flatId: 'Villa-${i + 1}',
          buildingId: 'b',
          buildingName: 'Villas',
          floor: 0,
          flatNumber: i + 1,
          unitIndex: i + 1,
          unitType: HousingUnitType.villa,
          type: '3BHK',
          area: '1800 Sqft',
          status: 'vacant',
        ),
      );
      await mount(
        tester,
        AddBuildingModal(
          isEditMode: true,
          existingBuilding: building,
          existingFlats: units,
          onSave: (input) {
            saved = input;
            throw Exception('keep editor open');
          },
        ),
      );
      expect(find.text('Villa-1'), findsOneWidget);
      expect(find.text('Floors'), findsNothing);
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).last)
            .controller!
            .text,
        '2',
      );
      await tester.enterText(find.byType(TextFormField).last, '3');
      final save = find.widgetWithText(ElevatedButton, 'Update Building');
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(saved!.totalFlats, 3);
      expect(saved!.flatBhkConfig, {'index:3': '2BHK'});
      expect(saved!.unitType, isNull);
    },
  );

  testWidgets(
    'cluster occupancy stream keeps search, reserved filter, list/grid and custom rename updates',
    (tester) async {
      final stream = StreamController<List<FloorOccupancy>>();
      addTearDown(stream.close);
      FlatUnit unit(String label, FlatStatus status) => FlatUnit(
        id: label,
        docId: 'canonical',
        type: '3BHK',
        unitType: HousingUnitType.villa,
        unitIndex: 1,
        status: status,
        floor: 0,
        area: '1800 Sqft',
      );
      await mount(
        tester,
        FlatOccupancyGridModal(
          towerName: 'Villas',
          dataStream: stream.stream,
          onFlatTap: (_) {},
        ),
        settle: false,
      );
      stream.add([
        FloorOccupancy(
          floorNumber: 0,
          flats: [unit('Villa-03', FlatStatus.vacant)],
        ),
      ]);
      await tester.pumpAndSettle();
      expect(find.text('Units'), findsOneWidget);
      expect(find.text('Floor 0'), findsNothing);
      expect(find.text('Villa-03'), findsOneWidget);
      stream.add([
        FloorOccupancy(
          floorNumber: 0,
          flats: [unit('Custom Home', FlatStatus.reserved)],
        ),
      ]);
      await tester.pumpAndSettle();
      expect(find.text('Custom Home'), findsOneWidget);
      expect(find.text('Villa-03'), findsNothing);
      await tester.tap(find.text('List View'));
      await tester.pumpAndSettle();
      expect(find.text('Custom Home'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'missing');
      await tester.pumpAndSettle();
      expect(find.text('No units found'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'custom');
      await tester.tap(find.byType(PopupMenuButton<FlatStatus?>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reserved').last);
      await tester.pumpAndSettle();
      expect(find.text('Custom Home'), findsOneWidget);
      stream.add([
        FloorOccupancy(
          floorNumber: 0,
          flats: [unit('Custom Home', FlatStatus.vacant)],
        ),
      ]);
      await tester.pumpAndSettle();
      expect(find.text('No units found'), findsOneWidget);
    },
  );
}
