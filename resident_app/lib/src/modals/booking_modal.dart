import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../models/amenity.dart';
import '../widgets/facility_information.dart';
import '../services/booking_firestore_service.dart';
import '../widgets/calendar_grid.dart';

class BookingModal extends StatefulWidget {
  final Amenity amenity;

  const BookingModal({super.key, required this.amenity, this.bookingService});
  final BookingFirestoreService? bookingService;

  static Future<void> show(BuildContext context, Amenity amenity) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Book ${amenity.name}',
      barrierColor: Colors.black.withOpacity(0.35),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Center(child: BookingModal(amenity: amenity));
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: ScaleTransition(
            scale: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            ).drive(Tween<double>(begin: 0.85, end: 1.0)),
            child: child,
          ),
        );
      },
    );
  }

  @override
  State<BookingModal> createState() => _BookingModalState();
}

class _BookingModalState extends State<BookingModal> {
  DateTime? _selectedDate;
  String? _selectedTimeSlot;
  String _bookingType = 'daily'; // 'daily', 'weekly', 'monthly', 'yearly'
  int _numberOfPeople = 1; // NEW: Track number of people
  bool _isSubmitting = false;
  bool _isLoadingTimeSlots = false;
  bool _isCheckingAvailability = false;
  bool _availabilityVerified = false;
  int _availabilityRequestId = 0;
  late final _bookingService =
      widget.bookingService ?? BookingFirestoreService();
  StreamSubscription<AmenityModel?>? _facilitySubscription;
  List<String> _timeSlots = [];
  AmenityModel? _amenityDetails;

  // Real-time availability data
  Set<DateTime> _blockedDates = {};
  Map<String, Map<String, dynamic>> _slotAvailability =
      {}; // timeSlot -> availability data
  List<String> _availableSlots = []; // NEW: Filtered available slots

  @override
  void initState() {
    super.initState();
    _loadAmenityDetails();
  }

  @override
  void dispose() {
    _facilitySubscription?.cancel();
    super.dispose();
  }

  void _loadAmenityDetails() {
    _isLoadingTimeSlots = true;
    _facilitySubscription = _bookingService
        .streamAmenityDetails(widget.amenity.id)
        .listen(
          (amenity) async {
            if (!mounted) return;
            final firstLoad = _amenityDetails == null;
            final available = amenity?.isAvailable == true;
            setState(() {
              _amenityDetails = available ? amenity : null;
              _timeSlots = available ? amenity!.timeSlots : [];
              _isLoadingTimeSlots = false;
              if (!_timeSlots.contains(_selectedTimeSlot)) {
                _selectedTimeSlot = null;
              }
              if (!available) _selectedDate = null;
            });
            if (!available || !firstLoad) return;
            await _loadBlockedDates();
            if (!mounted || _amenityDetails?.isAvailable != true) return;
            final today = DateTime.now();
            setState(
              () =>
                  _selectedDate = DateTime(today.year, today.month, today.day),
            );
            await _loadSlotAvailability();
          },
          onError: (Object error) {
            if (!mounted) return;
            setState(() {
              _amenityDetails = null;
              _timeSlots = [];
              _selectedTimeSlot = null;
              _selectedDate = null;
              _isLoadingTimeSlots = false;
            });
          },
        );
  }

  Future<void> _loadBlockedDates() async {
    if (_amenityDetails == null) return;

    try {
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final endOfMonth = DateTime(now.year, now.month + 1, 0);

      print(
        '📅 Checking blocked dates from '
        '${startOfMonth.toString().split(' ')[0]} to '
        '${endOfMonth.toString().split(' ')[0]}',
      );

      final blockedDates = await _bookingService.getFullyBookedDates(
        amenityId: widget.amenity.id,
        startDate: startOfMonth,
        endDate: endOfMonth,
        numberOfPeople: _numberOfPeople,
      );

      if (mounted) {
        setState(() => _blockedDates = blockedDates);
      }

      print('✅ Found ${blockedDates.length} blocked dates');
    } catch (e) {
      print('❌ Error loading blocked dates: $e');
    }
  }

  Future<void> _loadSlotAvailability() async {
    if (_selectedDate == null || _amenityDetails == null) return;
    final requestId = ++_availabilityRequestId;
    final requestedDate = _selectedDate!;

    setState(() {
      _isCheckingAvailability = true;
      _availabilityVerified = false;
      _selectedTimeSlot = null;
      _availableSlots = [];
      _slotAvailability = {};
    });

    try {
      final now = DateTime.now();

      print(
        '🔍 Loading slot availability for ${_selectedDate.toString().split(' ')[0]} '
        'with $_numberOfPeople people',
      );
      print(
        '   Current time: '
        '${now.hour}:${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}',
      );
      print('   Amenity ID: ${widget.amenity.id}');
      print('   Capacity: ${_amenityDetails!.maxCapacity}');
      print('   Time slots: ${_timeSlots.length}');

      final List<String> availableSlots = [];
      final Map<String, Map<String, dynamic>> availability = {};

      final slotResults = await _bookingService.getSlotAvailabilityForDate(
        amenityId: widget.amenity.id,
        date: requestedDate,
        numberOfPeople: _numberOfPeople,
      );

      if (!mounted || requestId != _availabilityRequestId) return;

      final availabilityVerified =
          _timeSlots.isNotEmpty &&
          _timeSlots.every((slot) {
            final result = slotResults[slot];
            return result?['availabilityVerified'] == true &&
                result?['available'] is bool;
          });

      for (final timeSlot in _timeSlots) {
        final slotResult =
            slotResults[timeSlot] ??
            {
              'available': false,
              'reason': 'Unable to check availability',
              'remainingSpots': 0,
              'totalCapacity': _amenityDetails!.maxCapacity,
              'totalPersonsBooked': 0,
            };

        final bool isAvailable = slotResult['available'] == true;
        final int totalPersonsBooked =
            (slotResult['totalPersonsBooked'] as num?)?.toInt() ?? 0;
        final int capacity =
            (slotResult['totalCapacity'] as num?)?.toInt() ??
            _amenityDetails!.maxCapacity;

        if (availabilityVerified && isAvailable) {
          availableSlots.add(timeSlot);
        }

        print('   📊 Slot "$timeSlot":');
        print('      - Available: $isAvailable');
        print('      - Total persons booked: $totalPersonsBooked');
        print('      - Capacity: $capacity');
        print('      - Result: $slotResult');

        availability[timeSlot] = {
          'available': isAvailable,
          'bookedSpots': totalPersonsBooked,
          'totalCapacity': capacity,
          'reason':
              slotResult['reason'] ??
              (isAvailable ? 'Available' : 'Not available'),
        };
      }

      if (!mounted || requestId != _availabilityRequestId) return;

      setState(() {
        _availableSlots = availableSlots;
        _slotAvailability = availability;
        _availabilityVerified = availabilityVerified;
        _isCheckingAvailability = false;
      });

      print('✅ Loaded availability for ${availability.length} time slots');
      print('   Available: ${availableSlots.length} slots');
    } catch (e) {
      print('❌ Error loading slot availability: $e');

      if (mounted && requestId == _availabilityRequestId) {
        setState(() {
          _availabilityVerified = false;
          _availableSlots = [];
          _slotAvailability = {};
          _selectedTimeSlot = null;
          _isCheckingAvailability = false;
        });
      }
    }
  }

  bool _isSlotAvailable(String timeSlot) {
    if (!_availabilityVerified) return false;

    // First check if slot is in the available slots list (after filtering)
    if (_availableSlots.isNotEmpty) {
      final isAvailable = _availableSlots.contains(timeSlot);
      print(
        '📊 Slot $timeSlot: ${isAvailable ? "Available" : "Not available (filtered)"}',
      );
      return isAvailable;
    }

    // Fallback to availability data
    final availability = _slotAvailability[timeSlot];
    if (availability == null) {
      return false;
    }

    final isAvailable = availability['available'] == true;
    print('📊 Slot $timeSlot: ${isAvailable ? "Available" : "Full"}');
    return isAvailable;
  }

  int _getRemainingSpots(String timeSlot) {
    // FIX: Return booked spots count (not remaining capacity)
    // Use the flow function's slotDetails which has accurate totalPersonsBooked
    if (_slotAvailability.isNotEmpty) {
      final availability = _slotAvailability[timeSlot];
      if (availability != null) {
        final bookedSpots = availability['bookedSpots'] as int?;
        if (bookedSpots != null) {
          print(
            '📊 _getRemainingSpots($timeSlot): bookedSpots=$bookedSpots from _slotAvailability',
          );
          return bookedSpots;
        }
      }
    }

    // If no availability data loaded yet, return 0 (no bookings)
    // This will be updated once _loadSlotAvailability() completes
    print('📊 _getRemainingSpots($timeSlot): returning 0 (no data yet)');
    return 0;
  }

  int _getTotalCapacity(String timeSlot) {
    // CRITICAL: Always use amenity's max capacity if available
    // This ensures we show the correct capacity (5, not 8)
    if (_amenityDetails != null) {
      final capacity = _amenityDetails!.maxCapacity;
      print(
        '📊 _getTotalCapacity($timeSlot): using amenity maxCapacity=$capacity',
      );
      return capacity;
    }

    // Fallback to availability data
    if (_slotAvailability.isNotEmpty) {
      final availability = _slotAvailability[timeSlot];
      if (availability != null) {
        final capacity = availability['totalCapacity'] ?? 1;
        print(
          '📊 _getTotalCapacity($timeSlot): using availability totalCapacity=$capacity',
        );
        return capacity;
      }
    }

    print('📊 _getTotalCapacity($timeSlot): returning 1 (default)');
    return 1;
  }

  bool get _canConfirm {
    return _amenityDetails?.isAvailable == true &&
        !_isLoadingTimeSlots &&
        !_isCheckingAvailability &&
        _availabilityVerified &&
        _selectedDate != null &&
        _selectedTimeSlot != null &&
        _isSlotAvailable(_selectedTimeSlot!) &&
        !_isSubmitting &&
        _numberOfPeople > 0;
  }

  String get _selectedPriceLabel {
    final amenity = _amenityDetails;
    if (amenity == null) return 'Price unavailable';
    if (_bookingType == 'daily') return amenity.priceDisplay;
    final packageKey = _getPackageType();
    return AmenityModel.formatPrice(
      amenity.subscriptionPackages?[packageKey],
      isFree: amenity.isFree,
    );
  }

  // NEW: Calculate end date based on booking type
  DateTime _calculateEndDate() {
    if (_selectedDate == null) return DateTime.now();

    switch (_bookingType) {
      case 'weekly':
        return _selectedDate!.add(const Duration(days: 7));
      case 'monthly':
        return _selectedDate!.add(const Duration(days: 30));
      case 'yearly':
        return _selectedDate!.add(const Duration(days: 365));
      default:
        return _selectedDate!; // Daily booking
    }
  }

  // NEW: Get validity days
  int _getValidityDays() {
    switch (_bookingType) {
      case 'weekly':
        return 7;
      case 'monthly':
        return 30;
      case 'yearly':
        return 365;
      default:
        return 1; // Daily
    }
  }

  // NEW: Get package type string
  String? _getPackageType() {
    if (_bookingType == 'daily') return null;

    switch (_bookingType) {
      case 'weekly':
        return 'weekly'.tr();
      case 'monthly':
        return 'monthly'.tr();
      case 'yearly':
        return 'yearly'.tr();
      default:
        return null;
    }
  }

  Future<void> _handleConfirm() async {
    if (!_canConfirm) return;

    setState(() => _isSubmitting = true);

    try {
      // Use flow function to create booking with validation
      final result = await _bookingService.createBooking(
        amenityId: widget.amenity.id,
        amenityName: widget.amenity.name,
        date: _selectedDate!,
        timeSlot: _selectedTimeSlot!,
        numberOfPeople: _numberOfPeople,
        bookingType: _bookingType,
      );

      setState(() => _isSubmitting = false);

      if (mounted) {
        if (result.success) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'facility_booked_successfully'.tr(
                  namedArgs: {'name': widget.amenity.name},
                ),
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.message ?? 'booking_failed_retry'.tr()),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _isSubmitting = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'operation_error'.tr(namedArgs: {'error': e.toString()}),
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final modalWidth = screenWidth * 0.92;

    return Material(
      color: Colors.transparent,
      child: Center(
        child: Container(
          width: modalWidth,
          constraints: BoxConstraints(
            maxWidth: 500.w,
            maxHeight: screenHeight - 48,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFFFCFDFE),
            borderRadius: BorderRadius.circular(24.r),
            border: Border.all(color: const Color(0xFFE1E9F2)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF172B4D).withValues(alpha: 0.14),
                blurRadius: 26,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(context),
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(20.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_isLoadingTimeSlots)
                        const Center(child: CircularProgressIndicator())
                      else if (_amenityDetails == null)
                        Text('facility_unavailable_now'.tr())
                      else ...[
                        _buildInfoCard(),

                        // Booking Type Selector (if packages available)
                        if (_amenityDetails?.hasPackages ?? false) ...[
                          SizedBox(height: 24.h),
                          _buildBookingTypeSelector(),
                        ],

                        // Number of People Selector (NEW)
                        if (_amenityDetails?.allowMultipleBookings ??
                            false) ...[
                          SizedBox(height: 24.h),
                          _buildPeopleSelector(),
                        ],

                        // Package Summary (NEW)
                        if (_bookingType != 'daily' &&
                            _selectedDate != null) ...[
                          SizedBox(height: 24.h),
                          _buildPackageSummary(),
                        ],

                        SizedBox(height: 24.h),
                        Text(
                          'select_date'.tr(),
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                        ),
                        SizedBox(height: 12.h),
                        CalendarGrid(
                          selectedDate: _selectedDate,
                          onDateSelected: (date) {
                            setState(() {
                              _selectedDate = date;
                              _selectedTimeSlot =
                                  null; // Reset time slot when date changes
                            });
                            _loadSlotAvailability(); // Load availability for selected date
                          },
                          blockedDates: _blockedDates,
                        ),
                        SizedBox(height: 24.h),
                        Text(
                          'select_time_slot'.tr(),
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                        ),
                        SizedBox(height: 12.h),
                        _isLoadingTimeSlots
                            ? Center(
                                child: Padding(
                                  padding: EdgeInsets.all(24.w),
                                  child: CircularProgressIndicator(),
                                ),
                              )
                            : _timeSlots.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: EdgeInsets.all(24.w),
                                  child: Text(
                                    'no_time_slots_available'.tr(),
                                    style: TextStyle(
                                      fontSize: 14.sp,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ),
                              )
                            : _buildTimeSlotSelector(),
                        SizedBox(height: 24.h),
                        _buildConfirmButton(),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF0F0F0))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _amenityDetails == null
                  ? 'facility'.tr()
                  : 'book_named_facility'.tr(
                      namedArgs: {'name': _amenityDetails!.name},
                    ),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20.sp,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
              ),
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 32.w,
              height: 32.h,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.close, size: 18.w, color: Color(0xFF6B7280)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() => Container(
    padding: EdgeInsets.all(14.w),
    decoration: BoxDecoration(
      color: const Color(0xFFF6F7F9),
      borderRadius: BorderRadius.circular(12.r),
    ),
    child: FacilityInformation(amenity: _amenityDetails!),
  );

  Widget _buildBookingTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'booking_type'.tr(),
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        SizedBox(height: 12.h),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF6F7F9),
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Column(
            children: [
              _buildBookingTypeOption(
                'daily',
                'daily'.tr(),
                _amenityDetails!.priceDisplay,
              ),
              if (_amenityDetails?.subscriptionPackages?.containsKey(
                    'weekly'.tr(),
                  ) ??
                  false)
                _buildBookingTypeOption(
                  'weekly',
                  'weekly_package'.tr(),
                  AmenityModel.formatPrice(
                    _amenityDetails!.subscriptionPackages!['Weekly'],
                    isFree: _amenityDetails!.isFree,
                    suffix: '/${'week'.tr()}',
                  ),
                ),
              if (_amenityDetails?.subscriptionPackages?.containsKey(
                    'monthly'.tr(),
                  ) ??
                  false)
                _buildBookingTypeOption(
                  'monthly',
                  'monthly_package'.tr(),
                  AmenityModel.formatPrice(
                    _amenityDetails!.subscriptionPackages!['Monthly'],
                    isFree: _amenityDetails!.isFree,
                    suffix: '/${'month'.tr()}',
                  ),
                ),
              if (_amenityDetails?.subscriptionPackages?.containsKey(
                    'yearly'.tr(),
                  ) ??
                  false)
                _buildBookingTypeOption(
                  'yearly',
                  'yearly_package'.tr(),
                  AmenityModel.formatPrice(
                    _amenityDetails!.subscriptionPackages!['Yearly'],
                    isFree: _amenityDetails!.isFree,
                    suffix: '/${'year'.tr()}',
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBookingTypeOption(String value, String label, String price) {
    final isSelected = _bookingType == value;

    return GestureDetector(
      onTap: () {
        setState(() {
          _bookingType = value;
          // Reload availability when booking type changes
          if (_selectedDate != null) {
            _loadSlotAvailability();
          }
        });
      },
      child: Container(
        padding: EdgeInsets.all(14.w),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10.r),
          border: isSelected
              ? Border.all(color: const Color(0xFF0E4778), width: 2)
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 20.w,
              height: 20.h,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF0E4778)
                      : const Color(0xFFD1D5DB),
                  width: 2,
                ),
                color: isSelected
                    ? const Color(0xFF0E4778)
                    : Colors.transparent,
              ),
              child: isSelected
                  ? Center(
                      child: Icon(
                        Icons.circle,
                        size: 10.w,
                        color: Colors.white,
                      ),
                    )
                  : null,
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? Colors.black
                          : const Color(0xFF6B7280),
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    price,
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: isSelected
                          ? const Color(0xFF0E4778)
                          : const Color(0xFF9CA3AF),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // NEW: People Selector Widget
  Widget _buildPeopleSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'number_of_people'.tr(),
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        SizedBox(height: 12.h),
        Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: const Color(0xFFF6F7F9),
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Row(
            children: [
              Icon(Icons.people_outline, size: 24.w, color: Color(0xFF6B7280)),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'people_count'.tr(
                        namedArgs: {'count': '$_numberOfPeople'},
                      ),
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF172B4D),
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      'each_person_capacity'.tr(),
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 12.w),
              Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      if (_numberOfPeople > 1) {
                        setState(() {
                          _numberOfPeople--;
                          // Reload availability with new number
                          if (_selectedDate != null) {
                            _loadSlotAvailability();
                          }
                        });
                      }
                    },
                    child: Container(
                      width: 36.w,
                      height: 36.h,
                      decoration: BoxDecoration(
                        color: _numberOfPeople > 1
                            ? Colors.white
                            : const Color(0xFFE5E7EB),
                        borderRadius: BorderRadius.circular(8.r),
                        border: Border.all(
                          color: _numberOfPeople > 1
                              ? const Color(0xFF0E4778)
                              : const Color(0xFFD1D5DB),
                        ),
                      ),
                      child: Icon(
                        Icons.remove,
                        size: 20.w,
                        color: _numberOfPeople > 1
                            ? const Color(0xFF0E4778)
                            : const Color(0xFF9CA3AF),
                      ),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  GestureDetector(
                    onTap: () {
                      final maxCapacity = _amenityDetails?.maxCapacity ?? 10;
                      if (_numberOfPeople < maxCapacity) {
                        setState(() {
                          _numberOfPeople++;
                          // Reload availability with new number
                          if (_selectedDate != null) {
                            _loadSlotAvailability();
                          }
                        });
                      }
                    },
                    child: Container(
                      width: 36.w,
                      height: 36.h,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8.r),
                        border: Border.all(color: const Color(0xFF0E4778)),
                      ),
                      child: Icon(
                        Icons.add,
                        size: 20.w,
                        color: Color(0xFF0E4778),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // NEW: Package Summary Widget
  Widget _buildPackageSummary() {
    final endDate = _calculateEndDate();
    final validityDays = _getValidityDays();
    final packageType = _getPackageType();

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: const Color(0xFF0E4778).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.card_membership, size: 20.w, color: Color(0xFF0E4778)),
              SizedBox(width: 8.w),
              Text(
                'package_details'.tr(),
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0E4778),
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          _buildPackageDetailRow(
            'package_type'.tr(),
            packageType ?? 'not_available'.tr(),
          ),
          SizedBox(height: 8.h),
          _buildPackageDetailRow(
            'start_date'.tr(),
            _formatDate(_selectedDate!),
          ),
          SizedBox(height: 8.h),
          _buildPackageDetailRow('end_date'.tr(), _formatDate(endDate)),
          SizedBox(height: 8.h),
          _buildPackageDetailRow(
            'validity'.tr(),
            'days_count'.tr(namedArgs: {'count': '$validityDays'}),
          ),
          SizedBox(height: 8.h),
          _buildPackageDetailRow('price'.tr(), _selectedPriceLabel),
        ],
      ),
    );
  }

  Widget _buildPackageDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 13.sp, color: Color(0xFF6B7280)),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13.sp,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF172B4D),
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return DateFormat.yMMMd(context.locale.toString()).format(date);
  }

  Widget _buildTimeSlotSelector() {
    if (_selectedDate == null) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(24.w),
          child: Text(
            'select_date_first'.tr(),
            style: TextStyle(fontSize: 14.sp, color: Colors.grey[600]),
          ),
        ),
      );
    }

    if (_isCheckingAvailability) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(24.w),
          child: Column(
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 12.h),
              Text(
                'checking_availability'.tr(),
                style: TextStyle(fontSize: 13.sp, color: Color(0xFF6B7280)),
              ),
            ],
          ),
        ),
      );
    }

    if (!_availabilityVerified) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: Column(
            children: [
              Text(
                'facility_availability_unverified'.tr(),
                textAlign: TextAlign.center,
              ),
              TextButton.icon(
                onPressed: _loadSlotAvailability,
                icon: const Icon(Icons.refresh),
                label: Text('retry_availability_check'.tr()),
              ),
            ],
          ),
        ),
      );
    }

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: _timeSlots.map((slot) {
        final isSelected = _selectedTimeSlot == slot;
        final isAvailable = _isSlotAvailable(slot);
        final remainingSpots = _getRemainingSpots(slot);
        final totalCapacity = _getTotalCapacity(slot);
        final showCapacity = _amenityDetails?.allowMultipleBookings ?? false;

        return GestureDetector(
          onTap: isAvailable
              ? () {
                  setState(() {
                    _selectedTimeSlot = slot;
                  });
                }
              : null,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            decoration: BoxDecoration(
              color: !isAvailable
                  ? const Color(0xFFF3F4F6)
                  : isSelected
                  ? const Color(0xFF0E4778)
                  : Colors.white,
              borderRadius: BorderRadius.circular(10.r),
              border: Border.all(
                color: !isAvailable
                    ? const Color(0xFFE5E7EB)
                    : isSelected
                    ? const Color(0xFF0E4778)
                    : const Color(0xFFD1D5DB),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  slot,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: !isAvailable
                        ? const Color(0xFF9CA3AF)
                        : isSelected
                        ? Colors.white
                        : Colors.black,
                  ),
                ),
                if (showCapacity) ...[
                  SizedBox(height: 4.h),
                  Text(
                    isAvailable
                        ? 'spots_booked'.tr(
                            namedArgs: {
                              'booked': '$remainingSpots',
                              'capacity': '$totalCapacity',
                            },
                          )
                        : 'slot_full'.tr(),
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: !isAvailable
                          ? const Color(0xFF9CA3AF)
                          : isSelected
                          ? Colors.white.withOpacity(0.9)
                          : const Color(0xFF6B7280),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildConfirmButton() {
    return SizedBox(
      width: double.infinity,
      height: 56.h,
      child: ElevatedButton(
        onPressed: _canConfirm ? _handleConfirm : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF172B4D),
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFFE6E6E6),
          disabledForegroundColor: const Color(0xFF9B9B9B),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
        ),
        child: _isSubmitting
            ? SizedBox(
                width: 20.w,
                height: 20.h,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                'confirm_booking'.tr(),
                style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600),
              ),
      ),
    );
  }
}
