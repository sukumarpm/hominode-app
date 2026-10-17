import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'src/services/bill_firestore_service.dart';
import 'src/utils/payment_method.dart';
import 'src/widgets/resident_visitor_page_background.dart';

class PaymentHistoryScreen extends StatelessWidget {
  const PaymentHistoryScreen({super.key, required this.paidBills});

  final List<Map<String, dynamic>> paidBills;

  @override
  Widget build(BuildContext context) {
    final history = List<Map<String, dynamic>>.of(paidBills)
      ..sort(_newestPaymentFirst);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FD),
      appBar: AppBar(
        backgroundColor: Colors.white.withValues(alpha: .82),
        foregroundColor: const Color(0xFF0E2247),
        elevation: 0,
        title: Text('payment_history'.tr()),
      ),
      body: ResidentVisitorPageBackground(
        child: history.isEmpty
            ? Center(child: Text('no_payment_history'.tr()))
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: history.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) =>
                    _PaymentHistoryCard(bill: history[index]),
              ),
      ),
    );
  }
}

class _PaymentHistoryCard extends StatelessWidget {
  const _PaymentHistoryCard({required this.bill});

  final Map<String, dynamic> bill;

  @override
  Widget build(BuildContext context) {
    final paidAt = _dateFrom(bill['paidAt']);
    final isV2 = BillFirestoreService.isV2Bill(bill);
    final amount = bill['amount'] as num?;
    final billId = _nonEmptyString(bill['id']);
    final month = _nonEmptyString(bill['month']);
    final year = _nonEmptyString(bill['year']);
    final status = _nonEmptyString(bill['status']);
    final paymentReference =
        _nonEmptyString(bill['paymentReference']) ??
        _nonEmptyString(bill['transactionId']);
    final paymentMethod = normalizePaymentMethod(bill['paymentMethod']);
    final billingPeriod = _displayBillingPeriod(
      bill['billingPeriod'],
      context.locale.toString(),
    );
    final period = isV2
        ? billingPeriod ?? 'paid_bill'.tr()
        : [if (month != null) month, if (year != null) year].join(' ');
    final amountText = isV2
        ? BillFirestoreService.formatV2BillMinorUnits(bill, bill['amountMinor'])
        : amount == null
        ? null
        : '₹${amount.toDouble().toStringAsFixed(2)}';

    return Card(
      margin: EdgeInsets.zero,
      color: Colors.white.withValues(alpha: .94),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: Colors.white, width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.check_circle, color: Color(0xFF12B76A)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    period.isNotEmpty ? period : 'paid_bill'.tr(),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (amountText != null)
                  Text(
                    amountText,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _DetailRow(
              label: 'payment_date'.tr(),
              value: paidAt == null
                  ? 'not_recorded'.tr()
                  : _formatDate(paidAt, context.locale.toString()),
            ),
            _DetailRow(
              label: 'payment_method'.tr(),
              value: _localizedPaymentMethod(paymentMethod),
            ),
            if (billId != null)
              _DetailRow(label: 'bill_reference'.tr(), value: billId),
            _DetailRow(
              label: 'status'.tr(),
              value: status == null
                  ? 'not_recorded'.tr()
                  : _localizedPaymentStatus(status),
            ),
            if (paymentReference != null)
              _DetailRow(
                label: 'payment_reference'.tr(),
                value: paymentReference,
              ),
          ],
        ),
      ),
    );
  }
}

String? _displayBillingPeriod(Object? value, String locale) {
  if (value is! String || !RegExp(r'^\d{4}-(0[1-9]|1[0-2])$').hasMatch(value)) {
    return null;
  }
  final pieces = value.split('-');
  return DateFormat.yMMMM(
    locale,
  ).format(DateTime(int.parse(pieces[0]), int.parse(pieces[1])));
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 124,
            child: Text(
              label,
              style: const TextStyle(color: Color(0xFF7A7A7A)),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

int _newestPaymentFirst(
  Map<String, dynamic> first,
  Map<String, dynamic> second,
) {
  final firstDate = _dateFrom(first['paidAt']);
  final secondDate = _dateFrom(second['paidAt']);
  if (firstDate == null && secondDate == null) return 0;
  if (firstDate == null) return 1;
  if (secondDate == null) return -1;
  return secondDate.compareTo(firstDate);
}

DateTime? _dateFrom(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}

String? _nonEmptyString(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

String _formatDate(DateTime date, String locale) {
  return DateFormat.yMMMd(locale).format(date);
}

String _localizedPaymentMethod(String label) => switch (label) {
  'UPI' => 'UPI',
  'Cash' => 'cash'.tr(),
  'Bank Transfer' => 'bank_transfer'.tr(),
  'Cheque' => 'cheque'.tr(),
  'Manual' => 'manual'.tr(),
  'External' => 'external'.tr(),
  'Not recorded' => 'not_recorded'.tr(),
  _ => label,
};

String _localizedPaymentStatus(String status) {
  final key = switch (status.toLowerCase()) {
    'paid' || 'settled' => 'paid',
    'pending' => 'pending',
    'partially_paid' => 'partially_paid',
    'overdue' => 'overdue',
    'rejected' || 'failed' => 'rejected',
    'cancelled' || 'canceled' => 'cancelled',
    _ => null,
  };
  return key == null ? status : key.tr();
}
