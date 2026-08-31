import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hominode_legal/hominode_legal.dart';
import 'admin_dashboard_page.dart';
import 'admin_login_screen.dart';
import 'models/admin_profile.dart';
import 'models/tenant_config.dart';
import 'services/auth_service.dart';
import 'services/admin_tenant_context.dart';
import 'services/admin_role_router.dart';
import 'services/admin_tenant_session.dart';
import 'splash_screen.dart';
import 'super_admin_home_screen.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({this.superAdminDestination, super.key});

  final Widget? superAdminDestination;
  @override
  Widget build(BuildContext context) {
    final service = AuthService();
    return StreamBuilder<User?>(
      stream: service.authStateChanges,
      builder: (context, auth) {
        if (auth.connectionState == ConnectionState.waiting) {
          return const SplashScreen();
        }
        if (auth.data == null) return const AdminLoginScreen();
        return FutureBuilder<AuthResult>(
          future: service.resolveAdminAuthorization(),
          builder: (context, access) {
            if (access.connectionState != ConnectionState.done) {
              return const SplashScreen();
            }
            if (access.data?.success == true) {
              final profile = access.data!.adminProfile!;
              switch (AdminRoleRouter.resolve(profile)) {
                case AdminPostAuthDestination.superAdminHome:
                  return HominodeLegalAcceptanceGate(
                    profileCollection: 'admins',
                    child:
                        superAdminDestination ?? const SuperAdminHomeScreen(),
                  );
                case AdminPostAuthDestination.adminTenantFlow:
                  return HominodeLegalAcceptanceGate(
                    profileCollection: 'admins',
                    child: _AdminTenantFlow(profile: profile),
                  );
                case AdminPostAuthDestination.rejected:
                  return const _AccessDenied(
                    message: 'Admin authorization could not be verified.',
                  );
              }
            }
            return _AccessDenied(
              message:
                  access.data?.message ??
                  'Admin authorization could not be verified.',
            );
          },
        );
      },
    );
  }
}

class _AdminTenantFlow extends StatefulWidget {
  const _AdminTenantFlow({required this.profile});
  final AdminProfile profile;
  @override
  State<_AdminTenantFlow> createState() => _AdminTenantFlowState();
}

class _AdminTenantFlowState extends State<_AdminTenantFlow> {
  final _session = AdminTenantSession();
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
          return const AdminDashboardPage();
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
