import 'package:flutter/material.dart';
import '../services/account_deletion_review_service.dart';
import '../services/assisted_deletion_service.dart';
import '../services/admin_tenant_context.dart';

class AssistedDeletionDetails extends StatelessWidget {
  const AssistedDeletionDetails({super.key, required this.request});
  final CommunityDeletionRequest request;
  @override
  Widget build(BuildContext context) {
    final intake = request.assistedIntake;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Text(request.verificationStatus == 'verified' ? 'Identity and consent verified' : 'Pending identity verification', style: const TextStyle(fontWeight: FontWeight.bold)),
      if (request.verificationStatus != 'verified') const Text('Account deletion has not started. A case reference alone does not verify identity.'),
      Text('Support case: ${intake?['supportCaseReference'] ?? 'Not provided'}'),
      Text('Verification method: ${assistedVerificationMethods[intake?['verificationMethod']] ?? 'Not provided'}'),
      Text('Protected evidence reference: ${intake?['verificationEvidenceReference'] ?? 'Not provided'}'),
      Text('Admin verification notes: ${intake?['verificationNotes'] ?? 'Not provided'}'),
      Text('Consent attestation recorded: ${intake?['consentAttested'] == true ? 'Yes' : 'No'}'),
    ]);
  }
}

class AssistedDeletionDialog extends StatefulWidget {
  const AssistedDeletionDialog({super.key, required this.communityId, required this.service, this.request});
  final String communityId;
  final AssistedDeletionGateway service;
  final CommunityDeletionRequest? request;
  @override
  State<AssistedDeletionDialog> createState() => _AssistedDeletionDialogState();
}
class _AssistedDeletionDialogState extends State<AssistedDeletionDialog> {
  final _case = TextEditingController(), _evidence = TextEditingController(), _notes = TextEditingController();
  String _search = '', _method = '';
  AssistedDeletionResident? _resident;
  bool _consent = false, _identity = false, _personalConsent = false, _saving = false;
  String? _error;
  late Future<List<AssistedDeletionResident>> _residents;
  bool get _scopeCurrent => AdminTenantContext.instance.communityId == widget.communityId && AdminTenantContext.instance.authorizedCommunityIds.contains(widget.communityId);
  @override
  void initState() {
    super.initState();
    _residents = widget.request == null ? widget.service.residents(widget.communityId) : Future.value([]);
    AdminTenantContext.instance.addListener(_tenantChanged);
  }
  void _tenantChanged() { if (mounted) setState(() {}); }
  bool _reference(String value, int max) => RegExp(r'^[A-Za-z0-9][A-Za-z0-9._:-]{2,159}$').hasMatch(value.trim()) && value.trim().length <= max;
  bool get _validIntake => _resident?.communityId == widget.communityId && _reference(_case.text, 80) && _reference(_evidence.text, 160) &&
    _case.text.trim() != _evidence.text.trim() && assistedVerificationMethods.containsKey(_method) && _notes.text.trim().length >= 20 && _notes.text.length <= 600 &&
    !RegExp(r'[\x00-\x08\x0b\x0c\x0e-\x1f]|data:|base64|<img|https?://|gs://|[A-Za-z0-9+/]{160,}={0,2}', caseSensitive: false).hasMatch(_notes.text) && _consent;
  bool get _validVerification => widget.request?.canVerifyAssisted == true && widget.request?.communityId == widget.communityId && _identity && _personalConsent;
  Future<void> _submit() async {
    if (_saving || !_scopeCurrent || (widget.request == null ? !_validIntake : !_validVerification)) return;
    setState(() { _saving = true; _error = null; });
    try {
      final request = widget.request;
      final result = request == null
        ? await widget.service.createIntake({'residentUid': _resident!.uid, 'communityId': widget.communityId, 'supportCaseReference': _case.text.trim(), 'verificationMethod': _method, 'verificationEvidenceReference': _evidence.text.trim(), 'verificationNotes': _notes.text.trim(), 'consentAttested': true})
        : await widget.service.verify(communityId: widget.communityId, requestId: request.requestId, intakeDigest: request.intakeDigest!);
      if (!mounted || !_scopeCurrent) return;
      String message;
      if (request != null) {
        if (result['verificationStatus'] != 'verified') throw StateError('Unconfirmed verification');
        message = 'Identity and consent verified. Existing financial eligibility checks and deletion processing continue; verification does not mean deletion is complete.';
      } else {
        if (result['requestId'] is! String || (result['sourceApp'] == 'admin_assisted' && !RegExp(r'^[a-f0-9]{64}$').hasMatch(result['intakeDigest'] is String ? result['intakeDigest'] as String : ''))) throw StateError('Invalid intake response');
        message = result['status'] == 'pending_assisted_verification' && result['sourceApp'] == 'admin_assisted'
          ? 'Pending identity verification. Intake saved; account deletion has not started. Review the saved request separately to verify identity and consent.'
          : 'An existing deletion request was returned. Refresh and review its current verification and deletion status; no additional intake was created.';
      }
      Navigator.pop(context, message);
    } catch (error) {
      if (mounted && _scopeCurrent) setState(() => _error = assistedDeletionError(error));
    } finally { if (mounted) setState(() => _saving = false); }
  }
  @override
  void dispose() {
    AdminTenantContext.instance.removeListener(_tenantChanged);
    _case.dispose(); _evidence.dispose(); _notes.dispose(); super.dispose();
  }
  @override
  Widget build(BuildContext context) => PopScope(canPop: !_saving, child: AlertDialog(
    title: Text(widget.request == null ? 'Assisted Account Deletion' : 'Verify assisted identity and consent'),
    content: SizedBox(width: 560, child: SingleChildScrollView(child: !_scopeCurrent ? const Text('Community changed. Close and reopen the request.') : Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (widget.request != null) ...[
        Text('${widget.request!.residentName ?? 'Name not provided'} · ${widget.request!.residentUnit ?? 'Unit not provided'}'),
        const SizedBox(height: 16), AssistedDeletionDetails(request: widget.request!),
        const SizedBox(height: 16),
        const Text('Confirm only after reviewing the saved evidence and independently checking identity and personal deletion consent. Verification queues the existing financial and deletion process.'),
        CheckboxListTile(contentPadding: EdgeInsets.zero, value: _identity, onChanged: _saving ? null : (v) => setState(() => _identity = v == true), title: const Text('I independently verified the Resident’s identity.')),
        CheckboxListTile(contentPadding: EdgeInsets.zero, value: _personalConsent, onChanged: _saving ? null : (v) => setState(() => _personalConsent = v == true), title: const Text('The Resident personally consented to account deletion.')),
      ] else ...[
        const Text('For Residents unable to access their accounts. Independently verify identity and explicit deletion consent using protected support evidence. Email or a case reference alone is insufficient.'),
        const SizedBox(height: 12),
        const Text('Saving intake does not start deletion or verify identity. Reauthenticate using your Admin phone within five minutes before each submission.'),
        const SizedBox(height: 20),
        FutureBuilder<List<AssistedDeletionResident>>(future: _residents, builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const Column(children: [CircularProgressIndicator(), Text('Loading community Residents…')]);
          if (snapshot.hasError) return Column(children: [const Text('Resident records could not be loaded. Check community access and retry.'), TextButton(onPressed: () => setState(() => _residents = widget.service.residents(widget.communityId)), child: const Text('Retry Resident list'))]);
          final residents = (snapshot.data ?? []).where((r) => r.communityId == widget.communityId).toList();
          final matches = residents.where((r) => r.uid == _resident?.uid || r.label.toLowerCase().contains(_search.toLowerCase())).toList();
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            TextField(enabled: !_saving, decoration: const InputDecoration(labelText: 'Search by name, building or unit'), onChanged: (v) => setState(() => _search = v)),
            const SizedBox(height: 24),
            DropdownButtonFormField<String>(isExpanded: true, initialValue: residents.any((r) => r.uid == _resident?.uid) ? _resident?.uid : null,
              decoration: const InputDecoration(labelText: 'Resident'), items: matches.map((r) => DropdownMenuItem(value: r.uid, child: Text(r.label, maxLines: 1, overflow: TextOverflow.ellipsis))).toList(),
              onChanged: _saving ? null : (v) => setState(() => _resident = residents.firstWhere((r) => r.uid == v))),
            if (_resident != null) Text('Selected Resident: ${_resident!.label}'),
            if (residents.isEmpty) const Text('No eligible Resident records in this community.'),
            if (residents.isNotEmpty && !residents.any((r) => r.label.toLowerCase().contains(_search.toLowerCase()))) const Text('No matching Residents.'),
          ]);
        }),
        const SizedBox(height: 24),
        TextField(controller: _case, enabled: !_saving, maxLength: 80, decoration: const InputDecoration(labelText: 'Support-case reference'), onChanged: (_) => setState(() {})),
        const SizedBox(height: 24),
        DropdownButtonFormField<String>(isExpanded: true, decoration: const InputDecoration(labelText: 'Identity-verification method'), items: assistedVerificationMethods.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, overflow: TextOverflow.ellipsis))).toList(), onChanged: _saving ? null : (v) => setState(() => _method = v ?? '')),
        const SizedBox(height: 24),
        TextField(controller: _evidence, enabled: !_saving, maxLength: 160, decoration: const InputDecoration(labelText: 'Protected evidence reference'), onChanged: (_) => setState(() {})),
        const Text('Separate opaque references: letters, digits, period, underscore, colon or hyphen; at least 3 characters. No uploads, document links, images or sensitive document contents.'),
        const SizedBox(height: 24),
        TextField(controller: _notes, enabled: !_saving, maxLength: 600, minLines: 3, maxLines: 5, decoration: const InputDecoration(labelText: 'Verification notes (20–600 characters)'), onChanged: (_) => setState(() {})),
        CheckboxListTile(contentPadding: EdgeInsets.zero, value: _consent, onChanged: _saving ? null : (v) => setState(() => _consent = v == true), title: const Text('I attest that the Resident explicitly requested and consented to deletion; protected evidence is recorded.')),
      ],
      if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
      if (_saving) const Column(children: [LinearProgressIndicator(), Text('Saving confirmation…')]),
    ]))),
    actions: [TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('Close')),
      FilledButton(onPressed: _saving || !_scopeCurrent || (widget.request == null ? !_validIntake : !_validVerification) ? null : _submit,
        child: Text(_saving ? 'Saving…' : widget.request == null ? 'Save pending intake' : 'Confirm identity and consent'))],
  ));
}
