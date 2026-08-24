// lib/test_amenities_fetch.dart
// Test script to debug amenities fetching

import 'package:flutter/widgets.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'src/services/booking_firestore_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  print('🔥 Initializing Firebase...');
  await Firebase.initializeApp();
  print('✅ Firebase initialized\n');
  
  print('🧪 Testing Amenities Fetch...\n');
  
  await testUserData();
  await testAmenitiesFetch();
  await testDirectFirestoreQuery();
  
  print('\n✅ All tests complete!');
}

/// Test 1: Check user data and adminId
Future<void> testUserData() async {
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  print('TEST 1: User Data & AdminId');
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
  
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('❌ No user logged in');
      return;
    }
    
    print('✅ User logged in: ${user.uid}');
    
    // Fetch user data
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    
    if (!userDoc.exists) {
      print('❌ User document not found');
      return;
    }
    
    final userData = userDoc.data()!;
    print('\n📋 User Data:');
    print('   Name: ${userData['name']}');
    print('   Email: ${userData['email']}');
    print('   Role: ${userData['role']}');
    print('   Flat ID: ${userData['flatId']}');
    print('   Flat Label: ${userData['flatLabel']}');
    print('   Admin ID: ${userData['adminId']}');
    
    if (userData['adminId'] == null || userData['adminId'].toString().isEmpty) {
      print('\n⚠️  WARNING: User has no adminId assigned!');
      print('   This means amenities query will fetch all active amenities');
    } else {
      print('\n✅ User has adminId: ${userData['adminId']}');
    }
  } catch (e) {
    print('❌ Error: $e');
  }
}

/// Test 2: Test amenities fetch using service
Future<void> testAmenitiesFetch() async {
  print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  print('TEST 2: Amenities Fetch via Service');
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
  
  try {
    print('📥 Calling BookingFirestoreService().getAmenities()...');
    
    final amenities = await BookingFirestoreService().getAmenities();
    
    print('\n📊 Result:');
    print('   Total amenities: ${amenities.length}');
    
    if (amenities.isEmpty) {
      print('\n❌ No amenities found!');
      print('   Possible reasons:');
      print('   1. No amenities in Firestore');
      print('   2. AdminId mismatch');
      print('   3. All amenities have isActive = false');
      print('   4. Firestore security rules blocking access');
    } else {
      print('\n✅ Amenities found:');
      for (var i = 0; i < amenities.length; i++) {
        final amenity = amenities[i];
        print('\n   ${i + 1}. ${amenity['name']}');
        print('      ID: ${amenity['id']}');
        print('      Price: ${amenity['price']}');
        print('      Admin ID: ${amenity['adminId']}');
        print('      Is Active: ${amenity['isActive']}');
        print('      Icon: ${amenity['iconName']}');
        print('      Background: ${amenity['backgroundColor']}');
      }
    }
  } catch (e) {
    print('❌ Error fetching amenities: $e');
    print('   Stack trace: ${StackTrace.current}');
  }
}

/// Test 3: Direct Firestore query to check data
Future<void> testDirectFirestoreQuery() async {
  print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  print('TEST 3: Direct Firestore Query');
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
  
  try {
    // Test 1: Get ALL amenities (no filter)
    print('📥 Querying ALL amenities...');
    final allSnapshot = await FirebaseFirestore.instance
        .collection('amenities')
        .get();
    
    print('   Total documents in collection: ${allSnapshot.docs.length}');
    
    if (allSnapshot.docs.isEmpty) {
      print('\n❌ No amenities in Firestore at all!');
      print('   You need to add amenities to the "amenities" collection');
      return;
    }
    
    // Show all amenities
    print('\n📋 All Amenities in Firestore:');
    for (var doc in allSnapshot.docs) {
      final data = doc.data();
      print('\n   Document ID: ${doc.id}');
      print('   Name: ${data['name']}');
      print('   Admin ID: ${data['adminId']}');
      print('   Is Active: ${data['isActive']}');
      print('   Price: ${data['price']}');
    }
    
    // Test 2: Get only active amenities
    print('\n📥 Querying ACTIVE amenities...');
    final activeSnapshot = await FirebaseFirestore.instance
        .collection('amenities')
        .where('isActive', isEqualTo: true)
        .get();
    
    print('   Active amenities: ${activeSnapshot.docs.length}');
    
    // Test 3: Get amenities by adminId
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      
      final adminId = userDoc.data()?['adminId'];
      
      if (adminId != null && adminId.toString().isNotEmpty) {
        print('\n📥 Querying amenities for adminId: $adminId...');
        final adminSnapshot = await FirebaseFirestore.instance
            .collection('amenities')
            .where('adminId', isEqualTo: adminId)
            .where('isActive', isEqualTo: true)
            .get();
        
        print('   Amenities for this admin: ${adminSnapshot.docs.length}');
        
        if (adminSnapshot.docs.isEmpty) {
          print('\n⚠️  No amenities found for adminId: $adminId');
          print('   Make sure amenities have the correct adminId field');
        }
      }
    }
  } catch (e) {
    print('❌ Error in direct query: $e');
  }
}

/// Test 4: Check Firestore security rules
Future<void> testSecurityRules() async {
  print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  print('TEST 4: Security Rules Check');
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
  
  try {
    print('🔒 Testing read access to amenities collection...');
    
    final snapshot = await FirebaseFirestore.instance
        .collection('amenities')
        .limit(1)
        .get();
    
    if (snapshot.docs.isNotEmpty) {
      print('✅ Read access granted - security rules allow reading');
    } else {
      print('⚠️  No documents returned (might be empty collection)');
    }
  } catch (e) {
    print('❌ Security rules might be blocking access!');
    print('   Error: $e');
    print('\n   Suggested security rule for testing:');
    print('   match /amenities/{amenityId} {');
    print('     allow read: if request.auth != null;');
    print('   }');
  }
}
