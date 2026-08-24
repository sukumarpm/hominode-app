// lib/src/services/domestic_staff_service.dart
import '../models/domestic_staff.dart';

class DomesticStaffService {
  static final DomesticStaffService instance = DomesticStaffService._internal();
  factory DomesticStaffService() => instance;
  DomesticStaffService._internal();

  /// Get all domestic staff
  /// TODO: Replace with actual API call
  Future<List<DomesticStaff>> getStaffList() async {
    await Future.delayed(const Duration(milliseconds: 500));
    
    // Mock data
    return [
      DomesticStaff(
        id: '1',
        name: 'Laxmi Devi',
        role: 'Maid',
        phone: '+91 98765 12345',
        isActive: true,
        schedule: 'Mon-Sat, 8:00 AM',
        lastEntry: DateTime.now().subtract(const Duration(hours: 2)),
      ),
      DomesticStaff(
        id: '2',
        name: 'Rajesh Kumar',
        role: 'Driver',
        phone: '+91 98765 54321',
        isActive: true,
        schedule: 'Mon-Fri, Flexible',
        lastEntry: DateTime.now().subtract(const Duration(hours: 5)),
      ),
      DomesticStaff(
        id: '3',
        name: 'Geeta Sharma',
        role: 'Cook',
        phone: '+91 98765 67890',
        isActive: false,
        schedule: 'Daily, 6:00 PM',
        lastEntry: DateTime.now().subtract(const Duration(days: 1, hours: 6)),
      ),
    ];
  }

  /// Get recent attendance records
  /// TODO: Replace with actual API call
  Future<List<StaffAttendance>> getRecentAttendance() async {
    await Future.delayed(const Duration(milliseconds: 500));
    
    final now = DateTime.now();
    return [
      StaffAttendance(
        id: '1',
        staffId: '1',
        staffName: 'Laxmi Devi',
        date: now,
        checkIn: DateTime(now.year, now.month, now.day, 8, 10),
        checkOut: DateTime(now.year, now.month, now.day, 10, 25),
      ),
      StaffAttendance(
        id: '2',
        staffId: '2',
        staffName: 'Rajesh Kumar',
        date: now,
        checkIn: DateTime(now.year, now.month, now.day, 9, 15),
        checkOut: null,
      ),
      StaffAttendance(
        id: '3',
        staffId: '1',
        staffName: 'Laxmi Devi',
        date: now.subtract(const Duration(days: 1)),
        checkIn: DateTime(now.year, now.month, now.day - 1, 8, 10),
        checkOut: DateTime(now.year, now.month, now.day - 1, 10, 25),
      ),
      StaffAttendance(
        id: '4',
        staffId: '3',
        staffName: 'Geeta Sharma',
        date: now.subtract(const Duration(days: 1)),
        checkIn: DateTime(now.year, now.month, now.day - 1, 18, 5),
        checkOut: DateTime(now.year, now.month, now.day - 1, 22, 25),
      ),
    ];
  }

  /// Add new staff member
  /// TODO: Replace with actual API call
  Future<bool> addStaff(DomesticStaff staff) async {
    await Future.delayed(const Duration(seconds: 1));
    return true;
  }

  /// Update staff member
  /// TODO: Replace with actual API call
  Future<bool> updateStaff(DomesticStaff staff) async {
    await Future.delayed(const Duration(seconds: 1));
    return true;
  }

  /// Delete staff member
  /// TODO: Replace with actual API call
  Future<bool> deleteStaff(String staffId) async {
    await Future.delayed(const Duration(seconds: 1));
    return true;
  }

  /// Update staff active status
  /// TODO: Replace with actual API call
  Future<bool> updateStaffStatus(String staffId, bool isActive) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return true;
  }
}
