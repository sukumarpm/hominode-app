/// Payment History Dialog
/// 
/// A centered overlay modal for displaying a resident's payment history.
/// Matches the admin app visual system with blue theme and rounded cards.
/// 
/// Usage:
/// ```dart
/// PaymentHistoryDialog.show(
///   context,
///   residentName: 'Rajesh Kumar',
///   unitNumber: 'A-204',
///   history: mockPaymentHistoryList,
/// );
/// ```
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/payment_history_entry.dart';

// ============================================================================
// PAYMENT HISTORY DIALOG
// ============================================================================

class PaymentHistoryDialog extends StatelessWidget {
  final String residentName;
  final String unitNumber;
  final List<PaymentHistoryEntry> history;

  const PaymentHistoryDialog({
    super.key,
    required this.residentName,
    required this.unitNumber,
    required this.history,
  });

  /// Show the dialog with fade and scale animation
  static Future<void> show(
    BuildContext context, {
    required String residentName,
    required String unitNumber,
    required List<PaymentHistoryEntry> history,
  }) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close',
      barrierColor: const Color(0x59000000), // rgba(0, 0, 0, 0.35)
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, animation, secondaryAnimation) {
        return PaymentHistoryDialog(
          residentName: residentName,
          unitNumber: unitNumber,
          history: history,
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1.0).animate(
              CurvedAnimation(
                parent: animation,
                curve: Curves.easeOut,
              ),
            ),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Center(
      child: Container(
        constraints: BoxConstraints(
          maxWidth: screenWidth > 720 ? 720 : screenWidth * 0.92,
          maxHeight: screenHeight * 0.80,
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          elevation: 8,
          shadowColor: Colors.black.withOpacity(0.15),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(context),
              Flexible(
                child: history.isEmpty
                    ? _buildEmptyState()
                    : _buildPaymentList(),
              ),
              _buildFooter(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 40),
            child: Column(
              children: [
                const Text(
                  'Payment History',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111111),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$residentName – $unitNumber',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: -6,
            right: -6,
            child: Semantics(
              label: 'Close payment history',
              button: true,
              child: InkWell(
                onTap: () => Navigator.of(context).pop(),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.close,
                    color: Color(0xFF9CA3AF),
                    size: 22,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: history.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildPaymentCard(history[index]),
        );
      },
    );
  }

  Widget _buildPaymentCard(PaymentHistoryEntry entry) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Month + Status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.monthLabel,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF111111),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        entry.periodLabel,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: Color(0xFF9CA3AF),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _buildStatusPill(entry.status),
              ],
            ),
            const SizedBox(height: 16),
            // Divider
            Container(
              height: 1,
              color: const Color(0xFFE5E7EB),
            ),
            const SizedBox(height: 16),
            // Payment details
            _buildDetailRow(
              'Amount :',
              '₹${entry.amount.toStringAsFixed(0)}',
              valueColor: const Color(0xFF111111),
              valueBold: true,
            ),
            const SizedBox(height: 12),
            _buildDetailRow(
              'Paid Date :',
              DateFormat('yyyy-MM-d').format(entry.paidDate),
              valueColor: const Color(0xFF16A34A),
            ),
            const SizedBox(height: 12),
            _buildDetailRow(
              'Method :',
              entry.method,
              valueColor: const Color(0xFF111111),
            ),
            const SizedBox(height: 12),
            _buildDetailRow(
              'Transaction ID :',
              entry.transactionId,
              valueColor: const Color(0xFF111111),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusPill(PaymentStatus status) {
    Color backgroundColor;
    Color textColor;
    String label;

    switch (status) {
      case PaymentStatus.paid:
        backgroundColor = const Color(0xFF16A34A);
        textColor = Colors.white;
        label = 'Paid';
        break;
      case PaymentStatus.pending:
        // TODO: Implement pending UI
        backgroundColor = const Color(0xFFF59E0B);
        textColor = Colors.white;
        label = 'Pending';
        break;
      case PaymentStatus.overdue:
        // TODO: Implement overdue UI
        backgroundColor = const Color(0xFFDC2626);
        textColor = Colors.white;
        label = 'Overdue';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value, {
    Color? valueColor,
    bool valueBold = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w400,
            color: Color(0xFF6B7280),
          ),
        ),
        const SizedBox(width: 16),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 15,
              fontWeight: valueBold ? FontWeight.w600 : FontWeight.w400,
              color: valueColor ?? const Color(0xFF111111),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No payment history available yet',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Semantics(
        label: 'Close payment history',
        button: true,
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF111111),
              side: const BorderSide(color: Color(0xFFE5E7EB), width: 1),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              'Close',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
