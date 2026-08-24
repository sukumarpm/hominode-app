import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import 'models/community_invite.dart';
import 'services/community_invite_service.dart';
import 'services/admin_tenant_context.dart';
import 'widgets/standard_header.dart';

class CommunitySettingsScreen extends StatefulWidget {
  const CommunitySettingsScreen({super.key});
  @override
  State<CommunitySettingsScreen> createState() =>
      _CommunitySettingsScreenState();
}

class _CommunitySettingsScreenState extends State<CommunitySettingsScreen> {
  final _service = CommunityInviteService();
  late Future<AdminCommunity> _community;

  @override
  void initState() {
    super.initState();
    _community = _service.getSelectedCommunity();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF7F7F7),
    body: CustomScrollView(
      slivers: [
        const StandardHeader(title: 'Community Settings'),
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList.list(
            children: [
              FutureBuilder<AdminCommunity>(
                future: _community,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    if (snapshot.error is CommunityNotFoundException) {
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              const Text('Selected community does not exist.'),
                              const SizedBox(height: 12),
                              FilledButton.icon(
                                onPressed: _showCreateCommunity,
                                icon: const Icon(Icons.add_business),
                                label: const Text('Create Community'),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    return Text('Unable to load community: ${snapshot.error}');
                  }
                  final community = snapshot.data!;
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundImage:
                                community.logoUrl?.isNotEmpty == true
                                ? NetworkImage(community.logoUrl!)
                                : null,
                            child: community.logoUrl?.isNotEmpty == true
                                ? null
                                : const Icon(Icons.apartment),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  community.name,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text('ID: ${community.id}'),
                                if (community.slug.isNotEmpty)
                                  Text('Slug: ${community.slug}'),
                                Text(
                                  community.isActive ? 'Active' : 'Inactive',
                                  style: TextStyle(
                                    color: community.isActive
                                        ? Colors.green
                                        : Colors.red,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Resident registration invites',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _createInvite,
                    icon: const Icon(Icons.add),
                    label: const Text('Create'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              StreamBuilder<List<CommunityInvite>>(
                stream: _service.watchInvites(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Text('Unable to load invites: ${snapshot.error}');
                  }
                  final invites = snapshot.data ?? const [];
                  if (invites.isEmpty) {
                    return const Card(
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: Center(
                          child: Text('No resident invites created'),
                        ),
                      ),
                    );
                  }
                  return Column(children: invites.map(_inviteCard).toList());
                },
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Future<void> _showCreateCommunity() async {
    final created = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _CreateCommunityDialog(service: _service),
    );
    if (!mounted || created != true) return;
    setState(() {
      _community = _service.getSelectedCommunity();
    });
  }

  Widget _inviteCard(CommunityInvite invite) {
    final usable = invite.isActive && !invite.isExpired && !invite.isExhausted;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
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
              const SizedBox(height: 12),
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

class _CreateCommunityDialog extends StatefulWidget {
  const _CreateCommunityDialog({required this.service});

  final CommunityInviteService service;

  @override
  State<_CreateCommunityDialog> createState() => _CreateCommunityDialogState();
}

class _CreateCommunityDialogState extends State<_CreateCommunityDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _idController;
  late final TextEditingController _nameController;
  late final TextEditingController _slugController;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _idController = TextEditingController(
      text: AdminTenantContext.instance.selectedCommunityId ?? '',
    );
    _nameController = TextEditingController();
    _slugController = TextEditingController();
  }

  @override
  void dispose() {
    _idController.dispose();
    _nameController.dispose();
    _slugController.dispose();
    super.dispose();
  }

  Future<void> _createCommunity() async {
    if (_submitting || _formKey.currentState?.validate() != true) return;
    setState(() => _submitting = true);
    try {
      await widget.service.createCommunity(
        communityId: _idController.text,
        name: _nameController.text,
        slug: _slugController.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString()), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Create Community'),
    content: Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            controller: _idController,
            decoration: const InputDecoration(
              labelText: 'Community ID',
              hintText: 'GV-0701',
            ),
            validator: (value) => value?.trim().isEmpty == true
                ? 'Community ID is required'
                : null,
          ),
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Name',
              hintText: 'Green Valley',
            ),
            validator: (value) =>
                value?.trim().isEmpty == true ? 'Name is required' : null,
          ),
          TextFormField(
            controller: _slugController,
            decoration: const InputDecoration(
              labelText: 'Slug',
              hintText: 'green-valley',
            ),
            validator: (value) =>
                CommunityInviteService.normalizeSlug(value ?? '').isEmpty
                ? 'Enter a valid slug'
                : null,
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: _submitting ? null : () => Navigator.of(context).pop(false),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _submitting ? null : _createCommunity,
        child: _submitting
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('Create'),
      ),
    ],
  );
}
