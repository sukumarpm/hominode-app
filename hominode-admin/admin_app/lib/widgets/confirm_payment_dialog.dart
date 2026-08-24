/// Confirm Payment Dialog
///
/// A confirmation dialog that appears when admin manually marks a bill as paid.
/// Used for cash/offline payments that require admin verification.
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ConfirmPaymentDialog extends StatefulWidget {
  final String residentName;
  final String flatLabel;
  final double amount;
  final VoidCallback onConfirm;

  const ConfirmPaymentDialog({
    super.key,
    required this.residentName,
    required this.flatLabel,
    required this.amount,
    required this.onConfirm,
  });

  static Future<bool?> show(
    BuildContext context, {
    required String residentName,
    required String flatLabel,
    required double amount,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ConfirmPaymentDialog(
        residentName: residentName,
        flatLabel: flatLabel,
        amount: amount,
        onConfirm: () {
          Navigator.of(context).pop(true);
        },
      ),
    );
  }

  @override
  State<ConfirmPaymentDialog> createState() => _ConfirmPaymentDialogState();
}

class _ConfirmPaymentDialogState extends State<ConfirmPaymentDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  String _selectedPaymentMethod = 'Cash';
  final List<String> _paymentMethods = [
    'Cash',
    'Bank Transfer',
    'Cheque',
    'UPI',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );

    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleConfirm() {
    widget.onConfirm();
  }

  void _handleCancel() {
    Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          contentPadding: EdgeInsets.zero,
          content: Container(
            width: MediaQuery.of(context).size.width * 0.85,
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with icon
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: const BoxDecoration(
                    color: Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
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
                        child: const Icon(
                          Icons.payment,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Confirm Payment',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF111111),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Mark this bill as paid?',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),

                // Content
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Bill details card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: Column(
                          children: [
                            _buildDetailRow(
                              'Resident',
                              widget.residentName,
                              Icons.person_outline,
                            ),
                            const SizedBox(height: 12),
                            _buildDetailRow(
                              'Flat',
                              widget.flatLabel,
                              Icons.home_outlined,
                            ),
                            const SizedBox(height: 12),
                            _buildDetailRow(
                              'Amount',
                              '₹${widget.amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}',
                              Icons.currency_rupee,
                              isAmount: true,
                            ),
                            const SizedBox(height: 12),
                            _buildDetailRow(
                              'Date',
                              DateFormat('dd MMM yyyy').format(DateTime.now()),
                              Icons.calendar_today_outlined,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Payment method selector
                      const Text(
                        'Payment Method',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF374151),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedPaymentMethod,
                            isExpanded: true,
                            icon: const Icon(
                              Icons.keyboard_arrow_down,
                              color: Color(0xFF9CA3AF),
                            ),
                            style: const TextStyle(
                              fontSize: 15,
                              color: Color(0xFF111111),
                            ),
                            items: _paymentMethods.map((method) {
                              return DropdownMenuItem(
                                value: method,
                                child: Row(
                                  children: [
                                    Icon(
                                      _getPaymentIcon(method),
                                      size: 20,
                                      color: const Color(0xFF6B7280),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(method),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  _selectedPaymentMethod = value;
                                });
                              }
                            },
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Info banner
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.info_outline,
                              color: Color(0xFFF59E0B),
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'This action will mark the bill as paid and cannot be undone.',
                                style: TextStyle(
                                  fontSize: 12,
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

                // Action buttons
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _handleCancel,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: const BorderSide(
                              color: Color(0xFFE5E7EB),
                              width: 1.5,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _handleConfirm,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            backgroundColor: const Color(0xFF10B981),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Confirm',
                            style: TextStyle(
                              fontSize: 16,
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
      ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value,
    IconData icon, {
    bool isAmount = false,
  }) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: const Color(0xFF6B7280)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: isAmount ? 18 : 15,
                  fontWeight: isAmount ? FontWeight.w700 : FontWeight.w600,
                  color: isAmount
                      ? const Color(0xFF10B981)
                      : const Color(0xFF111111),
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
}
