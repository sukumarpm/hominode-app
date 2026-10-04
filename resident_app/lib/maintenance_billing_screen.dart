import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import 'payment_history_screen.dart';
import 'resident_billing_statement_screen.dart';
import 'receipt_screen.dart';
import 'src/components/standard_screen.dart';
import 'src/providers/language_provider.dart';
import 'src/screens/submit_payment_proof_screen.dart';
import 'src/services/bill_firestore_service.dart';
import 'src/services/resident_direct_upi_service.dart';
import 'src/services/resident_billing_statement_service.dart';
import 'src/utils/payment_method.dart';
import 'src/widgets/cash_payment_info_card.dart';
import 'src/widgets/direct_upi_payment_card.dart';

// Design Constants
const kPrimaryBlue = Color(0xFF0E4778);
const kBackground = Color(0xFFFFFFFF);
const kDivider = Color(0xFFE6E6E6);
const kOrangeStart = Color(0xFFFF7A30);
const kOrangeEnd = Color(0xFFFF4E17);
const kPendingBg = Color(0xFFFFB59E);
const kPendingText = Color(0xFFA33E0C);
const kSuccessBg = Color(0xFFE9FCEB);
const kSuccessIcon = Color(0xFF12B76A);
const kDarkTitle = Color(0xFF111111);
const kSubtext = Color(0xFF7A7A7A);
const kBlackText = Color(0xFF333333);

const kSpacing = 16.0;
const kRadius = 16.0;

/// Maintenance & Billing Screen - Real-time Firestore Integration
class MaintenanceBillingScreen extends StatefulWidget {
  const MaintenanceBillingScreen({
    super.key,
    this.billService,
    this.directUpiService,
    this.statementService,
    this.languageCodeOverride,
  });

  final BillFirestoreService? billService;
  final ResidentDirectUpiService? directUpiService;
  final ResidentBillingStatementService? statementService;
  final String? languageCodeOverride;

  @override
  State<MaintenanceBillingScreen> createState() =>
      _MaintenanceBillingScreenState();
}

class _MaintenanceBillingScreenState extends State<MaintenanceBillingScreen> {
  late final BillFirestoreService _billService =
      widget.billService ?? BillFirestoreService();
  late final ResidentDirectUpiService _directUpiService =
      widget.directUpiService ?? ResidentDirectUpiService();

  Widget _buildSubmitPaymentCard(Map<String, dynamic> bill) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DirectUpiPaymentCard(
          billId: bill['id']?.toString() ?? '',
          preparePayment: _directUpiService.preparePayment,
          onSubmitProof: () async {
            await Navigator.push<bool>(
              context,
              MaterialPageRoute(
                builder: (_) => SubmitPaymentProofScreen(
                  bill: bill,
                  service: _directUpiService,
                ),
              ),
            );
          },
        ),
        SizedBox(height: 12.h),
        const CashPaymentInfoCard(),
      ],
    );
  }

  Widget _buildPaymentSubmittedCard(Map<String, dynamic> payment) {
    final method = normalizePaymentMethod(payment['method']);
    final provider = normalizePaymentProvider(payment['provider']);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(kRadius),
        border: Border.all(color: kDivider),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.hourglass_top_rounded, color: kPrimaryBlue, size: 28.w),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Payment Submitted',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w600,
                    color: kDarkTitle,
                  ),
                ),
                SizedBox(height: 6.h),
                Text(
                  '$method / $provider',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: kPrimaryBlue,
                  ),
                ),
                SizedBox(height: 6.h),
                Text(
                  'Your payment receipt has been submitted and is awaiting administrator verification.',
                  style: TextStyle(
                    fontSize: 14.sp,
                    height: 1.4,
                    color: kSubtext,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentRejectedCard(
    Map<String, dynamic> bill,
    Map<String, dynamic> payment,
  ) {
    final reason = payment['rejectionReason']?.toString().trim();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(kRadius),
        border: Border.all(color: kDivider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Payment Rejected',
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.w600,
              color: Colors.red,
            ),
          ),
          if (reason != null && reason.isNotEmpty) ...[
            SizedBox(height: 8.h),
            Text(
              'Reason: $reason',
              style: TextStyle(fontSize: 14.sp, color: kSubtext),
            ),
          ],
          SizedBox(height: 16.h),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SubmitPaymentProofScreen(
                      bill: bill,
                      service: _directUpiService,
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimaryBlue,
                foregroundColor: Colors.white,
              ),
              child: const Text('Resubmit Payment Proof'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentAction(Map<String, dynamic> bill) {
    final billId = bill['id']?.toString() ?? '';

    if (BillFirestoreService.isV2Bill(bill)) {
      final outstanding = bill['outstandingAmountMinor'];
      if (!BillFirestoreService.isV2InrBill(bill)) {
        return _buildV2BillUnavailableCard(bill);
      }
      if (outstanding is! int || outstanding <= 0) {
        return _buildV2NoOutstandingCard();
      }
      return StreamBuilder<Map<String, dynamic>?>(
        stream: _billService.streamLatestV2ProofForBill(billId),
        builder: (context, snapshot) {
          if (snapshot.hasError) return _buildPaymentStatusUnavailableCard();
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final proof = snapshot.data;
          final status = proof?['status']?.toString().toLowerCase();
          if (status == 'pending' && proof != null) {
            return _buildV2PendingProofCard(bill, proof);
          }
          if (status == 'failed' && proof != null) {
            return _buildPaymentRejectedCard(bill, proof);
          }
          if (status == 'completed' && proof != null) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildV2CompletedProofCard(),
                SizedBox(height: 12.h),
                _buildSubmitPaymentCard(bill),
              ],
            );
          }
          return _buildSubmitPaymentCard(bill);
        },
      );
    }

    return StreamBuilder<Map<String, dynamic>?>(
      stream: _billService.streamLatestPaymentForBill(billId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildPaymentStatusUnavailableCard();
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final payment = snapshot.data;
        final paymentStatus = payment?['status']?.toString().toLowerCase();

        if (paymentStatus == 'pending') {
          return _buildPaymentSubmittedCard(payment!);
        }

        if (paymentStatus == 'failed' && payment != null) {
          return _buildPaymentRejectedCard(bill, payment);
        }

        return _buildSubmitPaymentCard(bill);
      },
    );
  }

  Widget _buildPaymentStatusUnavailableCard() => Container(
    width: double.infinity,
    padding: EdgeInsets.all(20.w),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(kRadius),
      border: Border.all(color: kDivider),
    ),
    child: Text(
      'Unable to load payment status. Please try again.',
      style: TextStyle(fontSize: 14.sp, color: kSubtext),
    ),
  );

  Widget _buildV2NoOutstandingCard() => Container(
    width: double.infinity,
    padding: EdgeInsets.all(20.w),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(kRadius),
      border: Border.all(color: kDivider),
    ),
    child: const Text('No outstanding balance. No payment is due.'),
  );

  Widget _buildV2BillUnavailableCard(Map<String, dynamic> bill) => Container(
    key: ValueKey('v2-bill-unavailable-${bill['id']}'),
    width: double.infinity,
    padding: EdgeInsets.all(20.w),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(kRadius),
      border: Border.all(color: kDivider),
    ),
    child: const Text(
      'Billing details unavailable. Please contact your community administrator.',
    ),
  );

  Widget _buildV2PendingProofCard(
    Map<String, dynamic> bill,
    Map<String, dynamic> proof,
  ) => Container(
    width: double.infinity,
    padding: EdgeInsets.all(20.w),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(kRadius),
      border: Border.all(color: kDivider),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Payment submitted / awaiting Admin verification',
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.w600,
            color: kPrimaryBlue,
          ),
        ),
        SizedBox(height: 8.h),
        Text(
          'Your bill remains open until the payment is verified.',
          style: TextStyle(fontSize: 14.sp, color: kSubtext),
        ),
        SizedBox(height: 8.h),
        TextButton.icon(
          onPressed: () async {
            await Navigator.push<bool>(
              context,
              MaterialPageRoute(
                builder: (_) => SubmitPaymentProofScreen(
                  bill: bill,
                  existingV2Proof: proof,
                  service: _directUpiService,
                ),
              ),
            );
          },
          icon: const Icon(Icons.receipt_long_outlined),
          label: const Text('Check receipt or resume upload'),
        ),
      ],
    ),
  );

  Widget _buildV2CompletedProofCard() => Container(
    width: double.infinity,
    padding: EdgeInsets.all(20.w),
    decoration: BoxDecoration(
      color: kSuccessBg,
      borderRadius: BorderRadius.circular(kRadius),
      border: Border.all(color: kDivider),
    ),
    child: const Text('Payment verified by your community administrator.'),
  );

  @override
  Widget build(BuildContext context) {
    final languageCode = widget.languageCodeOverride;
    if (languageCode != null) return _buildForLanguage(languageCode);
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, _) {
        return _buildForLanguage(languageProvider.currentLanguageCode);
      },
    );
  }

  Widget _buildForLanguage(String languageCode) {
    return StandardScreen(
      key: ValueKey(languageCode),
      title: 'maintenance_billing'.tr(),
      showBackButton: false,
      isScrollable: true,
      padding: const EdgeInsets.all(kSpacing),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _billService.streamBills(),
        builder: (context, snapshot) {
          // Loading state
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(kPrimaryBlue),
              ),
            );
          }

          // Error state
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64.w, color: Colors.red),
                  SizedBox(height: 16.h),
                  Text(
                    'error_loading_bills'.tr(),
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    snapshot.error.toString(),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14.sp, color: Colors.grey[500]),
                  ),
                ],
              ),
            );
          }

          final bills = snapshot.data ?? [];

          // Pending and overdue bills are both unpaid current bills.
          final pendingBills = bills
              .where((bill) => _isCurrentBill(bill))
              .toList();
          final paidBills = bills.where((bill) => _isPaidBill(bill)).toList();

          // Keep the established most-recent V1 card and render every V2
          // liability so no outstanding billing period is hidden.
          var includedV1Bill = false;
          final currentBills = pendingBills.where((bill) {
            if (BillFirestoreService.isV2Bill(bill)) return true;
            if (includedV1Bill) return false;
            includedV1Bill = true;
            return true;
          }).toList();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildMonthlyStatementAction(),
              SizedBox(height: 16.h),
              // Current Bill Card
              if (currentBills.isEmpty)
                _buildNoBillCard()
              else
                ...currentBills.expand((bill) {
                  if (BillFirestoreService.isV2Bill(bill) &&
                      !BillFirestoreService.isV2InrBill(bill)) {
                    return [
                      _buildV2BillUnavailableCard(bill),
                      SizedBox(height: 24.h),
                    ];
                  }
                  return [
                    _buildCurrentBillCard(bill),
                    SizedBox(height: 20.h),
                    _buildBillBreakdownCard(bill),
                    SizedBox(height: 24.h),
                    _buildPaymentAction(bill),
                    SizedBox(height: 24.h),
                  ];
                }),

              // Payment History Section
              if (paidBills.isNotEmpty)
                _buildPaymentHistorySection(paidBills)
              else if (currentBills.isEmpty)
                _buildNoHistoryCard(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMonthlyStatementAction() => SizedBox(
    width: double.infinity,
    child: OutlinedButton.icon(
      key: const ValueKey('open-monthly-statement'),
      onPressed: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ResidentBillingStatementScreen(
              service: widget.statementService,
            ),
          ),
        );
      },
      icon: const Icon(Icons.receipt_long_outlined),
      label: const Text('Monthly Statement'),
    ),
  );

  bool _isCurrentBill(Map<String, dynamic> bill) {
    final status = bill['status'];
    if (status == 'pending' || status == 'overdue') return true;
    return BillFirestoreService.isV2Bill(bill) && status == 'partially_paid';
  }

  bool _isPaidBill(Map<String, dynamic> bill) {
    final status = bill['status'];
    if (status == 'paid') return true;
    return BillFirestoreService.isV2Bill(bill) && status == 'settled';
  }

  /// Current Bill Card with orange gradient
  Widget _buildCurrentBillCard(Map<String, dynamic> bill) {
    final isV2 = BillFirestoreService.isV2Bill(bill);
    final amount = isV2
        ? BillFirestoreService.formatV2BillMinorUnits(bill, bill['amountMinor'])
        : '₹${((bill['amount'] as num?)?.toDouble() ?? 0).toStringAsFixed(0)}';
    final dueDate = (bill['dueDate'] as Timestamp?)?.toDate();
    final status = bill['status'] as String? ?? 'pending';
    final month = isV2
        ? _displayBillingPeriod(bill['billingPeriod']?.toString())
        : bill['month'] as String? ?? 'Current';

    // Format due date
    String dueDateStr = 'Due Date: Not Set';
    if (dueDate != null) {
      final months = [
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
      dueDateStr =
          'Due Date: ${months[dueDate.month - 1]} ${dueDate.day}, ${dueDate.year}';
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24.w),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [kOrangeStart, kOrangeEnd],
        ),
        borderRadius: BorderRadius.circular(kRadius),
        boxShadow: [
          BoxShadow(
            color: kOrangeEnd.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with "Current Bill" and status badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  '$month Bill',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: kPendingBg,
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: Text(
                  status == 'pending'
                      ? 'Pending'
                      : status == 'overdue'
                      ? 'Overdue'
                      : status == 'partially_paid'
                      ? 'Partially paid'
                      : 'Paid',
                  style: TextStyle(
                    color: kPendingText,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: 16.h),

          // Amount
          Text(
            amount,
            style: TextStyle(
              color: Colors.white,
              fontSize: 48.sp,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),

          SizedBox(height: 8.h),

          // Due Date
          Text(
            dueDateStr,
            style: TextStyle(
              color: Colors.white,
              fontSize: 15.sp,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  String _displayBillingPeriod(String? value) {
    if (value == null || !RegExp(r'^\d{4}-(0[1-9]|1[0-2])$').hasMatch(value)) {
      return value ?? 'Current';
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

  /// No Bill Card
  Widget _buildNoBillCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(32.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(kRadius),
        border: Border.all(color: kDivider, width: 1),
      ),
      child: Column(
        children: [
          Icon(Icons.check_circle_outline, size: 64.w, color: Colors.grey[400]),
          SizedBox(height: 16.h),
          Text(
            'No Pending Bills',
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'You\'re all caught up!',
            style: TextStyle(fontSize: 14.sp, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  /// Bill Breakdown Card
  Widget _buildBillBreakdownCard(Map<String, dynamic> bill) {
    if (BillFirestoreService.isV2Bill(bill)) {
      return _buildV2BillBreakdownCard(bill);
    }
    final breakdown = _billService.getBillBreakdown(bill);
    final total = _billService.calculateTotal(breakdown);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(kRadius),
        border: Border.all(color: kDivider, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text(
            'Bill Breakdown',
            style: TextStyle(
              color: kDarkTitle,
              fontSize: 18.sp,
              fontWeight: FontWeight.w600,
            ),
          ),

          SizedBox(height: 20.h),

          // Breakdown items - only show non-zero values
          ...breakdown.entries.where((entry) => entry.value > 0).map((entry) {
            return Padding(
              padding: EdgeInsets.only(bottom: 16.h),
              child: _buildBreakdownItem(
                entry.key,
                '₹${entry.value.toStringAsFixed(0)}',
              ),
            );
          }),

          // Show message if no breakdown available
          if (breakdown.values.every((value) => value == 0))
            Padding(
              padding: EdgeInsets.symmetric(vertical: 16.h),
              child: Text(
                'No breakdown available',
                style: TextStyle(
                  color: kSubtext,
                  fontSize: 14.sp,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),

          // Divider
          const Divider(color: kDivider, thickness: 1),

          SizedBox(height: 16.h),

          // Total Amount
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Amount',
                style: TextStyle(
                  color: kSubtext,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '₹${total.toStringAsFixed(0)}',
                style: TextStyle(
                  color: kPrimaryBlue,
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildV2BillBreakdownCard(Map<String, dynamic> bill) {
    final lines = BillFirestoreService.getV2ChargeLines(bill);
    final rows = <({String label, Object? amount})>[
      (label: 'Total bill', amount: bill['amountMinor']),
      (label: 'Paid', amount: bill['paidAmountMinor']),
      (label: 'Credit applied', amount: bill['creditAppliedMinor']),
      (label: 'Outstanding', amount: bill['outstandingAmountMinor']),
    ];
    return Container(
      key: ValueKey('v2-bill-breakdown-${bill['id']}'),
      width: double.infinity,
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(kRadius),
        border: Border.all(color: kDivider, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bill Breakdown',
            style: TextStyle(
              color: kDarkTitle,
              fontSize: 18.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 12.h),
          ...rows.map(
            (row) => Padding(
              padding: EdgeInsets.only(bottom: 10.h),
              child: _buildBreakdownItem(
                row.label,
                BillFirestoreService.formatV2BillMinorUnits(bill, row.amount),
              ),
            ),
          ),
          const Divider(color: kDivider, thickness: 1),
          Text(
            'Charge details',
            style: TextStyle(
              color: kDarkTitle,
              fontSize: 15.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 12.h),
          if (lines.isEmpty)
            Text(
              'No charge details available',
              style: TextStyle(color: kSubtext, fontSize: 14.sp),
            )
          else
            ...lines.map(
              (line) => Padding(
                padding: EdgeInsets.only(bottom: 10.h),
                child: _buildBreakdownItem(
                  line.label,
                  BillFirestoreService.formatV2BillMinorUnits(
                    bill,
                    line.amountMinor,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Individual breakdown item
  Widget _buildBreakdownItem(String label, String amount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: kSubtext,
              fontSize: 15.sp,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
        SizedBox(width: 8.w),
        Text(
          amount,
          style: TextStyle(
            color: kBlackText,
            fontSize: 16.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  /// Payment History Section
  Widget _buildPaymentHistorySection(List<Map<String, dynamic>> paidBills) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Payment History',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: kDarkTitle,
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (context) =>
                        PaymentHistoryScreen(paidBills: paidBills),
                  ),
                );
              },
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 0),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'View All',
                style: TextStyle(
                  color: kPrimaryBlue,
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),

        SizedBox(height: 16.h),

        // Payment history items (show first 3)
        ...paidBills.take(3).map((payment) {
          return Padding(
            padding: EdgeInsets.only(bottom: 12.h),
            child: _buildPaymentHistoryItem(payment),
          );
        }),
      ],
    );
  }

  /// No History Card
  Widget _buildNoHistoryCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(32.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(kRadius),
        border: Border.all(color: kDivider, width: 1),
      ),
      child: Column(
        children: [
          Icon(Icons.history, size: 64.w, color: Colors.grey[400]),
          SizedBox(height: 16.h),
          Text(
            'No Payment History',
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'Your payment history will appear here',
            style: TextStyle(fontSize: 14.sp, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  /// Individual payment history item
  Widget _buildPaymentHistoryItem(Map<String, dynamic> payment) {
    final isV2 = BillFirestoreService.isV2Bill(payment);
    final month = isV2
        ? _displayBillingPeriod(payment['billingPeriod']?.toString())
        : payment['month'] as String? ?? 'Unknown';
    final amount = isV2
        ? BillFirestoreService.formatV2BillMinorUnits(
            payment,
            payment['amountMinor'],
          )
        : '₹${((payment['amount'] as num?)?.toDouble() ?? 0).toStringAsFixed(0)}';
    final paidAt = (payment['paidAt'] as Timestamp?)?.toDate();
    // Format paid date
    String paidDateStr = 'Paid';
    if (paidAt != null) {
      final months = [
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
      paidDateStr =
          'Paid on ${months[paidAt.month - 1]} ${paidAt.day}, ${paidAt.year}';
    }

    return Builder(
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12.r),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Success icon
              Container(
                width: 48.w,
                height: 48.h,
                decoration: BoxDecoration(
                  color: kSuccessBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check, color: kSuccessIcon, size: 28.w),
              ),

              SizedBox(width: 12.w),

              // Month and date
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      month,
                      style: TextStyle(
                        color: kDarkTitle,
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      paidDateStr,
                      style: TextStyle(
                        color: kSubtext,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      'Method: ${normalizePaymentMethod(payment['paymentMethod'])}',
                      style: TextStyle(
                        color: kSubtext,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    if ((payment['paymentReference'] as String?)
                            ?.trim()
                            .isNotEmpty ==
                        true) ...[
                      SizedBox(height: 4.h),
                      Text(
                        'Reference: ${(payment['paymentReference'] as String).trim()}',
                        style: TextStyle(
                          color: kSubtext,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Amount and receipt
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    amount,
                    style: TextStyle(
                      color: kDarkTitle,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  if (!isV2)
                    InkWell(
                      onTap: () {
                        // Navigate to Receipt Screen
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ReceiptScreen(
                              receipt: Receipt.fromBill(payment),
                            ),
                          ),
                        );
                      },
                      child: Row(
                        children: [
                          Icon(
                            Icons.download_outlined,
                            color: kPrimaryBlue,
                            size: 16.w,
                          ),
                          SizedBox(width: 4.w),
                          Text(
                            'Receipt',
                            style: TextStyle(
                              color: kPrimaryBlue,
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  /// Bottom Navigation Bar

  /// Individual bottom navigation item
  Widget _buildNavItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required bool isActive,
  }) {
    return InkWell(
      onTap: () {
        if (label == 'Home') {
          Navigator.pop(context);
        }
      },
      borderRadius: BorderRadius.circular(12.r),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isActive ? kPrimaryBlue : const Color(0xFF94A3B8),
              size: 24.w,
            ),
            SizedBox(height: 4.h),
            Text(
              label,
              style: TextStyle(
                color: isActive ? kPrimaryBlue : const Color(0xFF94A3B8),
                fontSize: 11.sp,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
