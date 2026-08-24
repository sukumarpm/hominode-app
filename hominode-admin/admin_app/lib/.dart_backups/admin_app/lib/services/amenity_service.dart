import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'admin_service.dart';
import 'notification_firestore_service.dart';
import '../models/notification_models.dart';

class AmenityService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AdminService _adminService = AdminService();
  final NotificationFirestoreService _notificationService =
      NotificationFirestoreService();
  final String _amenitiesCollection = 'amenities';
  final String _bookingsCollection = 'bookings';

  // Get all amenities for admin
  Stream<List<AmenityModel>> getAmenities() {
    final adminId = _adminService.getCurrentAdminId();
    if (adminId == null) return Stream.value([]);

    print('AmenityService: Fetching amenities for admin: $adminId');
    return _firestore
        .collection(_amenitiesCollection)
        .where(
          'communityId',
          isEqualTo: _adminService.requireCurrentCommunityId(),
        )
        .snapshots()
        .map((snapshot) {
          print('AmenityService: Found ${snapshot.docs.length} amenities');
          return snapshot.docs.map((doc) {
            final data = doc.data();
            return AmenityModel.fromFirestore(doc.id, data);
          }).toList();
        });
  }

  // Add new amenity
  Future<String> addAmenity({
    required String name,
    required String type,
    required bool isFree,
    required String buildingId,
    required String buildingName,
    double? pricePerDay,
    String? description,
    String? iconName,
    String? imageUrl,
    List<String>? timeSlots,
    int? maxCapacity,
    bool? allowMultipleBookings,
    List<String>? bookingDurations,
    bool? hasSubscriptionPackages,
    Map<String, double>? subscriptionPackages,
  }) async {
    try {
      final adminId = _adminService.getCurrentAdminId();
      if (adminId == null) throw Exception('Admin not logged in');

      final adminProfile = await _adminService.getAdminProfile();

      print(
        'AmenityService: Adding amenity - $name for building $buildingName',
      );

      final docRef = await _firestore.collection(_amenitiesCollection).add({
        'name': name,
        'type': type,
        'isFree': isFree,
        'pricePerDay': pricePerDay ?? 0,
        'description': description,
        'iconName': iconName,
        'imageUrl': imageUrl,
        'timeSlots': timeSlots,
        'isAvailable': true,
        'buildingId': buildingId,
        'buildingName': buildingName,
        'adminId': adminId,
        'communityId': _adminService.requireCurrentCommunityId(),
        'adminName': adminProfile?['name'] ?? '',
        'adminEmail': adminProfile?['email'] ?? '',
        'organization': adminProfile?['organization'] ?? '',
        // Booking Configuration
        'maxCapacity': maxCapacity ?? 1,
        'allowMultipleBookings': allowMultipleBookings ?? false,
        'bookingDurations': bookingDurations ?? ['1 hour'],
        // Subscription Packages
        'hasSubscriptionPackages': hasSubscriptionPackages ?? false,
        'subscriptionPackages': subscriptionPackages ?? {},
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('AmenityService: Amenity added with ID: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      print('AmenityService ERROR: Failed to add amenity: $e');
      throw Exception('Failed to add amenity: $e');
    }
  }

  // Update amenity
  Future<void> updateAmenity(
    String amenityId,
    Map<String, dynamic> updates,
  ) async {
    try {
      updates['updatedAt'] = FieldValue.serverTimestamp();
      await _firestore
          .collection(_amenitiesCollection)
          .doc(amenityId)
          .update(updates);
      print('AmenityService: Amenity updated successfully');
    } catch (e) {
      print('AmenityService ERROR: Failed to update amenity: $e');
      throw Exception('Failed to update amenity: $e');
    }
  }

  // Delete amenity
  Future<void> deleteAmenity(String amenityId) async {
    try {
      await _firestore.collection(_amenitiesCollection).doc(amenityId).delete();
      print('AmenityService: Amenity deleted successfully');
    } catch (e) {
      print('AmenityService ERROR: Failed to delete amenity: $e');
      throw Exception('Failed to delete amenity: $e');
    }
  }

  // Get all bookings for admin filtered by adminId
  Stream<List<AmenityBookingModel>> getBookings() {
    final adminId = _adminService.getCurrentAdminId();
    if (adminId == null) return Stream.value([]);

    print('AmenityService getBookings: Fetching bookings for admin: $adminId');

    return _firestore
        .collection(_bookingsCollection)
        .where(
          'communityId',
          isEqualTo: _adminService.requireCurrentCommunityId(),
        )
        .snapshots()
        .map((snapshot) {
          print(
            'AmenityService getBookings: Found ${snapshot.docs.length} bookings',
          );

          final bookings = snapshot.docs.map((doc) {
            return AmenityBookingModel.fromFirestore(doc.id, doc.data());
          }).toList();

          // Sort by booking date descending
          bookings.sort((a, b) {
            if (a.bookingDateTimestamp != null &&
                b.bookingDateTimestamp != null) {
              return b.bookingDateTimestamp!.compareTo(a.bookingDateTimestamp!);
            }
            return 0;
          });

          print(
            'AmenityService getBookings: Returning ${bookings.length} bookings',
          );
          return bookings;
        });
  }

  // Get pending bookings count
  Stream<int> getPendingBookingsCount() {
    final adminId = _adminService.getCurrentAdminId();
    if (adminId == null) return Stream.value(0);

    return _firestore
        .collection(_bookingsCollection)
        .where(
          'communityId',
          isEqualTo: _adminService.requireCurrentCommunityId(),
        )
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  // Approve booking
  Future<void> approveBooking(String bookingId) async {
    try {
      print('🔵 BOOKING APPROVAL: Starting...');

      // STEP 1: Validate Admin
      print('🔐 STEP 1: Validating admin...');
      final adminId = _adminService.getCurrentAdminId();
      if (adminId == null) throw Exception('Admin not logged in');
      print('✅ STEP 1 PASSED');

      // STEP 2: Validate Booking
      print('📋 STEP 2: Validating booking...');
      final bookingDoc = await _firestore
          .collection(_bookingsCollection)
          .doc(bookingId)
          .get();
      if (!bookingDoc.exists) throw Exception('Booking not found');

      final bookingData = bookingDoc.data();
      final residentId = bookingData?['residentId'];
      final amenityName = bookingData?['amenityName'] ?? 'Amenity';
      final bookingDate = bookingData?['bookingDate'] ?? 'Unknown date';
      print('✅ STEP 2 PASSED');

      // STEP 3: Approve Booking
      print('📝 STEP 3: Approving booking...');
      await _firestore.collection(_bookingsCollection).doc(bookingId).update({
        'status': 'approved',
        'approvedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('✅ STEP 3 PASSED');

      // STEP 4: Notify Resident
      print('🔔 STEP 4: Notifying resident...');
      if (residentId != null) {
        try {
          await _notificationService.createNotification(
            title: 'Booking Approved',
            message:
                'Your booking for $amenityName on $bookingDate has been approved',
            type: NotificationType.event,
            priority: NotificationPriority.high,
            recipientId: residentId,
            metadata: {
              'bookingId': bookingId,
              'amenityName': amenityName,
              'bookingDate': bookingDate,
            },
          );
          print('✅ STEP 4 PASSED: Resident notified');
        } catch (notificationError) {
          print(
            '⚠️ STEP 4 WARNING: Failed to send notification: $notificationError',
          );
        }
      }

      print('✅ BOOKING APPROVAL: COMPLETE');
    } catch (e) {
      print('❌ ERROR: $e');
      throw Exception('Failed to approve booking: $e');
    }
  }

  // Reject booking
  Future<void> rejectBooking(String bookingId, String? reason) async {
    try {
      print('🔵 BOOKING REJECTION: Starting...');

      // STEP 1: Validate Admin
      print('🔐 STEP 1: Validating admin...');
      final adminId = _adminService.getCurrentAdminId();
      if (adminId == null) throw Exception('Admin not logged in');
      print('✅ STEP 1 PASSED');

      // STEP 2: Validate Booking
      print('📋 STEP 2: Validating booking...');
      final bookingDoc = await _firestore
          .collection(_bookingsCollection)
          .doc(bookingId)
          .get();
      if (!bookingDoc.exists) throw Exception('Booking not found');

      final bookingData = bookingDoc.data();
      final residentId = bookingData?['residentId'];
      final amenityName = bookingData?['amenityName'] ?? 'Amenity';
      print('✅ STEP 2 PASSED');

      // STEP 3: Reject Booking
      print('📝 STEP 3: Rejecting booking...');
      await _firestore.collection(_bookingsCollection).doc(bookingId).update({
        'status': 'rejected',
        'rejectionReason': reason,
        'rejectedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('✅ STEP 3 PASSED');

      // STEP 4: Notify Resident
      print('🔔 STEP 4: Notifying resident...');
      if (residentId != null) {
        try {
          await _notificationService.createNotification(
            title: 'Booking Rejected',
            message:
                'Your booking for $amenityName has been rejected. Reason: ${reason ?? 'Not specified'}',
            type: NotificationType.event,
            priority: NotificationPriority.high,
            recipientId: residentId,
            metadata: {
              'bookingId': bookingId,
              'amenityName': amenityName,
              'reason': reason,
            },
          );
          print('✅ STEP 4 PASSED: Resident notified');
        } catch (notificationError) {
          print(
            '⚠️ STEP 4 WARNING: Failed to send notification: $notificationError',
          );
        }
      }

      print('✅ BOOKING REJECTION: COMPLETE');
    } catch (e) {
      print('❌ ERROR: $e');
      throw Exception('Failed to reject booking: $e');
    }
  }

  // Cancel booking
  Future<void> cancelBooking(String bookingId) async {
    try {
      print('🔵 BOOKING CANCELLATION: Starting...');

      // STEP 1: Validate Admin
      print('🔐 STEP 1: Validating admin...');
      final adminId = _adminService.getCurrentAdminId();
      if (adminId == null) throw Exception('Admin not logged in');
      print('✅ STEP 1 PASSED');

      // STEP 2: Validate Booking
      print('📋 STEP 2: Validating booking...');
      final bookingDoc = await _firestore
          .collection(_bookingsCollection)
          .doc(bookingId)
          .get();
      if (!bookingDoc.exists) throw Exception('Booking not found');

      final bookingData = bookingDoc.data();
      final residentId = bookingData?['residentId'];
      final amenityName = bookingData?['amenityName'] ?? 'Amenity';
      print('✅ STEP 2 PASSED');

      // STEP 3: Cancel Booking
      print('📝 STEP 3: Cancelling booking...');
      await _firestore.collection(_bookingsCollection).doc(bookingId).update({
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('✅ STEP 3 PASSED');

      // STEP 4: Notify Resident
      print('🔔 STEP 4: Notifying resident...');
      if (residentId != null) {
        try {
          await _notificationService.createNotification(
            title: 'Booking Cancelled',
            message: 'Your booking for $amenityName has been cancelled',
            type: NotificationType.event,
            priority: NotificationPriority.medium,
            recipientId: residentId,
            metadata: {'bookingId': bookingId, 'amenityName': amenityName},
          );
          print('✅ STEP 4 PASSED: Resident notified');
        } catch (notificationError) {
          print(
            '⚠️ STEP 4 WARNING: Failed to send notification: $notificationError',
          );
        }
      }

      print('✅ BOOKING CANCELLATION: COMPLETE');
    } catch (e) {
      print('❌ ERROR: $e');
      throw Exception('Failed to cancel booking: $e');
    }
  }

  // Check slot availability considering capacity
  Future<Map<String, dynamic>> checkSlotAvailability({
    required String amenityId,
    required String bookingDate,
    required String timeSlot,
  }) async {
    try {
      // Get amenity details
      final amenityDoc = await _firestore
          .collection(_amenitiesCollection)
          .doc(amenityId)
          .get();
      if (!amenityDoc.exists) {
        throw Exception('Amenity not found');
      }

      final amenityData = amenityDoc.data()!;
      final maxCapacity = amenityData['maxCapacity'] ?? 1;
      final allowMultiple = amenityData['allowMultipleBookings'] ?? false;

      // If multiple bookings not allowed, check if any booking exists
      if (!allowMultiple) {
        final existingBookings = await _firestore
            .collection(_bookingsCollection)
            .where('amenityId', isEqualTo: amenityId)
            .where('bookingDate', isEqualTo: bookingDate)
            .where('timeSlot', isEqualTo: timeSlot)
            .where('status', whereIn: ['pending', 'approved', 'confirmed'])
            .get();

        if (existingBookings.docs.isNotEmpty) {
          return {
            'available': false,
            'reason': 'This time slot is already booked',
            'currentBookings': existingBookings.docs.length,
            'maxCapacity': maxCapacity,
          };
        }

        return {
          'available': true,
          'currentBookings': 0,
          'maxCapacity': maxCapacity,
        };
      }

      // If multiple bookings allowed, check capacity
      final existingBookings = await _firestore
          .collection(_bookingsCollection)
          .where('amenityId', isEqualTo: amenityId)
          .where('bookingDate', isEqualTo: bookingDate)
          .where('timeSlot', isEqualTo: timeSlot)
          .where('status', whereIn: ['pending', 'approved', 'confirmed'])
          .get();

      final currentBookings = existingBookings.docs.length;

      if (currentBookings >= maxCapacity) {
        return {
          'available': false,
          'reason': 'Maximum capacity reached ($maxCapacity/$maxCapacity)',
          'currentBookings': currentBookings,
          'maxCapacity': maxCapacity,
        };
      }

      return {
        'available': true,
        'currentBookings': currentBookings,
        'maxCapacity': maxCapacity,
        'spotsLeft': maxCapacity - currentBookings,
      };
    } catch (e) {
      print('AmenityService ERROR: Failed to check availability: $e');
      throw Exception('Failed to check availability: $e');
    }
  }

  // Get bookings count for a specific slot
  Future<int> getSlotBookingsCount({
    required String amenityId,
    required String bookingDate,
    required String timeSlot,
  }) async {
    try {
      final bookings = await _firestore
          .collection(_bookingsCollection)
          .where('amenityId', isEqualTo: amenityId)
          .where('bookingDate', isEqualTo: bookingDate)
          .where('timeSlot', isEqualTo: timeSlot)
          .where('status', whereIn: ['pending', 'approved', 'confirmed'])
          .get();

      return bookings.docs.length;
    } catch (e) {
      print('AmenityService ERROR: Failed to get bookings count: $e');
      return 0;
    }
  }

  // Get bookings by date range for calendar view
  Stream<List<AmenityBookingModel>> getBookingsByDateRange({
    required DateTime startDate,
    required DateTime endDate,
  }) {
    final adminId = _adminService.getCurrentAdminId();
    if (adminId == null) return Stream.value([]);

    final startDateStr = _formatDate(startDate);
    final endDateStr = _formatDate(endDate);

    print(
      'AmenityService: Fetching bookings from $startDateStr to $endDateStr',
    );

    return _firestore
        .collection(_bookingsCollection)
        .where(
          'communityId',
          isEqualTo: _adminService.requireCurrentCommunityId(),
        )
        .where('bookingDate', isGreaterThanOrEqualTo: startDateStr)
        .where('bookingDate', isLessThanOrEqualTo: endDateStr)
        .snapshots()
        .map((snapshot) {
          print(
            'AmenityService: Found ${snapshot.docs.length} bookings in date range',
          );
          return snapshot.docs.map((doc) {
            final data = doc.data();
            return AmenityBookingModel.fromFirestore(doc.id, data);
          }).toList();
        });
  }

  // Get bookings grouped by date for calendar filtered by adminId
  Future<Map<DateTime, List<AmenityBookingModel>>> getBookingsGroupedByDate({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final adminId = _adminService.getCurrentAdminId();
    if (adminId == null) return {};

    print(
      'AmenityService: Fetching bookings for admin: $adminId, date range: $startDate to $endDate',
    );

    try {
      // Fetch bookings filtered by adminId
      final snapshot = await _firestore
          .collection(_bookingsCollection)
          .where(
            'communityId',
            isEqualTo: _adminService.requireCurrentCommunityId(),
          )
          .get();

      print('AmenityService: Total bookings found: ${snapshot.docs.length}');

      final Map<DateTime, List<AmenityBookingModel>> groupedBookings = {};

      for (var doc in snapshot.docs) {
        final data = doc.data();
        print('AmenityService: Processing booking ${doc.id}');

        final booking = AmenityBookingModel.fromFirestore(doc.id, data);

        // Get date from Timestamp 'date' field
        DateTime? bookingDate;

        if (data['date'] != null && data['date'] is Timestamp) {
          bookingDate = (data['date'] as Timestamp).toDate();
          print('AmenityService: Booking date: $bookingDate');
        }

        if (bookingDate != null) {
          // Check if date is in range
          if (bookingDate.isBefore(startDate) || bookingDate.isAfter(endDate)) {
            print('AmenityService: Date outside range, skipping');
            continue;
          }

          // Normalize to midnight
          final normalizedDate = DateTime(
            bookingDate.year,
            bookingDate.month,
            bookingDate.day,
          );

          print('AmenityService: Adding to date: $normalizedDate');

          if (!groupedBookings.containsKey(normalizedDate)) {
            groupedBookings[normalizedDate] = [];
          }
          groupedBookings[normalizedDate]!.add(booking);
        }
      }

      print(
        'AmenityService: Grouped ${groupedBookings.length} dates with bookings',
      );
      return groupedBookings;
    } catch (e, stackTrace) {
      print('AmenityService ERROR: $e');
      print('AmenityService ERROR Stack: $stackTrace');
      return {};
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

// Amenity Model
class AmenityModel {
  final String id;
  final String name;
  final String type;
  final bool isFree;
  final double pricePerDay;
  final String? description;
  final String? iconName;
  final String? imageUrl;
  final bool isAvailable;
  final List<String>? timeSlots; // Time slots like "6:00 AM - 7:00 AM"
  final String buildingId;
  final String buildingName;
  final String adminId;
  // Booking Configuration
  final int maxCapacity; // Maximum number of people/bookings at same time
  final bool
  allowMultipleBookings; // Allow multiple bookings for same time slot
  final List<String>
  bookingDurations; // e.g., ["1 hour", "Half day", "Full day"]
  // Subscription Packages
  final bool
  hasSubscriptionPackages; // Whether this amenity offers subscriptions
  final Map<String, double>
  subscriptionPackages; // e.g., {"Weekly": 500, "Monthly": 1500, "Yearly": 15000}
  final DateTime? createdAt;
  final DateTime? updatedAt;

  AmenityModel({
    required this.id,
    required this.name,
    required this.type,
    required this.isFree,
    required this.pricePerDay,
    this.description,
    this.iconName,
    this.imageUrl,
    required this.isAvailable,
    this.timeSlots,
    required this.buildingId,
    required this.buildingName,
    required this.adminId,
    required this.maxCapacity,
    required this.allowMultipleBookings,
    required this.bookingDurations,
    required this.hasSubscriptionPackages,
    required this.subscriptionPackages,
    this.createdAt,
    this.updatedAt,
  });

  factory AmenityModel.fromFirestore(String id, Map<String, dynamic> data) {
    return AmenityModel(
      id: id,
      name: data['name'] ?? '',
      type: data['type'] ?? '',
      isFree: data['isFree'] ?? true,
      pricePerDay: (data['pricePerDay'] ?? 0).toDouble(),
      description: data['description'],
      iconName: data['iconName'],
      imageUrl: data['imageUrl'],
      isAvailable: data['isAvailable'] ?? true,
      timeSlots: data['timeSlots'] != null
          ? List<String>.from(data['timeSlots'])
          : null,
      buildingId: data['buildingId'] ?? '',
      buildingName: data['buildingName'] ?? '',
      adminId: data['adminId'] ?? '',
      maxCapacity: data['maxCapacity'] ?? 1,
      allowMultipleBookings: data['allowMultipleBookings'] ?? false,
      bookingDurations: data['bookingDurations'] != null
          ? List<String>.from(data['bookingDurations'])
          : ['1 hour'],
      hasSubscriptionPackages: data['hasSubscriptionPackages'] ?? false,
      subscriptionPackages: data['subscriptionPackages'] != null
          ? Map<String, double>.from(
              (data['subscriptionPackages'] as Map).map(
                (key, value) =>
                    MapEntry(key.toString(), (value as num).toDouble()),
              ),
            )
          : {},
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  String get priceDisplay {
    if (isFree) return 'Free';
    if (hasSubscriptionPackages && subscriptionPackages.isNotEmpty) {
      final firstPackage = subscriptionPackages.entries.first;
      return '₹${firstPackage.value.toStringAsFixed(0)}/${firstPackage.key}';
    }
    return '₹${pricePerDay.toStringAsFixed(0)}/day';
  }

  String get capacityDisplay {
    if (maxCapacity == 1) return '1 person';
    return '$maxCapacity people max';
  }

  IconData get icon {
    switch (iconName) {
      case 'pool':
        return Icons.pool;
      case 'gym':
        return Icons.fitness_center;
      case 'hall':
        return Icons.home;
      case 'lawn':
        return Icons.grass;
      case 'parking':
        return Icons.local_parking;
      case 'playground':
        return Icons.sports_soccer;
      default:
        return Icons.apartment;
    }
  }

  Color get color {
    switch (type.toLowerCase()) {
      case 'sports':
        return Color(0xFF10B981);
      case 'recreation':
        return Color(0xFF2563EB);
      case 'event':
        return Color(0xFF8B5CF6);
      case 'facility':
        return Color(0xFFF4A100);
      default:
        return Color(0xFF6B7280);
    }
  }
}

// Amenity Booking Model
class AmenityBookingModel {
  final String id;
  final String amenityId;
  final String amenityName;
  final String buildingId;
  final String buildingName;
  final String userId;
  final String residentId;
  final String residentName;
  final String flatId;
  final String flatLabel;
  final String phone;
  final String? email;
  final String bookingDate; // YYYY-MM-DD format
  final DateTime? bookingDateTimestamp;
  final String timeSlot; // "6:00 AM - 7:00 AM"
  final String startTime; // "06:00"
  final String endTime; // "07:00"
  final String
  status; // confirmed, cancelled, completed, pending, approved, rejected
  final double amount;
  final String? rejectionReason;
  final String adminId;
  // Package/Subscription fields
  final String? packageType; // "daily", "weekly", "monthly", "yearly"
  final DateTime? packageStartDate;
  final DateTime? packageEndDate;
  final int? packageDurationDays;
  // Family/Group booking fields
  final int totalMembers; // Total people in booking
  final List<String>? familyMemberNames; // Names of family members
  final List<Map<String, dynamic>>?
  familyMembers; // Detailed family member info
  // Capacity tracking
  final int? slotCapacity; // Max capacity for this slot
  final int? currentBookings; // Current bookings for this slot
  final int? spotsRemaining; // Remaining spots
  // Additional booking details
  final String? bookingType; // "single", "recurring", "package"
  final String? notes; // Special notes or requirements
  final String? paymentStatus; // "paid", "pending", "refunded"
  final String? paymentMethod; // "cash", "online", "card"
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? bookedAt;
  final DateTime? approvedAt;
  final DateTime? rejectedAt;
  final DateTime? cancelledAt;

  AmenityBookingModel({
    required this.id,
    required this.amenityId,
    required this.amenityName,
    required this.buildingId,
    required this.buildingName,
    required this.userId,
    required this.residentId,
    required this.residentName,
    required this.flatId,
    required this.flatLabel,
    required this.phone,
    this.email,
    required this.bookingDate,
    this.bookingDateTimestamp,
    required this.timeSlot,
    required this.startTime,
    required this.endTime,
    required this.status,
    required this.amount,
    this.rejectionReason,
    required this.adminId,
    this.packageType,
    this.packageStartDate,
    this.packageEndDate,
    this.packageDurationDays,
    this.totalMembers = 1,
    this.familyMemberNames,
    this.familyMembers,
    this.slotCapacity,
    this.currentBookings,
    this.spotsRemaining,
    this.bookingType,
    this.notes,
    this.paymentStatus,
    this.paymentMethod,
    this.createdAt,
    this.updatedAt,
    this.bookedAt,
    this.approvedAt,
    this.rejectedAt,
    this.cancelledAt,
  });

  factory AmenityBookingModel.fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    // Handle date field - Firestore uses 'date' as Timestamp
    DateTime? dateTimestamp;
    String dateString = '';

    if (data['date'] != null && data['date'] is Timestamp) {
      dateTimestamp = (data['date'] as Timestamp).toDate();
      dateString =
          '${dateTimestamp.year}-${dateTimestamp.month.toString().padLeft(2, '0')}-${dateTimestamp.day.toString().padLeft(2, '0')}';
    }

    // Parse family members list
    List<String>? familyMemberNames;
    List<Map<String, dynamic>>? familyMembers;

    if (data['familyMemberNames'] != null) {
      familyMemberNames = List<String>.from(data['familyMemberNames']);
    }

    if (data['familyMembers'] != null) {
      familyMembers = List<Map<String, dynamic>>.from(
        (data['familyMembers'] as List).map(
          (item) => Map<String, dynamic>.from(item),
        ),
      );
    }

    return AmenityBookingModel(
      id: id,
      amenityId: data['amenityId'] ?? '',
      amenityName: data['amenityName'] ?? '',
      buildingId: data['buildingId'] ?? '',
      buildingName: data['buildingName'] ?? '',
      userId: data['userId'] ?? '',
      residentId: data['residentId'] ?? data['userId'] ?? '',
      residentName: data['residentName'] ?? data['userName'] ?? '',
      flatId: data['flatId'] ?? '',
      flatLabel: data['flatLabel'] ?? '',
      phone: data['phone'] ?? data['userPhone'] ?? '',
      email: data['email'] ?? data['userEmail'],
      bookingDate: dateString,
      bookingDateTimestamp: dateTimestamp,
      timeSlot: data['timeSlot'] ?? '',
      startTime: data['startTime'] ?? '',
      endTime: data['endTime'] ?? '',
      status: data['status'] ?? 'pending',
      amount: (data['amount'] ?? 0).toDouble(),
      rejectionReason: data['rejectionReason'],
      adminId: data['adminId'] ?? '',
      // Package fields
      packageType: data['packageType'],
      packageStartDate: (data['packageStartDate'] as Timestamp?)?.toDate(),
      packageEndDate: (data['packageEndDate'] as Timestamp?)?.toDate(),
      packageDurationDays: data['packageDurationDays'],
      // Family/Group fields
      totalMembers: data['totalMembers'] ?? 1,
      familyMemberNames: familyMemberNames,
      familyMembers: familyMembers,
      // Capacity fields
      slotCapacity: data['slotCapacity'],
      currentBookings: data['currentBookings'],
      spotsRemaining: data['spotsRemaining'],
      // Additional fields
      bookingType: data['bookingType'],
      notes: data['notes'],
      paymentStatus: data['paymentStatus'],
      paymentMethod: data['paymentMethod'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      bookedAt: (data['bookedAt'] as Timestamp?)?.toDate(),
      approvedAt: (data['approvedAt'] as Timestamp?)?.toDate(),
      rejectedAt: (data['rejectedAt'] as Timestamp?)?.toDate(),
      cancelledAt: (data['cancelledAt'] as Timestamp?)?.toDate(),
    );
  }

  String get formattedDate {
    // Try to use bookingDateTimestamp first if available
    if (bookingDateTimestamp != null) {
      return '${bookingDateTimestamp!.day.toString().padLeft(2, '0')}/${bookingDateTimestamp!.month.toString().padLeft(2, '0')}/${bookingDateTimestamp!.year}';
    }

    // Fall back to parsing bookingDate string
    if (bookingDate.isEmpty) return '';

    // Parse YYYY-MM-DD format
    try {
      final parts = bookingDate.split('-');
      if (parts.length == 3) {
        return '${parts[2]}/${parts[1]}/${parts[0]}'; // DD/MM/YYYY
      }
    } catch (e) {
      print('Error parsing date: $e');
    }
    return bookingDate;
  }

  String get formattedTime {
    return timeSlot; // Already in "6:00 AM - 7:00 AM" format
  }

  String get packageDisplay {
    if (packageType == null) return 'Single booking';

    switch (packageType!.toLowerCase()) {
      case 'daily':
        return 'Daily Package';
      case 'weekly':
        return 'Weekly Package';
      case 'monthly':
        return 'Monthly Package';
      case 'yearly':
        return 'Yearly Package';
      default:
        return packageType!;
    }
  }

  String get packageDurationDisplay {
    if (packageStartDate == null || packageEndDate == null) return '';

    final start =
        '${packageStartDate!.day}/${packageStartDate!.month}/${packageStartDate!.year}';
    final end =
        '${packageEndDate!.day}/${packageEndDate!.month}/${packageEndDate!.year}';

    return '$start - $end';
  }

  String get capacityDisplay {
    if (slotCapacity == null) return '';

    final current = currentBookings ?? 0;
    final remaining = spotsRemaining ?? (slotCapacity! - current);

    return '$current/$slotCapacity booked ($remaining spots left)';
  }

  String get membersDisplay {
    if (totalMembers <= 1) return '1 person';
    return '$totalMembers people';
  }

  Color get statusColor {
    switch (status.toLowerCase()) {
      case 'confirmed':
      case 'approved':
        return Color(0xFF10B981);
      case 'pending':
        return Color(0xFFF4A100);
      case 'rejected':
        return Color(0xFFEF4444);
      case 'cancelled':
        return Color(0xFF6B7280);
      case 'completed':
        return Color(0xFF2563EB);
      default:
        return Color(0xFF6B7280);
    }
  }

  String get statusDisplay {
    return status[0].toUpperCase() + status.substring(1);
  }

  Color get paymentStatusColor {
    switch (paymentStatus?.toLowerCase() ?? '') {
      case 'paid':
        return Color(0xFF10B981);
      case 'pending':
        return Color(0xFFF4A100);
      case 'refunded':
        return Color(0xFF6B7280);
      default:
        return Color(0xFF6B7280);
    }
  }
}
