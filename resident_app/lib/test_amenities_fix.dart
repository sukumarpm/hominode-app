// lib/test_amenities_fix.dart
// Quick test to verify amenities fetch fix

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
  
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  print('🧪 AMENITIES FETCH FIX TEST');
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
  
  await testAmenitiesFetch();
  await testFieldValidation();
  
  print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  print('✅ All tests complete!');
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
}

/// Test 1: Fetch amenities using the fixed service
Future<void> testAmenitiesFetch() async {
  print('TEST 1: Amenities Fetch with Field Validation');
  print('─────────────────────────────────────────────\n');
  
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('❌ No user logged in');
      print('   Please log in first and run this test again\n');
      return;
    }
    
    print('✅ User logged in: ${user.uid}\n');
    
    // Fetch user data
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    
    if (!userDoc.exists) {
      print('❌ User document not found\n');
      return;
    }
    
    final userData = userDoc.data()!;
    print('📋 User Data:');
    print('   Name: ${userData['name']}');
    print('   Role: ${userData['role']}');
    print('   Admin ID: ${userData['adminId']}');
    print('   Building ID: ${userData['buildingId']}');
    print('   Flat ID: ${userData['flatId']}');
    print('   Flat Label: ${userData['flatLabel']}\n');
    
    // Fetch amenities using the service
    print('📥 Fetching amenities using BookingFirestoreService...\n');
    
    final service = BookingFirestoreService();
    final amenities = await service.getAmenities();
    
    print('\n📊 RESULTS:');
    print('   Total amenities fetched: ${amenities.length}\n');
    
    if (amenities.isEmpty) {
      print('⚠️  No amenities found!');
      print('   Possible reasons:');
      print('   1. No amenities in Firestore');
      print('   2. AdminId/BuildingId mismatch');
      print('   3. All amenities have isActive = false\n');
      
      // Check if any amenities exist at all
      final allAmenities = await FirebaseFirestore.instance
          .collection('amenities')
          .get();
      
      print('   Total amenities in Firestore: ${allAmenities.docs.length}');
      
      if (allAmenities.docs.isNotEmpty) {
        print('   Sample amenity data:');
        final sample = allAmenities.docs.first.data();
        print('   - Name: ${sample['name']}');
        print('   - Admin ID: ${sample['adminId']}');
        print('   - Building ID: ${sample['buildingId']}');
        print('   - Is Active: ${sample['isActive']}\n');
        
        print('   💡 Check if adminId and buildingId match your user data!\n');
      }
    } else {
      print('✅ Amenities fetched successfully!\n');
      
      for (var i = 0; i < amenities.length; i++) {
        final amenity = amenities[i];
        print('   ${i + 1}. ${amenity['name']}');
        print('      ID: ${amenity['id']}');
        print('      Price: ${amenity['price']}');
        print('      Icon: ${amenity['iconName']}');
        print('      Background: ${amenity['backgroundColor']}');
        print('      Icon Color: ${amenity['iconColor']}');
        print('      Available: ${amenity['isAvailable']}');
        print('      Open Time: ${amenity['openTime']}');
        print('      Close Time: ${amenity['closeTime']}');
        print('      Admin ID: ${amenity['adminId']}');
        print('      Building ID: ${amenity['buildingId']}\n');
      }
    }
  } catch (e, stackTrace) {
    print('❌ Error: $e');
    print('   Stack trace: $stackTrace\n');
  }
}

/// Test 2: Verify field validation works
Future<void> testFieldValidation() async {
  print('\nTEST 2: Field Validation Check');
  print('─────────────────────────────────────────────\n');
  
  try {
    print('📋 Checking if all required fields have defaults...\n');
    
    final service = BookingFirestoreService();
    final amenities = await service.getAmenities();
    
    if (amenities.isEmpty) {
      print('⚠️  No amenities to validate\n');
      return;
    }
    
    bool allFieldsValid = true;
    
    for (var amenity in amenities) {
      final requiredFields = [
        'id',
        'name',
        'price',
        'isAvailable',
        'iconName',
        'backgroundColor',
        'iconColor',
        'openTime',
        'closeTime'
      ];
      
      for (var field in requiredFields) {
        if (!amenity.containsKey(field) || amenity[field] == null) {
          print('❌ Missing field "$field" in amenity: ${amenity['name']}');
          allFieldsValid = false;
        }
      }
    }
    
    if (allFieldsValid) {
      print('✅ All amenities have required fields!');
      print('   Field validation is working correctly\n');
    } else {
      print('\n⚠️  Some amenities are missing required fields');
      print('   The service should have added defaults\n');
    }
    
    // Check for default values
    print('📋 Checking for default values...\n');
    
    for (var amenity in amenities) {
      if (amenity['name'] == 'Unknown Amenity') {
        print('⚠️  Found default name in amenity ${amenity['id']}');
      }
      if (amenity['price'] == 'Free') {
        print('⚠️  Found default price in amenity ${amenity['name']}');
      }
      if (amenity['iconName'] == 'apartment') {
        print('⚠️  Found default icon in amenity ${amenity['name']}');
      }
    }
    
    print('✅ Field validation test complete\n');
  } catch (e) {
    print('❌ Error: $e\n');
  }
}
