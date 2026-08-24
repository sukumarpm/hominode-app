
enum StaffStatus { present, absent, offDuty, onLeave, inside, outside, active }

class StaffMember {
  final String id;
  final String name;
  final String role;
  final String phone;
  final String email;
  final String shift;
  final String? checkedIn;
  final String? checkedOut;
  final String salary;
  final StaffStatus status;
  final DateTime joinDate;
  final String address;
  final String emergencyContact;
  final String emergencyContactPhone;
  final List<String> skills;
  final double rating;
  final int totalTasks;
  final int completedTasks;
  final String? profileImage;
  final String? buildingId;
  final String? gateName;
  final String? shiftTiming;
  final String? qrCodeUrl;
  final DateTime? lastCheckIn;
  final DateTime? lastCheckOut;

  const StaffMember({
    required this.id,
    required this.name,
    required this.role,
    required this.phone,
    required this.email,
    required this.shift,
    this.checkedIn,
    this.checkedOut,
    required this.salary,
    required this.status,
    required this.joinDate,
    required this.address,
    required this.emergencyContact,
    required this.emergencyContactPhone,
    required this.skills,
    required this.rating,
    required this.totalTasks,
    required this.completedTasks,
    this.profileImage,
    this.buildingId,
    this.gateName,
    this.shiftTiming,
    this.qrCodeUrl,
    this.lastCheckIn,
    this.lastCheckOut,
  });

  // Sample data for demo
  static List<StaffMember> getSampleStaff() {
    return [
      StaffMember(
        id: '1',
        name: 'Ramesh Kumar',
        role: 'Plumber',
        phone: '+91 98765 11111',
        email: 'ramesh.kumar@society.com',
        shift: 'Morning',
        checkedIn: '8:00 AM',
        checkedOut: null,
        salary: '₹18,000/month',
        status: StaffStatus.present,
        joinDate: DateTime(2023, 1, 15),
        address: '123 Worker Colony, Mumbai',
        emergencyContact: 'Sunita Kumar',
        emergencyContactPhone: '+91 98765 11112',
        skills: ['Plumbing', 'Pipe Fitting', 'Water Systems'],
        rating: 4.5,
        totalTasks: 45,
        completedTasks: 42,
      ),
      StaffMember(
        id: '2',
        name: 'Suresh Patel',
        role: 'Electrician',
        phone: '+91 98765 22222',
        email: 'suresh.patel@society.com',
        shift: 'Morning',
        checkedIn: '8:15 AM',
        checkedOut: null,
        salary: '₹20,000/month',
        status: StaffStatus.present,
        joinDate: DateTime(2022, 8, 10),
        address: '456 Staff Quarters, Mumbai',
        emergencyContact: 'Meera Patel',
        emergencyContactPhone: '+91 98765 22223',
        skills: ['Electrical Work', 'Wiring', 'Generator Maintenance'],
        rating: 4.8,
        totalTasks: 38,
        completedTasks: 36,
      ),
      StaffMember(
        id: '3',
        name: 'Rajesh Singh',
        role: 'Security Guard',
        phone: '+91 98765 33333',
        email: 'rajesh.singh@society.com',
        shift: 'Night',
        checkedIn: null,
        checkedOut: '6:00 AM',
        salary: '₹20,000/month',
        status: StaffStatus.offDuty,
        joinDate: DateTime(2023, 3, 20),
        address: '789 Security Block, Mumbai',
        emergencyContact: 'Priya Singh',
        emergencyContactPhone: '+91 98765 33334',
        skills: ['Security', 'CCTV Monitoring', 'Emergency Response'],
        rating: 4.2,
        totalTasks: 25,
        completedTasks: 24,
      ),
      StaffMember(
        id: '4',
        name: 'Kavita Sharma',
        role: 'Housekeeping',
        phone: '+91 98765 44444',
        email: 'kavita.sharma@society.com',
        shift: 'Morning',
        checkedIn: '8:15 AM',
        checkedOut: null,
        salary: '₹12,000/month',
        status: StaffStatus.absent,
        joinDate: DateTime(2023, 6, 5),
        address: '321 Cleaning Staff Area, Mumbai',
        emergencyContact: 'Ravi Sharma',
        emergencyContactPhone: '+91 98765 44445',
        skills: ['Cleaning', 'Sanitization', 'Waste Management'],
        rating: 4.0,
        totalTasks: 30,
        completedTasks: 28,
      ),
    ];
  }
}