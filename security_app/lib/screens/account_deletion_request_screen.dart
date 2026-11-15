import 'package:flutter/material.dart';
import '../services/account_deletion_request_service.dart';
import '../utils/app_colors.dart';

class SecurityAccountDeletionRequestScreen extends StatefulWidget {
  const SecurityAccountDeletionRequestScreen({super.key, this.requests});
  final SecurityDeletionRequests? requests;

  @override
  State<SecurityAccountDeletionRequestScreen> createState() =>
      _SecurityAccountDeletionRequestScreenState();
}

class _SecurityAccountDeletionRequestScreenState
    extends State<SecurityAccountDeletionRequestScreen> {
  late final SecurityDeletionRequests _requests =
      widget.requests ?? SecurityAccountDeletionRequestService();
  SecurityDeletionStatus? _status;
  bool _loading = true, _submitting = false, _confirmed = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final status = await _requests.status();
      if (mounted) setState(() => _status = status);
    } catch (error) {
      if (mounted) setState(() => _error = securityDeletionError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    if (_submitting ||
        _loading ||
        !_confirmed ||
        _status == null ||
        _status!.submitted) {
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final status = await _requests.submit();
      if (!status.submitted || status.reference == null) {
        throw const FormatException('Unconfirmed request');
      }
      if (mounted) setState(() => _status = status);
    } catch (error) {
      if (mounted) setState(() => _error = securityDeletionError(error));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final submitted = _status?.submitted == true;
    return PopScope(
      canPop: !_submitting,
      child: Scaffold(
        appBar: AppBar(title: const Text('Account deletion')),
        body: SafeArea(
          child: SingleChildScrollView(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Request a review of your Security account',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'This request is for your signed-in Security account only. Your community will review it and may contact you on your registered phone number. Your account will not be deleted immediately.',
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Submitting a request does not change your account or shift assignments, or delete security history, audit records, gate logs or incident records. These require review before any action is taken.',
                      ),
                      const SizedBox(height: 20),
                      if (_loading)
                        const Center(child: CircularProgressIndicator())
                      else if (_status != null) ...[
                        Text(
                          'Community: ${_status!.communityName}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 16),
                        if (submitted) ...[
                          const Text(
                            'Request submitted for review',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryTeal,
                            ),
                          ),
                          const SizedBox(height: 12),
                          SelectableText('Reference: ${_status!.reference}'),
                          const SizedBox(height: 12),
                          const Text(
                            'Your community has been notified. Keep this reference for follow-up. This confirms receipt of your request, not deletion of your account.',
                          ),
                        ] else ...[
                          if (_status!.reference != null) ...[
                            SelectableText(
                              'Saved reference: ${_status!.reference}',
                            ),
                            const Text(
                              'Submission has not been confirmed. You can retry using this reference.',
                            ),
                          ],
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            value: _confirmed,
                            onChanged: _submitting
                                ? null
                                : (value) => setState(
                                    () => _confirmed = value == true,
                                  ),
                            controlAffinity: ListTileControlAffinity.leading,
                            title: const Text(
                              'I request account deletion review and understand that my account will not be deleted immediately.',
                            ),
                          ),
                        ],
                      ],
                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            _error!,
                            style: const TextStyle(color: AppColors.errorRed),
                          ),
                        ),
                        if (_status == null)
                          TextButton(
                            onPressed: _loading ? null : _load,
                            child: const Text('Try again'),
                          ),
                      ],
                      const SizedBox(height: 20),
                      if (!submitted && _status != null)
                        FilledButton(
                          onPressed: _submitting || _loading || !_confirmed
                              ? null
                              : _submit,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: _submitting
                                ? const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                      SizedBox(width: 10),
                                      Flexible(child: Text('Submitting…')),
                                    ],
                                  )
                                : const Text('Submit deletion request'),
                          ),
                        ),
                      TextButton(
                        onPressed: _submitting
                            ? null
                            : () => Navigator.of(context).pop(),
                        child: Text(submitted ? 'Done' : 'Cancel'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
