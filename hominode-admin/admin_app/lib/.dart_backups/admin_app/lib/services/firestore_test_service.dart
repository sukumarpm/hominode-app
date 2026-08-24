import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Test service to verify Firestore connectivity and operations
class FirestoreTestService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Test 1: Check Firestore connection
  Future<void> testConnection() async {
    try {
      print('=== TEST 1: Firestore Connection ===');
      final testDoc = await _firestore.collection('_test').doc('connection').get();
      print('✅ Firestore connection successful');
      print('Document exists: ${testDoc.exists}');
    } catch (e) {
      print('❌ Firestore connection failed: $e');
    }
  }

  /// Test 2: List all collections
  Future<void> listCollections() async {
    try {
      print('\n=== TEST 2: List Collections ===');
      // Note: listCollections() is not available in client SDK
      // We'll try to read from known collections
      final collections = ['users', 'buildings', 'flats', 'complaints'];
      
      for (final collectionName in collections) {
        try {
          final snapshot = await _firestore.collection(collectionName).limit(1).get();
          print('✅ Collection "$collectionName" exists (${snapshot.docs.length} docs found)');
        } catch (e) {
          print('❌ Collection "$collectionName" error: $e');
        }
      }
    } catch (e) {
      print('❌ List collections failed: $e');
    }
  }

  /// Test 3: Read users collection
  Future<void> readUsersCollection() async {
    try {
      print('\n=== TEST 3: Read Users Collection ===');
      final snapshot = await _firestore.collection('users').get();
      print('✅ Users collection read successful');
      print('Total documents: ${snapshot.docs.length}');
      
      if (snapshot.docs.isNotEmpty) {
        print('\nFirst 3 documents:');
        for (var i = 0; i < snapshot.docs.length && i < 3; i++) {
          final doc = snapshot.docs[i];
          final data = doc.data();
          print('  Document ${i + 1}:');
          print('    ID: ${doc.id}');
          print('    Name: ${data['name'] ?? 'N/A'}');
          print('    Role: ${data['role'] ?? 'N/A'}');
          print('    Phone: ${data['phone'] ?? 'N/A'}');
          print('    Email: ${data['email'] ?? 'N/A'}');
          print('    FlatId: ${data['flatId'] ?? 'N/A'}');
        }
      } else {
        print('⚠️  Users collection is empty');
      }
    } catch (e) {
      print('❌ Read users collection failed: $e');
    }
  }

  /// Test 4: Write to users collection
  Future<void> writeTestUser() async {
    try {
      print('\n=== TEST 4: Write Test User ===');
      
      final testData = {
        'name': 'Test User ${DateTime.now().millisecondsSinceEpoch}',
        'phone': '9999999999',
        'email': 'test@example.com',
        'residentId': 'TEST${DateTime.now().millisecondsSinceEpoch}',
        'authEmail': 'test@example.com',
        'password': 'TestPass123',
        'role': 'resident',
        'flatId': null,
        'flatLabel': null,
        'ownershipType': null,
        'familyMembers': 1,
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      
      final docRef = await _firestore.collection('users').add(testData);
      print('✅ Test user created successfully');
      print('Document ID: ${docRef.id}');
      
      // Read it back
      final doc = await docRef.get();
      if (doc.exists) {
        print('✅ Test user verified in Firestore');
        print('Data: ${doc.data()}');
      }
      
      // Clean up - delete test user
      await docRef.delete();
      print('✅ Test user deleted');
      
    } catch (e) {
      print('❌ Write test user failed: $e');
      print('Error details: ${e.toString()}');
    }
  }

  /// Test 5: Query users with role filter
  Future<void> queryResidents() async {
    try {
      print('\n=== TEST 5: Query Residents ===');
      final snapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'resident')
          .get();
      
      print('✅ Query successful');
      print('Residents found: ${snapshot.docs.length}');
      
      if (snapshot.docs.isNotEmpty) {
        print('\nResident details:');
        for (var doc in snapshot.docs) {
          final data = doc.data();
          print('  - ${data['name']} (${data['phone']}) - FlatId: ${data['flatId'] ?? 'Not assigned'}');
        }
      }
    } catch (e) {
      print('❌ Query residents failed: $e');
    }
  }

  /// Test 6: Check Firebase Auth
  Future<void> testFirebaseAuth() async {
    try {
      print('\n=== TEST 6: Firebase Auth ===');
      final currentUser = _auth.currentUser;
      if (currentUser != null) {
        print('✅ User is authenticated');
        print('User ID: ${currentUser.uid}');
        print('Email: ${currentUser.email}');
      } else {
        print('⚠️  No user is currently authenticated');
      }
    } catch (e) {
      print('❌ Firebase Auth check failed: $e');
    }
  }

  /// Run all tests
  Future<void> runAllTests() async {
    print('\n╔════════════════════════════════════════════════════════╗');
    print('║         FIRESTORE CONNECTIVITY TEST SUITE             ║');
    print('╚════════════════════════════════════════════════════════╝\n');
    
    await testConnection();
    await listCollections();
    await readUsersCollection();
    await writeTestUser();
    await queryResidents();
    await testFirebaseAuth();
    
    print('\n╔════════════════════════════════════════════════════════╗');
    print('║                  TESTS COMPLETED                       ║');
    print('╚════════════════════════════════════════════════════════╝\n');
  }
}
