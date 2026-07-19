// lib/test_complaints_fix.dart
// Test script to verify complaints authentication fix

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'src/services/complaint_firestore_service.dart';
import 'src/models/complaint.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const ComplaintsTestApp());
}

class ComplaintsTestApp extends StatelessWidget {
  const ComplaintsTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Complaints Test',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const ComplaintsTestScreen(),
    );
  }
}

class ComplaintsTestScreen extends StatefulWidget {
  const ComplaintsTestScreen({super.key});

  @override
  State<ComplaintsTestScreen> createState() => _ComplaintsTestScreenState();
}

class _ComplaintsTestScreenState extends State<ComplaintsTestScreen> {
  final _complaintService = ComplaintFirestoreService();
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
          statusText += '   Admin ID: ${userData?['adminId']}\n\n';
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

      statusText += '✅ Authentication check complete\n';
      statusText += 'Ready to test complaint operations';

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

  Future<void> _testCreateComplaint() async {
    setState(() {
      _status = 'Testing create complaint...';
      _isLoading = true;
    });

    try {
      final result = await _complaintService.createComplaint(
        title: 'Test Complaint ${DateTime.now().millisecondsSinceEpoch}',
        description: 'Testing authentication fix for complaints',
        category: ComplaintCategory.maintenance,
      );

      String statusText = '📝 CREATE COMPLAINT TEST\n\n';
      
      if (result.success) {
        statusText += '✅ SUCCESS!\n\n';
        statusText += 'Message: ${result.message}\n';
        statusText += 'Complaint ID: ${result.complaintId}\n\n';
        statusText += 'The authentication fix is working correctly!\n';
        statusText += 'User ID was retrieved successfully.';
      } else {
        statusText += '❌ FAILED\n\n';
        statusText += 'Message: ${result.message}\n';
        statusText += 'Error Code: ${result.errorCode}\n\n';
        statusText += 'Check the console logs for details.';
      }

      setState(() {
        _status = statusText;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _status = '❌ Error testing create complaint:\n$e';
        _isLoading = false;
      });
    }
  }

  Future<void> _testStreamComplaints() async {
    setState(() {
      _status = 'Testing stream complaints...';
      _isLoading = true;
    });

    try {
      String statusText = '📡 STREAM COMPLAINTS TEST\n\n';
      
      // Test the stream (just get first emission)
      final complaints = await _complaintService.streamMyComplaints().first;
      
      statusText += '✅ Stream working!\n\n';
      statusText += 'Found ${complaints.length} complaints\n\n';
      
      if (complaints.isEmpty) {
        statusText += 'No complaints found.\n';
        statusText += 'Try creating a complaint first.';
      } else {
        statusText += 'Recent complaints:\n';
        for (var i = 0; i < complaints.length && i < 3; i++) {
          final complaint = complaints[i];
          statusText += '\n${i + 1}. ${complaint.title}\n';
          statusText += '   Category: ${complaint.category.categoryDisplayName}\n';
          statusText += '   Status: ${complaint.status.displayName}\n';
          statusText += '   Date: ${complaint.formattedDate}\n';
        }
      }

      setState(() {
        _status = statusText;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _status = '❌ Error testing stream:\n$e\n\nCheck console for details.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Complaints Test'),
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
                  onPressed: _testCreateComplaint,
                  icon: const Icon(Icons.add_comment),
                  label: const Text('Test Create Complaint'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                    backgroundColor: Colors.green,
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: _testStreamComplaints,
                  icon: const Icon(Icons.stream),
                  label: const Text('Test Stream Complaints'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                    backgroundColor: Colors.orange,
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
