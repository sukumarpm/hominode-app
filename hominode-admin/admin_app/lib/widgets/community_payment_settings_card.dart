import 'package:flutter/material.dart';

import '../models/community_payment_config.dart';
import '../services/community_payment_config_service.dart';

class CommunityPaymentSettingsCard extends StatefulWidget {
  const CommunityPaymentSettingsCard({super.key, this.service});

  final CommunityPaymentConfigService? service;

  @override
  State<CommunityPaymentSettingsCard> createState() =>
      _CommunityPaymentSettingsCardState();
}

class _CommunityPaymentSettingsCardState
    extends State<CommunityPaymentSettingsCard> {
  late final CommunityPaymentConfigService _service;
  late Future<CommunityPaymentConfig> _configFuture;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? CommunityPaymentConfigService();
    _load();
  }

  void _load() {
    _configFuture = _service.getSelectedCommunityPaymentConfig();
  }

  Future<void> _retry() async {
    setState(_load);
  }

  Future<void> _edit(CommunityPaymentConfig? config) async {
    final updated = await showDialog<CommunityPaymentConfig>(
      context: context,
      builder: (context) =>
          _DirectUpiSettingsDialog(service: _service, config: config),
    );
    if (!mounted || updated == null) return;
    setState(() {
      _configFuture = Future.value(updated);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          updated.directUpi.enabled
              ? 'Direct UPI settings saved.'
              : 'Direct UPI disabled.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Card(
    child: FutureBuilder<CommunityPaymentConfig>(
      future: _configFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.all(20),
            child: Center(
              child: SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return ListTile(
            leading: const Icon(Icons.account_balance_wallet_outlined),
            title: const Text('Direct UPI payments'),
            subtitle: const Text('Payment settings could not be loaded.'),
            trailing: TextButton(onPressed: _retry, child: const Text('Retry')),
          );
        }

        final config = snapshot.data!;
        final enabled = config.directUpi.isUsable;
        final configured = config.updatedAt != null;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.account_balance_wallet_outlined),
                title: const Text('Direct UPI payments'),
                subtitle: Text(
                  enabled
                      ? 'Enabled'
                      : configured
                      ? 'Disabled'
                      : 'Not configured',
                ),
                trailing: OutlinedButton(
                  onPressed: () => _edit(config),
                  child: Text(enabled ? 'Edit' : 'Configure'),
                ),
              ),
              if (enabled)
                Padding(
                  padding: const EdgeInsets.fromLTRB(72, 0, 16, 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: 24,
                      runSpacing: 8,
                      children: [
                        _Detail(
                          label: 'Payee name',
                          value: config.directUpi.payeeName!,
                        ),
                        _Detail(
                          label: 'UPI ID (VPA)',
                          value: config.directUpi.vpa!,
                        ),
                      ],
                    ),
                  ),
                ),
              if (!enabled)
                const Padding(
                  padding: EdgeInsets.fromLTRB(72, 0, 16, 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Residents cannot use Direct UPI until it is configured.',
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    ),
  );
}

class _Detail extends StatelessWidget {
  const _Detail({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: Theme.of(context).textTheme.labelMedium),
      Text(value),
    ],
  );
}

class _DirectUpiSettingsDialog extends StatefulWidget {
  const _DirectUpiSettingsDialog({required this.service, required this.config});

  final CommunityPaymentConfigService service;
  final CommunityPaymentConfig? config;

  @override
  State<_DirectUpiSettingsDialog> createState() =>
      _DirectUpiSettingsDialogState();
}

class _DirectUpiSettingsDialogState extends State<_DirectUpiSettingsDialog> {
  late bool _enabled;
  late final bool _wasEnabled;
  late final TextEditingController _vpaController;
  late final TextEditingController _payeeController;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final directUpi = widget.config?.directUpi;
    _enabled = directUpi?.isUsable ?? false;
    _wasEnabled = _enabled;
    _vpaController = TextEditingController(
      text: _enabled ? directUpi!.vpa : '',
    );
    _payeeController = TextEditingController(
      text: _enabled ? directUpi!.payeeName : '',
    );
  }

  @override
  void dispose() {
    _vpaController.dispose();
    _payeeController.dispose();
    super.dispose();
  }

  Future<void> _setEnabled(bool value) async {
    if (!value && _wasEnabled && _enabled) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Disable Direct UPI?'),
          content: const Text(
            'Disabling Direct UPI will prevent residents from using this payment destination for new direct UPI payments.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Disable'),
            ),
          ],
        ),
      );
      if (!mounted || confirmed != true) return;
    }
    setState(() {
      _enabled = value;
      _error = null;
    });
  }

  Future<void> _save() async {
    final vpa = _vpaController.text.trim();
    final payeeName = _payeeController.text.trim();
    if (_enabled && (vpa.isEmpty || payeeName.isEmpty)) {
      setState(() {
        _error = vpa.isEmpty ? 'Enter a UPI ID (VPA).' : 'Enter a payee name.';
      });
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final config = _enabled
          ? await widget.service.updateDirectUpi(
              enabled: true,
              vpa: vpa,
              payeeName: payeeName,
            )
          : await widget.service.updateDirectUpi(enabled: false);
      if (mounted) Navigator.pop(context, config);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Could not save payment settings. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Direct UPI payment settings'),
    content: SingleChildScrollView(
      child: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Enable Direct UPI'),
              value: _enabled,
              onChanged: _saving ? null : _setEnabled,
            ),
            if (_enabled) ...[
              TextField(
                controller: _vpaController,
                enabled: !_saving,
                decoration: const InputDecoration(labelText: 'UPI ID (VPA)'),
              ),
              TextField(
                controller: _payeeController,
                enabled: !_saving,
                decoration: const InputDecoration(labelText: 'Payee name'),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _saving ? null : () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _saving ? null : _save,
        child: _saving
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('Save'),
      ),
    ],
  );
}
