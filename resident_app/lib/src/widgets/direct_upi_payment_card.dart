import 'package:flutter/material.dart';
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

  Future<void> _payViaUpi() async {
    if (_isBusy) return;

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
      try {
        launched = await (widget.launchPayment ?? _launchExternally)(
          preparation.paymentUri,
        );
      } catch (_) {
        // Launcher details are intentionally hidden; the manual fallback is
        // safe for both unsupported URI handlers and platform exceptions.
      }
      if (!mounted) return;

      if (launched) {
        await _submitProof(preparation);
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
