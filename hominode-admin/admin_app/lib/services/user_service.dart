import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import 'admin_service.dart';
import 'resident_service.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AdminService _adminService = AdminService();
  final ResidentService _residentService = ResidentService();
  final String _collection = 'users';

  static bool isReturningResidentData(Map<String, dynamic> data) {
    final flatId = data['flatId']?.toString().trim() ?? '';
    final residentType = data['residentType']?.toString().trim().toLowerCase();
    final ownershipType = data['ownershipType']
        ?.toString()
        .trim()
        .toLowerCase();
    final canonicalType = residentType?.isNotEmpty == true
        ? residentType
        : ownershipType;
    return data['role'] == 'resident' &&
        data['approvalStatus'] == 'approved' &&
        data['isActive'] == false &&
        data['status'] == 'inactive' &&
        data['occupancyStatus'] == 'moved_out' &&
        flatId.isEmpty &&
        (canonicalType == 'owner' || canonicalType == 'tenant') &&
        (residentType == null ||
            residentType.isEmpty ||
            residentType == canonicalType) &&
        (ownershipType == null ||
            ownershipType.isEmpty ||
            ownershipType == canonicalType);
  }

  // Get all users (residents) - FILTERED BY ADMIN
  Stream<List<UserModel>> getUsers() async* {
    print('UserService: Fetching residents for current admin');

    final communityId = _adminService.getCurrentCommunityId();
    if (communityId == null) {
      print('UserService: No admin logged in');
      yield [];
      return;
    }

    print('UserService: Filtering by communityId: $communityId');

    // Query by adminId instead of buildingId to show all residents created by this admin
    // This includes both assigned and unassigned residents
    yield* _firestore
        .collection(_collection)
        .where('role', isEqualTo: 'resident')
        .where('communityId', isEqualTo: communityId)
        .snapshots()
        .map((snapshot) {
          print(
            'UserService: Received ${snapshot.docs.length} residents from Firestore',
          );
          return snapshot.docs
              .where((doc) {
                final data = doc.data();
                return data['approvalStatus'] == 'approved';
              })
              .map((doc) {
                final data = doc.data();
                print(
                  'UserService: Processing resident ${doc.id}: ${data['name']}',
                );

                // Handle both 'status' string and 'isActive' boolean
                String status = 'active';
                if (data.containsKey('status')) {
                  status = data['status'] ?? 'active';
                } else if (data.containsKey('isActive')) {
                  status = (data['isActive'] == true) ? 'active' : 'inactive';
                }

                return UserModel(
                  id: doc.id, // Firebase Auth UID
                  name: data['name'] ?? data['fullName'] ?? '',
                  phone: data['phone'] ?? data['phoneNumber'] ?? '',
                  email: data['email'],
                  password: data['password'],
                  residentId: data['residentId'] ?? '',
                  role: data['role'] ?? 'resident',
                  flatId: data['flatId'],
                  flatLabel: data['flatLabel'],
                  buildingId: data['buildingId'],
                  buildingName: data['buildingName'],
                  unitId: data['unitId'],
                  communityId: data['communityId'],
                  buildingReference: data['buildingReference']?.toString(),
                  unitReference: data['unitReference']?.toString(),
                  approvalStatus: data['approvalStatus'] ?? '',
                  isActive: data['isActive'] == true,
                  occupancyStatus: data['occupancyStatus']?.toString(),
                  ownershipType: data['ownershipType'],
                  familyMembers: data['familyMembers'] ?? 1,
                  status: status,
                  createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
                  updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
                );
              })
              .toList();
        })
        .handleError((error) {
          print('UserService ERROR: Failed to fetch residents: $error');
          throw Exception('Failed to fetch residents: $error');
        });
  }

  // Get ALL residents with their status (for assign resident modal) - FILTERED BY ADMIN
  Stream<List<UserModel>> getAllResidentsWithStatus() async* {
    print('\n╔════════════════════════════════════════════════════════╗');
    print('║      GET ALL RESIDENTS WITH STATUS - START             ║');
    print('╚════════════════════════════════════════════════════════╝');

    final communityId = _adminService.getCurrentCommunityId();
    if (communityId == null) {
      print('⚠️  No admin logged in');
      yield [];
      return;
    }

    print('Collection: $_collection');
    print('Query: WHERE role = "resident" AND communityId = $communityId');
    print('Note: Fetching all residents created by this admin');

    yield* _firestore
        .collection(_collection)
        .where('role', isEqualTo: 'resident')
        .where('communityId', isEqualTo: communityId)
        .snapshots()
        .map((snapshot) {
          print('\n[Snapshot Received]');
          print('Total documents: ${snapshot.docs.length}');

          if (snapshot.docs.isEmpty) {
            print('⚠️  No residents found for this admin!');
            return <UserModel>[];
          }

          print('\nProcessing residents...');
          final allResidents = snapshot.docs.map((doc) {
            final data = doc.data();
            final flatId = data['flatId'];
            final flatLabel = data['flatLabel'];
            final isAssigned = flatId != null && flatId.toString().isNotEmpty;

            print('  Document ${doc.id}:');
            print('    residentId: ${data['residentId']}');
            print('    Name: ${data['name']}');
            print('    BuildingId: ${data['buildingId']}');
            print('    FlatId: $flatId');
            print('    FlatLabel: $flatLabel');
            print(
              '    Status: ${isAssigned ? "Assigned to $flatLabel" : "Available"}',
            );

            // Handle both 'status' string and 'isActive' boolean
            String status = 'active';
            if (data.containsKey('status')) {
              status = data['status'] ?? 'active';
            } else if (data.containsKey('isActive')) {
              status = (data['isActive'] == true) ? 'active' : 'inactive';
            }

            return UserModel(
              id: doc.id, // Firebase Auth UID
              name: data['name'] ?? '',
              phone: data['phone'] ?? '',
              email: data['email'],
              password: data['password'],
              residentId: data['residentId'] ?? '',
              role: data['role'] ?? 'resident',
              flatId: data['flatId'],
              flatLabel: data['flatLabel'],
              buildingId: data['buildingId'],
              buildingName: data['buildingName'],
              ownershipType: data['ownershipType'],
              familyMembers: data['familyMembers'] ?? 1,
              status: status,
              createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
              updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
            );
          }).toList();

          // Sort: Available first, then assigned
          allResidents.sort((a, b) {
            final aAssigned = a.flatId != null && a.flatId!.isNotEmpty;
            final bAssigned = b.flatId != null && b.flatId!.isNotEmpty;

            if (!aAssigned && bAssigned) return -1; // Available first
            if (aAssigned && !bAssigned) return 1;
            return a.name.compareTo(b.name); // Then alphabetically
          });

          final availableCount = allResidents
              .where((r) => r.flatId == null || r.flatId!.isEmpty)
              .length;
          final assignedCount = allResidents.length - availableCount;

          print('\n✅ Total residents: ${allResidents.length}');
          print('   - Available: $availableCount');
          print('   - Assigned: $assignedCount');

          for (var user in allResidents) {
            final statusText = user.flatId != null && user.flatId!.isNotEmpty
                ? 'Assigned to ${user.flatLabel}'
                : 'Available';
            print('   - ${user.name} (${user.residentId}) - $statusText');
          }

          print('╚════════════════════════════════════════════════════════╝\n');
          return allResidents;
        })
        .handleError((error) {
          print('\n╔════════════════════════════════════════════════════════╗');
          print('║      GET ALL RESIDENTS WITH STATUS - ERROR             ║');
          print('╚════════════════════════════════════════════════════════╝');
          print('❌ Error: $error');
          throw Exception('Failed to fetch all residents: $error');
        });
  }

  // Get available users (not assigned to any flat)
  Stream<List<UserModel>> getAvailableUsers() {
    print('\n╔════════════════════════════════════════════════════════╗');
    print('║         GET AVAILABLE USERS - START                    ║');
    print('╚════════════════════════════════════════════════════════╝');
    print('Collection: $_collection');
    final communityId = _adminService.getCurrentCommunityId();
    if (communityId == null) return Stream.value(const <UserModel>[]);
    print('Query: returning residents in community $communityId');

    return _firestore
        .collection(_collection)
        .where('role', isEqualTo: 'resident')
        .where('communityId', isEqualTo: communityId)
        .snapshots()
        .map((snapshot) {
          print('\n[Snapshot Received]');
          print('Total documents: ${snapshot.docs.length}');

          if (snapshot.docs.isEmpty) {
            print('⚠️  No residents found in Firestore!');
            print('   This could mean:');
            print('   1. No residents have been created yet');
            print('   2. Firestore rules are blocking read access');
            print('   3. Collection name mismatch');
            return <UserModel>[];
          }

          print('\nProcessing documents...');
          final availableUsers = snapshot.docs
              .where((doc) {
                final data = doc.data();
                final flatId = data['flatId'];
                final isAvailable = isReturningResidentData(data);

                print('  Document ${doc.id}:');
                print('    Name: ${data['name']}');
                print('    FlatId: $flatId');
                print('    Available: $isAvailable');

                return isAvailable;
              })
              .map((doc) {
                final data = doc.data();

                // Handle both 'status' string and 'isActive' boolean
                String status = 'active';
                if (data.containsKey('status')) {
                  status = data['status'] ?? 'active';
                } else if (data.containsKey('isActive')) {
                  status = (data['isActive'] == true) ? 'active' : 'inactive';
                }

                return UserModel(
                  id: doc.id, // Firebase Auth UID
                  name: data['name'] ?? '',
                  phone: data['phone'] ?? '',
                  email: data['email'],
                  password: data['password'],
                  residentId: data['residentId'] ?? '',
                  role: data['role'] ?? 'resident',
                  flatId: data['flatId'],
                  flatLabel: data['flatLabel'],
                  buildingId: data['buildingId'],
                  buildingName: data['buildingName'],
                  unitId: data['unitId'],
                  communityId: data['communityId'],
                  approvalStatus: data['approvalStatus'] ?? '',
                  isActive: data['isActive'] == true,
                  occupancyStatus: data['occupancyStatus']?.toString(),
                  ownershipType: data['ownershipType'],
                  familyMembers: data['familyMembers'] ?? 1,
                  status: status,
                  createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
                  updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
                );
              })
              .toList();

          print('\n✅ Available residents: ${availableUsers.length}');
          for (var user in availableUsers) {
            print('   - ${user.name} (${user.phone}) - Status: ${user.status}');
          }

          print('╚════════════════════════════════════════════════════════╝\n');
          return availableUsers;
        })
        .handleError((error) {
          print('\n╔════════════════════════════════════════════════════════╗');
          print('║         GET AVAILABLE USERS - ERROR                    ║');
          print('╚════════════════════════════════════════════════════════╝');
          print('❌ Error: $error');
          print('Stack trace: ${StackTrace.current}');
          throw Exception('Failed to fetch available residents: $error');
        });
  }

  // Get user by ID
  Future<UserModel?> getUserById(String userId) async {
    try {
      final doc = await _firestore.collection(_collection).doc(userId).get();
      if (!doc.exists) return null;

      final data = doc.data()!;
      return UserModel(
        id: doc.id,
        name: data['name'] ?? data['fullName'] ?? '',
        phone: data['phone'] ?? data['phoneNumber'] ?? '',
        email: data['email'],
        password: data['password'],
        residentId: data['residentId'] ?? '',
        role: data['role'] ?? 'resident',
        flatId: data['flatId'],
        flatLabel: data['flatLabel'],
        buildingId: data['buildingId'],
        buildingName: data['buildingName'],
        unitId: data['unitId'],
        communityId: data['communityId'],
        approvalStatus: data['approvalStatus'] ?? '',
        isActive: data['isActive'] == true,
        occupancyStatus: data['occupancyStatus']?.toString(),
        ownershipType: data['ownershipType'],
        familyMembers: data['familyMembers'] ?? 1,
        status: data['status'] ?? 'active',
        createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
        updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      );
    } catch (e) {
      throw Exception('Failed to get user: $e');
    }
  }

  /// Creates a server-owned pending onboarding record. It intentionally does
  /// not create a Firebase Auth account or a /users profile.
  Future<String> createUser({
    required String name,
    required String phone,
    String? password,
    String? email,
    String residentType = 'owner',
    String? buildingId,
    String? buildingName,
    String? unitReference,
    int familyMembers = 1,
  }) => _residentService.createResidentOnboarding(
    name: name,
    phone: phone,
    email: email,
    residentType: residentType,
    familyMembers: familyMembers,
    buildingReference: buildingName,
    unitReference: unitReference,
  );

  // Historical implementation retained privately while old widgets are
  // migrated. It has no active caller.
  // ignore: unused_element
  Future<String> _legacyCreateUser({
    required String name,
    required String phone,
    required String password,
    String? email,
    String? buildingId,
    String? buildingName,
    int familyMembers = 1,
  }) async {
    print('\n╔════════════════════════════════════════════════════════╗');
    print('║         CREATE USER - START                            ║');
    print('╚════════════════════════════════════════════════════════╝');
    print('Input parameters:');
    print('  - Name: $name');
    print('  - Phone: $phone');
    print('  - Email: $email');
    print('  - BuildingId: $buildingId');
    print('  - BuildingName: $buildingName');
    print('  - Password: [HIDDEN]');
    print('  - Family Members: $familyMembers');

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
      print('   Organization: ${adminProfile?['organization']}');

      // Step 1.5: Get buildingId and buildingName from admin profile if not provided
      String? finalBuildingId = buildingId;
      String? finalBuildingName = buildingName;

      if (finalBuildingId == null || finalBuildingName == null) {
        // Try to get from admin profile
        finalBuildingId = adminProfile?['buildingId'] as String?;
        finalBuildingName = adminProfile?['buildingName'] as String?;

        print('\n[Step 1.5] Building details from admin profile:');
        print('   BuildingId: $finalBuildingId');
        print('   BuildingName: $finalBuildingName');
      }

      // Step 2: Determine auth email with uniqueness
      // IMPORTANT: We don't create Firebase Auth account during resident creation
      // The resident will create their own account when they first log in
      // So we just store the email for future use
      String authEmail;
      if (email?.isNotEmpty == true) {
        // Make email unique by adding timestamp to prevent conflicts
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final emailParts = email!.split('@');
        if (emailParts.length == 2) {
          // john@example.com → john+1709123456789@example.com
          authEmail = '${emailParts[0]}+$timestamp@${emailParts[1]}';
        } else {
          authEmail = '$email+$timestamp';
        }
      } else {
        // Generate unique email from phone + timestamp to avoid conflicts
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        authEmail = '$phone.$timestamp@lyvo.com';
      }

      print('\n[Step 2] Auth email determined: $authEmail');
      print('   Note: Firebase Auth account will NOT be created now');
      print('   Resident will create their own account on first login');
      print('   Email made unique to prevent conflicts: $authEmail');

      // Step 3: Generate UID for resident (without creating Firebase Auth account yet)
      // IMPORTANT: We don't create Firebase Auth account here to avoid logging out the admin
      // The resident will create their own account when they first log in
      print('[Step 3] Generating resident UID...');

      // Generate a unique ID for the resident document
      // We'll use Firestore's auto-generated ID
      final residentDocRef = _firestore.collection(_collection).doc();
      final String uid = residentDocRef.id;

      print('✅ Resident document ID generated');
      print('   UID: $uid');
      print('   Auth Email (for future use): $authEmail');
      print(
        '   Note: Firebase Auth account will be created when resident first logs in',
      );

      // Store the auth email and password for future account creation
      // When resident logs in for the first time, we'll create their Firebase Auth account

      // Step 4: Generate unique resident ID for internal reference
      print('\n[Step 4] Generating resident ID...');
      final residentId = await generateResidentId();
      print('✅ Resident ID generated: $residentId');

      // Step 5: Prepare Firestore data with admin details and building info
      final firestoreData = {
        'name': name,
        'phone': phone,
        'email': email ?? authEmail,
        'authEmail':
            authEmail, // Email to use for Firebase Auth account creation
        'password': password, // Store password for future account creation
        'residentId': residentId,
        'role': 'resident',
        'flatId': null,
        'flatLabel': null,
        'buildingId': finalBuildingId,
        'buildingName': finalBuildingName,
        'ownershipType': null,
        'familyMembers': familyMembers,
        'status': 'active',
        'authAccountCreated':
            false, // Flag to track if Firebase Auth account is created
        // Admin details
        'adminId': adminId,
        'communityId': _adminService.requireCurrentCommunityId(),
        'adminName': adminProfile?['name'] ?? '',
        'adminEmail': adminProfile?['email'] ?? '',
        'adminPhone': adminProfile?['phone'] ?? '',
        'organization': adminProfile?['organization'] ?? '',
        // Timestamps
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      print(
        '\n[Step 5] Creating Firestore document with admin and building details...',
      );
      print('Collection: $_collection');
      print('Document ID: $uid (pre-generated)');
      print('Data to store:');
      print('  residentId: $residentId');
      print('  name: $name');
      print('  phone: $phone');
      print('  email: ${email ?? authEmail}');
      print('  authEmail: $authEmail');
      print('  password: [HIDDEN]');
      print('  role: resident');
      print('  status: active');
      print('  authAccountCreated: false');
      print('  buildingId: $finalBuildingId');
      print('  buildingName: $finalBuildingName');
      print('  flatId: null (unassigned)');
      print('  adminId: $adminId');
      print('  adminName: ${adminProfile?['name']}');
      print('  organization: ${adminProfile?['organization']}');

      // Create Firestore user document using pre-generated UID
      await residentDocRef.set(firestoreData);

      print('✅ Firestore document created successfully!');
      print('   Document path: users/$uid');

      // Verify the document was created
      print('\n[Step 6] Verifying document...');
      final verifyDoc = await _firestore.collection(_collection).doc(uid).get();
      if (verifyDoc.exists) {
        print('✅ Document verified in Firestore');
        final data = verifyDoc.data();
        print('   residentId: ${data?['residentId']}');
        print('   name: ${data?['name']}');
        print('   email: ${data?['email']}');
        print('   authEmail: ${data?['authEmail']}');
        print('   role: ${data?['role']}');
        print('   authAccountCreated: ${data?['authAccountCreated']}');
        print('   adminId: ${data?['adminId']}');
        print('   buildingId: ${data?['buildingId']}');
        print('   buildingName: ${data?['buildingName']}');
      } else {
        print('❌ Document not found after creation!');
      }

      print('\n╔════════════════════════════════════════════════════════╗');
      print('║         CREATE USER - SUCCESS                          ║');
      print('╚════════════════════════════════════════════════════════╝');
      print('Resident data stored successfully!');
      print('  Document ID: $uid');
      print('  Resident ID: $residentId');
      print('  Auth Email: $authEmail');
      print('  Password: [stored securely]');
      print('');
      print('NOTE: Firebase Auth account will be created when resident');
      print('      logs in for the first time. This prevents logging out');
      print('      the admin during resident creation.');
      print('');

      return uid; // Return the UID (which is also the document ID)
    } catch (e) {
      print('\n╔════════════════════════════════════════════════════════╗');
      print('║         CREATE USER - FAILED                           ║');
      print('╚════════════════════════════════════════════════════════╝');
      print('❌ Error: $e');
      print('Stack trace: ${StackTrace.current}');
      throw Exception('Failed to create user: $e');
    }
  }

  Future<void> assignUserToFlat({
    required String userId,
    required String flatId,
    required String flatLabel,
    String? buildingId,
    String? buildingName,
    String? ownershipType,
  }) async {
    if (buildingId == null || buildingId.trim().isEmpty) {
      throw StateError('A building is required to reassign a resident.');
    }
    await _residentService.reassignResident(
      userId: userId,
      buildingId: buildingId,
      flatId: flatId,
    );
  }

  // Historical direct assignment implementation; no active lifecycle flow
  // should invoke it.
  // ignore: unused_element
  // Assign user to flat - SAFE VERSION with existence checks and batch operations
  Future<void> _legacyAssignUserToFlat({
    required String userId,
    required String flatId,
    required String flatLabel,
    String? buildingId,
    String? buildingName,
    String? ownershipType,
  }) async {
    try {
      print('\n╔════════════════════════════════════════════════════════╗');
      print('║           ASSIGN USER TO FLAT - START                  ║');
      print('╚════════════════════════════════════════════════════════╝');
      print('UserId: $userId');
      print('FlatId: $flatId');
      print('FlatLabel: $flatLabel');
      print('BuildingId: ${buildingId ?? "Not provided"}');
      print('BuildingName: ${buildingName ?? "Not provided"}');
      print('OwnershipType: ${ownershipType ?? "Not specified"}');

      // STEP 1: Check if user document exists
      print('\n[Step 1] Checking if user document exists...');
      final userDoc = await _firestore
          .collection(_collection)
          .doc(userId)
          .get();
      if (!userDoc.exists) {
        print('❌ User document not found: $userId');
        throw Exception('User not found in system');
      }

      final userData = userDoc.data()!;
      final residentId = userData['residentId'] as String?;
      final residentName = userData['name'] as String?;
      print('✅ User document found');
      print('   Name: $residentName');
      print('   ResidentId: $residentId');

      // STEP 2: Query for the flat document using flatId field
      print('\n[Step 2] Querying for flat document with flatId: $flatId...');
      final flatQuery = await _firestore
          .collection('flats')
          .where('flatId', isEqualTo: flatId)
          .limit(1)
          .get();

      if (flatQuery.docs.isEmpty) {
        print('❌ Flat document not found with flatId: $flatId');
        throw Exception(
          'Flat not found. Please ensure the flat exists in the system.',
        );
      }

      final flatDocRef = flatQuery.docs.first.reference;
      final flatData = flatQuery.docs.first.data();

      print('✅ Flat document found');
      print('   Document ID: ${flatDocRef.id}');
      print('   FlatId: ${flatData['flatId']}');
      print('   Current Status: ${flatData['status']}');

      // STEP 3: Get building info from flat if not provided
      print('\n[Step 3] Determining building information...');
      String? finalBuildingId = buildingId;
      String? finalBuildingName = buildingName;

      if (finalBuildingId == null || finalBuildingName == null) {
        print('   Building info not provided, fetching from flat document...');
        finalBuildingId = flatData['buildingId'] as String?;
        finalBuildingName = flatData['buildingName'] as String?;
      }
      print('✅ Building info determined');
      print('   BuildingId: $finalBuildingId');
      print('   BuildingName: $finalBuildingName');

      // STEP 4: Prepare batch operation for atomic updates
      print('\n[Step 4] Creating batch operation for atomic updates...');
      final batch = _firestore.batch();

      // Prepare user update data
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

      // Queue user document update
      batch.update(
        _firestore.collection(_collection).doc(userId),
        userUpdateData,
      );
      print('   - User document update queued');

      // Prepare flat update data
      final flatUpdateData = {
        'residentId': residentId,
        'residentName': residentName,
        'residentUserId': userId,
        'status': 'occupied',
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (ownershipType != null) {
        flatUpdateData['ownershipType'] = ownershipType;
      }

      // Queue flat document update
      batch.update(flatDocRef, flatUpdateData);
      print('   - Flat document update queued');

      // STEP 5: Commit batch
      print('\n[Step 5] Committing batch operation...');
      await batch.commit();
      print('✅ Batch committed successfully');

      // STEP 6: Verify updates
      print('\n[Step 6] Verifying updates...');
      final verifyUser = await _firestore
          .collection(_collection)
          .doc(userId)
          .get();
      final verifyFlat = await flatDocRef.get();

      if (verifyUser.exists && verifyFlat.exists) {
        final updatedUserData = verifyUser.data()!;
        final updatedFlatData = verifyFlat.data()!;

        print('✅ Verification successful');
        print('   User flatId: ${updatedUserData['flatId']}');
        print('   Flat status: ${updatedFlatData['status']}');
        print('   Flat residentId: ${updatedFlatData['residentId']}');
      }

      print('\n╔════════════════════════════════════════════════════════╗');
      print('║      ASSIGN USER TO FLAT - COMPLETED SUCCESSFULLY      ║');
      print('╚════════════════════════════════════════════════════════╝');
      print('User assigned to flat:');
      print('  UserId: $userId');
      print('  FlatId: $flatId');
      print('  FlatLabel: $flatLabel');
      print('  ResidentName: $residentName');
      print('');
    } catch (e) {
      print('\n╔════════════════════════════════════════════════════════╗');
      print('║      ASSIGN USER TO FLAT - FAILED                      ║');
      print('╚════════════════════════════════════════════════════════╝');
      print('❌ Error: $e');
      print('Stack trace: ${StackTrace.current}');
      throw Exception('Failed to assign user to flat: $e');
    }
  }

  Future<void> removeUserFromFlat(String userId) =>
      _residentService.moveOutResident(userId);

  // Historical direct removal implementation; trusted move-out is used now.
  // ignore: unused_element
  // Remove user from flat - SAFE VERSION with existence checks and batch operations
  Future<void> _legacyRemoveUserFromFlat(String userId) async {
    try {
      print('\n╔════════════════════════════════════════════════════════╗');
      print('║        REMOVE USER FROM FLAT - START                   ║');
      print('╚════════════════════════════════════════════════════════╝');
      print('UserId: $userId');

      // STEP 1: Check if user document exists
      print('\n[Step 1] Checking if user document exists...');
      final userDoc = await _firestore
          .collection(_collection)
          .doc(userId)
          .get();
      if (!userDoc.exists) {
        print('❌ User document not found: $userId');
        throw Exception('User not found in system');
      }

      final userData = userDoc.data()!;
      final flatId = userData['flatId'] as String?;
      print('✅ User document found');
      print('   Name: ${userData['name']}');
      print('   Current FlatId: $flatId');

      // STEP 2: If no flat assigned, just return success
      if (flatId == null || flatId.isEmpty) {
        print('\n[Step 2] User has no flat assigned');
        print('✅ No action needed - user already unassigned');
        print('╚════════════════════════════════════════════════════════╝\n');
        return;
      }

      // STEP 3: Query for the flat document using flatId field
      print('\n[Step 3] Querying for flat document with flatId: $flatId...');

      final flatQuery = await _firestore
          .collection('flats')
          .where('flatId', isEqualTo: flatId)
          .limit(1)
          .get();

      if (flatQuery.docs.isEmpty) {
        print('⚠️  Flat document not found with flatId: $flatId');
        print('   This might mean the flat was deleted');
        print('   Proceeding to update user document only...');

        // Still update user document even if flat doesn't exist
        await _firestore.collection(_collection).doc(userId).update({
          'flatId': null,
          'flatLabel': null,
          'buildingId': null,
          'buildingName': null,
          'ownershipType': null,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        print('✅ User document updated (flat not found)');
        print('╚════════════════════════════════════════════════════════╝\n');
        return;
      }

      final flatDocRef = flatQuery.docs.first.reference;
      final flatData = flatQuery.docs.first.data();
      print('✅ Flat document found');
      print('   Document ID: ${flatDocRef.id}');
      print('   FlatId: ${flatData['flatId']}');
      print('   Current Status: ${flatData['status']}');

      // STEP 4: Use batch operation for consistency
      print('\n[Step 4] Creating batch operation for atomic updates...');
      final batch = _firestore.batch();

      // Update user document
      batch.update(_firestore.collection(_collection).doc(userId), {
        'flatId': null,
        'flatLabel': null,
        'buildingId': null,
        'buildingName': null,
        'ownershipType': null,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('   - User document update queued');

      // Update flat document
      batch.update(flatDocRef, {
        'residentId': null,
        'residentName': null,
        'residentUserId': null,
        'status': 'vacant',
        'ownershipType': null,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('   - Flat document update queued');

      // STEP 5: Commit batch
      print('\n[Step 5] Committing batch operation...');
      await batch.commit();
      print('✅ Batch committed successfully');

      // STEP 6: Verify updates
      print('\n[Step 6] Verifying updates...');
      final verifyUser = await _firestore
          .collection(_collection)
          .doc(userId)
          .get();
      final verifyFlat = await flatDocRef.get();

      if (verifyUser.exists && verifyFlat.exists) {
        final updatedUserData = verifyUser.data()!;
        final updatedFlatData = verifyFlat.data()!;

        print('✅ Verification successful');
        print('   User flatId: ${updatedUserData['flatId']}');
        print('   Flat status: ${updatedFlatData['status']}');
        print('   Flat residentId: ${updatedFlatData['residentId']}');
      }

      print('\n╔════════════════════════════════════════════════════════╗');
      print('║     REMOVE USER FROM FLAT - COMPLETED SUCCESSFULLY     ║');
      print('╚════════════════════════════════════════════════════════╝');
      print('User removed from flat:');
      print('  UserId: $userId');
      print('  FlatId: $flatId');
      print('  Name: ${userData['name']}');
      print('');
    } catch (e) {
      print('\n╔════════════════════════════════════════════════════════╗');
      print('║     REMOVE USER FROM FLAT - FAILED                     ║');
      print('╚════════════════════════════════════════════════════════╝');
      print('❌ Error: $e');
      print('Stack trace: ${StackTrace.current}');
      throw Exception('Failed to remove user from flat: $e');
    }
  }

  // Update user
  Future<void> updateUser({
    required String userId,
    String? name,
    String? phone,
    String? email,
    String? password,
    int? familyMembers,
    String? status,
  }) async {
    try {
      if (status != null) {
        throw ArgumentError(
          'Resident lifecycle status must use updateUserStatus().',
        );
      }
      final updates = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (name != null) updates['name'] = name;
      if (phone != null) updates['phone'] = phone;
      if (email != null) updates['email'] = email;
      if (password != null) updates['password'] = password;
      if (familyMembers != null) updates['familyMembers'] = familyMembers;

      await _firestore.collection(_collection).doc(userId).update(updates);
    } catch (e) {
      throw Exception('Failed to update user: $e');
    }
  }

  // Update user status (activate/deactivate)
  Future<void> updateUserStatus({
    required String userId,
    required String status,
  }) async {
    if (status == 'active') {
      await _residentService.reactivateResident(userId);
      return;
    }
    if (status == 'inactive') {
      await _residentService.deactivateResident(userId);
      return;
    }
    throw ArgumentError.value(status, 'status', 'Use active or inactive.');
  }

  Future<void> deleteUser(String userId) => Future<void>.error(
    StateError('Resident hard-delete is retired. Use Move Out.'),
  );

  // Historical hard-delete implementation; resident history is retained now.
  // ignore: unused_element
  Future<void> _legacyDeleteUser(String userId) async {
    try {
      // Get user data to find auth UID
      final doc = await _firestore.collection(_collection).doc(userId).get();
      final authUid = doc.data()?['authUid'];

      // Delete from Firestore
      await _firestore.collection(_collection).doc(userId).delete();

      // Delete from Firebase Auth if exists
      if (authUid != null) {
        try {
          // Note: Deleting other users requires Admin SDK
          // For now, just delete from Firestore
          print(
            'User auth account with UID $authUid should be deleted manually or via Admin SDK',
          );
        } catch (e) {
          print('Failed to delete auth account: $e');
        }
      }
    } catch (e) {
      throw Exception('Failed to delete user: $e');
    }
  }

  // Generate unique resident ID
  Future<String> generateResidentId() async {
    final random = Random();
    String residentId;
    bool exists = true;

    // Keep generating until we find a unique ID
    while (exists) {
      final number = random.nextInt(9000) + 1000; // 1000-9999
      residentId = 'RES$number';

      // Check if this ID already exists
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

    // Fallback (should never reach here)
    return 'RES${random.nextInt(9000) + 1000}';
  }

  // Generate random password
  String generatePassword() {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random();
    return String.fromCharCodes(
      Iterable.generate(
        8,
        (_) => chars.codeUnitAt(random.nextInt(chars.length)),
      ),
    );
  }
}

// User Model
class UserModel {
  final String id; // Firebase Auth UID (also Firestore document ID)
  final String name;
  final String phone;
  final String? email;
  final String? password; // Password stored in Firestore
  final String residentId;
  final String role;
  final String? flatId;
  final String? flatLabel;
  final String? buildingId;
  final String? buildingName;
  final String? unitId;
  final String? communityId;
  final String? buildingReference;
  final String? unitReference;
  final String approvalStatus;
  final bool isActive;
  final String? occupancyStatus;
  final String? ownershipType;
  final int familyMembers;
  final String status; // active, inactive
  final DateTime? createdAt;
  final DateTime? updatedAt;

  UserModel({
    required this.id,
    required this.name,
    required this.phone,
    this.email,
    this.password,
    required this.residentId,
    required this.role,
    this.flatId,
    this.flatLabel,
    this.buildingId,
    this.buildingName,
    this.unitId,
    this.communityId,
    this.buildingReference,
    this.unitReference,
    this.approvalStatus = '',
    this.isActive = false,
    this.occupancyStatus,
    this.ownershipType,
    required this.familyMembers,
    required this.status,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'email': email,
      'password': password,
      'residentId': residentId,
      'role': role,
      'flatId': flatId,
      'flatLabel': flatLabel,
      'buildingId': buildingId,
      'buildingName': buildingName,
      'unitId': unitId,
      'communityId': communityId,
      'buildingReference': buildingReference,
      'unitReference': unitReference,
      'approvalStatus': approvalStatus,
      'isActive': isActive,
      'occupancyStatus': occupancyStatus,
      'ownershipType': ownershipType,
      'familyMembers': familyMembers,
      'status': status,
    };
  }

  bool get isAvailable => flatId == null || flatId!.isEmpty;
  bool get isAssigned => flatId != null && flatId!.isNotEmpty;
}
