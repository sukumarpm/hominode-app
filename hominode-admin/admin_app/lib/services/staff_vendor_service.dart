import 'package:cloud_firestore/cloud_firestore.dart';
import 'admin_service.dart';

class StaffVendorService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AdminService _adminService = AdminService();
  final String _staffCollection = 'staff';
  final String _vendorCollection = 'vendors';

  // ============================================================================
  // STAFF METHODS
  // ============================================================================

  /// Add new staff member with documents
  Future<String> addStaffMemberWithDocuments({
    required String name,
    required String role,
    required String phone,
    required String address,
    required String aadharNumber,
    String? email,
    String? emergencyContact,
    String? emergencyPhone,
    DateTime? joiningDate,
    double? salary,
    String? photoUrl,
    String? aadharFrontUrl,
    String? aadharBackUrl,
    String? password,
  }) async {
    try {
      final adminId = _adminService.getCurrentAdminId();
      if (adminId == null) throw Exception('Admin not logged in');

      print('StaffVendorService: Adding staff member with documents - $name');

      final docRef = await _firestore.collection(_staffCollection).add({
        'name': name,
        'role': role,
        'phone': phone,
        'email': email,
        'address': address,
        'aadharNumber': aadharNumber,
        'emergencyContact': emergencyContact,
        'emergencyPhone': emergencyPhone,
        'joiningDate': joiningDate != null
            ? Timestamp.fromDate(joiningDate)
            : null,
        'salary': salary,
        'photoUrl': photoUrl,
        'aadharFrontUrl': aadharFrontUrl,
        'aadharBackUrl': aadharBackUrl,
        'password': password,
        'status': 'pending', // pending, present, absent, onLeave, offDuty
        'lastCheckIn': null,
        'lastCheckOut': null,
        'adminId': adminId, // Link to admin
        'communityId': _adminService.requireCurrentCommunityId(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('StaffVendorService: Staff member added with ID: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      print('StaffVendorService ERROR: Failed to add staff member: $e');
      throw Exception('Failed to add staff member: $e');
    }
  }

  /// Add new staff member
  Future<String> addStaffMember({
    required String name,
    required String role,
    required String phone,
    String? email,
    String? address,
    DateTime? joiningDate,
    double? salary,
  }) async {
    try {
      final adminId = _adminService.getCurrentAdminId();
      if (adminId == null) throw Exception('Admin not logged in');

      print('StaffVendorService: Adding staff member - $name');

      final docRef = await _firestore.collection(_staffCollection).add({
        'name': name,
        'role': role,
        'phone': phone,
        'email': email,
        'address': address,
        'joiningDate': joiningDate != null
            ? Timestamp.fromDate(joiningDate)
            : null,
        'salary': salary,
        'status': 'pending', // pending, present, absent, onLeave, offDuty
        'lastCheckIn': null,
        'lastCheckOut': null,
        'adminId': adminId, // Link to admin
        'communityId': _adminService.requireCurrentCommunityId(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('StaffVendorService: Staff member added with ID: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      print('StaffVendorService ERROR: Failed to add staff member: $e');
      throw Exception('Failed to add staff member: $e');
    }
  }

  /// Get all staff members (real-time stream) filtered by adminId
  Stream<List<StaffMember>> getStaffMembers() {
    final adminId = _adminService.getCurrentAdminId();
    if (adminId == null) return Stream.value([]);

    print('StaffVendorService: Fetching staff members for admin: $adminId');
    return _firestore
        .collection(_staffCollection)
        .where(
          'communityId',
          isEqualTo: _adminService.requireCurrentCommunityId(),
        )
        .snapshots()
        .map((snapshot) {
          print(
            'StaffVendorService: Received ${snapshot.docs.length} staff members',
          );
          return snapshot.docs.map((doc) {
            final data = doc.data();
            return StaffMember.fromFirestore(doc.id, data);
          }).toList();
        })
        .handleError((error) {
          print('StaffVendorService ERROR: $error');
          // Return empty list instead of throwing
          return <StaffMember>[];
        });
  }

  /// Security roster for the Admin attendance flow.
  Stream<List<StaffMember>> getSecurityStaffMembers() {
    final communityId = _adminService.requireCurrentCommunityId();

    return _firestore
        .collection('securityStaff')
        .where('communityId', isEqualTo: communityId)
        .snapshots()
        .map((snapshot) {
          final staff = snapshot.docs
              .map((doc) => StaffMember.fromFirestore(doc.id, doc.data()))
              .toList(growable: false);
          return [...staff]..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );
        });
  }

  /// Get staff member by ID
  Future<StaffMember?> getStaffMemberById(String staffId) async {
    try {
      print('StaffVendorService: Fetching staff member by ID - $staffId');
      final doc = await _firestore
          .collection(_staffCollection)
          .doc(staffId)
          .get();

      if (doc.exists) {
        final data = doc.data();
        if (data != null) {
          print('StaffVendorService: Staff member found - ${data['name']}');
          return StaffMember.fromFirestore(doc.id, data);
        }
      }

      print('StaffVendorService: Staff member not found - $staffId');
      return null;
    } catch (e) {
      print('StaffVendorService ERROR: Failed to fetch staff member: $e');
      return null;
    }
  }

  /// Security profile lookup scoped to the selected Admin community.
  Future<StaffMember?> getSecurityStaffMemberById(String staffId) async {
    final communityId = _adminService.requireCurrentCommunityId();
    final snapshot = await _firestore
        .collection('securityStaff')
        .where('communityId', isEqualTo: communityId)
        .where(FieldPath.documentId, isEqualTo: staffId)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    final doc = snapshot.docs.single;
    return StaffMember.fromFirestore(doc.id, doc.data());
  }

  /// Update staff member
  Future<void> updateStaffMember(
    String staffId,
    Map<String, dynamic> updates,
  ) async {
    try {
      print('StaffVendorService: Updating staff member - $staffId');
      updates['updatedAt'] = FieldValue.serverTimestamp();
      await _firestore
          .collection(_staffCollection)
          .doc(staffId)
          .update(updates);
      print('StaffVendorService: Staff member updated successfully');
    } catch (e) {
      print('StaffVendorService ERROR: Failed to update staff member: $e');
      throw Exception('Failed to update staff member: $e');
    }
  }

  /// Delete staff member
  Future<void> deleteStaffMember(String staffId) async {
    try {
      print('StaffVendorService: Deleting staff member - $staffId');
      await _firestore.collection(_staffCollection).doc(staffId).delete();
      print('StaffVendorService: Staff member deleted successfully');
    } catch (e) {
      print('StaffVendorService ERROR: Failed to delete staff member: $e');
      throw Exception('Failed to delete staff member: $e');
    }
  }

  // ============================================================================
  // VENDOR METHODS
  // ============================================================================

  /// Add new vendor with documents
  Future<String> addVendorWithDocuments({
    required String businessName,
    required String category,
    required String contactPerson,
    required String phone,
    required String address,
    required String aadharNumber,
    String? email,
    DateTime? contractStartDate,
    DateTime? contractEndDate,
    List<String>? services,
    String? photoUrl,
    String? aadharFrontUrl,
    String? aadharBackUrl,
  }) async {
    try {
      final adminId = _adminService.getCurrentAdminId();
      if (adminId == null) throw Exception('Admin not logged in');

      print('StaffVendorService: Adding vendor with documents - $businessName');

      final docRef = await _firestore.collection(_vendorCollection).add({
        'businessName': businessName,
        'category': category,
        'contactPerson': contactPerson,
        'phone': phone,
        'email': email,
        'address': address,
        'aadharNumber': aadharNumber,
        'photoUrl': photoUrl,
        'aadharFrontUrl': aadharFrontUrl,
        'aadharBackUrl': aadharBackUrl,
        'contractStartDate': contractStartDate != null
            ? Timestamp.fromDate(contractStartDate)
            : null,
        'contractEndDate': contractEndDate != null
            ? Timestamp.fromDate(contractEndDate)
            : null,
        'services': services ?? [],
        'rating': 0.0,
        'totalServices': 0,
        'status': 'active',
        'adminId': adminId, // Link to admin
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('StaffVendorService: Vendor added with ID: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      print('StaffVendorService ERROR: Failed to add vendor: $e');
      throw Exception('Failed to add vendor: $e');
    }
  }

  /// Add new vendor
  Future<String> addVendor({
    required String businessName,
    required String category,
    required String contactPerson,
    required String phone,
    String? email,
    String? address,
    DateTime? contractStartDate,
    DateTime? contractEndDate,
    List<String>? services,
  }) async {
    try {
      final adminId = _adminService.getCurrentAdminId();
      if (adminId == null) throw Exception('Admin not logged in');

      print('StaffVendorService: Adding vendor - $businessName');

      final docRef = await _firestore.collection(_vendorCollection).add({
        'businessName': businessName,
        'category': category,
        'contactPerson': contactPerson,
        'phone': phone,
        'email': email,
        'address': address,
        'contractStartDate': contractStartDate != null
            ? Timestamp.fromDate(contractStartDate)
            : null,
        'contractEndDate': contractEndDate != null
            ? Timestamp.fromDate(contractEndDate)
            : null,
        'services': services ?? [],
        'rating': 0.0,
        'totalServices': 0,
        'status': 'active',
        'adminId': adminId, // Link to admin
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('StaffVendorService: Vendor added with ID: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      print('StaffVendorService ERROR: Failed to add vendor: $e');
      throw Exception('Failed to add vendor: $e');
    }
  }

  /// Get all vendors (real-time stream) filtered by adminId
  Stream<List<VendorModel>> getVendors() {
    final adminId = _adminService.getCurrentAdminId();
    if (adminId == null) return Stream.value([]);

    print('StaffVendorService: Fetching vendors for admin: $adminId');
    return _firestore
        .collection(_vendorCollection)
        .where(
          'communityId',
          isEqualTo: _adminService.requireCurrentCommunityId(),
        )
        .snapshots()
        .map((snapshot) {
          print('StaffVendorService: Received ${snapshot.docs.length} vendors');
          return snapshot.docs.map((doc) {
            final data = doc.data();
            return VendorModel.fromFirestore(doc.id, data);
          }).toList();
        })
        .handleError((error) {
          print('StaffVendorService ERROR: $error');
          // Return empty list instead of throwing
          return <VendorModel>[];
        });
  }

  /// Get vendor by ID
  Future<VendorModel?> getVendorById(String vendorId) async {
    try {
      print('StaffVendorService: Fetching vendor by ID - $vendorId');
      final doc = await _firestore
          .collection(_vendorCollection)
          .doc(vendorId)
          .get();

      if (doc.exists) {
        final data = doc.data();
        if (data != null) {
          print('StaffVendorService: Vendor found - ${data['businessName']}');
          return VendorModel.fromFirestore(doc.id, data);
        }
      }

      print('StaffVendorService: Vendor not found - $vendorId');
      return null;
    } catch (e) {
      print('StaffVendorService ERROR: Failed to fetch vendor: $e');
      return null;
    }
  }

  /// Update vendor
  Future<void> updateVendor(
    String vendorId,
    Map<String, dynamic> updates,
  ) async {
    try {
      print('StaffVendorService: Updating vendor - $vendorId');
      updates['updatedAt'] = FieldValue.serverTimestamp();
      await _firestore
          .collection(_vendorCollection)
          .doc(vendorId)
          .update(updates);
      print('StaffVendorService: Vendor updated successfully');
    } catch (e) {
      print('StaffVendorService ERROR: Failed to update vendor: $e');
      throw Exception('Failed to update vendor: $e');
    }
  }

  /// Delete vendor
  Future<void> deleteVendor(String vendorId) async {
    try {
      print('StaffVendorService: Deleting vendor - $vendorId');
      await _firestore.collection(_vendorCollection).doc(vendorId).delete();
      print('StaffVendorService: Vendor deleted successfully');
    } catch (e) {
      print('StaffVendorService ERROR: Failed to delete vendor: $e');
      throw Exception('Failed to delete vendor: $e');
    }
  }
}

// ============================================================================
// STAFF MEMBER MODEL
// ============================================================================

class StaffMember {
  final String id;
  final String name;
  final String role;
  final String phone;
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
  final String status; // pending, present, absent, onLeave, offDuty
  final DateTime? lastCheckIn;
  final DateTime? lastCheckOut;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? password; // For security staff

  StaffMember({
    required this.id,
    required this.name,
    required this.role,
    required this.phone,
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
    required this.status,
    this.lastCheckIn,
    this.lastCheckOut,
    this.createdAt,
    this.updatedAt,
    this.password,
  });

  factory StaffMember.fromFirestore(String id, Map<String, dynamic> data) {
    return StaffMember(
      id: id,
      name: data['name'] ?? '',
      role: data['role'] ?? '',
      phone: data['phone'] ?? data['phoneNumber'] ?? '',
      email: data['email'],
      address: data['address'],
      aadharNumber: data['aadharNumber'],
      emergencyContact: data['emergencyContact'],
      emergencyPhone: data['emergencyPhone'],
      joiningDate: (data['joiningDate'] as Timestamp?)?.toDate(),
      salary: data['salary']?.toDouble(),
      photoUrl: data['photoUrl'],
      aadharFrontUrl: data['aadharFrontUrl'],
      aadharBackUrl: data['aadharBackUrl'],
      status:
          data['status'] ?? (data['isActive'] == true ? 'active' : 'inactive'),
      lastCheckIn: (data['lastCheckIn'] as Timestamp?)?.toDate(),
      lastCheckOut: (data['lastCheckOut'] as Timestamp?)?.toDate(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      password: data['password'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'role': role,
      'phone': phone,
      'email': email,
      'address': address,
      'aadharNumber': aadharNumber,
      'emergencyContact': emergencyContact,
      'emergencyPhone': emergencyPhone,
      'joiningDate': joiningDate != null
          ? Timestamp.fromDate(joiningDate!)
          : null,
      'salary': salary,
      'photoUrl': photoUrl,
      'aadharFrontUrl': aadharFrontUrl,
      'aadharBackUrl': aadharBackUrl,
      'status': status,
      'lastCheckIn': lastCheckIn != null
          ? Timestamp.fromDate(lastCheckIn!)
          : null,
      'lastCheckOut': lastCheckOut != null
          ? Timestamp.fromDate(lastCheckOut!)
          : null,
    };
  }

  String getStatusDisplay() {
    switch (status) {
      case 'present':
        return 'Present';
      case 'absent':
        return 'Absent';
      case 'onLeave':
        return 'On Leave';
      case 'offDuty':
        return 'Off Duty';
      case 'pending':
      default:
        return 'Pending';
    }
  }

  String? getCheckInTimeDisplay() {
    if (lastCheckIn == null) return null;
    final hour = lastCheckIn!.hour.toString().padLeft(2, '0');
    final minute = lastCheckIn!.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String? getCheckOutTimeDisplay() {
    if (lastCheckOut == null) return null;
    final hour = lastCheckOut!.hour.toString().padLeft(2, '0');
    final minute = lastCheckOut!.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

// ============================================================================
// VENDOR MODEL
// ============================================================================

class VendorModel {
  final String id;
  final String businessName;
  final String category;
  final String contactPerson;
  final String phone;
  final String? email;
  final String? address;
  final String? aadharNumber;
  final String? photoUrl;
  final String? aadharFrontUrl;
  final String? aadharBackUrl;
  final DateTime? contractStartDate;
  final DateTime? contractEndDate;
  final List<String> services;
  final double rating;
  final int totalServices;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  VendorModel({
    required this.id,
    required this.businessName,
    required this.category,
    required this.contactPerson,
    required this.phone,
    this.email,
    this.address,
    this.aadharNumber,
    this.photoUrl,
    this.aadharFrontUrl,
    this.aadharBackUrl,
    this.contractStartDate,
    this.contractEndDate,
    this.services = const [],
    this.rating = 0.0,
    this.totalServices = 0,
    required this.status,
    this.createdAt,
    this.updatedAt,
  });

  factory VendorModel.fromFirestore(String id, Map<String, dynamic> data) {
    return VendorModel(
      id: id,
      businessName: data['businessName'] ?? '',
      category: data['category'] ?? '',
      contactPerson: data['contactPerson'] ?? '',
      phone: data['phone'] ?? '',
      email: data['email'],
      address: data['address'],
      aadharNumber: data['aadharNumber'],
      photoUrl: data['photoUrl'],
      aadharFrontUrl: data['aadharFrontUrl'],
      aadharBackUrl: data['aadharBackUrl'],
      contractStartDate: (data['contractStartDate'] as Timestamp?)?.toDate(),
      contractEndDate: (data['contractEndDate'] as Timestamp?)?.toDate(),
      services: List<String>.from(data['services'] ?? []),
      rating: (data['rating'] ?? 0.0).toDouble(),
      totalServices: data['totalServices'] ?? 0,
      status: data['status'] ?? 'active',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'businessName': businessName,
      'category': category,
      'contactPerson': contactPerson,
      'phone': phone,
      'email': email,
      'address': address,
      'aadharNumber': aadharNumber,
      'photoUrl': photoUrl,
      'aadharFrontUrl': aadharFrontUrl,
      'aadharBackUrl': aadharBackUrl,
      'contractStartDate': contractStartDate != null
          ? Timestamp.fromDate(contractStartDate!)
          : null,
      'contractEndDate': contractEndDate != null
          ? Timestamp.fromDate(contractEndDate!)
          : null,
      'services': services,
      'rating': rating,
      'totalServices': totalServices,
      'status': status,
    };
  }
}
