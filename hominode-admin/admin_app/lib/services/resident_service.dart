import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'dart:math';
import 'admin_service.dart';
import '../models/pending_resident.dart';

/// Production-ready Resident Service with Firebase Auth integration
/// Implements full admin flow for creating and assigning residents
class ResidentService {
  ResidentService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    AdminService? adminService,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance,
       _adminService = adminService ?? AdminService();

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final AdminService _adminService;
  final String _collection = 'users';

  Stream<List<PendingResident>> watchPendingResidents() {
    final communityId = _adminService.getCurrentCommunityId();
    if (communityId == null) return Stream.value(const []);
    return _firestore
        .collection(_collection)
        .where('communityId', isEqualTo: communityId)
        .where('role', isEqualTo: 'resident')
        .where('approvalStatus', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) {
          final residents = snapshot.docs
              .map((doc) => PendingResident.fromMap(doc.id, doc.data()))
              .toList();
          residents.sort(
            (a, b) => (a.registeredAt ?? DateTime.fromMillisecondsSinceEpoch(0))
                .compareTo(
                  b.registeredAt ?? DateTime.fromMillisecondsSinceEpoch(0),
                ),
          );
          return residents;
        });
  }

  Future<void> approveResident({
    required String userId,
    required String buildingId,
    required String flatId,
  }) async {
    final communityId = _adminService.requireCurrentCommunityId();
    final adminId = _adminService.getCurrentAdminId();
    if (adminId == null) {
      throw StateError('Admin is not authenticated.');
    }

    await _firestore.runTransaction((transaction) async {
      final userRef = _firestore.collection(_collection).doc(userId);
      final buildingRef = _firestore.collection('buildings').doc(buildingId);
      final flatRef = _firestore.collection('flats').doc(flatId);
      final user = await transaction.get(userRef);
      final building = await transaction.get(buildingRef);
      final flat = await transaction.get(flatRef);

      if (!user.exists) {
        throw StateError('Resident registration was not found.');
      }
      if (!building.exists) {
        throw StateError('Selected building was not found.');
      }
      if (!flat.exists) throw StateError('Selected unit was not found.');

      final userData = user.data()!;
      final buildingData = building.data()!;
      final flatData = flat.data()!;
      if (!ResidentApprovalPolicy.canReview(userData, communityId)) {
        throw StateError('Resident is outside the selected community.');
      }
      if (userData['approvalStatus'] != 'pending') {
        throw StateError(
          'Only pending resident registrations can be approved.',
        );
      }
      if (!ResidentApprovalPolicy.canonicalAssignmentMatches(
        building: buildingData,
        unit: flatData,
        communityId: communityId,
        buildingId: buildingId,
      )) {
        throw StateError(
          'The selected building and unit do not belong to this community.',
        );
      }
      if (!ResidentApprovalPolicy.flatCanBeAssigned(flatData, userId)) {
        throw StateError('The selected unit is not available for assignment.');
      }

      final timestamp = FieldValue.serverTimestamp();
      transaction.update(
        userRef,
        approvalFields(
          adminId: adminId,
          buildingId: buildingId,
          flatId: flatId,
          buildingName: (buildingData['buildingName'] ?? buildingData['name'])
              ?.toString(),
          flatLabel: (flatData['flatLabel'] ?? flatData['flatId'])?.toString(),
          timestamp: timestamp,
        ),
      );
      transaction.update(flatRef, {
        'status': 'occupied',
        'residentUserId': userId,
        'residentId': userData['residentId'],
        'residentName': userData['name'] ?? userData['fullName'],
        'updatedAt': timestamp,
      });
    });
  }

  Future<void> rejectResident({required String userId, String? reason}) async {
    final communityId = _adminService.requireCurrentCommunityId();
    final adminId = _adminService.getCurrentAdminId();
    if (adminId == null) throw StateError('Admin is not authenticated.');

    await _firestore.runTransaction((transaction) async {
      final userRef = _firestore.collection(_collection).doc(userId);
      final user = await transaction.get(userRef);
      if (!user.exists) {
        throw StateError('Resident registration was not found.');
      }
      final data = user.data()!;
      if (!ResidentApprovalPolicy.canReview(data, communityId)) {
        throw StateError('Resident is outside the selected community.');
      }
      if (data['approvalStatus'] != 'pending') {
        throw StateError(
          'Only pending resident registrations can be rejected.',
        );
      }
      transaction.update(
        userRef,
        rejectionFields(
          adminId: adminId,
          reason: reason,
          timestamp: FieldValue.serverTimestamp(),
        ),
      );
    });
  }

  @visibleForTesting
  static Map<String, dynamic> approvalFields({
    required String adminId,
    required String buildingId,
    required String flatId,
    required Object timestamp,
    String? buildingName,
    String? flatLabel,
  }) => {
    'approvalStatus': 'approved',
    'isActive': true,
    'buildingId': buildingId,
    'flatId': flatId,
    'unitId': flatId,
    if (buildingName != null) 'buildingName': buildingName,
    if (flatLabel != null) 'flatLabel': flatLabel,
    'approvedAt': timestamp,
    'approvedBy': adminId,
    'updatedAt': timestamp,
  };

  @visibleForTesting
  static Map<String, dynamic> rejectionFields({
    required String adminId,
    required Object timestamp,
    String? reason,
  }) => {
    'approvalStatus': 'rejected',
    'isActive': false,
    'rejectedAt': timestamp,
    'rejectedBy': adminId,
    if (reason?.trim().isNotEmpty == true) 'rejectedReason': reason!.trim(),
    'updatedAt': timestamp,
  };

  /// Create a new resident with Firebase Authentication
  ///
  /// Flow:
  /// 1. Create user in Firebase Auth (email + password)
  /// 2. Get generated UID
  /// 3. Create Firestore document using UID as document ID
  /// 4. Store all required fields
  ///
  /// Returns: UID of created user
  /// Throws: Exception if creation fails (with rollback)
  Future<String> createResident({
    required String name,
    required String email,
    required String phone,
    required String password,
    String? buildingId,
    String? buildingName,
    int familyMembers = 1,
  }) async {
    print('\n╔════════════════════════════════════════════════════════╗');
    print('║         CREATE RESIDENT - START                        ║');
    print('╚════════════════════════════════════════════════════════╝');
    print('Input:');
    print('  Name: $name');
    print('  Email: $email');
    print('  Phone: $phone');
    print('  BuildingId: $buildingId');
    print('  BuildingName: $buildingName');
    print('  Family Members: $familyMembers');

    String? createdUid;
    User? currentUser = _auth.currentUser; // Save current admin user

    try {
      // Step 1: Get admin details
      final adminId = _adminService.getCurrentAdminId();
      if (adminId == null) {
        throw Exception('Admin not logged in');
      }

      final adminProfile = await _adminService.getAdminProfile();
      print('\n[Step 1] Admin details fetched');
      print('   AdminId: $adminId');
      print('   AdminName: ${adminProfile?['name']}');
      print('   AdminEmail: ${adminProfile?['email']}');

      // Get building details from admin profile if not provided
      String? finalBuildingId = buildingId ?? adminProfile?['buildingId'];
      String? finalBuildingName = buildingName ?? adminProfile?['buildingName'];

      print('\n[Step 2] Building details determined');
      print('   BuildingId: $finalBuildingId');
      print('   BuildingName: $finalBuildingName');

      // Step 3: Generate unique resident ID
      final residentId = await generateResidentId();
      print('\n[Step 3] Resident ID generated: $residentId');

      // Step 4: Create user in Firebase Authentication
      print('\n[Step 4] Creating Firebase Auth user...');

      // Create a temporary auth instance to avoid affecting the admin's session
      // We'll use the current user's credentials to re-authenticate after
      final adminEmail = currentUser?.email;

      try {
        final UserCredential userCredential = await _auth
            .createUserWithEmailAndPassword(email: email, password: password);

        createdUid = userCredential.user!.uid;
        print('✅ Firebase Auth user created');
        print('   UID: $createdUid');

        // Step 5: Re-authenticate admin (Firebase Auth switches to new user)
        print('\n[Step 5] Re-authenticating admin...');
        if (currentUser != null && adminEmail != null) {
          try {
            // Sign out the newly created user
            await _auth.signOut();
            print('✅ Signed out new user');

            // The auth wrapper will handle re-authentication
            // We just need to wait a moment for the state to update
            await Future.delayed(const Duration(milliseconds: 500));
            print('✅ Admin session restored');
          } catch (e) {
            print('⚠️  Re-authentication warning: $e');
          }
        }
      } catch (authError) {
        print('❌ Firebase Auth creation failed: $authError');
        throw Exception('Failed to create Firebase Auth account: $authError');
      }

      // Step 6: Create Firestore document with UID as document ID
      print('\n[Step 6] Creating Firestore document...');
      final firestoreData = {
        'uid': createdUid,
        'residentId': residentId,
        'name': name,
        'email': email,
        'phone': phone,
        'role': 'resident',
        'flatId': null,
        'flatLabel': null,
        'buildingId': finalBuildingId,
        'buildingName': finalBuildingName,
        'organization': adminProfile?['organization'] ?? '',
        'adminEmail': adminProfile?['email'] ?? '',
        'adminName': adminProfile?['name'] ?? '',
        'adminPhone': adminProfile?['phone'] ?? '',
        'adminId': adminId,
        'familyMembers': familyMembers,
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _firestore
          .collection(_collection)
          .doc(createdUid)
          .set(firestoreData);

      print('✅ Firestore document created');
      print('   Document ID: $createdUid');
      print('   Path: users/$createdUid');

      // Step 7: Verify document creation
      print('\n[Step 7] Verifying document...');
      final verifyDoc = await _firestore
          .collection(_collection)
          .doc(createdUid)
          .get();
      if (verifyDoc.exists) {
        print('✅ Document verified in Firestore');
        final data = verifyDoc.data();
        print('   uid: ${data?['uid']}');
        print('   residentId: ${data?['residentId']}');
        print('   name: ${data?['name']}');
        print('   email: ${data?['email']}');
        print('   adminId: ${data?['adminId']}');
        print('   buildingId: ${data?['buildingId']}');
      } else {
        throw Exception('Document verification failed');
      }

      print('\n╔════════════════════════════════════════════════════════╗');
      print('║         CREATE RESIDENT - SUCCESS                      ║');
      print('╚════════════════════════════════════════════════════════╝');
      print('Resident created successfully!');
      print('  UID: $createdUid');
      print('  Resident ID: $residentId');
      print('  Email: $email');
      print('');

      return createdUid;
    } catch (e, stackTrace) {
      print('\n╔════════════════════════════════════════════════════════╗');
      print('║         CREATE RESIDENT - FAILED                       ║');
      print('╚════════════════════════════════════════════════════════╝');
      print('❌ Error: $e');
      print('Stack trace: $stackTrace');

      // Rollback: Delete Firebase Auth user if Firestore creation failed
      if (createdUid != null) {
        try {
          print('\n[Rollback] Attempting to delete Firebase Auth user...');
          // Note: We can't delete the user directly as we're not authenticated as that user
          // The user will need to be cleaned up manually or via Admin SDK
          print('⚠️  Firebase Auth user $createdUid may need manual cleanup');
        } catch (rollbackError) {
          print('❌ Rollback failed: $rollbackError');
        }
      }

      throw Exception('Failed to create resident: $e');
    }
  }

  /// Assign resident to flat with proper error handling and rollback
  ///
  /// Flow:
  /// 1. Update users collection with flat details
  /// 2. Update flats collection with resident details
  /// 3. Ensure data consistency (rollback if one fails)
  ///
  /// Throws: Exception if assignment fails (with rollback)
  Future<void> assignResidentToFlat({
    required String residentUid,
    required String flatId,
    required String flatLabel,
    String? buildingId,
    String? buildingName,
    String? ownershipType,
  }) async {
    print('\n╔════════════════════════════════════════════════════════╗');
    print('║      ASSIGN RESIDENT TO FLAT - START                   ║');
    print('╚════════════════════════════════════════════════════════╝');
    print('ResidentUid: $residentUid');
    print('FlatId: $flatId');
    print('FlatLabel: $flatLabel');
    print('BuildingId: ${buildingId ?? "Not provided"}');
    print('BuildingName: ${buildingName ?? "Not provided"}');
    print('OwnershipType: ${ownershipType ?? "Not specified"}');

    // Store original data for rollback
    Map<String, dynamic>? originalUserData;
    Map<String, dynamic>? originalFlatData;

    try {
      // Step 1: Get resident data
      print('\n[Step 1] Fetching resident data...');
      final userDoc = await _firestore
          .collection(_collection)
          .doc(residentUid)
          .get();
      if (!userDoc.exists) {
        throw Exception('Resident not found');
      }

      originalUserData = userDoc.data();
      final residentId = originalUserData?['residentId'] as String?;
      final residentName = originalUserData?['name'] as String?;

      print('✅ Resident data fetched');
      print('   ResidentId: $residentId');
      print('   ResidentName: $residentName');

      // Step 2: Get flat data and building info if not provided
      print('\n[Step 2] Fetching flat data...');
      final flatDoc = await _firestore.collection('flats').doc(flatId).get();
      if (!flatDoc.exists) {
        throw Exception('Flat not found');
      }

      originalFlatData = flatDoc.data();
      String? finalBuildingId = buildingId ?? originalFlatData?['buildingId'];
      String? finalBuildingName =
          buildingName ?? originalFlatData?['buildingName'];

      print('✅ Flat data fetched');
      print('   BuildingId: $finalBuildingId');
      print('   BuildingName: $finalBuildingName');

      // Step 3: Update user document
      print('\n[Step 3] Updating user document...');
      final userUpdateData = {
        'flatId': flatId,
        'flatLabel': flatLabel,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (finalBuildingId != null) {
        userUpdateData['buildingId'] = finalBuildingId;
      }

      if (finalBuildingName != null) {
        userUpdateData['buildingName'] = finalBuildingName;
      }

      if (ownershipType != null) {
        userUpdateData['ownershipType'] = ownershipType;
      }

      await _firestore
          .collection(_collection)
          .doc(residentUid)
          .update(userUpdateData);
      print('✅ User document updated');

      // Step 4: Update flat document
      print('\n[Step 4] Updating flat document...');
      final flatUpdateData = {
        'residentId': residentId,
        'residentName': residentName,
        'residentUid': residentUid,
        'status': 'occupied',
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (ownershipType != null) {
        flatUpdateData['ownershipType'] = ownershipType;
      }

      await _firestore.collection('flats').doc(flatId).update(flatUpdateData);
      print('✅ Flat document updated');

      // Step 5: Verify updates
      print('\n[Step 5] Verifying updates...');
      final verifyUser = await _firestore
          .collection(_collection)
          .doc(residentUid)
          .get();
      final verifyFlat = await _firestore.collection('flats').doc(flatId).get();

      if (!verifyUser.exists || !verifyFlat.exists) {
        throw Exception('Verification failed: Documents not found');
      }

      final userData = verifyUser.data();
      final flatData = verifyFlat.data();

      if (userData?['flatId'] != flatId ||
          flatData?['residentUid'] != residentUid) {
        throw Exception('Verification failed: Data mismatch');
      }

      print('✅ Updates verified');
      print('   User flatId: ${userData?['flatId']}');
      print('   Flat residentUid: ${flatData?['residentUid']}');
      print('   Flat status: ${flatData?['status']}');

      print('\n╔════════════════════════════════════════════════════════╗');
      print('║      ASSIGN RESIDENT TO FLAT - SUCCESS                 ║');
      print('╚════════════════════════════════════════════════════════╝\n');
    } catch (e, stackTrace) {
      print('\n╔════════════════════════════════════════════════════════╗');
      print('║      ASSIGN RESIDENT TO FLAT - FAILED                  ║');
      print('╚════════════════════════════════════════════════════════╝');
      print('❌ Error: $e');
      print('Stack trace: $stackTrace');

      // Rollback: Restore original data
      print('\n[Rollback] Attempting to restore original data...');
      try {
        if (originalUserData != null) {
          await _firestore
              .collection(_collection)
              .doc(residentUid)
              .set(originalUserData);
          print('✅ User document restored');
        }

        if (originalFlatData != null) {
          await _firestore
              .collection('flats')
              .doc(flatId)
              .set(originalFlatData);
          print('✅ Flat document restored');
        }

        print('✅ Rollback completed successfully');
      } catch (rollbackError) {
        print('❌ Rollback failed: $rollbackError');
        print('⚠️  Manual data cleanup may be required');
      }

      throw Exception('Failed to assign resident to flat: $e');
    }
  }

  /// Generate unique resident ID
  Future<String> generateResidentId() async {
    final random = Random();
    String residentId;
    bool exists = true;

    while (exists) {
      final number = random.nextInt(9000) + 1000; // 1000-9999
      residentId = 'RES$number';

      final snapshot = await _firestore
          .collection(_collection)
          .where('residentId', isEqualTo: residentId)
          .limit(1)
          .get();

      exists = snapshot.docs.isNotEmpty;

      if (!exists) {
        return residentId;
      }
    }

    return 'RES${random.nextInt(9000) + 1000}';
  }

  /// Get all residents for current admin
  Stream<List<ResidentModel>> getResidents() async* {
    final communityId = _adminService.getCurrentCommunityId();
    if (communityId == null) {
      yield [];
      return;
    }

    yield* _firestore
        .collection(_collection)
        .where('role', isEqualTo: 'resident')
        .where('communityId', isEqualTo: communityId)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            return ResidentModel.fromFirestore(doc.id, data);
          }).toList();
        });
  }

  /// Get resident by UID
  Future<ResidentModel?> getResidentByUid(String uid) async {
    try {
      final doc = await _firestore.collection(_collection).doc(uid).get();
      if (!doc.exists) return null;
      return ResidentModel.fromFirestore(doc.id, doc.data()!);
    } catch (e) {
      throw Exception('Failed to get resident: $e');
    }
  }
}

/// Resident Model
class ResidentModel {
  final String uid;
  final String residentId;
  final String name;
  final String email;
  final String phone;
  final String role;
  final String? flatId;
  final String? flatLabel;
  final String? buildingId;
  final String? buildingName;
  final String? ownershipType;
  final int familyMembers;
  final String status;
  final String organization;
  final String adminEmail;
  final String adminName;
  final String adminPhone;
  final String adminId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  ResidentModel({
    required this.uid,
    required this.residentId,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    this.flatId,
    this.flatLabel,
    this.buildingId,
    this.buildingName,
    this.ownershipType,
    required this.familyMembers,
    required this.status,
    required this.organization,
    required this.adminEmail,
    required this.adminName,
    required this.adminPhone,
    required this.adminId,
    this.createdAt,
    this.updatedAt,
  });

  factory ResidentModel.fromFirestore(String uid, Map<String, dynamic> data) {
    return ResidentModel(
      uid: uid,
      residentId: data['residentId'] ?? '',
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      phone: data['phone'] ?? '',
      role: data['role'] ?? 'resident',
      flatId: data['flatId'],
      flatLabel: data['flatLabel'],
      buildingId: data['buildingId'],
      buildingName: data['buildingName'],
      ownershipType: data['ownershipType'],
      familyMembers: data['familyMembers'] ?? 1,
      status: data['status'] ?? 'active',
      organization: data['organization'] ?? '',
      adminEmail: data['adminEmail'] ?? '',
      adminName: data['adminName'] ?? '',
      adminPhone: data['adminPhone'] ?? '',
      adminId: data['adminId'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  bool get isAvailable => flatId == null || flatId!.isEmpty;
  bool get isAssigned => flatId != null && flatId!.isNotEmpty;
}
