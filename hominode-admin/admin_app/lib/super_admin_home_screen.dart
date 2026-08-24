import 'package:flutter/material.dart';

import 'services/auth_service.dart';

class SuperAdminHomeScreen extends StatelessWidget {
  const SuperAdminHomeScreen({super.key});

  static const routeName = '/super-admin';
  static const communitiesRouteName = '/super-admin/communities';
  static const adminsRouteName = '/super-admin/admins';
  static const overviewRouteName = '/super-admin/platform-overview';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hominode Super Admin'),
        actions: [
          IconButton(
            tooltip: 'Logout',
            onPressed: () => AuthService().signOut(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _DestinationCard(
            title: 'Communities',
            icon: Icons.apartment,
            onTap: () => Navigator.pushNamed(context, communitiesRouteName),
          ),
          _DestinationCard(
            title: 'Admins',
            icon: Icons.admin_panel_settings_outlined,
            onTap: () => Navigator.pushNamed(context, adminsRouteName),
          ),
          _DestinationCard(
            title: 'Platform Overview',
            icon: Icons.dashboard_outlined,
            onTap: () => Navigator.pushNamed(context, overviewRouteName),
          ),
        ],
      ),
    );
  }
}

class SuperAdminPlaceholderScreen extends StatelessWidget {
  const SuperAdminPlaceholderScreen({required this.title, super.key});

  final String title;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: Center(child: Text('$title is coming soon.')),
  );
}

class _DestinationCard extends StatelessWidget {
  const _DestinationCard({
    required this.title,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    ),
  );
}
