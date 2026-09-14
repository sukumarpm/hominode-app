import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/admin_payment_review_service.dart';
import '../session/web_session.dart';
import '../theme/web_design_system.dart';
import '../widgets/dashboard_components.dart';

class AdminBillingPage extends StatefulWidget {
  const AdminBillingPage({
    super.key,
    required this.session,
    required this.onNavigate,
  });

  final WebSession session;
  final ValueChanged<String> onNavigate;

  @override
  State<AdminBillingPage> createState() => _AdminBillingPageState();
}

class _AdminBillingPageState extends State<AdminBillingPage> {
  final TextEditingController _searchController = TextEditingController();
  final AdminPaymentReviewService _paymentService = AdminPaymentReviewService();
  final Set<String> _viewedPaymentReceiptIds = {};
  final Set<String> _busyPaymentIds = {};

  late Stream<QuerySnapshot<Map<String, dynamic>>> _billsStream;
  late Stream<List<AdminPaymentProof>> _paymentsStream;

  String _searchText = '';
  String _statusFilter = 'all';

  String get _communityId => widget.session.activeTenant!.communityId;

  String get _communityName => widget.session.activeTenant!.name;

  @override
  void initState() {
    super.initState();
    _bindStreams();
  }

  @override
  void didUpdateWidget(covariant AdminBillingPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session.activeTenant?.communityId != _communityId) {
      _viewedPaymentReceiptIds.clear();
      _busyPaymentIds.clear();
      _bindStreams();
    }
  }

  void _bindStreams() {
    _billsStream = FirebaseFirestore.instance
        .collection('bills')
        .where('communityId', isEqualTo: _communityId)
        .snapshots();
    _paymentsStream = _paymentService.watchCommunityPayments(widget.session);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AdminPaymentProof>>(
      stream: _paymentsStream,
      builder: (context, paymentSnapshot) {
        if (paymentSnapshot.hasError) {
          return SectionCard(
            title: 'Billing',
            child: EmptyState(
              icon: Icons.error_outline,
              message:
                  'Unable to load payment proofs: ${_errorMessage(paymentSnapshot.error!)}',
            ),
          );
        }
        if (!paymentSnapshot.hasData) {
          return const SectionCard(
            title: 'Billing',
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final latestProofByBill = _paymentService.latestProofByBill(
          paymentSnapshot.data!,
        );
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _billsStream,
          builder: (context, billSnapshot) {
            if (billSnapshot.hasError) {
              return const SectionCard(
                title: 'Billing',
                child: EmptyState(
                  icon: Icons.error_outline,
                  message: 'Unable to load billing records for this community.',
                ),
              );
            }
            if (!billSnapshot.hasData) {
              return const SectionCard(
                title: 'Billing',
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final bills = billSnapshot.data!.docs
                .where(
                  (doc) =>
                      doc.data()['communityId']?.toString() == _communityId,
                )
                .map(
                  (doc) => _BillingRecord(
                    document: doc,
                    payment: latestProofByBill[doc.id],
                  ),
                )
                .toList();

            final pendingCount = bills.where((doc) {
              final status = _billStatus(doc.data);

              return status == 'pending' ||
                  status == 'due' ||
                  status == 'unpaid';
            }).length;

            final paidCount = bills.where((doc) {
              final status = _billStatus(doc.data);

              return status == 'paid' ||
                  status == 'settled' ||
                  status == 'approved';
            }).length;

            final approvalCount = bills.where((doc) {
              return doc.payment?.isPending == true;
            }).length;

            final overdueCount = bills.where((doc) {
              final status = _billStatus(doc.data);

              return status == 'overdue';
            }).length;

            final filteredBills =
                bills.where((doc) {
                  final data = doc.data;
                  final payment = doc.payment;

                  final query = _searchText.trim().toLowerCase();

                  if (query.isNotEmpty) {
                    final searchable = [
                      _billTitle(doc.id, data),
                      _residentName(data),
                      _building(data),
                      _flat(data),
                      _billStatus(data),
                      _paymentApprovalStatus(payment, data),
                      _paymentReference(payment, data),
                      _paymentSource(payment, data),
                    ].join(' ').toLowerCase();

                    if (!searchable.contains(query)) {
                      return false;
                    }
                  }

                  if (_statusFilter != 'all') {
                    final billStatus = _billStatus(data);
                    final approvalStatus = _paymentApprovalStatus(
                      payment,
                      data,
                    );

                    if (_statusFilter == 'pendingapproval') {
                      if (approvalStatus != 'pendingapproval') {
                        return false;
                      }
                    } else if (_statusFilter == 'paid') {
                      if (billStatus != 'paid' &&
                          billStatus != 'settled' &&
                          billStatus != 'approved') {
                        return false;
                      }
                    } else if (_statusFilter == 'pending') {
                      if (billStatus != 'pending' &&
                          billStatus != 'due' &&
                          billStatus != 'unpaid') {
                        return false;
                      }
                    } else if (billStatus != _statusFilter) {
                      return false;
                    }
                  }

                  return true;
                }).toList()..sort(
                  (a, b) =>
                      _billSortDate(b.data).compareTo(_billSortDate(a.data)),
                );

            final totalAmount = bills.fold<double>(
              0,
              (total, doc) => total + _billAmount(doc.data),
            );

            final paidAmount = bills
                .where((doc) {
                  final status = _billStatus(doc.data);

                  return status == 'paid' ||
                      status == 'settled' ||
                      status == 'approved';
                })
                .fold<double>(0, (total, doc) => total + _billAmount(doc.data));

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _BillingHero(
                  communityName: _communityName,
                  totalBills: bills.length,
                  pendingBills: pendingCount,
                  paidBills: paidCount,
                  approvalPending: approvalCount,
                  overdueBills: overdueCount,
                ),

                const SizedBox(height: 16),

                _QuickNavigation(onNavigate: widget.onNavigate),

                const SizedBox(height: 16),

                ResponsiveMetricGrid(
                  children: [
                    DashboardStatCard(
                      label: 'Billed Amount',
                      value: _money(totalAmount),
                      icon: Icons.receipt_long_outlined,
                      color: const Color(0xFF246BFD),
                    ),
                    DashboardStatCard(
                      label: 'Paid Amount',
                      value: _money(paidAmount),
                      icon: Icons.check_circle_outline,
                      color: const Color(0xFF08A579),
                    ),
                    DashboardStatCard(
                      label: 'Outstanding',
                      value: _money(
                        (totalAmount - paidAmount).clamp(0, double.infinity),
                      ),
                      icon: Icons.account_balance_wallet_outlined,
                      color: const Color(0xFFE66A2C),
                    ),
                    DashboardStatCard(
                      label: 'Receipt Approvals',
                      value: approvalCount.toString(),
                      icon: Icons.fact_check_outlined,
                      color: const Color(0xFF7A42D8),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                SectionCard(
                  title: 'Billing Directory',
                  action: _BillingToolbar(
                    searchController: _searchController,
                    searchText: _searchText,
                    statusFilter: _statusFilter,
                    onSearchChanged: (value) {
                      setState(() {
                        _searchText = value;
                      });
                    },
                    onSearchClear: () {
                      _searchController.clear();

                      setState(() {
                        _searchText = '';
                      });
                    },
                    onStatusChanged: (value) {
                      if (value == null) {
                        return;
                      }

                      setState(() {
                        _statusFilter = value;
                      });
                    },
                  ),
                  child: filteredBills.isEmpty
                      ? EmptyState(
                          icon: Icons.receipt_long_outlined,
                          message:
                              _searchText.trim().isNotEmpty ||
                                  _statusFilter != 'all'
                              ? 'No billing records match the selected filters.'
                              : 'No billing records are available for this community.',
                        )
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            if (constraints.maxWidth >= 1000) {
                              return _BillingTable(
                                bills: filteredBills,
                                onNavigate: widget.onNavigate,
                                viewedPaymentIds: _viewedPaymentReceiptIds,
                                busyPaymentIds: _busyPaymentIds,
                                onViewReceipt: _viewPaymentReceipt,
                                onApprove: _approvePaymentProof,
                                onReject: _rejectPaymentProof,
                              );
                            }

                            return Column(
                              children: [
                                for (
                                  var i = 0;
                                  i < filteredBills.length;
                                  i++
                                ) ...[
                                  _BillingMobileCard(
                                    record: filteredBills[i],
                                    onNavigate: widget.onNavigate,
                                    receiptViewed:
                                        filteredBills[i].payment != null &&
                                        _viewedPaymentReceiptIds.contains(
                                          filteredBills[i].payment!.id,
                                        ),
                                    busy:
                                        filteredBills[i].payment != null &&
                                        _busyPaymentIds.contains(
                                          filteredBills[i].payment!.id,
                                        ),
                                    onViewReceipt: _viewPaymentReceipt,
                                    onApprove: _approvePaymentProof,
                                    onReject: _rejectPaymentProof,
                                  ),
                                  if (i != filteredBills.length - 1)
                                    const SizedBox(height: 10),
                                ],
                              ],
                            );
                          },
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _viewPaymentReceipt(AdminPaymentProof payment) async {
    if (payment.communityId != _communityId || !mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => _ReceiptReviewDialog(
        payment: payment,
        receiptFuture: _paymentService.loadPaymentReceipt(
          session: widget.session,
          payment: payment,
        ),
        onViewed: () {
          if (!mounted || payment.communityId != _communityId) return;
          setState(() => _viewedPaymentReceiptIds.add(payment.id));
        },
      ),
    );
  }

  Future<void> _approvePaymentProof(_BillingRecord record) async {
    final payment = record.payment;
    if (payment == null ||
        !payment.isPending ||
        payment.communityId != _communityId ||
        !_viewedPaymentReceiptIds.contains(payment.id) ||
        _busyPaymentIds.contains(payment.id)) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Verify Payment'),
        content: Text(
          'Confirm payment of ${_money(_billAmount(record.data))} '
          'for ${_residentName(record.data).isEmpty ? 'this resident' : _residentName(record.data)}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF08A579),
            ),
            child: const Text('Verify'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busyPaymentIds.add(payment.id));
    try {
      await _paymentService.verifyPaymentProof(
        session: widget.session,
        payment: payment,
      );
      if (!mounted) return;
      setState(() {
        _busyPaymentIds.remove(payment.id);
        _viewedPaymentReceiptIds.remove(payment.id);
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Payment proof verified.')));
    } catch (error) {
      if (!mounted) return;
      setState(() => _busyPaymentIds.remove(payment.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Verification failed: ${_errorMessage(error)}')),
      );
    }
  }

  Future<void> _rejectPaymentProof(_BillingRecord record) async {
    final payment = record.payment;
    if (payment == null ||
        !payment.isPending ||
        payment.communityId != _communityId ||
        _busyPaymentIds.contains(payment.id)) {
      return;
    }
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Reject Payment Proof'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          maxLength: 250,
          decoration: const InputDecoration(
            labelText: 'Reason for rejection',
            hintText: 'Example: Receipt amount does not match the bill.',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) Navigator.of(context).pop(value);
            },
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFC43D3D),
            ),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (reason == null || reason.trim().isEmpty || !mounted) return;
    setState(() => _busyPaymentIds.add(payment.id));
    try {
      await _paymentService.rejectPaymentProof(
        session: widget.session,
        payment: payment,
        rejectionReason: reason,
      );
      if (!mounted) return;
      setState(() {
        _busyPaymentIds.remove(payment.id);
        _viewedPaymentReceiptIds.remove(payment.id);
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Payment proof rejected.')));
    } catch (error) {
      if (!mounted) return;
      setState(() => _busyPaymentIds.remove(payment.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Rejection failed: ${_errorMessage(error)}')),
      );
    }
  }
}

class _BillingRecord {
  const _BillingRecord({required this.document, required this.payment});

  final QueryDocumentSnapshot<Map<String, dynamic>> document;
  final AdminPaymentProof? payment;

  String get id => document.id;
  Map<String, dynamic> get data => document.data();
}

class _ReceiptReviewDialog extends StatefulWidget {
  const _ReceiptReviewDialog({
    required this.payment,
    required this.receiptFuture,
    required this.onViewed,
  });

  final AdminPaymentProof payment;
  final Future<Uint8List> receiptFuture;
  final VoidCallback onViewed;

  @override
  State<_ReceiptReviewDialog> createState() => _ReceiptReviewDialogState();
}

class _ReceiptReviewDialogState extends State<_ReceiptReviewDialog> {
  bool _markedViewed = false;

  void _markViewed() {
    if (_markedViewed) return;
    _markedViewed = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onViewed();
    });
  }

  @override
  Widget build(BuildContext context) => Dialog(
    insetPadding: const EdgeInsets.all(20),
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: 900,
        maxHeight: MediaQuery.sizeOf(context).height * .82,
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Payment Receipt',
                    style: TextStyle(
                      color: WebDesign.text,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const Divider(color: WebDesign.border),
            Flexible(
              child: FutureBuilder<Uint8List>(
                future: widget.receiptFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError || !snapshot.hasData) {
                    return EmptyState(
                      icon: Icons.broken_image_outlined,
                      message: snapshot.hasError
                          ? 'Receipt could not be loaded: ${_errorMessage(snapshot.error!)}'
                          : 'Receipt could not be loaded.',
                    );
                  }
                  return InteractiveViewer(
                    minScale: .5,
                    maxScale: 4,
                    child: Image.memory(
                      snapshot.data!,
                      fit: BoxFit.contain,
                      frameBuilder:
                          (context, child, frame, loadedSynchronously) {
                            if (loadedSynchronously || frame != null) {
                              _markViewed();
                            }
                            return child;
                          },
                      errorBuilder: (context, error, stackTrace) => EmptyState(
                        icon: Icons.broken_image_outlined,
                        message:
                            'This receipt image could not be displayed: ${_errorMessage(error)}',
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

//
// ============================================================
// HERO
// ============================================================
//

class _BillingHero extends StatelessWidget {
  const _BillingHero({
    required this.communityName,
    required this.totalBills,
    required this.pendingBills,
    required this.paidBills,
    required this.approvalPending,
    required this.overdueBills,
  });

  final String communityName;
  final int totalBills;
  final int pendingBills;
  final int paidBills;
  final int approvalPending;
  final int overdueBills;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: WebDesign.adminPageHeader,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 820;

          final title = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: RolePalette.admin.soft,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: WebDesign.border),
                ),
                child: const Icon(
                  Icons.receipt_long_outlined,
                  color: WebDesign.text,
                  size: 31,
                ),
              ),
              const SizedBox(width: 14),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Billing',
                      style: TextStyle(
                        color: WebDesign.text,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      communityName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: WebDesign.muted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );

          final metrics = Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _HeroMetric(label: 'Total Bills', value: '$totalBills'),
              _HeroMetric(label: 'Pending', value: '$pendingBills'),
              _HeroMetric(label: 'Paid', value: '$paidBills'),
              _HeroMetric(label: 'Receipts', value: '$approvalPending'),
              _HeroMetric(label: 'Overdue', value: '$overdueBills'),
            ],
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [title, const SizedBox(height: 16), metrics],
            );
          }

          return Row(
            children: [
              Expanded(child: title),
              const SizedBox(width: 20),
              metrics,
            ],
          );
        },
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: RolePalette.admin.soft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: WebDesign.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: WebDesign.muted,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              color: WebDesign.text,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

//
// ============================================================
// QUICK ACCESS
// ============================================================
//

class _QuickNavigation extends StatelessWidget {
  const _QuickNavigation({required this.onNavigate});

  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Quick Access',
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          QuickActionCard(
            label: 'My Community',
            icon: Icons.apartment_outlined,
            color: RolePalette.admin.primary,
            onTap: () => onNavigate('/admin/community'),
          ),
          QuickActionCard(
            label: 'Residents',
            icon: Icons.people_outline,
            color: const Color(0xFF246BFD),
            onTap: () => onNavigate('/admin/residents'),
          ),
          QuickActionCard(
            label: 'Reports',
            icon: Icons.analytics_outlined,
            color: const Color(0xFFE66A2C),
            onTap: () => onNavigate('/admin/reports'),
          ),
          QuickActionCard(
            label: 'Settings',
            icon: Icons.settings_outlined,
            color: const Color(0xFF7A42D8),
            onTap: () => onNavigate('/admin/settings'),
          ),
        ],
      ),
    );
  }
}

//
// ============================================================
// TOOLBAR
// ============================================================
//

class _BillingToolbar extends StatelessWidget {
  const _BillingToolbar({
    required this.searchController,
    required this.searchText,
    required this.statusFilter,
    required this.onSearchChanged,
    required this.onSearchClear,
    required this.onStatusChanged,
  });

  final TextEditingController searchController;
  final String searchText;
  final String statusFilter;

  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSearchClear;
  final ValueChanged<String?> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 245,
          child: TextField(
            controller: searchController,
            onChanged: onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Search billing...',
              prefixIcon: const Icon(Icons.search, size: 19),
              suffixIcon: searchText.trim().isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear',
                      onPressed: onSearchClear,
                      icon: const Icon(Icons.close, size: 18),
                    ),
              isDense: true,
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: WebDesign.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: WebDesign.border),
              ),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: WebDesign.border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: statusFilter,
              borderRadius: BorderRadius.circular(12),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('All status')),
                DropdownMenuItem(value: 'pending', child: Text('Pending')),
                DropdownMenuItem(value: 'paid', child: Text('Paid')),
                DropdownMenuItem(value: 'overdue', child: Text('Overdue')),
                DropdownMenuItem(
                  value: 'pendingapproval',
                  child: Text('Receipt approval'),
                ),
              ],
              onChanged: onStatusChanged,
            ),
          ),
        ),
      ],
    );
  }
}

//
// ============================================================
// DESKTOP TABLE
// ============================================================
//

class _BillingTable extends StatelessWidget {
  const _BillingTable({
    required this.bills,
    required this.onNavigate,
    required this.viewedPaymentIds,
    required this.busyPaymentIds,
    required this.onViewReceipt,
    required this.onApprove,
    required this.onReject,
  });

  final List<_BillingRecord> bills;
  final ValueChanged<String> onNavigate;
  final Set<String> viewedPaymentIds;
  final Set<String> busyPaymentIds;
  final ValueChanged<AdminPaymentProof> onViewReceipt;
  final ValueChanged<_BillingRecord> onApprove;
  final ValueChanged<_BillingRecord> onReject;

  @override
  Widget build(BuildContext context) {
    return Table(
      columnWidths: const {
        0: FlexColumnWidth(2.1),
        1: FlexColumnWidth(1.6),
        2: FlexColumnWidth(1.3),
        3: FlexColumnWidth(1.1),
        4: FlexColumnWidth(1.2),
        5: FlexColumnWidth(1.2),
        6: FlexColumnWidth(.7),
      },
      border: const TableBorder(
        horizontalInside: BorderSide(color: WebDesign.border),
      ),
      children: [
        const TableRow(
          decoration: BoxDecoration(color: Color(0xFFF8FAFC)),
          children: [
            _TableHeader('Bill'),
            _TableHeader('Resident'),
            _TableHeader('Location'),
            _TableHeader('Amount'),
            _TableHeader('Payment'),
            _TableHeader('Status'),
            _TableHeader(''),
          ],
        ),
        for (final doc in bills) _billRow(doc),
      ],
    );
  }

  TableRow _billRow(_BillingRecord record) {
    final data = record.data;
    final payment = record.payment;

    return TableRow(
      children: [
        _BillCell(
          title: _billTitle(record.id, data),
          period: _billingPeriod(data),
          date: _billDateLabel(data),
        ),
        _TableTextCell(text: _residentName(data)),
        _LocationCell(building: _building(data), flat: _flat(data)),
        _AmountCell(amount: _billAmount(data)),
        _PaymentCell(
          source: _paymentSource(payment, data),
          approvalStatus: _paymentApprovalStatus(payment, data),
          reference: _paymentReference(payment, data),
        ),
        _StatusCell(
          status: _billStatus(data),
          approvalStatus: _paymentApprovalStatus(payment, data),
        ),
        _BillingActionsCell(
          payment: payment,
          receiptViewed:
              payment != null && viewedPaymentIds.contains(payment.id),
          busy: payment != null && busyPaymentIds.contains(payment.id),
          onViewReceipt: payment == null ? null : () => onViewReceipt(payment),
          onApprove: () => onApprove(record),
          onReject: () => onReject(record),
          onResident: () => onNavigate('/admin/residents'),
          onReports: () => onNavigate('/admin/reports'),
        ),
      ],
    );
  }
}

class _TableHeader extends StatelessWidget {
  const _TableHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      child: Text(
        label,
        style: const TextStyle(
          color: WebDesign.muted,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _BillCell extends StatelessWidget {
  const _BillCell({
    required this.title,
    required this.period,
    required this.date,
  });

  final String title;
  final String period;
  final String date;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFE6F0FF),
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(
              Icons.receipt_long_outlined,
              size: 19,
              color: Color(0xFF246BFD),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: WebDesign.text,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (period.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    period,
                    style: const TextStyle(color: WebDesign.muted, fontSize: 9),
                  ),
                ],
                if (date.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    date,
                    style: const TextStyle(color: WebDesign.muted, fontSize: 9),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TableTextCell extends StatelessWidget {
  const _TableTextCell({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      child: Text(
        text.isEmpty ? '—' : text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: WebDesign.text, fontSize: 11),
      ),
    );
  }
}

class _LocationCell extends StatelessWidget {
  const _LocationCell({required this.building, required this.flat});

  final String building;
  final String flat;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            building.isEmpty ? '—' : building,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: WebDesign.text,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (flat.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              flat,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: WebDesign.muted, fontSize: 9),
            ),
          ],
        ],
      ),
    );
  }
}

class _AmountCell extends StatelessWidget {
  const _AmountCell({required this.amount});

  final double amount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      child: Text(
        _money(amount),
        style: const TextStyle(
          color: WebDesign.text,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _PaymentCell extends StatelessWidget {
  const _PaymentCell({
    required this.source,
    required this.approvalStatus,
    required this.reference,
  });

  final String source;
  final String approvalStatus;
  final String reference;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            source.isEmpty ? '—' : _titleCase(source),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: WebDesign.text,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (approvalStatus.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              _approvalLabel(approvalStatus),
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: WebDesign.muted, fontSize: 9),
            ),
          ],
          if (reference.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              reference,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: WebDesign.muted, fontSize: 9),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusCell extends StatelessWidget {
  const _StatusCell({required this.status, required this.approvalStatus});

  final String status;
  final String approvalStatus;

  @override
  Widget build(BuildContext context) {
    final displayStatus = _displayBillingStatus(status, approvalStatus);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      child: Align(
        alignment: Alignment.centerLeft,
        child: _BillingStatusPill(status: displayStatus),
      ),
    );
  }
}

class _BillingActionsCell extends StatefulWidget {
  const _BillingActionsCell({
    required this.payment,
    required this.receiptViewed,
    required this.busy,
    required this.onViewReceipt,
    required this.onApprove,
    required this.onReject,
    required this.onResident,
    required this.onReports,
  });

  final AdminPaymentProof? payment;
  final bool receiptViewed;
  final bool busy;
  final VoidCallback? onViewReceipt;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onResident;
  final VoidCallback onReports;

  @override
  State<_BillingActionsCell> createState() => _BillingActionsCellState();
}

class _BillingActionsCellState extends State<_BillingActionsCell> {
  final MenuController _menuController = MenuController();

  void _runMenuAction(VoidCallback? action) {
    if (action == null) return;
    _menuController.close();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) action();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: Align(
        alignment: Alignment.centerRight,
        child: MenuAnchor(
          controller: _menuController,
          consumeOutsideTap: true,
          menuChildren: [
            if (widget.payment?.isPending == true) ...[
              MenuItemButton(
                closeOnActivate: false,
                onPressed: widget.busy
                    ? null
                    : () => _runMenuAction(widget.onViewReceipt),
                leadingIcon: const Icon(Icons.visibility_outlined, size: 18),
                child: const Text('View receipt'),
              ),
              MenuItemButton(
                closeOnActivate: false,
                onPressed: widget.receiptViewed && !widget.busy
                    ? () => _runMenuAction(widget.onApprove)
                    : null,
                leadingIcon: const Icon(Icons.verified_outlined, size: 18),
                child: Text(
                  widget.receiptViewed ? 'Approve' : 'View receipt first',
                ),
              ),
              MenuItemButton(
                closeOnActivate: false,
                onPressed: widget.busy
                    ? null
                    : () => _runMenuAction(widget.onReject),
                leadingIcon: const Icon(Icons.cancel_outlined, size: 18),
                child: const Text('Reject'),
              ),
            ] else ...[
              MenuItemButton(
                closeOnActivate: false,
                onPressed: () => _runMenuAction(widget.onResident),
                leadingIcon: const Icon(Icons.people_outline, size: 18),
                child: const Text('Residents'),
              ),
              MenuItemButton(
                closeOnActivate: false,
                onPressed: () => _runMenuAction(widget.onReports),
                leadingIcon: const Icon(Icons.analytics_outlined, size: 18),
                child: const Text('Reports'),
              ),
            ],
          ],
          builder: (context, controller, child) {
            return IconButton(
              tooltip: 'Billing actions',
              onPressed: () {
                if (_menuController.isOpen) {
                  _menuController.close();
                } else {
                  _menuController.open();
                }
              },
              icon: const Icon(Icons.more_vert, size: 18),
            );
          },
        ),
      ),
    );
  }
}

//
// ============================================================
// MOBILE
// ============================================================
//

class _BillingMobileCard extends StatelessWidget {
  const _BillingMobileCard({
    required this.record,
    required this.onNavigate,
    required this.receiptViewed,
    required this.busy,
    required this.onViewReceipt,
    required this.onApprove,
    required this.onReject,
  });

  final _BillingRecord record;
  final ValueChanged<String> onNavigate;
  final bool receiptViewed;
  final bool busy;
  final ValueChanged<AdminPaymentProof> onViewReceipt;
  final ValueChanged<_BillingRecord> onApprove;
  final ValueChanged<_BillingRecord> onReject;

  @override
  Widget build(BuildContext context) {
    final data = record.data;
    final payment = record.payment;

    final title = _billTitle(record.id, data);

    final resident = _residentName(data);
    final building = _building(data);
    final flat = _flat(data);

    final amount = _billAmount(data);
    final status = _billStatus(data);

    final approvalStatus = _paymentApprovalStatus(payment, data);

    final displayStatus = _displayBillingStatus(status, approvalStatus);

    final period = _billingPeriod(data);
    final date = _billDateLabel(data);
    final source = _paymentSource(payment, data);
    final reference = _paymentReference(payment, data);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: WebDesign.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFE6F0FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.receipt_long_outlined,
                  color: Color(0xFF246BFD),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: WebDesign.text,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (period.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        period,
                        style: const TextStyle(
                          color: WebDesign.muted,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _BillingStatusPill(status: displayStatus),
            ],
          ),

          const SizedBox(height: 12),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoPill(icon: Icons.payments_outlined, label: _money(amount)),
              if (resident.isNotEmpty)
                _InfoPill(icon: Icons.person_outline, label: resident),
              if (building.isNotEmpty)
                _InfoPill(icon: Icons.business_outlined, label: building),
              if (flat.isNotEmpty)
                _InfoPill(icon: Icons.door_front_door_outlined, label: flat),
              if (date.isNotEmpty)
                _InfoPill(icon: Icons.calendar_today_outlined, label: date),
              if (source.isNotEmpty)
                _InfoPill(
                  icon: Icons.account_balance_wallet_outlined,
                  label: _titleCase(source),
                ),
              if (reference.isNotEmpty)
                _InfoPill(icon: Icons.tag_outlined, label: reference),
            ],
          ),

          const SizedBox(height: 8),

          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: payment?.isPending == true
                ? [
                    TextButton.icon(
                      onPressed: busy ? null : () => onViewReceipt(payment!),
                      icon: const Icon(Icons.visibility_outlined, size: 16),
                      label: const Text('View receipt'),
                    ),
                    TextButton.icon(
                      onPressed: receiptViewed && !busy
                          ? () => onApprove(record)
                          : null,
                      icon: const Icon(Icons.verified_outlined, size: 16),
                      label: Text(
                        receiptViewed ? 'Approve' : 'View receipt first',
                      ),
                    ),
                    TextButton.icon(
                      onPressed: busy ? null : () => onReject(record),
                      icon: const Icon(Icons.cancel_outlined, size: 16),
                      label: const Text('Reject'),
                    ),
                  ]
                : [
                    TextButton.icon(
                      onPressed: () => onNavigate('/admin/residents'),
                      icon: const Icon(Icons.people_outline, size: 16),
                      label: const Text('Residents'),
                    ),
                    TextButton.icon(
                      onPressed: () => onNavigate('/admin/reports'),
                      icon: const Icon(Icons.analytics_outlined, size: 16),
                      label: const Text('Reports'),
                    ),
                  ],
          ),
        ],
      ),
    );
  }
}

//
// ============================================================
// BADGES / SMALL UI
// ============================================================
//

class _BillingStatusPill extends StatelessWidget {
  const _BillingStatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final normalized = status.toLowerCase();

    Color background;
    Color foreground;

    switch (normalized) {
      case 'paid':
      case 'settled':
      case 'approved':
        background = const Color(0xFFE8F8F2);
        foreground = const Color(0xFF087A5B);
        break;

      case 'receipt pending':
      case 'pending':
      case 'due':
      case 'unpaid':
        background = const Color(0xFFFFF4D8);
        foreground = const Color(0xFFA96B00);
        break;

      case 'overdue':
      case 'rejected':
        background = const Color(0xFFFFEEEE);
        foreground = const Color(0xFFB93C3C);
        break;

      default:
        background = const Color(0xFFF0F2F6);
        foreground = WebDesign.muted;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: foreground,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: WebDesign.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: WebDesign.muted),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: WebDesign.muted,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

//
// ============================================================
// FIELD HELPERS
// ============================================================
//

String _billTitle(String documentId, Map<String, dynamic> data) {
  for (final key in const ['title', 'billTitle', 'description', 'billType']) {
    final value = data[key]?.toString().trim();

    if (value != null && value.isNotEmpty) {
      return value;
    }
  }

  return 'Bill $documentId';
}

String _residentName(Map<String, dynamic> data) {
  for (final key in const [
    'residentName',
    'customerName',
    'userName',
    'name',
  ]) {
    final value = data[key]?.toString().trim();

    if (value != null && value.isNotEmpty) {
      return value;
    }
  }

  return '';
}

String _building(Map<String, dynamic> data) {
  for (final key in const ['buildingName', 'buildingLabel', 'buildingId']) {
    final value = data[key]?.toString().trim();

    if (value != null && value.isNotEmpty) {
      return value;
    }
  }

  return '';
}

String _flat(Map<String, dynamic> data) {
  for (final key in const [
    'flatLabel',
    'flatNumber',
    'flatNo',
    'unitNumber',
    'unitNo',
    'flatId',
  ]) {
    final value = data[key]?.toString().trim();

    if (value != null && value.isNotEmpty) {
      return value;
    }
  }

  return '';
}

double _billAmount(Map<String, dynamic> data) {
  for (final key in const [
    'amount',
    'totalAmount',
    'billAmount',
    'total',
    'dueAmount',
  ]) {
    final value = data[key];

    if (value is num) {
      return value.toDouble();
    }

    if (value is String) {
      final parsed = double.tryParse(value.replaceAll(',', ''));

      if (parsed != null) {
        return parsed;
      }
    }
  }

  return 0;
}

String _billStatus(Map<String, dynamic> data) {
  for (final key in const ['status', 'billStatus', 'paymentStatus']) {
    final value = data[key]?.toString().trim().toLowerCase();

    if (value != null && value.isNotEmpty) {
      if (value == 'pendingapproval' || value == 'pending_approval') {
        return 'pending';
      }

      return value.replaceAll(' ', '');
    }
  }

  return 'pending';
}

String _paymentApprovalStatus(
  AdminPaymentProof? payment,
  Map<String, dynamic> data,
) {
  if (payment != null) {
    return switch (payment.status) {
      'pending' => 'pendingapproval',
      'completed' => 'approved',
      'failed' => 'rejected',
      _ => '',
    };
  }
  final value = data['paymentStatus']?.toString().trim().toLowerCase();

  if (value == null || value.isEmpty) {
    return '';
  }

  return value.replaceAll('_', '').replaceAll(' ', '');
}

String _paymentSource(AdminPaymentProof? payment, Map<String, dynamic> data) {
  if (payment != null) return payment.method;
  for (final key in const [
    'paymentSource',
    'paymentMethod',
    'method',
    'paymentMode',
  ]) {
    final value = data[key]?.toString().trim();

    if (value != null && value.isNotEmpty) {
      return value;
    }
  }

  return '';
}

String _paymentReference(
  AdminPaymentProof? payment,
  Map<String, dynamic> data,
) {
  if (payment != null) return payment.transactionId;
  for (final key in const [
    'paymentReference',
    'reference',
    'transactionId',
    'referenceNumber',
  ]) {
    final value = data[key]?.toString().trim();

    if (value != null && value.isNotEmpty) {
      return value;
    }
  }

  return '';
}

String _billingPeriod(Map<String, dynamic> data) {
  for (final key in const ['billingPeriod', 'period', 'month', 'billMonth']) {
    final value = data[key]?.toString().trim();

    if (value != null && value.isNotEmpty) {
      return value;
    }
  }

  return '';
}

DateTime _billSortDate(Map<String, dynamic> data) {
  for (final key in const [
    'dueDate',
    'createdAt',
    'billingDate',
    'updatedAt',
  ]) {
    final value = data[key];

    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      final parsed = DateTime.tryParse(value);

      if (parsed != null) {
        return parsed;
      }
    }
  }

  return DateTime.fromMillisecondsSinceEpoch(0);
}

String _billDateLabel(Map<String, dynamic> data) {
  final date = _billSortDate(data);

  if (date.millisecondsSinceEpoch == 0) {
    return '';
  }

  final local = date.toLocal();

  final day = local.day.toString().padLeft(2, '0');

  final month = local.month.toString().padLeft(2, '0');

  return '$day/$month/${local.year}';
}

String _money(num amount) {
  if (amount == amount.roundToDouble()) {
    return amount.toStringAsFixed(0);
  }

  return amount.toStringAsFixed(2);
}

String _approvalLabel(String value) {
  switch (value) {
    case 'pendingapproval':
      return 'Receipt pending approval';

    case 'approved':
      return 'Receipt approved';

    case 'rejected':
      return 'Receipt rejected';

    default:
      return _titleCase(value);
  }
}

String _displayBillingStatus(String billStatus, String approvalStatus) {
  return switch (approvalStatus) {
    'pendingapproval' => 'Receipt Pending',
    'rejected' => 'Receipt Rejected',
    'approved' when billStatus == 'pending' => 'Payment Approved',
    _ => _titleCase(billStatus),
  };
}

String _errorMessage(Object error) {
  if (error is AdminPaymentReviewException) return error.message;
  return error.toString().replaceFirst('FirebaseException: ', '');
}

String _titleCase(String value) {
  final text = value.trim();

  if (text.isEmpty) {
    return 'Unknown';
  }

  final normalized = text
      .replaceAll('_', ' ')
      .replaceAllMapped(
        RegExp(r'([a-z])([A-Z])'),
        (match) => '${match.group(1)} ${match.group(2)}',
      );

  return normalized
      .split(' ')
      .where((part) => part.isNotEmpty)
      .map(
        (part) => part.length == 1
            ? part.toUpperCase()
            : '${part[0].toUpperCase()}${part.substring(1)}',
      )
      .join(' ');
}
