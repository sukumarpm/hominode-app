// lib/src/services/firestore_auth_service.dart
// Firestore-based Authentication Service with Firebase Auth integration
// Validates credentials from Firestore and signs in with Firebase Authentication

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Result class for authentication operations
class FirestoreAuthResult {
  final bool success;
  final String? message;
  final Map<String, dynamic>? userData;
  final String? userId;

  FirestoreAuthResult({
    required this.success,
    this.message,
    this.userData,
    this.userId,
  });

  factory FirestoreAuthResult.success({
    String? message,
    Map<String, dynamic>? userData,
    String? userId,
  }) {
    return FirestoreAuthResult(
      success: true,
      message: message ?? 'Login successful',
      userData: userData,
      userId: userId,
    );
  }

  factory FirestoreAuthResult.failure({required String message}) {
    return FirestoreAuthResult(
      success: false,
      message: message,
    );
  }
}

/// Firestore Authentication Service
/// Validates credentials directly from Firestore users collection
class FirestoreAuthService {
  // Singleton pattern
  static final FirestoreAuthService instance = FirestoreAuthService._internal();
  factory FirestoreAuthService() => instance;
  FirestoreAuthService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Storage keys
  static const String _keyIsLoggedIn = 'is_logged_in';
  static const String _keyUserId = 'user_id';
  static const String _keyUserEmail = 'user_email';
  static const String _keyUserPhone = 'user_phone';

  /// Sign in with ONLY Firestore (no Firebase Auth required)
  /// 
  /// This method validates credentials directly from Firestore
  /// and does NOT use Firebase Authentication at all
  /// 
  /// [identifier] can be email or phone number
  /// [password] is the user's password
  /// 
  /// Returns [FirestoreAuthResult] with user data if successful
  Future<FirestoreAuthResult> signInFirestoreOnly({
    required String identifier,
    required String password,
  }) async {
    try {
      print('🔐 Starting Firestore-only authentication...');
      print('   Identifier: $identifier');
      
      final cleanIdentifier = identifier.trim();
      
      // Check if identifier is phone or email
      final isPhone = RegExp(r'^[\d+\s()-]+$').hasMatch(cleanIdentifier);
      
      QuerySnapshot querySnapshot;
      
      if (isPhone) {
        print('📱 Detected phone number, searching in Firestore...');
        
        // Clean phone number
        String cleanPhone = cleanIdentifier.replaceAll(RegExp(r'[\s()-]'), '');
        
        // Remove country code if present
        if (cleanPhone.startsWith('+91')) {
          cleanPhone = cleanPhone.substring(3);
        } else if (cleanPhone.startsWith('91') && cleanPhone.length > 10) {
          cleanPhone = cleanPhone.substring(2);
        }
        
        print('   Searching for phone: $cleanPhone');
        
        // Try multiple phone format variations
        final phoneVariations = [
          cleanPhone,
          '+91$cleanPhone',
          '91$cleanPhone',
        ];
        
        QuerySnapshot? foundQuery;
        
        for (var phoneVar in phoneVariations) {
          print('   Trying: $phoneVar');
          final query = await _firestore
              .collection('users')
              .where('phone', isEqualTo: phoneVar)
              .limit(1)
              .get();
          
          if (query.docs.isNotEmpty) {
            foundQuery = query;
            print('   ✅ Found user with phone: $phoneVar');
            break;
          }
        }
        
        if (foundQuery == null || foundQuery.docs.isEmpty) {
          print('❌ No user found with phone: $cleanPhone');
          return FirestoreAuthResult.failure(
            message: 'No account found with this phone number',
          );
        }
        
        querySnapshot = foundQuery;
        
      } else {
        print('📧 Detected email, searching in Firestore...');
        print('   Searching for email: $cleanIdentifier');
        
        // Search by email
        querySnapshot = await _firestore
            .collection('users')
            .where('email', isEqualTo: cleanIdentifier)
            .limit(1)
            .get();
        
        if (querySnapshot.docs.isEmpty) {
          print('❌ No user found with email: $cleanIdentifier');
          return FirestoreAuthResult.failure(
            message: 'No account found with this email',
          );
        }
        
        print('   ✅ Found user with email: $cleanIdentifier');
      }
      
      // Get user document
      final userDoc = querySnapshot.docs.first;
      final userData = userDoc.data() as Map<String, dynamic>;
      final userId = userDoc.id;
      
      print('   User ID: $userId');
      print('   User Name: ${userData['name']}');
      
      // Check if password field exists
      if (!userData.containsKey('password')) {
        print('❌ Password field not found in user document');
        return FirestoreAuthResult.failure(
          message: 'Account configuration error. Please contact support.',
        );
      }
      
      // Verify password
      final storedPassword = userData['password'] as String;
      
      print('   Verifying password...');
      print('   Stored password: $storedPassword');
      print('   Entered password: $password');
      
      if (storedPassword != password) {
        print('❌ Password mismatch');
        return FirestoreAuthResult.failure(
          message: 'Invalid email or password',
        );
      }
      
      print('✅ Password verified successfully');
      
      // Check if user is active
      if (userData.containsKey('status') && userData['status'] != 'active') {
        print('⚠️  User account is not active: ${userData['status']}');
        return FirestoreAuthResult.failure(
          message: 'Your account is ${userData['status']}. Please contact support.',
        );
      }
      
      // Create/Sign in with Firebase Authentication
      print('🔐 Creating/Signing in with Firebase Authentication...');
      final email = userData['email'] as String?;
      
      if (email != null && email.isNotEmpty) {
        try {
          // Check if user has authUid stored
          final storedAuthUid = userData['authUid'] as String?;
          
          if (storedAuthUid != null && storedAuthUid.isNotEmpty) {
            // User has authUid, try to sign in with stored password
            print('   Found stored authUid: $storedAuthUid');
            try {
              final userCredential = await _auth.signInWithEmailAndPassword(
                email: email,
                password: password,
              );
              print('✅ Firebase Authentication successful (existing user)');
              
              // Update Firebase Auth profile with latest user data
              final firebaseUser = userCredential.user;
              if (firebaseUser != null) {
                await firebaseUser.updateDisplayName(userData['name']);
                if (userData.containsKey('profileImage') || userData.containsKey('photoURL')) {
                  await firebaseUser.updatePhotoURL(userData['profileImage'] ?? userData['photoURL']);
                }
                print('✅ Firebase Auth profile updated');
              }
            } on FirebaseAuthException catch (e) {
              print('⚠️  Firebase Auth sign-in failed: ${e.code}');
              print('   Continuing with Firestore-only authentication');
            }
          } else {
            // No authUid, create new Firebase Auth user
            print('   No authUid found, creating new Firebase Auth user...');
            try {
              // Create Firebase Auth user with the Firestore password
              final userCredential = await _auth.createUserWithEmailAndPassword(
                email: email,
                password: password,
              );
              print('✅ Firebase Auth account created');
              
              // Set user profile data in Firebase Auth
              final firebaseUser = userCredential.user;
              if (firebaseUser != null) {
                await firebaseUser.updateDisplayName(userData['name']);
                if (userData.containsKey('profileImage') || userData.containsKey('photoURL')) {
                  await firebaseUser.updatePhotoURL(userData['profileImage'] ?? userData['photoURL']);
                }
                
                // Store authUid in Firestore user document
                await _firestore.collection('users').doc(userId).update({
                  'authUid': firebaseUser.uid,
                  'updatedAt': FieldValue.serverTimestamp(),
                });
                
                print('✅ Firebase Auth profile set and authUid stored in Firestore');
                print('   Auth UID: ${firebaseUser.uid}');
                print('   Email: $email');
              }
            } on FirebaseAuthException catch (e) {
              if (e.code == 'email-already-in-use') {
                // Email exists in Firebase Auth but no authUid in Firestore
                // Try to sign in and link the accounts
                print('⚠️  Email already exists in Firebase Auth, attempting to link...');
                try {
                  final userCredential = await _auth.signInWithEmailAndPassword(
                    email: email,
                    password: password,
                  );
                  
                  final firebaseUser = userCredential.user;
                  if (firebaseUser != null) {
                    // Store authUid in Firestore
                    await _firestore.collection('users').doc(userId).update({
                      'authUid': firebaseUser.uid,
                      'updatedAt': FieldValue.serverTimestamp(),
                    });
                    
                    // Update profile
                    await firebaseUser.updateDisplayName(userData['name']);
                    if (userData.containsKey('profileImage') || userData.containsKey('photoURL')) {
                      await firebaseUser.updatePhotoURL(userData['profileImage'] ?? userData['photoURL']);
                    }
                    
                    print('✅ Linked existing Firebase Auth account');
                    print('   Auth UID: ${firebaseUser.uid}');
                  }
                } catch (linkError) {
                  print('❌ Failed to link accounts: $linkError');
                  print('   Continuing with Firestore-only authentication');
                }
              } else {
                print('❌ Failed to create Firebase Auth account: ${e.code} - ${e.message}');
                print('   Continuing with Firestore-only authentication');
              }
            } catch (createError) {
              print('❌ Unexpected error creating Firebase Auth account: $createError');
              print('   Continuing with Firestore-only authentication');
            }
          }
        } catch (e) {
          print('❌ Unexpected error during Firebase Auth: $e');
          print('   Continuing with Firestore-only authentication');
        }
      } else {
        print('⚠️  No email found in user data, skipping Firebase Auth');
      }
      
      // Ensure user has flatId assigned (for testing/demo purposes)
      if (!userData.containsKey('flatId') || userData['flatId'] == null || userData['flatId'].toString().isEmpty) {
        print('⚠️  No flatId assigned, assigning default flat for testing...');
        
        // Assign a default flat for testing
        await _firestore.collection('users').doc(userId).update({
          'flatId': 'flat_001',
          'flatLabel': 'A-101',
          'buildingId': 'building_001',
          'updatedAt': FieldValue.serverTimestamp(),
        });
        
        print('✅ Default flat assigned: flat_001');
        
        // Update userData with the new flatId
        userData['flatId'] = 'flat_001';
        userData['flatLabel'] = 'A-101';
        userData['buildingId'] = 'building_001';
      }
      
      // Save login state
      await _saveLoginState(
        userId: userId,
        email: userData['email'],
        phone: userData['phone'],
      );
      
      print('✅ Login successful!');
      print('   Welcome: ${userData['name']}');
      
      return FirestoreAuthResult.success(
        message: 'Login successful',
        userData: userData,
        userId: userId,
      );
      
    } catch (e, stackTrace) {
      print('❌ Error during authentication: $e');
      print('   Stack trace: $stackTrace');
      return FirestoreAuthResult.failure(
        message: 'Login failed. Please check your connection and try again.',
      );
    }
  }

  /// Sign in with email or phone and password
  /// 
  /// Checks credentials directly from Firestore users collection
  /// 
  /// [identifier] can be email or phone number
  /// [password] is the user's password
  /// 
  /// Returns [FirestoreAuthResult] with user data if successful
  Future<FirestoreAuthResult> signIn({
    required String identifier,
    required String password,
  }) async {
    try {
      print('🔐 Starting Firestore authentication...');
      print('   Identifier: $identifier');
      
      final cleanIdentifier = identifier.trim();
      
      // Check if identifier is phone or email
      final isPhone = RegExp(r'^[\d+\s()-]+$').hasMatch(cleanIdentifier);
      
      QuerySnapshot querySnapshot;
      
      if (isPhone) {
        print('📱 Detected phone number, searching in Firestore...');
        
        // Clean phone number
        String cleanPhone = cleanIdentifier.replaceAll(RegExp(r'[\s()-]'), '');
        
        // Remove country code if present
        if (cleanPhone.startsWith('+91')) {
          cleanPhone = cleanPhone.substring(3);
        } else if (cleanPhone.startsWith('91') && cleanPhone.length > 10) {
          cleanPhone = cleanPhone.substring(2);
        }
        
        print('   Searching for phone: $cleanPhone');
        
        // Try multiple phone format variations
        final phoneVariations = [
          cleanPhone,
          '+91$cleanPhone',
          '91$cleanPhone',
        ];
        
        QuerySnapshot? foundQuery;
        
        for (var phoneVar in phoneVariations) {
          print('   Trying: $phoneVar');
          final query = await _firestore
              .collection('users')
              .where('phone', isEqualTo: phoneVar)
              .limit(1)
              .get();
          
          if (query.docs.isNotEmpty) {
            foundQuery = query;
            print('   ✅ Found user with phone: $phoneVar');
            break;
          }
        }
        
        if (foundQuery == null || foundQuery.docs.isEmpty) {
          print('❌ No user found with phone: $cleanPhone');
          return FirestoreAuthResult.failure(
            message: 'No account found with this phone number',
          );
        }
        
        querySnapshot = foundQuery;
        
      } else {
        print('📧 Detected email, searching in Firestore...');
        print('   Searching for email: $cleanIdentifier');
        
        // Search by email
        querySnapshot = await _firestore
            .collection('users')
            .where('email', isEqualTo: cleanIdentifier)
            .limit(1)
            .get();
        
        if (querySnapshot.docs.isEmpty) {
          print('❌ No user found with email: $cleanIdentifier');
          return FirestoreAuthResult.failure(
            message: 'No account found with this email',
          );
        }
        
        print('   ✅ Found user with email: $cleanIdentifier');
      }
      
      // Get user document
      final userDoc = querySnapshot.docs.first;
      final userData = userDoc.data() as Map<String, dynamic>;
      final userId = userDoc.id;
      
      print('   User ID: $userId');
      print('   User Name: ${userData['name']}');
      
      // Check if password field exists
      if (!userData.containsKey('password')) {
        print('❌ Password field not found in user document');
        return FirestoreAuthResult.failure(
          message: 'Account configuration error. Please contact support.',
        );
      }
      
      // Verify password
      final storedPassword = userData['password'] as String;
      
      print('   Verifying password...');
      
      if (storedPassword != password) {
        print('❌ Password mismatch');
        return FirestoreAuthResult.failure(
          message: 'Invalid credentials. Please check and try again.',
        );
      }
      
      print('✅ Password verified successfully');
      
      // Check if user is active
      if (userData.containsKey('status') && userData['status'] != 'active') {
        print('⚠️  User account is not active: ${userData['status']}');
        return FirestoreAuthResult.failure(
          message: 'Your account is ${userData['status']}. Please contact support.',
        );
      }
      
      // Sign in with Firebase Authentication
      print('🔐 Signing in with Firebase Authentication...');
      final email = userData['email'] as String;
      
      try {
        final userCredential = await _auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
        print('✅ Firebase Authentication successful');
        
        // Update Firebase Auth profile with user data
        final firebaseUser = userCredential.user;
        if (firebaseUser != null) {
          await firebaseUser.updateDisplayName(userData['name']);
          await firebaseUser.updatePhotoURL(userData['profileImage'] ?? userData['photoURL']);
          print('✅ Firebase Auth profile updated with user data');
        }
      } on FirebaseAuthException catch (e) {
        if (e.code == 'user-not-found') {
          // User doesn't exist in Firebase Auth, create it
          print('⚠️  User not found in Firebase Auth, creating account...');
          try {
            final userCredential = await _auth.createUserWithEmailAndPassword(
              email: email,
              password: password,
            );
            print('✅ Firebase Auth account created');
            
            // Set user profile data in Firebase Auth
            final firebaseUser = userCredential.user;
            if (firebaseUser != null) {
              await firebaseUser.updateDisplayName(userData['name']);
              await firebaseUser.updatePhotoURL(userData['profileImage'] ?? userData['photoURL']);
              print('✅ Firebase Auth profile set with user data');
            }
          } catch (createError) {
            print('❌ Failed to create Firebase Auth account: $createError');
            return FirestoreAuthResult.failure(
              message: 'Authentication error. Please contact support.',
            );
          }
        } else {
          print('❌ Firebase Auth error: ${e.code} - ${e.message}');
          return FirestoreAuthResult.failure(
            message: 'Authentication failed: ${e.message}',
          );
        }
      }
      
      // Ensure user has flatId assigned (for testing/demo purposes)
      if (!userData.containsKey('flatId') || userData['flatId'] == null || userData['flatId'].toString().isEmpty) {
        print('⚠️  No flatId assigned, assigning default flat for testing...');
        
        // Assign a default flat for testing
        await _firestore.collection('users').doc(userId).update({
          'flatId': 'flat_001',
          'flatLabel': 'A-101',
          'buildingId': 'building_001',
          'updatedAt': FieldValue.serverTimestamp(),
        });
        
        print('✅ Default flat assigned: flat_001');
        
        // Update userData with the new flatId
        userData['flatId'] = 'flat_001';
        userData['flatLabel'] = 'A-101';
        userData['buildingId'] = 'building_001';
      }
      
      // Save login state
      await _saveLoginState(
        userId: userId,
        email: userData['email'],
        phone: userData['phone'],
      );
      
      print('✅ Login successful!');
      print('   Welcome: ${userData['name']}');
      
      return FirestoreAuthResult.success(
        message: 'Login successful',
        userData: userData,
        userId: userId,
      );
      
    } catch (e) {
      print('❌ Error during authentication: $e');
      return FirestoreAuthResult.failure(
        message: 'Login failed. Please check your connection and try again.',
      );
    }
  }

  /// Check if user is logged in
  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyIsLoggedIn) ?? false;
  }

  /// Get current user ID
  Future<String?> getCurrentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserId);
  }

  /// Get current user data from Firestore
  Future<Map<String, dynamic>?> getCurrentUserData() async {
    try {
      final userId = await getCurrentUserId();
      if (userId == null) return null;
      
      final doc = await _firestore.collection('users').doc(userId).get();
      if (!doc.exists) return null;
      
      return doc.data();
    } catch (e) {
      print('Error getting user data: $e');
      return null;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    await _auth.signOut();
    await _clearLoginState();
    print('✅ User signed out from Firebase Auth and local storage');
  }

  /// Save login state to SharedPreferences
  Future<void> _saveLoginState({
    required String userId,
    String? email,
    String? phone,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsLoggedIn, true);
    await prefs.setString(_keyUserId, userId);
    
    if (email != null) {
      await prefs.setString(_keyUserEmail, email);
    }
    
    if (phone != null) {
      await prefs.setString(_keyUserPhone, phone);
    }
    
    print('💾 Login state saved');
  }

  /// Clear login state from SharedPreferences
  Future<void> _clearLoginState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyIsLoggedIn);
    await prefs.remove(_keyUserId);
    await prefs.remove(_keyUserEmail);
    await prefs.remove(_keyUserPhone);
    
    print('🗑️  Login state cleared');
  }

  /// Validate email format
  bool validateEmail(String email) {
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    return emailRegex.hasMatch(email.trim());
  }

  /// Validate phone number format
  bool validatePhoneNumber(String phone) {
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d]'), '');
    return cleanPhone.length == 10;
  }

  /// Format phone number to E.164 format
  String formatPhoneNumber(String phone) {
    String cleanPhone = phone.replaceAll(RegExp(r'[^\d]'), '');
    
    // Remove country code if present
    if (cleanPhone.startsWith('91') && cleanPhone.length > 10) {
      cleanPhone = cleanPhone.substring(2);
    }
    
    return '+91$cleanPhone';
  }

  /// Sign in with email and password (wrapper for signIn)
  /// Properly syncs Firestore user with Firebase Authentication
  /// Handles both email and phone identifiers
  Future<FirestoreAuthResult> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      print('🔵 signInWithEmail: Starting email/password login...');
      print('📧 Identifier: $email');
      
      // Step 0: Determine if identifier is email or phone
      final identifier = email.trim();
      final isPhone = RegExp(r'^[\d+\s()-]+$').hasMatch(identifier);
      
      print('🔍 Identifier type: ${isPhone ? 'Phone' : 'Email'}');
      
      // Step 1: Find user in Firestore first
      print('🔐 Step 1: Searching for user in Firestore...');
      
      QuerySnapshot querySnapshot;
      
      if (isPhone) {
        print('📱 Searching by phone number...');
        
        // Clean phone number
        String cleanPhone = identifier.replaceAll(RegExp(r'[\s()-]'), '');
        
        // Remove country code if present
        if (cleanPhone.startsWith('+91')) {
          cleanPhone = cleanPhone.substring(3);
        } else if (cleanPhone.startsWith('91') && cleanPhone.length > 10) {
          cleanPhone = cleanPhone.substring(2);
        }
        
        print('   Searching for phone: $cleanPhone');
        
        // Try multiple phone format variations
        final phoneVariations = [
          cleanPhone,
          '+91$cleanPhone',
          '91$cleanPhone',
        ];
        
        QuerySnapshot? foundQuery;
        
        for (var phoneVar in phoneVariations) {
          print('   Trying: $phoneVar');
          final query = await _firestore
              .collection('users')
              .where('phone', isEqualTo: phoneVar)
              .limit(1)
              .get();
          
          if (query.docs.isNotEmpty) {
            foundQuery = query;
            print('   ✅ Found user with phone: $phoneVar');
            break;
          }
        }
        
        if (foundQuery == null || foundQuery.docs.isEmpty) {
          print('❌ No user found with phone: $cleanPhone');
          return FirestoreAuthResult.failure(
            message: 'No account found with this phone number',
          );
        }
        
        querySnapshot = foundQuery;
        
      } else {
        print('📧 Searching by email...');
        print('   Searching for email: $identifier');
        
        // Search by email
        querySnapshot = await _firestore
            .collection('users')
            .where('email', isEqualTo: identifier)
            .limit(1)
            .get();
        
        if (querySnapshot.docs.isEmpty) {
          print('❌ No user found with email: $identifier');
          return FirestoreAuthResult.failure(
            message: 'No account found with this email',
          );
        }
        
        print('   ✅ Found user with email: $identifier');
      }
      
      // Get user document
      final userDoc = querySnapshot.docs.first;
      final userData = userDoc.data() as Map<String, dynamic>;
      final userId = userDoc.id;
      final userEmail = userData['email'] as String?;
      
      print('✅ User found in Firestore: $userId');
      print('   Name: ${userData['name']}');
      print('   Email: $userEmail');
      
      // Step 2: Verify password
      print('🔐 Step 2: Verifying password...');
      
      if (!userData.containsKey('password')) {
        print('❌ Password field not found in user document');
        return FirestoreAuthResult.failure(
          message: 'Account configuration error. Please contact support.',
        );
      }
      
      final storedPassword = userData['password'] as String;
      
      if (storedPassword != password) {
        print('❌ Password mismatch');
        return FirestoreAuthResult.failure(
          message: 'Invalid credentials. Please check and try again.',
        );
      }
      
      print('✅ Password verified successfully');
      
      // Step 3: Check if user is active
      if (userData.containsKey('status') && userData['status'] != 'active') {
        print('⚠️  User account is not active: ${userData['status']}');
        return FirestoreAuthResult.failure(
          message: 'Your account is ${userData['status']}. Please contact support.',
        );
      }
      
      // Step 4: Sync with Firebase Authentication
      print('🔐 Step 3: Syncing with Firebase Authentication...');
      
      if (userEmail == null || userEmail.isEmpty) {
        print('⚠️  No email found in user data, skipping Firebase Auth');
      } else {
        try {
          // Try to sign in with Firebase Auth
          print('   Attempting Firebase Auth sign-in...');
          try {
            final userCredential = await _auth.signInWithEmailAndPassword(
              email: userEmail,
              password: password,
            );
            
            print('✅ Firebase Auth sign-in successful');
            print('🆔 Firebase UID: ${userCredential.user?.uid}');
            
            // Update Firestore with Firebase UID if not already set
            if (!userData.containsKey('authUid') || userData['authUid'] == null) {
              await _firestore.collection('users').doc(userId).update({
                'authUid': userCredential.user!.uid,
                'uid': userCredential.user!.uid,
                'updatedAt': FieldValue.serverTimestamp(),
              });
              print('✅ Updated Firestore with Firebase UID');
            }
            
          } on FirebaseAuthException catch (e) {
            if (e.code == 'user-not-found') {
              print('⚠️  User not found in Firebase Auth, creating account...');
              
              try {
                // Create Firebase Auth account
                final userCredential = await _auth.createUserWithEmailAndPassword(
                  email: userEmail,
                  password: password,
                );
                
                print('✅ Firebase Auth account created');
                print('🆔 Firebase UID: ${userCredential.user?.uid}');
                
                // Update Firestore with Firebase UID
                await _firestore.collection('users').doc(userId).update({
                  'authUid': userCredential.user!.uid,
                  'uid': userCredential.user!.uid,
                  'updatedAt': FieldValue.serverTimestamp(),
                });
                
                print('✅ Firestore synced with Firebase UID');
                
              } catch (createError) {
                print('❌ Failed to create Firebase Auth account: $createError');
                print('   Continuing with Firestore-only authentication');
              }
              
            } else if (e.code == 'wrong-password') {
              print('❌ Wrong password in Firebase Auth');
              print('   Continuing with Firestore-only authentication');
            } else {
              print('❌ Firebase Auth error: ${e.code} - ${e.message}');
              print('   Continuing with Firestore-only authentication');
            }
          }
        } catch (e) {
          print('❌ Unexpected error during Firebase Auth: $e');
          print('   Continuing with Firestore-only authentication');
        }
      }
      
      // Step 5: Ensure user has flatId assigned
      print('🔐 Step 4: Checking flat assignment...');
      
      if (!userData.containsKey('flatId') || userData['flatId'] == null || userData['flatId'].toString().isEmpty) {
        print('⚠️  No flatId assigned, assigning default flat for testing...');
        
        // Assign a default flat for testing
        await _firestore.collection('users').doc(userId).update({
          'flatId': 'flat_001',
          'flatLabel': 'A-101',
          'buildingId': 'building_001',
          'updatedAt': FieldValue.serverTimestamp(),
        });
        
        print('✅ Default flat assigned: flat_001');
        
        // Update userData with the new flatId
        userData['flatId'] = 'flat_001';
        userData['flatLabel'] = 'A-101';
        userData['buildingId'] = 'building_001';
      } else {
        print('✅ User has flatId: ${userData['flatId']}');
      }
      
      // Step 6: Save login state
      print('🔐 Step 5: Saving login state...');
      
      await _saveLoginState(
        userId: userId,
        email: userData['email'],
        phone: userData['phone'],
      );
      
      print('✅ Login successful!');
      print('   Welcome: ${userData['name']}');
      print('   Flat: ${userData['flatId']}');
      
      return FirestoreAuthResult.success(
        message: 'Login successful',
        userData: userData,
        userId: userId,
      );
      
    } catch (e, stackTrace) {
      print('❌ Unexpected error: $e');
      print('   Stack trace: $stackTrace');
      return FirestoreAuthResult.failure(
        message: 'Login failed. Please try again.',
      );
    }
  }

  /// Sign in with phone using OTP
  Future<void> signInWithPhone({
    required String phoneNumber,
    required Function(String verificationId) onCodeSent,
    required Function(String error) onError,
    required Function(PhoneAuthCredential credential) onAutoVerify,
  }) async {
    try {
      print('🔐 Starting phone OTP authentication...');
      print('   Phone: $phoneNumber');
      
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          print('✅ Phone auto-verified');
          onAutoVerify(credential);
          
          try {
            final userCredential = await _auth.signInWithCredential(credential);
            print('✅ Firebase Auth sign-in successful');
            
            // Get user data from Firestore
            final userId = userCredential.user?.uid;
            if (userId != null) {
              final userDoc = await _firestore.collection('users').doc(userId).get();
              if (userDoc.exists) {
                await _saveLoginState(
                  userId: userId,
                  email: userDoc['email'],
                  phone: userDoc['phone'],
                );
              }
            }
          } catch (e) {
            print('❌ Error during auto-verification sign-in: $e');
            onError('Auto-verification failed: $e');
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          print('❌ Phone verification failed: ${e.code} - ${e.message}');
          onError(e.message ?? 'Phone verification failed');
        },
        codeSent: (String verificationId, int? resendToken) {
          print('✅ OTP sent to $phoneNumber');
          print('   Verification ID: $verificationId');
          onCodeSent(verificationId);
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          print('⏱️  Auto-retrieval timeout for verification ID: $verificationId');
        },
      );
    } catch (e) {
      print('❌ Error during phone OTP: $e');
      onError('Phone OTP failed: $e');
    }
  }

  /// Send password reset email
  Future<FirestoreAuthResult> sendPasswordResetEmail({required String email}) async {
    try {
      print('🔐 Sending password reset email to: $email');
      
      // Check if user exists in Firestore
      final querySnapshot = await _firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      
      if (querySnapshot.docs.isEmpty) {
        print('❌ No user found with email: $email');
        return FirestoreAuthResult.failure(
          message: 'No account found with this email',
        );
      }
      
      // Send password reset email via Firebase Auth
      try {
        await _auth.sendPasswordResetEmail(email: email);
        print('✅ Password reset email sent to: $email');
        return FirestoreAuthResult.success(
          message: 'Password reset email sent. Check your inbox.',
        );
      } on FirebaseAuthException catch (e) {
        if (e.code == 'user-not-found') {
          print('⚠️  User not found in Firebase Auth, but exists in Firestore');
          print('   User may need to complete registration');
          return FirestoreAuthResult.failure(
            message: 'Account not fully set up. Please contact support.',
          );
        } else {
          print('❌ Firebase Auth error: ${e.code} - ${e.message}');
          return FirestoreAuthResult.failure(
            message: e.message ?? 'Failed to send reset email',
          );
        }
      }
    } catch (e) {
      print('❌ Error sending password reset email: $e');
      return FirestoreAuthResult.failure(
        message: 'Failed to send reset email. Please try again.',
      );
    }
  }
}
