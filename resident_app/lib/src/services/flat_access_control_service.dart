// lib/src/services/flat_access_control_service.dart
// Flat Access Control Service - Manages access based on flat assignment

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firestore_auth_service.dart';

/// Access Control Result
class AccessControlResult {
  final bool hasAccess;
  final String? flatId;
  final String? buildingId;
  final String? message;
  final Map<String, dynamic>? userData;

  AccessControlResult({
    required this.hasAccess,
    this.flatId,
    this.buildingId,
    this.message,
    this.userData,
  });

  factory AccessControlResult.granted({
    required String flatId,
    required String buildingId,
    required Map<String, dynamic> userData,
  }) {
    return AccessControlResult(
      hasAccess: true,
      flatId: flatId,
      buildingId: buildingId,
      userData: userData,
    );
  }

  factory AccessControlResult.denied({required String message}) {
    return AccessControlResult(
      hasAccess: false,
      message: message,
    );
  }
}

/// Flat Access Control Service
/// Validates user flat assignment and controls access to features
class FlatAccessControlService {
  // Singleton pattern
  static final FlatAccessControlService instance = FlatAccessControlService._internal();
  factory FlatAccessControlService() => instance;
  FlatAccessControlService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirestoreAuthService _authService = FirestoreAuthService();

  // Cache
  AccessControlResult? _cachedResult;
  String? _cachedUserId;

  /// Check if user has flat access
  /// Returns AccessControlResult with access status and user data
  Future<AccessControlResult> checkFlatAccess({bool forceRefresh = false}) async {
    try {
      print('🔐 Checking flat access...');

      // Get current user ID
      String? userId;
      
      // Try Firebase Auth first
      final firebaseUser = _auth.currentUser;
      if (firebaseUser != null) {
        print('📥 Using Firebase Auth UID: ${firebaseUser.uid}');
        
        // Try to find user document by Firebase Auth UID
        final doc = await _firestore.collection('users').doc(firebaseUser.uid).get();
        
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
      
      // Fallback to stored user ID
      if (userId == null) {
        userId = await _authService.getCurrentUserId();
        print('📥 Using stored user ID: $userId');
      }

      if (userId == null) {
        print('❌ No user logged in');
        return AccessControlResult.denied(
          message: 'Please log in to continue',
        );
      }

      // Return cached result if available and not forcing refresh
      if (!forceRefresh && _cachedUserId == userId && _cachedResult != null) {
        print('✅ Returning cached access result');
        return _cachedResult!;
      }

      print('📥 Fetching user data from Firestore...');
      print('   User ID: $userId');

      // Fetch user document
      final userDoc = await _firestore.collection('users').doc(userId).get();

      if (!userDoc.exists) {
        print('❌ User document not found');
        return AccessControlResult.denied(
          message: 'User account not found. Please contact support.',
        );
      }

      final userData = userDoc.data()!;
      print('✅ User data fetched');
      print('   Name: ${userData['name']}');
      print('   Email: ${userData['email']}');

      // Check flatId field - handle both String and dynamic types
      dynamic flatIdValue = userData['flatId'];
      String? flatId;
      
      if (flatIdValue != null) {
        flatId = flatIdValue.toString().trim();
        if (flatId.isEmpty) {
          flatId = null;
        }
      }
      
      // Check buildingId field - handle both String and dynamic types
      dynamic buildingIdValue = userData['buildingId'];
      String? buildingId;
      
      if (buildingIdValue != null) {
        buildingId = buildingIdValue.toString().trim();
        if (buildingId.isEmpty) {
          buildingId = null;
        }
      }

      print('   Flat ID: $flatId');
      print('   Building ID: $buildingId');
      print('   Flat ID type: ${flatId.runtimeType}');
      print('   Flat ID length: ${flatId?.length}');

      // Validate flat assignment
      if (flatId == null || flatId.isEmpty) {
        print('❌ No flat assigned to user');
        
        final result = AccessControlResult.denied(
          message: 'Your account is not yet assigned to a flat. Please contact admin.',
        );
        
        // Cache the result
        _cachedResult = result;
        _cachedUserId = userId;
        
        return result;
      }

      // Check if building ID is also present (optional but recommended)
      if (buildingId == null || buildingId.isEmpty) {
        print('⚠️  Warning: No building ID assigned');
      }

      print('✅ Flat access granted');
      print('   Flat: $flatId');
      print('   Building: $buildingId');

      final result = AccessControlResult.granted(
        flatId: flatId,
        buildingId: buildingId ?? '',
        userData: userData,
      );

      // Cache the result
      _cachedResult = result;
      _cachedUserId = userId;

      return result;
    } catch (e, stackTrace) {
      print('❌ Error checking flat access: $e');
      print('   Stack trace: $stackTrace');
      return AccessControlResult.denied(
        message: 'Error checking access. Please try again.',
      );
    }
  }

  /// Stream flat access status (real-time updates)
  Stream<AccessControlResult> streamFlatAccess() async* {
    try {
      // Get current user ID
      String? userId;
      
      print('🔵 streamFlatAccess: Starting access check...');
      
      final firebaseUser = _auth.currentUser;
      print('📥 Firebase Auth user: ${firebaseUser?.uid}');
      
      if (firebaseUser != null) {
        try {
          final doc = await _firestore.collection('users').doc(firebaseUser.uid).get();
          
          if (doc.exists) {
            userId = doc.id;
            print('✅ Found user by Firebase Auth UID: $userId');
          } else {
            print('🔍 User not found by Firebase Auth UID, searching by authUid field...');
            try {
              final querySnapshot = await _firestore
                  .collection('users')
                  .where('authUid', isEqualTo: firebaseUser.uid)
                  .limit(1)
                  .get();
              
              if (querySnapshot.docs.isNotEmpty) {
                userId = querySnapshot.docs.first.id;
                print('✅ Found user by authUid field: $userId');
              } else {
                print('❌ User not found by authUid field');
              }
            } catch (e) {
              print('⚠️  Error searching by authUid: $e');
            }
          }
        } catch (e) {
          print('⚠️  Error fetching user doc: $e');
        }
      }
      
      if (userId == null) {
        userId = await _authService.getCurrentUserId();
        print('📥 Using stored user ID: $userId');
      }

      if (userId == null) {
        print('❌ No user ID found');
        yield AccessControlResult.denied(
          message: 'Please log in to continue',
        );
        return;
      }

      // Stream user document changes
      yield* _firestore
          .collection('users')
          .doc(userId)
          .snapshots()
          .map((snapshot) {
            try {
              print('🔵 FlatAccessWrapper: Checking access for user: $userId');
              
              if (!snapshot.exists) {
                print('❌ User document not found');
                return AccessControlResult.denied(
                  message: 'User account not found. Please contact support.',
                );
              }

              final userData = snapshot.data();
              if (userData == null) {
                print('❌ User data is null');
                return AccessControlResult.denied(
                  message: 'User data not found. Please contact support.',
                );
              }
              
              print('📁 Raw user data: $userData');
              
              // Get flatId - handle both String and dynamic types
              dynamic flatIdValue = userData['flatId'];
              String? flatId;
              
              if (flatIdValue != null) {
                flatId = flatIdValue.toString().trim();
                if (flatId.isEmpty) {
                  flatId = null;
                }
              }
              
              // Get buildingId - handle both String and dynamic types
              dynamic buildingIdValue = userData['buildingId'];
              String? buildingId;
              
              if (buildingIdValue != null) {
                buildingId = buildingIdValue.toString().trim();
                if (buildingId.isEmpty) {
                  buildingId = null;
                }
              }

              print('📁 Parsed data: flatId=$flatId, buildingId=$buildingId');
              print('   flatId type: ${flatId.runtimeType}');
              print('   flatId length: ${flatId?.length}');

              if (flatId == null || flatId.isEmpty) {
                print('❌ No flatId found');
                final result = AccessControlResult.denied(
                  message: 'Your account is not yet assigned to a flat. Please contact admin.',
                );
                
                // Update cache
                _cachedResult = result;
                _cachedUserId = userId;
                
                return result;
              }

              print('✅ Access granted with flatId: $flatId');
              final result = AccessControlResult.granted(
                flatId: flatId,
                buildingId: buildingId ?? '',
                userData: userData,
              );

              // Update cache
              _cachedResult = result;
              _cachedUserId = userId;

              return result;
            } catch (e) {
              print('❌ Error in map: $e');
              return AccessControlResult.denied(
                message: 'Error processing user data. Please try again.',
              );
            }
          }).handleError((error) {
            print('❌ Stream error: $error');
          });
    } catch (e) {
      print('❌ Error streaming flat access: $e');
      yield AccessControlResult.denied(
        message: 'Error checking access. Please try again.',
      );
    }
  }

  /// Clear cached access result
  void clearCache() {
    _cachedResult = null;
    _cachedUserId = null;
    print('🗑️  Access control cache cleared');
  }

  /// Get cached flat ID (if available)
  String? getCachedFlatId() {
    return _cachedResult?.flatId;
  }

  /// Get cached building ID (if available)
  String? getCachedBuildingId() {
    return _cachedResult?.buildingId;
  }

  /// Check if user has access (cached)
  bool hasAccessCached() {
    return _cachedResult?.hasAccess ?? false;
  }
}
