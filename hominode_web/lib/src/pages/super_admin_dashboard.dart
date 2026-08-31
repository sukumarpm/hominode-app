import 'package:flutter/material.dart';

import '../services/dashboard_repository.dart';
import '../theme/web_design_system.dart';
import '../widgets/dashboard_components.dart';

class SuperAdminDashboard extends StatelessWidget {
  const SuperAdminDashboard({super.key, required this.onNavigate});

  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) => FutureBuilder<PlatformMetrics>(
    future: DashboardRepository().platformMetrics(),
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError || !snapshot.hasData) {
        return const SectionCard(
          title: 'Platform overview',
          child: EmptyState(
            icon: Icons.error_outline,
            message: 'Platform registry data is currently unavailable.',
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
                label: 'Societies',
                value: metricValue(data.communities),
                caption: '${data.activeCommunities} active',
                icon: Icons.holiday_village_outlined,
                color: const Color(0xFF246BFD),
              ),
              DashboardStatCard(
                label: 'Buildings',
                value: metricValue(data.buildings),
                caption: 'Tenant-managed data',
                icon: Icons.apartment_outlined,
                color: const Color(0xFF08A579),
              ),
              DashboardStatCard(
                label: 'Residents',
                value: metricValue(data.residents),
                caption: 'Tenant-managed data',
                icon: Icons.people_alt_outlined,
                color: const Color(0xFF7A42D8),
              ),
              DashboardStatCard(
                label: 'Admins',
                value: metricValue(data.admins),
                caption: '${data.activeAdmins} active',
                icon: Icons.admin_panel_settings_outlined,
                color: const Color(0xFFE66A2C),
              ),
              DashboardStatCard(
                label: 'Active complaints',
                value: metricValue(data.activeComplaints),
                caption: 'Tenant-managed data',
                icon: Icons.assignment_late_outlined,
                color: const Color(0xFFE34A5F),
              ),
            ],
          ),
          const SizedBox(height: 14),
          DashboardPanelGrid(
            flexes: const [2, 1],
            children: [
              SectionCard(
                title: 'Platform overview',
                subtitle: 'Current society registry composition',
                action: TextButton(
                  onPressed: () => onNavigate('/super-admin/platform-overview'),
                  child: const Text('View details'),
                ),
                child: CompositionRing(
                  centerValue: data.communities.toString(),
                  centerLabel: 'Societies',
                  slices: [
                    CompositionSlice(
                      'Active societies',
                      data.activeCommunities.toDouble(),
                      RolePalette.superAdmin.primary,
                    ),
                    CompositionSlice(
                      'Inactive societies',
                      data.inactiveCommunities.toDouble(),
                      const Color(0xFFE66A2C),
                    ),
                  ],
                ),
              ),
              SectionCard(
                title: 'System health',
                subtitle: 'Checks supported by existing V1 data',
                child: Column(
                  children: const [
                    _HealthRow(
                      label: 'Platform registry',
                      value: 'Available',
                      healthy: true,
                    ),
                    Divider(height: 20, color: WebDesign.border),
                    _HealthRow(
                      label: 'Tenant operations',
                      value: 'Access isolated',
                      healthy: true,
                    ),
                    Divider(height: 20, color: WebDesign.border),
                    _HealthRow(
                      label: 'Service monitoring',
                      value: 'Not configured',
                      healthy: false,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          DashboardPanelGrid(
            flexes: const [2, 1],
            children: [
              SectionCard(
                title: 'Recent activities',
                subtitle: 'Latest dated registry changes',
                child: DashboardRecordList(
                  records: data.recentActivities,
                  emptyMessage: 'No dated registry activity is available.',
                  color: RolePalette.superAdmin.primary,
                  icon: Icons.history_rounded,
                ),
              ),
              SectionCard(
                title: 'Quick actions',
                child: QuickActionGrid(
                  children: [
                    QuickActionCard(
                      label: 'Societies',
                      icon: Icons.holiday_village_outlined,
                      color: RolePalette.superAdmin.primary,
                      onTap: () => onNavigate('/super-admin/communities'),
                    ),
                    QuickActionCard(
                      label: 'Admins',
                      icon: Icons.admin_panel_settings_outlined,
                      color: const Color(0xFF08A579),
                      onTap: () => onNavigate('/super-admin/admins'),
                    ),
                    QuickActionCard(
                      label: 'Overview',
                      icon: Icons.donut_large_outlined,
                      color: const Color(0xFF7A42D8),
                      onTap: () => onNavigate('/super-admin/platform-overview'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      );
    },
  );
}

class _HealthRow extends StatelessWidget {
  const _HealthRow({
    required this.label,
    required this.value,
    required this.healthy,
  });

  final String label;
  final String value;
  final bool healthy;

  @override
  Widget build(BuildContext context) {
    final color = healthy ? const Color(0xFF08A579) : WebDesign.muted;
    return Row(
      children: [
        Icon(
          healthy ? Icons.check_circle_outline : Icons.info_outline,
          color: color,
          size: 18,
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: WebDesign.text,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(value, style: TextStyle(color: color, fontSize: 10)),
      ],
    );
  }
}
