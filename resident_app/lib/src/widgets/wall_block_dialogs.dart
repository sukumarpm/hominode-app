import 'package:flutter/material.dart';
import '../services/post_firestore_service.dart';

Future<bool> showBlockResidentDialog(
  BuildContext context,
  Future<void> Function() block,
) async =>
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _BlockResidentDialog(block: block),
    ) ??
    false;

class _BlockResidentDialog extends StatefulWidget {
  const _BlockResidentDialog({required this.block});
  final Future<void> Function() block;
  @override
  State<_BlockResidentDialog> createState() => _BlockResidentDialogState();
}

class _BlockResidentDialogState extends State<_BlockResidentDialog> {
  bool _busy = true;
  String? _error;
  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    try {
      await widget.block();
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = PostFirestoreService.blockErrorMessage(
            error,
            'Unable to block resident.',
          );
        });
      }
    }
  }

  void _retry() {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    _run();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      title: Text(_busy ? 'Blocking resident...' : 'Block resident'),
      content: _busy
          ? const Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 16),
                Expanded(child: Text('Please wait...')),
              ],
            )
          : Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
      actions: _busy
          ? null
          : [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(onPressed: _retry, child: const Text('Retry')),
            ],
    ),
  );
}

/// The existing Community Wall blocked-users dialog, loaded through the scoped callable.
class BlockedResidentsDialog extends StatefulWidget {
  const BlockedResidentsDialog({super.key, required this.service});
  final PostFirestoreService service;
  @override
  State<BlockedResidentsDialog> createState() => _BlockedResidentsDialogState();
}

class _BlockedResidentsDialogState extends State<BlockedResidentsDialog> {
  List<Map<String, dynamic>> _users = [];
  bool _loading = true, _loaded = false, _changed = false;
  String? _busyUser, _error, _message;
  String _search = '';
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _name(Map<String, dynamic> user) =>
      (user['name'] as String?)?.trim().isNotEmpty == true
      ? user['name'] as String
      : 'Resident';
  String _unit(Map<String, dynamic> user) =>
      (user['flatLabel'] ??
              user['unitLabel'] ??
              user['unitId'] ??
              user['flat'] ??
              '')
          .toString();

  Future<void> _load() async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final users = await widget.service.blockedUsers();
      users.sort(
        (a, b) => _name(a).toLowerCase().compareTo(_name(b).toLowerCase()),
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        _users = users;
        _loaded = true;
      });
    } catch (error) {
      if (mounted && generation == _generation) {
        setState(() {
          _error = PostFirestoreService.blockErrorMessage(
            error,
            'Unable to load blocked residents.',
          );
        });
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _unblock(String userId) async {
    if (_busyUser != null || _loading) return;
    setState(() {
      _busyUser = userId;
      _error = null;
      _message = null;
    });
    try {
      await widget.service.setUserBlocked(userId, false);
      if (!mounted) return;
      setState(() {
        _changed = true;
        _users.removeWhere((user) => user['userId'] == userId);
        _message = 'Resident unblocked.';
      });
      await _load();
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = PostFirestoreService.blockErrorMessage(
            error,
            'Unable to unblock resident.',
          );
        });
      }
    } finally {
      if (mounted) setState(() => _busyUser = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.trim().toLowerCase();
    final shown = _users
        .where(
          (user) =>
              '${_name(user)} ${_unit(user)}'.toLowerCase().contains(query),
        )
        .toList();
    return PopScope(
      canPop: _busyUser == null,
      child: AlertDialog(
        scrollable: true,
        title: const Text('Blocked residents'),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_loaded)
                Text(
                  '${_users.length} blocked ${_users.length == 1 ? 'resident' : 'residents'}',
                ),
              if (_loaded && _users.isNotEmpty) ...[
                const SizedBox(height: 12),
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Search by name or unit',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (value) => setState(() => _search = value),
                ),
                const SizedBox(height: 12),
              ],
              if (_message != null)
                Text(_message!, style: const TextStyle(color: Colors.green)),
              if (_error != null) ...[
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                TextButton(
                  onPressed: _loading || _busyUser != null ? null : _load,
                  child: const Text('Retry list'),
                ),
              ],
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_loaded && _users.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text('You haven’t blocked any residents.'),
                )
              else if (_loaded && shown.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text('No matching residents.'),
                )
              else if (_loaded)
                SizedBox(
                  height: 260,
                  child: ListView.builder(
                    itemCount: shown.length,
                    itemBuilder: (_, index) {
                      final user = shown[index], uid = user['userId'] as String;
                      final unit = _unit(user);
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(_name(user)),
                        subtitle: unit.isEmpty ? null : Text(unit),
                        trailing: _busyUser == uid
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : TextButton(
                                onPressed: _busyUser != null
                                    ? null
                                    : () => _unblock(uid),
                                child: const Text('Unblock'),
                              ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _busyUser != null
                ? null
                : () => Navigator.pop(context, _changed),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
