import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'receipt_screen.dart';
import 'payment_method_modal.dart';
import 'src/components/standard_screen.dart';
import 'src/services/bill_firestore_service.dart';
import 'src/providers/language_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Design Constants
const kPrimaryBlue = Color(0xFF2563EB);
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
  const MaintenanceBillingScreen({Key? key}) : super(key: key);

  @override
  State<MaintenanceBillingScreen> createState() => _MaintenanceBillingScreenState();
}

class _MaintenanceBillingScreenState extends State<MaintenanceBillingScreen> {
  final _billService = BillFirestoreService();

  Future<void> _handlePayment(PaymentMethod paymentMethod, String billId, LanguageProvider languageProvider) async {
    // Convert PaymentMethod enum to string
    String methodStr = '';
    switch (paymentMethod) {
      case PaymentMethod.upi:
        methodStr = 'UPI';
        break;
      case PaymentMethod.card:
        methodStr = 'card'.tr();
        break;
      case PaymentMethod.netBanking:
        methodStr = 'net_banking'.tr();
        break;
    }

    // Generate transaction ID (in real app, this would come from payment gateway)
    final transactionId = 'TXN${DateTime.now().millisecondsSinceEpoch}';

    final success = await _billService.payBill(
      billId: billId,
      paymentMethod: methodStr,
      transactionId: transactionId,
    );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('payment_successful'.tr()),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('payment_failed'.tr()),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, _) {
        return StandardScreen(
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
                      const Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'error_loading_bills'.tr(),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        snapshot.error.toString(),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                );
              }

              final bills = snapshot.data ?? [];
              
              // Separate pending and paid bills
              final pendingBills = bills.where((bill) => bill['status'] == 'pending').toList();
              final paidBills = bills.where((bill) => bill['status'] == 'paid').toList();
              
              // Get current pending bill (most recent)
              final currentBill = pendingBills.isNotEmpty ? pendingBills.first : null;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Current Bill Card
                  if (currentBill != null)
                    _buildCurrentBillCard(currentBill, languageProvider)
                  else
                    _buildNoBillCard(),
                  
                  const SizedBox(height: 20),
                  
                  // Bill Breakdown Card
                  if (currentBill != null)
                    _buildBillBreakdownCard(currentBill),
                  
                  if (currentBill != null)
                    const SizedBox(height: 24),
                  
                  // Payment History Section
                  if (paidBills.isNotEmpty)
                    _buildPaymentHistorySection(paidBills)
                  else if (currentBill == null)
                    _buildNoHistoryCard(),
                ],
              );
            },
          ),
        );
      },
    );
  }

  /// Current Bill Card with orange gradient
  Widget _buildCurrentBillCard(Map<String, dynamic> bill, LanguageProvider languageProvider) {
    final amount = (bill['amount'] as num?)?.toDouble() ?? 0;
    final dueDate = (bill['dueDate'] as Timestamp?)?.toDate();
    final status = bill['status'] as String? ?? 'pending';
    final month = bill['month'] as String? ?? 'Current';
    final billId = bill['id'] as String;

    // Format due date
    String dueDateStr = 'Due Date: Not Set';
    if (dueDate != null) {
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      dueDateStr = 'Due Date: ${months[dueDate.month - 1]} ${dueDate.day}, ${dueDate.year}';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
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
              Text(
                '$month Bill',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: kPendingBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status == 'pending' ? 'Pending' : status == 'overdue' ? 'Overdue' : 'Paid',
                  style: const TextStyle(
                    color: kPendingText,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Amount
          Text(
            '₹${amount.toStringAsFixed(0)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 48,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Due Date
          Text(
            dueDateStr,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w400,
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Pay Now Button
          if (status == 'pending' || status == 'overdue')
            Builder(
              builder: (context) {
                return Container(
                  width: double.infinity,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        // Show payment method modal
                        showPaymentMethodModal(context, (method) {
                          _handlePayment(method, billId, languageProvider);
                        });
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: const Center(
                        child: Text(
                          'Pay Now',
                          style: TextStyle(
                            color: kOrangeEnd,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }
            ),
        ],
      ),
    );
  }

  /// No Bill Card
  Widget _buildNoBillCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(kRadius),
        border: Border.all(color: kDivider, width: 1),
      ),
      child: Column(
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No Pending Bills',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You\'re all caught up!',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  /// Bill Breakdown Card
  Widget _buildBillBreakdownCard(Map<String, dynamic> bill) {
    final breakdown = _billService.getBillBreakdown(bill);
    final total = _billService.calculateTotal(breakdown);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(kRadius),
        border: Border.all(
          color: kDivider,
          width: 1,
        ),
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
          const Text(
            'Bill Breakdown',
            style: TextStyle(
              color: kDarkTitle,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Breakdown items - only show non-zero values
          ...breakdown.entries.where((entry) => entry.value > 0).map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _buildBreakdownItem(entry.key, '₹${entry.value.toStringAsFixed(0)}'),
            );
          }).toList(),
          
          // Show message if no breakdown available
          if (breakdown.values.every((value) => value == 0))
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'No breakdown available',
                style: TextStyle(
                  color: kSubtext,
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          
          // Divider
          const Divider(color: kDivider, thickness: 1),
          
          const SizedBox(height: 16),
          
          // Total Amount
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total Amount',
                style: TextStyle(
                  color: kSubtext,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '₹${total.toStringAsFixed(0)}',
                style: const TextStyle(
                  color: kPrimaryBlue,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
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
        Text(
          label,
          style: const TextStyle(
            color: kSubtext,
            fontSize: 15,
            fontWeight: FontWeight.w400,
          ),
        ),
        Text(
          amount,
          style: const TextStyle(
            color: kBlackText,
            fontSize: 16,
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
            const Text(
              'Payment History',
              style: TextStyle(
                color: kDarkTitle,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            TextButton(
              onPressed: () {},
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 0),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'View All',
                style: TextStyle(
                  color: kPrimaryBlue,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 16),
        
        // Payment history items (show first 3)
        ...paidBills.take(3).map((payment) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildPaymentHistoryItem(payment),
          );
        }).toList(),
      ],
    );
  }

  /// No History Card
  Widget _buildNoHistoryCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(kRadius),
        border: Border.all(color: kDivider, width: 1),
      ),
      child: Column(
        children: [
          Icon(
            Icons.history,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No Payment History',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your payment history will appear here',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  /// Individual payment history item
  Widget _buildPaymentHistoryItem(Map<String, dynamic> payment) {
    final month = payment['month'] as String? ?? 'Unknown';
    final amount = (payment['amount'] as num?)?.toDouble() ?? 0;
    final paidAt = (payment['paidAt'] as Timestamp?)?.toDate();
    final billId = payment['id'] as String? ?? '';

    // Format paid date
    String paidDateStr = 'Paid';
    if (paidAt != null) {
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      paidDateStr = 'Paid on ${months[paidAt.month - 1]} ${paidAt.day}, ${paidAt.year}';
    }

    return Builder(
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
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
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: kSuccessBg,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check,
                  color: kSuccessIcon,
                  size: 28,
                ),
              ),
              
              const SizedBox(width: 12),
              
              // Month and date
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      month,
                      style: const TextStyle(
                        color: kDarkTitle,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      paidDateStr,
                      style: const TextStyle(
                        color: kSubtext,
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Amount and receipt
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₹${amount.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: kDarkTitle,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
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
                      children: const [
                        Icon(
                          Icons.download_outlined,
                          color: kPrimaryBlue,
                          size: 16,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Receipt',
                          style: TextStyle(
                            color: kPrimaryBlue,
                            fontSize: 14,
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
      }
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
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isActive ? kPrimaryBlue : const Color(0xFF94A3B8),
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isActive ? kPrimaryBlue : const Color(0xFF94A3B8),
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
