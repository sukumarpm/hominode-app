// lib/src/screens/domestic_staff_screen.dart
// Domestic Staff Management Screen

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import '../services/user_data_service.dart';
import '../widgets/skeleton_loader.dart';

// ============================================================================
// DOMESTIC STAFF SCREEN
// ============================================================================
class DomesticStaffScreen extends StatefulWidget {
  const DomesticStaffScreen({Key? key}) : super(key: key);

  @override
  State<DomesticStaffScreen> createState() => _DomesticStaffScreenState();
}

class _DomesticStaffScreenState extends State<DomesticStaffScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _userDataService = UserDataService();
  late Stream<List<Map<String, dynamic>>> _staffStream;
  String? _flatId;

  @override
  void initState() {
    super.initState();
    _initializeStream();
  }

  Future<void> _initializeStream() async {
    print('🔵 DOMESTIC STAFF SCREEN: Initializing...');
    
    try {
      final userData = await _userDataService.getCurrentUserData();
      
      if (userData == null) {
        print('❌ No user data found');
        return;
      }

      final flatId = userData['flatId'] ?? userData['flatLabel'];
      
      if (flatId == null || flatId.isEmpty) {
        print('❌ No flat ID found');
        return;
      }

      setState(() {
        _flatId = flatId;
        _staffStream = _getDomesticStaffStream(flatId);
      });

      print('✅ Stream initialized for flat: $flatId');
    } catch (e) {
      print('❌ Error initializing: $e');
    }
  }

  Stream<List<Map<String, dynamic>>> _getDomesticStaffStream(String flatId) {
    print('📡 DOMESTIC STAFF FLOW: Streaming staff for flat: $flatId');
    
    return _firestore
        .collection('domesticStaff')
        .where('flatId', isEqualTo: flatId)
        .where('status', isEqualTo: 'active')
        .orderBy('addedDate', descending: true)
        .snapshots()
        .map((snapshot) {
      print('📊 Found ${snapshot.docs.length} domestic staff members');
      
      return snapshot.docs.map((doc) {
        final data = doc.data();
        print('✅ Staff: ${data['name']} - ${data['role']}');
        
        return {
          'id': doc.id,
          'name': data['name'] ?? 'Unknown',
          'role': data['role'] ?? 'Staff',
          'phone': data['phone'] ?? '',
          'email': data['email'] ?? '',
          'address': data['address'] ?? '',
          'joinDate': (data['addedDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
          'salary': data['salary'] ?? 0,
          'status': data['status'] ?? 'active',
          'notes': data['notes'] ?? '',
          'aadharNumber': data['aadharNumber'] ?? '',
          'bankAccount': data['bankAccount'] ?? '',
        };
      }).toList();
    }).handleError((error) {
      print('❌ Stream error: $error');
      return [];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Domestic Staff'),
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _flatId == null
          ? const Center(
              child: Text('Unable to load staff information'),
            )
          : StreamBuilder<List<Map<String, dynamic>>>(
              stream: _staffStream,
              builder: (context, snapshot) {
                // Loading state
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: 3,
                    itemBuilder: (context, index) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: SkeletonLoader(
                        width: double.infinity,
                        height: 120,
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                    ),
                  );
                }

                // Error state
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.red),
                        const SizedBox(height: 16),
                        Text('Error: ${snapshot.error}'),
                      ],
                    ),
                  );
                }

                final staffList = snapshot.data ?? [];

                // Empty state
                if (staffList.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 64,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No domestic staff added',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // Staff list
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: staffList.length,
                  itemBuilder: (context, index) {
                    final staff = staffList[index];
                    return _buildStaffCard(context, staff);
                  },
                );
              },
            ),
    );
  }

  Widget _buildStaffCard(BuildContext context, Map<String, dynamic> staff) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showStaffDetails(context, staff),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Name and role
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3E8),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.cleaning_services_outlined,
                      color: Color(0xFFF97316),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          staff['name'] ?? 'Unknown',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          staff['role'] ?? 'Staff',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.grey),
                ],
              ),
              const SizedBox(height: 12),
              // Contact info
              if ((staff['phone'] as String?)?.isNotEmpty ?? false)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.phone, size: 16, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text(
                        staff['phone'] ?? '',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                ),
              if ((staff['email'] as String?)?.isNotEmpty ?? false)
                Row(
                  children: [
                    const Icon(Icons.email, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        staff['email'] ?? '',
                        style: const TextStyle(fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showStaffDetails(BuildContext context, Map<String, dynamic> staff) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3E8),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.cleaning_services_outlined,
                      color: Color(0xFFF97316),
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          staff['name'] ?? 'Unknown',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          staff['role'] ?? 'Staff',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Details
              _buildDetailRow('Phone', staff['phone'] ?? 'Not provided'),
              _buildDetailRow('Email', staff['email'] ?? 'Not provided'),
              _buildDetailRow('Address', staff['address'] ?? 'Not provided'),
              _buildDetailRow('Aadhar Number', staff['aadharNumber'] ?? 'Not provided'),
              _buildDetailRow('Bank Account', staff['bankAccount'] ?? 'Not provided'),
              if (((staff['salary'] as num?) ?? 0) > 0)
                _buildDetailRow('Monthly Salary', '₹${staff['salary']}'),
              if (staff['joinDate'] != null)
                _buildDetailRow(
                  'Join Date',
                  _formatDate(staff['joinDate'] as DateTime),
                ),
              if ((staff['notes'] as String?)?.isNotEmpty ?? false)
                _buildDetailRow('Notes', staff['notes'] ?? ''),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Close',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
