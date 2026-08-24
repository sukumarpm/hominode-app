import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Access Control Service - Validates user access to app features
/// Implements 5-step flow function pattern for access validation
class AccessControlService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Validate user access on login
  /// Returns true if user has valid building and flat assignment
  /// Returns false if user should be restricted
  Future<AccessValidationResult> validateUserAccess(String userId) async {
    try {
      print('🔵 ACCESS VALIDATION FLOW: Starting...');
      
      // STEP 1: Validate user authentication
      print('🔐 STEP 1: Validating user authentication...');
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        print('❌ STEP 1 FAILED: User not authenticated');
        return AccessValidationResult.failure('User not authenticated');
      }
      print('✅ STEP 1 PASSED: User authenticated - $userId');
      
      // STEP 2: Fetch and validate user document
      print('📋 STEP 2: Fetching user document...');
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        print('❌ STEP 2 FAILED: User document not found');
        return AccessValidationResult.failure('User document not found');
      }
      
      final userData = userDoc.data();
      if (userData == null) {
        print('❌ STEP 2 FAILED: User data is empty');
        return AccessValidationResult.failure('User data is empty');
      }
      
      final buildingId = userData['buildingId'] as String?;
      final flatId = userData['flatId'] as String?;
      final status = userData['status'] as String?;
      
      print('   - buildingId: $buildingId');
      print('   - flatId: $flatId');
      print('   - status: $status');
      print('✅ STEP 2 PASSED: User document fetched');
      
      // STEP 3: Validate building assignment
      print('📋 STEP 3: Validating building assignment...');
      if (buildingId == null || buildingId.isEmpty) {
        print('❌ STEP 3 FAILED: User not assigned to building');
        return AccessValidationResult.failure('User not assigned to building');
      }
      
      final buildingDoc = await _firestore.collection('buildings').doc(buildingId).get();
      if (!buildingDoc.exists) {
        print('❌ STEP 3 FAILED: Building document not found');
        return AccessValidationResult.failure('Building has been deleted');
      }
      print('✅ STEP 3 PASSED: Building exists and is valid');
      
      // STEP 4: Validate flat assignment
      print('📋 STEP 4: Validating flat assignment...');
      if (flatId == null || flatId.isEmpty) {
        print('❌ STEP 4 FAILED: User not assigned to flat');
        return AccessValidationResult.failure('User not assigned to flat');
      }
      
      final flatDoc = await _firestore.collection('flats').doc(flatId).get();
      if (!flatDoc.exists) {
        print('❌ STEP 4 FAILED: Flat document not found');
        return AccessValidationResult.failure('Flat has been deleted');
      }
      
      final flatData = flatDoc.data();
      if (flatData == null) {
        print('❌ STEP 4 FAILED: Flat data is empty');
        return AccessValidationResult.failure('Flat data is empty');
      }
      print('✅ STEP 4 PASSED: Flat exists and is valid');
      
      // STEP 5: Return success result
      print('✅ ACCESS VALIDATION FLOW: COMPLETE');
      print('   - User has valid access');
      print('   - Building: ${buildingDoc.data()?['name'] ?? 'Unknown'}');
      print('   - Flat: ${flatData['flatId'] ?? 'Unknown'}');
      
      return AccessValidationResult.success(
        userId: userId,
        buildingId: buildingId,
        flatId: flatId,
        buildingName: buildingDoc.data()?['name'] ?? '',
        flatLabel: flatData['flatId'] ?? '',
      );
    } catch (e) {
      print('❌ ERROR: $e');
      return AccessValidationResult.failure('Access validation failed: $e');
    }
  }

  /// Listen to real-time access changes
  /// Triggers callback if user loses building/flat access
  Stream<AccessValidationResult> listenToAccessChanges(String userId) {
    return _firestore.collection('users').doc(userId).snapshots().asyncMap((userDoc) async {
      if (!userDoc.exists) {
        print('⚠️  User document deleted - access revoked');
        return AccessValidationResult.failure('User document deleted');
      }

      final userData = userDoc.data();
      if (userData == null) {
        return AccessValidationResult.failure('User data is empty');
      }

      final buildingId = userData['buildingId'] as String?;
      final flatId = userData['flatId'] as String?;

      // Check if building still exists
      if (buildingId != null && buildingId.isNotEmpty) {
        final buildingDoc = await _firestore.collection('buildings').doc(buildingId).get();
        if (!buildingDoc.exists) {
          print('⚠️  Building deleted - access revoked');
          return AccessValidationResult.failure('Building has been deleted');
        }
      }

      // Check if flat still exists
      if (flatId != null && flatId.isNotEmpty) {
        final flatDoc = await _firestore.collection('flats').doc(flatId).get();
        if (!flatDoc.exists) {
          print('⚠️  Flat deleted - access revoked');
          return AccessValidationResult.failure('Flat has been deleted');
        }
      }

      // If both are missing, access is revoked
      if ((buildingId == null || buildingId.isEmpty) || (flatId == null || flatId.isEmpty)) {
        print('⚠️  User unassigned - access revoked');
        return AccessValidationResult.failure('User not assigned to building or flat');
      }

      return AccessValidationResult.success(
        userId: userId,
        buildingId: buildingId,
        flatId: flatId,
        buildingName: '',
        flatLabel: '',
      );
    });
  }
}

/// Result of access validation
class AccessValidationResult {
  final bool success;
  final String message;
  final String? userId;
  final String? buildingId;
  final String? flatId;
  final String? buildingName;
  final String? flatLabel;

  AccessValidationResult({
    required this.success,
    required this.message,
    this.userId,
    this.buildingId,
    this.flatId,
    this.buildingName,
    this.flatLabel,
  });

  factory AccessValidationResult.success({
    required String userId,
    required String buildingId,
    required String flatId,
    required String buildingName,
    required String flatLabel,
  }) {
    return AccessValidationResult(
      success: true,
      message: 'Access granted',
      userId: userId,
      buildingId: buildingId,
      flatId: flatId,
      buildingName: buildingName,
      flatLabel: flatLabel,
    );
  }

  factory AccessValidationResult.failure(String message) {
    return AccessValidationResult(
      success: false,
      message: message,
    );
  }
}
