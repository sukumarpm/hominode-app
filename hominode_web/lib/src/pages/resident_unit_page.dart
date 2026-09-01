import 'package:flutter/material.dart';

import '../session/web_session.dart';
import '../theme/web_design_system.dart';
import '../widgets/dashboard_components.dart';
import '../widgets/resident_page_components.dart';

class ResidentUnitPage extends StatelessWidget {
  const ResidentUnitPage({super.key, required this.session});

  final WebSession session;

  @override
  Widget build(BuildContext context) => ResidentPageLayout(
    title: 'My Unit',
    subtitle: 'Your registered apartment information',
    child: SectionCard(
      title: 'Apartment details',
      subtitle: session.activeTenant!.name,
      child: Column(
        children: [
          _UnitDetailRow(
            icon: Icons.holiday_village_outlined,
            label: 'Community',
            value: session.activeTenant!.name,
          ),
          const Divider(height: 24, color: WebDesign.border),
          _UnitDetailRow(
            icon: Icons.apartment_outlined,
            label: 'Building',
            value: _availableValue(session.buildingId),
          ),
          const Divider(height: 24, color: WebDesign.border),
          _UnitDetailRow(
            icon: Icons.door_front_door_outlined,
            label: 'Unit',
            value: _availableValue(session.flatLabel ?? session.flatId),
          ),
          const Divider(height: 24, color: WebDesign.border),
          _UnitDetailRow(
            icon: Icons.person_outline,
            label: 'Resident',
            value: _availableValue(session.displayName),
          ),
        ],
      ),
    ),
  );
}

String _availableValue(String? value) {
  final cleaned = value?.trim();
  return cleaned == null || cleaned.isEmpty ? 'Not available' : cleaned;
}

class _UnitDetailRow extends StatelessWidget {
  const _UnitDetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: RolePalette.resident.soft,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: RolePalette.resident.primary, size: 19),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(color: WebDesign.muted, fontSize: 10),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(
                color: WebDesign.text,
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
