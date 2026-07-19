// lib/test_amenities_realtime.dart
// Test real-time amenities streaming

import 'package:flutter/widgets.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'src/services/booking_firestore_service.dart';
import 'dart:async';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  print('🔥 Initializing Firebase...');
  await Firebase.initializeApp();
  print('✅ Firebase initialized\n');
  
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  print('🧪 AMENITIES REAL-TIME STREAMING TEST');
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
  
  await testUserData();
  await testAmenitiesStream();
  await testBookingsStream();
  
  print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  print('✅ All tests complete!');
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
  
  // Keep running for 30 seconds to observe real-time updates
  print('⏱️  Keeping stream active for 30 seconds...');
  print('   Try updating data in Firebase Console to see real-time updates!\n');
  await Future.delayed(const Duration(seconds: 30));
  
  print('✅ Test complete!');
}

/// Test 1: Check user data
Future<void> testUserData() async {
  print('TEST 1: User Data Check');
  print('─────────────────────────────────────────────\n');
  
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('❌ No user logged in');
      print('   Please log in first\n');
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
    print('   Email: ${userData['email']}');
    print('   Role: ${userData['role']}');
    print('   Building ID: ${userData['buildingId']}');
    print('   Organization ID: ${userData['organizationId']}');
    print('   Flat ID: ${userData['flatId']}');
    print('   Flat Label: ${userData['flatLabel']}\n');
    
    if (userData['buildingId'] == null) {
      print('⚠️  WARNING: No buildingId found!');
      print('   Amenities will show all available amenities\n');
    } else {
      print('✅ Building ID found: ${userData['buildingId']}\n');
    }
  } catch (e) {
    print('❌ Error: $e\n');
  }
}

/// Test 2: Test amenities real-time stream
Future<void> testAmenitiesStream() async {
  print('\nTEST 2: Amenities Real-Time Stream');
  print('─────────────────────────────────────────────\n');
  
  try {
    final service = BookingFirestoreService();
    
    print('🔄 Starting amenities stream...\n');
    
    // Listen to stream for 10 seconds
    final subscription = service.streamAmenitiesRealtime().listen(
      (amenities) {
        print('\n📊 STREAM UPDATE:');
        print('   Received ${amenities.length} amenities\n');
        
        if (amenities.isEmpty) {
          print('   ⚠️  No amenities available');
          print('   Possible reasons:');
          print('   1. No amenities in Firestore');
          print('   2. BuildingId mismatch');
          print('   3. All amenities have isAvailable = false\n');
        } else {
          print('   ✅ Amenities:');
          for (var i = 0; i < amenities.length; i++) {
            final amenity = amenities[i];
            print('\n   ${i + 1}. ${amenity.name}');
            print('      Type: ${amenity.type}');
            print('      Price: ${amenity.priceDisplay}');
            print('      Time Slots: ${amenity.timeSlotsDisplay}');
            print('      Available: ${amenity.isAvailable}');
            print('      Building ID: ${amenity.buildingId}');
          }
        }
        print('\n   💡 Try updating amenities in Firebase Console!');
        print('   The stream will automatically show changes.\n');
      },
      onError: (error) {
        print('❌ Stream error: $error\n');
      },
    );
    
    // Wait 10 seconds
    await Future.delayed(const Duration(seconds: 10));
    
    // Cancel subscription
    await subscription.cancel();
    print('✅ Amenities stream test complete\n');
  } catch (e) {
    print('❌ Error: $e\n');
  }
}

/// Test 3: Test bookings real-time stream
Future<void> testBookingsStream() async {
  print('\nTEST 3: Bookings Real-Time Stream');
  print('─────────────────────────────────────────────\n');
  
  try {
    final service = BookingFirestoreService();
    
    print('🔄 Starting bookings stream...\n');
    
    // Listen to stream for 10 seconds
    final subscription = service.streamMyBookingsRealtime().listen(
      (bookings) {
        print('\n📊 STREAM UPDATE:');
        print('   Received ${bookings.length} bookings\n');
        
        if (bookings.isEmpty) {
          print('   ⚠️  No bookings found');
          print('   Book an amenity to see it here\n');
        } else {
          print('   ✅ Bookings:');
          for (var i = 0; i < bookings.length; i++) {
            final booking = bookings[i];
            print('\n   ${i + 1}. ${booking.amenityName}');
            print('      Date: ${booking.formattedDate}');
            print('      Time: ${booking.timeSlot}');
            print('      Status: ${booking.status}');
          }
        }
        print('\n   💡 Try creating/cancelling bookings in the app!');
        print('   The stream will automatically show changes.\n');
      },
      onError: (error) {
        print('❌ Stream error: $error\n');
      },
    );
    
    // Wait 10 seconds
    await Future.delayed(const Duration(seconds: 10));
    
    // Cancel subscription
    await subscription.cancel();
    print('✅ Bookings stream test complete\n');
  } catch (e) {
    print('❌ Error: $e\n');
  }
}
