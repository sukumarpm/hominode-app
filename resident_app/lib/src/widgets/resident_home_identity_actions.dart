import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../screens/emergency_sos_screen.dart';

/// Approved Resident brand mark used in the Home header.
class ResidentHomeLogo extends StatelessWidget {
  const ResidentHomeLogo({super.key});

  @override
  Widget build(BuildContext context) => Image.asset(
    'lib/assets/Resident_New1.png',
    key: const ValueKey('resident-home-logo'),
    width: 50,
    height: 50,
    fit: BoxFit.contain,
    semanticLabel: 'Resident logo',
  );
}

/// Opens the existing emergency interface. Sending an alert remains an
/// explicit action within [EmergencySosScreen].
class ResidentHomeEmergencySosButton extends StatelessWidget {
  const ResidentHomeEmergencySosButton({super.key, this.screenBuilder});

  @visibleForTesting
  final WidgetBuilder? screenBuilder;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white.withValues(alpha: .86),
    borderRadius: BorderRadius.circular(18),
    child: InkWell(
      key: const ValueKey('resident-home-emergency-sos'),
      borderRadius: BorderRadius.circular(18),
      onTap: () => Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: screenBuilder ?? (_) => const EmergencySosScreen(),
        ),
      ),
      child: Container(
        constraints: const BoxConstraints(minHeight: 52),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0x55C63D3D)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF172B4D).withValues(alpha: .06),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.sos_rounded, color: Color(0xFFB42318), size: 23),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'emergency_sos'.tr(),
                softWrap: true,
                style: const TextStyle(
                  color: Color(0xFF7A271A),
                  fontSize: 15,
                  height: 1.2,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: Color(0xFF7A271A),
              size: 15,
            ),
          ],
        ),
      ),
    ),
  );
}
