// lib/diagnose_messages_members.dart
// Diagnostic: Debug why flat members are not showing in messages

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

void main() async {
  print('🔍 DIAGNOSTIC: Messages - Flat Members Not Showing');
  print('=' * 70);
  
  await diagnoseFlatMembers();
}

Future<void> diagnoseFlatMembers() async {
  try {
    final firestore = FirebaseFirestore.instance;
    final auth = FirebaseAuth.instance;
    
    // Step 1: Check current user
    print('\n📋 STEP 1: Check Current User');
    print('-' * 70);
    
    final currentUser = auth.currentUser;
    if (currentUser == null) {
      print('❌ No Firebase Auth user logged in');
      return;
    }
    
    print('✅ Firebase Auth User: ${currentUser.uid}');
    print('   Email: ${currentUser.email}');
    
    // Step 2: Find user document
    print('\n📋 STEP 2: Find User Document');
    print('-' * 70);
    
    final userQuery = await firestore
        .collection('users')
        .where('authUid', isEqualTo: currentUser.uid)
        .limit(1)
        .get();
    
    if (userQuery.docs.isEmpty) {
      print('❌ User document not found for authUid: ${currentUser.uid}');
      print('   Checking by document ID...');
      
      final userDoc = await firestore.collection('users').doc(currentUser.uid).get();
      if (!userDoc.exists) {
        print('❌ User document not found by ID either');
        return;
      }
      
      print('✅ Found user by ID: ${userDoc.id}');
      final userData = userDoc.data() as Map<String, dynamic>;
      _printUserData(userData, userDoc.id);
    } else {
      final userDoc = userQuery.docs.first;
      print('✅ Found user by authUid: ${userDoc.id}');
      final userData = userDoc.data();
      _printUserData(userData, userDoc.id);
    }
    
    // Step 3: Check building members
    print('\n📋 STEP 3: Check Building Members');
    print('-' * 70);
    
    final allUsers = await firestore.collection('users').get();
    print('📊 Total users in Firestore: ${allUsers.docs.length}');
    
    // Group by buildingId
    final Map<String, List<Map<String, dynamic>>> usersByBuilding = {};
    
    for (var doc in allUsers.docs) {
      final data = doc.data();
      final buildingId = data['buildingId'] as String?;
      final name = data['name'] as String?;
      final flatId = data['flatId'] as String?;
      
      if (buildingId != null) {
        if (!usersByBuilding.containsKey(buildingId)) {
          usersByBuilding[buildingId] = [];
        }
        usersByBuilding[buildingId]!.add({
          'id': doc.id,
          'name': name,
          'flatId': flatId,
          'authUid': data['authUid'],
        });
      }
    }
    
    print('\n📊 Users grouped by building:');
    for (var entry in usersByBuilding.entries) {
      print('\n🏢 Building: ${entry.key}');
      print('   Members: ${entry.value.length}');
      for (var user in entry.value) {
        print('   - ${user['name']} (ID: ${user['id']}, Flat: ${user['flatId']})');
      }
    }
    
    // Step 4: Check current user's building
    print('\n📋 STEP 4: Check Current User\'s Building');
    print('-' * 70);
    
    final currentUserQuery2 = await firestore
        .collection('users')
        .where('authUid', isEqualTo: currentUser.uid)
        .limit(1)
        .get();
    
    if (currentUserQuery2.docs.isEmpty) {
      print('❌ Could not find current user');
      return;
    }
    
    final currentUserData = currentUserQuery2.docs.first.data();
    final currentBuildingId = currentUserData['buildingId'] as String?;
    final currentFlatId = currentUserData['flatId'] as String?;
    
    print('✅ Current User:');
    print('   Name: ${currentUserData['name']}');
    print('   Building ID: $currentBuildingId');
    print('   Flat ID: $currentFlatId');
    
    if (currentBuildingId == null) {
      print('\n❌ ISSUE: Current user has no buildingId!');
      print('   This is why no members are showing');
      return;
    }
    
    // Step 5: Query members in same building
    print('\n📋 STEP 5: Query Members in Same Building');
    print('-' * 70);
    
    final buildingMembers = await firestore
        .collection('users')
        .where('buildingId', isEqualTo: currentBuildingId)
        .get();
    
    print('📊 Members in building "$currentBuildingId": ${buildingMembers.docs.length}');
    
    for (var doc in buildingMembers.docs) {
      final data = doc.data();
      final isCurrentUser = data['authUid'] == currentUser.uid;
      print('\n${isCurrentUser ? '👤' : '👥'} ${data['name']}');
      print('   ID: ${doc.id}');
      print('   Flat: ${data['flatId']}');
      print('   authUid: ${data['authUid']}');
      if (isCurrentUser) {
        print('   (This is the current user - should be excluded)');
      }
    }
    
    // Step 6: Check if there are other members
    print('\n📋 STEP 6: Analysis');
    print('-' * 70);
    
    final otherMembers = buildingMembers.docs
        .where((doc) => doc.data()['authUid'] != currentUser.uid)
        .toList();
    
    if (otherMembers.isEmpty) {
      print('⚠️  NO OTHER MEMBERS FOUND');
      print('   This is why the message shows "No other members in your flat"');
      print('\n   Possible reasons:');
      print('   1. You are the only user in this building');
      print('   2. Other users have not been created yet');
      print('   3. Other users have a different buildingId');
    } else {
      print('✅ FOUND ${otherMembers.length} OTHER MEMBER(S)');
      print('   These should appear in the messages screen');
      for (var doc in otherMembers) {
        final data = doc.data();
        print('   - ${data['name']}');
      }
    }
    
  } catch (e) {
    print('❌ Error: $e');
    print('   Stack trace: ${StackTrace.current}');
  }
}

void _printUserData(Map<String, dynamic> userData, String userId) {
  print('✅ User Document Found:');
  print('   ID: $userId');
  print('   Name: ${userData['name']}');
  print('   Email: ${userData['email']}');
  print('   Phone: ${userData['phone']}');
  print('   buildingId: ${userData['buildingId']}');
  print('   buildingName: ${userData['buildingName']}');
  print('   flatId: ${userData['flatId']}');
  print('   flatLabel: ${userData['flatLabel']}');
  print('   flatNumber: ${userData['flatNumber']}');
  print('   authUid: ${userData['authUid']}');
}
