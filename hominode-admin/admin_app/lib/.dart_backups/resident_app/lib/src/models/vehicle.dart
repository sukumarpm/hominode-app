class Vehicle {
  final String id;
  final String name;
  final String type;
  final String plateNumber;
  final String color;
  final String? photoUrl;

  Vehicle({
    required this.id,
    required this.name,
    required this.type,
    required this.plateNumber,
    required this.color,
    this.photoUrl,
  });

  Vehicle copyWith({
    String? id,
    String? name,
    String? type,
    String? plateNumber,
    String? color,
    String? photoUrl,
  }) {
    return Vehicle(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      plateNumber: plateNumber ?? this.plateNumber,
      color: color ?? this.color,
      photoUrl: photoUrl ?? this.photoUrl,
    );
  }

  static List<Vehicle> mockList() {
    return [
      Vehicle(
        id: '1',
        name: 'Honda City',
        type: 'Sedan',
        plateNumber: 'DL 01 AB 1234',
        color: 'Silver',
      ),
      Vehicle(
        id: '2',
        name: 'Royal Enfield',
        type: 'Motorcycle',
        plateNumber: 'DL 02 CD 5678',
        color: 'Black',
      ),
    ];
  }
}
