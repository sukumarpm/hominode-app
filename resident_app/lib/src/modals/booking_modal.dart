import 'package:flutter/material.dart';
import '../models/amenity.dart';
import '../models/booking.dart';
import '../widgets/calendar_grid.dart';
import '../widgets/time_slot_selector.dart';
import '../services/booking_firestore_service.dart';
import '../services/amenities_booking_flow_function.dart';

class BookingModal extends StatefulWidget {
  final Amenity amenity;

  const BookingModal({
    Key? key,
    required this.amenity,
  }) : super(key: key);

  static Future<void> show(BuildContext context, Amenity amenity) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Book ${amenity.name}',
      barrierColor: Colors.black.withOpacity(0.35),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Center(
          child: BookingModal(amenity: amenity),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: Curves.easeOut,
          ),
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
  final _bookingService = BookingFirestoreService();
  final _bookingFlow = AmenitiesBookingFlowFunction.instance; // NEW: Flow function instance
  List<String> _timeSlots = [];
  AmenityModel? _amenityDetails;
  
  // Real-time availability data
  Set<DateTime> _blockedDates = {};
  Map<String, Map<String, dynamic>> _slotAvailability = {}; // timeSlot -> availability data
  List<String> _availableSlots = []; // NEW: Filtered available slots

  @override
  void initState() {
    super.initState();
    _loadAmenityDetails();
  }

  Future<void> _loadAmenityDetails() async {
    setState(() => _isLoadingTimeSlots = true);
    
    try {
      print('🔵 Loading amenity details for: ${widget.amenity.id}');
      
      final amenity = await _bookingService.getAmenityDetails(widget.amenity.id);
      
      if (amenity != null) {
        setState(() {
          _amenityDetails = amenity;
          _timeSlots = amenity.timeSlots;
          _isLoadingTimeSlots = false;
        });
        
        print('✅ Loaded amenity details:');
        print('   Name: ${amenity.name}');
        print('   Time slots: ${_timeSlots.length}');
        print('   Max capacity: ${amenity.maxCapacity}');
        print('   Has packages: ${amenity.hasPackages}');
        print('   Allow multiple: ${amenity.allowMultipleBookings}');
        print('   Price per day: ${amenity.pricePerDay}');
        
        // Load blocked dates for current month
        await _loadBlockedDates();
        
        // CRITICAL: Auto-select today and load availability
        final today = DateTime.now();
        final todayDate = DateTime(today.year, today.month, today.day);
        setState(() {
          _selectedDate = todayDate;
        });
        print('✅ Auto-selected today: ${todayDate.toString().split(' ')[0]}');
        
        // Load availability for today
        await _loadSlotAvailability();
      } else {
        print('⚠️  No amenity details found, using default time slots');
        setState(() {
          _timeSlots = _getDefaultTimeSlots();
          _isLoadingTimeSlots = false;
        });
      }
    } catch (e) {
      print('❌ Error loading amenity details: $e');
      setState(() {
        _timeSlots = _getDefaultTimeSlots();
        _isLoadingTimeSlots = false;
      });
    }
  }
  
  Future<void> _loadBlockedDates() async {
    if (_amenityDetails == null) return;
    
    try {
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final endOfMonth = DateTime(now.year, now.month + 1, 0);
      
      print('📅 Checking blocked dates from ${startOfMonth.toString().split(' ')[0]} to ${endOfMonth.toString().split(' ')[0]}');
      
      final blockedDates = <DateTime>{};
      
      // Check each date in the month
      for (var date = startOfMonth; date.isBefore(endOfMonth.add(const Duration(days: 1))); date = date.add(const Duration(days: 1))) {
        final isBlocked = await _bookingService.isDateFullyBooked(
          amenityId: widget.amenity.id,
          date: date,
        );
        
        if (isBlocked) {
          blockedDates.add(date);
        }
      }
      
      setState(() {
        _blockedDates = blockedDates;
      });
      
      print('✅ Found ${blockedDates.length} blocked dates');
    } catch (e) {
      print('❌ Error loading blocked dates: $e');
    }
  }
  
  Future<void> _loadSlotAvailability() async {
    if (_selectedDate == null || _amenityDetails == null) return;
    
    setState(() => _isCheckingAvailability = true);
    
    try {
      // CRITICAL: Always fetch fresh current time for real-time accuracy
      final now = DateTime.now();
      print('🔍 Loading slot availability for ${_selectedDate.toString().split(' ')[0]} with $_numberOfPeople people');
      print('   Current time (FRESH): ${now.hour}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}');
      print('   Selected date: ${_selectedDate.toString().split(' ')[0]}');
      print('   Amenity ID: ${widget.amenity.id}');
      print('   Amenity max capacity: ${_amenityDetails!.maxCapacity}');
      print('   Time slots to check: ${_timeSlots.length}');
      
      // Use the flow function to get available slots
      // This applies both RULE 1 (past time slots) and RULE 2 (capacity)
      final result = await _bookingFlow.getAvailableSlots(
        amenityId: widget.amenity.id,
        selectedDate: _selectedDate!,
        allTimeSlots: _timeSlots,
        capacity: _amenityDetails!.maxCapacity,
        numberOfPeople: _numberOfPeople,
      );
      
      if (!result.success) {
        print('❌ Error loading availability: ${result.message}');
        setState(() => _isCheckingAvailability = false);
        return;
      }
      
      print('✅ Available slots returned: ${result.availableSlots?.length ?? 0} slots');
      if (result.availableSlots != null && result.availableSlots!.isNotEmpty) {
        print('   Slots: ${result.availableSlots}');
      } else {
        print('   ⚠️  No available slots for this date');
      }
      
      // Build availability map from slot details
      final availability = <String, Map<String, dynamic>>{};
      
      for (var timeSlot in _timeSlots) {
        final slotDetail = result.slotDetails?[timeSlot] as Map<String, dynamic>?;
        final isAvailable = result.availableSlots?.contains(timeSlot) ?? false;
        
        // FIX: Use totalPersonsBooked (not remainingCapacity) for display
        // If no bookings exist for this slot, totalPersonsBooked will be 0
        final totalPersonsBooked = slotDetail?['totalPersonsBooked'] as int? ?? 0;
        final capacity = _amenityDetails!.maxCapacity;
        
        print('   📊 Slot "$timeSlot":');
        print('      - Available: $isAvailable');
        print('      - Total persons booked: $totalPersonsBooked');
        print('      - Capacity: $capacity');
        print('      - Slot detail: $slotDetail');
        
        availability[timeSlot] = {
          'available': isAvailable,
          'bookedSpots': totalPersonsBooked,  // Changed from remainingSpots
          'totalCapacity': capacity,
          'reason': isAvailable ? 'Available' : 'Not available',
        };
      }
      
      setState(() {
        _availableSlots = result.availableSlots ?? [];
        _slotAvailability = availability;
        _isCheckingAvailability = false;
      });
      
      print('✅ Loaded availability for ${availability.length} time slots');
      print('   Available: ${_availableSlots.length} slots');
    } catch (e) {
      print('❌ Error loading slot availability: $e');
      setState(() => _isCheckingAvailability = false);
    }
  }

  List<String> _getDefaultTimeSlots() {
    // Generate default time slots based on amenity hours
    return [
      '6:00 AM - 7:00 AM',
      '7:00 AM - 8:00 AM',
      '8:00 AM - 9:00 AM',
      '9:00 AM - 10:00 AM',
      '10:00 AM - 11:00 AM',
      '11:00 AM - 12:00 PM',
      '12:00 PM - 1:00 PM',
      '1:00 PM - 2:00 PM',
      '2:00 PM - 3:00 PM',
      '3:00 PM - 4:00 PM',
      '4:00 PM - 5:00 PM',
      '5:00 PM - 6:00 PM',
      '6:00 PM - 7:00 PM',
      '7:00 PM - 8:00 PM',
    ];
  }

  bool _isSlotAvailable(String timeSlot) {
    // Use the filtered available slots from AmenitiesBookingLogic
    if (_availableSlots.isEmpty && _slotAvailability.isEmpty) {
      print('⚠️  No availability data loaded yet for $timeSlot, assuming available');
      return true;
    }
    
    // First check if slot is in the available slots list (after filtering)
    if (_availableSlots.isNotEmpty) {
      final isAvailable = _availableSlots.contains(timeSlot);
      print('📊 Slot $timeSlot: ${isAvailable ? "Available" : "Not available (filtered)"}');
      return isAvailable;
    }
    
    // Fallback to availability data
    final availability = _slotAvailability[timeSlot];
    if (availability == null) {
      print('⚠️  No availability data for $timeSlot, assuming available');
      return true;
    }
    
    final isAvailable = availability['available'] ?? true;
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
          print('📊 _getRemainingSpots($timeSlot): bookedSpots=$bookedSpots from _slotAvailability');
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
      print('📊 _getTotalCapacity($timeSlot): using amenity maxCapacity=$capacity');
      return capacity;
    }
    
    // Fallback to availability data
    if (_slotAvailability.isNotEmpty) {
      final availability = _slotAvailability[timeSlot];
      if (availability != null) {
        final capacity = availability['totalCapacity'] ?? 1;
        print('📊 _getTotalCapacity($timeSlot): using availability totalCapacity=$capacity');
        return capacity;
      }
    }
    
    print('📊 _getTotalCapacity($timeSlot): returning 1 (default)');
    return 1;
  }

  bool get _canConfirm {
    return _selectedDate != null && _selectedTimeSlot != null && !_isSubmitting && _numberOfPeople > 0;
  }
  
  double get _selectedPrice {
    if (_amenityDetails == null) return 0;
    
    if (_bookingType == 'daily') {
      return _amenityDetails!.pricePerDay ?? 0;
    } else if (_amenityDetails!.subscriptionPackages != null) {
      final packageKey = _bookingType == 'weekly' ? 'Weekly' 
                       : _bookingType == 'monthly' ? 'Monthly'
                       : 'Yearly';
      return _amenityDetails!.subscriptionPackages![packageKey] ?? 0;
    }
    
    return 0;
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
        return 'Weekly';
      case 'monthly':
        return 'Monthly';
      case 'yearly':
        return 'Yearly';
      default:
        return null;
    }
  }

  Future<void> _handleConfirm() async {
    if (!_canConfirm) return;

    setState(() => _isSubmitting = true);

    try {
      // Use flow function to create booking with validation
      final result = await _bookingFlow.createBooking(
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
              content: Text('${widget.amenity.name} booked successfully!'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.message ?? 'Booking failed. Please try again.'),
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
            content: Text('Error: $e'),
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
            maxWidth: 500,
            maxHeight: screenHeight - 48,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(context),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoCard(),
                      
                      // Booking Type Selector (if packages available)
                      if (_amenityDetails?.hasPackages ?? false) ...[
                        const SizedBox(height: 24),
                        _buildBookingTypeSelector(),
                      ],
                      
                      // Number of People Selector (NEW)
                      if (_amenityDetails?.allowMultipleBookings ?? false) ...[
                        const SizedBox(height: 24),
                        _buildPeopleSelector(),
                      ],
                      
                      // Package Summary (NEW)
                      if (_bookingType != 'daily' && _selectedDate != null) ...[
                        const SizedBox(height: 24),
                        _buildPackageSummary(),
                      ],
                      
                      const SizedBox(height: 24),
                      const Text(
                        'Select Date',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 12),
                      CalendarGrid(
                        selectedDate: _selectedDate,
                        onDateSelected: (date) {
                          setState(() {
                            _selectedDate = date;
                            _selectedTimeSlot = null; // Reset time slot when date changes
                          });
                          _loadSlotAvailability(); // Load availability for selected date
                        },
                        blockedDates: _blockedDates,
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Select Time Slot',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _isLoadingTimeSlots
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(24),
                                child: CircularProgressIndicator(),
                              ),
                            )
                          : _timeSlots.isEmpty
                              ? Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(24),
                                    child: Text(
                                      'No time slots available',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ),
                                )
                              : _buildTimeSlotSelector(),
                      const SizedBox(height: 24),
                      _buildConfirmButton(),
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
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFFF0F0F0)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Book ${widget.amenity.name}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
              ),
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close,
                size: 18,
                color: Color(0xFF6B7280),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F7F9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(
                Icons.access_time,
                size: 18,
                color: Color(0xFF9B9B9B),
              ),
              const SizedBox(width: 8),
              Text(
                'Timings: ${widget.amenity.openTime} - ${widget.amenity.closeTime}',
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF6B7280),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.payments_outlined,
                size: 18,
                color: Color(0xFF9B9B9B),
              ),
              const SizedBox(width: 8),
              Text(
                'Price: ${widget.amenity.price}',
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF6B7280),
                ),
              ),
            ],
          ),
          if (_amenityDetails?.allowMultipleBookings ?? false) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.people_outline,
                  size: 18,
                  color: Color(0xFF9B9B9B),
                ),
                const SizedBox(width: 8),
                Text(
                  'Capacity: Up to ${_amenityDetails!.maxCapacity} users',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildBookingTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Booking Type',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF6F7F9),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              _buildBookingTypeOption(
                'daily',
                'Daily',
                '₹${_amenityDetails?.pricePerDay?.toStringAsFixed(0) ?? '0'}/day',
              ),
              if (_amenityDetails?.subscriptionPackages?.containsKey('Weekly') ?? false)
                _buildBookingTypeOption(
                  'weekly',
                  'Weekly Package',
                  '₹${_amenityDetails!.subscriptionPackages!['Weekly']!.toStringAsFixed(0)}/week',
                ),
              if (_amenityDetails?.subscriptionPackages?.containsKey('Monthly') ?? false)
                _buildBookingTypeOption(
                  'monthly',
                  'Monthly Package',
                  '₹${_amenityDetails!.subscriptionPackages!['Monthly']!.toStringAsFixed(0)}/month',
                ),
              if (_amenityDetails?.subscriptionPackages?.containsKey('Yearly') ?? false)
                _buildBookingTypeOption(
                  'yearly',
                  'Yearly Package',
                  '₹${_amenityDetails!.subscriptionPackages!['Yearly']!.toStringAsFixed(0)}/year',
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
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: isSelected ? Border.all(color: const Color(0xFF2563EB), width: 2) : null,
        ),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFD1D5DB),
                  width: 2,
                ),
                color: isSelected ? const Color(0xFF2563EB) : Colors.transparent,
              ),
              child: isSelected
                  ? const Center(
                      child: Icon(
                        Icons.circle,
                        size: 10,
                        color: Colors.white,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.black : const Color(0xFF6B7280),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    price,
                    style: TextStyle(
                      fontSize: 13,
                      color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF9CA3AF),
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
        const Text(
          'Number of People',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF6F7F9),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.people_outline,
                size: 24,
                color: Color(0xFF6B7280),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$_numberOfPeople ${_numberOfPeople == 1 ? "Person" : "People"}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Each person counts toward capacity',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
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
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _numberOfPeople > 1 ? Colors.white : const Color(0xFFE5E7EB),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _numberOfPeople > 1 ? const Color(0xFF2563EB) : const Color(0xFFD1D5DB),
                        ),
                      ),
                      child: Icon(
                        Icons.remove,
                        size: 20,
                        color: _numberOfPeople > 1 ? const Color(0xFF2563EB) : const Color(0xFF9CA3AF),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
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
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF2563EB)),
                      ),
                      child: const Icon(
                        Icons.add,
                        size: 20,
                        color: Color(0xFF2563EB),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2563EB).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(
                Icons.card_membership,
                size: 20,
                color: Color(0xFF2563EB),
              ),
              SizedBox(width: 8),
              Text(
                'Package Details',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2563EB),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildPackageDetailRow('Package Type', packageType ?? 'N/A'),
          const SizedBox(height: 8),
          _buildPackageDetailRow('Start Date', _formatDate(_selectedDate!)),
          const SizedBox(height: 8),
          _buildPackageDetailRow('End Date', _formatDate(endDate)),
          const SizedBox(height: 8),
          _buildPackageDetailRow('Validity', '$validityDays days'),
          const SizedBox(height: 8),
          _buildPackageDetailRow('Price', '₹${_selectedPrice.toStringAsFixed(0)}'),
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
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF6B7280),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
      ],
    );
  }
  
  String _formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
  
  Widget _buildTimeSlotSelector() {
    if (_selectedDate == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Please select a date first',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ),
      );
    }
    
    if (_isCheckingAvailability) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 12),
              Text(
                'Checking availability...',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF6B7280),
                ),
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: !isAvailable
                  ? const Color(0xFFF3F4F6)
                  : isSelected
                      ? const Color(0xFF2563EB)
                      : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: !isAvailable
                    ? const Color(0xFFE5E7EB)
                    : isSelected
                        ? const Color(0xFF2563EB)
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
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: !isAvailable
                        ? const Color(0xFF9CA3AF)
                        : isSelected
                            ? Colors.white
                            : Colors.black,
                  ),
                ),
                if (showCapacity) ...[
                  const SizedBox(height: 4),
                  Text(
                    isAvailable
                        ? '$remainingSpots/$totalCapacity spots booked'
                        : 'Slot Full',
                    style: TextStyle(
                      fontSize: 11,
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
      height: 56,
      child: ElevatedButton(
        onPressed: _canConfirm ? _handleConfirm : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2563EB),
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFFE6E6E6),
          disabledForegroundColor: const Color(0xFF9B9B9B),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isSubmitting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Text(
                'Confirm Booking',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }
}
