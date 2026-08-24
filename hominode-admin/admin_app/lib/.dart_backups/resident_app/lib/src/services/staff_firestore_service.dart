// lib/src/services/staff_firestore_service.dart
// Staff Firestore Service - Manage maintenance/technician staff

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/staff_model.dart';

class StaffFirestoreService {
  static final StaffFirestoreService instance = StaffFirestoreService._internal();
  factory StaffFirestoreService() => instance;
  StaffFirestoreService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String staffCollection = 'staff';

  /// Get staff member by ID
  Future<StaffModel?> getStaffById(String staffId) async {
    try {
      print('🔵 Fetching staff with ID: $staffId');
      
      final doc = await _firestore
          .collection(staffCollection)
          .doc(staffId)
          .get();

      if (!doc.exists) {
        print('⚠️ Staff not found: $staffId');
        return null;
      }

      final staff = StaffModel.fromFirestore(doc);
      print('✅ Staff fetched: ${staff.name}');
      return staff;
    } catch (e) {
      print('❌ Error fetching staff: $e');
      return null;
    }
  }

  /// Get all active staff members
  Future<List<StaffModel>> getAllActiveStaff() async {
    try {
      print('🔵 Fetching all active staff...');
      
      final snapshot = await _firestore
          .collection(staffCollection)
          .where('isActive', isEqualTo: true)
          .get();

      final staffList = snapshot.docs
          .map((doc) => StaffModel.fromFirestore(doc))
          .toList();

      print('✅ Fetched ${staffList.length} active staff members');
      return staffList;
    } catch (e) {
      print('❌ Error fetching staff list: $e');
      return [];
    }
  }

  /// Get staff by role
  Future<List<StaffModel>> getStaffByRole(String role) async {
    try {
      print('🔵 Fetching staff with role: $role');
      
      final snapshot = await _firestore
          .collection(staffCollection)
          .where('role', isEqualTo: role)
          .where('isActive', isEqualTo: true)
          .get();

      final staffList = snapshot.docs
          .map((doc) => StaffModel.fromFirestore(doc))
          .toList();

      print('✅ Fetched ${staffList.length} staff members with role: $role');
      return staffList;
    } catch (e) {
      print('❌ Error fetching staff by role: $e');
      return [];
    }
  }

  /// Stream staff member by ID (real-time updates)
  Stream<StaffModel?> streamStaffById(String staffId) {
    return _firestore
        .collection(staffCollection)
        .doc(staffId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return null;
      return StaffModel.fromFirestore(doc);
    });
  }
}
