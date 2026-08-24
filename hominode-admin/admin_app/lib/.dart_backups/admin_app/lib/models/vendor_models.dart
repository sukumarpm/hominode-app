
class Vendor {
  final String id;
  final String businessName;
  final String category;
  final String contactPerson;
  final String phone;
  final double rating;
  final String? email;
  final String? profileImage;
  final String? address;
  final DateTime? contractStartDate;
  final DateTime? contractEndDate;
  final int totalServices;
  final List<String> services;

  const Vendor({
    required this.id,
    required this.businessName,
    required this.category,
    required this.contactPerson,
    required this.phone,
    required this.rating,
    this.email,
    this.profileImage,
    this.address,
    this.contractStartDate,
    this.contractEndDate,
    this.totalServices = 0,
    this.services = const [],
  });

  // Backward compatibility
  String get name => businessName;

  // Sample data for demo
  static List<Vendor> getSampleVendors() {
    return [
      Vendor(
        id: '1',
        businessName: 'Quick Fix Plumbing',
        category: 'Plumber',
        contactPerson: 'Mohit Kumar',
        phone: '+91 98765 66666',
        email: 'quickfix@example.com',
        rating: 4.5,
        address: 'Shop 12, Market Complex',
        contractStartDate: DateTime(2024, 1, 1),
        contractEndDate: DateTime(2024, 12, 31),
        totalServices: 24,
        services: ['Pipe Repair', 'Leak Fixing', 'Installation'],
      ),
      Vendor(
        id: '2',
        businessName: 'Clean & Shine',
        category: 'Cleaning',
        contactPerson: 'Priya Devi',
        phone: '+91 98765 88888',
        email: 'cleanshine@example.com',
        rating: 4.5,
        address: 'Building A, Sector 5',
        contractStartDate: DateTime(2024, 3, 1),
        contractEndDate: DateTime(2025, 2, 28),
        totalServices: 18,
        services: ['Deep Cleaning', 'Regular Maintenance'],
      ),
      Vendor(
        id: '3',
        businessName: 'Bright Electricals',
        category: 'Electrician',
        contactPerson: 'Anil Sharma',
        phone: '+91 98765 66666',
        email: 'bright@example.com',
        rating: 4.5,
        address: 'Shop 5, Main Road',
        contractStartDate: DateTime(2024, 2, 1),
        contractEndDate: DateTime(2024, 12, 31),
        totalServices: 32,
        services: ['Wiring', 'Repairs', 'Installation'],
      ),
    ];
  }
}