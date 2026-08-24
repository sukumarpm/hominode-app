import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DebugAdminHelper extends StatefulWidget {
  const DebugAdminHelper({super.key});

  @override
  State<DebugAdminHelper> createState() => _DebugAdminHelperState();
}

class _DebugAdminHelperState extends State<DebugAdminHelper> {
  String _debugInfo = 'Loading...';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkAdminData();
  }

  Future<void> _checkAdminData() async {
    setState(() {
      _isLoading = true;
      _debugInfo = 'Checking...';
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _debugInfo = 'ERROR: No user logged in';
          _isLoading = false;
        });
        return;
      }

      String info = '';
      info += '=== FIREBASE AUTH ===\n';
      info += 'UID: ${user.uid}\n';
      info += 'Email: ${user.email}\n';
      info += '\n';

      // Check admins collection
      info += '=== ADMINS COLLECTION ===\n';
      final adminDoc = await FirebaseFirestore.instance
          .collection('admins')
          .doc(user.uid)
          .get();

      if (adminDoc.exists) {
        info += 'Document EXISTS at: admins/${user.uid}\n';
        final data = adminDoc.data()!;
        info += 'Name: ${data['name']}\n';
        info += 'Email: ${data['email']}\n';
        info += 'Phone: ${data['phone']}\n';
        info += 'Organization: ${data['organization']}\n';
        info += 'Role: ${data['role']}\n';
      } else {
        info += 'Document DOES NOT EXIST at: admins/${user.uid}\n';
        info += '\nNeed to create this document!\n';
      }

      info += '\n';

      // Check all documents in admins collection
      info += '=== ALL ADMIN DOCUMENTS ===\n';
      final allAdmins = await FirebaseFirestore.instance
          .collection('admins')
          .get();

      if (allAdmins.docs.isEmpty) {
        info += 'No documents in admins collection\n';
      } else {
        info += 'Found ${allAdmins.docs.length} document(s):\n';
        for (var doc in allAdmins.docs) {
          info += '\nDoc ID: ${doc.id}\n';
          final data = doc.data();
          info += '  Name: ${data['name']}\n';
          info += '  Email: ${data['email']}\n';
        }
      }

      setState(() {
        _debugInfo = info;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _debugInfo = 'ERROR: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _createAdminDocument() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Check if there's an existing admin document with different ID
      final allAdmins = await FirebaseFirestore.instance
          .collection('admins')
          .get();

      Map<String, dynamic>? existingData;
      if (allAdmins.docs.isNotEmpty) {
        // Use data from first admin document found
        existingData = allAdmins.docs.first.data();
      }

      // Create new document with correct UID
      await FirebaseFirestore.instance.collection('admins').doc(user.uid).set({
        'name': existingData?['name'] ?? 'Admin User',
        'email': existingData?['email'] ?? user.email ?? '',
        'phone': existingData?['phone'] ?? '',
        'organization':
            existingData?['organization'] ?? 'HOMINODE Property Management',
        'role': existingData?['role'] ?? 'admin',
        'buildingIds': existingData?['buildingIds'] ?? [],
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Admin document created successfully!'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }

      // Refresh debug info
      _checkAdminData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug Admin Data'),
        backgroundColor: const Color(0xFF2563EB),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: SelectableText(
                      _debugInfo,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _checkAdminData,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Refresh'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _createAdminDocument,
                          icon: const Icon(Icons.add),
                          label: const Text('Create/Fix Document'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Instructions:',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '1. Check the debug info above\n'
                    '2. If document does not exist at your Auth UID, click "Create/Fix Document"\n'
                    '3. Go back and refresh the profile screen\n'
                    '4. Your data should now display correctly',
                    style: TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
    );
  }
}
