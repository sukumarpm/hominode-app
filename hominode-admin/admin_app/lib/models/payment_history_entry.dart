/// Payment History Entry Model
/// 
/// Represents a single payment record for a resident.
/// Used in the Payment History dialog to display payment details.
library;

// ============================================================================
// PAYMENT STATUS ENUM
// ============================================================================

enum PaymentStatus {
  paid,
  pending,
  overdue,
}

// ============================================================================
// PAYMENT HISTORY ENTRY MODEL
// ============================================================================

class PaymentHistoryEntry {
  final String monthLabel; // e.g., "November 2025"
  final String periodLabel; // e.g., "November 2025"
  final double amount; // e.g., 5500
  final DateTime paidDate; // Date when payment was made
  final String method; // e.g., "UPI", "Cash", "Bank Transfer"
  final String transactionId; // e.g., "TXN1234567890"
  final PaymentStatus status; // paid, pending, overdue

  PaymentHistoryEntry({
    required this.monthLabel,
    required this.periodLabel,
    required this.amount,
    required this.paidDate,
    required this.method,
    required this.transactionId,
    required this.status,
  });

  // TODO: Connect to backend API
  Map<String, dynamic> toJson() {
    return {
      'monthLabel': monthLabel,
      'periodLabel': periodLabel,
      'amount': amount,
      'paidDate': paidDate.toIso8601String(),
      'method': method,
      'transactionId': transactionId,
      'status': status.name,
    };
  }

  factory PaymentHistoryEntry.fromJson(Map<String, dynamic> json) {
    return PaymentHistoryEntry(
      monthLabel: json['monthLabel'] as String,
      periodLabel: json['periodLabel'] as String,
      amount: (json['amount'] as num).toDouble(),
      paidDate: DateTime.parse(json['paidDate'] as String),
      method: json['method'] as String,
      transactionId: json['transactionId'] as String,
      status: PaymentStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => PaymentStatus.pending,
      ),
    );
  }

  @override
  String toString() {
    return 'PaymentHistoryEntry(monthLabel: $monthLabel, amount: $amount, status: $status)';
  }
}

// ============================================================================
// MOCK DATA FOR TESTING
// ============================================================================

/// Sample payment history data for testing
/// TODO: Replace with actual API data
List<PaymentHistoryEntry> getMockPaymentHistory() {
  return [
    PaymentHistoryEntry(
      monthLabel: 'November 2025',
      periodLabel: 'November 2025',
      amount: 5500,
      paidDate: DateTime(2025, 11, 2),
      method: 'UPI',
      transactionId: 'TXN1234567890',
      status: PaymentStatus.paid,
    ),
    PaymentHistoryEntry(
      monthLabel: 'October 2025',
      periodLabel: 'October 2025',
      amount: 5500,
      paidDate: DateTime(2025, 10, 5),
      method: 'UPI',
      transactionId: 'TXN0987654321',
      status: PaymentStatus.paid,
    ),
    PaymentHistoryEntry(
      monthLabel: 'September 2025',
      periodLabel: 'September 2025',
      amount: 5500,
      paidDate: DateTime(2025, 9, 3),
      method: 'Bank Transfer',
      transactionId: 'TXN1122334455',
      status: PaymentStatus.paid,
    ),
    PaymentHistoryEntry(
      monthLabel: 'August 2025',
      periodLabel: 'August 2025',
      amount: 5500,
      paidDate: DateTime(2025, 8, 1),
      method: 'Cash',
      transactionId: 'TXN5544332211',
      status: PaymentStatus.paid,
    ),
    PaymentHistoryEntry(
      monthLabel: 'July 2025',
      periodLabel: 'July 2025',
      amount: 5500,
      paidDate: DateTime(2025, 7, 4),
      method: 'UPI',
      transactionId: 'TXN6677889900',
      status: PaymentStatus.paid,
    ),
  ];
}
