import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/dashboard_repository.dart';
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
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: WebDesign.cardDecoration,
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 19),
            ),
            const Spacer(),
            Flexible(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: WebDesign.text,
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.4,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 9),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: WebDesign.text,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (caption case final text?) ...[
          const SizedBox(height: 2),
          Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: WebDesign.muted, fontSize: 10),
          ),
        ],
      ],
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
          : box.maxWidth >= 320
          ? 2
          : 1;
      return GridView.builder(
        itemCount: children.length,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          mainAxisExtent: 112,
        ),
        itemBuilder: (_, index) => children[index],
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
    this.subtitle,
    this.padding = const EdgeInsets.all(18),
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? action;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: WebDesign.cardDecoration,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: WebDesign.text,
                    ),
                  ),
                  if (subtitle case final text?) ...[
                    const SizedBox(height: 3),
                    Text(
                      text,
                      style: const TextStyle(
                        color: WebDesign.muted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
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

class DashboardPanelGrid extends StatelessWidget {
  const DashboardPanelGrid({
    super.key,
    required this.children,
    this.flexes,
    this.breakpoint = 860,
  });

  final List<Widget> children;
  final List<int>? flexes;
  final double breakpoint;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (_, constraints) {
      if (constraints.maxWidth < breakpoint) {
        return Column(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              children[i],
              if (i != children.length - 1) const SizedBox(height: 14),
            ],
          ],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            Expanded(
              flex: flexes != null && i < flexes!.length ? flexes![i] : 1,
              child: children[i],
            ),
            if (i != children.length - 1) const SizedBox(width: 14),
          ],
        ],
      );
    },
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
      constraints: const BoxConstraints(minHeight: 82),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .075),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: .08)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 21),
          const SizedBox(height: 7),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: WebDesign.text,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    ),
  );
}

class QuickActionGrid extends StatelessWidget {
  const QuickActionGrid({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (_, constraints) {
      final width = constraints.maxWidth;
      final columns = width >= 620
          ? 4
          : width >= 300
          ? 2
          : 1;
      return GridView.builder(
        itemCount: children.length,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          mainAxisExtent: 84,
        ),
        itemBuilder: (_, index) => children[index],
      );
    },
  );
}

class DashboardRecordList extends StatelessWidget {
  const DashboardRecordList({
    super.key,
    required this.records,
    required this.emptyMessage,
    required this.color,
    this.icon = Icons.arrow_right_alt_rounded,
  });

  final List<DashboardRecord>? records;
  final String emptyMessage;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    if (records == null) {
      return const EmptyState(
        icon: Icons.cloud_off_outlined,
        message: 'Data is unavailable for this dashboard.',
      );
    }
    if (records!.isEmpty) return EmptyState(message: emptyMessage, icon: icon);
    return Column(
      children: [
        for (var i = 0; i < records!.length; i++) ...[
          _DashboardRecordRow(record: records![i], color: color, icon: icon),
          if (i != records!.length - 1)
            const Divider(height: 18, color: WebDesign.border),
        ],
      ],
    );
  }
}

class _DashboardRecordRow extends StatelessWidget {
  const _DashboardRecordRow({
    required this.record,
    required this.color,
    required this.icon,
  });

  final DashboardRecord record;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: color.withValues(alpha: .09),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Icon(icon, color: color, size: 17),
      ),
      const SizedBox(width: 11),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              record.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: WebDesign.text,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              record.subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: WebDesign.muted,
                fontSize: 10,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(width: 8),
      Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (record.status case final status?)
            DashboardStatusPill(label: status, color: color),
          if (record.date case final date?) ...[
            const SizedBox(height: 4),
            Text(
              compactDate(date),
              style: const TextStyle(color: WebDesign.muted, fontSize: 9),
            ),
          ],
        ],
      ),
    ],
  );
}

class DashboardStatusPill extends StatelessWidget {
  const DashboardStatusPill({
    super.key,
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(maxWidth: 86),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .09),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      titleCase(label),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w700),
    ),
  );
}

class CompositionSlice {
  const CompositionSlice(this.label, this.value, this.color);

  final String label;
  final double value;
  final Color color;
}

class CompositionRing extends StatelessWidget {
  const CompositionRing({
    super.key,
    required this.slices,
    required this.centerValue,
    required this.centerLabel,
  });

  final List<CompositionSlice> slices;
  final String centerValue;
  final String centerLabel;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (_, constraints) {
      final compact = constraints.maxWidth < 380;
      final ring = SizedBox(
        width: 132,
        height: 132,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: const Size.square(132),
              painter: _CompositionPainter(slices),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  centerValue,
                  style: const TextStyle(
                    color: WebDesign.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  centerLabel,
                  style: const TextStyle(color: WebDesign.muted, fontSize: 9),
                ),
              ],
            ),
          ],
        ),
      );
      final legend = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final slice in slices)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: slice.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      slice.label,
                      style: const TextStyle(
                        color: WebDesign.muted,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  Text(
                    formatCompactNumber(slice.value),
                    style: const TextStyle(
                      color: WebDesign.text,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
        ],
      );
      if (compact) {
        return Column(children: [ring, const SizedBox(height: 12), legend]);
      }
      return Row(
        children: [
          ring,
          const SizedBox(width: 20),
          Expanded(child: legend),
        ],
      );
    },
  );
}

class _CompositionPainter extends CustomPainter {
  const _CompositionPainter(this.slices);

  final List<CompositionSlice> slices;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    final rect = bounds.deflate(9);
    final base = Paint()
      ..color = WebDesign.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12;
    canvas.drawArc(rect, 0, math.pi * 2, false, base);
    final total = slices.fold<double>(0, (sum, slice) => sum + slice.value);
    if (total <= 0) return;
    var start = -math.pi / 2;
    for (final slice in slices.where((slice) => slice.value > 0)) {
      final sweep = math.pi * 2 * (slice.value / total);
      canvas.drawArc(
        rect,
        start,
        sweep,
        false,
        Paint()
          ..color = slice.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 12
          ..strokeCap = StrokeCap.butt,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _CompositionPainter oldDelegate) =>
      oldDelegate.slices != slices;
}

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) => DashboardStatusPill(
    label: active ? 'Active' : 'Inactive',
    color: active ? const Color(0xFF087A55) : const Color(0xFFC43B3B),
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
      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: WebDesign.muted, size: 24),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: WebDesign.muted, fontSize: 11),
          ),
        ],
      ),
    ),
  );
}

String metricValue(num? value) =>
    value == null ? '—' : formatCompactNumber(value);

String moneyValue(double? value) => value == null
    ? '—'
    : '₹${value.toStringAsFixed(value == value.roundToDouble() ? 0 : 2)}';

String formatCompactNumber(num value) {
  final amount = value.toDouble();
  if (amount.abs() >= 10000000) {
    return '${(amount / 10000000).toStringAsFixed(1)}Cr';
  }
  if (amount.abs() >= 100000) {
    return '${(amount / 100000).toStringAsFixed(1)}L';
  }
  if (amount.abs() >= 1000) {
    return '${(amount / 1000).toStringAsFixed(1)}K';
  }
  return amount == amount.roundToDouble()
      ? amount.toInt().toString()
      : amount.toStringAsFixed(1);
}

String compactDate(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[date.month - 1]} ${date.day}';
}

String titleCase(String value) {
  if (value.isEmpty) return value;
  final spaced = value.replaceAll('_', ' ');
  return '${spaced[0].toUpperCase()}${spaced.substring(1)}';
}
