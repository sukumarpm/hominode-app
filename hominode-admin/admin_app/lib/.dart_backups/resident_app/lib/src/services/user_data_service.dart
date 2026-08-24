// lib/src/services/user_data_service.dart
// User Data Service - Fetches and manages user data from Firestore

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firestore_auth_service.dart';

/// User Data Service
/// Handles fetching and caching user data from Firestore
class UserDataService {
  // Singleton pattern
  static final UserDataService instance = UserDataService._internal();
  factory UserDataService() => instance;
  UserDataService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirestoreAuthService _authService = FirestoreAuthService();
  
  // Cache user data
  Map<String, dynamic>? _cachedUserData;
  String? _cachedUserId;

  /// Get current user data
  /// Returns cached data if available, otherwise fetches from Firestore
  /// Follows the standardized flow function pattern
  Future<Map<String, dynamic>?> getCurrentUserData({bool forceRefresh = false}) async {
    try {
      print('🔵 USER DATA FETCH FLOW: Starting...');
      
      // STEP 1: Validate Authentication
      print('🔐 STEP 1: Validating user authentication...');
      final firebaseUser = _auth.currentUser;
      
      if (firebaseUser == null) {
        print('❌ STEP 1 FAILED: No user logged in - Firebase Auth user is null');
        return null;
      }
      
      print('✅ STEP 1 PASSED: User authenticated');
      print('   Firebase Auth UID: ${firebaseUser.uid}');
      
      // STEP 2: Check Cache
      print('💾 STEP 2: Checking cache...');
      if (!forceRefresh && _cachedUserId == firebaseUser.uid && _cachedUserData != null) {
        print('✅ STEP 2 PASSED: Returning cached user data');
        return _cachedUserData;
      }
      print('✅ STEP 2 PASSED: Cache miss or refresh requested');

      // STEP 3: Fetch from Firestore
      print('📥 STEP 3: Fetching user data from Firestore...');
      print('   Collection: users');
      print('   Document ID: ${firebaseUser.uid}');

      final doc = await _firestore.collection('users').doc(firebaseUser.uid).get();

      if (!doc.exists) {
        print('❌ STEP 3 FAILED: User document not found');
        print('');
        print('🔧 SOLUTION: Create user document in Firebase Console');
        print('   1. Go to Firebase Console → Firestore Database');
        print('   2. Open "users" collection');
        print('   3. Create document with ID: ${firebaseUser.uid}');
        print('   4. Add these fields:');
        print('      - id: "${firebaseUser.uid}"');
        print('      - authUid: "${firebaseUser.uid}"');
        print('      - email: "${firebaseUser.email}"');
        print('      - name: "Your Name"');
        print('      - phone: "+1234567890"');
        print('      - buildingId: "building1"');
        print('      - flatId: "flat101"');
        print('      - flatLabel: "A-101"');
        print('      - role: "resident"');
        print('');
        return null;
      }

      final userData = doc.data();
      
      if (userData == null) {
        print('❌ STEP 3 FAILED: User document exists but has no data');
        return null;
      }
      
      print('✅ STEP 3 PASSED: Document fetched from Firestore');
      
      // STEP 4: Validate and Enrich Data
      print('📋 STEP 4: Validating and enriching user data...');
      
      // Add document ID to the data
      userData['id'] = doc.id;
      
      // Validate required fields
      final missingFields = <String>[];
      if (userData['buildingId'] == null) missingFields.add('buildingId');
      if (userData['flatId'] == null) missingFields.add('flatId');
      if (userData['role'] == null) missingFields.add('role');
      
      if (missingFields.isNotEmpty) {
        print('⚠️  WARNING: User document missing required fields: ${missingFields.join(", ")}');
        print('   Add these fields in Firebase Console to fix permission errors');
      }
      
      print('✅ STEP 4 PASSED: Data validated');
      
      // STEP 5: Cache and Return
      print('💾 STEP 5: Caching user data...');
      _cachedUserData = userData;
      _cachedUserId = firebaseUser.uid;
      
      print('✅ STEP 5 PASSED: Data cached');
      print('');
      print('✅ USER DATA FETCH FLOW: COMPLETE');
      print('   ID: ${userData['id']}');
      print('   Name: ${userData['name'] ?? "Missing"}');
      print('   Email: ${userData['email'] ?? "Missing"}');
      print('   Phone: ${userData['phone'] ?? "Missing"}');
      print('   Flat: ${userData['flatLabel'] ?? userData['flatId'] ?? "Missing"}');
      print('   Building ID: ${userData['buildingId'] ?? "❌ MISSING"}');
      print('   Role: ${userData['role'] ?? "❌ MISSING"}');
      print('');

      return userData;
    } catch (e, stackTrace) {
      print('❌ ERROR in USER DATA FETCH FLOW: $e');
      print('   Stack trace: $stackTrace');
      
      if (e.toString().contains('permission-denied')) {
        print('');
        print('🔧 PERMISSION DENIED ERROR');
        print('   This means either:');
        print('   1. User document does not exist in Firestore');
        print('   2. Firestore security rules are not deployed');
        print('   3. User document is missing required fields');
        print('');
        print('   📖 Read: DO_THIS_NOW_PERMISSION_FIX.md for solution');
        print('');
      }
      
      return null;
    }
  }

  /// Get user name
  Future<String> getUserName() async {
    final userData = await getCurrentUserData();
    return userData?['name'] ?? 'User';
  }

  /// Get user email
  Future<String> getUserEmail() async {
    final userData = await getCurrentUserData();
    return userData?['email'] ?? '';
  }

  /// Get user phone
  Future<String> getUserPhone() async {
    final userData = await getCurrentUserData();
    return userData?['phone'] ?? '';
  }

  /// Get user flat
  Future<String> getUserFlat() async {
    final userData = await getCurrentUserData();
    return userData?['flatLabel'] ?? userData?['flatId'] ?? '';
  }

  /// Get user role
  Future<String> getUserRole() async {
    final userData = await getCurrentUserData();
    return userData?['role'] ?? 'resident';
  }

  /// Get user resident ID
  Future<String> getUserResidentId() async {
    final userData = await getCurrentUserData();
    return userData?['residentId'] ?? '';
  }

  /// Get user ownership type
  Future<String> getUserOwnershipType() async {
    final userData = await getCurrentUserData();
    return userData?['ownershipType'] ?? 'Owner';
  }

  /// Get family members count
  Future<int> getFamilyMembersCount() async {
    final userData = await getCurrentUserData();
    return userData?['familyMembers'] ?? 0;
  }

  /// Get user profile photo URL
  Future<String?> getUserPhotoUrl() async {
    final userData = await getCurrentUserData();
    return userData?['photoUrl'];
  }

  /// Update user data in Firestore
  Future<bool> updateUserData(Map<String, dynamic> updates) async {
    try {
      final userId = await _authService.getCurrentUserId();
      
      if (userId == null) {
        print('❌ No user logged in');
        return false;
      }

      print('📤 Updating user data in Firestore...');

      // Add timestamp
      updates['updatedAt'] = FieldValue.serverTimestamp();

      // Update in Firestore
      await _firestore.collection('users').doc(userId).update(updates);

      // Also update Firebase Auth profile if name or photo changed
      final firebaseUser = _auth.currentUser;
      if (firebaseUser != null) {
        if (updates.containsKey('name')) {
          await firebaseUser.updateDisplayName(updates['name']);
          print('✅ Updated Firebase Auth display name');
        }
        if (updates.containsKey('profileImage') || updates.containsKey('photoURL')) {
          final photoUrl = updates['profileImage'] ?? updates['photoURL'];
          if (photoUrl != null) {
            await firebaseUser.updatePhotoURL(photoUrl);
            print('✅ Updated Firebase Auth photo URL');
          }
        }
      }

      // Clear cache to force refresh
      _cachedUserData = null;

      print('✅ User data updated successfully');
      return true;
    } catch (e) {
      print('❌ Error updating user data: $e');
      return false;
    }
  }

  /// Update user profile
  Future<bool> updateProfile({
    String? name,
    String? email,
    String? phone,
    String? photoUrl,
  }) async {
    final updates = <String, dynamic>{};
    
    if (name != null) updates['name'] = name;
    if (email != null) updates['email'] = email;
    if (phone != null) updates['phone'] = phone;
    if (photoUrl != null) updates['photoUrl'] = photoUrl;

    return await updateUserData(updates);
  }

  /// Stream user data (real-time updates)
  Stream<Map<String, dynamic>?> streamUserData() async* {
    final userId = await _authService.getCurrentUserId();
    
    if (userId == null) {
      yield null;
      return;
    }

    yield* _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((snapshot) {
          if (!snapshot.exists) return null;
          
          final data = snapshot.data()!;
          
          // Update cache
          _cachedUserData = data;
          _cachedUserId = userId;
          
          return data;
        });
  }

  /// Clear cached data
  void clearCache() {
    _cachedUserData = null;
    _cachedUserId = null;
    print('🗑️  User data cache cleared');
  }

  /// Check if user is admin
  Future<bool> isAdmin() async {
    final role = await getUserRole();
    return role == 'admin';
  }

  /// Check if user is resident
  Future<bool> isResident() async {
    final role = await getUserRole();
    return role == 'resident';
  }

  /// Get user display info (for UI)
  Future<Map<String, String>> getUserDisplayInfo() async {
    final userData = await getCurrentUserData();
    
    if (userData == null) {
      return {
        'name': 'User',
        'email': '',
        'phone': '',
        'flat': '',
        'role': 'resident',
      };
    }

    return {
      'name': userData['name'] ?? 'User',
      'email': userData['email'] ?? '',
      'phone': userData['phone'] ?? '',
      'flat': userData['flatLabel'] ?? userData['flatId'] ?? '',
      'role': userData['role'] ?? 'resident',
      'residentId': userData['residentId'] ?? '',
      'ownershipType': userData['ownershipType'] ?? 'Owner',
    };
  }

  /// Get user's language preference
  Future<String?> getUserLanguagePreference(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      
      if (!doc.exists) {
        return null;
      }

      final language = doc.data()?['language'] as String?;
      return language;
    } catch (e) {
      print('❌ Error fetching language preference: $e');
      return null;
    }
  }

  /// Save user's language preference
  Future<bool> saveUserLanguagePreference(String userId, String languageCode) async {
    try {
      print('📤 Saving language preference: $languageCode');
      
      await _firestore.collection('users').doc(userId).update({
        'language': languageCode,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Clear cache to force refresh
      _cachedUserData = null;

      print('✅ Language preference saved successfully');
      return true;
    } catch (e) {
      print('❌ Error saving language preference: $e');
      return false;
    }
  }
}
