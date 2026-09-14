import 'package:flutter/material.dart';

import '../services/dashboard_repository.dart';
import '../session/web_session.dart';
import '../theme/web_design_system.dart';
import '../widgets/dashboard_components.dart';

/// Admin "My Community" page.
///
/// Security:
/// - Uses only the already validated active tenant from [WebSession].
/// - Any backend metric request is scoped by activeTenant.communityId.
/// - Does not accept a communityId from route/query parameters.
class AdminMyCommunityPage extends StatelessWidget {
  const AdminMyCommunityPage({
    super.key,
    required this.session,
    required this.onNavigate,
  });

  final WebSession session;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    final tenant = session.activeTenant!;

    return FutureBuilder<DashboardMetrics>(
      future: DashboardRepository().adminMetrics(tenant.communityId),
      builder: (context, snapshot) {
        final metrics = snapshot.data;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CommunityHero(session: session),
            const SizedBox(height: 16),

            ResponsiveMetricGrid(
              children: [
                DashboardStatCard(
                  label: 'Residents',
                  value: _metric(metrics?['residents']),
                  icon: Icons.people_outline,
                  color: const Color(0xFF246BFD),
                ),
                DashboardStatCard(
                  label: 'Buildings',
                  value: _metric(metrics?['buildings']),
                  icon: Icons.apartment_outlined,
                  color: RolePalette.admin.primary,
                ),
                DashboardStatCard(
                  label: 'Visitors',
                  value: _metric(metrics?['visitors']),
                  icon: Icons.badge_outlined,
                  color: const Color(0xFF7A42D8),
                ),
                DashboardStatCard(
                  label: 'Complaints',
                  value: _metric(metrics?['complaints']),
                  icon: Icons.report_problem_outlined,
                  color: const Color(0xFFE34A5F),
                ),
              ],
            ),

            const SizedBox(height: 16),

            LayoutBuilder(
              builder: (context, constraints) {
                final details = _CommunityDetails(session: session);
                final status = _CommunityStatus(session: session);

                if (constraints.maxWidth >= 900) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 2, child: details),
                      const SizedBox(width: 16),
                      Expanded(child: status),
                    ],
                  );
                }

                return Column(
                  children: [details, const SizedBox(height: 16), status],
                );
              },
            ),

            const SizedBox(height: 16),

            SectionCard(
              title: 'Community Management',
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final tileWidth = constraints.maxWidth >= 1000
                      ? (constraints.maxWidth - 36) / 4
                      : constraints.maxWidth >= 650
                      ? (constraints.maxWidth - 12) / 2
                      : constraints.maxWidth;

                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _NavigationTile(
                        width: tileWidth,
                        icon: Icons.business_outlined,
                        title: 'Buildings',
                        subtitle: 'Manage buildings and flats',
                        onTap: () => onNavigate('/admin/buildings'),
                      ),
                      _NavigationTile(
                        width: tileWidth,
                        icon: Icons.people_outline,
                        title: 'Residents',
                        subtitle: 'View and manage residents',
                        onTap: () => onNavigate('/admin/residents'),
                      ),
                      _NavigationTile(
                        width: tileWidth,
                        icon: Icons.campaign_outlined,
                        title: 'Events & Notices',
                        subtitle: 'Share community updates',
                        onTap: () => onNavigate('/admin/events'),
                      ),
                      _NavigationTile(
                        width: tileWidth,
                        icon: Icons.settings_outlined,
                        title: 'Settings',
                        subtitle: 'Community-level preferences',
                        onTap: () => onNavigate('/admin/settings'),
                      ),
                    ],
                  );
                },
              ),
            ),

            const SizedBox(height: 16),

            SectionCard(
              title: 'Quick Access',
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  QuickActionCard(
                    label: 'Visitors',
                    icon: Icons.badge_outlined,
                    color: const Color(0xFF7A42D8),
                    onTap: () => onNavigate('/admin/visitors'),
                  ),
                  QuickActionCard(
                    label: 'Complaints',
                    icon: Icons.report_problem_outlined,
                    color: const Color(0xFFE34A5F),
                    onTap: () => onNavigate('/admin/complaints'),
                  ),
                  QuickActionCard(
                    label: 'Billing',
                    icon: Icons.receipt_long_outlined,
                    color: const Color(0xFF08A579),
                    onTap: () => onNavigate('/admin/billing'),
                  ),
                  QuickActionCard(
                    label: 'Reports',
                    icon: Icons.analytics_outlined,
                    color: const Color(0xFFE66A2C),
                    onTap: () => onNavigate('/admin/reports'),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  String _metric(int? value) => value?.toString() ?? '—';
}

class _CommunityHero extends StatelessWidget {
  const _CommunityHero({required this.session});

  final WebSession session;

  @override
  Widget build(BuildContext context) {
    final tenant = session.activeTenant!;
    final brand = _nonEmpty(tenant.brandName) ?? tenant.name;
    final website = _nonEmpty(tenant.websitePath);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: WebDesign.adminPageHeader,
      child: Wrap(
        spacing: 18,
        runSpacing: 14,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _CommunityLogo(logoUrl: tenant.logoUrl),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 650),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  brand,
                  style: const TextStyle(
                    color: WebDesign.text,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  tenant.name,
                  style: const TextStyle(color: WebDesign.muted, fontSize: 13),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _HeroPill(
                      icon: Icons.language_outlined,
                      label: website ?? 'Website path not configured',
                    ),
                    _HeroPill(
                      icon: tenant.isActive
                          ? Icons.check_circle_outline
                          : Icons.pause_circle_outline,
                      label: tenant.isActive
                          ? 'Active community'
                          : 'Inactive community',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CommunityDetails extends StatelessWidget {
  const _CommunityDetails({required this.session});

  final WebSession session;

  @override
  Widget build(BuildContext context) {
    final tenant = session.activeTenant!;

    final rows = <(String, String)>[
      ('Community ID', tenant.communityId),
      ('Community Name', tenant.name),
      ('Brand Name', _nonEmpty(tenant.brandName) ?? tenant.name),
      ('Slug', _nonEmpty(tenant.slug) ?? '—'),
      ('Website Path', _nonEmpty(tenant.websitePath) ?? '—'),
      ('Database', _nonEmpty(tenant.databaseId) ?? '(default)'),
    ];

    return SectionCard(
      title: 'Community Details',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 620 ? 2 : 1;
          final width = columns == 2
              ? (constraints.maxWidth - 12) / 2
              : constraints.maxWidth;

          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final row in rows)
                SizedBox(
                  width: width,
                  child: _DetailTile(label: row.$1, value: row.$2),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _CommunityStatus extends StatelessWidget {
  const _CommunityStatus({required this.session});

  final WebSession session;

  @override
  Widget build(BuildContext context) {
    final tenant = session.activeTenant!;

    return SectionCard(
      title: 'Access & Status',
      child: Column(
        children: [
          _InfoRow(
            icon: Icons.verified_user_outlined,
            label: 'Community Status',
            value: tenant.isActive ? 'Active' : 'Inactive',
            valueColor: tenant.isActive
                ? const Color(0xFF087A5B)
                : const Color(0xFFB93C3C),
          ),
          const Divider(height: 24),
          const _InfoRow(
            icon: Icons.admin_panel_settings_outlined,
            label: 'Your Access',
            value: 'Community Admin',
          ),
          const Divider(height: 24),
          const _InfoRow(
            icon: Icons.security_outlined,
            label: 'Tenant Isolation',
            value: 'Community scoped',
          ),
        ],
      ),
    );
  }
}

class _CommunityLogo extends StatelessWidget {
  const _CommunityLogo({required this.logoUrl});

  final String? logoUrl;

  @override
  Widget build(BuildContext context) {
    final url = _nonEmpty(logoUrl);

    return Container(
      width: 82,
      height: 82,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white24),
      ),
      child: url == null
          ? const Icon(Icons.apartment_rounded, color: Colors.white, size: 42)
          : Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const Icon(
                Icons.apartment_rounded,
                color: Colors.white,
                size: 42,
              ),
            ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  const _HeroPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: RolePalette.admin.soft,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: WebDesign.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: WebDesign.text),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: WebDesign.text,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailTile extends StatelessWidget {
  const _DetailTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: WebDesign.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: WebDesign.muted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 5),
          SelectableText(
            value,
            style: const TextStyle(
              color: WebDesign.text,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: RolePalette.admin.soft,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 19, color: RolePalette.admin.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(color: WebDesign.muted, fontSize: 11),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  color: valueColor ?? WebDesign.text,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NavigationTile extends StatelessWidget {
  const _NavigationTile({
    required this.width,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final double width;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: WebDesign.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: RolePalette.admin.soft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: RolePalette.admin.primary, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: WebDesign.text,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: WebDesign.muted,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: WebDesign.muted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String? _nonEmpty(String? value) {
  final text = value?.trim();
  return (text == null || text.isEmpty) ? null : text;
}
