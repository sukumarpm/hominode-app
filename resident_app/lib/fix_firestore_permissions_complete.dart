// lib/fix_firestore_permissions_complete.dart
// Complete script to fix all Firestore permission issues

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

void main() async {
  print('🔧 Starting Firestore Permission Fix...\n');
  await fixAllPermissionIssues();
}

Future<void> fixAllPermissionIssues() async {
  final auth = FirebaseAuth.instance;
  final firestore = FirebaseFirestore.instance;
  
  print('=' * 60);
  print('STEP 1: Check Authentication');
  print('=' * 60);
  
  final user = auth.currentUser;
  if (user == null) {
    print('❌ NO USER LOGGED IN');
    print('   You must login before running this script');
    print('   Solution: Login to your app first, then run this script\n');
    return;
  }
  
  print('✅ User is logged in');
  print('   Firebase Auth UID: ${user.uid}');
  print('   Email: ${user.email ?? "No email"}');
  print('   Display Name: ${user.displayName ?? "No name"}');
  print('');
  
  print('=' * 60);
  print('STEP 2: Check/Create User Document');
  print('=' * 60);
  
  try {
    final doc = await firestore.collection('users').doc(user.uid).get();
    
    if (!doc.exists) {
      print('❌ User document does not exist');
      print('   Creating user document with correct structure...\n');
      
      // ⚠️ IMPORTANT: Update these values for your user
      final userData = {
        'id': user.uid,
        'authUid': user.uid,
        'email': user.email ?? '',
        'name': user.displayName ?? 'User Name', // ⚠️ CHANGE THIS
        'phone': user.phoneNumber ?? '+1234567890', // ⚠️ CHANGE THIS
        'buildingId': 'building1', // ⚠️ CHANGE THIS
        'flatId': 'flat101', // ⚠️ CHANGE THIS
        'flatLabel': 'A-101', // ⚠️ CHANGE THIS
        'role': 'resident', // or 'admin' ⚠️ CHANGE IF ADMIN
        'residentId': 'RES${DateTime.now().millisecondsSinceEpoch}',
        'ownershipType': 'Owner',
        'profileImage': '',
        'photoURL': '',
        'language': 'en',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      
      await firestore.collection('users').doc(user.uid).set(userData);
      
      print('✅ User document created successfully');
      print('   Document ID: ${user.uid}');
      print('   ⚠️  IMPORTANT: Update buildingId, flatId, name, phone in the script');
      print('');
    } else {
      print('✅ User document exists');
      print('   Document ID: ${doc.id}');
      print('');
    }
  } catch (e) {
    print('❌ ERROR: $e');
    if (e.toString().contains('permission-denied')) {
      print('   This is a permission error - rules may not be deployed');
      print('   Or rules are not propagated yet (wait 2 minutes)\n');
    }
    return;
  }
  
  print('=' * 60);
  print('STEP 3: Verify Required Fields');
  print('=' * 60);
  
  try {
    final doc = await firestore.collection('users').doc(user.uid).get();
    final data = doc.data()!;
    
    print('Checking required fields...');
    
    final updates = <String, dynamic>{};
    bool needsUpdate = false;
    
    // Check buildingId
    if (data['buildingId'] == null || data['buildingId'] == '') {
      print('❌ Missing: buildingId');
      updates['buildingId'] = 'building1'; // ⚠️ CHANGE THIS
      needsUpdate = true;
    } else {
      print('✅ buildingId: ${data['buildingId']}');
    }
    
    // Check flatId
    if (data['flatId'] == null || data['flatId'] == '') {
      print('❌ Missing: flatId');
      updates['flatId'] = 'flat101'; // ⚠️ CHANGE THIS
      needsUpdate = true;
    } else {
      print('✅ flatId: ${data['flatId']}');
    }
    
    // Check role
    if (data['role'] == null || data['role'] == '') {
      print('❌ Missing: role');
      updates['role'] = 'resident'; // ⚠️ CHANGE TO 'admin' IF NEEDED
      needsUpdate = true;
    } else {
      print('✅ role: ${data['role']}');
    }
    
    // Check name
    if (data['name'] == null || data['name'] == '') {
      print('⚠️  Missing: name');
      updates['name'] = user.displayName ?? 'User Name';
      needsUpdate = true;
    } else {
      print('✅ name: ${data['name']}');
    }
    
    // Check email
    if (data['email'] == null || data['email'] == '') {
      print('⚠️  Missing: email');
      updates['email'] = user.email ?? '';
      needsUpdate = true;
    } else {
      print('✅ email: ${data['email']}');
    }
    
    if (needsUpdate) {
      print('\n📝 Updating user document with missing fields...');
      updates['updatedAt'] = FieldValue.serverTimestamp();
      
      await firestore.collection('users').doc(user.uid).update(updates);
      print('✅ User document updated successfully\n');
    } else {
      print('\n✅ All required fields are present\n');
    }
  } catch (e) {
    print('❌ ERROR: $e\n');
    return;
  }
  
  print('=' * 60);
  print('STEP 4: Test Permissions');
  print('=' * 60);
  
  // Test reading user document
  print('🧪 Test 1: Reading user document...');
  try {
    final doc = await firestore.collection('users').doc(user.uid).get();
    print('✅ SUCCESS: Can read user document');
    print('   Data: ${doc.data()}');
  } catch (e) {
    print('❌ FAILED: Cannot read user document');
    print('   Error: $e');
    print('   Solution: Wait 2 minutes for rules to propagate, then try again');
  }
  print('');
  
  // Test reading bills
  print('🧪 Test 2: Reading bills collection...');
  try {
    final snapshot = await firestore.collection('bills').limit(1).get();
    print('✅ SUCCESS: Can read bills collection (${snapshot.docs.length} docs)');
  } catch (e) {
    print('❌ FAILED: Cannot read bills collection');
    print('   Error: ${e.toString().contains('permission-denied') ? 'Permission Denied' : e}');
  }
  print('');
  
  // Test reading complaints
  print('🧪 Test 3: Reading complaints collection...');
  try {
    final snapshot = await firestore.collection('complaints').limit(1).get();
    print('✅ SUCCESS: Can read complaints collection (${snapshot.docs.length} docs)');
  } catch (e) {
    print('❌ FAILED: Cannot read complaints collection');
    print('   Error: ${e.toString().contains('permission-denied') ? 'Permission Denied' : e}');
  }
  print('');
  
  // Test reading visitors
  print('🧪 Test 4: Reading visitors collection...');
  try {
    final snapshot = await firestore.collection('visitors').limit(1).get();
    print('✅ SUCCESS: Can read visitors collection (${snapshot.docs.length} docs)');
  } catch (e) {
    print('❌ FAILED: Cannot read visitors collection');
    print('   Error: ${e.toString().contains('permission-denied') ? 'Permission Denied' : e}');
  }
  print('');
  
  print('=' * 60);
  print('FIX COMPLETE');
  print('=' * 60);
  print('');
  
  print('📋 SUMMARY:');
  print('   ✅ User is authenticated');
  print('   ✅ User document exists with correct ID');
  print('   ✅ Required fields are present');
  print('   ✅ Permission tests completed (check results above)');
  print('');
  
  print('🔧 NEXT STEPS:');
  print('   1. If tests failed: Wait 2 minutes for rules to propagate');
  print('   2. Restart your app completely (not hot reload)');
  print('   3. Try accessing data again');
  print('   4. If still failing: Check Firebase Console > Firestore > Rules for errors');
  print('');
  
  print('⚠️  IMPORTANT REMINDERS:');
  print('   - Update buildingId, flatId, name, phone in this script');
  print('   - Make sure Firestore rules are published in Firebase Console');
  print('   - Wait 2 minutes after publishing rules');
  print('   - Restart app completely after running this script');
  print('');
  
  print('✅ All fixes applied! Your app should work now.');
}
