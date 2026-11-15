import 'package:flutter/material.dart';
import '../services/post_firestore_service.dart';

Future<void> showWallReportDialog(
  BuildContext context, {
  required String targetLabel,
  required Future<ServiceResult> Function(String reason) submit,
}) async {
  final message = await showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (_) => WallReportDialog(targetLabel: targetLabel, submit: submit),
  );
  if (context.mounted && message != null) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class WallReportDialog extends StatefulWidget {
  const WallReportDialog({
    super.key,
    required this.targetLabel,
    required this.submit,
  });
  final String targetLabel;
  final Future<ServiceResult> Function(String reason) submit;
  @override
  State<WallReportDialog> createState() => _WallReportDialogState();
}

class _WallReportDialogState extends State<WallReportDialog> {
  static const reasons = [
    'Inappropriate content',
    'Harassment or bullying',
    'Spam',
    'Other',
  ];
  final _explanation = TextEditingController();
  String _reason = reasons.first;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _explanation.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final explanation = _explanation.text.trim();
      final result = await widget.submit(
        explanation.isEmpty ? _reason : '$_reason: $explanation',
      );
      if (!mounted) return;
      if (result.success) {
        Navigator.pop(context, result.message ?? 'Report submitted');
      } else {
        setState(
          () => _error =
              result.message ?? 'Unable to submit this report. Please retry.',
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = PostFirestoreService.reportErrorMessage(error));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      title: Text('Report ${widget.targetLabel}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _reason,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Reason'),
              items: reasons
                  .map(
                    (reason) =>
                        DropdownMenuItem(value: reason, child: Text(reason)),
                  )
                  .toList(),
              onChanged: _busy
                  ? null
                  : (value) => setState(() => _reason = value!),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _explanation,
              enabled: !_busy,
              maxLength: 450,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Additional explanation (optional)',
                alignLabelWithHint: true,
              ),
            ),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            if (_busy)
              const Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: Text(_busy ? 'Reporting...' : 'Report'),
        ),
      ],
    ),
  );
}
