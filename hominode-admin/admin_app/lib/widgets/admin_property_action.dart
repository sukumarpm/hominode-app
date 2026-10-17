import 'package:flutter/material.dart';

import '../about_hominode_screen.dart';
import '../services/admin_tenant_context.dart';
import 'community_switcher_dialog.dart';

/// Adds an action to the existing property pill without changing its geometry.
class AdminPropertyAction extends StatelessWidget {
  const AdminPropertyAction({super.key, required this.child});

  final Widget child;

  Future<void> _open(BuildContext context) async {
    final canSwitch = AdminTenantContext.instance.authorizedTenants.length > 1;
    if (canSwitch) {
      final action = await showModalBottomSheet<String>(
        context: context,
        builder: (context) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.apartment_outlined),
                title: const Text('Switch Community'),
                onTap: () => Navigator.pop(context, 'switch'),
              ),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('About Hominode'),
                onTap: () => Navigator.pop(context, 'about'),
              ),
            ],
          ),
        ),
      );
      if (!context.mounted || action == null) return;
      if (action == 'switch') {
        if (await CommunitySwitcherDialog.show(context) && context.mounted) {
          Navigator.of(
            context,
          ).pushNamedAndRemoveUntil('/dashboard', (route) => false);
        }
        return;
      }
    }
    if (context.mounted) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const AboutHominodeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Property information and community options',
    child: GestureDetector(onTap: () => _open(context), child: child),
  );
}
