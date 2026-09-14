import 'package:admin_app/auth_wrapper.dart';
import 'package:admin_app/models/admin_profile.dart';
import 'package:admin_app/models/tenant_config.dart';
import 'package:admin_app/navigation/admin_module_destinations.dart';
import 'package:admin_app/navigation/admin_module_routes.dart';
import 'package:admin_app/services/admin_tenant_context.dart';
import 'package:admin_app/services/admin_tenant_session.dart';
import 'package:admin_app/services/auth_service.dart';
import 'package:admin_app/super_admin_home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemoryTenantStore implements ActiveTenantStore {
  final values = <String, String>{};

  @override
  Future<String?> read(String adminUid) async => values[adminUid];

  @override
  Future<void> remove(String adminUid) async => values.remove(adminUid);

  @override
  Future<void> write(String adminUid, String communityId) async {
    values[adminUid] = communityId;
  }
}

TenantConfig _tenant(String id, {bool active = true}) =>
    TenantConfig.fromMap(id, {
      'name': 'Tenant $id',
      'slug': id.toLowerCase(),
      'websitePath': id.toLowerCase(),
      'isActive': active,
    });

AdminProfile _adminProfile({
  String role = 'admin',
  List<String> communities = const ['A'],
}) => AdminProfile(
  uid: 'admin-1',
  phoneNumber: '+15550000001',
  role: role,
  isActive: true,
  authorizedCommunityIds: communities,
);

Map<String, WidgetBuilder> _guardedRoutes({
  required bool authenticated,
  required AuthResult resolvedAuth,
  required AdminTenantSession Function() sessionFactory,
}) {
  AuthWrapper route(AdminModuleId module) => AuthWrapper(
    requestedModule: module,
    authenticatedOverride: authenticated,
    resolvedAuthOverride: resolvedAuth,
    tenantSessionFactory: sessionFactory,
    legalGateBuilder: (child) => child,
    loginBuilder: (_) =>
        const Scaffold(body: Center(child: Text('Admin Login Screen Mock'))),
    adminDestinationBuilder: (_, requestedModule) =>
        Text('module-${requestedModule?.name ?? AdminModuleId.dashboard.name}'),
  );

  return {
    adminDashboardRoute: (_) => route(AdminModuleId.dashboard),
    adminBuildingsRoute: (_) => route(AdminModuleId.buildings),
    adminBillingRoute: (_) => route(AdminModuleId.billing),
    adminVisitorsRoute: (_) => route(AdminModuleId.visitors),
    adminComplaintsRoute: (_) => route(AdminModuleId.complaints),
    adminEventsRoute: (_) => route(AdminModuleId.events),
    adminParkingRoute: (_) => route(AdminModuleId.parking),
    adminResidentVehiclesRoute: (_) => route(AdminModuleId.residentVehicles),
    adminAmenitiesRoute: (_) => route(AdminModuleId.amenities),
    adminProfileRoute: (_) => route(AdminModuleId.profile),
    adminSettingsRoute: (_) => route(AdminModuleId.settings),
    adminVisitorsLegacyRoute: (_) => route(AdminModuleId.visitors),
    adminParkingLegacyRoute: (_) => route(AdminModuleId.parking),
    adminResidentVehiclesLegacyRoute: (_) =>
        route(AdminModuleId.residentVehicles),
    SuperAdminHomeScreen.routeName: (_) => AuthWrapper(
      superAdminDestination: const Text('super-admin-home'),
      authenticatedOverride: authenticated,
      resolvedAuthOverride: resolvedAuth,
      tenantSessionFactory: sessionFactory,
      legalGateBuilder: (child) => child,
      loginBuilder: (_) =>
          const Scaffold(body: Center(child: Text('Admin Login Screen Mock'))),
      adminDestinationBuilder: (_, requestedModule) => Text(
        'module-${requestedModule?.name ?? AdminModuleId.dashboard.name}',
      ),
    ),
  };
}

Widget _testApp({
  required String initialRoute,
  required Map<String, WidgetBuilder> routes,
}) => ScreenUtilInit(
  designSize: const Size(390, 844),
  minTextAdapt: true,
  splitScreenMode: true,
  builder: (_, __) => MaterialApp(initialRoute: initialRoute, routes: routes),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final tenantContext = AdminTenantContext.instance;

  tearDown(tenantContext.clear);

  testWidgets('signed-out direct module URL resolves to login', (tester) async {
    final store = _MemoryTenantStore();

    final session = AdminTenantSession(
      store: store,
      context: tenantContext,
      tenantLoader: (id) async => _tenant(id),
    );

    await tester.pumpWidget(
      _testApp(
        initialRoute: adminBuildingsRoute,
        routes: _guardedRoutes(
          authenticated: false,
          resolvedAuth: const AuthResult(
            success: false,
            message: 'not-authenticated',
            status: AdminAuthStatus.unauthenticated,
          ),
          sessionFactory: () => session,
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Admin Login Screen Mock'), findsOneWidget);
  });

  testWidgets('signed-in unauthorized admin is denied (fail closed)', (
    tester,
  ) async {
    final store = _MemoryTenantStore();

    final session = AdminTenantSession(
      store: store,
      context: tenantContext,
      tenantLoader: (id) async => _tenant(id),
    );

    await tester.pumpWidget(
      _testApp(
        initialRoute: adminBuildingsRoute,
        routes: _guardedRoutes(
          authenticated: true,
          resolvedAuth: const AuthResult(
            success: false,
            message: 'No communities are assigned to this admin account.',
            status: AdminAuthStatus.noCommunities,
          ),
          sessionFactory: () => session,
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 4));
    expect(find.text('Admin access unavailable'), findsOneWidget);
  });

  testWidgets('authorized admin deep link lands on requested desktop module', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1366, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = _MemoryTenantStore();

    final session = AdminTenantSession(
      store: store,
      context: tenantContext,
      tenantLoader: (id) async => _tenant(id),
    );

    await tester.pumpWidget(
      _testApp(
        initialRoute: adminBuildingsRoute,
        routes: _guardedRoutes(
          authenticated: true,
          resolvedAuth: AuthResult(
            success: true,
            message: 'ok',
            status: AdminAuthStatus.authorized,
            adminProfile: _adminProfile(communities: const ['A']),
          ),
          sessionFactory: () => session,
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 4));
    expect(find.text('module-buildings'), findsOneWidget);
  });

  testWidgets('browser-style route changes preserve selected module', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1366, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = _MemoryTenantStore();

    final session = AdminTenantSession(
      store: store,
      context: tenantContext,
      tenantLoader: (id) async => _tenant(id),
    );

    await tester.pumpWidget(
      _testApp(
        initialRoute: adminDashboardRoute,
        routes: _guardedRoutes(
          authenticated: true,
          resolvedAuth: AuthResult(
            success: true,
            message: 'ok',
            status: AdminAuthStatus.authorized,
            adminProfile: _adminProfile(communities: const ['A']),
          ),
          sessionFactory: () => session,
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 4));
    expect(find.text('module-dashboard'), findsOneWidget);

    final context = tester.element(find.text('module-dashboard'));
    Navigator.of(context).pushNamed(adminBillingRoute);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 4));

    expect(find.text('module-billing'), findsOneWidget);
  });

  testWidgets('ordinary admin cannot open Super Admin route', (tester) async {
    final store = _MemoryTenantStore();

    final session = AdminTenantSession(
      store: store,
      context: tenantContext,
      tenantLoader: (id) async => _tenant(id),
    );

    await tester.pumpWidget(
      _testApp(
        initialRoute: SuperAdminHomeScreen.routeName,
        routes: _guardedRoutes(
          authenticated: true,
          resolvedAuth: AuthResult(
            success: true,
            message: 'ok',
            status: AdminAuthStatus.authorized,
            adminProfile: _adminProfile(
              role: 'admin',
              communities: const ['A'],
            ),
          ),
          sessionFactory: () => session,
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 4));
    expect(find.text('super-admin-home'), findsNothing);
    expect(find.text('module-dashboard'), findsOneWidget);
  });

  testWidgets('tenant selection remains valid after guarded navigation', (
    tester,
  ) async {
    final store = _MemoryTenantStore()..values['admin-1'] = 'B';

    final session = AdminTenantSession(
      store: store,
      context: tenantContext,
      tenantLoader: (id) async {
        if (id == 'A') return _tenant('A');
        if (id == 'B') return _tenant('B');
        throw StateError('missing');
      },
    );

    await tester.pumpWidget(
      _testApp(
        initialRoute: adminDashboardRoute,
        routes: _guardedRoutes(
          authenticated: true,
          resolvedAuth: AuthResult(
            success: true,
            message: 'ok',
            status: AdminAuthStatus.authorized,
            adminProfile: _adminProfile(communities: const ['A', 'B']),
          ),
          sessionFactory: () => session,
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 4));
    expect(tenantContext.requireCommunityId(), 'B');

    final context = tester.element(find.text('module-dashboard'));
    Navigator.of(context).pushNamed(adminBuildingsRoute);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 4));

    expect(tenantContext.requireCommunityId(), 'B');
    expect(find.text('module-buildings'), findsOneWidget);
  });

  testWidgets('direct route refresh still resolves through AuthWrapper guard', (
    tester,
  ) async {
    final store = _MemoryTenantStore();

    final session = AdminTenantSession(
      store: store,
      context: tenantContext,
      tenantLoader: (id) async => _tenant(id),
    );

    await tester.pumpWidget(
      _testApp(
        initialRoute: adminComplaintsRoute,
        routes: _guardedRoutes(
          authenticated: true,
          resolvedAuth: AuthResult(
            success: true,
            message: 'ok',
            status: AdminAuthStatus.authorized,
            adminProfile: _adminProfile(communities: const ['A']),
          ),
          sessionFactory: () => session,
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 4));
    expect(find.text('module-complaints'), findsOneWidget);
  });
}
