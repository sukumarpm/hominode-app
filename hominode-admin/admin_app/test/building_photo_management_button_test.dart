import 'package:admin_app/manage_buildings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'Manage Photos button is visible, touch-sized, responsive, and keeps canonical building ID',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: BuildingPhotoManagementButton(
                buildingId: 'canonical-building-42',
                destinationBuilder: (_, id) =>
                    Scaffold(body: Text('Building photo scope: $id')),
              ),
            ),
          ),
        ),
      );

      final button = find.ancestor(
        of: find.text('Manage Photos'),
        matching: find.byType(OutlinedButton),
      );
      expect(button, findsOneWidget);
      expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
      expect(tester.getSize(button).width, lessThanOrEqualTo(320));

      await tester.tap(find.text('Manage Photos'));
      await tester.pumpAndSettle();
      expect(
        find.text('Building photo scope: canonical-building-42'),
        findsOneWidget,
      );
    },
  );
}
