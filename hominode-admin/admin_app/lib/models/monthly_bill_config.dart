/// Monthly Bill Configuration Model
/// 
/// Represents the configuration for generating monthly bills with multiple charge types.
library;

class MonthlyBillConfig {
  final int year;
  final int month;
  final DateTime dueDate;
  final String billingScope; // 'all' or 'specific_units'
  final String? building;
  final List<String>? selectedUnits;
  
  // Individual charge amounts (all optional)
  final double maintenanceAmount;
  final double waterAmount;
  final double parkingAmount;
  final double serviceAmount;
  final double electricityAmount;
  final double securityAmount;
  final double otherAmount;

  MonthlyBillConfig({
    required this.year,
    required this.month,
    required this.dueDate,
    required this.billingScope,
    this.building,
    this.selectedUnits,
    this.maintenanceAmount = 0,
    this.waterAmount = 0,
    this.parkingAmount = 0,
    this.serviceAmount = 0,
    this.electricityAmount = 0,
    this.securityAmount = 0,
    this.otherAmount = 0,
  });

  String get monthName {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month - 1];
  }

  // Calculate total amount from all charge types
  double get totalAmount {
    return maintenanceAmount +
        waterAmount +
        parkingAmount +
        serviceAmount +
        electricityAmount +
        securityAmount +
        otherAmount;
  }

  // Get breakdown of charges (only non-zero amounts)
  Map<String, double> get chargeBreakdown {
    final breakdown = <String, double>{};
    if (maintenanceAmount > 0) breakdown['Maintenance'] = maintenanceAmount;
    if (waterAmount > 0) breakdown['Water'] = waterAmount;
    if (parkingAmount > 0) breakdown['Parking'] = parkingAmount;
    if (serviceAmount > 0) breakdown['Service'] = serviceAmount;
    if (electricityAmount > 0) breakdown['Electricity'] = electricityAmount;
    if (securityAmount > 0) breakdown['Security'] = securityAmount;
    if (otherAmount > 0) breakdown['Other'] = otherAmount;
    return breakdown;
  }

  Map<String, dynamic> toJson() {
    return {
      'year': year,
      'month': month,
      'dueDate': dueDate.toIso8601String(),
      'billingScope': billingScope,
      'building': building,
      'selectedUnits': selectedUnits,
      'maintenanceAmount': maintenanceAmount,
      'waterAmount': waterAmount,
      'parkingAmount': parkingAmount,
      'serviceAmount': serviceAmount,
      'electricityAmount': electricityAmount,
      'securityAmount': securityAmount,
      'otherAmount': otherAmount,
      'totalAmount': totalAmount,
    };
  }

  factory MonthlyBillConfig.fromJson(Map<String, dynamic> json) {
    return MonthlyBillConfig(
      year: json['year'] as int,
      month: json['month'] as int,
      dueDate: DateTime.parse(json['dueDate'] as String),
      billingScope: json['billingScope'] as String,
      building: json['building'] as String?,
      selectedUnits: json['selectedUnits'] != null
          ? List<String>.from(json['selectedUnits'] as List)
          : null,
      maintenanceAmount: (json['maintenanceAmount'] as num?)?.toDouble() ?? 0,
      waterAmount: (json['waterAmount'] as num?)?.toDouble() ?? 0,
      parkingAmount: (json['parkingAmount'] as num?)?.toDouble() ?? 0,
      serviceAmount: (json['serviceAmount'] as num?)?.toDouble() ?? 0,
      electricityAmount: (json['electricityAmount'] as num?)?.toDouble() ?? 0,
      securityAmount: (json['securityAmount'] as num?)?.toDouble() ?? 0,
      otherAmount: (json['otherAmount'] as num?)?.toDouble() ?? 0,
    );
  }
}
