import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'services/admin_tenant_context.dart';

class ContentModerationScreen extends StatefulWidget {
  const ContentModerationScreen({super.key, this.call});
  final Future<Map<String, dynamic>> Function(String, Map<String, dynamic>)?
  call;
  @override
  State<ContentModerationScreen> createState() =>
      _ContentModerationScreenState();
}

class _ContentModerationScreenState extends State<ContentModerationScreen> {
  Future<Map<String, dynamic>> _call(
    String name,
    Map<String, dynamic> data,
  ) async {
    if (widget.call != null) return widget.call!(name, data);
    final response = await FirebaseFunctions.instanceFor(
      region: 'asia-southeast1',
    ).httpsCallable(name).call(data);
    return Map<String, dynamic>.from(response.data as Map);
  }

  List<Map<String, dynamic>> _reports = [], _history = [];
  bool _loading = true, _busy = false, _queueLoaded = false;
  bool _reportsTruncated = false, _historyTruncated = false;
  String? _error;
  late final String _communityId = AdminTenantContext.instance
      .requireCommunityId();

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _queueLoaded = false;
        _error = null;
      });
    }
    try {
      final result = await _call('listWallModerationReports', {
        'communityId': _communityId,
      });
      final reports = (result['reports'] as List)
          .map((x) => Map<String, dynamic>.from(x as Map))
          .toList();
      final history = (result['history'] as List)
          .map((x) => Map<String, dynamic>.from(x as Map))
          .toList();
      if (mounted) {
        setState(() {
          _reports = reports;
          _history = history;
          _reportsTruncated = result['reportsTruncated'] == true;
          _historyTruncated = result['historyTruncated'] == true;
          _loading = false;
          _queueLoaded = true;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = _errorMessage(
            error,
            'Moderation queue could not be loaded.',
          );
          _loading = false;
        });
      }
    }
  }

  String _errorMessage(Object error, String fallback) {
    if (error is FirebaseFunctionsException &&
        error.message?.trim().isNotEmpty == true) {
      return '$fallback ${error.message}';
    }
    return fallback;
  }

  Future<void> _resolve(String reportId, String action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final saved = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _ModerationDecisionDialog(
          action: action,
          save: (fields) => _call('resolveWallModerationReport', {
            'communityId': _communityId,
            'reportId': reportId,
            'action': action,
            ...fields,
          }),
        ),
      );
      if (saved == true && mounted) await _refresh();
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = _errorMessage(
            error,
            'Moderation decision could not be saved. Please retry.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _loadMoreHistory() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await _call('listWallModerationReports', {
        'communityId': _communityId,
        'historyOffset': _history.length,
      });
      final next = (result['history'] as List)
          .map((x) => Map<String, dynamic>.from(x as Map))
          .toList();
      if (mounted) {
        setState(() {
          _history = [..._history, ...next];
          _historyTruncated = result['historyTruncated'] == true;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = _errorMessage(
            error,
            'Moderation history could not be loaded.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _section(String title, int count) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 16),
    child: Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        Chip(label: Text('$count')),
      ],
    ),
  );

  Widget _cards(List<Map<String, dynamic>> rows, {bool history = false}) =>
      LayoutBuilder(
        builder: (_, constraints) {
          final width = constraints.maxWidth >= 800
              ? (constraints.maxWidth - 16) / 2
              : constraints.maxWidth;
          return Wrap(
            spacing: 16,
            runSpacing: 16,
            children: rows
                .map(
                  (item) => SizedBox(
                    width: width,
                    child: _ModerationCard(
                      item: item,
                      history: history,
                      busy: _busy,
                      resolve: (action) =>
                          _resolve(item['id'] as String, action),
                    ),
                  ),
                )
                .toList(),
          );
        },
      );

  @override
  Widget build(BuildContext context) {
    final open = _reports.where((item) => item['status'] == 'open').toList();
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        title: const Text('Content moderation'),
        actions: [
          IconButton(
            onPressed: _loading || _busy ? null : _refresh,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1120),
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Text(
                      'Review reported content and keep a clear record of community decisions.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    if (!_queueLoaded)
                      TextButton(
                        onPressed: _busy ? null : _refresh,
                        child: const Text('Retry'),
                      ),
                    if (_queueLoaded) ...[
                      _section('Open reports', open.length),
                      if (_reportsTruncated)
                        const Text(
                          'Showing the first 500 open reports. Resolve reports and refresh to see more.',
                        ),
                      if (open.isEmpty)
                        const _ModerationEmpty('No open reports.'),
                      _cards(open),
                      _section('Moderation history', _history.length),
                      if (_history.isEmpty)
                        const _ModerationEmpty('No moderation actions yet.'),
                      _cards(_history, history: true),
                      if (_historyTruncated)
                        TextButton(
                          onPressed: _busy ? null : _loadMoreHistory,
                          child: const Text('Load more history'),
                        ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }
}

String _moderationDate(dynamic milliseconds) => milliseconds is int
    ? DateFormat.yMMMd().add_jm().format(
        DateTime.fromMillisecondsSinceEpoch(milliseconds).toLocal(),
      )
    : 'Date unavailable';

class _ModerationEmpty extends StatelessWidget {
  const _ModerationEmpty(this.message);
  final String message;
  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    child: Padding(padding: const EdgeInsets.all(24), child: Text(message)),
  );
}

class _ModerationCard extends StatelessWidget {
  const _ModerationCard({
    required this.item,
    required this.history,
    required this.busy,
    required this.resolve,
  });
  final Map<String, dynamic> item;
  final bool history, busy;
  final void Function(String) resolve;
  @override
  Widget build(BuildContext context) {
    final hidden = item['action'] == 'hide';
    final status = history
        ? hidden
              ? 'Hidden'
              : 'Dismissed'
        : 'Open';
    final color = history
        ? hidden
              ? Colors.red.shade700
              : Colors.green.shade700
        : Colors.orange.shade800;
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    history
                        ? hidden
                              ? 'Content hidden'
                              : 'Report dismissed'
                        : 'Reported ${item['targetType'] ?? 'content'}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(color: color, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Author: ${item['authorName'] ?? 'Resident'}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            Text(
              '${item['targetType'] ?? 'Content'} · ${_moderationDate(item['createdAtMs'])}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(vertical: 14),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                (item['contentSnapshot'] as String?)?.isNotEmpty == true
                    ? item['contentSnapshot'] as String
                    : 'Content preview unavailable',
              ),
            ),
            Text(
              'Report reason: ${history ? item['reportReason'] ?? 'Not recorded' : item['reason'] ?? 'Not recorded'}',
            ),
            if (history) ...[
              const SizedBox(height: 12),
              Text(
                'Public decision reason: ${item['publicReason'] ?? 'Reason not recorded for this earlier decision.'}',
              ),
              const SizedBox(height: 8),
              Text(
                'Moderator: ${item['actorName'] ?? 'Community Admin'} · ${_moderationDate(item['createdAtMs'])}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if ((item['internalNote'] as String?)?.isNotEmpty == true)
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: const Text('Internal note · Admin only'),
                  children: [Text(item['internalNote'] as String)],
                ),
            ] else ...[
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: busy ? null : () => resolve('dismiss'),
                    child: const Text('Dismiss report'),
                  ),
                  FilledButton(
                    onPressed: busy ? null : () => resolve('hide'),
                    child: const Text('Hide content'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ModerationDecisionDialog extends StatefulWidget {
  const _ModerationDecisionDialog({required this.action, required this.save});
  final String action;
  final Future<Map<String, dynamic>> Function(Map<String, dynamic>) save;
  @override
  State<_ModerationDecisionDialog> createState() =>
      _ModerationDecisionDialogState();
}

class _ModerationDecisionDialogState extends State<_ModerationDecisionDialog> {
  static const reasons = {
    'dismiss': {
      'no_violation': 'No community guideline violation',
      'insufficient_context': 'Insufficient context',
      'duplicate_report': 'Duplicate report',
      'resolved': 'Issue already resolved',
    },
    'hide': {
      'inappropriate_content': 'Inappropriate content',
      'harassment': 'Harassment or bullying',
      'spam': 'Spam',
      'privacy': 'Privacy or personal information',
      'other_violation': 'Other community guideline violation',
    },
  };
  final _public = TextEditingController(), _internal = TextEditingController();
  String? _reason, _error;
  bool _busy = false;
  @override
  void dispose() {
    _public.dispose();
    _internal.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || _reason == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await widget.save({
        'reasonCode': _reason,
        'publicExplanation': _public.text.trim(),
        'internalNote': _internal.text.trim(),
      });
      if (result['success'] != true) {
        throw StateError('Decision was not confirmed.');
      }
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = error is FirebaseFunctionsException
              ? error.message ?? 'Unable to save decision. Please retry.'
              : 'Unable to save decision. Please retry.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      title: Text(widget.action == 'hide' ? 'Hide content' : 'Dismiss report'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'This public reason is shared with the resident. Do not include the reporter’s identity.',
              ),
              const SizedBox(height: 24),
              DropdownButtonFormField<String>(
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Public decision reason',
                ),
                items: reasons[widget.action]!.entries
                    .map(
                      (e) => DropdownMenuItem(
                        value: e.key,
                        child: Text(e.value, maxLines: 2),
                      ),
                    )
                    .toList(),
                onChanged: _busy
                    ? null
                    : (value) => setState(() => _reason = value),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _public,
                enabled: !_busy,
                maxLength: 300,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Public explanation (optional)',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _internal,
                enabled: !_busy,
                maxLength: 1000,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Internal note (Admin only, optional)',
                  alignLabelWithHint: true,
                ),
              ),
              const Text(
                'Internal notes are never included in resident notifications.',
              ),
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              if (_busy)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Center(child: CircularProgressIndicator()),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy || _reason == null ? null : _save,
          child: Text(_busy ? 'Saving decision...' : 'Confirm decision'),
        ),
      ],
    ),
  );
}
