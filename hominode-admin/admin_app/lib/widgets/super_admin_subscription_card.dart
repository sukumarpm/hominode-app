import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../services/subscription_service.dart';

class SuperAdminSubscriptionCard extends StatefulWidget {
  const SuperAdminSubscriptionCard({required this.communityId, super.key});

  final String communityId;

  @override
  State<SuperAdminSubscriptionCard> createState() =>
      _SuperAdminSubscriptionCardState();
}

class _SuperAdminSubscriptionCardState
    extends State<SuperAdminSubscriptionCard> {
  final SubscriptionService _service = SubscriptionService();

  late Future<CommunitySubscription?> _subscription = _load();
  bool _busy = false;

  static const Map<String, String> _plans = {
    'essential': 'Hominode Essential',
    'plus': 'Hominode Plus',
    'pro': 'Hominode Pro',
  };

  static const List<String> _statuses = [
    'trial',
    'active',
    'grace',
    'expired',
    'suspended',
    'cancelled',
  ];

  Future<CommunitySubscription?> _load() =>
      _service.getSubscription(widget.communityId);

  void _refresh() {
    setState(() {
      _subscription = _load();
    });
  }

  String _date(int? milliseconds) {
    if (milliseconds == null) return 'No fixed end date';

    final date = DateTime.fromMillisecondsSinceEpoch(milliseconds).toLocal();

    String two(int value) => value.toString().padLeft(2, '0');

    return '${date.year}-${two(date.month)}-${two(date.day)}';
  }

  String _friendlyStatus(String value) {
    if (value.isEmpty) return 'Unknown';

    return value
        .split('_')
        .map(
          (part) => part.isEmpty
              ? part
              : '${part[0].toUpperCase()}${part.substring(1)}',
        )
        .join(' ');
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;

    setState(() => _busy = true);

    try {
      await action();

      if (!mounted) return;

      _refresh();

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Subscription updated.')));
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message ?? 'Subscription operation failed.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Subscription operation failed: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<DateTime?> _pickEndDate({DateTime? initialDate}) {
    final now = DateTime.now();

    final firstDate = DateTime(
      now.year,
      now.month,
      now.day,
    ).add(const Duration(days: 1));

    final initial = initialDate != null && initialDate.isAfter(firstDate)
        ? initialDate
        : firstDate;

    return showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: firstDate,
      lastDate: DateTime(now.year + 10),
    );
  }

  int _endOfDayMillis(DateTime date) {
    return DateTime(
      date.year,
      date.month,
      date.day,
      23,
      59,
      59,
      999,
    ).millisecondsSinceEpoch;
  }

  Future<void> _create() async {
    String planId = 'essential';
    String status = 'active';
    DateTime? endDate;
    final notes = TextEditingController();

    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final requiresEnd = status == 'trial' || status == 'grace';

          return AlertDialog(
            title: const Text('Create subscription'),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: planId,
                    decoration: const InputDecoration(labelText: 'Plan'),
                    items: _plans.entries
                        .map(
                          (entry) => DropdownMenuItem(
                            value: entry.key,
                            child: Text(entry.value),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => planId = value);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: status,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items: _statuses
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(_friendlyStatus(value)),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => status = value);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      endDate == null
                          ? 'No end date'
                          : 'Ends ${_date(_endOfDayMillis(endDate!))}',
                    ),
                    subtitle: requiresEnd
                        ? const Text('Required for Trial and Grace status.')
                        : null,
                    trailing: const Icon(Icons.calendar_month),
                    onTap: () async {
                      final picked = await _pickEndDate(initialDate: endDate);
                      if (picked != null) {
                        setDialogState(() => endDate = picked);
                      }
                    },
                  ),
                  TextField(
                    controller: notes,
                    maxLength: 500,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Notes (optional)',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: requiresEnd && endDate == null
                    ? null
                    : () => Navigator.pop(dialogContext, true),
                child: const Text('Create'),
              ),
            ],
          );
        },
      ),
    );

    if (submitted != true) {
      notes.dispose();
      return;
    }

    final noteText = notes.text;
    notes.dispose();

    await _run(
      () => _service.createSubscription(
        communityId: widget.communityId,
        planId: planId,
        status: status,
        endsAtMs: endDate == null ? null : _endOfDayMillis(endDate!),
        notes: noteText,
      ),
    );
  }

  Future<void> _changePlan(CommunitySubscription subscription) async {
    String planId = subscription.planId;
    final notes = TextEditingController();

    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Change subscription plan'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              StatefulBuilder(
                builder: (context, setDialogState) =>
                    DropdownButtonFormField<String>(
                      initialValue: planId,
                      decoration: const InputDecoration(labelText: 'Plan'),
                      items: _plans.entries
                          .map(
                            (entry) => DropdownMenuItem(
                              value: entry.key,
                              child: Text(entry.value),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => planId = value);
                        }
                      },
                    ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notes,
                maxLength: 500,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Reason / notes (optional)',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Change plan'),
          ),
        ],
      ),
    );

    if (submitted != true) {
      notes.dispose();
      return;
    }

    final noteText = notes.text;
    notes.dispose();

    await _run(
      () => _service.changePlan(
        communityId: widget.communityId,
        planId: planId,
        notes: noteText,
      ),
    );
  }

  Future<void> _changeStatus(CommunitySubscription subscription) async {
    String status = subscription.status;
    final notes = TextEditingController();

    final allowedStatuses = subscription.endsAtMs == null
        ? _statuses
              .where((value) => value != 'trial' && value != 'grace')
              .toList()
        : _statuses;

    if (!allowedStatuses.contains(status)) {
      status = 'active';
    }

    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Change subscription status'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              StatefulBuilder(
                builder: (context, setDialogState) =>
                    DropdownButtonFormField<String>(
                      initialValue: status,
                      decoration: const InputDecoration(labelText: 'Status'),
                      items: allowedStatuses
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(_friendlyStatus(value)),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => status = value);
                        }
                      },
                    ),
              ),
              if (subscription.endsAtMs == null)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text('Trial and Grace require an end date.'),
                ),
              const SizedBox(height: 12),
              TextField(
                controller: notes,
                maxLength: 500,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Reason / notes (optional)',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Update status'),
          ),
        ],
      ),
    );

    if (submitted != true) {
      notes.dispose();
      return;
    }

    final noteText = notes.text;
    notes.dispose();

    await _run(
      () => _service.setStatus(
        communityId: widget.communityId,
        status: status,
        notes: noteText,
      ),
    );
  }

  Future<void> _extend(CommunitySubscription subscription) async {
    DateTime? initial;

    if (subscription.endsAtMs != null) {
      initial = DateTime.fromMillisecondsSinceEpoch(
        subscription.endsAtMs!,
      ).toLocal().add(const Duration(days: 30));
    }

    final selected = await _pickEndDate(initialDate: initial);

    if (selected == null) return;

    final notes = TextEditingController();

    if (!mounted) {
      notes.dispose();
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          subscription.endsAtMs == null
              ? 'Set subscription end date'
              : 'Extend subscription',
        ),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('New end date: ${_date(_endOfDayMillis(selected))}'),
              const SizedBox(height: 12),
              TextField(
                controller: notes,
                maxLength: 500,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Reason / notes (optional)',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      notes.dispose();
      return;
    }

    final noteText = notes.text;
    notes.dispose();

    await _run(
      () => _service.extendSubscription(
        communityId: widget.communityId,
        endsAtMs: _endOfDayMillis(selected),
        notes: noteText,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<CommunitySubscription?>(
      future: _subscription,
      builder: (context, snapshot) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: snapshot.connectionState != ConnectionState.done
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(),
                    ),
                  )
                : snapshot.hasError
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Subscription',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text('Unable to load subscription: ${snapshot.error}'),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _refresh,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  )
                : _buildContent(context, snapshot.data),
          ),
        );
      },
    );
  }

  Widget _buildContent(
    BuildContext context,
    CommunitySubscription? subscription,
  ) {
    if (subscription == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Subscription', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          const Text('This community does not have a subscription yet.'),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _busy ? null : _create,
            icon: const Icon(Icons.add_card),
            label: const Text('Create subscription'),
          ),
        ],
      );
    }

    final maxBankAccounts = subscription.limits['maxCommunityBankAccounts'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Subscription',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Chip(label: Text(_friendlyStatus(subscription.status))),
          ],
        ),
        const SizedBox(height: 12),
        _Row(
          label: 'Plan',
          value: subscription.planName.isEmpty
              ? subscription.planId
              : subscription.planName,
        ),
        _Row(
          label: 'Started',
          value: subscription.startsAtMs == null
              ? '—'
              : _date(subscription.startsAtMs),
        ),
        _Row(label: 'Ends', value: _date(subscription.endsAtMs)),
        _Row(
          label: 'Bank accounts',
          value: maxBankAccounts == null
              ? 'Plan-defined / unrestricted in V1'
              : 'Maximum $maxBankAccounts',
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: _busy ? null : () => _changePlan(subscription),
              icon: const Icon(Icons.workspace_premium_outlined),
              label: const Text('Change plan'),
            ),
            OutlinedButton.icon(
              onPressed: _busy ? null : () => _changeStatus(subscription),
              icon: const Icon(Icons.toggle_on_outlined),
              label: const Text('Change status'),
            ),
            OutlinedButton.icon(
              onPressed: _busy ? null : () => _extend(subscription),
              icon: const Icon(Icons.event_repeat),
              label: Text(
                subscription.endsAtMs == null ? 'Set end date' : 'Extend',
              ),
            ),
            IconButton(
              tooltip: 'Refresh subscription',
              onPressed: _busy ? null : _refresh,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        if (_busy)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: LinearProgressIndicator(),
          ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
