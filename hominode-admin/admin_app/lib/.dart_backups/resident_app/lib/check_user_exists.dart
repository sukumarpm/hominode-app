// Quick check to see if user exists in Firebase Auth and Firestore
// Run: flutter run lib/check_user_exists.dart -d chrome

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  print('🔍 Checking User Status\n');
  
  await Firebase.initializeApp();
  
  final testEmail = 'preethampriyadharshan07@gmail.com';
  final testPhone = '7010678124';
  final testPassword = '121456';
  
  print('Checking for:');
  print('Email: $testEmail');
  print('Phone: $testPhone\n');
  
  // Check 1: Firebase Authentication
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  print('CHECK 1: Firebase Authentication');
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  
  try {
    // Try to sign in
    final userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: testEmail,
      password: testPassword,
    );
    
    print('✅ User EXISTS in Firebase Auth');
    print('   UID: ${userCredential.user!.uid}');
    print('   Email: ${userCredential.user!.email}');
    print('   Email Verified: ${userCredential.user!.emailVerified}');
    
    // Sign out
    await FirebaseAuth.instance.signOut();
    
  } on FirebaseAuthException catch (e) {
    if (e.code == 'user-not-found') {
      print('❌ User DOES NOT EXIST in Firebase Auth');
      print('   Error: No user found with this email');
      print('   Action: Run create_firebase_user.dart to create the account');
    } else if (e.code == 'wrong-password') {
      print('⚠️  User EXISTS but PASSWORD IS WRONG');
      print('   Error: The password you provided is incorrect');
      print('   Action: Check the password or reset it');
    } else if (e.code == 'invalid-credential') {
      print('❌ INVALID CREDENTIALS');
      print('   Error: ${e.message}');
      print('   Action: User might not exist or password is wrong');
    } else {
      print('❌ Firebase Auth Error: ${e.code}');
      print('   Message: ${e.message}');
    }
  }
  
  print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  print('CHECK 2: Firestore Database');
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  
  try {
    // Check by email
    print('\nSearching by email...');
    final emailQuery = await FirebaseFirestore.instance
        .collection('users')
        .where('email', isEqualTo: testEmail)
        .limit(1)
        .get();
    
    if (emailQuery.docs.isNotEmpty) {
      print('✅ Found user by email');
      final doc = emailQuery.docs.first;
      final data = doc.data();
      print('   Document ID: ${doc.id}');
      print('   Name: ${data['name']}');
      print('   Email: ${data['email']}');
      print('   Phone: ${data['phone']}');
      print('   Flat: ${data['flatLabel']}');
      print('   Role: ${data['role']}');
    } else {
      print('❌ No user found by email in Firestore');
    }
    
    // Check by phone
    print('\nSearching by phone...');
    final phoneQuery = await FirebaseFirestore.instance
        .collection('users')
        .where('phone', isEqualTo: testPhone)
        .limit(1)
        .get();
    
    if (phoneQuery.docs.isNotEmpty) {
      print('✅ Found user by phone');
      final doc = phoneQuery.docs.first;
      final data = doc.data();
      print('   Document ID: ${doc.id}');
      print('   Name: ${data['name']}');
      print('   Email: ${data['email']}');
      print('   Phone: ${data['phone']}');
    } else {
      print('❌ No user found by phone in Firestore');
    }
    
  } catch (e) {
    print('❌ Firestore Error: $e');
  }
  
  print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  print('CHECK 3: Phone Format Variations');
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
  
  final phoneVariations = [
    testPhone,
    '+91$testPhone',
    '91$testPhone',
    '0$testPhone',
  ];
  
  for (var phone in phoneVariations) {
    try {
      final query = await FirebaseFirestore.instance
          .collection('users')
          .where('phone', isEqualTo: phone)
          .limit(1)
          .get();
      
      if (query.docs.isNotEmpty) {
        print('✅ Match found: $phone');
      } else {
        print('❌ No match: $phone');
      }
    } catch (e) {
      print('❌ Error checking $phone: $e');
    }
  }
  
  print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  print('SUMMARY & RECOMMENDATIONS');
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
  
  print('If user DOES NOT EXIST in Firebase Auth:');
  print('  → Run: flutter run lib/create_firebase_user.dart -d chrome\n');
  
  print('If user EXISTS but password is WRONG:');
  print('  → Reset password in Firebase Console');
  print('  → Or use Firebase password reset email\n');
  
  print('If user EXISTS in Firestore but NOT in Firebase Auth:');
  print('  → Run: flutter run lib/create_firebase_user.dart -d chrome');
  print('  → This will create the Firebase Auth account\n');
  
  print('If phone format doesn\'t match:');
  print('  → The code now handles multiple formats automatically');
  print('  → But you can update Firestore to use: $testPhone\n');
  
  print('✅ Check complete!');
}
