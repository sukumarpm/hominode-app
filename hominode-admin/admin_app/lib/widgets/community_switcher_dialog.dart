import 'package:flutter/material.dart';

import '../services/admin_tenant_context.dart';
import '../services/admin_tenant_session.dart';

class CommunitySwitcherDialog extends StatelessWidget {
  const CommunitySwitcherDialog({super.key});

  static Future<bool> show(BuildContext context) async =>
      await showDialog<bool>(
        context: context,
        builder: (_) => const CommunitySwitcherDialog(),
      ) ??
      false;

  @override
  Widget build(BuildContext context) {
    final tenantContext = AdminTenantContext.instance;
    return AlertDialog(
      title: const Text('Switch Community'),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final tenant in tenantContext.authorizedTenants)
              ListTile(
                leading: CircleAvatar(
                  backgroundImage: tenant.logoUrl == null
                      ? null
                      : NetworkImage(tenant.logoUrl!),
                  child: tenant.logoUrl == null
                      ? const Icon(Icons.apartment)
                      : null,
                ),
                title: Text(tenant.name),
                subtitle: Text(tenant.websitePath),
                trailing: tenant.communityId == tenantContext.communityId
                    ? const Icon(Icons.check_circle)
                    : null,
                onTap: tenant.communityId == tenantContext.communityId
                    ? null
                    : () async {
                        await AdminTenantSession().selectTenant(tenant);
                        if (context.mounted) Navigator.pop(context, true);
                      },
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
