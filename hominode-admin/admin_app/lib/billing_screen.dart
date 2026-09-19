library;

import 'dart:async';
import 'dart:io';

import 'package:excel/excel.dart' as xls;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import 'desktop/admin_desktop_page_frame.dart';
import 'services/admin_tenant_context.dart';
import 'services/billing_service.dart';
import 'services/invoice_generator_service.dart';
import 'widgets/create_monthly_bill_modal.dart';
import 'widgets/standard_bottom_nav.dart';
import 'widgets/standard_header.dart';

// ============================================================================
// MAIN BILLING SCREEN
// ============================================================================

class BillingScreen extends StatefulWidget {
  const BillingScreen({super.key});

  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen> {
  final BillingService _billingService = BillingService();
  int _selectedTab = 0;
  final Set<String> _viewedPaymentReceiptIds = {};
  final TextEditingController _billingSearchController =
      TextEditingController();

  String _billingSearchQuery = '';
  String _statusFilter = 'all';
  String _monthFilter = 'all';
  String _yearFilter = 'all';

  double? _minAmountFilter;
  double? _maxAmountFilter;

  DateTime? _dueDateFrom;
  DateTime? _dueDateTo;

  int? _monthNumber(String month) {
    const months = {
      'january': 1,
      'february': 2,
      'march': 3,
      'april': 4,
      'may': 5,
      'june': 6,
      'july': 7,
      'august': 8,
      'september': 9,
      'october': 10,
      'november': 11,
      'december': 12,
    };

    return months[month.toLowerCase()];
  }

  bool _showAdvancedSearch = false;
  late final Stream<List<BillModel>> _billsStream;

  // Get current admin ID
  String get _adminId => FirebaseAuth.instance.currentUser?.uid ?? '';
  Timer? _searchDebounce;
  final Map<String, Stream<Map<String, dynamic>?>> _paymentProofStreams = {};

  late String _exportRange = 'filtered';

  DateTime? _exportFromDate;
  DateTime? _exportToDate;

  Stream<Map<String, dynamic>?> _paymentProofStreamForBill(BillModel bill) {
    final key = '${bill.communityId}:${bill.id}';

    return _paymentProofStreams.putIfAbsent(
      key,
      () => _billingService.streamPendingPaymentForBill(
        communityId: bill.communityId,
        billId: bill.id,
      ),
    );
  }

  @override
  void initState() {
    super.initState();

    final communityId = AdminTenantContext.instance.requireCommunityId();

    _billsStream = _billingService.getBills(communityId);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _billingSearchController.dispose();
    super.dispose();
  }

  Future<List<BillModel>?> _showExportOptions(List<BillModel> allBills) async {
    return showDialog<List<BillModel>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final exportBills = _getBillsForExport(allBills);

            return AlertDialog(
              title: const Text('Export Billing Report'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: _exportRange,
                      decoration: const InputDecoration(
                        labelText: 'Export Range',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'filtered',
                          child: Text('Current filtered results'),
                        ),
                        DropdownMenuItem(
                          value: 'this_month',
                          child: Text('This month'),
                        ),
                        DropdownMenuItem(
                          value: 'last_3_months',
                          child: Text('Last 3 months'),
                        ),
                        DropdownMenuItem(
                          value: 'last_6_months',
                          child: Text('Last 6 months'),
                        ),
                        DropdownMenuItem(
                          value: 'this_year',
                          child: Text('This year'),
                        ),
                        DropdownMenuItem(
                          value: 'custom',
                          child: Text('Custom range'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;

                        setDialogState(() {
                          _exportRange = value;
                        });
                      },
                    ),

                    if (_exportRange == 'custom') ...[
                      SizedBox(height: 16.h),

                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final date = await showDatePicker(
                                  context: context,
                                  initialDate:
                                      _exportFromDate ?? DateTime.now(),
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime.now().add(
                                    const Duration(days: 365),
                                  ),
                                );

                                if (date != null) {
                                  setDialogState(() {
                                    _exportFromDate = date;
                                  });
                                }
                              },
                              icon: const Icon(Icons.calendar_today),
                              label: FittedBox(
                                child: Text(
                                  _exportFromDate == null
                                      ? 'From'
                                      : DateFormat(
                                          'dd MMM yyyy',
                                        ).format(_exportFromDate!),
                                ),
                              ),
                            ),
                          ),

                          SizedBox(width: 8.w),

                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final date = await showDatePicker(
                                  context: context,
                                  initialDate: _exportToDate ?? DateTime.now(),
                                  firstDate: _exportFromDate ?? DateTime(2020),
                                  lastDate: DateTime.now().add(
                                    const Duration(days: 365),
                                  ),
                                );

                                if (date != null) {
                                  setDialogState(() {
                                    _exportToDate = date;
                                  });
                                }
                              },
                              icon: const Icon(Icons.calendar_today),
                              label: FittedBox(
                                child: Text(
                                  _exportToDate == null
                                      ? 'To'
                                      : DateFormat(
                                          'dd MMM yyyy',
                                        ).format(_exportToDate!),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],

                    SizedBox(height: 18.h),

                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(12.w),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            exportBills.isEmpty
                                ? Icons.info_outline
                                : Icons.check_circle_outline,
                            size: 18.w,
                            color: exportBills.isEmpty
                                ? const Color(0xFFF59E0B)
                                : const Color(0xFF16A34A),
                          ),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: Text(
                              exportBills.isEmpty
                                  ? 'No records match the selected filters.'
                                  : '${exportBills.length} record'
                                        '${exportBills.length == 1 ? '' : 's'} will be exported',
                              style: TextStyle(
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: exportBills.isEmpty
                      ? null
                      : () => Navigator.pop(dialogContext, exportBills),
                  child: const Text('Continue'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  List<BillModel> _getBillsForExport(List<BillModel> allBills) {
    // First apply the same search / advanced filters shown on screen.
    var bills = _filterBills(allBills, paymentHistory: _selectedTab == 1);

    final now = DateTime.now();

    DateTime? from;
    DateTime? to;

    switch (_exportRange) {
      case 'this_month':
        from = DateTime(now.year, now.month, 1);
        to = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
        break;

      case 'last_3_months':
        from = DateTime(now.year, now.month - 2, 1);
        to = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
        break;

      case 'last_6_months':
        from = DateTime(now.year, now.month - 5, 1);
        to = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
        break;

      case 'this_year':
        from = DateTime(now.year, 1, 1);
        to = DateTime(now.year, 12, 31, 23, 59, 59);
        break;

      case 'custom':
        from = _exportFromDate;
        to = _exportToDate == null
            ? null
            : DateTime(
                _exportToDate!.year,
                _exportToDate!.month,
                _exportToDate!.day,
                23,
                59,
                59,
              );
        break;

      case 'filtered':
      default:
        return bills;
    }

    return bills.where((bill) {
      // Billing period is better than createdAt for billing reports.
      final monthNumber = _monthNumber(bill.month);

      if (monthNumber == null) {
        return false;
      }

      final year = int.tryParse(bill.year);

      if (year == null) {
        return false;
      }

      final billPeriod = DateTime(year, monthNumber, 1);

      if (from != null && billPeriod.isBefore(from)) {
        return false;
      }

      if (to != null && billPeriod.isAfter(to)) {
        return false;
      }

      return true;
    }).toList();
  }

  List<BillModel> _filterBills(
    List<BillModel> bills, {
    required bool paymentHistory,
  }) {
    final query = _billingSearchQuery.trim().toLowerCase();

    return bills.where((bill) {
      // Tab filter
      if (paymentHistory) {
        if (bill.status != 'paid') {
          return false;
        }
      } else {
        if (bill.status != 'pending' && bill.status != 'overdue') {
          return false;
        }
      }

      // Free text
      if (query.isNotEmpty) {
        final searchableText = [
          bill.residentName,
          bill.flatLabel,
          bill.id,
          bill.month,
          bill.year,
          bill.status,
        ].join(' ').toLowerCase();

        if (!searchableText.contains(query)) {
          return false;
        }
      }

      // Status
      if (_statusFilter != 'all' &&
          bill.status.toLowerCase() != _statusFilter) {
        return false;
      }

      // Month
      if (_monthFilter != 'all' &&
          bill.month.toLowerCase() != _monthFilter.toLowerCase()) {
        return false;
      }

      // Year
      if (_yearFilter != 'all' && bill.year != _yearFilter) {
        return false;
      }

      // Minimum amount
      if (_minAmountFilter != null && bill.amount < _minAmountFilter!) {
        return false;
      }

      // Maximum amount
      if (_maxAmountFilter != null && bill.amount > _maxAmountFilter!) {
        return false;
      }

      // Due date from
      if (_dueDateFrom != null) {
        if (bill.dueDate == null ||
            bill.dueDate!.isBefore(
              DateTime(
                _dueDateFrom!.year,
                _dueDateFrom!.month,
                _dueDateFrom!.day,
              ),
            )) {
          return false;
        }
      }

      // Due date to
      if (_dueDateTo != null) {
        final inclusiveEnd = DateTime(
          _dueDateTo!.year,
          _dueDateTo!.month,
          _dueDateTo!.day,
          23,
          59,
          59,
        );

        if (bill.dueDate == null || bill.dueDate!.isAfter(inclusiveEnd)) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  Widget _buildBillingSearch(List<BillModel> bills) {
    final years =
        bills
            .map((bill) => bill.year)
            .where((year) => year.trim().isNotEmpty)
            .toSet()
            .toList()
          ..sort((a, b) => b.compareTo(a));

    final activeFilters = [
      _billingSearchQuery.isNotEmpty,
      _statusFilter != 'all',
      _monthFilter != 'all',
      _yearFilter != 'all',
      _minAmountFilter != null,
      _maxAmountFilter != null,
      _dueDateFrom != null,
      _dueDateTo != null,
    ].where((active) => active).length;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _billingSearchController,
                  onChanged: (value) {
                    _searchDebounce?.cancel();

                    _searchDebounce = Timer(
                      const Duration(milliseconds: 300),
                      () {
                        if (!mounted) return;

                        setState(() {
                          _billingSearchQuery = value.trim();
                        });
                      },
                    );
                  },
                  decoration: InputDecoration(
                    hintText: 'Search resident, unit or bill ID',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _billingSearchQuery.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              _billingSearchController.clear();

                              setState(() {
                                _billingSearchQuery = '';
                              });
                            },
                          ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 14.w,
                      vertical: 12.h,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.r),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.r),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                  ),
                ),
              ),

              SizedBox(width: 8.w),

              Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton.filledTonal(
                    onPressed: () {
                      setState(() {
                        _showAdvancedSearch = !_showAdvancedSearch;
                      });
                    },
                    icon: const Icon(Icons.tune),
                    tooltip: 'Advanced search',
                  ),

                  if (activeFilters > 0)
                    Positioned(
                      right: -2,
                      top: -3,
                      child: Container(
                        constraints: const BoxConstraints(
                          minWidth: 18,
                          minHeight: 18,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: const BoxDecoration(
                          color: Color(0xFF0E4778),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '$activeFilters',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),

          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            crossFadeState: _showAdvancedSearch
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: EdgeInsets.only(top: 12.h),
              child: _buildAdvancedBillingFilters(years),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdvancedBillingFilters(List<String> years) {
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

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Advanced Search',
                style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              TextButton(
                onPressed: _clearBillingFilters,
                child: const Text('Clear All'),
              ),
            ],
          ),

          SizedBox(height: 8.h),

          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _statusFilter,
                  decoration: const InputDecoration(
                    labelText: 'Status',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All')),
                    DropdownMenuItem(value: 'pending', child: Text('Pending')),
                    DropdownMenuItem(value: 'overdue', child: Text('Overdue')),
                    DropdownMenuItem(value: 'paid', child: Text('Paid')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _statusFilter = value ?? 'all';
                    });
                  },
                ),
              ),

              SizedBox(width: 10.w),

              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _monthFilter,
                  decoration: const InputDecoration(
                    labelText: 'Month',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem(value: 'all', child: Text('All')),
                    ...months.map(
                      (month) =>
                          DropdownMenuItem(value: month, child: Text(month)),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _monthFilter = value ?? 'all';
                    });
                  },
                ),
              ),
            ],
          ),

          SizedBox(height: 12.h),

          DropdownButtonFormField<String>(
            initialValue: _yearFilter,
            decoration: const InputDecoration(
              labelText: 'Year',
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem(value: 'all', child: Text('All years')),
              ...years.map(
                (year) => DropdownMenuItem(value: year, child: Text(year)),
              ),
            ],
            onChanged: (value) {
              setState(() {
                _yearFilter = value ?? 'all';
              });
            },
          ),

          SizedBox(height: 12.h),

          Row(
            children: [
              Expanded(
                child: TextFormField(
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Min Amount',
                    prefixText: '₹ ',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _minAmountFilter = double.tryParse(value.trim());
                    });
                  },
                ),
              ),

              SizedBox(width: 10.w),

              Expanded(
                child: TextFormField(
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Max Amount',
                    prefixText: '₹ ',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _maxAmountFilter = double.tryParse(value.trim());
                    });
                  },
                ),
              ),
            ],
          ),

          SizedBox(height: 12.h),

          Row(
            children: [
              Expanded(
                child: _buildDateFilterButton(
                  label: 'Due From',
                  value: _dueDateFrom,
                  onTap: () async {
                    final date = await _selectBillingDate(_dueDateFrom);

                    if (date != null) {
                      setState(() {
                        _dueDateFrom = date;
                      });
                    }
                  },
                ),
              ),

              SizedBox(width: 10.w),

              Expanded(
                child: _buildDateFilterButton(
                  label: 'Due To',
                  value: _dueDateTo,
                  onTap: () async {
                    final date = await _selectBillingDate(_dueDateTo);

                    if (date != null) {
                      setState(() {
                        _dueDateTo = date;
                      });
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getExportPeriodLabel(List<BillModel> bills) {
    if (bills.isEmpty) {
      return 'No records';
    }

    final periods = <DateTime>[];

    for (final bill in bills) {
      final month = _monthNumber(bill.month);
      final year = int.tryParse(bill.year);

      if (month != null && year != null) {
        periods.add(DateTime(year, month, 1));
      }
    }

    if (periods.isEmpty) {
      return 'Selected records';
    }

    periods.sort();

    final first = periods.first;
    final last = periods.last;

    if (first.year == last.year && first.month == last.month) {
      return DateFormat('MMMM yyyy').format(first);
    }

    return '${DateFormat('MMM yyyy').format(first)} - '
        '${DateFormat('MMM yyyy').format(last)}';
  }

  Widget _buildDateFilterButton({
    required String label,
    required DateTime? value,
    required VoidCallback onTap,
  }) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.calendar_month_outlined),
      label: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          value == null ? label : DateFormat('dd MMM yyyy').format(value),
          maxLines: 1,
        ),
      ),
    );
  }

  Future<DateTime?> _selectBillingDate(DateTime? initialDate) {
    final now = DateTime.now();

    return showDatePicker(
      context: context,
      initialDate: initialDate ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
    );
  }

  void _clearBillingFilters() {
    _billingSearchController.clear();

    setState(() {
      _billingSearchQuery = '';
      _statusFilter = 'all';
      _monthFilter = 'all';
      _yearFilter = 'all';
      _minAmountFilter = null;
      _maxAmountFilter = null;
      _dueDateFrom = null;
      _dueDateTo = null;
    });
  }

  Future<void> _onViewPaymentReceipt(Map<String, dynamic> payment) async {
    final receiptPath = payment['receiptPath']?.toString() ?? '';

    if (receiptPath.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Receipt is not available.'),
            backgroundColor: Color(0xFFEF4444),
          ),
        );
      }
      return;
    }

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      final bytes = await _billingService.loadPaymentReceipt(receiptPath);
      final paymentId = payment['id']?.toString() ?? '';

      if (paymentId.isNotEmpty) {
        setState(() {
          _viewedPaymentReceiptIds.add(paymentId);
        });
      }
      if (!mounted) return;

      Navigator.of(context, rootNavigator: true).pop();

      await showDialog(
        context: context,
        builder: (dialogContext) {
          return Dialog(
            child: Padding(
              padding: EdgeInsets.all(16.w),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Payment Receipt',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  SizedBox(height: 12.h),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.65,
                    ),
                    child: InteractiveViewer(
                      minScale: 0.5,
                      maxScale: 4,
                      child: Image.memory(bytes, fit: BoxFit.contain),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } catch (e) {
      if (!mounted) return;

      if (Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load receipt: $e'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
  }

  Future<void> _onRejectPaymentProof(
    BillModel bill,
    Map<String, dynamic> payment,
  ) async {
    final paymentId = payment['id']?.toString() ?? '';

    if (paymentId.isEmpty) {
      return;
    }

    final controller = TextEditingController();

    final reason = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Reject Payment Proof'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Payment submitted by ${bill.residentName} will be rejected.',
              ),
              SizedBox(height: 16.h),
              TextField(
                controller: controller,
                maxLines: 3,
                maxLength: 250,
                decoration: const InputDecoration(
                  labelText: 'Reason for rejection',
                  hintText: 'Example: Receipt amount does not match the bill.',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final text = controller.text.trim();

                if (text.isEmpty) {
                  return;
                }

                Navigator.of(dialogContext).pop(text);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
              ),
              child: const Text('Reject'),
            ),
          ],
        );
      },
    );

    if (reason == null || reason.trim().isEmpty) {
      return;
    }
    // Removed redundant check for empty reason as it's already handled above.

    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Rejecting payment proof...'),
            duration: Duration(seconds: 30),
            backgroundColor: Color(0xFF0E4778),
          ),
        );
      }

      await _billingService.rejectPaymentProof(
        paymentId: paymentId,
        rejectionReason: reason,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).clearSnackBars();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment proof rejected for ${bill.residentName}'),
          backgroundColor: const Color(0xFFF59E0B),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).clearSnackBars();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to reject payment: $e'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
  }

  Widget _buildNormalPendingBillActions(BillModel bill) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Semantics(
                label: 'Send reminder button',
                button: true,
                child: OutlinedButton.icon(
                  onPressed: () => _onSendReminder(bill),
                  icon: Icon(Icons.send_outlined, size: 16.w),
                  label: const Text('Remind'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF374151),
                    side: const BorderSide(color: Color(0xFFD1D5DB), width: 1),
                    backgroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(width: 8.w),
            Expanded(
              child: Semantics(
                label: 'Mark as paid button',
                button: true,
                child: ElevatedButton.icon(
                  onPressed: () => _onMarkAsPaid(bill),
                  icon: Icon(Icons.check, size: 16.w),
                  label: const Text('Mark Paid'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 8.h),
        Semantics(
          label: 'Delete bill button',
          button: true,
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _onDeleteBill(bill),
              icon: Icon(Icons.delete_outline, size: 18.w),
              label: const Text('Delete Bill'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFEF4444),
                side: const BorderSide(color: Color(0xFFEF4444), width: 1),
                backgroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 12.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentProofActions(
    BillModel bill,
    Map<String, dynamic> payment,
  ) {
    final paymentId = payment['id']?.toString() ?? '';

    final reference = payment['transactionId']?.toString().trim() ?? '';
    final receiptViewed = _viewedPaymentReceiptIds.contains(paymentId);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: const Color(0xFF86EFAC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.receipt_long_outlined,
                color: const Color(0xFF15803D),
                size: 20.w,
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  'Payment Proof Submitted',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF166534),
                  ),
                ),
              ),
            ],
          ),

          if (reference.isNotEmpty) ...[
            SizedBox(height: 8.h),
            Text(
              'Reference: $reference',
              style: TextStyle(fontSize: 13.sp, color: const Color(0xFF374151)),
            ),
          ],

          SizedBox(height: 12.h),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _onViewPaymentReceipt(payment),
              icon: const Icon(Icons.visibility_outlined),
              label: const Text('View Receipt'),
            ),
          ),

          SizedBox(height: 8.h),

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: paymentId.isEmpty
                      ? null
                      : () => _onRejectPaymentProof(bill, payment),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFDC2626),
                  ),
                  child: const Text('Reject'),
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: paymentId.isEmpty || !receiptViewed
                      ? null
                      : () => _onVerifyPaymentProof(bill, payment),
                  icon: const Icon(Icons.verified_outlined),
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      receiptViewed ? 'Verify' : 'View Receipt First',
                      maxLines: 1,
                      softWrap: false,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _onVerifyPaymentProof(
    BillModel bill,
    Map<String, dynamic> payment,
  ) async {
    final paymentId = payment['id']?.toString() ?? '';

    if (paymentId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment ID is missing.'),
            backgroundColor: Color(0xFFEF4444),
          ),
        );
      }
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Verify Payment'),
          content: Text(
            'Confirm payment of ₹${bill.amount.toStringAsFixed(2)} '
            'for ${bill.residentName}?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
              ),
              child: const Text('Verify'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verifying payment...'),
            duration: Duration(seconds: 30),
            backgroundColor: Color(0xFF0E4778),
          ),
        );
      }

      await _billingService.verifyPaymentProof(paymentId);

      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment verified for ${bill.residentName}'),
            backgroundColor: const Color(0xFF10B981),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to verify payment: $e'),
            backgroundColor: const Color(0xFFEF4444),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }
  // ============================================================================
  // ACTION HANDLERS
  // ============================================================================

  void _onAddBill() {
    CreateMonthlyBillModal.show(
      context,
      onGenerate: (config) async {
        try {
          // Show loading
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  SizedBox(
                    width: 20.w,
                    height: 20.h,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Text('Generating bills...'),
                ],
              ),
              backgroundColor: Color(0xFF0E4778),
              duration: Duration(seconds: 30),
            ),
          );

          // Generate bills with charge breakdown
          final count = await _billingService.generateMonthlyBills(
            adminId: _adminId,
            month: config.monthName,
            year: config.year.toString(),
            totalAmount: config.totalAmount,
            chargeBreakdown: config.chargeBreakdown,
            dueDate: config.dueDate,
            specificFlatIds: config.selectedUnits,
          );

          // Show success
          if (mounted) {
            ScaffoldMessenger.of(context).clearSnackBars();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '$count bills generated successfully (Total: ₹${config.totalAmount.toStringAsFixed(0)})',
                ),
                backgroundColor: const Color(0xFF10B981),
                duration: const Duration(seconds: 3),
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).clearSnackBars();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to generate bills: $e'),
                backgroundColor: const Color(0xFFEF4444),
                duration: const Duration(seconds: 4),
              ),
            );
          }
        }
      },
    );
  }

  void _onSendReminder(BillModel bill) async {
    // Simulate API call
    await Future.delayed(const Duration(milliseconds: 700));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Reminder sent to ${bill.residentName}'),
          backgroundColor: const Color(0xFF10B981),
          duration: const Duration(seconds: 2),
        ),
      );
    }

    // TODO: Integrate with push/SMS/WhatsApp APIs
    // - POST /api/bills/{id}/send-reminder
    // - Send notification via preferred channel
  }

  Future<void> _onMarkAsPaid(BillModel bill) async {
    // Show confirmation dialog for manual payment
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _buildConfirmPaymentDialog(bill),
    );

    if (confirmed != true) return;

    try {
      await _billingService.markBillAsPaid(
        bill.id,
        paymentMethod: 'manual', // Manual payment by admin
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 20.w),
                SizedBox(width: 12.w),
                Expanded(
                  child: Text('Payment confirmed for ${bill.residentName}'),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10.r),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to mark as paid: $e'),
            backgroundColor: const Color(0xFFEF4444),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Widget _buildConfirmPaymentDialog(BillModel bill) {
    String selectedPaymentMethod = 'Cash';
    final paymentMethods = ['Cash', 'Bank Transfer', 'Cheque', 'UPI', 'Other'];

    return StatefulBuilder(
      builder: (context, setState) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.r),
          ),
          contentPadding: EdgeInsets.zero,
          content: Container(
            width: MediaQuery.of(context).size.width * 0.85,
            constraints: BoxConstraints(maxWidth: 400.w),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    padding: EdgeInsets.all(24.w),
                    decoration: BoxDecoration(
                      color: Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(20.r),
                        topRight: Radius.circular(20.r),
                      ),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 64.w,
                          height: 64.h,
                          decoration: BoxDecoration(
                            color: const Color(0xFF0E4778),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF0E4778).withOpacity(0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.payment,
                            color: Colors.white,
                            size: 32.w,
                          ),
                        ),
                        SizedBox(height: 16.h),
                        Text(
                          'Confirm Payment',
                          style: TextStyle(
                            fontSize: 22.sp,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF111111),
                          ),
                        ),
                        SizedBox(height: 6.h),
                        Text(
                          'Mark this bill as paid?',
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Content
                  Padding(
                    padding: EdgeInsets.all(24.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Bill details
                        Container(
                          padding: EdgeInsets.all(16.w),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.circular(12.r),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: Column(
                            children: [
                              _buildDialogDetailRow(
                                'Resident',
                                bill.residentName,
                                Icons.person_outline,
                              ),
                              SizedBox(height: 12.h),
                              _buildDialogDetailRow(
                                'Flat',
                                bill.flatLabel,
                                Icons.home_outlined,
                              ),
                              SizedBox(height: 12.h),
                              _buildDialogDetailRow(
                                'Amount',
                                '₹${bill.amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}',
                                Icons.currency_rupee,
                                isAmount: true,
                              ),
                              SizedBox(height: 12.h),
                              _buildDialogDetailRow(
                                'Date',
                                DateFormat(
                                  'dd MMM yyyy',
                                ).format(DateTime.now()),
                                Icons.calendar_today_outlined,
                              ),
                            ],
                          ),
                        ),

                        SizedBox(height: 20.h),

                        // Payment method
                        Text(
                          'Payment Method',
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF374151),
                          ),
                        ),
                        SizedBox(height: 10.h),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 14.w),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12.r),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: selectedPaymentMethod,
                              isExpanded: true,
                              icon: const Icon(
                                Icons.keyboard_arrow_down,
                                color: Color(0xFF9CA3AF),
                              ),
                              style: TextStyle(
                                fontSize: 15.sp,
                                color: Color(0xFF111111),
                              ),
                              items: paymentMethods.map((method) {
                                return DropdownMenuItem(
                                  value: method,
                                  child: Row(
                                    children: [
                                      Icon(
                                        _getPaymentIcon(method),
                                        size: 20.w,
                                        color: const Color(0xFF6B7280),
                                      ),
                                      SizedBox(width: 10.w),
                                      Text(method),
                                    ],
                                  ),
                                );
                              }).toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() {
                                    selectedPaymentMethod = value;
                                  });
                                }
                              },
                            ),
                          ),
                        ),

                        SizedBox(height: 20.h),

                        // Warning
                        Container(
                          padding: EdgeInsets.all(12.w),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(10.r),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: Color(0xFFF59E0B),
                                size: 20.w,
                              ),
                              SizedBox(width: 10.w),
                              Expanded(
                                child: Text(
                                  'This action will mark the bill as paid and cannot be undone.',
                                  style: TextStyle(
                                    fontSize: 12.sp,
                                    color: Colors.grey[800],
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Buttons
                  Container(
                    padding: EdgeInsets.fromLTRB(24.w, 0, 24.w, 24.h),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: 14.h),
                              side: const BorderSide(
                                color: Color(0xFFE5E7EB),
                                width: 1.5,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                            ),
                            child: Text(
                              'Cancel',
                              style: TextStyle(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            style: ElevatedButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: 14.h),
                              backgroundColor: const Color(0xFF10B981),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                            ),
                            child: Text(
                              'Confirm',
                              style: TextStyle(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDialogDetailRow(
    String label,
    String value,
    IconData icon, {
    bool isAmount = false,
  }) {
    return Row(
      children: [
        Container(
          width: 32.w,
          height: 32.h,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8.r),
          ),
          child: Icon(icon, size: 18.w, color: const Color(0xFF6B7280)),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 12.sp, color: Colors.grey[600]),
              ),
              SizedBox(height: 2.h),
              isAmount
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.currency_rupee,
                          size: 18.w,
                          color: const Color(0xFF10B981),
                        ),
                        Text(
                          value.replaceFirst('₹', ''),
                          style: TextStyle(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF10B981),
                          ),
                        ),
                      ],
                    )
                  : Text(
                      value,
                      style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF111111),
                      ),
                    ),
            ],
          ),
        ),
      ],
    );
  }

  IconData _getPaymentIcon(String method) {
    switch (method) {
      case 'Cash':
        return Icons.money;
      case 'Bank Transfer':
        return Icons.account_balance;
      case 'Cheque':
        return Icons.receipt_long;
      case 'UPI':
        return Icons.qr_code_scanner;
      default:
        return Icons.payment;
    }
  }

  void _onDownloadBill(BillModel bill) async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: Container(
            padding: EdgeInsets.all(24.w),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16.r),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16.h),
                Text(
                  'Generating Invoice...',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      // Generate PDF invoice
      final invoiceService = InvoiceGeneratorService();
      final pdfFile = await invoiceService.generateInvoice(bill);

      // Automatically download to device storage
      final savedPath = await invoiceService.downloadInvoice(pdfFile);

      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();
      }

      // Show success dialog with options
      if (mounted) {
        _showDownloadSuccessDialog(pdfFile, bill, savedPath, invoiceService);
      }
    } catch (e) {
      // Close loading dialog if open
      if (mounted) {
        Navigator.of(context).pop();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white, size: 20.w),
                SizedBox(width: 12.w),
                Expanded(child: Text('Failed to generate invoice: $e')),
              ],
            ),
            backgroundColor: const Color(0xFFEF4444),
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10.r),
            ),
          ),
        );
      }
    }
  }

  void _showDownloadSuccessDialog(
    File pdfFile,
    BillModel bill,
    String savedPath,
    InvoiceGeneratorService invoiceService,
  ) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Container(
          constraints: BoxConstraints(maxWidth: 400.w),
          padding: EdgeInsets.all(24.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Success icon
              Container(
                width: 72.w,
                height: 72.h,
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle,
                  color: Color(0xFF10B981),
                  size: 40.w,
                ),
              ),
              SizedBox(height: 20.h),

              // Title
              Text(
                'Invoice Downloaded',
                style: TextStyle(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111111),
                ),
              ),
              SizedBox(height: 8.h),

              // Subtitle
              Text(
                'Invoice for ${bill.residentName}',
                style: TextStyle(fontSize: 14.sp, color: Color(0xFF6B7280)),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 4.h),
              Text(
                'Flat ${bill.flatLabel} • ${bill.month} ${bill.year}',
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF374151),
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16.h),

              // File location info
              Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.folder_outlined,
                      color: Color(0xFF6B7280),
                      size: 20.w,
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Saved to Downloads',
                            style: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF374151),
                            ),
                          ),
                          SizedBox(height: 2.h),
                          Text(
                            pdfFile.path.split('/').last,
                            style: TextStyle(
                              fontSize: 11.sp,
                              color: Color(0xFF6B7280),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 24.h),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        try {
                          await invoiceService.shareInvoice(pdfFile, bill);
                          if (mounted) {
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Row(
                                  children: [
                                    Icon(
                                      Icons.share,
                                      color: Colors.white,
                                      size: 20.w,
                                    ),
                                    SizedBox(width: 12.w),
                                    Text('Invoice shared successfully'),
                                  ],
                                ),
                                backgroundColor: const Color(0xFF10B981),
                                duration: const Duration(seconds: 2),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10.r),
                                ),
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Failed to share: $e'),
                                backgroundColor: const Color(0xFFEF4444),
                              ),
                            );
                          }
                        }
                      },
                      icon: Icon(Icons.share_outlined, size: 20.w),
                      label: const Text('Share'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF0E4778),
                        side: const BorderSide(
                          color: Color(0xFF0E4778),
                          width: 1.5,
                        ),
                        padding: EdgeInsets.symmetric(vertical: 14.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      icon: Icon(Icons.done, size: 20.w),
                      label: const Text('Done'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 14.h),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onDeleteBill(BillModel bill) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _buildDeleteConfirmationDialog(bill),
    );

    if (confirmed != true) return;

    try {
      // Delete bill from Firestore
      await _billingService.deleteBill(bill.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 20.w),
                SizedBox(width: 12.w),
                Expanded(child: Text('Bill deleted for ${bill.residentName}')),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10.r),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white, size: 20.w),
                SizedBox(width: 12.w),
                Expanded(child: Text('Failed to delete bill: $e')),
              ],
            ),
            backgroundColor: const Color(0xFFEF4444),
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10.r),
            ),
          ),
        );
      }
    }
  }

  Widget _buildDeleteConfirmationDialog(BillModel bill) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
      contentPadding: EdgeInsets.zero,
      content: Container(
        width: MediaQuery.of(context).size.width * 0.85,
        constraints: BoxConstraints(maxWidth: 400.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(24.w),
              decoration: BoxDecoration(
                color: Color(0xFFFEF2F2),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20.r),
                  topRight: Radius.circular(20.r),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: 64.w,
                    height: 64.h,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFEF4444).withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.delete_outline,
                      color: Colors.white,
                      size: 32.w,
                    ),
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    'Delete Bill?',
                    style: TextStyle(
                      fontSize: 22.sp,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111111),
                    ),
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    'This action cannot be undone',
                    style: TextStyle(fontSize: 14.sp, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),

            // Content
            Padding(
              padding: EdgeInsets.all(24.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Bill details
                  Container(
                    padding: EdgeInsets.all(16.w),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Column(
                      children: [
                        _buildDialogDetailRow(
                          'Resident',
                          bill.residentName,
                          Icons.person_outline,
                        ),
                        SizedBox(height: 12.h),
                        _buildDialogDetailRow(
                          'Flat',
                          bill.flatLabel,
                          Icons.home_outlined,
                        ),
                        SizedBox(height: 12.h),
                        _buildDialogDetailRow(
                          'Amount',
                          '₹${bill.amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}',
                          Icons.currency_rupee,
                          isAmount: true,
                        ),
                        SizedBox(height: 12.h),
                        _buildDialogDetailRow(
                          'Period',
                          '${bill.month} ${bill.year}',
                          Icons.calendar_today_outlined,
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 20.h),

                  // Warning
                  Container(
                    padding: EdgeInsets.all(12.w),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: Color(0xFFEF4444),
                          size: 20.w,
                        ),
                        SizedBox(width: 10.w),
                        Expanded(
                          child: Text(
                            'Deleting this bill will permanently remove it from the system.',
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: Colors.grey[800],
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Buttons
            Container(
              padding: EdgeInsets.fromLTRB(24.w, 0, 24.w, 24.h),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 14.h),
                        side: const BorderSide(
                          color: Color(0xFFE5E7EB),
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 14.h),
                        backgroundColor: const Color(0xFFEF4444),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                      ),
                      child: Text(
                        'Delete',
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onExportPDF(List<BillModel> bills) async {
    if (bills.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No bills available to export'),
            backgroundColor: Color(0xFFF59E0B),
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Generating billing PDF...'),
          backgroundColor: Color(0xFF0E4778),
          duration: Duration(seconds: 30),
        ),
      );
    }

    try {
      final communityId = AdminTenantContext.instance.requireCommunityId();
      final generatedAt = DateTime.now();
      final currencyFormat = NumberFormat('#,##0.00');
      final reportPeriod = _getExportPeriodLabel(bills);
      final logoBytes = await rootBundle.load('assets/Admin_New.png');

      final hominodeLogo = pw.MemoryImage(logoBytes.buffer.asUint8List());

      final totalAmount = bills.fold<double>(
        0,
        (sum, bill) => sum + bill.amount,
      );
      final paidAmount = bills
          .where((bill) => bill.status == 'paid')
          .fold<double>(0, (sum, bill) => sum + bill.amount);
      final pendingAmount = bills
          .where((bill) => bill.status == 'pending')
          .fold<double>(0, (sum, bill) => sum + bill.amount);
      final overdueAmount = bills
          .where((bill) => bill.status == 'overdue')
          .fold<double>(0, (sum, bill) => sum + bill.amount);

      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(28),
          header: (context) => pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 12),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: PdfColors.blue900, width: 1.5),
              ),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Image(hominodeLogo, width: 38, height: 38),
                pw.SizedBox(width: 10),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'HOMINODE',
                      style: pw.TextStyle(
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue900,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'Billing & Collection Report',
                      style: pw.TextStyle(
                        fontSize: 13,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.grey800,
                      ),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'Community: $communityId',
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 3),
                    pw.Text(
                      'Report Period: $reportPeriod',
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue900,
                      ),
                    ),
                    pw.SizedBox(height: 3),
                    pw.Text(
                      'Generated: ${DateFormat('dd MMM yyyy, hh:mm a').format(generatedAt)}',
                      style: const pw.TextStyle(
                        fontSize: 8,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          footer: (context) => pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
            ),
          ),
          build: (context) => [
            pw.SizedBox(height: 12),
            pw.Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _buildPdfSummaryCard('Bills', bills.length.toString()),
                _buildPdfSummaryCard(
                  'Total',
                  'INR ${currencyFormat.format(totalAmount)}',
                ),
                _buildPdfSummaryCard(
                  'Paid',
                  'INR ${currencyFormat.format(paidAmount)}',
                ),
                _buildPdfSummaryCard(
                  'Pending',
                  'INR ${currencyFormat.format(pendingAmount)}',
                ),
                _buildPdfSummaryCard(
                  'Overdue',
                  'INR ${currencyFormat.format(overdueAmount)}',
                ),
              ],
            ),
            pw.SizedBox(height: 18),
            pw.Table.fromTextArray(
              headers: const [
                'Resident',
                'Flat',
                'Period',
                'Amount',
                'Status',
                'Due Date',
                'Paid Date',
              ],
              data: bills.map((bill) {
                return [
                  bill.residentName,
                  bill.flatLabel,
                  '${bill.month} ${bill.year}',
                  'INR ${currencyFormat.format(bill.amount)}',
                  bill.status.toUpperCase(),
                  bill.dueDate != null
                      ? DateFormat('dd MMM yyyy').format(bill.dueDate!)
                      : '-',
                  bill.paidAt != null
                      ? DateFormat('dd MMM yyyy').format(bill.paidAt!)
                      : '-',
                ];
              }).toList(),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.blue900,
              ),
              headerStyle: pw.TextStyle(
                color: PdfColors.white,
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
              ),
              cellStyle: const pw.TextStyle(fontSize: 8),
              cellAlignment: pw.Alignment.centerLeft,
              cellPadding: const pw.EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 6,
              ),
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              rowDecoration: const pw.BoxDecoration(color: PdfColors.white),
              oddRowDecoration: const pw.BoxDecoration(
                color: PdfColors.grey100,
              ),
              columnWidths: {
                0: const pw.FlexColumnWidth(1.6),
                1: const pw.FlexColumnWidth(0.8),
                2: const pw.FlexColumnWidth(1.0),
                3: const pw.FlexColumnWidth(1.0),
                4: const pw.FlexColumnWidth(0.8),
                5: const pw.FlexColumnWidth(1.1),
                6: const pw.FlexColumnWidth(1.1),
              },
            ),
          ],
        ),
      );

      final bytes = await pdf.save();
      final fileName =
          'hominode_billing_report_${DateFormat('yyyyMMdd_HHmm').format(generatedAt)}.pdf';

      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
      }

      await Printing.sharePdf(bytes: bytes, filename: fileName);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Billing PDF generated successfully'),
            backgroundColor: Color(0xFF10B981),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e, stackTrace) {
      debugPrint('Billing PDF export failed: $e');
      debugPrint('$stackTrace');

      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export PDF: $e'),
            backgroundColor: const Color(0xFFEF4444),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  pw.Widget _buildPdfSummaryCard(String label, String value) {
    return pw.Container(
      width: 125,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue900,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onExportExcel(List<BillModel> bills) async {
    if (bills.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No billing records available to export.'),
            backgroundColor: Color(0xFFF59E0B),
          ),
        );
      }
      return;
    }
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );
    }
    final reportPeriod = _getExportPeriodLabel(bills);
    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Generating Excel report...'),
            backgroundColor: Color(0xFF0E4778),
            duration: Duration(seconds: 2),
          ),
        );
      }

      final communityId = AdminTenantContext.instance.requireCommunityId();

      final excel = xls.Excel.createExcel();

      // Rename default sheet.
      final defaultSheet = excel.getDefaultSheet();
      if (defaultSheet != null && defaultSheet != 'Billing Report') {
        excel.rename(defaultSheet, 'Billing Report');
      }

      final sheet = excel['Billing Report'];

      // Report information.
      sheet.appendRow([xls.TextCellValue('HOMINODE BILLING REPORT')]);

      sheet.appendRow([
        xls.TextCellValue('Community'),
        xls.TextCellValue(communityId),
      ]);

      sheet.appendRow([
        xls.TextCellValue('Report Period'),
        xls.TextCellValue(reportPeriod),
      ]);

      sheet.appendRow([
        xls.TextCellValue('Generated'),
        xls.TextCellValue(
          DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now()),
        ),
      ]);

      sheet.appendRow([]);

      // Empty row.
      sheet.appendRow([]);

      // Column headers.
      sheet.appendRow([
        xls.TextCellValue('Resident'),
        xls.TextCellValue('Unit'),
        xls.TextCellValue('Period'),
        xls.TextCellValue('Amount (INR)'),
        xls.TextCellValue('Status'),
        xls.TextCellValue('Due Date'),
        xls.TextCellValue('Paid Date'),
      ]);
      final titleCell = sheet.cell(xls.CellIndex.indexByString('A1'));

      titleCell.cellStyle = xls.CellStyle(
        bold: true,
        fontSize: 18,
        fontColorHex: xls.ExcelColor.fromHexString('#0E4778'),
      );

      final headerStyle = xls.CellStyle(
        bold: true,
        fontColorHex: xls.ExcelColor.fromHexString('#FFFFFF'),
        backgroundColorHex: xls.ExcelColor.fromHexString('#0E4778'),
        horizontalAlign: xls.HorizontalAlign.Center,
        verticalAlign: xls.VerticalAlign.Center,
      );
      // Apply header style to column headers.
      for (var col = 0; col < 7; col++) {
        final cell = sheet.cell(
          xls.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 9),
        );
        cell.cellStyle = headerStyle;
      }
      for (final bill in bills) {
        sheet.appendRow([
          xls.TextCellValue(bill.residentName),
          xls.TextCellValue(bill.flatLabel),
          xls.TextCellValue('${bill.month} ${bill.year}'),
          xls.DoubleCellValue(bill.amount),
          xls.TextCellValue(bill.status.toUpperCase()),
          xls.TextCellValue(
            bill.dueDate == null
                ? ''
                : DateFormat('dd-MM-yyyy').format(bill.dueDate!),
          ),
          xls.TextCellValue(
            bill.paidAt == null
                ? ''
                : DateFormat('dd-MM-yyyy').format(bill.paidAt!),
          ),
        ]);
      }

      // Summary section.
      final totalAmount = bills.fold<double>(
        0,
        (sum, bill) => sum + bill.amount,
      );

      final paidAmount = bills
          .where((bill) => bill.status == 'paid')
          .fold<double>(0, (sum, bill) => sum + bill.amount);

      final pendingAmount = bills
          .where((bill) => bill.status == 'pending')
          .fold<double>(0, (sum, bill) => sum + bill.amount);

      final overdueAmount = bills
          .where((bill) => bill.status == 'overdue')
          .fold<double>(0, (sum, bill) => sum + bill.amount);

      sheet.appendRow([]);
      sheet.appendRow([xls.TextCellValue('SUMMARY')]);

      sheet.appendRow([
        xls.TextCellValue('Total Bills'),
        xls.IntCellValue(bills.length),
      ]);

      sheet.appendRow([
        xls.TextCellValue('Total Amount'),
        xls.DoubleCellValue(totalAmount),
      ]);

      sheet.appendRow([
        xls.TextCellValue('Paid Amount'),
        xls.DoubleCellValue(paidAmount),
      ]);

      sheet.appendRow([
        xls.TextCellValue('Pending Amount'),
        xls.DoubleCellValue(pendingAmount),
      ]);

      sheet.appendRow([
        xls.TextCellValue('Overdue Amount'),
        xls.DoubleCellValue(overdueAmount),
      ]);
      sheet.setColumnWidth(0, 24); // Resident
      sheet.setColumnWidth(1, 12); // Unit
      sheet.setColumnWidth(2, 16); // Period
      sheet.setColumnWidth(3, 16); // Amount
      sheet.setColumnWidth(4, 12); // Status
      sheet.setColumnWidth(5, 16); // Due Date
      sheet.setColumnWidth(6, 16); // Paid Date

      final bytes = excel.encode();

      if (bytes == null) {
        throw StateError('Excel file could not be generated.');
      }

      final tempDir = await getTemporaryDirectory();

      final fileName =
          'hominode_billing_${communityId}_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.xlsx';

      final file = File('${tempDir.path}/$fileName');

      await file.writeAsBytes(bytes, flush: true);
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Hominode Billing Report',
        text: 'Billing report for $communityId',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Excel report created successfully.'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted && Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export Excel: $e'),
            backgroundColor: const Color(0xFFEF4444),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }
  // ============================================================================
  // BUILD METHOD
  // ============================================================================

  @override
  Widget build(BuildContext context) {
    if (AdminDesktopPresentationScope.isActive(context)) {
      return AdminDesktopPageFrame(
        title: 'Billing & Payments',
        subtitle: 'Review bills, payment history, and collection performance.',
        actions: [
          AdminDesktopPrimaryAction(
            label: 'Add Bill',
            icon: Icons.post_add_outlined,
            onPressed: _onAddBill,
          ),
        ],
        child: StreamBuilder<List<BillModel>>(
          stream: _billsStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return const Center(child: Text('Unable to load billing data.'));
            }
            final bills = snapshot.data ?? [];
            final kpiData = _billingService.calculateKPIs(bills);
            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildKPICards(kpiData),
                  SizedBox(height: 16.h),
                  _buildBillingSearch(bills),
                  SizedBox(height: 16.h),
                  _buildTabs(),
                  SizedBox(height: 12.h),
                  _buildDesktopBillTable(
                    bills,
                    paymentHistory: _selectedTab == 1,
                  ),
                  SizedBox(height: 12.h),
                  _buildExportSection(bills),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: StreamBuilder<List<BillModel>>(
        stream: _billsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 48.w,
                    color: Color(0xFFEF4444),
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    'Error loading bills: ${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Color(0xFF6B7280)),
                  ),
                ],
              ),
            );
          }

          final bills = snapshot.data ?? [];
          final kpiData = _billingService.calculateKPIs(bills);

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              const StandardHeader(title: 'Billing & Payments'),
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader(),
                    SizedBox(height: 12.h),
                    _buildKPICards(kpiData),
                    SizedBox(height: 16.h),

                    _buildBillingSearch(bills),

                    SizedBox(height: 16.h),
                    _buildTabs(),
                    SizedBox(height: 12.h),
                    _selectedTab == 0
                        ? _buildBillsList(bills)
                        : _buildPaymentHistory(bills),
                    SizedBox(height: 12.h),
                    _buildExportSection(bills),
                    SizedBox(height: 100.h), // Space for bottom nav
                  ],
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: const StandardBottomNav(
        selectedIndex: 3, // Billing tab
      ),
    );
  }

  Widget _buildDesktopBillTable(
    List<BillModel> allBills, {
    required bool paymentHistory,
  }) {
    final bills = _filterBills(allBills, paymentHistory: paymentHistory);
    if (bills.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: Text('No matching billing records')),
      );
    }

    Widget cell(String value, {int flex = 1, FontWeight? weight}) => Expanded(
      flex: flex,
      child: Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: const Color(0xFF334E68),
          fontSize: 12,
          fontWeight: weight,
        ),
      ),
    );

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE1E8EF)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: const Color(0xFFF3F6F9),
            child: Row(
              children: [
                cell('Resident', flex: 2, weight: FontWeight.w700),
                cell('Unit', weight: FontWeight.w700),
                cell('Period', weight: FontWeight.w700),
                cell('Amount', weight: FontWeight.w700),
                cell('Status', weight: FontWeight.w700),
                const SizedBox(width: 250, child: Text('Actions')),
              ],
            ),
          ),
          for (final bill in bills)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFEDF1F5))),
              ),
              child: Row(
                children: [
                  cell(bill.residentName, flex: 2, weight: FontWeight.w600),
                  cell(bill.flatLabel),
                  cell('${bill.month} ${bill.year}'),
                  cell('₹${bill.amount.toStringAsFixed(0)}'),
                  cell(bill.status),
                  SizedBox(width: 250, child: _buildActionButtons(bill)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ============================================================================
  // UI COMPONENTS
  // ============================================================================

  Widget _buildSectionHeader() {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Maintenance & Billing',
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111111),
            ),
          ),
          Semantics(
            label: 'Create new bill',
            button: true,
            child: InkWell(
              onTap: _onAddBill,
              borderRadius: BorderRadius.circular(18.r),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
                decoration: BoxDecoration(
                  color: const Color(0xFF0E4778),
                  borderRadius: BorderRadius.circular(18.r),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add, color: Colors.white, size: 16.w),
                    SizedBox(width: 4.w),
                    Text(
                      'Create Bill',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKPICards(Map<String, dynamic> kpiData) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildKPICard(
                  label: 'Total Revenue',
                  value:
                      '₹${(kpiData['totalRevenue'] / 100000).toStringAsFixed(1)}L',
                  valueColor: const Color(0xFF0E4778),
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: _buildKPICard(
                  label: 'Collected',
                  value: '${kpiData['collected']}%',
                  valueColor: const Color(0xFF10B981),
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          Row(
            children: [
              Expanded(
                child: _buildKPICard(
                  label: 'Pending',
                  value: '₹${(kpiData['pending'] / 1000).toStringAsFixed(0)}K',
                  valueColor: const Color(0xFFF59E0B),
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: _buildKPICard(
                  label: 'Overdue',
                  value: '₹${(kpiData['overdue'] / 1000).toStringAsFixed(0)}K',
                  valueColor: const Color(0xFF0E4778),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKPICard({
    required String label,
    required String value,
    required Color valueColor,
  }) {
    return Container(
      height: 85.h,
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11.sp,
              fontWeight: FontWeight.w400,
              color: Color(0xFF9CA3AF),
              height: 1.2,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.currency_rupee, size: 20.w, color: valueColor),
              Text(
                value.replaceFirst('₹', ''),
                style: TextStyle(
                  fontSize: 24.sp,
                  fontWeight: FontWeight.w700,
                  color: valueColor,
                  height: 1.0,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Container(
        padding: EdgeInsets.all(3.w),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(22.r),
        ),
        child: Row(
          children: [
            Expanded(
              child: _buildTabButton(
                label: 'Bills',
                isSelected: _selectedTab == 0,
                onTap: () => setState(() => _selectedTab = 0),
              ),
            ),
            Expanded(
              child: _buildTabButton(
                label: 'Payment History',
                isSelected: _selectedTab == 1,
                onTap: () => setState(() => _selectedTab = 1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(vertical: 10.h),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(19.r),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 6,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected
                ? const Color(0xFF111111)
                : const Color(0xFF6B7280),
          ),
        ),
      ),
    );
  }

  Widget _buildBillsList(List<BillModel> allBills) {
    final bills = _filterBills(allBills, paymentHistory: false);

    if (bills.isEmpty) {
      return Padding(
        padding: EdgeInsets.all(32.w),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.search_off, size: 56.w, color: Colors.grey[400]),
              SizedBox(height: 12.h),
              Text(
                'No matching bills',
                style: TextStyle(fontSize: 15.sp, color: Colors.grey[600]),
              ),
              SizedBox(height: 6.h),
              Text(
                'Try changing your search or filters.',
                style: TextStyle(fontSize: 13.sp, color: Colors.grey[500]),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Column(
        children: bills.map((bill) {
          return Padding(
            padding: EdgeInsets.only(bottom: 12.h),
            child: _buildBillCard(bill),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBillCard(BillModel bill) {
    // Convert BillModel to display format
    final statusColor = bill.status == 'paid'
        ? const Color(0xFF10B981)
        : bill.status == 'overdue'
        ? const Color(0xFFEF4444)
        : const Color(0xFFF59E0B);

    final statusText = bill.status == 'paid'
        ? 'Paid'
        : bill.status == 'overdue'
        ? 'Overdue'
        : 'Pending';

    return Semantics(
      label:
          'Bill card for ${bill.residentName}, unit ${bill.flatLabel}, status $statusText, amount ₹${bill.amount.toStringAsFixed(0)}',
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Name + Status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          bill.residentName,
                          style: TextStyle(
                            fontSize: 17.sp,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF111111),
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          bill.flatLabel,
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: Color(0xFF9CA3AF),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 6.h,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 14.h),
              // Amount & Due Date
              Container(
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Amount',
                            style: TextStyle(
                              fontSize: 13.sp,
                              color: Color(0xFF9CA3AF),
                            ),
                          ),
                          SizedBox(height: 6.h),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.currency_rupee,
                                size: 16.w,
                                color: Color(0xFF111111),
                              ),
                              Text(
                                bill.amount
                                    .toStringAsFixed(0)
                                    .replaceAllMapped(
                                      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                                      (Match m) => '${m[1]},',
                                    ),
                                style: TextStyle(
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF111111),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Due Date',
                            style: TextStyle(
                              fontSize: 13.sp,
                              color: Color(0xFF9CA3AF),
                            ),
                          ),
                          SizedBox(height: 6.h),
                          Text(
                            bill.dueDate != null
                                ? DateFormat('yyyy-MM-dd').format(bill.dueDate!)
                                : 'N/A',
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF111111),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Paid status (if paid)
              if (bill.status == 'paid' && bill.paidAt != null) ...[
                SizedBox(height: 10.h),
                Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      size: 16.w,
                      color: Color(0xFF16A34A),
                    ),
                    SizedBox(width: 6.w),
                    Text(
                      'Paid on ${DateFormat('yyyy-MM-dd').format(bill.paidAt!)}',
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF16A34A),
                      ),
                    ),
                  ],
                ),
              ],
              SizedBox(height: 12.h),
              // Action buttons
              // Action buttons
              _buildActionButtons(bill),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons(BillModel bill) {
    print(
      '💳 BUILD ACTIONS: bill=${bill.id}, '
      'status=${bill.status}, community=${bill.communityId}',
    );

    if (bill.status == 'paid') {
      // Download + Delete buttons for paid bills
      return Row(
        children: [
          Expanded(
            child: Semantics(
              label: 'Download bill button',
              button: true,
              child: OutlinedButton.icon(
                onPressed: () => _onDownloadBill(bill),
                icon: Icon(Icons.download_outlined, size: 18.w),
                label: const Text('Download'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF374151),
                  side: const BorderSide(color: Color(0xFFD1D5DB), width: 1),
                  backgroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 12.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(width: 8.w),
          Semantics(
            label: 'Delete bill button',
            button: true,
            child: OutlinedButton(
              onPressed: () => _onDeleteBill(bill),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFEF4444),
                side: const BorderSide(color: Color(0xFFEF4444), width: 1),
                backgroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
              ),
              child: Icon(Icons.delete_outline, size: 18.w),
            ),
          ),
        ],
      );
    } else {
      return StreamBuilder<Map<String, dynamic>?>(
        stream: _paymentProofStreamForBill(bill),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            print('❌ ADMIN PAYMENT PROOF STREAM ERROR: ${snapshot.error}');

            return _buildNormalPendingBillActions(bill);
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return Padding(
              padding: EdgeInsets.symmetric(vertical: 12.h),
              child: const Center(child: CircularProgressIndicator()),
            );
          }

          final payment = snapshot.data;

          if (payment != null) {
            return _buildPaymentProofActions(bill, payment);
          }

          return _buildNormalPendingBillActions(bill);
        },
      );
    }
  }

  Widget _buildPaymentHistory(List<BillModel> allBills) {
    final paidBills = _filterBills(allBills, paymentHistory: true);

    if (paidBills.isEmpty) {
      return Padding(
        padding: EdgeInsets.all(32.w),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.history, size: 56.w, color: Colors.grey[400]),
              SizedBox(height: 12.h),
              Text(
                'No payment history',
                style: TextStyle(fontSize: 15.sp, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Column(
        children: paidBills.map((bill) {
          return Padding(
            padding: EdgeInsets.only(bottom: 12.h),
            child: _buildBillCard(bill),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildExportSection(List<BillModel> bills) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Export Reports',
              style: TextStyle(
                fontSize: 17.sp,
                fontWeight: FontWeight.w600,
                color: Color(0xFF111111),
              ),
            ),
            SizedBox(height: 14.h),
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    label: 'Export PDF',
                    button: true,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final exportBills = await _showExportOptions(bills);

                        if (exportBills == null || exportBills.isEmpty) {
                          return;
                        }

                        await _onExportPDF(exportBills);
                      },
                      icon: Icon(Icons.download_outlined, size: 18.w),
                      label: const Text('Export PDF'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF374151),
                        side: const BorderSide(
                          color: Color(0xFFD1D5DB),
                          width: 1,
                        ),
                        backgroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 12.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: Semantics(
                    label: 'Export Excel',
                    button: true,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final exportBills = await _showExportOptions(bills);

                        if (exportBills == null || exportBills.isEmpty) {
                          return;
                        }

                        await _onExportExcel(exportBills);
                      },
                      icon: Icon(Icons.download_outlined, size: 18.w),
                      label: const Text('Export Excel'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF374151),
                        side: const BorderSide(
                          color: Color(0xFFD1D5DB),
                          width: 1,
                        ),
                        backgroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 12.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
