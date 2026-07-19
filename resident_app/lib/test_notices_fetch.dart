// Test script to verify notices can be fetched from Firestore
// Run this to debug the notifications issue

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

Future<void> testNoticesFetch() async {
  print('========================================');
  print('TESTING NOTICES FETCH');
  print('========================================');
  
  try {
    // Check auth
    final user = FirebaseAuth.instance.currentUser;
    print('1. Current user: ${user?.uid ?? "NOT LOGGED IN"}');
    print('   Email: ${user?.email ?? "N/A"}');
    
    if (user == null) {
      print('❌ ERROR: No user logged in!');
      return;
    }
    
    // Test Firestore connection
    print('\n2. Testing Firestore connection...');
    final testDoc = await FirebaseFirestore.instance
        .collection('notices')
        .limit(1)
        .get();
    print('✅ Firestore connection OK');
    print('   Documents in notices collection: ${testDoc.docs.length}');
    
    // Fetch all notices
    print('\n3. Fetching ALL notices...');
    final snapshot = await FirebaseFirestore.instance
        .collection('notices')
        .get();
    
    print('✅ Found ${snapshot.docs.length} total documents');
    
    // Print each notice
    for (var doc in snapshot.docs) {
      print('\n📄 Notice ID: ${doc.id}');
      final data = doc.data();
      print('   Fields: ${data.keys.toList()}');
      print('   title: ${data['title']}');
      print('   content: ${data['content']}');
      print('   status: ${data['status']}');
      print('   isActive: ${data['isActive']}');
      print('   publishedAt: ${data['publishedAt']}');
      print('   expiresAt: ${data['expiresAt']}');
      print('   targetFlats: ${data['targetFlats']}');
      
      // Check if it should be shown
      final isActive = data['status'] == 'published' || data['isActive'] == true;
      print('   Should show: $isActive');
      
      if (data['expiresAt'] != null) {
        final expiresAt = (data['expiresAt'] as Timestamp).toDate();
        final isExpired = DateTime.now().isAfter(expiresAt);
        print('   Expires: $expiresAt');
        print('   Is expired: $isExpired');
      }
    }
    
    print('\n========================================');
    print('TEST COMPLETE');
    print('========================================');
    
  } catch (e, stackTrace) {
    print('❌ ERROR: $e');
    print('Stack trace: $stackTrace');
  }
}
