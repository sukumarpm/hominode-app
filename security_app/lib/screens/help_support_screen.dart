import 'package:flutter/material.dart';
import '../services/support_request_service.dart';
import '../utils/app_colors.dart';

class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({
    super.key,
    this.requests,
    this.initialTopic = 'technical_issue',
  });
  final SecuritySupportRequests? requests;
  final String initialTopic;
  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  late final SecuritySupportRequests _requests =
      widget.requests ?? SecuritySupportRequestService();
  late String _topic = securitySupportTopics.containsKey(widget.initialTopic)
      ? widget.initialTopic
      : 'technical_issue';
  final _message = TextEditingController();
  final _form = GlobalKey<FormState>();
  String _requestKey = newSecuritySupportRequestKey();
  String? _community, _error;
  SecuritySupportReceipt? _receipt;
  bool _loading = true, _sending = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final community = await _requests.communityName();
      if (mounted) setState(() => _community = community);
    } catch (error) {
      if (mounted) setState(() => _error = securitySupportError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _edited() => _requestKey = newSecuritySupportRequestKey();
  Future<void> _submit() async {
    if (_sending ||
        _loading ||
        _community == null ||
        !_form.currentState!.validate()) {
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final receipt = await _requests.submit(
        topic: _topic,
        message: _message.text.trim(),
        requestKey: _requestKey,
      );
      if (mounted) setState(() => _receipt = receipt);
    } catch (error) {
      if (mounted) setState(() => _error = securitySupportError(error));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_sending,
    child: Scaffold(
      appBar: AppBar(title: const Text('Help & Support')),
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
                      'How can we help?',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Your Community Admin manages registered phone-number changes, gate and shift assignments, account provisioning and access issues.',
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'App and other support requests go to Hominode Support. Your signed-in Security identity and verified community are included automatically. Never include OTPs or sensitive visitor details.',
                    ),
                    const SizedBox(height: 20),
                    if (_loading)
                      const Center(child: CircularProgressIndicator())
                    else if (_community != null) ...[
                      Text(
                        'Community: $_community',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 16),
                      if (_receipt != null) ...[
                        const Text(
                          'Request sent',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryTeal,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _receipt!.destination == 'community_admin'
                              ? 'Your request is available in your Community Admin’s Notifications. They can contact you on your registered phone number.'
                              : 'Your request has been sent to Hominode Support. Support can contact you on your registered phone number.',
                        ),
                        const SizedBox(height: 12),
                        SelectableText('Reference: ${_receipt!.reference}'),
                      ] else
                        Form(
                          key: _form,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              DropdownButtonFormField<String>(
                                initialValue: _topic,
                                isExpanded: true,
                                isDense: false,
                                itemHeight: null,
                                decoration: const InputDecoration(
                                  labelText: 'What do you need help with?',
                                  border: OutlineInputBorder(),
                                ),
                                items: securitySupportTopics.entries
                                    .map(
                                      (topic) => DropdownMenuItem(
                                        value: topic.key,
                                        child: Text(
                                          topic.value,
                                          softWrap: true,
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: _sending
                                    ? null
                                    : (value) {
                                        if (value != null) {
                                          setState(() {
                                            _topic = value;
                                            _edited();
                                          });
                                        }
                                      },
                              ),
                              const SizedBox(height: 12),
                              Text(
                                securityTopicGoesToAdmin(_topic)
                                    ? 'Send to: Community Admin'
                                    : 'Send to: Hominode Support',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _message,
                                enabled: !_sending,
                                minLines: 4,
                                maxLines: 8,
                                maxLength: 2000,
                                decoration: const InputDecoration(
                                  labelText: 'Describe your issue',
                                  alignLabelWithHint: true,
                                  errorMaxLines: 3,
                                  border: OutlineInputBorder(),
                                ),
                                onChanged: (_) => _edited(),
                                validator: (value) =>
                                    (value?.trim().length ?? 0) < 10
                                    ? 'Describe the issue in at least 10 characters.'
                                    : null,
                              ),
                              const SizedBox(height: 16),
                              FilledButton(
                                onPressed: _sending ? null : _submit,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  child: _sending
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
                                            Flexible(child: Text('Sending…')),
                                          ],
                                        )
                                      : const Text('Send request'),
                                ),
                              ),
                            ],
                          ),
                        ),
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
                      if (_community == null)
                        TextButton(
                          onPressed: _loading ? null : _load,
                          child: const Text('Try again'),
                        ),
                    ],
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _sending
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: Text(_receipt == null ? 'Cancel' : 'Done'),
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
