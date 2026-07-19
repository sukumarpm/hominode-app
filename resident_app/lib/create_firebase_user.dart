// lib/create_firebase_user.dart
// Run this ONCE to create the user in Firebase Authentication
// Command: flutter run lib/create_firebase_user.dart -d chrome

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> main() async {
  print('🔵 Starting user creation in Firebase Auth...');
  
  try {
    // Initialize Firebase (will use default configuration)
    await Firebase.initializeApp();
    print('✅ Firebase initialized');
    
    // User details from your Firestore (from screenshot)
    const email = 'preethampriyadharshan07@gmail.com';
    const password = '121456';
    const phone = '7010678124';
    const name = 'Preetham';
    
    print('📧 Creating user with email: $email');
    
    // Create user in Firebase Auth
    final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    
    print('✅ User created in Firebase Auth!');
    print('🆔 UID: ${userCredential.user?.uid}');
    print('📧 Email: ${userCredential.user?.email}');
    
    // Update the existing Firestore document with the correct UID
    final uid = userCredential.user!.uid;
    
    // Get the old document
    final oldDocs = await FirebaseFirestore.instance
        .collection('users')
        .where('email', isEqualTo: email)
        .get();
    
    if (oldDocs.docs.isNotEmpty) {
      final oldData = oldDocs.docs.first.data();
      final oldDocId = oldDocs.docs.first.id;
      
      print('📦 Found existing Firestore document: $oldDocId');
      
      // Create new document with correct UID
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        ...oldData,
        'uid': uid,
        'authUid': uid,
        'email': email,
        'phone': phone,
        'name': name,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      print('✅ Created new Firestore document with correct UID: $uid');
      
      // Delete old document
      await FirebaseFirestore.instance.collection('users').doc(oldDocId).delete();
      print('✅ Deleted old Firestore document: $oldDocId');
    } else {
      // Create new Firestore document
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'uid': uid,
        'authUid': uid,
        'email': email,
        'phone': phone,
        'name': name,
        'role': 'resident',
        'status': 'active',
        'flatId': 'b202',
        'flatLabel': 'b202',
        'residentId': 'RBS2393',
        'familyMembers': 2,
        'ownershipType': 'Owner',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      print('✅ Created new Firestore document: $uid');
    }
    
    // Sign out
    await FirebaseAuth.instance.signOut();
    print('✅ User signed out');
    
    print('\n🎉 SUCCESS! User created successfully!');
    print('📱 You can now login with:');
    print('   Email: $email');
    print('   Phone: $phone');
    print('   Password: $password');
    
  } catch (e) {
    if (e.toString().contains('email-already-in-use')) {
      print('✅ User already exists in Firebase Auth!');
      print('📱 You can login with:');
      print('   Email: preethampriyadharshan07@gmail.com');
      print('   Phone: 7010678124');
      print('   Password: 121456');
    } else {
      print('❌ Error: $e');
    }
  }
}
