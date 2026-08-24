// Test Login Debug Script
// Run this to diagnose the login issue

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  print('🔍 Login Debug Test\n');
  
  await Firebase.initializeApp();
  
  // Test credentials from your screenshot
  final testPhone = '7010678124';
  final testEmail = 'preethampriyadharshan07@gmail.com';
  final testPassword = '121456';
  
  print('Testing with:');
  print('Phone: $testPhone');
  print('Email: $testEmail');
  print('Password: $testPassword\n');
  
  // Test 1: Check Firestore user document
  print('📋 Test 1: Checking Firestore user document...');
  try {
    final firestore = FirebaseFirestore.instance;
    
    // Query by phone
    print('Querying by phone: $testPhone');
    final phoneQuery = await firestore
        .collection('users')
        .where('phone', isEqualTo: testPhone)
        .limit(1)
        .get();
    
    if (phoneQuery.docs.isEmpty) {
      print('❌ No user found with phone: $testPhone');
      
      // Try to find what phone values exist
      print('\n🔍 Checking all users to see phone formats...');
      final allUsers = await firestore.collection('users').limit(5).get();
      for (var doc in allUsers.docs) {
        final data = doc.data();
        print('  User ${doc.id}:');
        print('    phone: ${data['phone']} (type: ${data['phone'].runtimeType})');
        print('    email: ${data['email']}');
      }
    } else {
      print('✅ Found user with phone: $testPhone');
      final userData = phoneQuery.docs.first.data();
      print('User data:');
      print('  email: ${userData['email']}');
      print('  phone: ${userData['phone']}');
      print('  name: ${userData['name']}');
    }
  } catch (e) {
    print('❌ Firestore error: $e');
  }
  
  print('\n📋 Test 2: Trying direct email login...');
  try {
    final auth = FirebaseAuth.instance;
    final userCredential = await auth.signInWithEmailAndPassword(
      email: testEmail,
      password: testPassword,
    );
    
    if (userCredential.user != null) {
      print('✅ Direct email login successful!');
      print('User ID: ${userCredential.user!.uid}');
      print('Email: ${userCredential.user!.email}');
      
      // Sign out
      await auth.signOut();
    }
  } on FirebaseAuthException catch (e) {
    print('❌ Email login failed: ${e.code} - ${e.message}');
  }
  
  print('\n📋 Test 3: Testing phone number formats...');
  final variations = [
    testPhone,
    '+91$testPhone',
    '0$testPhone',
    testPhone.replaceAll(RegExp(r'[\s()-]'), ''),
  ];
  
  for (var phoneVariation in variations) {
    print('Trying: $phoneVariation');
    try {
      final query = await FirebaseFirestore.instance
          .collection('users')
          .where('phone', isEqualTo: phoneVariation)
          .limit(1)
          .get();
      
      if (query.docs.isNotEmpty) {
        print('  ✅ Found match!');
      } else {
        print('  ❌ No match');
      }
    } catch (e) {
      print('  ❌ Error: $e');
    }
  }
  
  print('\n✅ Debug test complete!');
}
