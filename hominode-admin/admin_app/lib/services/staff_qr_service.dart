import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:typed_data';
import 'admin_service.dart';

class StaffQRService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AdminService _adminService = AdminService();

  // ============================================================================
  // UNIQUE ID GENERATION
  // ============================================================================

  /// Generate unique staff ID
  String generateUniqueStaffId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = (DateTime.now().microsecond % 10000).toString().padLeft(
      4,
      '0',
    );
    return 'STAFF_${timestamp}_$random';
  }

  // ============================================================================
  // QR CODE GENERATION
  // ============================================================================

  /// Generate QR code image from staff ID
  Future<Uint8List> generateQRCode(String staffId) async {
    try {
      final qrPainter = QrPainter(
        data: staffId,
        version: QrVersions.auto,
        gapless: false,
      );

      final image = await qrPainter.toImageData(200);
      return image!.buffer.asUint8List();
    } catch (e) {
      print('StaffQRService ERROR: Failed to generate QR code: $e');
      throw Exception('Failed to generate QR code: $e');
    }
  }

  /// Save QR code to Firestore storage reference
  Future<void> saveQRCodeReference(String staffId, String qrCodeUrl) async {
    try {
      await _firestore.collection('staff').doc(staffId).update({
        'qrCodeUrl': qrCodeUrl,
        'qrCodeGeneratedAt': FieldValue.serverTimestamp(),
      });
      print('StaffQRService: QR code reference saved for staff: $staffId');
    } catch (e) {
      print('StaffQRService ERROR: Failed to save QR code reference: $e');
      throw Exception('Failed to save QR code reference: $e');
    }
  }

  // ============================================================================
  // STAFF CREATION WITH QR CODE
  // ============================================================================

  /// Create staff member with QR code (with pre-generated ID)
  Future<void> createStaffWithQRCode({
    required String staffId,
    required String name,
    required String phone,
    required String role,
    required String buildingId,
    required String gateName,
    required String shiftTiming,
    String? photoUrl,
  }) async {
    try {
      final adminId = _adminService.getCurrentAdminId();
      if (adminId == null) throw Exception('Admin not logged in');

      print('StaffQRService: Creating staff member: $name with ID: $staffId');

      // Create staff document
      await _firestore.collection('staff').doc(staffId).set({
        'staffId': staffId,
        'name': name,
        'phone': phone,
        'role': role,
        'buildingId': buildingId,
        'gateName': gateName,
        'shiftTiming': shiftTiming,
        'photoUrl': photoUrl,
        'qrCodeUrl': '', // Will be updated after generation
        'adminId': adminId,
        'communityId': _adminService.requireCurrentCommunityId(),
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('StaffQRService: Staff member created successfully');
    } catch (e) {
      print('StaffQRService ERROR: Failed to create staff with QR: $e');
      throw Exception('Failed to create staff with QR: $e');
    }
  }

  /// Create staff member with QR code (old method - generates ID)
  Future<String> createStaffWithQRCodeOld({
    required String name,
    required String phone,
    required String role,
    required String buildingId,
    required String gateName,
    required String shiftTiming,
    String? photoUrl,
  }) async {
    try {
      final adminId = _adminService.getCurrentAdminId();
      if (adminId == null) throw Exception('Admin not logged in');

      // Generate unique staff ID
      final staffId = _firestore.collection('staff').doc().id;

      print('StaffQRService: Creating staff member: $name with ID: $staffId');

      // Create staff document
      await _firestore.collection('staff').doc(staffId).set({
        'staffId': staffId,
        'name': name,
        'phone': phone,
        'role': role,
        'buildingId': buildingId,
        'gateName': gateName,
        'shiftTiming': shiftTiming,
        'photoUrl': photoUrl,
        'qrCodeUrl': '', // Will be updated after generation
        'adminId': adminId,
        'communityId': _adminService.requireCurrentCommunityId(),
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('StaffQRService: Staff member created successfully');
      return staffId;
    } catch (e) {
      print('StaffQRService ERROR: Failed to create staff with QR: $e');
      throw Exception('Failed to create staff with QR: $e');
    }
  }

  // ============================================================================
  // STAFF RETRIEVAL
  // ============================================================================

  /// Get staff details by ID
  Future<Map<String, dynamic>> getStaffDetails(String staffId) async {
    try {
      final communityId = _adminService.requireCurrentCommunityId();
      final snapshot = await _firestore
          .collection('securityStaff')
          .where('communityId', isEqualTo: communityId)
          .where(FieldPath.documentId, isEqualTo: staffId)
          .limit(1)
          .get();
      if (snapshot.docs.isEmpty) {
        throw Exception('Staff member not found');
      }
      return _normalizedSecurityStaff(snapshot.docs.single);
    } catch (e) {
      print('StaffQRService ERROR: Failed to get staff details: $e');
      throw Exception('Failed to get staff details: $e');
    }
  }

  /// Get all staff members for admin
  Future<List<Map<String, dynamic>>> getAllStaffMembers() async {
    try {
      final adminId = _adminService.getCurrentAdminId();
      if (adminId == null) throw Exception('Admin not logged in');

      final snapshot = await _firestore
          .collection('securityStaff')
          .where(
            'communityId',
            isEqualTo: _adminService.requireCurrentCommunityId(),
          )
          .get();

      final staff = snapshot.docs.map(_normalizedSecurityStaff).toList();
      staff.sort((a, b) {
        final aCreatedAt = a['createdAt'] as Timestamp?;
        final bCreatedAt = b['createdAt'] as Timestamp?;
        return (bCreatedAt?.millisecondsSinceEpoch ?? 0).compareTo(
          aCreatedAt?.millisecondsSinceEpoch ?? 0,
        );
      });
      return staff;
    } catch (e) {
      print('StaffQRService ERROR: Failed to get staff members: $e');
      throw Exception('Failed to get staff members: $e');
    }
  }

  // ============================================================================
  // ATTENDANCE TRACKING
  // ============================================================================

  /// Mark staff entry
  Future<void> markStaffEntry(String staffId) async {
    throw UnsupportedError(
      'Admin QR check-in is disabled. Security must check in from the '
      'Security app.',
    );
  }

  /// Mark staff exit
  Future<void> markStaffExit(String staffId) async {
    throw UnsupportedError(
      'Admin QR check-out is disabled. Security must check out from the '
      'Security app.',
    );
  }

  /// Get staff attendance records
  Future<List<Map<String, dynamic>>> getStaffAttendance(String staffId) async {
    try {
      final snapshot = await _firestore
          .collection('staffAttendance')
          .where(
            'communityId',
            isEqualTo: _adminService.requireCurrentCommunityId(),
          )
          .where('staffId', isEqualTo: staffId)
          .orderBy('checkInTime', descending: true)
          .limit(30)
          .get();

      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      print('StaffQRService ERROR: Failed to get attendance: $e');
      throw Exception('Failed to get attendance: $e');
    }
  }

  // ============================================================================
  // STAFF PROFILE OPERATIONS
  // ============================================================================

  /// Update staff details
  Future<void> updateStaffDetails(
    String staffId,
    Map<String, dynamic> updates,
  ) async {
    try {
      updates['updatedAt'] = FieldValue.serverTimestamp();
      await _firestore.collection('staff').doc(staffId).update(updates);
      print('StaffQRService: Staff details updated for: $staffId');
    } catch (e) {
      print('StaffQRService ERROR: Failed to update staff: $e');
      throw Exception('Failed to update staff: $e');
    }
  }

  /// Delete staff member
  Future<void> deleteStaffMember(String staffId) async {
    try {
      await _firestore.collection('staff').doc(staffId).delete();
      print('StaffQRService: Staff member deleted: $staffId');
    } catch (e) {
      print('StaffQRService ERROR: Failed to delete staff: $e');
      throw Exception('Failed to delete staff: $e');
    }
  }

  Map<String, dynamic> _normalizedSecurityStaff(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = Map<String, dynamic>.from(doc.data());
    return {
      ...data,
      'id': doc.id,
      'staffId': data['staffId'] ?? data['uid'] ?? doc.id,
      'phone': data['phone'] ?? data['phoneNumber'] ?? '',
      'gateName':
          data['gateName'] ??
          data['gateAssignment'] ??
          data['gateId'] ??
          'Not assigned',
      'shiftTiming': data['shiftTiming'] ?? data['shift'] ?? 'Not assigned',
    };
  }
}
