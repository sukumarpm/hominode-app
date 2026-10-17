import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

import 'receipt_screen.dart';
import 'src/services/bill_firestore_service.dart';
import 'src/services/resident_billing_statement_service.dart';
import 'src/services/resident_billing_v2_receipt_service.dart';
import 'src/utils/payment_method.dart';
import 'src/widgets/resident_visitor_page_background.dart';

class ResidentBillingStatementScreen extends StatefulWidget {
  const ResidentBillingStatementScreen({
    super.key,
    this.service,
    this.receiptService,
    this.now,
  });

  final ResidentBillingStatementService? service;
  final ResidentBillingV2ReceiptService? receiptService;
  final DateTime Function()? now;

  @override
  State<ResidentBillingStatementScreen> createState() =>
      _ResidentBillingStatementScreenState();
}

class _ResidentBillingStatementScreenState
    extends State<ResidentBillingStatementScreen> {
  late final ResidentBillingStatementService _service =
      widget.service ?? ResidentBillingStatementService();
  late final ResidentBillingV2ReceiptService _receiptService =
      widget.receiptService ?? ResidentBillingV2ReceiptService();
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
      backgroundColor: const Color(0xFFF7F9FD),
      appBar: AppBar(
        backgroundColor: Colors.white.withValues(alpha: .82),
        foregroundColor: const Color(0xFF0E2247),
        elevation: 0,
        title: Text('monthly_statement'.tr()),
      ),
      body: ResidentVisitorPageBackground(
        child: Column(
          children: [
            _monthSelector(),
            Expanded(child: _statementBody()),
          ],
        ),
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
          tooltip: 'previous'.tr(),
          onPressed: () => _changeMonth(-1),
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: Text(
            _monthLabel(_selectedMonth),
            key: const ValueKey('statement-selected-month'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0E2247),
            ),
          ),
        ),
        IconButton(
          key: const ValueKey('statement-next-month'),
          tooltip: 'next'.tr(),
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
                child: Text('retry'.tr()),
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
          Card(
            color: Colors.white.withValues(alpha: .94),
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
              side: const BorderSide(color: Colors.white, width: 1.2),
            ),
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('no_bills_period'.tr())),
            ),
          )
        else
          ...statement.bills.map(_billCard),
      ],
    );
  }

  Widget _summaryCard(ResidentBillingStatementSummary summary) => Card(
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
          Text(
            'statement_summary'.tr(),
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          _moneyRow('total_billed'.tr(), summary.billedMinor),
          _moneyRow('payments_applied'.tr(), summary.paidAllocationMinor),
          _moneyRow('credit_applied'.tr(), summary.creditAppliedMinor),
          _moneyRow('outstanding'.tr(), summary.outstandingMinor),
          _moneyRow(
            'current_available_credit'.tr(),
            summary.availableCreditMinor,
            note: 'account_level_balance'.tr(),
          ),
          const Divider(height: 24),
          Text(
            'bill_status_counts'.tr(),
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          _countRow('pending'.tr(), summary.statusCounts['pending']!),
          _countRow(
            'partially_paid'.tr(),
            summary.statusCounts['partially_paid']!,
          ),
          _countRow('paid'.tr(), summary.statusCounts['paid']!),
          _countRow('overdue'.tr(), summary.statusCounts['overdue']!),
        ],
      ),
    ),
  );

  Widget _billCard(ResidentStatementBill bill) => Card(
    color: Colors.white.withValues(alpha: .94),
    elevation: 1,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(22),
      side: const BorderSide(color: Colors.white, width: 1.2),
    ),
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
              _statusBadge(bill.status),
            ],
          ),
          const SizedBox(height: 10),
          _moneyRow('total'.tr(), bill.amountMinor),
          _moneyRow('payment_allocations'.tr(), bill.paidAllocationMinor),
          _moneyRow('credit_applied'.tr(), bill.creditAppliedMinor),
          _moneyRow('outstanding'.tr(), bill.outstandingMinor),
          _detailRow('due_date'.tr(), _formatDateKey(bill.dueDateKey)),
          const Divider(height: 24),
          Text(
            'charge_lines'.tr(),
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          ...bill.chargeLines.map(
            (line) => _moneyRow(line.label, line.amountMinor),
          ),
          const Divider(height: 24),
          Text(
            'settlements'.tr(),
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          if (bill.settlements.isEmpty)
            Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('no_payment_allocations'.tr()),
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
          'received'.tr(),
          _formatDate(
            DateTime.fromMillisecondsSinceEpoch(settlement.receivedAt),
          ),
        ),
        if (settlement.reference != null &&
            settlement.reference!.trim().isNotEmpty)
          _detailRow('payment_reference'.tr(), settlement.reference!.trim()),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            key: ValueKey('view-receipt-${settlement.transactionId}'),
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) => ResidentBillingV2ReceiptScreen(
                  transactionId: settlement.transactionId,
                  service: _receiptService,
                ),
              ),
            ),
            icon: const Icon(Icons.receipt_long_outlined),
            label: Text('view_receipt'.tr()),
          ),
        ),
      ],
    ),
  );

  Widget _moneyRow(String label, int amountMinor, {String? note}) =>
      LayoutBuilder(
        builder: (context, constraints) {
          final labelText = Text(note == null ? label : '$label ($note)');
          final amountText = Text(
            BillFirestoreService.formatInrMinorUnits(amountMinor),
            textAlign: TextAlign.end,
          );
          final stack =
              constraints.maxWidth < 320 ||
              MediaQuery.textScalerOf(context).scale(1) > 1.3;
          return Padding(
            padding: const EdgeInsets.only(top: 6),
            child: stack
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      labelText,
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: amountText,
                      ),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: labelText),
                      const SizedBox(width: 12),
                      amountText,
                    ],
                  ),
          );
        },
      );

  Widget _statusBadge(String status) {
    final normalized = status.toLowerCase();
    final background = normalized == 'overdue'
        ? const Color(0xFFFEE2E2)
        : normalized == 'paid' || normalized == 'settled'
        ? const Color(0xFFD1FAE5)
        : normalized == 'partially_paid'
        ? const Color(0xFFDBEAFE)
        : const Color(0xFFFFF3D6);
    final foreground = normalized == 'overdue'
        ? const Color(0xFFB42318)
        : normalized == 'paid' || normalized == 'settled'
        ? const Color(0xFF047857)
        : normalized == 'partially_paid'
        ? const Color(0xFF1D4ED8)
        : const Color(0xFF9A6700);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        _titleCase(status),
        style: TextStyle(
          color: foreground,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _countRow(String label, int count) => LayoutBuilder(
    builder: (context, constraints) {
      final stack =
          constraints.maxWidth < 320 ||
          MediaQuery.textScalerOf(context).scale(1) > 1.3;
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: stack
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(label),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: Text('$count'),
                  ),
                ],
              )
            : Row(
                children: [
                  Expanded(child: Text(label)),
                  Text('$count'),
                ],
              ),
      );
    },
  );

  Widget _detailRow(String label, String value) => LayoutBuilder(
    builder: (context, constraints) {
      final labelWidget = Text(
        label,
        style: const TextStyle(color: Color(0xFF7A7A7A)),
      );
      final stack =
          constraints.maxWidth < 320 ||
          MediaQuery.textScalerOf(context).scale(1) > 1.3;
      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: stack
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [labelWidget, Text(value)],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 105, child: labelWidget),
                  Expanded(child: Text(value)),
                ],
              ),
      );
    },
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
