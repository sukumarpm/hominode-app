class Amenity {
  final String id;
  final String name;
  final String price;
  final bool isAvailable;
  final String iconName;
  final String backgroundColor;
  final String iconColor;
  final String openTime;
  final String closeTime;

  Amenity({
    required this.id,
    required this.name,
    required this.price,
    required this.isAvailable,
    required this.iconName,
    required this.backgroundColor,
    required this.iconColor,
    this.openTime = '6:00 AM',
    this.closeTime = '8:00 PM',
  });

  factory Amenity.fromJson(Map<String, dynamic> json) {
    return Amenity(
      id: json['id'],
      name: json['name'],
      price: json['price'],
      isAvailable: json['isAvailable'],
      iconName: json['iconName'],
      backgroundColor: json['backgroundColor'],
      iconColor: json['iconColor'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'isAvailable': isAvailable,
      'iconName': iconName,
      'backgroundColor': backgroundColor,
      'iconColor': iconColor,
    };
  }
}

class AmenityBooking {
  final String id;
  final String amenityName;
  final DateTime bookingDate;
  final String startTime;
  final String endTime;
  final String status;
  final String userId;

  AmenityBooking({
    required this.id,
    required this.amenityName,
    required this.bookingDate,
    required this.startTime,
    required this.endTime,
    required this.status,
    required this.userId,
  });

  factory AmenityBooking.fromJson(Map<String, dynamic> json) {
    return AmenityBooking(
      id: json['id'],
      amenityName: json['amenityName'],
      bookingDate: DateTime.parse(json['bookingDate']),
      startTime: json['startTime'],
      endTime: json['endTime'],
      status: json['status'],
      userId: json['userId'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'amenityName': amenityName,
      'bookingDate': bookingDate.toIso8601String(),
      'startTime': startTime,
      'endTime': endTime,
      'status': status,
      'userId': userId,
    };
  }

  String get formattedDate {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[bookingDate.month - 1]} ${bookingDate.day}, ${bookingDate.year}';
  }

  String get formattedTimeRange {
    return '$startTime - $endTime';
  }
}
