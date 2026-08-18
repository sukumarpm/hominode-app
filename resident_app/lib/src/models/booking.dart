class BookingModel {
  final String? id;
  final String communityId;
  final String amenityId;
  final String amenityName;
  final DateTime date;
  final String timeSlot;
  final String status;
  final DateTime createdAt;
  final String userId;

  // NEW: Booking type and package fields
  final String bookingType; // 'daily', 'weekly', 'monthly', 'yearly'
  final String?
  packageType; // null for daily, 'Weekly', 'Monthly', 'Yearly' for packages
  final int numberOfPeople; // Number of people in this booking
  final DateTime? subscriptionStartDate;
  final DateTime? subscriptionEndDate;
  final int
  validityDays; // 1 for daily, 7 for weekly, 30 for monthly, 365 for yearly
  final double price; // Amount paid

  BookingModel({
    this.id,
    this.communityId = '',
    required this.amenityId,
    required this.amenityName,
    required this.date,
    required this.timeSlot,
    required this.status,
    DateTime? createdAt,
    required this.userId,
    this.bookingType = 'daily',
    this.packageType,
    this.numberOfPeople = 1,
    this.subscriptionStartDate,
    this.subscriptionEndDate,
    this.validityDays = 1,
    this.price = 0,
  }) : createdAt = createdAt ?? DateTime.now();

  factory BookingModel.fromJson(Map<String, dynamic> json) {
    return BookingModel(
      id: json['id'],
      communityId: json['communityId'] as String? ?? '',
      amenityId: json['amenityId'],
      amenityName: json['amenityName'],
      date: DateTime.parse(json['date']),
      timeSlot: json['timeSlot'],
      status: json['status'],
      createdAt: DateTime.parse(json['createdAt']),
      userId: json['userId'],
      bookingType: json['bookingType'] ?? 'daily',
      packageType: json['packageType'],
      numberOfPeople: json['numberOfPeople'] ?? 1,
      subscriptionStartDate: json['subscriptionStartDate'] != null
          ? DateTime.parse(json['subscriptionStartDate'])
          : null,
      subscriptionEndDate: json['subscriptionEndDate'] != null
          ? DateTime.parse(json['subscriptionEndDate'])
          : null,
      validityDays: json['validityDays'] ?? 1,
      price: (json['price'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'communityId': communityId,
      'amenityId': amenityId,
      'amenityName': amenityName,
      'date': date.toIso8601String(),
      'timeSlot': timeSlot,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'userId': userId,
      'bookingType': bookingType,
      'packageType': packageType,
      'numberOfPeople': numberOfPeople,
      'subscriptionStartDate': subscriptionStartDate?.toIso8601String(),
      'subscriptionEndDate': subscriptionEndDate?.toIso8601String(),
      'validityDays': validityDays,
      'price': price,
    };
  }

  String get formattedDate {
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
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  // NEW: Check if this is a package booking
  bool get isPackage => bookingType != 'daily';

  // NEW: Get formatted package duration
  String get packageDuration {
    if (!isPackage ||
        subscriptionStartDate == null ||
        subscriptionEndDate == null) {
      return '';
    }
    return '${_formatDate(subscriptionStartDate!)} - ${_formatDate(subscriptionEndDate!)}';
  }

  String _formatDate(DateTime date) {
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
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}
