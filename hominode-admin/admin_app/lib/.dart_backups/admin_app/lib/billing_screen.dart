/// Maintenance & Billing Screen for Admin App
///
/// Integration: Add to MaterialApp routes:
/// '/billing': (context) => const BillingScreen(),
///
/// Or use with bottom navigation as shown in the existing admin app structure.
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'widgets/standard_bottom_nav.dart';
import 'widgets/create_monthly_bill_modal.dart';
import 'widgets/standard_header.dart';
import 'services/billing_service.dart';
import 'services/admin_tenant_context.dart';
import 'services/invoice_generator_service.dart';

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

  // Get current admin ID
  String get _adminId => FirebaseAuth.instance.currentUser?.uid ?? '';

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
            const SnackBar(
              content: Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  SizedBox(width: 12),
                  Text('Generating bills...'),
                ],
              ),
              backgroundColor: Color(0xFF2563EB),
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
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Payment confirmed for ${bill.residentName}'),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
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
            borderRadius: BorderRadius.circular(20),
          ),
          contentPadding: EdgeInsets.zero,
          content: Container(
            width: MediaQuery.of(context).size.width * 0.85,
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
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
                          color: const Color(0xFF2563EB),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF2563EB).withOpacity(0.3),
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
                      // Bill details
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: Column(
                          children: [
                            _buildDialogDetailRow(
                              'Resident',
                              bill.residentName,
                              Icons.person_outline,
                            ),
                            const SizedBox(height: 12),
                            _buildDialogDetailRow(
                              'Flat',
                              bill.flatLabel,
                              Icons.home_outlined,
                            ),
                            const SizedBox(height: 12),
                            _buildDialogDetailRow(
                              'Amount',
                              '₹${bill.amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}',
                              Icons.currency_rupee,
                              isAmount: true,
                            ),
                            const SizedBox(height: 12),
                            _buildDialogDetailRow(
                              'Date',
                              DateFormat('dd MMM yyyy').format(DateTime.now()),
                              Icons.calendar_today_outlined,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Payment method
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
                            value: selectedPaymentMethod,
                            isExpanded: true,
                            icon: const Icon(
                              Icons.keyboard_arrow_down,
                              color: Color(0xFF9CA3AF),
                            ),
                            style: const TextStyle(
                              fontSize: 15,
                              color: Color(0xFF111111),
                            ),
                            items: paymentMethods.map((method) {
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
                                  selectedPaymentMethod = value;
                                });
                              }
                            },
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Warning
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

                // Buttons
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(false),
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
                          onPressed: () => Navigator.of(context).pop(true),
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
              isAmount
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.currency_rupee,
                          size: 18,
                          color: const Color(0xFF10B981),
                        ),
                        Text(
                          value.replaceFirst('₹', ''),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF10B981),
                          ),
                        ),
                      ],
                    )
                  : Text(
                      value,
                      style: const TextStyle(
                        fontSize: 15,
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
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text(
                  'Generating Invoice...',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
                const Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(child: Text('Failed to generate invoice: $e')),
              ],
            ),
            backgroundColor: const Color(0xFFEF4444),
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Success icon
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: Color(0xFF10B981),
                  size: 40,
                ),
              ),
              const SizedBox(height: 20),

              // Title
              const Text(
                'Invoice Downloaded',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111111),
                ),
              ),
              const SizedBox(height: 8),

              // Subtitle
              Text(
                'Invoice for ${bill.residentName}',
                style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                'Flat ${bill.flatLabel} • ${bill.month} ${bill.year}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF374151),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // File location info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.folder_outlined,
                      color: Color(0xFF6B7280),
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Saved to Downloads',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF374151),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            pdfFile.path.split('/').last,
                            style: const TextStyle(
                              fontSize: 11,
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
              const SizedBox(height: 24),

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
                                content: const Row(
                                  children: [
                                    Icon(
                                      Icons.share,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                    SizedBox(width: 12),
                                    Text('Invoice shared successfully'),
                                  ],
                                ),
                                backgroundColor: const Color(0xFF10B981),
                                duration: const Duration(seconds: 2),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
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
                      icon: const Icon(Icons.share_outlined, size: 20),
                      label: const Text('Share'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF2563EB),
                        side: const BorderSide(
                          color: Color(0xFF2563EB),
                          width: 1.5,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      icon: const Icon(Icons.done, size: 20),
                      label: const Text('Done'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
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
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(child: Text('Bill deleted for ${bill.residentName}')),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
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
                const Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(child: Text('Failed to delete bill: $e')),
              ],
            ),
            backgroundColor: const Color(0xFFEF4444),
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  Widget _buildDeleteConfirmationDialog(BillModel bill) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      contentPadding: EdgeInsets.zero,
      content: Container(
        width: MediaQuery.of(context).size.width * 0.85,
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Color(0xFFFEF2F2),
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
                    child: const Icon(
                      Icons.delete_outline,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Delete Bill?',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111111),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'This action cannot be undone',
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
                  // Bill details
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Column(
                      children: [
                        _buildDialogDetailRow(
                          'Resident',
                          bill.residentName,
                          Icons.person_outline,
                        ),
                        const SizedBox(height: 12),
                        _buildDialogDetailRow(
                          'Flat',
                          bill.flatLabel,
                          Icons.home_outlined,
                        ),
                        const SizedBox(height: 12),
                        _buildDialogDetailRow(
                          'Amount',
                          '₹${bill.amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}',
                          Icons.currency_rupee,
                          isAmount: true,
                        ),
                        const SizedBox(height: 12),
                        _buildDialogDetailRow(
                          'Period',
                          '${bill.month} ${bill.year}',
                          Icons.calendar_today_outlined,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Warning
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          color: Color(0xFFEF4444),
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Deleting this bill will permanently remove it from the system.',
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

            // Buttons
            Container(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(false),
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
                      onPressed: () => Navigator.of(context).pop(true),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: const Color(0xFFEF4444),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Delete',
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
    );
  }

  void _onExportPDF() async {
    await Future.delayed(const Duration(milliseconds: 500));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Exporting PDF...'),
          backgroundColor: Color(0xFF2563EB),
          duration: Duration(seconds: 2),
        ),
      );
    }

    // TODO: Generate PDF report
    // - POST /api/bills/export/pdf
  }

  void _onExportExcel() async {
    await Future.delayed(const Duration(milliseconds: 500));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Exporting Excel...'),
          backgroundColor: Color(0xFF10B981),
          duration: Duration(seconds: 2),
        ),
      );
    }

    // TODO: Generate Excel report
    // - POST /api/bills/export/excel
  }

  // ============================================================================
  // BUILD METHOD
  // ============================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: StreamBuilder<List<BillModel>>(
        stream: _billingService.getBills(
          AdminTenantContext.instance.requireCommunityId(),
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 48,
                    color: Color(0xFFEF4444),
                  ),
                  const SizedBox(height: 16),
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
                    const SizedBox(height: 12),
                    _buildKPICards(kpiData),
                    const SizedBox(height: 16),
                    _buildTabs(),
                    const SizedBox(height: 12),
                    _selectedTab == 0
                        ? _buildBillsList(bills)
                        : _buildPaymentHistory(bills),
                    const SizedBox(height: 12),
                    _buildExportSection(),
                    const SizedBox(height: 100), // Space for bottom nav
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

  // ============================================================================
  // UI COMPONENTS
  // ============================================================================

  Widget _buildSectionHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Maintenance & Billing',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111111),
            ),
          ),
          Semantics(
            label: 'Create new bill',
            button: true,
            child: InkWell(
              onTap: _onAddBill,
              borderRadius: BorderRadius.circular(18),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add, color: Colors.white, size: 16),
                    SizedBox(width: 4),
                    Text(
                      'Create Bill',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
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
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildKPICard(
                  label: 'Total Revenue',
                  value:
                      '₹${(kpiData['totalRevenue'] / 100000).toStringAsFixed(1)}L',
                  valueColor: const Color(0xFF2563EB),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildKPICard(
                  label: 'Collected',
                  value: '${kpiData['collected']}%',
                  valueColor: const Color(0xFF10B981),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildKPICard(
                  label: 'Pending',
                  value: '₹${(kpiData['pending'] / 1000).toStringAsFixed(0)}K',
                  valueColor: const Color(0xFFF59E0B),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildKPICard(
                  label: 'Overdue',
                  value: '₹${(kpiData['overdue'] / 1000).toStringAsFixed(0)}K',
                  valueColor: const Color(0xFF2563EB),
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
      height: 85,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
            style: const TextStyle(
              fontSize: 11,
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
              Icon(Icons.currency_rupee, size: 20, color: valueColor),
              Text(
                value.replaceFirst('₹', ''),
                style: TextStyle(
                  fontSize: 24,
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
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(22),
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
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(19),
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
            fontSize: 14,
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
    // Filter based on selected tab - show pending and overdue
    final bills = allBills.where((bill) {
      return bill.status == 'pending' || bill.status == 'overdue';
    }).toList();

    if (bills.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.receipt_long, size: 56, color: Colors.grey[400]),
              const SizedBox(height: 12),
              Text(
                'No bills yet',
                style: TextStyle(fontSize: 15, color: Colors.grey[600]),
              ),
              const SizedBox(height: 8),
              Text(
                'Click "Create Bill" to generate bills',
                style: TextStyle(fontSize: 13, color: Colors.grey[500]),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: bills.map((bill) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
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
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
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
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF111111),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          bill.flatLabel,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF9CA3AF),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Amount & Due Date
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Amount',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF9CA3AF),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.currency_rupee,
                                size: 16,
                                color: Color(0xFF111111),
                              ),
                              Text(
                                bill.amount
                                    .toStringAsFixed(0)
                                    .replaceAllMapped(
                                      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                                      (Match m) => '${m[1]},',
                                    ),
                                style: const TextStyle(
                                  fontSize: 16,
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
                          const Text(
                            'Due Date',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF9CA3AF),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            bill.dueDate != null
                                ? DateFormat('yyyy-MM-dd').format(bill.dueDate!)
                                : 'N/A',
                            style: const TextStyle(
                              fontSize: 16,
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
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(
                      Icons.check_circle,
                      size: 16,
                      color: Color(0xFF16A34A),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Paid on ${DateFormat('yyyy-MM-dd').format(bill.paidAt!)}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF16A34A),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              // Action buttons
              _buildActionButtons(bill),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons(BillModel bill) {
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
                icon: const Icon(Icons.download_outlined, size: 18),
                label: const Text('Download'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF374151),
                  side: const BorderSide(color: Color(0xFFD1D5DB), width: 1),
                  backgroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Semantics(
            label: 'Delete bill button',
            button: true,
            child: OutlinedButton(
              onPressed: () => _onDeleteBill(bill),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFEF4444),
                side: const BorderSide(color: Color(0xFFEF4444), width: 1),
                backgroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Icon(Icons.delete_outline, size: 18),
            ),
          ),
        ],
      );
    } else {
      // Send Reminder + Mark Paid + Delete for pending/overdue
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
                    icon: const Icon(Icons.send_outlined, size: 16),
                    label: const Text('Remind'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF374151),
                      side: const BorderSide(
                        color: Color(0xFFD1D5DB),
                        width: 1,
                      ),
                      backgroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Semantics(
                  label: 'Mark as paid button',
                  button: true,
                  child: ElevatedButton.icon(
                    onPressed: () => _onMarkAsPaid(bill),
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Mark Paid'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Semantics(
            label: 'Delete bill button',
            button: true,
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _onDeleteBill(bill),
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Delete Bill'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFEF4444),
                  side: const BorderSide(color: Color(0xFFEF4444), width: 1),
                  backgroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }
  }

  Widget _buildPaymentHistory(List<BillModel> allBills) {
    final paidBills = allBills.where((bill) => bill.status == 'paid').toList();

    if (paidBills.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.history, size: 56, color: Colors.grey[400]),
              const SizedBox(height: 12),
              Text(
                'No payment history',
                style: TextStyle(fontSize: 15, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: paidBills.map((bill) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildBillCard(bill),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildExportSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
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
            const Text(
              'Export Reports',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Color(0xFF111111),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    label: 'Export PDF',
                    button: true,
                    child: OutlinedButton.icon(
                      onPressed: _onExportPDF,
                      icon: const Icon(Icons.download_outlined, size: 18),
                      label: const Text('Export PDF'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF374151),
                        side: const BorderSide(
                          color: Color(0xFFD1D5DB),
                          width: 1,
                        ),
                        backgroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Semantics(
                    label: 'Export Excel',
                    button: true,
                    child: OutlinedButton.icon(
                      onPressed: _onExportExcel,
                      icon: const Icon(Icons.download_outlined, size: 18),
                      label: const Text('Export Excel'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF374151),
                        side: const BorderSide(
                          color: Color(0xFFD1D5DB),
                          width: 1,
                        ),
                        backgroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
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
