import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Enhanced UserService with comprehensive logging and error handling
/// This version helps debug Firestore connection and data fetching issues
class UserServiceEnhanced {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final String _collection = 'users';

  /// Test Firestore connection
  Future<bool> testConnection() async {
    try {
      print('=== TESTING FIRESTORE CONNECTION ===');
      final testDoc = await _firestore.collection(_collection).limit(1).get();
      print('✅ Firestore connection successful');
      print('📊 Collection "$_collection" has ${testDoc.docs.length} documents (showing first 1)');
      return true;
    } catch (e) {
      print('❌ Firestore connection FAILED: $e');
      return false;
    }
  }

  /// Get all users (residents) with detailed logging
  Stream<List<UserModel>> getUsers() {
    print('\n=== FETCHING ALL RESIDENTS ===');
    print('📍 Colle