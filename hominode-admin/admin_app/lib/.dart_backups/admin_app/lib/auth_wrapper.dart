import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'admin_dashboard_page.dart';
import 'admin_login_screen.dart';
import 'services/auth_service.dart';
import 'services/admin_tenant_context.dart';
import 'splash_screen.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});
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
              AdminTenantContext.instance.initialize(
                access.data!.adminProfile!,
              );
              if (!AdminTenantContext.instance.hasSelectedCommunity) {
                return const _CommunitySelectionRequired();
              }
              return const AdminDashboardPage();
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

class _CommunitySelectionRequired extends StatelessWidget {
  const _CommunitySelectionRequired();

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: AdminTenantContext.instance,
    builder: (context, _) {
      final tenant = AdminTenantContext.instance;
      if (tenant.hasSelectedCommunity) return const AdminDashboardPage();
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.apartment, size: 56),
                const SizedBox(height: 16),
                const Text(
                  'Select a community',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Choose a community before operational data is loaded.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                DropdownButton<String>(
                  hint: const Text('Authorized community'),
                  items: tenant.authorizedCommunityIds
                      .map((id) => DropdownMenuItem(value: id, child: Text(id)))
                      .toList(),
                  onChanged: (id) {
                    if (id != null) tenant.selectCommunity(id);
                  },
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => AuthService().signOut(),
                  child: const Text('Back to login'),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _AccessDenied extends StatelessWidget {
  const _AccessDenied({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 56, color: Colors.red),
            const SizedBox(height: 16),
            const Text(
              'Admin access unavailable',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 24),
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
