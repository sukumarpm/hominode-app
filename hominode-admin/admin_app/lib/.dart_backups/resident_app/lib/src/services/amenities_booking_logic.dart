// lib/src/services/amenities_booking_logic.dart
// Amenities Booking Logic - Real-world timing and capacity rules

import 'package:cloud_firestore/cloud_firestore.dart';

/// Slot availability result
class SlotAvailability {
  final bool isAvailable;
  final String reason;
  final int remainingCapacity;
  final int totalCapacity;
  final int bookedPersons;
  final bool isPastTime;
  final bool isAtCapacity;

  SlotAvailability({
    required this.isAvailable,
    required this.reason,
    required this.remainingCapacity,
    required this.totalCapacity,
    required this.bookedPersons,
    required this.isPastTime,
    required this.isAtCapacity,
  });

  factory SlotAvailability.available({
    required int remainingCapacity,
    required int totalCapacity,
    required int bookedPersons,
  }) {
    return SlotAvailability(
      isAvailable: true,
      reason: 'Available',
      remainingCapacity: remainingCapacity,
      totalCapacity: totalCapacity,
      bookedPersons: bookedPersons,
      isPastTime: false,
      isAtCapacity: false,
    );
  }

  factory SlotAvailability.pastTime({
    required int totalCapacity,
  }) {
    return SlotAvailability(
      isAvailable: false,
      reason: 'Time slot has passed',
      remainingCapacity: 0,
      totalCapacity: totalCapacity,
      bookedPersons: 0,
      isPastTime: true,
      isAtCapacity: false,
    );
  }

  factory SlotAvailability.atCapacity({
    required int totalCapacity,
    required int bookedPersons,
  }) {
    return SlotAvailability(
      isAvailable: false,
      reason: 'Slot is at full capacity',
      remainingCapacity: 0,
      totalCapacity: totalCapacity,
      bookedPersons: bookedPersons,
      isPastTime: false,
      isAtCapacity: true,
    );
  }
}

/// Amenities Booking Logic Service
/// Implements real-world timing and capacity rules
class AmenitiesBookingLogic {
  static final AmenitiesBookingLogic instance =
      AmenitiesBookingLogic._internal();
  factory AmenitiesBookingLogic() => instance;
  AmenitiesBookingLogic._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ============================================================================
  // RULE 1: PAST TIME SLOTS - Hide slots that have already passed
  // ============================================================================

  /// Check if a time slot is in the past
  /// Returns true if the slot start time has already passed
  bool _isTimeSlotPast({
    required DateTime selectedDate,
    required String timeSlot,
    required DateTime currentTime,
  }) {
    try {
      print('🔍 Checking if time slot is past...');
      print('   Selected date: ${selectedDate.toString().split(' ')[0]}');
      print('   Current time: ${currentTime.toString()}');
      print('   Time slot: $timeSlot');

      // Check if selected date is today
      final today = DateTime(currentTime.year, currentTime.month, currentTime.day);
      final selectedDay = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);

      if (selectedDay.isBefore(today)) {
        print('❌ Selected date is in the past');
        return true;
      }

      if (selectedDay.isAfter(today)) {
        print('✅ Selected date is in the future - slot is not past');
        return false;
      }

      // Selected date is today - check if time slot has passed
      print('📅 Selected date is today - checking time slot...');

      // Parse time slot (format: "6:00 AM - 7:00 AM")
      final parts = timeSlot.split(' - ');
      if (parts.length != 2) {
        print('⚠️  Invalid time slot format: $timeSlot');
        return false;
      }

      final startTimeStr = parts[0].trim(); // "6:00 AM"
      final slotStartTime = _parseTimeString(startTimeStr);

      if (slotStartTime == null) {
        print('⚠️  Could not parse start time: $startTimeStr');
        return false;
      }

      // Create DateTime for slot start time today
      final slotDateTime = DateTime(
        today.year,
        today.month,
        today.day,
        slotStartTime['hour']!,
        slotStartTime['minute']!,
      );

      print('   Slot start time: ${slotDateTime.toString()}');
      print('   Current time: ${currentTime.toString()}');

      // Check if slot start time has passed or is equal to current time
      // Use <= instead of < to hide slots that are currently happening
      final isPast = slotDateTime.isBefore(currentTime) || slotDateTime.isAtSameMomentAs(currentTime);

      if (isPast) {
        print('❌ Time slot has passed (slot: ${slotDateTime.hour}:${slotDateTime.minute.toString().padLeft(2, '0')}, current: ${currentTime.hour}:${currentTime.minute.toString().padLeft(2, '0')})');
      } else {
        print('✅ Time slot is still available');
      }

      return isPast;
    } catch (e) {
      print('❌ Error checking if time slot is past: $e');
      return false;
    }
  }

  /// Parse time string (e.g., "6:00 AM" or "14:30") to hour and minute
  Map<String, int>? _parseTimeString(String timeStr) {
    try {
      timeStr = timeStr.trim().toUpperCase();

      // Handle 12-hour format (e.g., "6:00 AM", "2:30 PM")
      if (timeStr.contains('AM') || timeStr.contains('PM')) {
        final isPM = timeStr.contains('PM');
        final timePart = timeStr.replaceAll(RegExp(r'[AP]M'), '').trim();
        final parts = timePart.split(':');

        if (parts.length != 2) return null;

        int hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);

        // Convert to 24-hour format
        if (isPM && hour != 12) {
          hour += 12;
        } else if (!isPM && hour == 12) {
          hour = 0;
        }

        return {'hour': hour, 'minute': minute};
      }

      // Handle 24-hour format (e.g., "14:30")
      final parts = timeStr.split(':');
      if (parts.length != 2) return null;

      return {
        'hour': int.parse(parts[0]),
        'minute': int.parse(parts[1]),
      };
    } catch (e) {
      print('❌ Error parsing time string "$timeStr": $e');
      return null;
    }
  }

  // ============================================================================
  // RULE 2: SLOT CAPACITY - Hide slots at full capacity
  // ============================================================================

  /// Get total persons booked for a time slot
  /// Sums up numberOfPeople from all confirmed/pending bookings
  Future<int> _getTotalPersonsBooked({
    required String amenityId,
    required DateTime date,
    required String timeSlot,
  }) async {
    try {
      print('📊 Calculating total persons booked...');
      print('   Amenity: $amenityId');
      print('   Date: ${date.toString().split(' ')[0]}');
      print('   Time slot: $timeSlot');

      // Create date range for the day
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

      // Query bookings for this amenity and date
      final bookingsSnapshot = await _firestore
          .collection('amenityBookings')
          .where('amenityId', isEqualTo: amenityId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
          .get();

      print('📊 Found ${bookingsSnapshot.docs.length} total bookings for this date');

      // Filter for matching time slot and active status
      int totalPersons = 0;
      for (var doc in bookingsSnapshot.docs) {
        final data = doc.data();
        final docTimeSlot = data['timeSlot'] as String?;
        final docStatus = data['status'] as String?;
        final numberOfPeople = data['numberOfPeople'] as int? ?? 1;

        // Only count if time slot matches and status is confirmed or pending
        if (docTimeSlot == timeSlot &&
            (docStatus == 'confirmed' || docStatus == 'pending')) {
          totalPersons += numberOfPeople;
          print('   ✅ Booking: $numberOfPeople people (Status: $docStatus)');
        }
      }

      print('📊 Total persons booked for this slot: $totalPersons');
      return totalPersons;
    } catch (e) {
      print('❌ Error calculating total persons booked: $e');
      return 0;
    }
  }

  /// Check if a slot is at capacity
  Future<bool> _isSlotAtCapacity({
    required String amenityId,
    required DateTime date,
    required String timeSlot,
    required int capacity,
  }) async {
    try {
      final totalPersons = await _getTotalPersonsBooked(
        amenityId: amenityId,
        date: date,
        timeSlot: timeSlot,
      );

      final atCapacity = totalPersons >= capacity;

      if (atCapacity) {
        print('❌ Slot is at full capacity ($totalPersons/$capacity)');
      } else {
        print('✅ Slot has available capacity ($totalPersons/$capacity)');
      }

      return atCapacity;
    } catch (e) {
      print('❌ Error checking if slot is at capacity: $e');
      return false;
    }
  }

  // ============================================================================
  // MAIN LOGIC: Filter available slots
  // ============================================================================

  /// Get available time slots for a given date
  /// Applies both RULE 1 (past time) and RULE 2 (capacity)
  Future<List<String>> getAvailableTimeSlots({
    required String amenityId,
    required DateTime selectedDate,
    required List<String> allTimeSlots,
    required int capacity,
    DateTime? currentTime,
  }) async {
    try {
      print('🔵 AMENITIES BOOKING LOGIC: Getting available time slots...');
      print('   Amenity: $amenityId');
      print('   Date: ${selectedDate.toString().split(' ')[0]}');
      print('   Total slots: ${allTimeSlots.length}');
      print('   Capacity: $capacity');

      // Use provided current time or system time
      final now = currentTime ?? DateTime.now();

      final availableSlots = <String>[];

      for (var timeSlot in allTimeSlots) {
        print('\n📍 Checking slot: $timeSlot');

        // RULE 1: Check if time slot is in the past
        final isPast = _isTimeSlotPast(
          selectedDate: selectedDate,
          timeSlot: timeSlot,
          currentTime: now,
        );

        if (isPast) {
          print('   ❌ RULE 1 FAILED: Time slot has passed');
          continue;
        }

        print('   ✅ RULE 1 PASSED: Time slot is not in the past');

        // RULE 2: Check if slot is at capacity
        final atCapacity = await _isSlotAtCapacity(
          amenityId: amenityId,
          date: selectedDate,
          timeSlot: timeSlot,
          capacity: capacity,
        );

        if (atCapacity) {
          print('   ❌ RULE 2 FAILED: Slot is at full capacity');
          continue;
        }

        print('   ✅ RULE 2 PASSED: Slot has available capacity');

        // Both rules passed - slot is available
        print('   ✅ SLOT AVAILABLE');
        availableSlots.add(timeSlot);
      }

      print('\n✅ RESULT: ${availableSlots.length} available slots out of ${allTimeSlots.length}');
      if (availableSlots.isNotEmpty) {
        print('   Available slots: $availableSlots');
      }

      return availableSlots;
    } catch (e, stackTrace) {
      print('❌ Error getting available time slots: $e');
      print('   Stack trace: $stackTrace');
      return [];
    }
  }

  /// Get detailed availability for each time slot
  /// Returns SlotAvailability object with reason for unavailability
  Future<Map<String, SlotAvailability>> getSlotAvailabilityDetails({
    required String amenityId,
    required DateTime selectedDate,
    required List<String> allTimeSlots,
    required int capacity,
    DateTime? currentTime,
  }) async {
    try {
      print('🔵 Getting detailed slot availability...');

      final now = currentTime ?? DateTime.now();
      final availabilityMap = <String, SlotAvailability>{};

      for (var timeSlot in allTimeSlots) {
        // RULE 1: Check if time slot is in the past
        final isPast = _isTimeSlotPast(
          selectedDate: selectedDate,
          timeSlot: timeSlot,
          currentTime: now,
        );

        if (isPast) {
          availabilityMap[timeSlot] = SlotAvailability.pastTime(
            totalCapacity: capacity,
          );
          continue;
        }

        // RULE 2: Check capacity
        final totalPersons = await _getTotalPersonsBooked(
          amenityId: amenityId,
          date: selectedDate,
          timeSlot: timeSlot,
        );

        final remainingCapacity = capacity - totalPersons;

        if (remainingCapacity <= 0) {
          availabilityMap[timeSlot] = SlotAvailability.atCapacity(
            totalCapacity: capacity,
            bookedPersons: totalPersons,
          );
        } else {
          availabilityMap[timeSlot] = SlotAvailability.available(
            remainingCapacity: remainingCapacity,
            totalCapacity: capacity,
            bookedPersons: totalPersons,
          );
        }
      }

      return availabilityMap;
    } catch (e) {
      print('❌ Error getting slot availability details: $e');
      return {};
    }
  }

  /// Get remaining capacity for a specific slot
  Future<int> getRemainingCapacity({
    required String amenityId,
    required DateTime date,
    required String timeSlot,
    required int capacity,
  }) async {
    try {
      final totalPersons = await _getTotalPersonsBooked(
        amenityId: amenityId,
        date: date,
        timeSlot: timeSlot,
      );

      final remaining = capacity - totalPersons;
      return remaining > 0 ? remaining : 0;
    } catch (e) {
      print('❌ Error getting remaining capacity: $e');
      return capacity;
    }
  }

  /// Check if a specific booking request can be accommodated
  Future<bool> canBookSlot({
    required String amenityId,
    required DateTime selectedDate,
    required String timeSlot,
    required int capacity,
    required int numberOfPeople,
    DateTime? currentTime,
  }) async {
    try {
      print('🔍 Checking if booking can be accommodated...');
      print('   Requested: $numberOfPeople people');

      // RULE 1: Check if time slot is in the past
      final isPast = _isTimeSlotPast(
        selectedDate: selectedDate,
        timeSlot: timeSlot,
        currentTime: currentTime ?? DateTime.now(),
      );

      if (isPast) {
        print('❌ Cannot book: Time slot has passed');
        return false;
      }

      // RULE 2: Check if enough capacity
      final totalPersons = await _getTotalPersonsBooked(
        amenityId: amenityId,
        date: selectedDate,
        timeSlot: timeSlot,
      );

      final remainingCapacity = capacity - totalPersons;

      if (remainingCapacity < numberOfPeople) {
        print('❌ Cannot book: Not enough capacity (need $numberOfPeople, have $remainingCapacity)');
        return false;
      }

      print('✅ Can book: Slot is available with enough capacity');
      return true;
    } catch (e) {
      print('❌ Error checking if booking can be accommodated: $e');
      return false;
    }
  }

  // ============================================================================
  // HELPER: Format slot availability for UI
  // ============================================================================

  /// Get user-friendly message for slot availability
  String getAvailabilityMessage(SlotAvailability availability) {
    if (availability.isPastTime) {
      return 'Time slot has passed';
    }

    if (availability.isAtCapacity) {
      return 'Fully booked (${availability.bookedPersons}/${availability.totalCapacity})';
    }

    return 'Available (${availability.remainingCapacity} spots left)';
  }

  /// Get color for slot availability status
  /// Green = available, Red = unavailable, Grey = past time
  int getAvailabilityColor(SlotAvailability availability) {
    if (availability.isPastTime) {
      return 0xFF9CA3AF; // Grey
    }

    if (availability.isAtCapacity) {
      return 0xFFFF5757; // Red
    }

    return 0xFF10B981; // Green
  }
}
