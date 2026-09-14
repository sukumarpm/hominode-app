import 'package:admin_app/navigation/admin_module_destinations.dart';
import 'package:admin_app/navigation/admin_module_routes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'each admin desktop module has a canonical path and roundtrip mapping',
    () {
      for (final module in AdminModuleId.values) {
        final path = adminRoutePathForModule(module);
        expect(path.startsWith('/'), isTrue);
        expect(adminModuleFromRoutePath(path), module);
      }
    },
  );

  test('legacy route aliases map to the intended module', () {
    expect(
      adminModuleFromRoutePath(adminVisitorsLegacyRoute),
      AdminModuleId.visitors,
    );
    expect(
      adminModuleFromRoutePath(adminParkingLegacyRoute),
      AdminModuleId.parking,
    );
    expect(
      adminModuleFromRoutePath(adminResidentVehiclesLegacyRoute),
      AdminModuleId.residentVehicles,
    );
  });
}
