// lib/src/services/visitor_firestore_service.dart
// Visitor Firestore Service - Save and manage visitor data

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Result class for visitor operations
class VisitorResult {
  final bool success;
  final String? message;
  final String? visitorId;
  final String? errorCode;

  VisitorResult({
    required this.success,
    this.message,
    this.visitorId,
    this.errorCode,
  });

  factory VisitorResult.success({String? message, String? visitorId}) {
    return VisitorResult(
      success: true,
      message: message ?? 'Operation successful',
      visitorId: visitorId,
    );
  }

  factory VisitorResult.failure({required String message, String? errorCode}) {
    return VisitorResult(
      success: false,
      message: message,
      errorCode: errorCode,
    );
  }
}

/// Visitor Firestore Service
class VisitorFirestoreService {
  // Singleton pattern
  static final VisitorFirestoreService instance =
      VisitorFirestoreService._internal();
  factory VisitorFirestoreService() => instance;
  VisitorFirestoreService._internal({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    Future<Map<String, dynamic>> Function(Map<String, dynamic>)?
    createInvitation,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance,
       _createInvitationOverride = createInvitation;

  @visibleForTesting
  VisitorFirestoreService.withDependencies({
    required FirebaseFirestore firestore,
    required FirebaseAuth auth,
    Future<Map<String, dynamic>> Function(Map<String, dynamic>)?
    createInvitation,
  }) : _firestore = firestore,
       _auth = auth,
       _createInvitationOverride = createInvitation;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final Future<Map<String, dynamic>> Function(Map<String, dynamic>)?
  _createInvitationOverride;

  // Collection name
  static const String visitorsCollection = 'visitors';
  FirebaseFunctions? _functions;
  FirebaseFunctions get _visitorFunctions =>
      _functions ??= FirebaseFunctions.instanceFor(region: 'asia-southeast1');

  // ============================================================================
  // ADD EXPECTED VISITOR
  // ============================================================================

  /// Add expected visitor to Firestore
  Future<VisitorResult> addExpectedVisitor({
    required String visitorName,
    required String purpose,
    required DateTime expectedDate,
    required DateTime expectedTime,
    String? phoneNumber,
    String? vehicleNumber,
  }) async {
    try {
      print('🔵 Adding expected visitor...');
      print('👤 Visitor Name: $visitorName');
      print('📝 Purpose: $purpose');
      print('📅 Expected Date: $expectedDate');
      print('⏰ Expected Time: $expectedTime');

      // Get user ID using the same logic as UserDataService
      String? userId;

      // First try Firebase Auth
      final firebaseUser = _auth.currentUser;
      if (firebaseUser != null) {
        print('🆔 Firebase Auth User: ${firebaseUser.uid}');

        // Try to find user document by Firebase Auth UID
        final doc = await _firestore
            .collection('users')
            .doc(firebaseUser.uid)
            .get();

        if (doc.exists) {
          userId = doc.id;
          print('✅ Found user document by Firebase Auth UID');
        } else {
          // Try to find by authUid field
          print('🔍 Searching by authUid field...');
          final querySnapshot = await _firestore
              .collection('users')
              .where('authUid', isEqualTo: firebaseUser.uid)
              .limit(1)
              .get();

          if (querySnapshot.docs.isNotEmpty) {
            userId = querySnapshot.docs.first.id;
            print('✅ Found user document by authUid field');
          }
        }
      }

      // Fallback to SharedPreferences
      if (userId == null) {
        print('⚠️  No Firebase Auth user, checking SharedPreferences...');
        final prefs = await SharedPreferences.getInstance();
        userId = prefs.getString('user_id');

        if (userId == null) {
          print('❌ No user ID found');
          return VisitorResult.failure(
            message: 'Please log in to add visitors',
            errorCode: 'not-authenticated',
          );
        }

        print('🆔 Using stored User ID: $userId');
      }

      // Fetch user data from Firestore
      print('📥 Fetching user data from Firestore...');
      final userDoc = await _firestore.collection('users').doc(userId).get();

      if (!userDoc.exists) {
        print('❌ User document not found in Firestore');
        print('   User ID: $userId');
        print('   Please ensure user document exists in Firestore');
        return VisitorResult.failure(
          message: 'User profile not found. Please contact support.',
          errorCode: 'user-not-found',
        );
      }

      final userData = userDoc.data();
      final userName =
          userData?['name'] ?? firebaseUser?.displayName ?? 'Unknown User';
      final userEmail = userData?['email'] ?? firebaseUser?.email ?? '';
      final flatId = userData?['flatId'] ?? '';
      final flatLabel = userData?['flatLabel'] ?? userData?['flatId'] ?? '';
      final adminId = userData?['adminId'];
      final communityId = userData?['communityId']?.toString().trim() ?? '';
      if (communityId.isEmpty) {
        return VisitorResult.failure(
          message: 'Your resident account is not assigned to a community.',
          errorCode: 'community-not-assigned',
        );
      }

      print('✅ User data fetched: $userName ($userEmail)');
      print('🏢 Flat ID: $flatId');
      print('🏢 Flat Label: $flatLabel');
      print('👤 Admin ID: $adminId');

      // Combine date and time
      // Combine date and time
      final expectedArrival = DateTime(
        expectedDate.year,
        expectedDate.month,
        expectedDate.day,
        expectedTime.hour,
        expectedTime.minute,
      );

      final request = {
        'visitorName': visitorName,
        'purpose': purpose,
        'expectedArrival': expectedArrival.millisecondsSinceEpoch,
        'phoneNumber': phoneNumber,
        'vehicleNumber': vehicleNumber,
      };
      final response = _createInvitationOverride != null
          ? await _createInvitationOverride(request)
          : (await _visitorFunctions
                    .httpsCallable('createVisitorInvitation')
                    .call<Map<String, dynamic>>(request))
                .data;
      final visitorId = response['visitorId'] as String?;
      if (visitorId == null || visitorId.isEmpty) {
        throw StateError('Visitor invitation response was incomplete.');
      }

      return VisitorResult.success(
        message: 'Visitor added successfully',
        visitorId: visitorId,
      );
    } on FirebaseException catch (e) {
      print('❌ Firebase Error: ${e.code}');
      print('❌ Message: ${e.message}');
      return VisitorResult.failure(
        message: _getErrorMessage(e.code),
        errorCode: e.code,
      );
    } catch (e) {
      print('❌ Unexpected Error: $e');
      return VisitorResult.failure(
        message: 'Failed to add visitor. Please try again.',
      );
    }
  }

  Future<String> _requireResidentCommunityId() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw StateError('Resident is not authenticated.');
    }

    final userDoc = await _firestore.collection('users').doc(user.uid).get();

    if (!userDoc.exists || userDoc.data() == null) {
      throw StateError('Resident profile not found.');
    }

    final data = userDoc.data()!;

    if (data['role'] != 'resident') {
      throw StateError('Invalid resident role.');
    }

    if (data['isActive'] != true || data['approvalStatus'] != 'approved') {
      throw StateError('Resident profile is not approved.');
    }

    final communityId = data['communityId'];

    if (communityId is! String || communityId.trim().isEmpty) {
      throw StateError('Resident community is not assigned.');
    }

    return communityId.trim();
  }

  // ============================================================================
  // GET VISITORS
  // ============================================================================

  /// Get all visitors for current user
  Future<List<Map<String, dynamic>>> getMyVisitors() async {
    try {
      // Try to get user ID from Firebase Auth first
      String? userId;

      final firebaseUser = _auth.currentUser;
      if (firebaseUser != null) {
        userId = firebaseUser.uid;
        print('🆔 Using Firebase Auth User ID: $userId');
      } else {
        // Fallback to Firestore-only authentication
        final prefs = await SharedPreferences.getInstance();
        userId = prefs.getString('user_id');

        if (userId == null) {
          print('❌ No user ID found');
          return [];
        }

        print('🆔 Using Firestore User ID: $userId');
      }
      final communityId = await _requireResidentCommunityId();
      final snapshot = await _firestore
          .collection(visitorsCollection)
          .where('communityId', isEqualTo: communityId)
          .where('hostUserId', isEqualTo: userId)
          .get();

      final visitors = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      // Sort in memory
      visitors.sort((a, b) {
        final aTime = (a['expectedArrival'] as Timestamp?)?.toDate();
        final bTime = (b['expectedArrival'] as Timestamp?)?.toDate();
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return bTime.compareTo(aTime);
      });

      return visitors;
    } catch (e) {
      print('❌ Error fetching visitors: $e');
      return [];
    }
  }

  /// Get all visitors for admin (by adminId)
  /// Admin can see all visitors for flats they manage
  Future<List<Map<String, dynamic>>> getAdminVisitors() async {
    try {
      // Try to get user ID from Firebase Auth first
      String? userId;

      final firebaseUser = _auth.currentUser;
      if (firebaseUser != null) {
        userId = firebaseUser.uid;
        print('🆔 Using Firebase Auth User ID: $userId');
      } else {
        // Fallback to Firestore-only authentication
        final prefs = await SharedPreferences.getInstance();
        userId = prefs.getString('user_id');

        if (userId == null) {
          print('❌ No user ID found');
          return [];
        }

        print('🆔 Using Firestore User ID: $userId');
      }

      // Check if user is admin
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        print('❌ User document not found');
        return [];
      }

      final userData = userDoc.data();
      final userRole = userData?['role'] ?? 'resident';

      if (userRole != 'admin') {
        print('⚠️  User is not an admin, returning personal visitors only');
        return await getMyVisitors();
      }

      print('✅ User is admin, fetching all visitors for this admin');

      // Query visitors where adminId matches current user
      final snapshot = await _firestore
          .collection(visitorsCollection)
          .where('adminId', isEqualTo: userId)
          .get();

      final visitors = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      // Sort in memory
      visitors.sort((a, b) {
        final aTime = (a['expectedArrival'] as Timestamp?)?.toDate();
        final bTime = (b['expectedArrival'] as Timestamp?)?.toDate();
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return bTime.compareTo(aTime);
      });

      print('✅ Found ${visitors.length} visitors for admin');

      return visitors;
    } catch (e) {
      print('❌ Error fetching admin visitors: $e');
      return [];
    }
  }

  /// Get visitors by flat ID
  /// Useful for admin to see visitors for a specific flat
  Future<List<Map<String, dynamic>>> getVisitorsByFlatId(String flatId) async {
    try {
      print('🔵 Fetching visitors for flat: $flatId');

      final snapshot = await _firestore
          .collection(visitorsCollection)
          .where('flatId', isEqualTo: flatId)
          .get();

      final visitors = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      // Sort in memory
      visitors.sort((a, b) {
        final aTime = (a['expectedArrival'] as Timestamp?)?.toDate();
        final bTime = (b['expectedArrival'] as Timestamp?)?.toDate();
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return bTime.compareTo(aTime);
      });

      print('✅ Found ${visitors.length} visitors for flat $flatId');

      return visitors;
    } catch (e) {
      print('❌ Error fetching visitors by flat: $e');
      return [];
    }
  }

  /// Get visitors based on user role
  /// Automatically determines if user is admin or resident and returns appropriate data
  Future<List<Map<String, dynamic>>> getVisitorsForCurrentUser() async {
    try {
      // Try to get user ID from Firebase Auth first
      String? userId;

      final firebaseUser = _auth.currentUser;
      if (firebaseUser != null) {
        userId = firebaseUser.uid;
      } else {
        // Fallback to Firestore-only authentication
        final prefs = await SharedPreferences.getInstance();
        userId = prefs.getString('user_id');

        if (userId == null) {
          print('❌ No user ID found');
          return [];
        }
      }

      // Check user role
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        print('❌ User document not found');
        return [];
      }

      final userData = userDoc.data();
      final userRole = userData?['role'] ?? 'resident';

      if (userRole == 'admin') {
        print('👤 User is admin, fetching admin visitors');
        return await getAdminVisitors();
      } else {
        print('👤 User is resident, fetching personal visitors');
        return await getMyVisitors();
      }
    } catch (e) {
      print('❌ Error fetching visitors for current user: $e');
      return [];
    }
  }

  /// Get expected visitors (not yet arrived)
  Future<List<Map<String, dynamic>>> getExpectedVisitors() async {
    try {
      // Try to get user ID from Firebase Auth first
      String? userId;

      final firebaseUser = _auth.currentUser;
      if (firebaseUser != null) {
        userId = firebaseUser.uid;
        print('🆔 Using Firebase Auth User ID: $userId');
      } else {
        // Fallback to Firestore-only authentication
        final prefs = await SharedPreferences.getInstance();
        userId = prefs.getString('user_id');

        if (userId == null) {
          print('❌ No user ID found');
          return [];
        }

        print('🆔 Using Firestore User ID: $userId');
      }
      final communityId = await _requireResidentCommunityId();

      final snapshot = await _firestore
          .collection(visitorsCollection)
          .where('communityId', isEqualTo: communityId)
          .where('hostUserId', isEqualTo: userId)
          .where('status', isEqualTo: 'expected')
          .get();

      final visitors = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      // Sort in memory
      visitors.sort((a, b) {
        final aTime = (a['expectedArrival'] as Timestamp?)?.toDate();
        final bTime = (b['expectedArrival'] as Timestamp?)?.toDate();
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return aTime.compareTo(bTime); // Ascending order (earliest first)
      });

      return visitors;
    } catch (e) {
      print('❌ Error fetching expected visitors: $e');
      return [];
    }
  }

  /// Stream visitors (real-time updates)
  Stream<List<Map<String, dynamic>>> streamMyVisitors() async* {
    String? userId;

    final firebaseUser = _auth.currentUser;

    if (firebaseUser != null) {
      userId = firebaseUser.uid;
      print('🆔 Firebase Auth User for stream: $userId');
    } else {
      final prefs = await SharedPreferences.getInstance();
      userId = prefs.getString('user_id');

      if (userId == null) {
        print('❌ No user ID found for stream');
        yield [];
        return;
      }
    }

    print('📡 Streaming visitors for user: $userId');
    final communityId = await _requireResidentCommunityId();

    yield* _firestore
        .collection(visitorsCollection)
        .where('communityId', isEqualTo: communityId)
        .where('hostUserId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
          final visitors = snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return data;
          }).toList();

          visitors.sort((a, b) {
            final aTime = (a['expectedArrival'] as Timestamp?)?.toDate();
            final bTime = (b['expectedArrival'] as Timestamp?)?.toDate();

            if (aTime == null && bTime == null) return 0;
            if (aTime == null) return 1;
            if (bTime == null) return -1;

            return bTime.compareTo(aTime);
          });

          print('✅ Streamed ${visitors.length} visitors');
          return visitors;
        });
  }

  /// Stream admin visitors (real-time updates for admin)
  Stream<List<Map<String, dynamic>>> streamAdminVisitors() async* {
    // Get user ID using the same logic as UserDataService
    String? userId;

    // First try Firebase Auth
    final firebaseUser = _auth.currentUser;
    if (firebaseUser != null) {
      print('🆔 Firebase Auth User for admin stream: ${firebaseUser.uid}');

      // Try to find user document by Firebase Auth UID
      final doc = await _firestore
          .collection('users')
          .doc(firebaseUser.uid)
          .get();

      if (doc.exists) {
        userId = doc.id;
        print('✅ Found user document by Firebase Auth UID for admin stream');
      } else {
        // Try to find by authUid field
        print('🔍 Searching by authUid field for admin stream...');
        final querySnapshot = await _firestore
            .collection('users')
            .where('authUid', isEqualTo: firebaseUser.uid)
            .limit(1)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          userId = querySnapshot.docs.first.id;
          print('✅ Found user document by authUid field for admin stream');
        }
      }
    }

    // Fallback to SharedPreferences
    if (userId == null) {
      print(
        '⚠️  No Firebase Auth user, checking SharedPreferences for admin stream...',
      );
      final prefs = await SharedPreferences.getInstance();
      userId = prefs.getString('user_id');

      if (userId == null) {
        print('❌ No user ID found for admin stream');
        yield [];
        return;
      }

      print('🆔 Using stored User ID for admin stream: $userId');
    }

    // Check if user is admin
    final userDoc = await _firestore.collection('users').doc(userId).get();
    if (!userDoc.exists) {
      print('❌ User document not found for admin stream');
      print('   User ID: $userId');
      yield [];
      return;
    }

    final userData = userDoc.data();
    final userRole = userData?['role'] ?? 'resident';

    if (userRole != 'admin') {
      print('⚠️  User is not an admin, returning personal visitors stream');
      yield* streamMyVisitors();
      return;
    }

    print('✅ User is admin, streaming all visitors for this admin');

    yield* _firestore
        .collection(visitorsCollection)
        .where('adminId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
          final visitors = snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return data;
          }).toList();

          // Sort in memory
          visitors.sort((a, b) {
            final aTime = (a['expectedArrival'] as Timestamp?)?.toDate();
            final bTime = (b['expectedArrival'] as Timestamp?)?.toDate();
            if (aTime == null && bTime == null) return 0;
            if (aTime == null) return 1;
            if (bTime == null) return -1;
            return bTime.compareTo(aTime);
          });

          return visitors;
        });
  }

  /// Stream visitors based on user role
  Stream<List<Map<String, dynamic>>> streamVisitorsForCurrentUser() async* {
    // Try to get user ID from Firebase Auth first
    String? userId;

    final firebaseUser = _auth.currentUser;
    if (firebaseUser != null) {
      userId = firebaseUser.uid;
    } else {
      // Fallback to Firestore-only authentication
      final prefs = await SharedPreferences.getInstance();
      userId = prefs.getString('user_id');

      if (userId == null) {
        print('❌ No user ID found');
        yield [];
        return;
      }
    }

    // Check user role
    final userDoc = await _firestore.collection('users').doc(userId).get();
    if (!userDoc.exists) {
      print('❌ User document not found');
      yield [];
      return;
    }

    final userData = userDoc.data();
    final userRole = userData?['role'] ?? 'resident';

    if (userRole == 'admin') {
      print('👤 User is admin, streaming admin visitors');
      yield* streamAdminVisitors();
    } else {
      print('👤 User is resident, streaming personal visitors');
      yield* streamMyVisitors();
    }
  }

  // ============================================================================
  // UPDATE VISITOR
  // ============================================================================

  /// Update visitor status
  Future<VisitorResult> updateVisitorStatus({
    required String visitorId,
    required String status,
  }) async {
    try {
      await _firestore.collection(visitorsCollection).doc(visitorId).update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return VisitorResult.success(message: 'Visitor status updated');
    } catch (e) {
      return VisitorResult.failure(message: 'Failed to update visitor status');
    }
  }

  /// Approve visitor
  Future<VisitorResult> approveVisitor(String visitorId) async {
    try {
      // Try to get user ID from Firebase Auth first
      String? userId;

      final firebaseUser = _auth.currentUser;
      if (firebaseUser != null) {
        userId = firebaseUser.uid;
      } else {
        // Fallback to Firestore-only authentication
        final prefs = await SharedPreferences.getInstance();
        userId = prefs.getString('user_id');
      }

      if (userId == null) {
        return VisitorResult.failure(message: 'Not authenticated');
      }

      await _firestore.collection(visitorsCollection).doc(visitorId).update({
        'isApproved': true,
        'approvedBy': userId,
        'approvedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return VisitorResult.success(message: 'Visitor approved');
    } catch (e) {
      return VisitorResult.failure(message: 'Failed to approve visitor');
    }
  }

  /// Mark visitor as arrived
  Future<VisitorResult> markVisitorArrived(String visitorId) async {
    try {
      await _firestore.collection(visitorsCollection).doc(visitorId).update({
        'status': 'arrived',
        'actualArrival': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return VisitorResult.success(message: 'Visitor marked as arrived');
    } catch (e) {
      return VisitorResult.failure(message: 'Failed to update visitor');
    }
  }

  /// Mark visitor as departed/exited
  Future<VisitorResult> markVisitorDeparted(String visitorId) async {
    try {
      print('🔵 Marking visitor as departed: $visitorId');

      await _firestore.collection(visitorsCollection).doc(visitorId).update({
        'status': 'departed',
        'departure': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('✅ Visitor marked as departed');

      return VisitorResult.success(message: 'Visitor marked as departed');
    } catch (e) {
      print('❌ Error marking visitor as departed: $e');
      return VisitorResult.failure(message: 'Failed to update visitor');
    }
  }

  // ============================================================================
  // DELETE VISITOR
  // ============================================================================

  /// Delete/Cancel visitor
  Future<VisitorResult> deleteVisitor(String visitorId) async {
    try {
      await _firestore.collection(visitorsCollection).doc(visitorId).delete();

      return VisitorResult.success(message: 'Visitor deleted');
    } catch (e) {
      return VisitorResult.failure(message: 'Failed to delete visitor');
    }
  }

  // ============================================================================
  // ERROR MESSAGES
  // ============================================================================

  String _getErrorMessage(String errorCode) {
    switch (errorCode) {
      case 'permission-denied':
        return 'Permission denied. Please check your access rights.';
      case 'unavailable':
        return 'Service temporarily unavailable. Please try again.';
      case 'not-found':
        return 'Visitor not found.';
      case 'already-exists':
        return 'Visitor already exists.';
      default:
        return 'An error occurred. Please try again.';
    }
  }
}
