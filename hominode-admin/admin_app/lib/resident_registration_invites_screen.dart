import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import 'models/community_invite.dart';
import 'services/community_invite_service.dart';

class ResidentRegistrationInvitesScreen extends StatefulWidget {
  const ResidentRegistrationInvitesScreen({super.key});

  @override
  State<ResidentRegistrationInvitesScreen> createState() =>
      _ResidentRegistrationInvitesScreenState();
}

class _ResidentRegistrationInvitesScreenState
    extends State<ResidentRegistrationInvitesScreen> {
  final CommunityInviteService _service = CommunityInviteService();
  late Future<List<CommunityInvite>> _invitesFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _invitesFuture = _service.watchInvites().first.timeout(
      const Duration(seconds: 20),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Resident Registration Invites')),
    body: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(child: Text('Resident registration codes')),
              FilledButton.icon(
                onPressed: _createInvite,
                icon: const Icon(Icons.add),
                label: const Text('Create'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: FutureBuilder<List<CommunityInvite>>(
              future: _invitesFuture,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Unable to load registration invites.'),
                        const SizedBox(height: 8),
                        Text('${snapshot.error}', textAlign: TextAlign.center),
                        TextButton.icon(
                          onPressed: () => setState(_reload),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final invites = snapshot.data!;
                if (invites.isEmpty) {
                  return const Center(
                    child: Text('No resident invites created'),
                  );
                }

                return ListView(children: invites.map(_inviteCard).toList());
              },
            ),
          ),
        ],
      ),
    ),
  );

  Widget _inviteCard(CommunityInvite invite) {
    final usable = invite.isActive && !invite.isExpired && !invite.isExhausted;
    return Card(
      margin: EdgeInsets.only(bottom: 10.h),
      child: ListTile(
        title: SelectableText(
          invite.code,
          style: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1),
        ),
        subtitle: Text(
          [
            usable
                ? 'Active'
                : invite.isActive
                ? (invite.isExpired ? 'Expired' : 'Usage limit reached')
                : 'Revoked',
            if (invite.expiresAt != null)
              'Expires ${DateFormat.yMMMd().format(invite.expiresAt!)}',
            if (invite.maxUses != null)
              '${invite.useCount}/${invite.maxUses} uses',
          ].join(' • '),
        ),
        trailing: Wrap(
          spacing: 2,
          children: [
            IconButton(
              tooltip: 'Copy',
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: invite.code));
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Invite code copied')),
                  );
                }
              },
              icon: const Icon(Icons.copy_outlined),
            ),
            IconButton(
              tooltip: 'Share',
              onPressed: () => Share.share(
                'Hominode resident registration code: ${invite.code}',
              ),
              icon: const Icon(Icons.share_outlined),
            ),
            if (invite.isActive)
              IconButton(
                tooltip: 'Revoke',
                onPressed: () => _revoke(invite),
                icon: const Icon(Icons.block, color: Colors.red),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _createInvite() async {
    DateTime? expiry;
    final uses = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create resident invite'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: uses,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Maximum uses (optional)',
                ),
              ),
              SizedBox(height: 12.h),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  expiry == null
                      ? 'No expiry'
                      : 'Expires ${DateFormat.yMMMd().format(expiry!)}',
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final selected = await showDatePicker(
                    context: context,
                    firstDate: DateTime.now().add(const Duration(days: 1)),
                    lastDate: DateTime.now().add(const Duration(days: 3650)),
                  );
                  if (selected != null) {
                    setDialogState(
                      () => expiry = DateTime(
                        selected.year,
                        selected.month,
                        selected.day,
                        23,
                        59,
                        59,
                      ),
                    );
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) {
      uses.dispose();
      return;
    }
    try {
      final maxUses = uses.text.trim().isEmpty
          ? null
          : int.tryParse(uses.text.trim());
      if (uses.text.trim().isNotEmpty && maxUses == null) {
        throw const FormatException('Usage limit must be a whole number.');
      }
      final code = await _service.createInvite(
        expiresAt: expiry,
        maxUses: maxUses,
      );
      if (mounted) setState(_reload);
      if (mounted) {
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Invite created'),
            content: SelectableText(code),
            actions: [
              TextButton(
                onPressed: () => Clipboard.setData(ClipboardData(text: code)),
                child: const Text('Copy'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Done'),
              ),
            ],
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
    uses.dispose();
  }

  Future<void> _revoke(CommunityInvite invite) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Revoke invite?'),
        content: Text(invite.code),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Revoke'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _service.revokeInvite(invite.code);
      if (mounted) setState(_reload);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
