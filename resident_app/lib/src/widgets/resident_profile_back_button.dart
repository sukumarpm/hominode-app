import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// Returns from Profile to its caller, or restores the authenticated Home route
/// when Profile is the navigator's root page.
class ResidentProfileBackButton extends StatelessWidget {
  const ResidentProfileBackButton({super.key});

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'back'.tr(),
    onPressed: () {
      final navigator = Navigator.of(context);
      if (navigator.canPop()) {
        navigator.pop();
      } else {
        navigator.pushNamedAndRemoveUntil('/home', (_) => false);
      }
    },
    icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF172B4D), size: 20),
    padding: EdgeInsets.zero,
    constraints: const BoxConstraints(minWidth: 40, minHeight: 44),
  );
}
