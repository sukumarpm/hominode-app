import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../theme/web_design_system.dart';
import '../widgets/dashboard_components.dart';

class SuperAdminPlatformOverviewPage extends StatelessWidget {
  const SuperAdminPlatformOverviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_PlatformOverview>(
      future: _load(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return const SectionCard(
            title: 'Platform Overview',
            child: EmptyState(
              icon: Icons.error_outline,
              message: 'Unable to load platform registry information.',
            ),
          );
        }

        final data = snapshot.data!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ResponsiveMetricGrid(
              children: [
                DashboardStatCard(
                  label: 'Communities',
                  value: data.communities.toString(),
                  icon: Icons.apartment_outlined,
                  color: const Color(0xFF246BFD),
                ),
                DashboardStatCard(
                  label: 'Active Communities',
                  value: data.activeCommunities.toString(),
                  icon: Icons.verified_outlined,
                  color: const Color(0xFF08A579),
                ),
                DashboardStatCard(
                  label: 'Community Admins',
                  value: data.admins.toString(),
                  icon: Icons.admin_panel_settings_outlined,
                  color: const Color(0xFF7A42D8),
                ),
                DashboardStatCard(
                  label: 'Active Admins',
                  value: data.activeAdmins.toString(),
                  icon: Icons.verified_user_outlined,
                  color: const Color(0xFFE66A2C),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SectionCard(
              title: 'Platform Registry',
              child: Column(
                children: [
                  _OverviewRow(
                    icon: Icons.apartment_outlined,
                    title: 'Communities',
                    value: '${data.communities}',
                  ),
                  const Divider(height: 24),
                  _OverviewRow(
                    icon: Icons.verified_outlined,
                    title: 'Active Communities',
                    value: '${data.activeCommunities}',
                  ),
                  const Divider(height: 24),
                  _OverviewRow(
                    icon: Icons.pause_circle_outline,
                    title: 'Inactive Communities',
                    value: '${data.inactiveCommunities}',
                  ),
                  const Divider(height: 24),
                  _OverviewRow(
                    icon: Icons.admin_panel_settings_outlined,
                    title: 'Community Administrators',
                    value: '${data.admins}',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const SectionCard(
              title: 'Platform Boundary',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Super Admin manages the Hominode platform registry, community configuration, and administrator assignments.',
                    style: TextStyle(color: WebDesign.text, height: 1.5),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Resident, visitor, billing, complaint, amenity and other operational community records remain controlled by the respective community administrators.',
                    style: TextStyle(color: WebDesign.muted, height: 1.5),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Future<_PlatformOverview> _load() async {
    final db = FirebaseFirestore.instance;

    final results = await Future.wait([
      db.collection('communities').get(),

      //
      // Excludes superAdmin.
      //
      db.collection('admins').where('role', isEqualTo: 'admin').get(),
    ]);

    final communities = results[0].docs;
    final admins = results[1].docs;

    return _PlatformOverview(
      communities: communities.length,
      activeCommunities: communities
          .where((doc) => doc.data()['isActive'] == true)
          .length,
      inactiveCommunities: communities
          .where((doc) => doc.data()['isActive'] != true)
          .length,
      admins: admins.length,
      activeAdmins: admins
          .where((doc) => doc.data()['isActive'] == true)
          .length,
    );
  }
}

class _PlatformOverview {
  const _PlatformOverview({
    required this.communities,
    required this.activeCommunities,
    required this.inactiveCommunities,
    required this.admins,
    required this.activeAdmins,
  });

  final int communities;
  final int activeCommunities;
  final int inactiveCommunities;
  final int admins;
  final int activeAdmins;
}

class _OverviewRow extends StatelessWidget {
  const _OverviewRow({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: RolePalette.superAdmin.soft,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: RolePalette.superAdmin.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
      ],
    );
  }
}
