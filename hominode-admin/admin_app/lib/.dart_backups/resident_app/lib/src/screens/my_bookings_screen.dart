// lib/src/screens/my_bookings_screen.dart
// My Bookings Screen

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/user_data_service.dart';
import '../widgets/skeleton_loader.dart';

// ============================================================================
// MY BOOKINGS SCREEN
// ============================================================================
class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _userDataService = UserDataService();
  late Stream<List<Map<String, dynamic>>> _bookingsStream;
  String? _userId;
  String _selectedTab = 'upcoming'; // upcoming, completed, cancelled

  @override
  void initState() {
    super.initState();
    _initializeStream();
  }

  Future<void> _initializeStream() async {
    print('🔵 MY BOOKINGS SCREEN: Initializing...');
    
    try {
      final userData = await _userDataService.getCurrentUserData();
      
      if (userData == null) {
        print('❌ No user data found');
        return;
      }

      final userId = userData['id'];
      
      if (userId == null || userId.isEmpty) {
        print('❌ No user ID found');
        return;
      }

      setState(() {
        _userId = userId;
        _bookingsStream = _getBookingsStream(userId);
      });

      print('✅ Stream initialized for user: $userId');
    } catch (e) {
      print('❌ Error initializing: $e');
    }
  }

  Stream<List<Map<String, dynamic>>> _getBookingsStream(String userId) {
    print('📡 MY BOOKINGS FLOW: Streaming bookings for user: $userId');
    
    return _firestore
        .collection('amenityBookings')
        .where('userId', isEqualTo: userId)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
      print('📊 Found ${snapshot.docs.length} bookings');
      
      return snapshot.docs.map((doc) {
        final data = doc.data();
        final date = (data['date'] as Timestamp?)?.toDate() ?? DateTime.now();
        final status = data['status'] ?? 'pending';
        
        print('✅ Booking: ${data['amenityName']} - $status');
        
        return {
          'id': doc.id,
          'amenityName': data['amenityName'] ?? 'Amenity',
          'amenityId': data['amenityId'] ?? '',
          'date': date,
          'timeSlot': data['timeSlot'] ?? '',
          'numberOfPeople': data['numberOfPeople'] ?? 1,
          'status': status,
          'bookingType': data['bookingType'] ?? 'daily',
          'createdAt': (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          'updatedAt': (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          'notes': data['notes'] ?? '',
          'price': data['price'] ?? 0,
          'userName': data['userName'] ?? 'You',
        };
      }).toList();
    }).handleError((error) {
      print('❌ Stream error: $error');
      return [];
    });
  }

  List<Map<String, dynamic>> _filterBookings(List<Map<String, dynamic>> bookings) {
    final now = DateTime.now();
    
    switch (_selectedTab) {
      case 'upcoming':
        return bookings.where((b) {
          final bookingDate = b['date'] as DateTime;
          return bookingDate.isAfter(now) && b['status'] != 'cancelled';
        }).toList();
      
      case 'completed':
        return bookings.where((b) {
          final bookingDate = b['date'] as DateTime;
          return bookingDate.isBefore(now) || b['status'] == 'completed';
        }).toList();
      
      case 'cancelled':
        return bookings.where((b) => b['status'] == 'cancelled').toList();
      
      default:
        return bookings;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Bookings'),
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _userId == null
          ? const Center(
              child: Text('Unable to load bookings'),
            )
          : Column(
              children: [
                // Tab selector
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      _buildTabButton('Upcoming', 'upcoming'),
                      const SizedBox(width: 8),
                      _buildTabButton('Completed', 'completed'),
                      const SizedBox(width: 8),
                      _buildTabButton('Cancelled', 'cancelled'),
                    ],
                  ),
                ),
                // Bookings list
                Expanded(
                  child: StreamBuilder<List<Map<String, dynamic>>>(
                    stream: _bookingsStream,
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
                              height: 140,
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

                      final allBookings = snapshot.data ?? [];
                      final filteredBookings = _filterBookings(allBookings);

                      // Empty state
                      if (filteredBookings.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.bookmark_outline,
                                size: 64,
                                color: Colors.grey[300],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No $_selectedTab bookings',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      // Bookings list
                      return ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filteredBookings.length,
                        itemBuilder: (context, index) {
                          final booking = filteredBookings[index];
                          return _buildBookingCard(context, booking);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildTabButton(String label, String value) {
    final isSelected = _selectedTab == value;
    
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF2563EB) : Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white : Colors.grey[700],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBookingCard(BuildContext context, Map<String, dynamic> booking) {
    final date = booking['date'] as DateTime;
    final status = booking['status'] as String;
    final statusColor = _getStatusColor(status);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showBookingDetails(context, booking),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Amenity name and status
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8FDEB),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.bookmark_outline,
                      color: Color(0xFF10B981),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          booking['amenityName'] ?? 'Amenity',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${booking['numberOfPeople']} people',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Date and time
              Row(
                children: [
                  const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    _formatDate(date),
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(width: 16),
                  const Icon(Icons.access_time, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    booking['timeSlot'] ?? 'Not specified',
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showBookingDetails(BuildContext context, Map<String, dynamic> booking) {
    final date = booking['date'] as DateTime;
    
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
                      color: const Color(0xFFE8FDEB),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.bookmark_outline,
                      color: Color(0xFF10B981),
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          booking['amenityName'] ?? 'Amenity',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _getStatusColor(booking['status']).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            (booking['status'] as String).toUpperCase(),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _getStatusColor(booking['status']),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Details
              _buildDetailRow('Date', _formatDate(date)),
              _buildDetailRow('Time Slot', booking['timeSlot'] ?? 'Not specified'),
              _buildDetailRow('Number of People', '${booking['numberOfPeople']} people'),
              _buildDetailRow('Booking Type', booking['bookingType'] ?? 'Daily'),
              if (((booking['price'] as num?) ?? 0) > 0)
                _buildDetailRow('Price', '₹${booking['price']}'),
              if ((booking['notes'] as String?)?.isNotEmpty ?? false)
                _buildDetailRow('Notes', booking['notes'] ?? ''),
              _buildDetailRow(
                'Booked On',
                _formatDateTime(booking['createdAt'] as DateTime),
              ),
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

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
      case 'completed':
        return const Color(0xFF10B981);
      case 'pending':
        return const Color(0xFFF59E0B);
      case 'cancelled':
        return const Color(0xFFEF4444);
      default:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatDateTime(DateTime date) {
    return '${date.day}/${date.month}/${date.year} at ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
