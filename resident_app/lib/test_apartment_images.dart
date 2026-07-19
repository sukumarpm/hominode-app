import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'src/services/apartment_images_service.dart';

/// Test script to debug apartment images fetching
void main() async {
  print('🔵 Starting apartment images test...\n');

  try {
    // Check Firebase Auth
    final currentUser = FirebaseAuth.instance.currentUser;
    print('📱 Current User: ${currentUser?.uid}');
    print('📧 Email: ${currentUser?.email}\n');

    if (currentUser == null) {
      print('❌ No user logged in. Please login first.');
      return;
    }

    // Check SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final buildingId = prefs.getString('building_id');
    print('💾 Building ID in SharedPreferences: $buildingId\n');

    // Check user document
    print('🔍 Checking user document...');
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .get();

    if (userDoc.exists) {
      print('✅ User document found');
      print('   Data: ${userDoc.data()}\n');
    } else {
      print('❌ User document not found\n');
    }

    // Check apartmentImages collection
    print('🔍 Checking apartmentImages collection...');
    final allImages = await FirebaseFirestore.instance
        .collection('apartmentImages')
        .get();

    print('✅ Total documents in apartmentImages: ${allImages.docs.length}');
    for (var doc in allImages.docs) {
      print('\n   Document ID: ${doc.id}');
      print('   Data: ${doc.data()}');
    }

    // Test the service
    print('\n\n🧪 Testing ApartmentImagesService...\n');
    final service = ApartmentImagesService();
    final result = await service.getApartmentImages();

    if (!result.success) {
      print('❌ Service error: ${result.message}');
      return;
    }

    final images = result.imageUrls ?? [];
    print('\n✅ Service returned ${images.length} images:');
    for (var url in images) {
      print('   - $url');
    }
  } catch (e, stackTrace) {
    print('❌ Error: $e');
    print('Stack trace: $stackTrace');
  }
}
