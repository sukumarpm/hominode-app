import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/resident_direct_upi_service.dart';

typedef PrepareDirectUpiPayment =
    Future<DirectUpiPaymentPreparation> Function(String billId);
typedef LaunchDirectUpiPayment = Future<bool> Function(Uri uri);
typedef SubmitDirectUpiProof = Future<void> Function();

class DirectUpiPaymentCard extends StatefulWidget {
  const DirectUpiPaymentCard({
    super.key,
    required this.billId,
    required this.onSubmitProof,
    this.preparePayment,
    this.launchPayment,
  });

  final String billId;
  final SubmitDirectUpiProof onSubmitProof;
  final PrepareDirectUpiPayment? preparePayment;
  final LaunchDirectUpiPayment? launchPayment;

  @override
  State<DirectUpiPaymentCard> createState() => _DirectUpiPaymentCardState();
}

class _DirectUpiPaymentCardState extends State<DirectUpiPaymentCard> {
  bool _isBusy = false;

  Future<void> _payViaUpi() async {
    if (_isBusy) return;

    setState(() => _isBusy = true);
    try {
      final preparation =
          await (widget.preparePayment ??
              ResidentDirectUpiService().preparePayment)(widget.billId);
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
        await widget.onSubmitProof();
      } else {
        final shouldSubmitProof = await _showManualFallback(preparation);
        if (shouldSubmitProof && mounted) {
          await widget.onSubmitProof();
        }
      }
    } on ResidentDirectUpiException catch (error) {
      if (mounted) _showMessage(error.message);
    } catch (_) {
      if (mounted) {
        _showMessage('UPI payment could not be started. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<bool> _showManualFallback(
    DirectUpiPaymentPreparation preparation,
  ) async {
    final submitProof = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Unable to open a UPI app automatically.'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Open your preferred UPI app and pay the exact amount using these details.',
            ),
            const SizedBox(height: 16),
            const Text('Payee name'),
            SelectableText(preparation.payeeName),
            const SizedBox(height: 8),
            const Text('UPI ID'),
            SelectableText(preparation.vpa),
            const SizedBox(height: 8),
            const Text('Exact amount'),
            Text('₹${preparation.amount.toStringAsFixed(2)}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Close'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Submit payment proof'),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE6E6E6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Payment', style: Theme.of(context).textTheme.titleMedium),
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
              label: Text(_isBusy ? 'Preparing payment…' : 'Pay via UPI'),
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: TextButton(
              onPressed: _isBusy ? null : widget.onSubmitProof,
              child: const Text('Already paid? Submit payment proof'),
            ),
          ),
        ],
      ),
    );
  }
}
