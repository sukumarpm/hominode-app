import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../services/resident_payment_service.dart';
import '../session/web_session.dart';
import '../theme/web_design_system.dart';
import '../widgets/dashboard_components.dart';
import '../widgets/resident_page_components.dart';

class ResidentBillsPage extends StatefulWidget {
  const ResidentBillsPage({super.key, required this.session});

  final WebSession session;

  @override
  State<ResidentBillsPage> createState() => _ResidentBillsPageState();
}

class _ResidentBillsPageState extends State<ResidentBillsPage> {
  final ResidentPaymentService _service = ResidentPaymentService();
  late Future<ResidentBillingData> _future = _service.load(widget.session);
  String? _uploadingBillId;

  @override
  void didUpdateWidget(covariant ResidentBillsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session.uid != widget.session.uid ||
        oldWidget.session.activeTenant?.communityId !=
            widget.session.activeTenant?.communityId ||
        oldWidget.session.flatId != widget.session.flatId) {
      _future = _service.load(widget.session);
    }
  }

  Future<void> _pickAndSubmit(ResidentBill bill) async {
    if (_uploadingBillId != null) return;
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['jpg', 'jpeg', 'png', 'heic', 'heif'],
        allowMultiple: false,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.single;
      final bytes = file.bytes;
      if (bytes == null) {
        throw const ResidentPaymentException(
          'The selected receipt could not be read.',
        );
      }

      setState(() => _uploadingBillId = bill.id);
      await _service.submitProof(
        session: widget.session,
        billId: bill.id,
        receipt: ResidentReceiptFile(name: file.name, bytes: bytes),
      );
      if (!mounted) return;
      setState(() {
        _uploadingBillId = null;
        _future = _service.load(widget.session);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment proof submitted for Admin review.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _uploadingBillId = null);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_messageFor(error))));
    }
  }

  @override
  Widget build(BuildContext context) => ResidentPageLayout(
    title: 'Bills',
    subtitle: 'Bills assigned to your registered unit',
    child: FutureBuilder<ResidentBillingData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return SectionCard(
            title: 'Your bills',
            child: EmptyState(
              icon: Icons.error_outline,
              message: snapshot.hasError
                  ? 'Bills could not be loaded: ${_messageFor(snapshot.error!)}'
                  : 'Bills could not be loaded.',
            ),
          );
        }

        final data = snapshot.data!;
        return Column(
          children: [
            ResponsiveMetricGrid(
              children: [
                DashboardStatCard(
                  label: 'Pending bills',
                  value: data.pendingBills.length.toString(),
                  caption: 'Awaiting payment or review',
                  icon: Icons.receipt_long_outlined,
                  color: const Color(0xFFE66A2C),
                ),
                DashboardStatCard(
                  label: 'Pending amount',
                  value: _money(data.pendingAmount),
                  caption: 'For your unit',
                  icon: Icons.account_balance_wallet_outlined,
                  color: const Color(0xFFE66A2C),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SectionCard(
              title: 'Your bills',
              subtitle:
                  'Submit an image receipt; payment remains pending until Admin review',
              child:
                  widget.session.flatId == null ||
                      widget.session.flatId!.isEmpty
                  ? const EmptyState(
                      message: 'Your resident profile has no unit assignment.',
                      icon: Icons.home_work_outlined,
                    )
                  : data.bills.isEmpty
                  ? const EmptyState(
                      message: 'No bills are available for your unit.',
                      icon: Icons.receipt_long_outlined,
                    )
                  : Column(
                      children: [
                        for (
                          var index = 0;
                          index < data.bills.length;
                          index++
                        ) ...[
                          _BillRow(
                            bill: data.bills[index],
                            proof: data.latestProofByBill[data.bills[index].id],
                            uploading: _uploadingBillId == data.bills[index].id,
                            uploadDisabled: _uploadingBillId != null,
                            onSubmit: () => _pickAndSubmit(data.bills[index]),
                          ),
                          if (index != data.bills.length - 1)
                            const Divider(height: 24, color: WebDesign.border),
                        ],
                      ],
                    ),
            ),
          ],
        );
      },
    ),
  );
}

class _BillRow extends StatelessWidget {
  const _BillRow({
    required this.bill,
    required this.proof,
    required this.uploading,
    required this.uploadDisabled,
    required this.onSubmit,
  });

  final ResidentBill bill;
  final ResidentPaymentProof? proof;
  final bool uploading;
  final bool uploadDisabled;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final canResubmit = proof == null || proof!.isFailed;
    final showSubmit = bill.canSubmitProof && canResubmit;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 620;
        final details = Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFE66A2C).withValues(alpha: .1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.receipt_long_outlined,
                color: Color(0xFFE66A2C),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bill.title,
                    style: const TextStyle(
                      color: WebDesign.text,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    [
                      bill.subtitle,
                      if (bill.dueDate != null) 'Due ${_date(bill.dueDate!)}',
                    ].join(' · '),
                    style: const TextStyle(
                      color: WebDesign.muted,
                      fontSize: 11,
                    ),
                  ),
                  if (proof?.isFailed == true &&
                      proof!.rejectionReason != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Admin note: ${proof!.rejectionReason}',
                      style: const TextStyle(
                        color: Color(0xFFC43D3D),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
        final action = Column(
          crossAxisAlignment: compact
              ? CrossAxisAlignment.stretch
              : CrossAxisAlignment.end,
          children: [
            Text(
              _money(bill.amount),
              textAlign: compact ? TextAlign.left : TextAlign.right,
              style: const TextStyle(
                color: WebDesign.text,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            _PaymentStatusBadge(bill: bill, proof: proof),
            if (showSubmit) ...[
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: uploadDisabled ? null : onSubmit,
                icon: uploading
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.upload_file_outlined, size: 17),
                label: Text(uploading ? 'Submitting…' : 'Submit proof'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFE66A2C),
                  textStyle: const TextStyle(fontSize: 11),
                ),
              ),
            ],
          ],
        );
        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [details, const SizedBox(height: 12), action],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: details),
            const SizedBox(width: 16),
            action,
          ],
        );
      },
    );
  }
}

class _PaymentStatusBadge extends StatelessWidget {
  const _PaymentStatusBadge({required this.bill, required this.proof});

  final ResidentBill bill;
  final ResidentPaymentProof? proof;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch ((bill.status, proof?.status)) {
      ('paid' || 'completed' || 'approved', _) => (
        'Paid',
        const Color(0xFF14805E),
      ),
      (_, 'completed') => ('Approved', const Color(0xFF14805E)),
      (_, 'pending') => ('Proof pending', const Color(0xFFE66A2C)),
      (_, 'failed') => ('Proof rejected', const Color(0xFFC43D3D)),
      ('pending', _) => ('Proof not submitted', const Color(0xFF6B7280)),
      _ => (_displayStatus(bill.status), const Color(0xFF6B7280)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

String _money(double amount) {
  final decimals = amount == amount.roundToDouble() ? 0 : 2;
  return '₹${amount.toStringAsFixed(decimals)}';
}

String _date(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/'
    '${value.month.toString().padLeft(2, '0')}/${value.year}';

String _displayStatus(String status) => status
    .split('_')
    .where((part) => part.isNotEmpty)
    .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
    .join(' ');

String _messageFor(Object error) {
  if (error is ResidentPaymentException) return error.message;
  return error.toString().replaceFirst('FirebaseException: ', '');
}
