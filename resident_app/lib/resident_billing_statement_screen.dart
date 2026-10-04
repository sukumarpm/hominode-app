import 'package:flutter/material.dart';

import 'src/services/bill_firestore_service.dart';
import 'src/services/resident_billing_statement_service.dart';
import 'src/utils/payment_method.dart';

class ResidentBillingStatementScreen extends StatefulWidget {
  const ResidentBillingStatementScreen({super.key, this.service, this.now});

  final ResidentBillingStatementService? service;
  final DateTime Function()? now;

  @override
  State<ResidentBillingStatementScreen> createState() =>
      _ResidentBillingStatementScreenState();
}

class _ResidentBillingStatementScreenState
    extends State<ResidentBillingStatementScreen> {
  late final ResidentBillingStatementService _service =
      widget.service ?? ResidentBillingStatementService();
  late DateTime _selectedMonth;
  ResidentBillingStatement? _statement;
  bool _loading = true;
  bool _failed = false;
  int _requestGeneration = 0;

  @override
  void initState() {
    super.initState();
    final now = widget.now?.call() ?? DateTime.now();
    _selectedMonth = DateTime(now.year, now.month);
    _loadStatement();
  }

  String get _billingPeriod =>
      '${_selectedMonth.year.toString().padLeft(4, '0')}-${_selectedMonth.month.toString().padLeft(2, '0')}';

  Future<void> _loadStatement() async {
    final generation = ++_requestGeneration;
    final period = _billingPeriod;
    setState(() {
      _statement = null;
      _failed = false;
      _loading = true;
    });
    try {
      final result = await _service.getStatement(period);
      if (!mounted || generation != _requestGeneration) return;
      setState(() {
        _statement = result;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || generation != _requestGeneration) return;
      setState(() {
        _failed = true;
        _loading = false;
      });
    }
  }

  void _changeMonth(int delta) {
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + delta,
      );
      _statement = null;
      _failed = false;
      _loading = true;
    });
    _loadStatement();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0E4778),
        foregroundColor: Colors.white,
        title: const Text('Monthly Statement'),
      ),
      body: Column(
        children: [
          _monthSelector(),
          Expanded(child: _statementBody()),
        ],
      ),
    );
  }

  Widget _monthSelector() => Padding(
    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          key: const ValueKey('statement-previous-month'),
          tooltip: 'Previous month',
          onPressed: () => _changeMonth(-1),
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: Text(
            _monthLabel(_selectedMonth),
            key: const ValueKey('statement-selected-month'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
        ),
        IconButton(
          key: const ValueKey('statement-next-month'),
          tooltip: 'Next month',
          onPressed: () => _changeMonth(1),
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    ),
  );

  Widget _statementBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(key: ValueKey('statement-loading')),
      );
    }
    if (_failed) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 40, color: Colors.red),
              const SizedBox(height: 12),
              const Text(ResidentBillingStatementService.safeErrorMessage),
              const SizedBox(height: 12),
              TextButton(
                key: const ValueKey('statement-retry'),
                onPressed: _loadStatement,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    final statement = _statement;
    if (statement == null) return const SizedBox.shrink();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        _summaryCard(statement.summary),
        const SizedBox(height: 12),
        if (statement.bills.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('No bills for this period.')),
            ),
          )
        else
          ...statement.bills.map(_billCard),
      ],
    );
  }

  Widget _summaryCard(ResidentBillingStatementSummary summary) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Statement Summary',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          _moneyRow('Total billed', summary.billedMinor),
          _moneyRow('Payments applied', summary.paidAllocationMinor),
          _moneyRow('Credit applied', summary.creditAppliedMinor),
          _moneyRow('Outstanding', summary.outstandingMinor),
          _moneyRow(
            'Current available credit',
            summary.availableCreditMinor,
            note: 'Account-level balance',
          ),
          const Divider(height: 24),
          const Text(
            'Bill status counts',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          _countRow('Pending', summary.statusCounts['pending']!),
          _countRow('Partially paid', summary.statusCounts['partially_paid']!),
          _countRow('Paid', summary.statusCounts['paid']!),
          _countRow('Overdue', summary.statusCounts['overdue']!),
        ],
      ),
    ),
  );

  Widget _billCard(ResidentStatementBill bill) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _monthLabel(_parsePeriod(bill.billingPeriod)),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(_titleCase(bill.status)),
            ],
          ),
          const SizedBox(height: 10),
          _moneyRow('Total', bill.amountMinor),
          _moneyRow('Payment allocations', bill.paidAllocationMinor),
          _moneyRow('Credit applied', bill.creditAppliedMinor),
          _moneyRow('Outstanding', bill.outstandingMinor),
          _detailRow('Due date', _formatDateKey(bill.dueDateKey)),
          const Divider(height: 24),
          const Text(
            'Charge lines',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          ...bill.chargeLines.map(
            (line) => _moneyRow(line.label, line.amountMinor),
          ),
          const Divider(height: 24),
          const Text(
            'Settlements',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          if (bill.settlements.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('No payment allocations'),
            )
          else
            ...bill.settlements.map(_settlement),
        ],
      ),
    ),
  );

  Widget _settlement(ResidentStatementSettlement settlement) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _moneyRow(
          normalizePaymentMethod(settlement.method),
          settlement.netAppliedMinor,
        ),
        _detailRow(
          'Received',
          _formatDate(
            DateTime.fromMillisecondsSinceEpoch(settlement.receivedAt),
          ),
        ),
        if (settlement.reference != null &&
            settlement.reference!.trim().isNotEmpty)
          _detailRow('Payment reference', settlement.reference!.trim()),
      ],
    ),
  );

  Widget _moneyRow(String label, int amountMinor, {String? note}) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Text(note == null ? label : '$label ($note)')),
        const SizedBox(width: 12),
        Text(BillFirestoreService.formatInrMinorUnits(amountMinor)),
      ],
    ),
  );

  Widget _countRow(String label, int count) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        Text('$count'),
      ],
    ),
  );

  Widget _detailRow(String label, String value) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 105,
          child: Text(label, style: const TextStyle(color: Color(0xFF7A7A7A))),
        ),
        Expanded(child: Text(value)),
      ],
    ),
  );
}

DateTime _parsePeriod(String period) {
  final parts = period.split('-');
  return DateTime(int.parse(parts[0]), int.parse(parts[1]));
}

String _monthLabel(DateTime month) {
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
  return '${months[month.month - 1]} ${month.year}';
}

String _formatDateKey(String value) {
  final parts = value.split('-').map(int.parse).toList();
  return _formatDate(DateTime(parts[0], parts[1], parts[2]));
}

String _formatDate(DateTime date) =>
    '${_monthShort(date.month)} ${date.day}, ${date.year}';

String _monthShort(int month) => const [
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
][month - 1];

String _titleCase(String value) => value
    .split('_')
    .map(
      (part) =>
          part.isEmpty ? part : '${part[0].toUpperCase()}${part.substring(1)}',
    )
    .join(' ');
