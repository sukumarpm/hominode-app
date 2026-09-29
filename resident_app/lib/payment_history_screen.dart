import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'src/services/bill_firestore_service.dart';
import 'src/utils/payment_method.dart';

class PaymentHistoryScreen extends StatelessWidget {
  const PaymentHistoryScreen({super.key, required this.paidBills});

  final List<Map<String, dynamic>> paidBills;

  @override
  Widget build(BuildContext context) {
    final history = List<Map<String, dynamic>>.of(paidBills)
      ..sort(_newestPaymentFirst);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0E4778),
        foregroundColor: Colors.white,
        title: const Text('Payment History'),
      ),
      body: history.isEmpty
          ? const Center(child: Text('No payment history'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: history.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) =>
                  _PaymentHistoryCard(bill: history[index]),
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
    final billingPeriod = _displayBillingPeriod(bill['billingPeriod']);
    final period = isV2
        ? billingPeriod ?? 'Paid bill'
        : [if (month != null) month, if (year != null) year].join(' ');
    final amountText = isV2
        ? BillFirestoreService.formatV2BillMinorUnits(bill, bill['amountMinor'])
        : amount == null
        ? null
        : '₹${amount.toDouble().toStringAsFixed(2)}';

    return Card(
      margin: EdgeInsets.zero,
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
                    period.isNotEmpty ? period : 'Paid bill',
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
              label: 'Payment date',
              value: paidAt == null ? 'Not recorded' : _formatDate(paidAt),
            ),
            _DetailRow(label: 'Payment method', value: paymentMethod),
            if (billId != null)
              _DetailRow(label: 'Bill reference', value: billId),
            _DetailRow(
              label: 'Status',
              value: status == null ? 'Not recorded' : _titleCase(status),
            ),
            if (paymentReference != null)
              _DetailRow(label: 'Payment reference', value: paymentReference),
          ],
        ),
      ),
    );
  }
}

String? _displayBillingPeriod(Object? value) {
  if (value is! String || !RegExp(r'^\d{4}-(0[1-9]|1[0-2])$').hasMatch(value)) {
    return null;
  }
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  final pieces = value.split('-');
  return '${months[int.parse(pieces[1]) - 1]} ${pieces[0]}';
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

String _formatDate(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}

String _titleCase(String value) {
  return '${value[0].toUpperCase()}${value.substring(1).toLowerCase()}';
}
