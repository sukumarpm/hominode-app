// lib/verify_firestore_indexes.dart
// Verify that Firestore indexes are created and working

import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  print('═══════════════════════════════════════════════════');
  print('🔍 FIRESTORE INDEXES VERIFICATION');
  print('═══════════════════════════════════════════════════\n');

  final firestore = FirebaseFirestore.instance;

  // Test 1: Chats Index
  print('📋 TEST 1: Chats Collection Index');
  print('   Collection: chats');
  print('   Fields: participantIds (Array), updatedAt (Descending)');
  print('   Query: where("participantIds", arrayContains: userId)');
  print('          .orderBy("updatedAt", descending: true)');
  print('');

  try {
    // This query requires the index
    final chatsQuery = firestore
        .collection('chats')
        .where('participantIds', arrayContains: 'test-user-id')
        .orderBy('updatedAt', descending: true)
        .limit(1);

    final snapshot = await chatsQuery.get();
    print('   ✅ Chats index is working!');
    print('   📊 Found ${snapshot.docs.length} documents\n');
  } catch (e) {
    print('   ❌ Chats index error: $e\n');
  }

  // Test 2: Chat Requests Index
  print('📋 TEST 2: Chat Requests Collection Index');
  print('   Collection: chatRequests');
  print('   Fields: receiverId (Asc), status (Asc), createdAt (Desc)');
  print('   Query: where("receiverId", isEqualTo: userId)');
  print('          .where("status", isEqualTo: "pending")');
  print('          .orderBy("createdAt", descending: true)');
  print('');

  try {
    // This query requires the index
    final requestsQuery = firestore
        .collection('chatRequests')
        .where('receiverId', isEqualTo: 'test-user-id')
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .limit(1);

    final snapshot = await requestsQuery.get();
    print('   ✅ Chat Requests index is working!');
    print('   📊 Found ${snapshot.docs.length} documents\n');
  } catch (e) {
    print('   ❌ Chat Requests index error: $e\n');
  }

  print('═══════════════════════════════════════════════════');
  print('✅ VERIFICATION COMPLETE');
  print('═══════════════════════════════════════════════════');
}
