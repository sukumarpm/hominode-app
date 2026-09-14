import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hominode_legal/hominode_legal.dart';

import 'admin_dashboard_page.dart';
import 'admin_desktop_shell.dart';
import 'admin_login_screen.dart';
import 'admin_residents_page_firestore.dart';
import 'amenities_management_screen.dart';
import 'billing_screen.dart';
import 'complaint_management_screen.dart';
import 'events_announcements_screen.dart';
import 'manage_buildings_page.dart';
import 'models/admin_profile.dart';
import 'models/tenant_config.dart';
import 'navigation/admin_module_destinations.dart';
import 'parking_management_screen.dart';
import 'profile_screen.dart';
import 'resident_vehicle_management_screen.dart';
import 'services/admin_role_router.dart';
import 'services/admin_tenant_context.dart';
import 'services/admin_tenant_session.dart';
import 'services/auth_service.dart';
import 'settings_screen.dart';
import 'splash_screen.dart';
import 'super_admin_home_screen.dart';
import 'visitor_management_screen.dart';

typedef AdminAuthStreamFactory = Stream<User?> Function(AuthService service);
typedef AdminAuthResolver = Future<AuthResult> Function();
typedef AdminTenantSessionFactory = AdminTenantSession Function();
typedef AdminTenantDestinationBuilder =
    Widget Function(double width, AdminModuleId? requestedModule);
typedef AdminLegalGateBuilder = Widget Function(Widget child);

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({
    this.superAdminDestination,
    this.requestedModule,
    this.authenticatedOverride,
    this.resolvedAuthOverride,
    this.loginBuilder,
    this.authStreamFactory,
    this.authResolver,
    this.tenantSessionFactory,
    this.adminDestinationBuilder,
    this.legalGateBuilder,
    this.authService,
    super.key,
  });

  final Widget? superAdminDestination;
  final AdminModuleId? requestedModule;
  final bool? authenticatedOverride;
  final AuthResult? resolvedAuthOverride;
  final WidgetBuilder? loginBuilder;
  final AdminAuthStreamFactory? authStreamFactory;
  final AdminAuthResolver? authResolver;
  final AdminTenantSessionFactory? tenantSessionFactory;
  final AdminTenantDestinationBuilder? adminDestinationBuilder;
  final AdminLegalGateBuilder? legalGateBuilder;
  final AuthService? authService;

  Widget _withLegalGate(Widget child) {
    if (legalGateBuilder case final builder?) {
      return builder(child);
    }
    return HominodeLegalAcceptanceGate(
      profileCollection: 'admins',
      child: child,
    );
  }

  Widget _buildLogin(BuildContext context) =>
      loginBuilder?.call(context) ?? const AdminLoginScreen();

  Widget _resolvedAccessView(AuthResult? access) {
    if (access?.success == true) {
      final profile = access!.adminProfile!;
      switch (AdminRoleRouter.resolve(profile)) {
        case AdminPostAuthDestination.superAdminHome:
          return _withLegalGate(
            superAdminDestination ?? const SuperAdminHomeScreen(),
          );
        case AdminPostAuthDestination.adminTenantFlow:
          return _withLegalGate(
            _AdminTenantFlow(
              profile: profile,
              requestedModule: requestedModule,
              session: tenantSessionFactory?.call(),
              destinationBuilder: adminDestinationBuilder,
            ),
          );
        case AdminPostAuthDestination.rejected:
          return const _AccessDenied(
            message: 'Admin authorization could not be verified.',
          );
      }
    }
    return _AccessDenied(
      message: access?.message ?? 'Admin authorization could not be verified.',
    );
  }

  Widget _buildPostAuth([AuthService? service]) {
    if (resolvedAuthOverride != null) {
      return _resolvedAccessView(resolvedAuthOverride);
    }
    return FutureBuilder<AuthResult>(
      future:
          authResolver?.call() ??
          (service ?? authService ?? AuthService()).resolveAdminAuthorization(),
      builder: (context, access) {
        if (access.connectionState != ConnectionState.done) {
          return const SplashScreen();
        }
        return _resolvedAccessView(access.data);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (authenticatedOverride != null) {
      if (!authenticatedOverride!) {
        return _buildLogin(context);
      }
      return _buildPostAuth();
    }
    final service = AuthService();
    return StreamBuilder<User?>(
      stream: authStreamFactory?.call(service) ?? service.authStateChanges,
      builder: (context, auth) {
        if (auth.connectionState == ConnectionState.waiting) {
          return const SplashScreen();
        }
        if (auth.data == null) return _buildLogin(context);
        return _buildPostAuth(service);
      },
    );
  }
}

class _AdminTenantFlow extends StatefulWidget {
  const _AdminTenantFlow({
    required this.profile,
    this.requestedModule,
    this.session,
    this.destinationBuilder,
  });

  final AdminProfile profile;
  final AdminModuleId? requestedModule;
  final AdminTenantSession? session;
  final AdminTenantDestinationBuilder? destinationBuilder;

  @override
  State<_AdminTenantFlow> createState() => _AdminTenantFlowState();
}

class _AdminTenantFlowState extends State<_AdminTenantFlow> {
  late final AdminTenantSession _session =
      widget.session ?? AdminTenantSession();
  late final Future<AdminTenantResolution> _resolution = _session.resolve(
    widget.profile,
  );

  @override
  Widget build(BuildContext context) => FutureBuilder<AdminTenantResolution>(
    future: _resolution,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const SplashScreen();
      }
      switch (snapshot.data) {
        case AdminTenantResolution.selected:
          final destinationBuilder =
              widget.destinationBuilder ??
              (double width, AdminModuleId? requestedModule) =>
                  adminTenantDestinationForWidth(
                    width,
                    requestedModule: requestedModule,
                  );
          return LayoutBuilder(
            builder: (context, constraints) => destinationBuilder(
              constraints.maxWidth,
              widget.requestedModule,
            ),
          );
        case AdminTenantResolution.selectionRequired:
          return _CommunitySelectionRequired(session: _session);
        case AdminTenantResolution.noValidTenants:
          return const _AccessDenied(
            message:
                'No active authorized communities are available for this admin account.',
          );
        case null:
          return const _AccessDenied(
            message: 'Authorized communities could not be resolved.',
          );
      }
    },
  );
}

Widget adminTenantDestinationForWidth(
  double width, {
  AdminModuleId? requestedModule,
}) {
  final module = requestedModule ?? AdminModuleId.dashboard;
  if (width < adminDesktopBreakpoint) {
    switch (module) {
      case AdminModuleId.dashboard:
        return const AdminDashboardPage();
      case AdminModuleId.buildings:
        return const ManageBuildingsPage();
      case AdminModuleId.residents:
        return const AdminResidentsPageFirestore();
      case AdminModuleId.billing:
        return const BillingScreen();
      case AdminModuleId.visitors:
        return const VisitorManagementScreen();
      case AdminModuleId.complaints:
        return const ComplaintManagementScreen();
      case AdminModuleId.events:
        return const EventsAnnouncementsScreen();
      case AdminModuleId.parking:
        return const ParkingManagementScreenEnhanced();
      case AdminModuleId.residentVehicles:
        return const ResidentVehicleManagementScreen();
      case AdminModuleId.amenities:
        return const AmenitiesManagementScreen();
      case AdminModuleId.profile:
        return const ProfileScreen();
      case AdminModuleId.settings:
        return const SettingsScreen();
    }
  }
  return AdminDesktopShell(initialModule: module);
}

class _CommunitySelectionRequired extends StatefulWidget {
  const _CommunitySelectionRequired({required this.session});
  final AdminTenantSession session;

  @override
  State<_CommunitySelectionRequired> createState() =>
      _CommunitySelectionRequiredState();
}

class _CommunitySelectionRequiredState
    extends State<_CommunitySelectionRequired> {
  bool _selecting = false;

  Future<void> _select(TenantConfig tenant) async {
    setState(() => _selecting = true);
    await widget.session.selectTenant(tenant);
    if (mounted) {
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil('/dashboard', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tenant = AdminTenantContext.instance;
    return Scaffold(
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.apartment, size: 56.w),
              SizedBox(height: 16.h),
              Text(
                'Select a community',
                style: TextStyle(fontSize: 22.sp, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8.h),
              const Text(
                'Choose a community before operational data is loaded.',
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 24.h),
              for (final option in tenant.authorizedTenants)
                ListTile(
                  leading: CircleAvatar(
                    backgroundImage: option.logoUrl == null
                        ? null
                        : NetworkImage(option.logoUrl!),
                    child: option.logoUrl == null
                        ? const Icon(Icons.apartment)
                        : null,
                  ),
                  title: Text(option.name),
                  subtitle: Text(option.communityId),
                  enabled: !_selecting,
                  onTap: () => _select(option),
                ),
              SizedBox(height: 16.h),
              TextButton(
                onPressed: () => AuthService().signOut(),
                child: const Text('Back to login'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccessDenied extends StatelessWidget {
  const _AccessDenied({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Padding(
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline, size: 56.w, color: Colors.red),
            SizedBox(height: 16.h),
            Text(
              'Admin access unavailable',
              style: TextStyle(fontSize: 22.sp, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8.h),
            Text(message, textAlign: TextAlign.center),
            SizedBox(height: 24.h),
            FilledButton(
              onPressed: () => AuthService().signOut(),
              child: const Text('Back to login'),
            ),
          ],
        ),
      ),
    ),
  );
}
