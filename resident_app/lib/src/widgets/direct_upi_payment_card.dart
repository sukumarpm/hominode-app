import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/resident_direct_upi_service.dart';

typedef PrepareDirectUpiPayment =
    Future<DirectUpiPaymentPreparation> Function(
      String billId,
      int? submittedAmountMinor,
      bool allowFlexibleAmounts,
    );
typedef LaunchDirectUpiPayment = Future<bool> Function(Uri uri);
typedef SubmitDirectUpiProof = Future<void> Function();
typedef SubmitPreparedDirectUpiProof =
    Future<void> Function(DirectUpiPaymentPreparation preparation);

class DirectUpiPaymentCard extends StatefulWidget {
  const DirectUpiPaymentCard({
    super.key,
    required this.billId,
    required this.onSubmitProof,
    this.onSubmitPreparedProof,
    this.preparePayment,
    this.launchPayment,
    this.flexibleAmountsEnabled = flexibleResidentV2PaymentAmountsEnabled,
  });

  final String billId;
  final SubmitDirectUpiProof onSubmitProof;
  final SubmitPreparedDirectUpiProof? onSubmitPreparedProof;
  final PrepareDirectUpiPayment? preparePayment;
  final LaunchDirectUpiPayment? launchPayment;
  final bool flexibleAmountsEnabled;

  @override
  State<DirectUpiPaymentCard> createState() => _DirectUpiPaymentCardState();
}

class _DirectUpiPaymentCardState extends State<DirectUpiPaymentCard> {
  bool _isBusy = false;
  bool _hasAttemptedUpi = false;
  static const _upiChannel = MethodChannel('hominode/upi');
  String? _returnedReference;
  String? _returnedStatus;

  Future<bool> _launchUpi(Uri uri) async {
    if (widget.launchPayment != null) return widget.launchPayment!(uri);
    if (!Platform.isAndroid) return _launchExternally(uri);
    try {
      final result = await _upiChannel.invokeMapMethod<String, dynamic>(
        'launchPayment',
        {'uri': uri.toString()},
      );
      // The callback is an untrusted hint; the bank remains the authority.
      final raw = result?['response']?.toString() ?? '';
      Map<String, String> fields = {};
      try {
        fields = Uri.splitQueryString(raw, encoding: utf8);
      } catch (_) {
        // A malformed or absent callback is not evidence of failure.
      }
      final normalized = <String, String>{
        for (final entry in fields.entries) entry.key.toLowerCase(): entry.value,
      };
      final explicitRef = result?['reference']?.toString().trim() ?? '';
      final ref = (explicitRef.isNotEmpty
          ? explicitRef
          : (normalized['txnid'] ?? normalized['approvalrefno'] ?? normalized['txnref'] ?? '')).trim();
      _returnedReference = ref.isNotEmpty && ref.length <= 200 ? ref : null;
      final explicitStatus = result?['status']?.toString().trim() ?? '';
      _returnedStatus = (explicitStatus.isNotEmpty
          ? explicitStatus : normalized['status'])?.trim().toLowerCase();
      return true;
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    }
  }


  Future<void> _payViaUpi() async {
    if (_isBusy) return;
    if (_hasAttemptedUpi && !await _confirmRetry()) return;
    if (!mounted) return;

    setState(() => _isBusy = true);
    try {
      final prepare =
          widget.preparePayment ??
          (String id, int? amount, bool flexible) =>
              ResidentDirectUpiService().preparePayment(
                id,
                submittedAmountMinor: amount,
                allowFlexibleAmounts: flexible,
              );
      final initial = await prepare(widget.billId, null, false);
      if (!mounted) return;
      final selectedAmount = await _selectAmount(initial);
      if (selectedAmount == null || !mounted) return;
      final preparation =
          selectedAmount == initial.paymentAmountMinor &&
              !widget.flexibleAmountsEnabled
          ? initial
          : await prepare(
              widget.billId,
              selectedAmount,
              widget.flexibleAmountsEnabled,
            );
      if (!mounted) return;

      var launched = false;
      _hasAttemptedUpi = true;
      _returnedReference = null;
      _returnedStatus = null;
      try {
        launched = await _launchUpi(preparation.paymentUri);
      } catch (_) {
        // Launcher details are intentionally hidden; the manual fallback is
        // safe for both unsupported URI handlers and platform exceptions.
      }
      if (!mounted) return;

      if (launched) {
        // launchUrl only confirms the app was opened. It is not a payment
        // result. The dialog remains available when Hominode resumes.
        await _confirmAfterExternalApp(preparation);
      } else {
        final shouldSubmitProof = await _showManualFallback(preparation);
        if (shouldSubmitProof && mounted) {
          await _submitProof(preparation);
        }
      }
    } on ResidentDirectUpiException catch (error) {
      if (mounted) _showMessage(error.message);
    } catch (_) {
      if (mounted) {
        _showMessage('upi_start_error'.tr());
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  static const _retrySafety =
      'Before retrying, check your UPI app and bank account to confirm '
      'that no amount was deducted. If the status is uncertain, do not '
      'pay again until you confirm.';

  Future<bool> _confirmRetry() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Check deduction before retrying'),
        content: const Text(_retrySafety),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Do not retry'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('I checked — retry UPI'),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<void> _confirmAfterExternalApp(
    DirectUpiPaymentPreparation preparation,
  ) async {
    while (mounted) {
      // Some UPI apps cannot return a transaction status via url_launcher.
      // Never infer success from a successful launch or app resume.
      final action = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Check your UPI payment'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'If payment completed, select I Have Paid to request community '
                'bank verification. The bill remains unpaid until Admin confirms '
                'the bank credit. If cancelled or uncertain, check for a '
                'deduction before retrying.',
              ),
              if (_returnedStatus != null && _returnedStatus!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('UPI app returned: ${_returnedStatus!} (unverified)'),
              ],
              if (_returnedReference != null) ...[
                const SizedBox(height: 6),
                SelectableText('UPI app reference: ${_returnedReference!}'),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, 'later'),
              child: const Text('Not paid / Check later'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, 'retry'),
              child: const Text('Retry payment'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, 'paid'),
              child: const Text('I Have Paid'),
            ),
          ],
        ),
      );
      if (!mounted || action == 'later' || action == null) return;
      if (action == 'paid') {
        final captured = _returnedReference;
        await _submitProof(captured == null
            ? preparation
            : preparation.withCallbackReference(captured));
        return;
      }
      if (action == 'retry') {
        if (!await _confirmRetry() || !mounted) continue;
        try {
          _returnedReference = null;
          _returnedStatus = null;
          final opened = await _launchUpi(preparation.paymentUri);
          if (!mounted) return;
          if (!opened) {
            final manual = await _showManualFallback(preparation);
            if (manual && mounted) await _submitProof(preparation);
            return;
          }
        } catch (_) {
          if (!mounted) return;
          final manual = await _showManualFallback(preparation);
          if (manual && mounted) await _submitProof(preparation);
          return;
        }
      }
    }
  }

  Future<void> _submitProof(DirectUpiPaymentPreparation preparation) async {
    final submit = widget.onSubmitPreparedProof;
    if (submit != null) {
      await submit(preparation);
    } else {
      await widget.onSubmitProof();
    }
  }

  Future<int?> _selectAmount(DirectUpiPaymentPreparation preparation) async {
    final controller = TextEditingController(
      text: _inrText(
        preparation.paymentAmountMinor ??
            preparation.outstandingAmountMinor ??
            0,
      ),
    );
    String? error;
    try {
      return await showDialog<int>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            backgroundColor: const Color(0xFFFBFCFE),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: const BorderSide(color: Colors.white, width: 1.2),
            ),
            title: Text('payment_amount_title'.tr()),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${'selected_bill_outstanding'.tr()}: ₹${_inrText(preparation.outstandingAmountMinor ?? 0)}',
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  enabled: widget.flexibleAmountsEnabled,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'payment_amount_inr'.tr(),
                    prefixText: '₹',
                    errorText: error,
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFDCE5EF)),
                    ),
                  ),
                  onChanged: (_) => setDialogState(() => error = null),
                ),
                const SizedBox(height: 8),
                if (widget.flexibleAmountsEnabled)
                  Text('excess_credit_info'.tr()),
                Text('upi_return_not_confirm'.tr()),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text('cancel'.tr()),
              ),
              FilledButton(
                onPressed: () {
                  final amount = parseResidentInrMinorUnits(controller.text);
                  if (amount == null ||
                      (!widget.flexibleAmountsEnabled &&
                          amount != preparation.outstandingAmountMinor)) {
                    setDialogState(() => error = 'invalid_inr_amount'.tr());
                    return;
                  }
                  Navigator.pop(dialogContext, amount);
                },
                child: Text('continue'.tr()),
              ),
            ],
          ),
        ),
      );
    } finally {
      controller.dispose();
    }
  }

  String _inrText(int? minor) {
    final value = minor ?? 0;
    return '${value ~/ 100}.${(value % 100).toString().padLeft(2, '0')}';
  }

  Future<bool> _showManualFallback(
    DirectUpiPaymentPreparation preparation,
  ) async {
    final submitProof = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('upi_open_failed'.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('upi_manual_instructions'.tr()),
            const SizedBox(height: 16),
            Text('payee_name'.tr()),
            SelectableText(preparation.payeeName),
            const SizedBox(height: 8),
            Text('upi_id'.tr()),
            SelectableText(preparation.vpa),
            const SizedBox(height: 8),
            Text('exact_amount'.tr()),
            Text('₹${preparation.amount.toStringAsFixed(2)}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('close'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text('submit_payment_proof'.tr()),
          ),
        ],
      ),
    );
    return submitProof ?? false;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<bool> _launchExternally(Uri uri) =>
      launchUrl(uri, mode: LaunchMode.externalApplication);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .94),
        borderRadius: BorderRadius.circular(23),
        border: Border.all(color: Colors.white, width: 1.3),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF082F73).withValues(alpha: .07),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'UPI / Direct UPI',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            'Pay your bill directly to your community using a UPI app.',
          ),
          const SizedBox(height: 6),
          const Text(
            'No Hominode payment fee. Payment goes to your community.',
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isBusy ? null : _payViaUpi,
              icon: _isBusy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.account_balance_wallet_outlined),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF243143),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              label: Text(
                _isBusy ? 'preparing_payment'.tr() : 'pay_via_upi'.tr(),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: TextButton(
              onPressed: _isBusy ? null : widget.onSubmitProof,
              child: Text('already_paid_submit_proof'.tr()),
            ),
          ),
        ],
      ),
    );
  }
}
