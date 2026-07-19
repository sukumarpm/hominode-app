// Create Firebase Auth User - Run this FIRST before login
// Command: flutter run lib/create_auth_user_now.dart -d chrome

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  print('\n╔════════════════════════════════════════════════════════╗');
  print('║   CREATE FIREBASE AUTH USER                            ║');
  print('╚════════════════════════════════════════════════════════╝\n');
  
  try {
    await Firebase.initializeApp();
    print('✅ Firebase initialized\n');
    
    // Your credentials from Firestore
    const email = 'preethampriyadharshan07@gmail.com';
    const password = '121456';
    const phone = '7010678124';
    
    print('Creating user with:');
    print('  Email: $email');
    print('  Password: $password');
    print('  Phone: $phone\n');
    
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    
    // Step 1: Check if user already exists
    print('STEP 1: Checking if user exists in Firebase Auth...');
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      print('✅ User already exists and password is correct!');
      print('   You can login now with:');
      print('   Phone: $phone');
      print('   Password: $password\n');
      
      await FirebaseAuth.instance.signOut();
      
      print('╔════════════════════════════════════════════════════════╗');
      print('║   ✅ SUCCESS - USER READY TO LOGIN                     ║');
      print('╚════════════════════════════════════════════════════════╝\n');
      return;
      
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' || e.code == 'invalid-credential') {
        print('ℹ️  User does not exist. Creating now...\n');
      } else if (e.code == 'wrong-password') {
        print('⚠️  User exists but password is different!');
        print('   Deleting old user and creating new one...\n');
        
        // Delete the old user (requires admin SDK in production)
        // For now, just inform the user
        print('❌ ERROR: User exists with different password');
        print('   Please go to Firebase Console and:');
        print('   1. Go to Authentication > Users');
        print('   2. Find user: $email');
        print('   3. Delete the user');
        print('   4. Run this script again\n');
        return;
      } else {
        print('❌ Error checking user: ${e.code} - ${e.message}\n');
        return;
      }
    }
    
    // Step 2: Create user in Firebase Auth
    print('STEP 2: Creating user in Firebase Authentication...');
    UserCredential userCredential;
    try {
      userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      print('✅ User created successfully!');
      print('   UID: ${userCredential.user!.uid}\n');
      
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        print('⚠️  Email already in use. Trying to sign in...');
        userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
        print('✅ Signed in successfully!\n');
      } else {
        print('❌ Error creating user: ${e.code} - ${e.message}\n');
        return;
      }
    }
    
    final uid = userCredential.user!.uid;
    
    // Step 3: Update/Create Firestore document
    print('STEP 3: Syncing with Firestore database...');
    
    // Check if document exists with this email
    final existingDocs = await FirebaseFirestore.instance
        .collection('users')
        .where('email', isEqualTo: email)
        .get();
    
    if (existingDocs.docs.isNotEmpty) {
      final oldDoc = existingDocs.docs.first;
      final oldData = oldDoc.data();
      final oldDocId = oldDoc.id;
      
      print('   Found existing Firestore document: $oldDocId');
      
      if (oldDocId != uid) {
        print('   Document ID mismatch. Creating new document with correct UID...');
        
        // Create new document with correct UID
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          ...oldData,
          'uid': uid,
          'authUid': uid,
          'email': email,
          'phone': phone,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        
        print('   ✅ Created new document: $uid');
        
        // Delete old document
        await FirebaseFirestore.instance.collection('users').doc(oldDocId).delete();
        print('   ✅ Deleted old document: $oldDocId');
      } else {
        print('   ✅ Document already has correct UID');
        
        // Just update the document
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'uid': uid,
          'authUid': uid,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        print('   ✅ Updated document');
      }
    } else {
      print('   No existing document found. Creating new one...');
      
      // Create new document
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'uid': uid,
        'authUid': uid,
        'email': email,
        'phone': phone,
        'name': 'Preetham',
        'role': 'resident',
        'status': 'active',
        'flatId': '1402',
        'flatLabel': '1402',
        'residentId': 'RES1046',
        'familyMembers': 4,
        'ownershipType': 'Owner',
        'password': password,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      print('   ✅ Created new document: $uid');
    }
    
    // Sign out
    await FirebaseAuth.instance.signOut();
    
    print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    print('╔════════════════════════════════════════════════════════╗');
    print('║   ✅ SUCCESS - USER CREATED SUCCESSFULLY               ║');
    print('╚════════════════════════════════════════════════════════╝\n');
    
    print('You can now login with:\n');
    print('  📱 Phone: $phone');
    print('  📧 Email: $email');
    print('  🔑 Password: $password\n');
    
    print('Next steps:');
    print('  1. Run your app: flutter run');
    print('  2. Enter phone: $phone');
    print('  3. Enter password: $password');
    print('  4. Click Login\n');
    
  } catch (e) {
    print('\n❌ UNEXPECTED ERROR: $e\n');
    print('Please check:');
    print('  1. Firebase is configured correctly');
    print('  2. Internet connection is working');
    print('  3. firebase_options.dart exists\n');
  }
}
