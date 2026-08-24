/// Maintenance Bill Model
/// 
/// Represents a maintenance bill for a resident in the society.
library;

enum BillStatus {
  paid,
  pending,
  overdue,
}

extension BillStatusExtension on BillStatus {
  String get label {
    switch (this) {
      case BillStatus.paid:
        return 'Paid';
      case BillStatus.pending:
        return 'Pending';
      case BillStatus.overdue:
        return 'Overdue';
    }
  }
}

class MaintenanceBill {
  final String id;
  final String residentName;
  final String unit;
  final double amount;
  final DateTime dueDate;
  final DateTime? paidOn;
  final BillStatus status;

  MaintenanceBill({
    required this.id,
    required this.residentName,
    required this.unit,
    required this.amount,
    required this.dueDate,
    this.paidOn,
    required this.status,
  });

  // TODO: Connect to backend API
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'residentName': residentName,
      'unit': unit,
      'amount': amount,
      'dueDate': dueDate.toIso8601String(),
      'paidOn': paidOn?.toIso8601String(),
      'status': status.name,
    };
  }

  factory MaintenanceBill.fromJson(Map<String, dynamic> json) {
    return MaintenanceBill(
      id: json['id'] as String,
      residentName: json['residentName'] as String,
      unit: json['unit'] as String,
      amount: (json['amount'] as num).toDouble(),
      dueDate: DateTime.parse(json['dueDate'] as String),
      paidOn: json['paidOn'] != null 
          ? DateTime.parse(json['paidOn'] as String) 
          : null,
      status: BillStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => BillStatus.pending,
      ),
    );
  }
}
