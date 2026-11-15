import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'services/account_deletion_review_service.dart';
import 'services/admin_tenant_context.dart';
import 'services/assisted_deletion_service.dart';
import 'widgets/assisted_deletion_dialog.dart';

class AccountDeletionRequestsScreen extends StatefulWidget {
  const AccountDeletionRequestsScreen({super.key, this.service, this.assistedService});

  final AccountDeletionReviewGateway? service;
  final AssistedDeletionGateway? assistedService;

  @override
  State<AccountDeletionRequestsScreen> createState() =>
      _AccountDeletionRequestsScreenState();
}

class _AccountDeletionRequestsScreenState
    extends State<AccountDeletionRequestsScreen> {
  late final AccountDeletionReviewGateway _service =
      widget.service ?? AccountDeletionReviewService();
  late String? _communityId = _resolveCommunity();
  late Future<List<CommunityDeletionRequest>> _requests = _load();
  String? _error;
  String? _success;
  bool _saving = false;
  String? _reassessingRequestId;

  @override
  void initState() {
    super.initState();
    AdminTenantContext.instance.addListener(_tenantChanged);
  }

  void _tenantChanged() {
    final community = _resolveCommunity();
    if (community == _communityId || !mounted) return;
    setState(() { _communityId = community; _error = null; _success = null; _requests = _load(); });
  }

  @override
  void dispose() {
    AdminTenantContext.instance.removeListener(_tenantChanged);
    super.dispose();
  }

  Future<void> _assisted([CommunityDeletionRequest? request]) async {
    final community = _communityId;
    if (_saving || _reassessingRequestId != null || community == null || _resolveCommunity() != community ||
        (request != null && (!request.canVerifyAssisted || request.communityId != community))) return;
    setState(() { _saving = true; _error = null; _success = null; });
    try {
      final message = await showDialog<String>(context: context, barrierDismissible: false,
        builder: (_) => AssistedDeletionDialog(communityId: community, service: widget.assistedService ?? AssistedDeletionService(), request: request));
      if (!mounted || _resolveCommunity() != community || message == null) return;
      setState(() => _success = message);
      _refresh(clearMessages: false);
    } finally { if (mounted) setState(() => _saving = false); }
  }

  String? _resolveCommunity() {
    try {
      return AdminTenantContext.instance.requireCommunityId();
    } catch (_) {
      return null;
    }
  }

  Future<List<CommunityDeletionRequest>> _load() {
    final communityId = _communityId;
    if (communityId == null) {
      return Future.error(StateError('Select an authorized community first.'));
    }
    return _service.list(communityId);
  }

  void _refresh({bool clearMessages = true}) {
    setState(() {
      _error = null;
      if (clearMessages) _success = null;
      _requests = _load();
    });
  }

  Future<void> _recordFinding(CommunityDeletionRequest request) async {
    if (_saving) return;
    final verified = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _FindingDialog(
        submit: (note) async {
          setState(() {
            _saving = true;
            _error = null;
            _success = null;
          });
          try {
            await _service.recordFinding(
              requestId: request.requestId,
              finding: 'verified_handover',
              note: note,
              evidenceDigest: request.financialEvidence?['digest'] as String?,
              retainFinancialRecords: true,
            );
          } finally {
            if (mounted) setState(() => _saving = false);
          }
        },
      ),
    );
    if (!mounted || verified != true) return;
    setState(
      () => _success = 'Financial handover verified. Deletion processing.',
    );
    _refresh(clearMessages: false);
  }

  Future<void> _reassess(CommunityDeletionRequest request) async {
    if (_saving || _reassessingRequestId != null || !_canReassess(request)) {
      return;
    }
    setState(() {
      _reassessingRequestId = request.requestId;
      _error = null;
      _success = null;
    });
    try {
      final result = await _service.reassess(requestId: request.requestId);
      if (!mounted) return;
      final status = result['status'] is String
          ? result['status'] as String
          : 'updated';
      setState(() {
        _success = result['completed'] == true || status == 'completed'
            ? 'Account deletion completed.'
            : 'Deletion recheck finished. Current status: $status.';
      });
      _refresh(clearMessages: false);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Deletion could not be rechecked. Please retry.',
        );
      }
    } finally {
      if (mounted) setState(() => _reassessingRequestId = null);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Account Deletion Requests'),
      actions: [
        IconButton(
          tooltip: 'Refresh requests',
          onPressed: _saving || _reassessingRequestId != null ? null : _refresh,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: LayoutBuilder(
      builder: (context, constraints) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: Padding(
            padding: EdgeInsets.all(constraints.maxWidth < 600 ? 16 : 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(alignment: Alignment.centerLeft, child: FilledButton.icon(
                  onPressed: _saving || _reassessingRequestId != null || _communityId == null ? null : () => _assisted(),
                  icon: const Icon(Icons.person_remove_alt_1_outlined), label: const Text('Assisted Account Deletion'))),
                const SizedBox(height: 12),
                const Text(
                  'Zero dues are processed automatically. For unpaid or unknown balances, review settlement and verify handover after the balance is zero. Viewing a request never deletes an account.',
                ),
                if (_success != null) ...[
                  const SizedBox(height: 12),
                  _Notice(text: _success!, color: Colors.green),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  _Notice(text: _error!, color: Colors.red),
                ],
                const SizedBox(height: 18),
                Expanded(
                  child: FutureBuilder<List<CommunityDeletionRequest>>(
                    future: _requests,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('Requests could not be loaded.'),
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: _refresh,
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        );
                      }
                      final requests = snapshot.data ?? const [];
                      if (requests.isEmpty) {
                        return const Center(
                          child: Text(
                            'No account deletion requests for this community.',
                          ),
                        );
                      }
                      return ListView.separated(
                        itemCount: requests.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) => _RequestCard(
                          request: requests[index],
                          onOpen: () => _showDetails(requests[index]),
                          onAssistedVerify: !_saving && _reassessingRequestId == null && requests[index].canVerifyAssisted && requests[index].communityId == _communityId ? () => _assisted(requests[index]) : null,
                          onReview: _saving || !_canVerify(requests[index])
                              ? null
                              : () => _recordFinding(requests[index]),
                          onReassess:
                              _saving ||
                                  _reassessingRequestId != null ||
                                  !_canReassess(requests[index])
                              ? null
                              : () => _reassess(requests[index]),
                          reassessing:
                              _reassessingRequestId ==
                              requests[index].requestId,
                        ),
                      );
                    },
                  ),
                ),
                if (_saving || _reassessingRequestId != null)
                  const LinearProgressIndicator(),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  void _showDetails(CommunityDeletionRequest request) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Request details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (request.sourceApp == 'admin_assisted') ...[AssistedDeletionDetails(request: request), const SizedBox(height: 16)],
              _Detail(label: 'Request ID', value: request.requestId),
              _Detail(
                label: 'Resident',
                value:
                    request.residentProfileStatus == 'verified' ||
                        request.residentProfileStatus ==
                            'retained_after_deletion'
                    ? (request.residentName ?? 'Name not provided')
                    : 'Identity verification required',
              ),
              _Detail(
                label: 'Unit / apartment',
                value: request.residentUnit ?? 'Not provided',
              ),
              _Detail(
                label: 'Community',
                value:
                    request.communityName ??
                    request.communityId ??
                    'Not provided',
              ),
              if (request.residentType != null)
                _Detail(
                  label: 'Resident role',
                  value: _residentRole(request.residentType),
                ),
              _Detail(
                label: 'Phone',
                value: request.residentPhone ?? 'Not provided',
              ),
              _Detail(
                label: 'Request date and time',
                value: _date(request.createdAt),
              ),
              _Detail(
                label: 'Current deletion status',
                value: _deletionStatus(request.status),
              ),
              if (request.completedAt != null)
                _Detail(
                  label: 'Deletion completion date and time',
                  value: _date(request.completedAt),
                ),
              if (request.status != 'completed')
                _Detail(
                  label: 'Review queue status',
                  value: request.reviewStatus,
                ),
              _Detail(
                label: 'Outstanding dues / settlement',
                value: _financialStatus(request),
              ),
              if (request.financialReviewRequired ||
                  request.financialReviewStatus != 'NOT_REQUIRED')
                _Detail(
                  label: 'Financial verification status',
                  value: _financialVerificationStatus(
                    request.financialReviewStatus,
                    completed: request.status == 'completed',
                  ),
                ),
              if (request.status != 'completed')
                _Detail(label: 'Review due', value: _date(request.reviewDueAt)),
              _Detail(
                label: 'Previous Admin finding',
                value: request.reviewFinding ?? 'None recorded',
              ),
              _Detail(
                label: 'Previous review note',
                value: request.reviewNote ?? 'None recorded',
              ),
              _Detail(
                label: 'Previous review timestamp',
                value: _date(request.reviewedAt),
              ),
              for (final dependency in request.unresolvedDependencies)
                _Detail(label: 'Unresolved dependency', value: dependency),
              const SizedBox(height: 8),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  static String _date(DateTime? value) => value == null
      ? 'Not provided'
      : DateFormat.yMMMd().add_jm().format(value.toLocal());

  static String _residentRole(String? value) => switch (value?.toLowerCase()) {
    'owner' => 'Owner',
    'tenant' => 'Tenant',
    _ => value ?? 'Not provided',
  };

  static String _deletionStatus(String value) => switch (value) {
    'completed' => 'Account Deleted',
    'pending_assisted_verification' => 'Pending identity verification',
    'pending_verification' => 'Verification pending',
    'pending_review' => 'Pending review',
    'eligibility_blocked' => 'Eligibility check blocked',
    'deletion_in_progress' => 'Deletion in progress',
    'reconciliation_required' => 'Reconciliation required',
    'failed' => 'Processing failed',
    _ => value,
  };

  static String _financialVerificationStatus(
    String value, {
    bool completed = false,
  }) => completed && value != 'VERIFIED_HANDOVER'
      ? (value == 'NOT_REQUIRED' ? 'Not required' : 'Not recorded')
      : switch (value) {
          'VERIFIED_HANDOVER' => 'Financial handover verified',
          'NOT_REQUIRED' => 'Not required',
          'UNKNOWN_REQUIRES_REVIEW' => 'Unknown — requires review',
          _ => value,
        };

  static bool _canVerify(CommunityDeletionRequest request) =>
      request.status == 'pending_review' &&
      request.financialReviewRequired &&
      request.financialReviewStatus != 'VERIFIED_HANDOVER' &&
      (request.financialEvidence?['outstandingMinor'] as num?)?.toInt() == 0;

  static bool _canReassess(CommunityDeletionRequest request) => const {
    'pending_review',
    'eligibility_blocked',
    'deletion_in_progress',
    'reconciliation_required',
    'failed',
  }.contains(request.status);

  static String _financialStatus(CommunityDeletionRequest request) {
    if (request.status == 'pending_assisted_verification') return 'Not started: identity verification pending';
    if (request.financialReviewStatus == 'VERIFIED_HANDOVER') {
      return 'Financial handover verified';
    }
    if (request.status == 'completed') return 'Deletion completed';
    final evidence = request.financialEvidence;
    final outstanding = (evidence?['outstandingMinor'] as num?)?.toInt();
    if (outstanding == null) return 'Unknown: requires reconciliation';
    if (outstanding > 0) return 'Outstanding dues: awaiting settlement';
    return request.financialReviewRequired
        ? 'Zero dues: eligible for financial verification'
        : 'Zero dues: automatic processing';
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.request,
    required this.onOpen,
    this.onReview,
    this.onAssistedVerify,
    this.onReassess,
    this.reassessing = false,
  });
  final CommunityDeletionRequest request;
  final VoidCallback onOpen;
  final VoidCallback? onReview;
  final VoidCallback? onAssistedVerify;
  final VoidCallback? onReassess;
  final bool reassessing;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 18,
        runSpacing: 12,
        children: [
          SizedBox(
            width: 470,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  request.sourceApp == 'admin_assisted' ? 'Assisted deletion request' : 'Resident deletion request',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  request.residentProfileStatus == 'verified' ||
                          request.residentProfileStatus ==
                              'retained_after_deletion'
                      ? (request.residentName ?? 'Name not provided')
                      : 'Identity verification required',
                ),
                if (request.sourceApp == 'admin_assisted') AssistedDeletionDetails(request: request),
                if (request.residentUnit != null)
                  Text('Unit: ${request.residentUnit}'),
                Text(
                  'Community: ${request.communityName ?? request.communityId ?? 'Not provided'}',
                ),
                if (request.residentType != null)
                  Text(
                    'Resident role: ${_AccountDeletionRequestsScreenState._residentRole(request.residentType)}',
                  ),
                const SizedBox(height: 6),
                Text(
                  'Current deletion status: ${_AccountDeletionRequestsScreenState._deletionStatus(request.status)}',
                ),
                if (request.residentPhone != null)
                  Text('Phone: ${request.residentPhone}'),
                if (request.completedAt != null)
                  Text(
                    'Deletion completion: ${_AccountDeletionRequestsScreenState._date(request.completedAt)}',
                  ),
                Text(
                  'Request date and time: ${_AccountDeletionRequestsScreenState._date(request.createdAt)}',
                ),
                if (request.status != 'completed')
                  Text('Review queue status: ${request.reviewStatus}'),
                Text(
                  'Outstanding dues / settlement: ${_AccountDeletionRequestsScreenState._financialStatus(request)}',
                ),
                if (request.financialReviewRequired ||
                    request.financialReviewStatus != 'NOT_REQUIRED')
                  Text(
                    'Financial verification: ${_AccountDeletionRequestsScreenState._financialVerificationStatus(request.financialReviewStatus, completed: request.status == 'completed')}',
                  ),
                if (request.reviewFinding != null)
                  Text('Previous finding: ${request.reviewFinding}'),
                if (request.reviewNote != null)
                  Text('Previous note: ${request.reviewNote}'),
                for (final dependency in request.unresolvedDependencies)
                  Text('Unresolved: $dependency'),
              ],
            ),
          ),
          Wrap(
            spacing: 8,
            children: [
              if (onAssistedVerify != null) FilledButton(onPressed: onAssistedVerify, child: const Text('Verify identity and consent')),
              OutlinedButton(
                onPressed: onOpen,
                child: const Text('Open details'),
              ),
              if (onReview != null)
                FilledButton(
                  onPressed: onReview,
                  child: const Text('Verify financial handover'),
                ),
              if (onReassess != null || reassessing)
                OutlinedButton.icon(
                  onPressed: reassessing ? null : onReassess,
                  icon: reassessing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                  label: Text(reassessing ? 'Rechecking…' : 'Recheck deletion'),
                ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _FindingDialog extends StatefulWidget {
  const _FindingDialog({required this.submit});
  final Future<void> Function(String note) submit;
  @override
  State<_FindingDialog> createState() => _FindingDialogState();
}

class _FindingDialogState extends State<_FindingDialog> {
  final _note = TextEditingController();
  bool _retentionConfirmed = false;
  bool _saving = false;
  String? _error;

  Future<void> _verify() async {
    if (_saving || _note.text.trim().length < 10 || !_retentionConfirmed) {
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.submit(_note.text.trim());
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Financial verification could not be saved. Please retry.';
        });
      }
    }
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: AlertDialog(
      title: const Text('Verify financial handover'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Zero dues confirmed. Backend will recheck current financial records before deletion.',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            CheckboxListTile(
              value: _retentionConfirmed,
              onChanged: _saving
                  ? null
                  : (value) =>
                        setState(() => _retentionConfirmed = value == true),
              title: const Text(
                'I confirm financial settlement and that billing history remains unchanged.',
              ),
            ),
            TextField(
              controller: _note,
              enabled: !_saving,
              minLines: 3,
              maxLines: 5,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Financial handover note (at least 10 characters)',
              ),
            ),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Back'),
        ),
        FilledButton(
          onPressed:
              _saving || _note.text.trim().length < 10 || !_retentionConfirmed
              ? null
              : _verify,
          child: Text(_saving ? 'Verifying...' : 'Confirm settlement'),
        ),
      ],
    ),
  );
}

class _Detail extends StatelessWidget {
  const _Detail({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text('$label: $value'),
  );
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text, required this.color});
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) =>
      Text(text, style: TextStyle(color: color));
}
