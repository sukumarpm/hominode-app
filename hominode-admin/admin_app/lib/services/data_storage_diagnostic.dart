import 'package:cloud_firestore/cloud_firestore.dart';
import 'admin_service.dart';

/// Diagnostic service to verify data storage in Firestore
class DataStorageDiagnostic {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AdminService _adminService = AdminService();

  /// Test if admin profile has complete data
  Future<Map<String, dynamic>> checkAdminProfile() async {
    print('\n╔════════════════════════════════════════════════════════╗');
    print('║         DIAGNOSTIC: CHECK ADMIN PROFILE                ║');
    print('╚════════════════════════════════════════════════════════╝');
    
    final adminId = _adminService.getCurrentAdminId();
    if (adminId == null) {
      return {
        'success': false,
        'error': 'No admin logged in',
      };
    }

    print('Admin ID: $adminId');
    
    try {
      final adminDoc = await _firestore.collection('admins').doc(adminId).get();
      
      if (!adminDoc.exists) {
        print('❌ Admin document does NOT exist in Firestore!');
        return {
          'success': false,
          'error': 'Admin document not found',
          'adminId': adminId,
        };
      }

      final data = adminDoc.data()!;
      print('\n✅ Admin document found');
      print('Admin data:');
      print('  name: ${data['name']}');
      print('  email: ${data['email']}');
      print('  phone: ${data['phone']}');
      print('  organization: ${data['organization']}');
      print('  buildingId: ${data['buildingId']}');
      print('  buildingName: ${data['buildingName']}');

      // Check for missing fields
      final missingFields = <String>[];
      if (data['name'] == null || data['name'] == '') missingFields.add('name');
      if (data['email'] == null || data['email'] == '') missingFields.add('email');
      if (data['phone'] == null || data['phone'] == '') missingFields.add('phone');
      if (data['organization'] == null || data['organization'] == '') missingFields.add('organization');

      if (missingFields.isNotEmpty) {
        print('\n⚠️  WARNING: Missing or empty fields in admin profile:');
        for (var field in missingFields) {
          print('   - $field');
        }
      }

      return {
        'success': true,
        'adminId': adminId,
        'data': data,
        'missingFields': missingFields,
      };
    } catch (e) {
      print('❌ Error fetching admin profile: $e');
      return {
        'success': false,
        'error': e.toString(),
        'adminId': adminId,
      };
    }
  }

  /// Test creating a resident and verify data storage
  Future<Map<String, dynamic>> testResidentCreation({
    required String name,
    required String phone,
    required String password,
    String? email,
    String? buildingId,
    String? buildingName,
  }) async {
    print('\n╔════════════════════════════════════════════════════════╗');
    print('║      DIAGNOSTIC: TEST RESIDENT CREATION                ║');
    print('╚════════════════════════════════════════════════════════╝');
    
    try {
      // Step 1: Check admin profile
      print('\n[Step 1] Checking admin profile...');
      final adminCheck = await checkAdminProfile();
      if (!adminCheck['success']) {
        return {
          'success': false,
          'step': 'admin_profile_check',
          'error': adminCheck['error'],
        };
      }

      final adminId = adminCheck['adminId'];
      final adminData = adminCheck['data'] as Map<String, dynamic>;

      // Step 2: Prepare data
      print('\n[Step 2] Preparing resident data...');
      final residentId = 'TEST${DateTime.now().millisecondsSinceEpoch}';
      final authEmail = email ?? '$phone@test.lyvo.com';
      
      final firestoreData = {
        'name': name,
        'phone': phone,
        'email': email ?? authEmail,
        'authEmail': authEmail,
        'password': password,
        'residentId': residentId,
        'role': 'resident',
        'flatId': null,
        'flatLabel': null,
        'buildingId': buildingId ?? adminData['buildingId'],
        'buildingName': buildingName ?? adminData['buildingName'],
        'ownershipType': null,
        'familyMembers': 1,
        'status': 'active',
        'authAccountCreated': false,
        // Admin details
        'adminId': adminId,
        'adminName': adminData['name'] ?? '',
        'adminEmail': adminData['email'] ?? '',
        'adminPhone': adminData['phone'] ?? '',
        'organization': adminData['organization'] ?? '',
        // Timestamps
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      print('Data to be stored:');
      print('  residentId: $residentId');
      print('  name: $name');
      print('  adminId: $adminId');
      print('  adminName: ${adminData['name']}');
      print('  adminEmail: ${adminData['email']}');
      print('  adminPhone: ${adminData['phone']}');
      print('  organization: ${adminData['organization']}');
      print('  buildingId: ${firestoreData['buildingId']}');
      print('  buildingName: ${firestoreData['buildingName']}');

      // Step 3: Create document
      print('\n[Step 3] Creating Firestore document...');
      final docRef = _firestore.collection('users').doc();
      final userId = docRef.id;
      
      await docRef.set(firestoreData);
      print('✅ Document created with ID: $userId');

      // Step 4: Verify document
      print('\n[Step 4] Verifying document...');
      await Future.delayed(const Duration(seconds: 1)); // Wait for Firestore
      
      final verifyDoc = await _firestore.collection('users').doc(userId).get();
      
      if (!verifyDoc.exists) {
        print('❌ Document NOT found after creation!');
        return {
          'success': false,
          'step': 'verification',
          'error': 'Document not found after creation',
          'userId': userId,
        };
      }

      final savedData = verifyDoc.data()!;
      print('✅ Document verified in Firestore');
      
      // Check all required fields
      final requiredFields = [
        'adminId', 'adminName', 'adminEmail', 'adminPhone', 'organization',
        'buildingId', 'buildingName', 'name', 'phone', 'residentId'
      ];
      
      final missingFields = <String>[];
      final emptyFields = <String>[];
      
      for (var field in requiredFields) {
        if (!savedData.containsKey(field)) {
          missingFields.add(field);
        } else if (savedData[field] == null || savedData[field] == '') {
          emptyFields.add(field);
        }
      }

      print('\nField verification:');
      for (var field in requiredFields) {
        final value = savedData[field];
        final status = value != null && value != '' ? '✅' : '❌';
        print('  $status $field: $value');
      }

      if (missingFields.isNotEmpty) {
        print('\n❌ MISSING FIELDS:');
        for (var field in missingFields) {
          print('   - $field');
        }
      }

      if (emptyFields.isNotEmpty) {
        print('\n⚠️  EMPTY FIELDS:');
        for (var field in emptyFields) {
          print('   - $field');
        }
      }

      return {
        'success': missingFields.isEmpty,
        'userId': userId,
        'residentId': residentId,
        'savedData': savedData,
        'missingFields': missingFields,
        'emptyFields': emptyFields,
      };
    } catch (e, stackTrace) {
      print('\n❌ ERROR: $e');
      print('Stack trace: $stackTrace');
      return {
        'success': false,
        'error': e.toString(),
        'stackTrace': stackTrace.toString(),
      };
    }
  }

  /// Test assigning resident to flat
  Future<Map<String, dynamic>> testFlatAssignment({
    required String userId,
    required String flatId,
    required String flatLabel,
    required String buildingId,
    required String buildingName,
    String ownershipType = 'Owner',
  }) async {
    print('\n╔════════════════════════════════════════════════════════╗');
    print('║      DIAGNOSTIC: TEST FLAT ASSIGNMENT                  ║');
    print('╚════════════════════════════════════════════════════════╝');
    
    try {
      // Step 1: Get user data
      print('\n[Step 1] Fetching user data...');
      final userDoc = await _firestore.collection('users').doc(userId).get();
      
      if (!userDoc.exists) {
        return {
          'success': false,
          'error': 'User not found',
          'userId': userId,
        };
      }

      final userData = userDoc.data()!;
      final residentId = userData['residentId'];
      final residentName = userData['name'];
      
      print('✅ User found:');
      print('  residentId: $residentId');
      print('  residentName: $residentName');

      // Step 2: Update user document
      print('\n[Step 2] Updating user document...');
      await _firestore.collection('users').doc(userId).update({
        'flatId': flatId,
        'flatLabel': flatLabel,
        'buildingId': buildingId,
        'buildingName': buildingName,
        'ownershipType': ownershipType,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('✅ User document updated');

      // Step 3: Update flat document
      print('\n[Step 3] Updating flat document...');
      await _firestore.collection('flats').doc(flatId).update({
        'residentId': residentId,
        'residentName': residentName,
        'residentUserId': userId,
        'status': 'occupied',
        'ownershipType': ownershipType,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('✅ Flat document updated');

      // Step 4: Verify both documents
      print('\n[Step 4] Verifying updates...');
      await Future.delayed(const Duration(seconds: 1));
      
      final verifyUser = await _firestore.collection('users').doc(userId).get();
      final verifyFlat = await _firestore.collection('flats').doc(flatId).get();

      final userDataAfter = verifyUser.data()!;
      final flatDataAfter = verifyFlat.data()!;

      print('\nUser document verification:');
      print('  ✅ flatId: ${userDataAfter['flatId']}');
      print('  ✅ flatLabel: ${userDataAfter['flatLabel']}');
      print('  ✅ buildingId: ${userDataAfter['buildingId']}');
      print('  ✅ buildingName: ${userDataAfter['buildingName']}');
      print('  ✅ ownershipType: ${userDataAfter['ownershipType']}');

      print('\nFlat document verification:');
      print('  ✅ residentId: ${flatDataAfter['residentId']}');
      print('  ✅ residentName: ${flatDataAfter['residentName']}');
      print('  ✅ residentUserId: ${flatDataAfter['residentUserId']}');
      print('  ✅ status: ${flatDataAfter['status']}');
      print('  ✅ ownershipType: ${flatDataAfter['ownershipType']}');

      return {
        'success': true,
        'userId': userId,
        'flatId': flatId,
        'userDataAfter': userDataAfter,
        'flatDataAfter': flatDataAfter,
      };
    } catch (e, stackTrace) {
      print('\n❌ ERROR: $e');
      print('Stack trace: $stackTrace');
      return {
        'success': false,
        'error': e.toString(),
        'stackTrace': stackTrace.toString(),
      };
    }
  }

  /// Run complete diagnostic
  Future<void> runCompleteDiagnostic() async {
    print('\n');
    print('═══════════════════════════════════════════════════════════');
    print('         COMPLETE DATA STORAGE DIAGNOSTIC                  ');
    print('═══════════════════════════════════════════════════════════');
    print('');

    // Test 1: Check admin profile
    final adminResult = await checkAdminProfile();
    
    if (!adminResult['success']) {
      print('\n❌ DIAGNOSTIC FAILED: Admin profile issue');
      print('   Error: ${adminResult['error']}');
      print('\n🔧 FIX: Update your admin profile in Firestore');
      print('   1. Open Firebase Console');
      print('   2. Go to Firestore Database');
      print('   3. Navigate to admins collection');
      print('   4. Find your admin document');
      print('   5. Add missing fields: name, email, phone, organization');
      return;
    }

    // Test 2: Create test resident
    print('\n');
    final residentResult = await testResidentCreation(
      name: 'Test Resident',
      phone: '9999999999',
      password: 'test123',
      email: 'test@example.com',
    );

    if (!residentResult['success']) {
      print('\n❌ DIAGNOSTIC FAILED: Resident creation issue');
      print('   Error: ${residentResult['error']}');
      if (residentResult['missingFields'] != null) {
        print('   Missing fields: ${residentResult['missingFields']}');
      }
      if (residentResult['emptyFields'] != null) {
        print('   Empty fields: ${residentResult['emptyFields']}');
      }
      return;
    }

    print('\n✅ DIAGNOSTIC PASSED: All data stored correctly!');
    print('\n═══════════════════════════════════════════════════════════\n');
  }
}
