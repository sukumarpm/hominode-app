// lib/src/services/booking_firestore_service.dart
// Booking Firestore Service - Real-time amenities and bookings management

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/booking.dart';
import 'user_data_service.dart';

/// Amenity model for real-time streaming
class AmenityModel {
  final String id;
  final String name;
  final String type;
  final bool isFree;
  final double? pricePerDay;
  final List<String> timeSlots;
  final bool isAvailable;
  final String? buildingId;
  final String? organizationId;
  final String? iconName;
  final String? imageUrl;
  final String? description;

  // Subscription packages
  final bool hasSubscriptionPackages;
  final Map<String, double>? subscriptionPackages;

  // Capacity management
  final bool allowMultipleBookings;
  final int maxCapacity;

  // Booking durations
  final List<String> bookingDurations;

  AmenityModel({
    required this.id,
    required this.name,
    required this.type,
    required this.isFree,
    this.pricePerDay,
    required this.timeSlots,
    required this.isAvailable,
    this.buildingId,
    this.organizationId,
    this.iconName,
    this.imageUrl,
    this.description,
    this.hasSubscriptionPackages = false,
    this.subscriptionPackages,
    this.allowMultipleBookings = false,
    this.maxCapacity = 1,
    this.bookingDurations = const ['1 hour'],
  });

  factory AmenityModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;

    if (data == null) {
      throw Exception('Amenity document data is null');
    }

    // FIX: Convert List<dynamic> to List<String> safely
    List<String> timeSlots = [];
    try {
      final rawTimeSlots = data['timeSlots'];
      if (rawTimeSlots != null && rawTimeSlots is List) {
        timeSlots = List<String>.from(rawTimeSlots.cast<String>());
      }
    } catch (e) {
      print('⚠️  Error parsing timeSlots: $e');
      timeSlots = [];
    }

    // Parse subscription packages
    Map<String, double>? packages;
    if (data['subscriptionPackages'] != null) {
      try {
        final packagesData =
            data['subscriptionPackages'] as Map<String, dynamic>?;
        if (packagesData != null) {
          packages = packagesData.map(
            (key, value) => MapEntry(key, (value as num).toDouble()),
          );
        }
      } catch (e) {
        print('⚠️  Error parsing subscriptionPackages: $e');
        packages = null;
      }
    }

    // FIX: Convert bookingDurations safely
    List<String> bookingDurations = ['1 hour'];
    try {
      final rawDurations = data['bookingDurations'];
      if (rawDurations != null && rawDurations is List) {
        bookingDurations = List<String>.from(rawDurations.cast<String>());
      }
    } catch (e) {
      print('⚠️  Error parsing bookingDurations: $e');
      bookingDurations = ['1 hour'];
    }

    // FIX: Safe null checks for all fields
    final maxCapacity = (data['maxCapacity'] as num?)?.toInt() ?? 1;
    final pricePerDay = (data['pricePerDay'] as num?)?.toDouble();

    return AmenityModel(
      id: doc.id,
      name: (data['name'] as String?)?.trim() ?? 'Unknown Amenity',
      type: data['type'] ?? 'General',
      isFree: data['isFree'] ?? false,
      pricePerDay: (data['pricePerDay'] as num?)?.toDouble(),
      timeSlots: timeSlots,
      isAvailable: data['isAvailable'] ?? true,
      buildingId: data['buildingId']?.toString(),
      organizationId: data['organizationId']?.toString(),
      iconName: data['iconName']?.toString(),
      imageUrl: data['imageUrl']?.toString(),
      description: data['description']?.toString(),
      hasSubscriptionPackages: data['hasSubscriptionPackages'] ?? false,
      subscriptionPackages: packages,
      allowMultipleBookings: data['allowMultipleBookings'] ?? false,
      maxCapacity: data['maxCapacity'] ?? 1,
      bookingDurations: bookingDurations,
    );
  }

  String get priceDisplay {
    if (isFree) return 'Free';
    if (pricePerDay != null) return '₹${pricePerDay!.toStringAsFixed(0)}/day';
    return 'Free';
  }

  String get timeSlotsDisplay {
    if (timeSlots.isEmpty) return 'No time slots available';
    if (timeSlots.length == 1) return timeSlots.first;
    return '${timeSlots.length} slots available';
  }

  String get capacityDisplay {
    if (!allowMultipleBookings) return 'Single booking';
    return 'Up to $maxCapacity users';
  }

  bool get hasPackages =>
      hasSubscriptionPackages &&
      subscriptionPackages != null &&
      subscriptionPackages!.isNotEmpty;
}

/// Result class for booking operations
class BookingResult {
  final bool success;
  final String? message;
  final String? bookingId;
  final String? errorCode;

  BookingResult({
    required this.success,
    this.message,
    this.bookingId,
    this.errorCode,
  });

  factory BookingResult.success({String? message, String? bookingId}) {
    return BookingResult(
      success: true,
      message: message ?? 'Operation successful',
      bookingId: bookingId,
    );
  }

  factory BookingResult.failure({required String message, String? errorCode}) {
    return BookingResult(
      success: false,
      message: message,
      errorCode: errorCode,
    );
  }
}

/// Booking Firestore Service
class BookingFirestoreService {
  // Singleton pattern
  static final BookingFirestoreService instance =
      BookingFirestoreService._internal();
  factory BookingFirestoreService() => instance;
  BookingFirestoreService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final UserDataService _userDataService = UserDataService();

  // Collection names
  static const String bookingsCollection = 'bookings';
  static const String amenitiesCollection = 'amenities';

  /// Get current user ID (Firebase Auth or SharedPreferences fallback)
  /// Following the flow function pattern from UserDataService
  Future<String?> _getUserId() async {
    try {
      // First try Firebase Auth
      final firebaseUser = _auth.currentUser;
      if (firebaseUser != null) {
        print('🆔 BookingService: Firebase Auth User: ${firebaseUser.uid}');

        // Try to find user document by Firebase Auth UID
        final doc = await _firestore
            .collection('users')
            .doc(firebaseUser.uid)
            .get();

        if (doc.exists) {
          print('✅ BookingService: Found user document by Firebase Auth UID');
          return doc.id;
        } else {
          // Try to find by authUid field
          print('🔍 BookingService: Searching by authUid field...');
          final querySnapshot = await _firestore
              .collection('users')
              .where('authUid', isEqualTo: firebaseUser.uid)
              .limit(1)
              .get();

          if (querySnapshot.docs.isNotEmpty) {
            print('✅ BookingService: Found user document by authUid field');
            return querySnapshot.docs.first.id;
          }
        }
      }

      // Fallback to SharedPreferences
      print(
        '⚠️  BookingService: No Firebase Auth user, checking SharedPreferences...',
      );
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');

      if (userId != null) {
        print('🆔 BookingService: Using stored User ID: $userId');
      } else {
        print('❌ BookingService: No user ID found');
      }

      return userId;
    } catch (e) {
      print('❌ BookingService: Error getting user ID: $e');
      return null;
    }
  }

  /// Get current user data from Firestore
  Future<Map<String, dynamic>?> _getUserData() async {
    try {
      final userId = await _getUserId();
      if (userId == null) {
        print('❌ No user logged in');
        return null;
      }

      final userDoc = await _firestore.collection('users').doc(userId).get();

      if (!userDoc.exists) {
        print('❌ User document not found');
        return null;
      }

      final userData = userDoc.data() as Map<String, dynamic>;

      // CRITICAL: Use Firebase Auth UID for userId, not Firestore document ID
      // This is required for Firestore rules to work
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser != null) {
        userData['userId'] = firebaseUser.uid;
        print('✅ Using Firebase Auth UID as userId: ${firebaseUser.uid}');
      } else {
        userData['userId'] = userId;
        print('⚠️  Using Firestore document ID as userId: $userId');
      }

      return userData;
    } catch (e) {
      print('❌ Error fetching user data: $e');
      return null;
    }
  }

  // ============================================================================
  // REAL-TIME AMENITIES STREAMING
  // ============================================================================

  /// Stream amenities in real-time filtered by buildingId and isAvailable
  /// Following the flow function pattern
  Stream<List<AmenityModel>> streamAmenitiesRealtime() async* {
    try {
      print('🔄 Starting real-time amenities stream...');

      // Verify user is authenticated
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        print('❌ User not authenticated');
        yield [];
        return;
      }

      // Get current user data
      final userData = await _getUserData();
      if (userData == null) {
        print('❌ No user data available');
        yield [];
        return;
      }

      final buildingId = userData['buildingId']?.toString();
      final organizationId = userData['organizationId']?.toString();

      print('👤 User: ${userData['name']}');
      print('🏢 Building ID: $buildingId');
      print('🏛️  Organization ID: $organizationId');

      // Build query - filter by isAvailable and buildingId
      Query query = _firestore
          .collection(amenitiesCollection)
          .where('isAvailable', isEqualTo: true);

      // Add buildingId filter if available
      if (buildingId != null && buildingId.isNotEmpty) {
        query = query.where('buildingId', isEqualTo: buildingId);
        print('✅ Filtering by buildingId: $buildingId');
      } else {
        print('⚠️  No buildingId - showing all available amenities');
      }

      // Stream the query results
      yield* query.snapshots().map((snapshot) {
        print('📊 Received ${snapshot.docs.length} amenities from stream');

        final amenities = snapshot.docs
            .map((doc) {
              try {
                return AmenityModel.fromFirestore(doc);
              } catch (e) {
                print('⚠️  Error parsing amenity ${doc.id}: $e');
                return null;
              }
            })
            .whereType<AmenityModel>()
            .toList();

        if (amenities.isNotEmpty) {
          print('✅ Streaming ${amenities.length} amenities:');
          for (var amenity in amenities) {
            print(
              '  📍 ${amenity.name} - ${amenity.priceDisplay} - ${amenity.timeSlotsDisplay}',
            );
          }
        } else {
          print('⚠️  No amenities available');
        }

        return amenities;
      });
    } catch (e, stackTrace) {
      print('❌ Error in amenities stream: $e');
      print('Stack trace: $stackTrace');
      yield [];
    }
  }

  // ============================================================================
  // REAL-TIME BOOKINGS STREAMING
  // ============================================================================

  /// Stream user's bookings in real-time
  Stream<List<BookingModel>> streamMyBookingsRealtime() async* {
    try {
      print('🔄 Starting real-time bookings stream...');

      final userId = await _getUserId();
      if (userId == null) {
        print('❌ No user logged in');
        yield [];
        return;
      }

      print('✅ Streaming bookings for user: $userId');

      // Stream bookings filtered by userId (no orderBy to avoid index requirement)
      yield* _firestore
          .collection(bookingsCollection)
          .where('userId', isEqualTo: userId)
          .snapshots()
          .map((snapshot) {
            print('📊 Received ${snapshot.docs.length} bookings from stream');

            final bookings = snapshot.docs
                .map((doc) {
                  try {
                    return _bookingFromFirestore(doc);
                  } catch (e) {
                    print('⚠️  Error parsing booking ${doc.id}: $e');
                    return null;
                  }
                })
                .whereType<BookingModel>()
                .toList();

            // Sort in memory by date (newest first)
            bookings.sort((a, b) => b.date.compareTo(a.date));

            if (bookings.isNotEmpty) {
              print('✅ Streaming ${bookings.length} bookings');
            } else {
              print('⚠️  No bookings found');
            }

            return bookings;
          });
    } catch (e, stackTrace) {
      print('❌ Error in bookings stream: $e');
      print('Stack trace: $stackTrace');
      yield [];
    }
  }

  /// Get amenity details including time slots
  Future<AmenityModel?> getAmenityDetails(String amenityId) async {
    try {
      print('📥 Fetching amenity details for: $amenityId');

      final doc = await _firestore
          .collection(amenitiesCollection)
          .doc(amenityId)
          .get();

      if (!doc.exists) {
        print('❌ Amenity not found');
        return null;
      }

      final amenity = AmenityModel.fromFirestore(doc);
      print('✅ Amenity details fetched: ${amenity.name}');
      print('   Time slots: ${amenity.timeSlots}');
      print('   Has packages: ${amenity.hasPackages}');
      print('   Allow multiple: ${amenity.allowMultipleBookings}');
      print('   Max capacity: ${amenity.maxCapacity}');

      return amenity;
    } catch (e) {
      print('❌ Error fetching amenity details: $e');
      return null;
    }
  }

  /// Check slot availability and get remaining capacity
  Future<Map<String, dynamic>> checkSlotAvailability({
    required String amenityId,
    required DateTime date,
    required String timeSlot,
    int numberOfPeople = 1, // NEW: Number of people to book for
  }) async {
    try {
      print(
        '🔍 Checking availability for $amenityId on ${date.toString().split(' ')[0]} at $timeSlot for $numberOfPeople people',
      );

      // Get amenity details
      final amenity = await getAmenityDetails(amenityId);
      if (amenity == null) {
        print('❌ Amenity not found');
        return {
          'available': false,
          'reason': 'Amenity not found',
          'remainingSpots': 0,
          'totalCapacity': 0,
        };
      }

      // Query existing bookings for this date and time slot
      // Use simpler query to avoid index requirements
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

      print(
        '📅 Querying bookings from ${startOfDay.toString()} to ${endOfDay.toString()}',
      );

      final bookingsSnapshot = await _firestore
          .collection(bookingsCollection)
          .where('amenityId', isEqualTo: amenityId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
          .get();

      print('📊 Total bookings for this date: ${bookingsSnapshot.docs.length}');

      // Filter in memory for time slot and status
      final matchingBookings = bookingsSnapshot.docs.where((doc) {
        final data = doc.data();
        final docTimeSlot = data['timeSlot'] as String?;
        final docStatus = data['status'] as String?;

        return docTimeSlot == timeSlot &&
            (docStatus == 'confirmed' || docStatus == 'pending');
      }).toList();

      print(
        '📊 Found ${matchingBookings.length} bookings for time slot "$timeSlot"',
      );

      // NEW: Sum up numberOfPeople from all bookings (not just count bookings)
      int totalPeople = 0;
      for (var doc in matchingBookings) {
        final data = doc.data();
        final people = data['numberOfPeople'] as int? ?? 1;
        totalPeople += people;
        print(
          '  👥 Booking ${doc.id}: $people people (Status: ${data['status']})',
        );
      }

      print(
        '📊 Total people booked: $totalPeople out of ${amenity.maxCapacity}',
      );

      // Check availability based on amenity settings
      if (!amenity.allowMultipleBookings) {
        // Single booking only
        final available = matchingBookings.isEmpty;
        print('✅ Single booking mode: ${available ? "Available" : "Booked"}');
        return {
          'available': available,
          'reason': available ? 'Available' : 'Already booked',
          'remainingSpots': available ? 1 : 0,
          'totalCapacity': 1,
          'bookingCount': matchingBookings.length,
          'totalPeople': totalPeople,
        };
      } else {
        // Multiple bookings allowed - check if enough capacity for requested number of people
        final remainingSpots = amenity.maxCapacity - totalPeople;
        final canBook = remainingSpots >= numberOfPeople;
        print('✅ Multiple booking mode:');
        print('   Max capacity: ${amenity.maxCapacity}');
        print('   Total people booked: $totalPeople');
        print('   Remaining spots: $remainingSpots');
        print('   Requested: $numberOfPeople people');
        print('   Can book: $canBook');
        return {
          'available': canBook,
          'reason': canBook ? 'Available' : 'Not enough capacity',
          'remainingSpots': remainingSpots > 0 ? remainingSpots : 0,
          'totalCapacity': amenity.maxCapacity,
          'bookingCount': matchingBookings.length,
          'totalPeople': totalPeople,
        };
      }
    } catch (e, stackTrace) {
      print('❌ Error checking availability: $e');
      print('Stack trace: $stackTrace');
      // Return available by default on error to not block users
      return {
        'available': true,
        'reason': 'Unable to check availability',
        'remainingSpots': 1,
        'totalCapacity': 1,
        'error': e.toString(),
      };
    }
  }

  /// Get bookings for a date range (for calendar blocking)
  Future<Map<String, List<Map<String, dynamic>>>> getBookingsForDateRange({
    required String amenityId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      print(
        '📅 Fetching bookings from ${startDate.toString().split(' ')[0]} to ${endDate.toString().split(' ')[0]}',
      );

      final bookingsSnapshot = await _firestore
          .collection(bookingsCollection)
          .where('amenityId', isEqualTo: amenityId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .where('status', whereIn: ['confirmed', 'pending'])
          .get();

      // Group bookings by date and time slot
      final Map<String, List<Map<String, dynamic>>> bookingsByDate = {};

      for (var doc in bookingsSnapshot.docs) {
        final data = doc.data();
        final timestamp = data['date'] as Timestamp;
        final date = timestamp.toDate();
        final dateKey =
            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        final timeSlot = data['timeSlot'] as String;

        if (!bookingsByDate.containsKey(dateKey)) {
          bookingsByDate[dateKey] = [];
        }

        bookingsByDate[dateKey]!.add({
          'timeSlot': timeSlot,
          'bookingId': doc.id,
        });
      }

      print('✅ Found bookings for ${bookingsByDate.length} dates');
      return bookingsByDate;
    } catch (e) {
      print('❌ Error fetching bookings for date range: $e');
      return {};
    }
  }

  /// Check if a date is fully booked (all time slots full)
  Future<bool> isDateFullyBooked({
    required String amenityId,
    required DateTime date,
  }) async {
    try {
      final amenity = await getAmenityDetails(amenityId);
      if (amenity == null || amenity.timeSlots.isEmpty) return true;

      // Check each time slot
      for (var timeSlot in amenity.timeSlots) {
        final availability = await checkSlotAvailability(
          amenityId: amenityId,
          date: date,
          timeSlot: timeSlot,
        );

        if (availability['available'] == true) {
          return false; // At least one slot is available
        }
      }

      return true; // All slots are full
    } catch (e) {
      print('❌ Error checking if date is fully booked: $e');
      return true; // Assume fully booked on error
    }
  }

  // ============================================================================
  // CREATE BOOKING
  // ============================================================================

  /// Create a new booking in Firestore
  Future<BookingResult> createBooking({
    required String amenityId,
    required String amenityName,
    required DateTime date,
    required String timeSlot,
    String bookingType = 'daily', // NEW: 'daily', 'weekly', 'monthly', 'yearly'
    int numberOfPeople = 1, // NEW: Number of people
    List<String>? familyMembers, // NEW: Optional family member names
  }) async {
    try {
      print('🔵 Creating booking...');
      print('🏢 Amenity: $amenityName');
      print('📅 Date: $date');
      print('⏰ Time Slot: $timeSlot');
      print('📦 Booking Type: $bookingType');
      print('👥 Number of People: $numberOfPeople');

      // Get current user data
      final userData = await _getUserData();
      if (userData == null) {
        return BookingResult.failure(
          message: 'No user is currently signed in',
          errorCode: 'not-authenticated',
        );
      }

      final userId = userData['userId'] as String;
      final userName = userData['name'] ?? 'Unknown User';
      final userEmail = userData['email'] ?? '';
      final flatId = userData['flatId'] ?? '';
      final flatLabel = userData['flatLabel'] ?? userData['flatId'] ?? '';
      final buildingId = userData['buildingId'];
      final organizationId = userData['organizationId'];
      final communityId = userData['communityId']?.toString().trim() ?? '';
      if (communityId.isEmpty) {
        return BookingResult.failure(
          message: 'Your resident account is not assigned to a community.',
          errorCode: 'community-not-assigned',
        );
      }

      print('✅ User data fetched: $userName');
      print('🏢 Flat: $flatLabel');
      print('🏢 Building ID: $buildingId');

      // Get amenity details to fetch adminId and calculate price
      final amenity = await getAmenityDetails(amenityId);
      String? adminId;
      String? adminName;
      String? adminEmail;
      double price = 0;

      if (amenity != null) {
        // Fetch amenity document to get admin details
        final amenityDoc = await _firestore
            .collection(amenitiesCollection)
            .doc(amenityId)
            .get();

        if (amenityDoc.exists) {
          final amenityData = amenityDoc.data() as Map<String, dynamic>;
          adminId = amenityData['adminId']?.toString();
          adminName = amenityData['adminName']?.toString();
          adminEmail = amenityData['adminEmail']?.toString();

          print('✅ Admin data fetched: $adminName (ID: $adminId)');
        }

        // Calculate price based on booking type
        if (bookingType == 'daily') {
          price = amenity.pricePerDay ?? 0;
        } else if (amenity.subscriptionPackages != null) {
          final packageKey = bookingType == 'weekly'
              ? 'Weekly'
              : bookingType == 'monthly'
              ? 'Monthly'
              : 'Yearly';
          price = amenity.subscriptionPackages![packageKey] ?? 0;
        }

        print('💰 Calculated price: ₹$price');
      }

      // Calculate package dates
      final subscriptionStartDate = date;
      DateTime subscriptionEndDate;
      int validityDays;
      String? packageType;

      switch (bookingType) {
        case 'weekly':
          subscriptionEndDate = date.add(const Duration(days: 7));
          validityDays = 7;
          packageType = 'Weekly';
          break;
        case 'monthly':
          subscriptionEndDate = date.add(const Duration(days: 30));
          validityDays = 30;
          packageType = 'Monthly';
          break;
        case 'yearly':
          subscriptionEndDate = date.add(const Duration(days: 365));
          validityDays = 365;
          packageType = 'Yearly';
          break;
        default: // daily
          subscriptionEndDate = date;
          validityDays = 1;
          packageType = null;
      }

      print(
        '📅 Subscription: ${subscriptionStartDate.toString().split(' ')[0]} to ${subscriptionEndDate.toString().split(' ')[0]}',
      );
      print('⏳ Validity: $validityDays days');

      // Create booking document
      final bookingData = {
        // User Info
        'userId': userId,
        'userName': userName,
        'userEmail': userEmail,
        'flatId': flatId,
        'flatLabel': flatLabel,
        'buildingId': buildingId,
        'organizationId': organizationId,
        'communityId': communityId,

        // Amenity Info
        'amenityId': amenityId,
        'amenityName': amenityName,

        // Booking Type & Duration (NEW)
        'bookingType': bookingType,
        'packageType': packageType,

        // Date & Time
        'date': Timestamp.fromDate(date),
        'timeSlot': timeSlot,

        // Package Duration (NEW)
        'subscriptionStartDate': Timestamp.fromDate(subscriptionStartDate),
        'subscriptionEndDate': Timestamp.fromDate(subscriptionEndDate),
        'validityDays': validityDays,

        // Family Members (NEW)
        'numberOfPeople': numberOfPeople,

        // Pricing
        'price': price,
        'pricePerDay': amenity?.pricePerDay ?? 0,

        // Status
        'status': 'confirmed', // confirmed, cancelled, completed, expired
        'cancellationDate': null,
        'cancellationReason': null,

        // Timestamps
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Add admin details if available
      if (adminId != null) {
        bookingData['adminId'] = adminId;
        if (adminName != null) bookingData['adminName'] = adminName;
        if (adminEmail != null) bookingData['adminEmail'] = adminEmail;
      }

      // Add family members if provided
      if (familyMembers != null && familyMembers.isNotEmpty) {
        bookingData['familyMembers'] = familyMembers;
      }

      print('📦 Booking data: $bookingData');

      // Add to Firestore
      final docRef = await _firestore
          .collection(bookingsCollection)
          .add(bookingData);

      print('✅ Booking created successfully!');
      print('🆔 Booking ID: ${docRef.id}');

      return BookingResult.success(
        message: 'Booking confirmed successfully',
        bookingId: docRef.id,
      );
    } on FirebaseException catch (e) {
      print('❌ Firebase Error: ${e.code}');
      print('❌ Message: ${e.message}');
      return BookingResult.failure(
        message: _getErrorMessage(e.code),
        errorCode: e.code,
      );
    } catch (e) {
      print('❌ Unexpected Error: $e');
      return BookingResult.failure(
        message: 'Failed to create booking. Please try again.',
      );
    }
  }

  // ============================================================================
  // UPDATE BOOKING
  // ============================================================================

  /// Cancel booking
  Future<BookingResult> cancelBooking(
    String bookingId, {
    String? reason,
  }) async {
    try {
      print('🔵 Cancelling booking: $bookingId');
      if (reason != null) {
        print('📝 Reason: $reason');
      }

      final updateData = {
        'status': 'cancelled',
        'cancellationDate': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Add cancellation reason if provided
      if (reason != null && reason.isNotEmpty) {
        updateData['cancellationReason'] = reason;
      }

      await _firestore
          .collection(bookingsCollection)
          .doc(bookingId)
          .update(updateData);

      print('✅ Booking cancelled successfully');
      return BookingResult.success(message: 'Booking cancelled successfully');
    } on FirebaseException catch (e) {
      print('❌ Firebase Error: ${e.code}');
      return BookingResult.failure(
        message: _getErrorMessage(e.code),
        errorCode: e.code,
      );
    } catch (e) {
      print('❌ Error cancelling booking: $e');
      return BookingResult.failure(message: 'Failed to cancel booking');
    }
  }

  // ============================================================================
  // HELPER METHODS
  // ============================================================================

  /// Convert Firestore document to BookingModel object
  BookingModel _bookingFromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // Parse date timestamp
    DateTime date;
    try {
      final timestamp = data['date'] as Timestamp?;
      date = timestamp?.toDate() ?? DateTime.now();
    } catch (e) {
      date = DateTime.now();
    }

    // Parse createdAt timestamp
    DateTime createdAt;
    try {
      final timestamp = data['createdAt'] as Timestamp?;
      createdAt = timestamp?.toDate() ?? DateTime.now();
    } catch (e) {
      createdAt = DateTime.now();
    }

    // Parse subscription dates (NEW)
    DateTime? subscriptionStartDate;
    DateTime? subscriptionEndDate;
    try {
      final startTimestamp = data['subscriptionStartDate'] as Timestamp?;
      subscriptionStartDate = startTimestamp?.toDate();

      final endTimestamp = data['subscriptionEndDate'] as Timestamp?;
      subscriptionEndDate = endTimestamp?.toDate();
    } catch (e) {
      // Ignore parsing errors
    }

    return BookingModel(
      id: doc.id,
      amenityId: data['amenityId'] as String? ?? '',
      amenityName: data['amenityName'] as String? ?? 'Unknown',
      date: date,
      timeSlot: data['timeSlot'] as String? ?? '',
      status: data['status'] as String? ?? 'confirmed',
      createdAt: createdAt,
      userId: data['userId'] as String? ?? '',
      // NEW fields
      bookingType: data['bookingType'] as String? ?? 'daily',
      packageType: data['packageType'] as String?,
      numberOfPeople: data['numberOfPeople'] as int? ?? 1,
      subscriptionStartDate: subscriptionStartDate,
      subscriptionEndDate: subscriptionEndDate,
      validityDays: data['validityDays'] as int? ?? 1,
      price: (data['price'] as num?)?.toDouble() ?? 0,
    );
  }

  // ============================================================================
  // ERROR MESSAGES
  // ============================================================================

  String _getErrorMessage(String errorCode) {
    switch (errorCode) {
      case 'permission-denied':
        return 'Permission denied. Please check your access rights.';
      case 'unavailable':
        return 'Service temporarily unavailable. Please try again.';
      case 'not-found':
        return 'Booking not found.';
      case 'already-exists':
        return 'Booking already exists.';
      default:
        return 'An error occurred. Please try again.';
    }
  }
}
