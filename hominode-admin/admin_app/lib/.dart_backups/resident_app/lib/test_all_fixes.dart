// lib/test_all_fixes.dart
// Comprehensive test for amenities and chat fixes

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'src/services/booking_firestore_service.dart';
import 'src/services/chat_firestore_service.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const AllFixesTestApp());
}

class AllFixesTestApp extends StatelessWidget {
  const AllFixesTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'All Fixes Test',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const AllFixesTestScreen(),
    );
  }
}

class AllFixesTestScreen extends StatefulWidget {
  const AllFixesTestScreen({super.key});

  @override
  State<AllFixesTestScreen> createState() => _AllFixesTestScreenState();
}

class _AllFixesTestScreenState extends State<AllFixesTestScreen> {
  final _bookingService = BookingFirestoreService();
  final _chatService = ChatFirestoreService();
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  
  String _status = 'Ready to test';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    setState(() {
      _status = 'Checking authentication status...';
      _isLoading = true;
    });

    try {
      final firebaseUser = _auth.currentUser;
      final prefs = await SharedPreferences.getInstance();
      final storedUserId = prefs.getString('user_id');

      String statusText = '📊 AUTHENTICATION STATUS\n\n';

      // Firebase Auth status
      if (firebaseUser != null) {
        statusText += '✅ Firebase Auth: Logged in\n';
        statusText += '   UID: ${firebaseUser.uid}\n';
        statusText += '   Email: ${firebaseUser.email ?? "N/A"}\n\n';

        // Check if user document exists
        final doc = await _firestore.collection('users').doc(firebaseUser.uid).get();
        if (doc.exists) {
          statusText += '✅ User document found by Firebase Auth UID\n';
          final userData = doc.data();
          statusText += '   Name: ${userData?['name']}\n';
          statusText += '   Flat: ${userData?['flatLabel'] ?? userData?['flatId']}\n';
          statusText += '   Role: ${userData?['role']}\n';
          statusText += '   Building: ${userData?['buildingId']}\n\n';
        } else {
          statusText += '⚠️  User document NOT found by Firebase Auth UID\n';
          statusText += '   Searching by authUid field...\n';
          
          final querySnapshot = await _firestore
              .collection('users')
              .where('authUid', isEqualTo: firebaseUser.uid)
              .limit(1)
              .get();
          
          if (querySnapshot.docs.isNotEmpty) {
            statusText += '✅ User document found by authUid field\n';
            final userData = querySnapshot.docs.first.data();
            statusText += '   Document ID: ${querySnapshot.docs.first.id}\n';
            statusText += '   Name: ${userData['name']}\n';
            statusText += '   Flat: ${userData['flatLabel'] ?? userData['flatId']}\n\n';
          } else {
            statusText += '❌ User document NOT found by authUid field\n\n';
          }
        }
      } else {
        statusText += '❌ Firebase Auth: Not logged in\n\n';
      }

      // SharedPreferences status
      if (storedUserId != null) {
        statusText += '✅ SharedPreferences: User ID stored\n';
        statusText += '   User ID: $storedUserId\n\n';
      } else {
        statusText += '❌ SharedPreferences: No user ID stored\n\n';
      }

      statusText += '✅ Authentication check complete';

      setState(() {
        _status = statusText;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _status = '❌ Error checking auth status:\n$e';
        _isLoading = false;
      });
    }
  }

  Future<void> _testAmenitiesFetch() async {
    setState(() {
      _status = 'Testing amenities fetch...';
      _isLoading = true;
    });

    try {
      String statusText = '🏢 AMENITIES FETCH TEST\n\n';
      
      // Test the stream (just get first emission)
      final amenities = await _bookingService.streamAmenitiesRealtime().first;
      
      statusText += '✅ Amenities stream working!\n\n';
      statusText += 'Found ${amenities.length} amenities\n\n';
      
      if (amenities.isEmpty) {
        statusText += '⚠️  No amenities found.\n';
        statusText += 'Admin needs to create amenities in Firestore.\n\n';
        statusText += 'Collection: amenities\n';
        statusText += 'Required fields:\n';
        statusText += '  - name\n';
        statusText += '  - type\n';
        statusText += '  - isAvailable: true\n';
        statusText += '  - buildingId: (match user buildingId)\n';
        statusText += '  - timeSlots: array\n';
      } else {
        statusText += 'Available amenities:\n';
        for (var i = 0; i < amenities.length && i < 5; i++) {
          final amenity = amenities[i];
          statusText += '\n${i + 1}. ${amenity.name}\n';
          statusText += '   Type: ${amenity.type}\n';
          statusText += '   Price: ${amenity.priceDisplay}\n';
          statusText += '   Capacity: ${amenity.capacityDisplay}\n';
          statusText += '   Building: ${amenity.buildingId ?? "N/A"}\n';
        }
      }

      setState(() {
        _status = statusText;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _status = '❌ Error testing amenities:\n$e\n\nCheck console for details.';
        _isLoading = false;
      });
    }
  }

  Future<void> _testFlatMembers() async {
    setState(() {
      _status = 'Testing flat members fetch...';
      _isLoading = true;
    });

    try {
      String statusText = '👥 FLAT MEMBERS FETCH TEST\n\n';
      
      final members = await _chatService.getFlatMembers();
      
      statusText += '✅ Flat members fetch working!\n\n';
      statusText += 'Found ${members.length} flat members\n\n';
      
      if (members.isEmpty) {
        statusText += '⚠️  No flat members found.\n';
        statusText += 'This could mean:\n';
        statusText += '  - You are the only user in your flat\n';
        statusText += '  - Other users have different flatId\n';
        statusText += '  - User flatId is not set correctly\n';
      } else {
        statusText += 'Flat members:\n';
        for (var i = 0; i < members.length; i++) {
          final member = members[i];
          statusText += '\n${i + 1}. ${member['name']}\n';
          statusText += '   Email: ${member['email'] ?? "N/A"}\n';
          statusText += '   Phone: ${member['phone'] ?? "N/A"}\n';
          statusText += '   Role: ${member['role'] ?? "N/A"}\n';
        }
      }

      setState(() {
        _status = statusText;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _status = '❌ Error testing flat members:\n$e\n\nCheck console for details.';
        _isLoading = false;
      });
    }
  }

  Future<void> _testAdminChat() async {
    setState(() {
      _status = 'Testing admin chat...';
      _isLoading = true;
    });

    try {
      String statusText = '💬 ADMIN CHAT TEST\n\n';
      
      final chatId = await _chatService.getOrCreateAdminChat();
      
      if (chatId != null) {
        statusText += '✅ Admin chat working!\n\n';
        statusText += 'Chat ID: $chatId\n\n';
        statusText += 'Admin chat is ready for messaging.';
      } else {
        statusText += '❌ Failed to create admin chat\n\n';
        statusText += 'Possible issues:\n';
        statusText += '  - No buildingId in user document\n';
        statusText += '  - No admin user found for building\n';
        statusText += '  - Authentication error\n';
      }

      setState(() {
        _status = statusText;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _status = '❌ Error testing admin chat:\n$e\n\nCheck console for details.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('All Fixes Test'),
        backgroundColor: Colors.blue,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      _status,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (_isLoading)
                const Center(
                  child: CircularProgressIndicator(),
                )
              else ...[
                ElevatedButton.icon(
                  onPressed: _checkAuthStatus,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Check Auth Status'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: _testAmenitiesFetch,
                  icon: const Icon(Icons.apartment),
                  label: const Text('Test Amenities Fetch'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                    backgroundColor: Colors.green,
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: _testFlatMembers,
                  icon: const Icon(Icons.people),
                  label: const Text('Test Flat Members'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                    backgroundColor: Colors.orange,
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: _testAdminChat,
                  icon: const Icon(Icons.chat),
                  label: const Text('Test Admin Chat'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                    backgroundColor: Colors.purple,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
