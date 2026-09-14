import 'package:admin_app/desktop/admin_desktop_page_frame.dart';
import 'package:admin_app/desktop/admin_module_desktop_contents.dart';
import 'package:admin_app/navigation/admin_module_destinations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('desktop registry maps every module to desktop content', (
    tester,
  ) async {
    final expectedTypes = <AdminModuleId, Type>{
      AdminModuleId.buildings: BuildingsDesktopContent,
      AdminModuleId.residents: ResidentsDesktopContent,
      AdminModuleId.billing: BillingDesktopContent,
      AdminModuleId.visitors: VisitorsDesktopContent,
      AdminModuleId.complaints: ComplaintsDesktopContent,
      AdminModuleId.events: EventsDesktopContent,
      AdminModuleId.parking: ParkingDesktopContent,
      AdminModuleId.residentVehicles: VehiclesDesktopContent,
      AdminModuleId.amenities: AmenitiesDesktopContent,
      AdminModuleId.profile: ProfileDesktopContent,
      AdminModuleId.settings: SettingsDesktopContent,
    };

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            for (final entry in expectedTypes.entries) {
              final destination = adminModuleDestinations.firstWhere(
                (candidate) => candidate.id == entry.key,
              );
              expect(destination.builder(context).runtimeType, entry.value);
            }
            return const SizedBox();
          },
        ),
      ),
    );
  });

  testWidgets('desktop presentation scope is explicit and inherited', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AdminDesktopPresentationScope(
          child: Builder(
            builder: (context) => Text(
              AdminDesktopPresentationScope.isActive(context)
                  ? 'desktop'
                  : 'mobile',
            ),
          ),
        ),
      ),
    );

    expect(find.text('desktop'), findsOneWidget);
    expect(find.text('mobile'), findsNothing);
  });

  for (final size in <Size>[
    const Size(800, 708),
    const Size(1126, 708),
    const Size(1200, 840),
    const Size(1680, 1020),
  ]) {
    testWidgets('shared desktop frame lays out at ${size.width.toInt()}px', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: AdminDesktopPageFrame(
            title: 'Module',
            subtitle: 'Desktop module presentation',
            actions: [
              AdminDesktopPrimaryAction(
                label: 'Create',
                icon: Icons.add,
                onPressed: _noop,
              ),
            ],
            child: ColoredBox(color: Colors.white),
          ),
        ),
      );

      expect(find.text('Module'), findsOneWidget);
      expect(find.text('Create'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}

void _noop() {}
