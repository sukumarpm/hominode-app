import 'package:admin_app/services/building_service.dart';
import 'package:admin_app/widgets/add_building_modal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('building structural fields are read-only while editing', (
    tester,
  ) async {
    final building = BuildingModel(
      id: 'building-a',
      name: 'Tower A',
      floors: 5,
      flatsPerFloor: 4,
      totalFlats: 20,
      occupied: 1,
      vacant: 19,
      occupancyRate: 5,
    );

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(800, 600),
        builder: (context, child) => MaterialApp(
          home: Scaffold(
            body: AddBuildingModal(
              existingBuilding: building,
              isEditMode: true,
              onSave: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final fields = tester
        .widgetList<EditableText>(find.byType(EditableText))
        .toList();
    expect(fields, hasLength(3));
    expect(fields[0].readOnly, isFalse);
    expect(fields[1].readOnly, isTrue);
    expect(fields[2].readOnly, isTrue);
  });
}
