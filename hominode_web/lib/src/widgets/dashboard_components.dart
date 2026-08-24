import 'package:flutter/material.dart';

import '../theme/web_design_system.dart';

class DashboardStatCard extends StatelessWidget {
  const DashboardStatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.caption,
  });
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? caption;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(WebDesign.radius),
      border: Border.all(color: WebDesign.border),
      boxShadow: const [WebDesign.shadow],
    ),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(color: WebDesign.muted, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: WebDesign.text,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (caption != null)
                  Text(
                    caption!,
                    style: const TextStyle(
                      color: WebDesign.muted,
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class ResponsiveMetricGrid extends StatelessWidget {
  const ResponsiveMetricGrid({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (_, box) {
      final columns = box.maxWidth >= 1180
          ? 5
          : box.maxWidth >= 760
          ? 3
          : 2;
      return GridView.count(
        crossAxisCount: columns,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: box.maxWidth < 460 ? 1.15 : 1.75,
        children: children,
      );
    },
  );
}

class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    required this.child,
    this.action,
  });
  final String title;
  final Widget child;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(WebDesign.radius),
      border: Border.all(color: WebDesign.border),
      boxShadow: const [WebDesign.shadow],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: WebDesign.text,
                ),
              ),
            ),
            ?action,
          ],
        ),
        const SizedBox(height: 16),
        child,
      ],
    ),
  );
}

class QuickActionCard extends StatelessWidget {
  const QuickActionCard({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    this.onTap,
  });
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Container(
      width: 120,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    ),
  );
}

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.active});
  final bool active;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: active ? const Color(0xFFE7F8F1) : const Color(0xFFFFEEEE),
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(
      active ? 'Active' : 'Inactive',
      style: TextStyle(
        color: active ? const Color(0xFF087A55) : const Color(0xFFC43B3B),
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.message,
    this.icon = Icons.hourglass_empty,
  });
  final String message;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: WebDesign.muted),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: WebDesign.muted),
          ),
        ],
      ),
    ),
  );
}
