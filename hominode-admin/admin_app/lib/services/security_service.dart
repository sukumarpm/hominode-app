// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:flutter/material.dart';
// import 'admin_service.dart';

// class SecurityService {
//   final FirebaseFirestore _firestore = FirebaseFirestore.instance;
//   final AdminService _adminService = AdminService();
//   final String _securityCollection = 'staff';

//   // ============================================================================
//   // SECURITY STAFF METHODS
//   // ============================================================================

//   /// Get all security staff members (real-time stream) filtered by adminId and role
//   Stream<List<SecurityStaff>> getSecurityStaff() {
//     final adminId = _adminService.getCurrentAdminId();
//     if (adminId == null) return Stream.value([]);

//     print('SecurityService: Fetching security staff for admin: $adminId');
//     return _firestore
//         .collection(_securityCollection)
//         .where(
//           'communityId',
//           isEqualTo: _adminService.requireCurrentCommunityId(),
//         )
//         .where('role', isEqualTo: 'Security')
//         .snapshots()
//         .map((snapshot) {
//           print(
//             'SecurityService: Received ${snapshot.docs.length} security staff members',
//           );
//           return snapshot.docs.map((doc) {
//             final data = doc.data();
//             return SecurityStaff.fromFirestore(doc.id, data);
//           }).toList();
//         })
//         .handleError((error) {
//           print('SecurityService ERROR: $error');
//           return <SecurityStaff>[];
//         });
//   }

//   /// Get security staff member by ID
//   Future<SecurityStaff?> getSecurityStaffById(String staffId) async {
//     try {
//       print('SecurityService: Fetching security staff by ID - $staffId');
//       final doc = await _firestore
//           .collection(_securityCollection)
//           .doc(staffId)
//           .get();

//       if (doc.exists) {
//         final data = doc.data();
//         if (data != null) {
//           print('SecurityService: Security staff found - ${data['name']}');
//           return SecurityStaff.fromFirestore(doc.id, data);
//         }
//       }

//       print('SecurityService: Security staff not found - $staffId');
//       return null;
//     } catch (e) {
//       print('SecurityService ERROR: Failed to fetch security staff: $e');
//       return null;
//     }
//   }

//   /// Assign work to security staff with status update
//   Future<void> assignWork({
//     required String staffId,
//     required String shiftTiming,
//     required String gateAssignment,
//     required String workStatus,
//     String? specialInstructions,
//   }) async {
//     try {
//       print('SecurityService: Assigning work to security staff - $staffId');

//       // When work is assigned, status should be "on-duty" (according to flow function)
//       // The workStatus field stores the work assignment type (On Duty, Off Duty, Break)
//       // The status field reflects the actual attendance/duty status
//       String newStatus =
//           'on-duty'; // Always set to on-duty when work is assigned

//       final updates = {
//         'shiftTiming': shiftTiming,
//         'gateAssignment': gateAssignment,
//         'workStatus': workStatus,
//         'specialInstructions': specialInstructions,
//         'status': newStatus, // Set to on-duty when work is assigned
//         'lastWorkAssignment': FieldValue.serverTimestamp(),
//         'updatedAt': FieldValue.serverTimestamp(),
//       };

//       await _firestore
//           .collection(_securityCollection)
//           .doc(staffId)
//           .update(updates);
//       print(
//         'SecurityService: Work assigned successfully with status: $newStatus',
//       );
//     } catch (e) {
//       print('SecurityService ERROR: Failed to assign work: $e');
//       throw Exception('Failed to assign work: $e');
//     }
//   }

//   /// Update security staff status
//   Future<void> updateSecurityStatus(String staffId, String status) async {
//     try {
//       print('SecurityService: Updating security status - $staffId to $status');
//       await _firestore.collection(_securityCollection).doc(staffId).update({
//         'status': status,
//         'updatedAt': FieldValue.serverTimestamp(),
//       });
//       print('SecurityService: Status updated successfully');
//     } catch (e) {
//       print('SecurityService ERROR: Failed to update status: $e');
//       throw Exception('Failed to update status: $e');
//     }
//   }

//   /// Get security staff statistics
//   Future<SecurityStats> getSecurityStats() async {
//     try {
//       final adminId = _adminService.getCurrentAdminId();
//       if (adminId == null) throw Exception('Admin not logged in');

//       final snapshot = await _firestore
//           .collection(_securityCollection)
//           .where(
//             'communityId',
//             isEqualTo: _adminService.requireCurrentCommunityId(),
//           )
//           .where('role', isEqualTo: 'Security')
//           .get();

//       int total = snapshot.docs.length;
//       int onDuty = 0;
//       int offDuty = 0;
//       int onLeave = 0;

//       for (var doc in snapshot.docs) {
//         final status = doc.data()['status'] as String?;
//         if (status == 'present' || status == 'on-duty') {
//           onDuty++;
//         } else if (status == 'offDuty' || status == 'off-duty') {
//           offDuty++;
//         } else if (status == 'onLeave' || status == 'on-leave') {
//           onLeave++;
//         }
//       }

//       return SecurityStats(
//         total: total,
//         onDuty: onDuty,
//         offDuty: offDuty,
//         onLeave: onLeave,
//       );
//     } catch (e) {
//       print('SecurityService ERROR: Failed to get stats: $e');
//       return SecurityStats(total: 0, onDuty: 0, offDuty: 0, onLeave: 0);
//     }
//   }

//   /// Add security personnel with password
//   Future<void> addSecurityPersonnel({
//     required String name,
//     required String email,
//     required String phone,
//     required String password,
//     required String buildingId,
//   }) async {
//     try {
//       final adminId = _adminService.getCurrentAdminId();
//       if (adminId == null) throw Exception('Admin not logged in');

//       print('SecurityService: Adding security personnel - $name');

//       // Create document with auto-generated ID
//       final docRef = _firestore.collection(_securityCollection).doc();
//       final securityId = docRef.id;

//       await docRef.set({
//         'id': securityId,
//         'name': name,
//         'email': email,
//         'phone': phone,
//         'password': password,
//         'role': 'Security',
//         'buildingId': buildingId,
//         'adminId': adminId,
//         'communityId': _adminService.requireCurrentCommunityId(),
//         'status': 'pending',
//         'createdAt': FieldValue.serverTimestamp(),
//         'updatedAt': FieldValue.serverTimestamp(),
//       });

//       print(
//         'SecurityService: Security personnel added successfully - $securityId',
//       );
//     } catch (e) {
//       print('SecurityService ERROR: Failed to add security personnel: $e');
//       throw Exception('Failed to add security personnel: $e');
//     }
//   }

//   /// Get security personnel by ID (with password for display)
//   Future<Map<String, dynamic>?> getSecurityPersonnelById(
//     String securityId,
//   ) async {
//     try {
//       print('SecurityService: Fetching security personnel by ID - $securityId');
//       final doc = await _firestore
//           .collection(_securityCollection)
//           .doc(securityId)
//           .get();

//       if (doc.exists) {
//         final data = doc.data();
//         if (data != null) {
//           print('SecurityService: Security personnel found - ${data['name']}');
//           return data;
//         }
//       }

//       print('SecurityService: Security personnel not found - $securityId');
//       return null;
//     } catch (e) {
//       print('SecurityService ERROR: Failed to fetch security personnel: $e');
//       return null;
//     }
//   }
// }

// // ============================================================================
// // SECURITY STAFF MODEL
// // ============================================================================

// class SecurityStaff {
//   final String id;
//   final String name;
//   final String role;
//   final String phone;
//   final String? email;
//   final String? address;
//   final String? aadharNumber;
//   final String? emergencyContact;
//   final String? emergencyPhone;
//   final DateTime? joiningDate;
//   final double? salary;
//   final String? photoUrl;
//   final String? aadharFrontUrl;
//   final String? aadharBackUrl;
//   final String status;
//   final DateTime? lastCheckIn;
//   final DateTime? lastCheckOut;

//   // Security-specific fields
//   final String? shiftTiming;
//   final String? gateAssignment;
//   final String? workStatus;
//   final String? specialInstructions;
//   final DateTime? lastWorkAssignment;

//   final DateTime? createdAt;
//   final DateTime? updatedAt;

//   SecurityStaff({
//     required this.id,
//     required this.name,
//     required this.role,
//     required this.phone,
//     this.email,
//     this.address,
//     this.aadharNumber,
//     this.emergencyContact,
//     this.emergencyPhone,
//     this.joiningDate,
//     this.salary,
//     this.photoUrl,
//     this.aadharFrontUrl,
//     this.aadharBackUrl,
//     required this.status,
//     this.lastCheckIn,
//     this.lastCheckOut,
//     this.shiftTiming,
//     this.gateAssignment,
//     this.workStatus,
//     this.specialInstructions,
//     this.lastWorkAssignment,
//     this.createdAt,
//     this.updatedAt,
//   });

//   factory SecurityStaff.fromFirestore(String id, Map<String, dynamic> data) {
//     return SecurityStaff(
//       id: id,
//       name: data['name'] ?? '',
//       role: data['role'] ?? '',
//       phone: data['phone'] ?? '',
//       email: data['email'],
//       address: data['address'],
//       aadharNumber: data['aadharNumber'],
//       emergencyContact: data['emergencyContact'],
//       emergencyPhone: data['emergencyPhone'],
//       joiningDate: (data['joiningDate'] as Timestamp?)?.toDate(),
//       salary: data['salary']?.toDouble(),
//       photoUrl: data['photoUrl'],
//       aadharFrontUrl: data['aadharFrontUrl'],
//       aadharBackUrl: data['aadharBackUrl'],
//       status: data['status'] ?? 'pending',
//       lastCheckIn: (data['lastCheckIn'] as Timestamp?)?.toDate(),
//       lastCheckOut: (data['lastCheckOut'] as Timestamp?)?.toDate(),
//       shiftTiming: data['shiftTiming'],
//       gateAssignment: data['gateAssignment'],
//       workStatus: data['workStatus'],
//       specialInstructions: data['specialInstructions'],
//       lastWorkAssignment: (data['lastWorkAssignment'] as Timestamp?)?.toDate(),
//       createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
//       updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
//     );
//   }

//   String getStatusDisplay() {
//     switch (status.toLowerCase()) {
//       case 'present':
//       case 'on-duty':
//         return 'On Duty';
//       case 'absent':
//         return 'Absent';
//       case 'onleave':
//       case 'on-leave':
//         return 'On Leave';
//       case 'offduty':
//       case 'off-duty':
//         return 'Off Duty';
//       case 'pending':
//       default:
//         return 'Pending';
//     }
//   }

//   Color getStatusColor() {
//     switch (status.toLowerCase()) {
//       case 'present':
//       case 'on-duty':
//         return const Color(0xFF10B981);
//       case 'absent':
//         return const Color(0xFFEF4444);
//       case 'onleave':
//       case 'on-leave':
//         return const Color(0xFFF59E0B);
//       case 'offduty':
//       case 'off-duty':
//         return const Color(0xFF6B7280);
//       case 'pending':
//       default:
//         return const Color(0xFF9CA3AF);
//     }
//   }

//   String? getCheckInTimeDisplay() {
//     if (lastCheckIn == null) return null;
//     final hour = lastCheckIn!.hour.toString().padLeft(2, '0');
//     final minute = lastCheckIn!.minute.toString().padLeft(2, '0');
//     return '$hour:$minute';
//   }

//   String? getCheckOutTimeDisplay() {
//     if (lastCheckOut == null) return null;
//     final hour = lastCheckOut!.hour.toString().padLeft(2, '0');
//     final minute = lastCheckOut!.minute.toString().padLeft(2, '0');
//     return '$hour:$minute';
//   }
// }

// // ============================================================================
// // SECURITY STATS MODEL
// // ============================================================================

// class SecurityStats {
//   final int total;
//   final int onDuty;
//   final int offDuty;
//   final int onLeave;

//   SecurityStats({
//     required this.total,
//     required this.onDuty,
//     required this.offDuty,
//     required this.onLeave,
//   });
// }
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import 'admin_tenant_context.dart';

class SecurityService {
  SecurityService({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
    AdminTenantContext? tenantContext,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _functions =
           functions ??
           FirebaseFunctions.instanceFor(region: 'asia-southeast1'),
       _tenantContext = tenantContext ?? AdminTenantContext.instance;

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;
  final AdminTenantContext _tenantContext;

  static const String _collection = 'securityStaff';

  String get _communityId => _tenantContext.requireTenant().communityId;

  /// Security staff belonging only to the currently selected community.
  ///
  /// We intentionally query only by communityId and then defensively verify
  /// role/community locally. This avoids accidentally fetching another
  /// community and avoids requiring an unnecessary compound Firestore index.
  Stream<List<SecurityStaff>> getSecurityStaff() {
    final communityId = _communityId;

    return _firestore
        .collection(_collection)
        .where('communityId', isEqualTo: communityId)
        .snapshots()
        .map((snapshot) {
          final staff = snapshot.docs
              .where((doc) {
                final data = doc.data();

                return data['communityId'] == communityId &&
                    data['role'] == 'security';
              })
              .map((doc) => SecurityStaff.fromFirestore(doc.id, doc.data()))
              .toList(growable: false);

          final sorted = [...staff]
            ..sort(
              (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
            );

          return sorted;
        });
  }

  /// Reads one Security profile, but only returns it when it belongs to the
  /// current admin's selected community.
  Future<SecurityStaff?> getSecurityStaffById(String staffId) async {
    final id = staffId.trim();

    if (id.isEmpty) {
      return null;
    }

    final communityId = _communityId;

    final doc = await _firestore.collection(_collection).doc(id).get();

    if (!doc.exists) {
      return null;
    }

    final data = doc.data();

    if (data == null ||
        data['communityId'] != communityId ||
        data['role'] != 'security') {
      return null;
    }

    return SecurityStaff.fromFirestore(doc.id, data);
  }

  /// Secure provisioning through the Cloud Function.
  ///
  /// Firebase Auth creation and Firestore securityStaff/{uid} creation are
  /// performed server-side. The Admin client never creates the profile itself.
  Future<void> createSecurityStaff({
    required String name,
    required String phoneNumber,
    String? securityId,
    String? buildingId,
    String? gateId,
    String? shift,
  }) async {
    final tenant = _tenantContext.requireTenant();

    final cleanedName = name.trim();
    final cleanedPhone = phoneNumber.trim();

    if (cleanedName.isEmpty) {
      throw ArgumentError('Security staff name is required.');
    }

    if (!RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(cleanedPhone)) {
      throw ArgumentError(
        'Enter the phone number with country code, for example +639123456789.',
      );
    }

    await _functions.httpsCallable('createSecurityStaff').call({
      'communityId': tenant.communityId,
      'name': cleanedName,
      'phoneNumber': cleanedPhone,
      if (_cleanOptional(securityId) != null)
        'securityId': _cleanOptional(securityId),
      if (_cleanOptional(buildingId) != null)
        'buildingId': _cleanOptional(buildingId),
      if (_cleanOptional(gateId) != null) 'gateId': _cleanOptional(gateId),
      if (_cleanOptional(shift) != null) 'shift': _cleanOptional(shift),
      'isActive': true,
    });
  }

  Future<void> removeAssignment({required String staffId}) async {
    final tenant = _tenantContext.requireTenant();

    final cleanedStaffId = staffId.trim();

    if (cleanedStaffId.isEmpty) {
      throw ArgumentError('Security staff ID is required.');
    }

    await _functions.httpsCallable('removeSecurityAssignment').call({
      'communityId': tenant.communityId,
      'staffUid': cleanedStaffId,
    });
  }

  /// Work assignment will be moved to a verified callable in the next phase.
  ///
  /// Direct writes to securityStaff are intentionally not permitted by the
  /// current Firestore rules.
  Future<void> assignWork({
    required String staffId,
    required String gateId,
    required String shiftTiming,
    required String workStatus,
    String? specialInstructions,
  }) async {
    final tenant = _tenantContext.requireTenant();

    final cleanedStaffId = staffId.trim();
    final cleanedGateId = gateId.trim();
    final cleanedShift = shiftTiming.trim();
    final cleanedStatus = workStatus.trim();
    final cleanedInstructions = specialInstructions?.trim();

    if (cleanedStaffId.isEmpty) {
      throw ArgumentError('Security staff ID is required.');
    }

    if (cleanedGateId.isEmpty) {
      throw ArgumentError('Security place is required.');
    }

    if (cleanedShift.isEmpty) {
      throw ArgumentError('Shift timing is required.');
    }

    if (cleanedStatus.isEmpty) {
      throw ArgumentError('Work status is required.');
    }

    await _functions.httpsCallable('assignSecurityWork').call({
      'communityId': tenant.communityId,
      'staffUid': cleanedStaffId,
      'gateId': cleanedGateId,
      'shiftTiming': cleanedShift,
      'workStatus': cleanedStatus,
      if (cleanedInstructions != null && cleanedInstructions.isNotEmpty)
        'specialInstructions': cleanedInstructions,
    });
  }

  /// Security status changes will also move to a trusted callable.
  Future<void> updateSecurityStatus(String staffId, String status) {
    throw StateError(
      'Security status updates are temporarily unavailable while the '
      'Hominode security backend is being upgraded.',
    );
  }

  Future<SecurityStats> getSecurityStats() async {
    final communityId = _communityId;

    final snapshot = await _firestore
        .collection(_collection)
        .where('communityId', isEqualTo: communityId)
        .get();

    var total = 0;
    var onDuty = 0;
    var offDuty = 0;
    var onLeave = 0;

    for (final doc in snapshot.docs) {
      final data = doc.data();

      if (data['communityId'] != communityId || data['role'] != 'security') {
        continue;
      }

      total++;

      final staff = SecurityStaff.fromFirestore(doc.id, data);

      switch (staff.getStatusDisplay()) {
        case 'On Duty':
          onDuty++;
          break;
        case 'On Leave':
          onLeave++;
          break;
        default:
          offDuty++;
      }
    }

    return SecurityStats(
      total: total,
      onDuty: onDuty,
      offDuty: offDuty,
      onLeave: onLeave,
    );
  }

  static String? _cleanOptional(String? value) {
    final cleaned = value?.trim();

    if (cleaned == null || cleaned.isEmpty) {
      return null;
    }

    return cleaned;
  }
}

class SecurityStaff {
  const SecurityStaff({
    required this.id,
    required this.uid,
    required this.communityId,
    required this.name,
    required this.role,
    required this.phone,
    required this.isActive,
    required this.status,
    this.securityId,
    this.buildingId,
    this.gateId,
    this.shift,
    this.email,
    this.address,
    this.aadharNumber,
    this.emergencyContact,
    this.emergencyPhone,
    this.joiningDate,
    this.salary,
    this.photoUrl,
    this.aadharFrontUrl,
    this.aadharBackUrl,
    this.lastCheckIn,
    this.lastCheckOut,
    this.shiftTiming,
    this.gateAssignment,
    this.workStatus,
    this.specialInstructions,
    this.lastWorkAssignment,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String uid;
  final String communityId;

  final String name;
  final String role;
  final String phone;
  final bool isActive;

  final String? securityId;
  final String? buildingId;
  final String? gateId;
  final String? shift;

  // Kept temporarily for compatibility with the existing Security UI.
  final String? email;
  final String? address;
  final String? aadharNumber;
  final String? emergencyContact;
  final String? emergencyPhone;
  final DateTime? joiningDate;
  final double? salary;
  final String? photoUrl;
  final String? aadharFrontUrl;
  final String? aadharBackUrl;

  final String status;

  final DateTime? lastCheckIn;
  final DateTime? lastCheckOut;

  final String? shiftTiming;
  final String? gateAssignment;
  final String? workStatus;
  final String? specialInstructions;
  final DateTime? lastWorkAssignment;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory SecurityStaff.fromFirestore(String id, Map<String, dynamic> data) {
    final isActive = data['isActive'] == true;

    final rawStatus = (data['status'] as String?)?.trim();

    return SecurityStaff(
      id: id,
      uid: (data['uid'] as String?)?.trim().isNotEmpty == true
          ? data['uid'] as String
          : id,
      communityId: data['communityId'] as String? ?? '',
      name: data['name'] as String? ?? '',
      role: data['role'] as String? ?? '',
      phone: data['phoneNumber'] as String? ?? data['phone'] as String? ?? '',
      isActive: isActive,
      securityId: data['securityId'] as String?,
      buildingId: data['buildingId'] as String?,
      gateId: data['gateId'] as String? ?? data['gateAssignment'] as String?,
      shift: data['shift'] as String? ?? data['shiftTiming'] as String?,
      email: data['email'] as String?,
      address: data['address'] as String?,
      aadharNumber: data['aadharNumber'] as String?,
      emergencyContact: data['emergencyContact'] as String?,
      emergencyPhone: data['emergencyPhone'] as String?,
      joiningDate: _timestampDate(data['joiningDate']),
      salary: (data['salary'] as num?)?.toDouble(),
      photoUrl: data['photoUrl'] as String?,
      aadharFrontUrl: data['aadharFrontUrl'] as String?,
      aadharBackUrl: data['aadharBackUrl'] as String?,
      status: rawStatus?.isNotEmpty == true
          ? rawStatus!
          : isActive
          ? 'off-duty'
          : 'inactive',
      lastCheckIn: _timestampDate(data['lastCheckIn']),
      lastCheckOut: _timestampDate(data['lastCheckOut']),
      shiftTiming: data['shiftTiming'] as String? ?? data['shift'] as String?,
      gateAssignment:
          data['gateAssignment'] as String? ?? data['gateId'] as String?,
      workStatus: data['workStatus'] as String?,
      specialInstructions: data['specialInstructions'] as String?,
      lastWorkAssignment: _timestampDate(data['lastWorkAssignment']),
      createdAt: _timestampDate(data['createdAt']),
      updatedAt: _timestampDate(data['updatedAt']),
    );
  }

  static DateTime? _timestampDate(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    return null;
  }

  String getStatusDisplay() {
    if (!isActive) {
      return 'Inactive';
    }

    switch (status.toLowerCase()) {
      case 'present':
      case 'on-duty':
      case 'onduty':
        return 'On Duty';

      case 'onleave':
      case 'on-leave':
        return 'On Leave';

      case 'absent':
      case 'offduty':
      case 'off-duty':
      case 'inactive':
        return 'Off Duty';

      default:
        return 'Off Duty';
    }
  }

  Color getStatusColor() {
    if (!isActive) {
      return const Color(0xFF9CA3AF);
    }

    switch (getStatusDisplay()) {
      case 'On Duty':
        return const Color(0xFF10B981);

      case 'On Leave':
        return const Color(0xFFF59E0B);

      case 'Off Duty':
      default:
        return const Color(0xFF6B7280);
    }
  }

  String? getCheckInTimeDisplay() {
    if (lastCheckIn == null) {
      return null;
    }

    final hour = lastCheckIn!.hour.toString().padLeft(2, '0');
    final minute = lastCheckIn!.minute.toString().padLeft(2, '0');

    return '$hour:$minute';
  }

  String? getCheckOutTimeDisplay() {
    if (lastCheckOut == null) {
      return null;
    }

    final hour = lastCheckOut!.hour.toString().padLeft(2, '0');
    final minute = lastCheckOut!.minute.toString().padLeft(2, '0');

    return '$hour:$minute';
  }
}

class SecurityStats {
  const SecurityStats({
    required this.total,
    required this.onDuty,
    required this.offDuty,
    required this.onLeave,
  });

  final int total;
  final int onDuty;
  final int offDuty;
  final int onLeave;
}
