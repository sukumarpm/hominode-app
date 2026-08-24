# Amenities Bookings Tab Implementation Guide

## Overview
Add a "Bookings" tab to the Amenities Management screen that fetches and displays booking data from the Firestore `bookings` collection.

## Current Structure
The amenities management screen currently has tabs for managing amenities. We need to add a new "Bookings" tab.

## Updated Tab Structure
```
┌─────────────────────────────────────────┐
│  Amenities Management                   │
├─────────────────────────────────────────┤
│  [Amenities] [Bookings]  ← Add this tab │
├─────────────────────────────────────────┤
│  Content based on selected tab          │
└─────────────────────────────────────────┘
```

## Firestore Collection Structure

### Collection: `bookings`
```
bookings/
  {bookingId}/
    // Amenity Information
    amenityId: "amenity123"
    amenityName: "Swimming Pool"
    
    // Building Information
    buildingId: "building123"
    buildingName: "Sunrise Apartments"
    
    // Date and Time
    bookingDate: "2024-01-26" (YYYY-MM-DD)
    bookingDateTimestamp: Timestamp
    timeSlot: "6:00 AM - 7:00 AM"
    startTime: "06:00"
    endTime: "07:00"
    
    // Resident Information
    userId: "user123"
    residentId: "RES1234"
    residentName: "John Doe"
    flatId: "flat123"
    flatLabel: "A-101"
    phone: "+91 9876543210"
    email: "john@example.com"
    
    // Status
    status: "confirmed" | "cancelled" | "completed"
    
    // Admin Information
    adminId: "admin123"
    
    // Timestamps
    createdAt: Timestamp
    updatedAt: Timestamp
    bookedAt: Timestamp
```

## Implementation Steps

### Step 1: Update Amenities Management Screen

Add a tab controller and bookings view:

```dart
// In amenities_management_screen.dart

class _AmenitiesManagementScreenState extends State<AmenitiesManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Amenities Management'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Amenities'),
            Tab(text: 'Bookings'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAmenitiesTab(),
          _buildBookingsTab(),
        ],
      ),
    );
  }
  
  Widget _buildBookingsTab() {
    return AmenitiesBookingsView();
  }
}
```

### Step 2: Create Booking Service

File: `lib/services/booking_service.dart`

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'admin_service.dart';

class BookingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AdminService _adminService = AdminService();
  final String _collection = 'bookings';

  // Get all bookings for admin's building
  Stream<List<BookingModel>> getBookings() {
    final adminId = _adminService.getCurrentAdminId();
    if (adminId == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection(_collection)
        .where('adminId', isEqualTo: adminId)
        .orderBy('bookingDateTimestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return BookingModel.fromFirestore(doc.id, data);
      }).toList();
    });
  }

  // Get bookings by date
  Stream<List<BookingModel>> getBookingsByDate(DateTime date) {
    final adminId = _adminService.getCurrentAdminId();
    if (adminId == null) {
      return Stream.value([]);
    }

    final dateStr = _formatDate(date);
    
    return _firestore
        .collection(_collection)
        .where('adminId', isEqualTo: adminId)
        .where('bookingDate', isEqualTo: dateStr)
        .orderBy('startTime')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return BookingModel.fromFirestore(doc.id, data);
      }).toList();
    });
  }

  // Get bookings by amenity
  Stream<List<BookingModel>> getBookingsByAmenity(String amenityId) {
    final adminId = _adminService.getCurrentAdminId();
    if (adminId == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection(_collection)
        .where('adminId', isEqualTo: adminId)
        .where('amenityId', isEqualTo: amenityId)
        .orderBy('bookingDateTimestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return BookingModel.fromFirestore(doc.id, data);
      }).toList();
    });
  }

  // Get bookings by status
  Stream<List<BookingModel>> getBookingsByStatus(String status) {
    final adminId = _adminService.getCurrentAdminId();
    if (adminId == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection(_collection)
        .where('adminId', isEqualTo: adminId)
        .where('status', isEqualTo: status)
        .orderBy('bookingDateTimestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return BookingModel.fromFirestore(doc.id, data);
      }).toList();
    });
  }

  // Cancel booking
  Future<void> cancelBooking(String bookingId) async {
    await _firestore.collection(_collection).doc(bookingId).update({
      'status': 'cancelled',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Complete booking
  Future<void> completeBooking(String bookingId) async {
    await _firestore.collection(_collection).doc(bookingId).update({
      'status': 'completed',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

// Booking Model
class BookingModel {
  final String id;
  final String amenityId;
  final String amenityName;
  final String buildingId;
  final String buildingName;
  final String bookingDate;
  final DateTime? bookingDateTimestamp;
  final String timeSlot;
  final String startTime;
  final String endTime;
  final String userId;
  final String residentId;
  final String residentName;
  final String flatId;
  final String flatLabel;
  final String phone;
  final String? email;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  BookingModel({
    required this.id,
    required this.amenityId,
    required this.amenityName,
    required this.buildingId,
    required this.buildingName,
    required this.bookingDate,
    this.bookingDateTimestamp,
    required this.timeSlot,
    required this.startTime,
    required this.endTime,
    required this.userId,
    required this.residentId,
    required this.residentName,
    required this.flatId,
    required this.flatLabel,
    required this.phone,
    this.email,
    required this.status,
    this.createdAt,
    this.updatedAt,
  });

  factory BookingModel.fromFirestore(String id, Map<String, dynamic> data) {
    return BookingModel(
      id: id,
      amenityId: data['amenityId'] ?? '',
      amenityName: data['amenityName'] ?? '',
      buildingId: data['buildingId'] ?? '',
      buildingName: data['buildingName'] ?? '',
      bookingDate: data['bookingDate'] ?? '',
      bookingDateTimestamp: (data['bookingDateTimestamp'] as Timestamp?)?.toDate(),
      timeSlot: data['timeSlot'] ?? '',
      startTime: data['startTime'] ?? '',
      endTime: data['endTime'] ?? '',
      userId: data['userId'] ?? '',
      residentId: data['residentId'] ?? '',
      residentName: data['residentName'] ?? '',
      flatId: data['flatId'] ?? '',
      flatLabel: data['flatLabel'] ?? '',
      phone: data['phone'] ?? '',
      email: data['email'],
      status: data['status'] ?? 'confirmed',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}
```

### Step 3: Create Bookings View Widget

File: `lib/widgets/amenities_bookings_view.dart`

```dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/booking_service.dart';

class AmenitiesBookingsView extends StatefulWidget {
  const AmenitiesBookingsView({Key? key}) : super(key: key);

  @override
  State<AmenitiesBookingsView> createState() => _AmenitiesBookingsViewState();
}

class _AmenitiesBookingsViewState extends State<AmenitiesBookingsView> {
  final BookingService _bookingService = BookingService();
  DateTime _selectedDate = DateTime.now();
  String _selectedStatus = 'all';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildDateSelector(),
        _buildStatusFilter(),
        Expanded(
          child: _buildBookingsList(),
        ),
      ],
    );
  }

  Widget _buildDateSelector() {
    return Container(
      padding: EdgeInsets.all(16),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.chevron_left),
            onPressed: () {
              setState(() {
                _selectedDate = _selectedDate.subtract(Duration(days: 1));
              });
            },
          ),
          Expanded(
            child: InkWell(
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                );
                if (date != null) {
                  setState(() {
                    _selectedDate = date;
                  });
                }
              },
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  DateFormat('EEEE, MMMM d, y').format(_selectedDate),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.chevron_right),
            onPressed: () {
              setState(() {
                _selectedDate = _selectedDate.add(Duration(days: 1));
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatusFilter() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Text('Status: '),
          SizedBox(width: 8),
          DropdownButton<String>(
            value: _selectedStatus,
            items: [
              DropdownMenuItem(value: 'all', child: Text('All')),
              DropdownMenuItem(value: 'confirmed', child: Text('Confirmed')),
              DropdownMenuItem(value: 'cancelled', child: Text('Cancelled')),
              DropdownMenuItem(value: 'completed', child: Text('Completed')),
            ],
            onChanged: (value) {
              setState(() {
                _selectedStatus = value!;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBookingsList() {
    return StreamBuilder<List<BookingModel>>(
      stream: _selectedStatus == 'all'
          ? _bookingService.getBookingsByDate(_selectedDate)
          : _bookingService.getBookingsByStatus(_selectedStatus),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final bookings = snapshot.data ?? [];

        if (bookings.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.event_busy, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No bookings found',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: EdgeInsets.all(16),
          itemCount: bookings.length,
          itemBuilder: (context, index) {
            return _buildBookingCard(bookings[index]);
          },
        );
      },
    );
  }

  Widget _buildBookingCard(BookingModel booking) {
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    booking.amenityName,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _buildStatusChip(booking.status),
              ],
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.access_time, size: 16, color: Colors.grey),
                SizedBox(width: 4),
                Text(
                  booking.timeSlot,
                  style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                ),
              ],
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.person, size: 16, color: Colors.grey),
                SizedBox(width: 4),
                Text(
                  '${booking.residentName} (${booking.flatLabel})',
                  style: TextStyle(fontSize: 14),
                ),
              ],
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.phone, size: 16, color: Colors.grey),
                SizedBox(width: 4),
                Text(
                  booking.phone,
                  style: TextStyle(fontSize: 14),
                ),
              ],
            ),
            if (booking.status == 'confirmed') ...[
              SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => _cancelBooking(booking),
                    child: Text('Cancel'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                  ),
                  SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => _completeBooking(booking),
                    child: Text('Complete'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    switch (status) {
      case 'confirmed':
        color = Colors.green;
        break;
      case 'cancelled':
        color = Colors.red;
        break;
      case 'completed':
        color = Colors.blue;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Future<void> _cancelBooking(BookingModel booking) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Cancel Booking'),
        content: Text('Are you sure you want to cancel this booking?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Yes'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _bookingService.cancelBooking(booking.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Booking cancelled successfully')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to cancel booking: $e')),
        );
      }
    }
  }

  Future<void> _completeBooking(BookingModel booking) async {
    try {
      await _bookingService.completeBooking(booking.id);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Booking marked as completed')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to complete booking: $e')),
      );
    }
  }
}
```

## Data Flow

```
1. Admin opens Amenities Management
   ↓
2. Admin clicks "Bookings" tab
   ↓
3. System fetches bookings from Firestore
   - Collection: bookings
   - Filter: adminId = current admin
   - Order: by bookingDateTimestamp (descending)
   ↓
4. Display bookings list with:
   - Amenity name
   - Time slot
   - Resident details
   - Status
   - Action buttons
   ↓
5. Admin can:
   - View bookings by date
   - Filter by status
   - Cancel bookings
   - Mark as completed
```

## Summary

This implementation adds a comprehensive bookings management system to the amenities screen that:
- Fetches data from the `bookings` collection in Firestore
- Displays bookings with all relevant information
- Allows filtering by date and status
- Provides actions to cancel or complete bookings
- Follows the flow function requirements

The booking data is properly structured and includes all necessary information about the amenity, resident, and booking details.
