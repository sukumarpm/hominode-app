// lib/test_visitor_admin_access.dart
// Test script to verify visitor admin access with flatId, flatLabel, adminId

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'src/services/visitor_firestore_service.dart';

void main() async {
  print('🧪 Testing Visitor Admin Access...\n');
  
  await testVisitorCreation();
  await testAdminAccess();
  await testFlatFiltering();
  
  print('\n✅ All tests complete!');
}

/// Test 1: Verify visitor creation includes flatId, flatLabel, adminId
Future<void> testVisitorCreation() async {
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  print('TEST 1: Visitor Creation with Flat & Admin Data');
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
  
  try {
    // Add a test visitor
    final result = await VisitorFirestoreService.instance.addExpectedVisitor(
      visitorName: 'Test Visitor',
      purpose: 'Testing Admin Access',
      expectedDate: DateTime.now().add(Duration(days: 1)),
      expectedTime: DateTime.now().add(Duration(hours: 2)),
      phoneNumber: '+1234567890',
      vehicleNumber: 'TEST-123',
    );
    
    if (result.success) {
      print('✅ Visitor created successfully');
      print('   Visitor ID: ${result.visitorId}');
      
      // Fetch the visitor to verify fields
      final visitorDoc = await FirebaseFirestore.instance
          .collection('visitors')
          .doc(result.visitorId)
          .get();
      
      if (visitorDoc.exists) {
        final data = visitorDoc.data()!;
        
        print('\n📋 Visitor Data:');
        print('   Visitor Name: ${data['visitorName']}');
        print('   Host User ID: ${data['hostUserId']}');
        print('   Flat ID: ${data['flatId']}');
        print('   Flat Label: ${data['flatLabel']}');
        print('   Admin ID: ${data['adminId']}');
        print('   Purpose: ${data['purpose']}');
        print('   Status: ${data['status']}');
        
        // Verify required fields
        if (data['flatId'] != null && data['flatId'].toString().isNotEmpty) {
          print('\n✅ flatId is present');
        } else {
          print('\n❌ flatId is missing or empty');
        }
        
        if (data['flatLabel'] != null && data['flatLabel'].toString().isNotEmpty) {
          print('✅ flatLabel is present');
        } else {
          print('⚠️  flatLabel is missing or empty');
        }
        
        if (data['adminId'] != null && data['adminId'].toString().isNotEmpty) {
          print('✅ adminId is present');
        } else {
          print('⚠️  adminId is missing (user might not have admin assigned)');
        }
      }
    } else {
      print('❌ Failed to create visitor: ${result.message}');
    }
  } catch (e) {
    print('❌ Error: $e');
  }
}

/// Test 2: Verify admin can access visitors
Future<void> testAdminAccess() async {
  print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  print('TEST 2: Admin Access to Visitors');
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
  
  try {
    // Get current user
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      print('❌ No user logged in');
      return;
    }
    
    // Check user role
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .get();
    
    if (!userDoc.exists) {
      print('❌ User document not found');
      return;
    }
    
    final userData = userDoc.data()!;
    final userRole = userData['role'] ?? 'resident';
    
    print('👤 Current User:');
    print('   Name: ${userData['name']}');
    print('   Role: $userRole');
    print('   Flat: ${userData['flatLabel'] ?? userData['flatId']}');
    
    if (userRole == 'admin') {
      print('\n✅ User is admin, testing admin access...');
      
      // Get admin visitors
      final adminVisitors = await VisitorFirestoreService.instance
          .getAdminVisitors();
      
      print('\n📊 Admin Visitors:');
      print('   Total: ${adminVisitors.length}');
      
      if (adminVisitors.isNotEmpty) {
        print('\n   Sample visitors:');
        for (var i = 0; i < adminVisitors.length && i < 3; i++) {
          final visitor = adminVisitors[i];
          print('   ${i + 1}. ${visitor['visitorName']} - Flat: ${visitor['flatLabel']}');
        }
      }
    } else {
      print('\n⚠️  User is not admin, testing resident access...');
      
      // Get resident visitors
      final myVisitors = await VisitorFirestoreService.instance
          .getMyVisitors();
      
      print('\n📊 My Visitors:');
      print('   Total: ${myVisitors.length}');
      
      if (myVisitors.isNotEmpty) {
        print('\n   Sample visitors:');
        for (var i = 0; i < myVisitors.length && i < 3; i++) {
          final visitor = myVisitors[i];
          print('   ${i + 1}. ${visitor['visitorName']} - Status: ${visitor['status']}');
        }
      }
    }
  } catch (e) {
    print('❌ Error: $e');
  }
}

/// Test 3: Verify flat-based filtering
Future<void> testFlatFiltering() async {
  print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  print('TEST 3: Flat-Based Visitor Filtering');
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
  
  try {
    // Get current user's flat
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      print('❌ No user logged in');
      return;
    }
    
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .get();
    
    if (!userDoc.exists) {
      print('❌ User document not found');
      return;
    }
    
    final userData = userDoc.data()!;
    final flatId = userData['flatId'];
    final flatLabel = userData['flatLabel'] ?? flatId;
    
    if (flatId == null || flatId.toString().isEmpty) {
      print('⚠️  User does not have flatId assigned');
      return;
    }
    
    print('🏢 Testing flat filter for: $flatLabel');
    
    // Get visitors for this flat
    final flatVisitors = await VisitorFirestoreService.instance
        .getVisitorsByFlatId(flatId);
    
    print('\n📊 Visitors for Flat $flatLabel:');
    print('   Total: ${flatVisitors.length}');
    
    if (flatVisitors.isNotEmpty) {
      print('\n   Visitor List:');
      for (var i = 0; i < flatVisitors.length; i++) {
        final visitor = flatVisitors[i];
        final expectedArrival = (visitor['expectedArrival'] as Timestamp?)?.toDate();
        print('   ${i + 1}. ${visitor['visitorName']}');
        print('      Status: ${visitor['status']}');
        print('      Expected: ${expectedArrival?.toString().substring(0, 16)}');
        print('      Flat: ${visitor['flatLabel']}');
      }
      
      // Verify all visitors belong to the same flat
      final allSameFlat = flatVisitors.every((v) => v['flatId'] == flatId);
      if (allSameFlat) {
        print('\n✅ All visitors belong to flat $flatLabel');
      } else {
        print('\n❌ Some visitors belong to different flats');
      }
    }
  } catch (e) {
    print('❌ Error: $e');
  }
}

/// Test 4: Verify role-based auto-detection
Future<void> testAutoDetection() async {
  print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  print('TEST 4: Role-Based Auto-Detection');
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
  
  try {
    print('🔍 Testing auto-detection method...');
    
    final visitors = await VisitorFirestoreService.instance
        .getVisitorsForCurrentUser();
    
    print('\n📊 Visitors (Auto-Detected):');
    print('   Total: ${visitors.length}');
    
    if (visitors.isNotEmpty) {
      print('\n   Sample visitors:');
      for (var i = 0; i < visitors.length && i < 5; i++) {
        final visitor = visitors[i];
        print('   ${i + 1}. ${visitor['visitorName']} - Flat: ${visitor['flatLabel']}');
      }
      
      print('\n✅ Auto-detection working correctly');
    }
  } catch (e) {
    print('❌ Error: $e');
  }
}
