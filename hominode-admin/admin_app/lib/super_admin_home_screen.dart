import 'package:flutter/material.dart';

import 'services/auth_service.dart';
import 'services/public_platform_stats_service.dart';

class SuperAdminHomeScreen extends StatefulWidget {
  const SuperAdminHomeScreen({super.key});

  static const routeName = '/super-admin';
  static const communitiesRouteName = '/super-admin/communities';
  static const adminsRouteName = '/super-admin/admins';
  static const overviewRouteName = '/super-admin/platform-overview';

  @override
  State<SuperAdminHomeScreen> createState() => _SuperAdminHomeScreenState();
}

class _SuperAdminHomeScreenState extends State<SuperAdminHomeScreen> {
  final PublicPlatformStatsService _statsService = PublicPlatformStatsService();

  bool _refreshingStats = false;

  Future<void> _refreshPublicStats() async {
    if (_refreshingStats) return;

    setState(() {
      _refreshingStats = true;
    });

    try {
      final stats = await _statsService.refresh();

      if (!mounted) return;

      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Public statistics refreshed'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StatRow(
                label: 'Active communities',
                value: stats['activeCommunities'],
              ),
              _StatRow(
                label: 'Active residents',
                value: stats['activeResidents'],
              ),
              _StatRow(
                label: 'Active security staff',
                value: stats['activeSecurityStaff'],
              ),
              _StatRow(
                label: 'Visitors processed',
                value: stats['visitorsProcessed'],
              ),
              _StatRow(
                label: 'Resolved complaints',
                value: stats['resolvedComplaints'],
              ),
              _StatRow(
                label: 'Facility bookings',
                value: stats['facilityBookings'],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not refresh public statistics: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _refreshingStats = false;
        });
      }
    }
  }

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
            onTap: () => Navigator.pushNamed(
              context,
              SuperAdminHomeScreen.communitiesRouteName,
            ),
          ),
          _DestinationCard(
            title: 'Admins',
            icon: Icons.admin_panel_settings_outlined,
            onTap: () => Navigator.pushNamed(
              context,
              SuperAdminHomeScreen.adminsRouteName,
            ),
          ),
          _DestinationCard(
            title: 'Platform Overview',
            icon: Icons.dashboard_outlined,
            onTap: () => Navigator.pushNamed(
              context,
              SuperAdminHomeScreen.overviewRouteName,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: _refreshingStats
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : const Icon(Icons.refresh),
              title: const Text('Refresh Public Statistics'),
              subtitle: const Text(
                'Recalculate the public Hominode platform counters.',
              ),
              trailing: const Icon(Icons.chevron_right),
              enabled: !_refreshingStats,
              onTap: _refreshingStats ? null : _refreshPublicStats,
            ),
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

class _StatRow extends StatelessWidget {
  const _StatRow({required this.label, required this.value});

  final String label;
  final Object? value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        Text(
          '${value ?? 0}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ],
    ),
  );
}
