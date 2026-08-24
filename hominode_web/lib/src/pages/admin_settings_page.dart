import 'package:flutter/material.dart';

import '../session/web_session.dart';
import '../theme/web_design_system.dart';
import '../widgets/dashboard_components.dart';

class AdminSettingsPage extends StatelessWidget {
  const AdminSettingsPage({
    super.key,
    required this.session,
    required this.onNavigate,
  });

  final WebSession session;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    final tenant = session.activeTenant!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SettingsHero(
          communityName: tenant.name,
          brandName: tenant.brandName,
          isActive: tenant.isActive,
        ),

        const SizedBox(height: 16),

        _QuickNavigation(onNavigate: onNavigate),

        const SizedBox(height: 16),

        LayoutBuilder(
          builder: (context, constraints) {
            final community = _CommunitySettingsCard(
              communityId: tenant.communityId,
              communityName: tenant.name,
              brandName: tenant.brandName,
              slug: tenant.slug,
              websitePath: tenant.websitePath,
              databaseId: tenant.databaseId,
              logoUrl: tenant.logoUrl,
              isActive: tenant.isActive,
              onNavigate: onNavigate,
            );

            final admin = _AdminAccessCard(session: session);

            if (constraints.maxWidth >= 900) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 2, child: community),
                  const SizedBox(width: 16),
                  Expanded(child: admin),
                ],
              );
            }

            return Column(
              children: [community, const SizedBox(height: 16), admin],
            );
          },
        ),

        const SizedBox(height: 16),

        _SettingsAreas(onNavigate: onNavigate),

        const SizedBox(height: 16),

        const _SecurityCard(),
      ],
    );
  }
}

//
// ============================================================
// HERO
// ============================================================
//

class _SettingsHero extends StatelessWidget {
  const _SettingsHero({
    required this.communityName,
    required this.brandName,
    required this.isActive,
  });

  final String communityName;
  final String brandName;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final displayBrand = brandName.trim().isEmpty ? communityName : brandName;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: RolePalette.admin.gradient,
        borderRadius: BorderRadius.circular(WebDesign.radius + 2),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 700;

          final title = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white24),
                ),
                child: const Icon(
                  Icons.settings_outlined,
                  color: Colors.white,
                  size: 31,
                ),
              ),
              const SizedBox(width: 14),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Settings',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      displayBrand,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );

          final status = _HeroStatus(active: isActive);

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [title, const SizedBox(height: 14), status],
            );
          }

          return Row(
            children: [
              Expanded(child: title),
              status,
            ],
          );
        },
      ),
    );
  }
}

class _HeroStatus extends StatelessWidget {
  const _HeroStatus({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            active ? Icons.check_circle_outline : Icons.pause_circle_outline,
            size: 15,
            color: Colors.white,
          ),
          const SizedBox(width: 6),
          Text(
            active ? 'Active community' : 'Inactive community',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

//
// ============================================================
// QUICK ACCESS
// ============================================================
//

class _QuickNavigation extends StatelessWidget {
  const _QuickNavigation({required this.onNavigate});

  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Quick Access',
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          QuickActionCard(
            label: 'My Community',
            icon: Icons.apartment_outlined,
            color: RolePalette.admin.primary,
            onTap: () => onNavigate('/admin/community'),
          ),
          QuickActionCard(
            label: 'Buildings',
            icon: Icons.business_outlined,
            color: const Color(0xFF246BFD),
            onTap: () => onNavigate('/admin/buildings'),
          ),
          QuickActionCard(
            label: 'Residents',
            icon: Icons.people_outline,
            color: const Color(0xFF08A579),
            onTap: () => onNavigate('/admin/residents'),
          ),
          QuickActionCard(
            label: 'Events & Notices',
            icon: Icons.campaign_outlined,
            color: const Color(0xFFE66A2C),
            onTap: () => onNavigate('/admin/events'),
          ),
        ],
      ),
    );
  }
}

//
// ============================================================
// COMMUNITY SETTINGS
// ============================================================
//

class _CommunitySettingsCard extends StatelessWidget {
  const _CommunitySettingsCard({
    required this.communityId,
    required this.communityName,
    required this.brandName,
    required this.slug,
    required this.websitePath,
    required this.databaseId,
    required this.logoUrl,
    required this.isActive,
    required this.onNavigate,
  });

  final String communityId;
  final String communityName;
  final String brandName;
  final String slug;
  final String websitePath;
  final String databaseId;
  final String? logoUrl;
  final bool isActive;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Community Configuration',
      action: TextButton.icon(
        onPressed: () => onNavigate('/admin/community'),
        icon: const Icon(Icons.open_in_new, size: 16),
        label: const Text('View Community'),
      ),
      child: Column(
        children: [
          _SettingRow(
            icon: Icons.key_outlined,
            label: 'Community ID',
            value: communityId,
          ),
          const Divider(height: 24),
          _SettingRow(
            icon: Icons.apartment_outlined,
            label: 'Community Name',
            value: communityName,
          ),
          const Divider(height: 24),
          _SettingRow(
            icon: Icons.branding_watermark_outlined,
            label: 'Brand Name',
            value: _display(brandName),
          ),
          const Divider(height: 24),
          _SettingRow(
            icon: Icons.link_outlined,
            label: 'Slug',
            value: _display(slug),
          ),
          const Divider(height: 24),
          _SettingRow(
            icon: Icons.language_outlined,
            label: 'Website Path',
            value: _display(websitePath),
          ),
          const Divider(height: 24),
          _SettingRow(
            icon: Icons.storage_outlined,
            label: 'Database',
            value: _display(databaseId, fallback: '(default)'),
          ),
          const Divider(height: 24),
          _SettingRow(
            icon: Icons.image_outlined,
            label: 'Community Logo',
            value: logoUrl != null && logoUrl!.trim().isNotEmpty
                ? 'Configured'
                : 'Not configured',
          ),
          const Divider(height: 24),
          _SettingRow(
            icon: Icons.verified_outlined,
            label: 'Status',
            value: isActive ? 'Active' : 'Inactive',
            valueColor: isActive
                ? const Color(0xFF087A5B)
                : const Color(0xFFB93C3C),
          ),
        ],
      ),
    );
  }
}

//
// ============================================================
// ADMIN ACCESS
// ============================================================
//

class _AdminAccessCard extends StatelessWidget {
  const _AdminAccessCard({required this.session});

  final WebSession session;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Admin Access',
      child: Column(
        children: [
          _SettingRow(
            icon: Icons.phone_outlined,
            label: 'Signed-in Admin',
            value: session.phoneNumber ?? 'Admin User',
          ),
          const Divider(height: 24),
          const _SettingRow(
            icon: Icons.admin_panel_settings_outlined,
            label: 'Role',
            value: 'Community Admin',
          ),
          const Divider(height: 24),
          _SettingRow(
            icon: Icons.account_tree_outlined,
            label: 'Available Communities',
            value: session.availableTenants.length.toString(),
          ),
          const Divider(height: 24),
          const _SettingRow(
            icon: Icons.security_outlined,
            label: 'Tenant Access',
            value: 'Validated community only',
            valueColor: Color(0xFF087A5B),
          ),
        ],
      ),
    );
  }
}

//
// ============================================================
// SETTINGS AREAS
// ============================================================
//

class _SettingsAreas extends StatelessWidget {
  const _SettingsAreas({required this.onNavigate});

  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Management Areas',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth >= 1000
              ? (constraints.maxWidth - 36) / 4
              : constraints.maxWidth >= 650
              ? (constraints.maxWidth - 12) / 2
              : constraints.maxWidth;

          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _SettingsTile(
                width: width,
                icon: Icons.business_outlined,
                title: 'Buildings',
                description: 'Building and flat configuration',
                onTap: () => onNavigate('/admin/buildings'),
              ),
              _SettingsTile(
                width: width,
                icon: Icons.people_outline,
                title: 'Residents',
                description: 'Resident access and community membership',
                onTap: () => onNavigate('/admin/residents'),
              ),
              _SettingsTile(
                width: width,
                icon: Icons.spa_outlined,
                title: 'Amenities',
                description: 'Amenity availability and booking setup',
                onTap: () => onNavigate('/admin/amenities'),
              ),
              _SettingsTile(
                width: width,
                icon: Icons.receipt_long_outlined,
                title: 'Billing',
                description: 'Bills, payment status and receipts',
                onTap: () => onNavigate('/admin/billing'),
              ),
              _SettingsTile(
                width: width,
                icon: Icons.badge_outlined,
                title: 'Visitors',
                description: 'Visitor and gate activity',
                onTap: () => onNavigate('/admin/visitors'),
              ),
              _SettingsTile(
                width: width,
                icon: Icons.report_problem_outlined,
                title: 'Complaints',
                description: 'Service requests and complaints',
                onTap: () => onNavigate('/admin/complaints'),
              ),
              _SettingsTile(
                width: width,
                icon: Icons.campaign_outlined,
                title: 'Events & Notices',
                description: 'Community communication',
                onTap: () => onNavigate('/admin/events'),
              ),
              _SettingsTile(
                width: width,
                icon: Icons.analytics_outlined,
                title: 'Reports',
                description: 'Community operational summaries',
                onTap: () => onNavigate('/admin/reports'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.width,
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final double width;
  final IconData icon;
  final String title;
  final String description;
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
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: RolePalette.admin.soft,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(icon, color: RolePalette.admin.primary, size: 20),
                ),
                const SizedBox(width: 11),
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
                        description,
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
                  color: WebDesign.muted,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

//
// ============================================================
// SECURITY
// ============================================================
//

class _SecurityCard extends StatelessWidget {
  const _SecurityCard();

  @override
  Widget build(BuildContext context) {
    return const SectionCard(
      title: 'Security & Data Isolation',
      child: Column(
        children: [
          _SecurityRow(
            icon: Icons.lock_outline,
            title: 'Community-scoped access',
            description:
                'Operational data is loaded only for the validated active community.',
          ),
          Divider(height: 24),
          _SecurityRow(
            icon: Icons.link_off_outlined,
            title: 'URL does not grant access',
            description:
                'Community routes and website paths are navigation context only.',
          ),
          Divider(height: 24),
          _SecurityRow(
            icon: Icons.shield_outlined,
            title: 'Protected configuration',
            description:
                'Sensitive community configuration changes are not written directly from this page.',
          ),
        ],
      ),
    );
  }
}

class _SecurityRow extends StatelessWidget {
  const _SecurityRow({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFFE8F8F2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: const Color(0xFF087A5B), size: 20),
        ),
        const SizedBox(width: 12),
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
                description,
                style: const TextStyle(
                  color: WebDesign.muted,
                  fontSize: 10,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

//
// ============================================================
// GENERIC SETTING ROW
// ============================================================
//

class _SettingRow extends StatelessWidget {
  const _SettingRow({
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: RolePalette.admin.soft,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: RolePalette.admin.primary, size: 19),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: WebDesign.muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              SelectableText(
                value,
                style: TextStyle(
                  color: valueColor ?? WebDesign.text,
                  fontSize: 12,
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

String _display(String value, {String fallback = '—'}) {
  final text = value.trim();

  return text.isEmpty ? fallback : text;
}
