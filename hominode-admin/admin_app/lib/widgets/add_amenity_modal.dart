import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../services/amenity_service.dart';
import '../services/building_service.dart';

class AddAmenityModal extends StatefulWidget {
  const AddAmenityModal({super.key});

  @override
  State<AddAmenityModal> createState() => _AddAmenityModalState();
}

class _AddAmenityModalState extends State<AddAmenityModal> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _customTimeSlotController = TextEditingController();
  final _maxCapacityController = TextEditingController(text: '1');
  final _customDurationController = TextEditingController();

  final AmenityService _amenityService = AmenityService();
  final BuildingService _buildingService = BuildingService();

  String _selectedIcon = 'pool';
  String _pricingType = 'free'; // 'free' or 'paid'
  bool _isLoading = false;
  bool _allowMultipleBookings = false;
  bool _hasSubscriptionPackages = false;

  // Building selection
  String? _selectedBuildingId;
  String? _selectedBuildingName;
  List<BuildingModel> _buildings = [];

  // Subscription packages
  final Map<String, TextEditingController> _packageControllers = {
    'Weekly': TextEditingController(),
    'Monthly': TextEditingController(),
    'Yearly': TextEditingController(),
  };

  // Predefined time slots
  final List<String> _predefinedTimeSlots = [
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
    '8:00 PM - 9:00 PM',
    '9:00 PM - 10:00 PM',
  ];

  final List<String> _selectedTimeSlots = [];

  // Booking durations
  final List<String> _predefinedDurations = [
    '1 hour',
    '2 hours',
    '3 hours',
    'Half day',
    'Full day',
  ];

  final List<String> _selectedDurations = ['1 hour'];

  final Map<String, Map<String, dynamic>> _icons = {
    'pool': {'icon': Icons.pool, 'name': 'Pool'},
    'gym': {'icon': Icons.fitness_center, 'name': 'Gym'},
    'hall': {'icon': Icons.home, 'name': 'Hall'},
    'lawn': {'icon': Icons.grass, 'name': 'Lawn'},
    'parking': {'icon': Icons.local_parking, 'name': 'Parking'},
    'playground': {'icon': Icons.sports_soccer, 'name': 'Playground'},
  };

  @override
  void initState() {
    super.initState();
    _loadBuildings();
  }

  void _loadBuildings() {
    _buildingService.getBuildings().listen((buildings) {
      if (mounted) {
        setState(() {
          _buildings = buildings;
          if (_buildings.isNotEmpty && _selectedBuildingId == null) {
            _selectedBuildingId = _buildings.first.id;
            _selectedBuildingName = _buildings.first.name;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _customTimeSlotController.dispose();
    _maxCapacityController.dispose();
    _customDurationController.dispose();
    for (var controller in _packageControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(24.w),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Add Amenity',
                      style: TextStyle(
                        fontSize: 20.sp,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111111),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                SizedBox(height: 24.h),

                // Building Selection
                DropdownButtonFormField<String>(
                  initialValue: _selectedBuildingId,
                  decoration: InputDecoration(
                    labelText: 'Building *',
                    hintText: 'Select building',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                  ),
                  items: _buildings.map((building) {
                    return DropdownMenuItem(
                      value: building.id,
                      child: Text(building.name),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedBuildingId = value;
                      _selectedBuildingName = _buildings
                          .firstWhere((b) => b.id == value)
                          .name;
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select a building';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16.h),

                // Name
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Amenity Name *',
                    hintText: 'e.g., Swimming Pool',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter amenity name';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16.h),

                // Icon Selection
                Text(
                  'Select Icon *',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827),
                  ),
                ),
                SizedBox(height: 12.h),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: _icons.entries.map((entry) {
                    final isSelected = _selectedIcon == entry.key;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedIcon = entry.key;
                        });
                      },
                      child: Column(
                        children: [
                          Container(
                            width: 64.w,
                            height: 64.h,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF0E4778).withOpacity(0.1)
                                  : const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(12.r),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFF0E4778)
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: Icon(
                              entry.value['icon'] as IconData,
                              color: isSelected
                                  ? const Color(0xFF0E4778)
                                  : const Color(0xFF6B7280),
                              size: 32.w,
                            ),
                          ),
                          SizedBox(height: 6.h),
                          Text(
                            entry.value['name'] as String,
                            style: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              color: isSelected
                                  ? const Color(0xFF0E4778)
                                  : const Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
                SizedBox(height: 20.h),

                // Pricing Type
                Text(
                  'Pricing *',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827),
                  ),
                ),
                SizedBox(height: 12.h),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _pricingType = 'free';
                            _priceController.clear();
                          });
                        },
                        child: Container(
                          padding: EdgeInsets.all(16.w),
                          decoration: BoxDecoration(
                            color: _pricingType == 'free'
                                ? const Color(0xFF10B981).withOpacity(0.1)
                                : const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(8.r),
                            border: Border.all(
                              color: _pricingType == 'free'
                                  ? const Color(0xFF10B981)
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _pricingType == 'free'
                                    ? Icons.check_circle
                                    : Icons.circle_outlined,
                                color: _pricingType == 'free'
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFF6B7280),
                                size: 20.w,
                              ),
                              SizedBox(width: 8.w),
                              Text(
                                'Free',
                                style: TextStyle(
                                  fontSize: 15.sp,
                                  fontWeight: FontWeight.w600,
                                  color: _pricingType == 'free'
                                      ? const Color(0xFF10B981)
                                      : const Color(0xFF6B7280),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _pricingType = 'paid';
                          });
                        },
                        child: Container(
                          padding: EdgeInsets.all(16.w),
                          decoration: BoxDecoration(
                            color: _pricingType == 'paid'
                                ? const Color(0xFF0E4778).withOpacity(0.1)
                                : const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(8.r),
                            border: Border.all(
                              color: _pricingType == 'paid'
                                  ? const Color(0xFF0E4778)
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _pricingType == 'paid'
                                    ? Icons.check_circle
                                    : Icons.circle_outlined,
                                color: _pricingType == 'paid'
                                    ? const Color(0xFF0E4778)
                                    : const Color(0xFF6B7280),
                                size: 20.w,
                              ),
                              SizedBox(width: 8.w),
                              Text(
                                'Paid',
                                style: TextStyle(
                                  fontSize: 15.sp,
                                  fontWeight: FontWeight.w600,
                                  color: _pricingType == 'paid'
                                      ? const Color(0xFF0E4778)
                                      : const Color(0xFF6B7280),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                // Price (if paid)
                if (_pricingType == 'paid') ...[
                  SizedBox(height: 16.h),
                  TextFormField(
                    controller: _priceController,
                    decoration: InputDecoration(
                      labelText: 'Price per Day *',
                      hintText: 'Enter amount',
                      prefixText: '₹ ',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (_pricingType == 'paid' &&
                          !_hasSubscriptionPackages &&
                          (value == null || value.isEmpty)) {
                        return 'Please enter price';
                      }
                      return null;
                    },
                  ),
                ],

                // Subscription Packages (if paid)
                if (_pricingType == 'paid') ...[
                  SizedBox(height: 16.h),
                  Container(
                    padding: EdgeInsets.all(16.w),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(8.r),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Subscription Packages',
                                    style: TextStyle(
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF111827),
                                    ),
                                  ),
                                  SizedBox(height: 4.h),
                                  Text(
                                    'Offer weekly, monthly, or yearly packages (e.g., gym membership)',
                                    style: TextStyle(
                                      fontSize: 12.sp,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: _hasSubscriptionPackages,
                              onChanged: (value) {
                                setState(() {
                                  _hasSubscriptionPackages = value;
                                });
                              },
                              activeThumbColor: const Color(0xFF0E4778),
                            ),
                          ],
                        ),

                        if (_hasSubscriptionPackages) ...[
                          SizedBox(height: 16.h),
                          ...['Weekly', 'Monthly', 'Yearly'].map((packageType) {
                            return Padding(
                              padding: EdgeInsets.only(bottom: 12.h),
                              child: TextFormField(
                                controller: _packageControllers[packageType],
                                decoration: InputDecoration(
                                  labelText: '$packageType Package',
                                  hintText: 'Enter price',
                                  prefixText: '₹ ',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8.r),
                                  ),
                                  filled: true,
                                  fillColor: Colors.white,
                                ),
                                keyboardType: TextInputType.number,
                              ),
                            );
                          }),
                        ],
                      ],
                    ),
                  ),
                ],
                SizedBox(height: 20.h),

                // Time Slots Section
                Text(
                  'Time Slots (Optional)',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827),
                  ),
                ),
                SizedBox(height: 12.h),

                // Time Slot Grid
                Container(
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(8.r),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Column(
                    children: [
                      // Quick Actions
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${_selectedTimeSlots.length} selected',
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                          Row(
                            children: [
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    _selectedTimeSlots.clear();
                                    _selectedTimeSlots.addAll(
                                      _predefinedTimeSlots,
                                    );
                                  });
                                },
                                style: TextButton.styleFrom(
                                  foregroundColor: const Color(0xFF0E4778),
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 8.w,
                                  ),
                                  minimumSize: const Size(0, 28),
                                ),
                                child: Text(
                                  'All',
                                  style: TextStyle(fontSize: 11.sp),
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    _selectedTimeSlots.clear();
                                  });
                                },
                                style: TextButton.styleFrom(
                                  foregroundColor: const Color(0xFFEF4444),
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 8.w,
                                  ),
                                  minimumSize: const Size(0, 28),
                                ),
                                child: Text(
                                  'Clear',
                                  style: TextStyle(fontSize: 11.sp),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      SizedBox(height: 8.h),

                      // Time Slot Chips
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _selectedTimeSlots.map((slot) {
                          final isPredefined = _predefinedTimeSlots.contains(
                            slot,
                          );
                          return Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 14.w,
                              vertical: 10.h,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0E4778),
                              borderRadius: BorderRadius.circular(6.r),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  slot,
                                  style: TextStyle(
                                    fontSize: 13.sp,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(width: 6.w),
                                GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _selectedTimeSlots.remove(slot);
                                    });
                                  },
                                  child: Icon(
                                    Icons.close,
                                    size: 16.w,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                      SizedBox(height: 12.h),

                      // Predefined Time Slots
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _predefinedTimeSlots.map((slot) {
                          final isSelected = _selectedTimeSlots.contains(slot);
                          if (isSelected) return const SizedBox.shrink();

                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedTimeSlots.add(slot);
                              });
                            },
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 14.w,
                                vertical: 10.h,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(6.r),
                                border: Border.all(
                                  color: const Color(0xFFE5E7EB),
                                ),
                              ),
                              child: Text(
                                slot,
                                style: TextStyle(
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF374151),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),

                      // Custom Time Slot Entry
                      SizedBox(height: 12.h),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _customTimeSlotController,
                              decoration: InputDecoration(
                                hintText: 'e.g., 10:00 PM - 11:00 PM',
                                hintStyle: TextStyle(fontSize: 12.sp),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12.w,
                                  vertical: 8.h,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6.r),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFE5E7EB),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6.r),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFE5E7EB),
                                  ),
                                ),
                              ),
                              style: TextStyle(fontSize: 12.sp),
                            ),
                          ),
                          SizedBox(width: 8.w),
                          ElevatedButton(
                            onPressed: () {
                              if (_customTimeSlotController.text
                                  .trim()
                                  .isNotEmpty) {
                                setState(() {
                                  _selectedTimeSlots.add(
                                    _customTimeSlotController.text.trim(),
                                  );
                                  _customTimeSlotController.clear();
                                });
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0E4778),
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(
                                horizontal: 16.w,
                                vertical: 8.h,
                              ),
                              minimumSize: const Size(0, 32),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6.r),
                              ),
                            ),
                            child: Text(
                              'Add',
                              style: TextStyle(fontSize: 12.sp),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16.h),

                // Description
                TextFormField(
                  controller: _descriptionController,
                  decoration: InputDecoration(
                    labelText: 'Description (Optional)',
                    hintText: 'Enter amenity description',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                  ),
                  maxLines: 3,
                ),
                SizedBox(height: 20.h),

                // Booking Configuration Section
                Text(
                  'Booking Configuration',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827),
                  ),
                ),
                SizedBox(height: 12.h),

                // Allow Multiple Bookings
                Container(
                  padding: EdgeInsets.all(16.w),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(8.r),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Allow Multiple Bookings',
                                  style: TextStyle(
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF111827),
                                  ),
                                ),
                                SizedBox(height: 4.h),
                                Text(
                                  'Allow multiple residents to book the same time slot',
                                  style: TextStyle(
                                    fontSize: 12.sp,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: _allowMultipleBookings,
                            onChanged: (value) {
                              setState(() {
                                _allowMultipleBookings = value;
                                if (!value) {
                                  _maxCapacityController.text = '1';
                                }
                              });
                            },
                            activeThumbColor: const Color(0xFF0E4778),
                          ),
                        ],
                      ),

                      // Max Capacity (shown only if multiple bookings allowed)
                      if (_allowMultipleBookings) ...[
                        SizedBox(height: 16.h),
                        TextFormField(
                          controller: _maxCapacityController,
                          decoration: InputDecoration(
                            labelText: 'Maximum Capacity *',
                            hintText: 'e.g., 30 for swimming pool',
                            helperText:
                                'Maximum number of people allowed at the same time',
                            helperStyle: TextStyle(fontSize: 11.sp),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (_allowMultipleBookings &&
                                (value == null || value.isEmpty)) {
                              return 'Please enter maximum capacity';
                            }
                            if (_allowMultipleBookings &&
                                int.tryParse(value!) == null) {
                              return 'Please enter a valid number';
                            }
                            if (_allowMultipleBookings &&
                                int.parse(value!) < 2) {
                              return 'Capacity must be at least 2';
                            }
                            return null;
                          },
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(height: 16.h),

                // Booking Duration Options
                Text(
                  'Booking Duration Options',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827),
                  ),
                ),
                SizedBox(height: 8.h),
                Container(
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(8.r),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Select how residents can book this amenity',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: Colors.grey[600],
                        ),
                      ),
                      SizedBox(height: 12.h),

                      // Selected Durations
                      if (_selectedDurations.isNotEmpty)
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _selectedDurations.map((duration) {
                            return Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 12.w,
                                vertical: 8.h,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0E4778),
                                borderRadius: BorderRadius.circular(6.r),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    duration,
                                    style: TextStyle(
                                      fontSize: 12.sp,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white,
                                    ),
                                  ),
                                  if (_selectedDurations.length > 1) ...[
                                    SizedBox(width: 6.w),
                                    GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _selectedDurations.remove(duration);
                                        });
                                      },
                                      child: Icon(
                                        Icons.close,
                                        size: 14.w,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      SizedBox(height: 12.h),

                      // Available Durations
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _predefinedDurations.map((duration) {
                          final isSelected = _selectedDurations.contains(
                            duration,
                          );
                          if (isSelected) return const SizedBox.shrink();

                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedDurations.add(duration);
                              });
                            },
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 12.w,
                                vertical: 8.h,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(6.r),
                                border: Border.all(
                                  color: const Color(0xFFE5E7EB),
                                ),
                              ),
                              child: Text(
                                duration,
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF374151),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),

                      // Custom Duration Entry
                      SizedBox(height: 12.h),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _customDurationController,
                              decoration: InputDecoration(
                                hintText: 'e.g., 4 hours',
                                hintStyle: TextStyle(fontSize: 12.sp),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12.w,
                                  vertical: 8.h,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6.r),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFE5E7EB),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6.r),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFE5E7EB),
                                  ),
                                ),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                              style: TextStyle(fontSize: 12.sp),
                            ),
                          ),
                          SizedBox(width: 8.w),
                          ElevatedButton(
                            onPressed: () {
                              if (_customDurationController.text
                                  .trim()
                                  .isNotEmpty) {
                                setState(() {
                                  _selectedDurations.add(
                                    _customDurationController.text.trim(),
                                  );
                                  _customDurationController.clear();
                                });
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0E4778),
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(
                                horizontal: 16.w,
                                vertical: 8.h,
                              ),
                              minimumSize: const Size(0, 32),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6.r),
                              ),
                            ),
                            child: Text(
                              'Add',
                              style: TextStyle(fontSize: 12.sp),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 24.h),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 48.h,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submitForm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0E4778),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                    ),
                    child: _isLoading
                        ? SizedBox(
                            width: 20.w,
                            height: 20.h,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : Text(
                            'Add Amenity',
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedBuildingId == null || _selectedBuildingName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a building'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    if (_selectedDurations.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one booking duration'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Determine type based on icon
      String type = 'Recreation';
      switch (_selectedIcon) {
        case 'gym':
        case 'playground':
          type = 'Sports';
          break;
        case 'hall':
          type = 'Event';
          break;
        case 'parking':
          type = 'Facility';
          break;
      }

      // Build subscription packages map
      Map<String, double>? subscriptionPackages;
      if (_hasSubscriptionPackages) {
        subscriptionPackages = {};
        _packageControllers.forEach((key, controller) {
          if (controller.text.isNotEmpty) {
            final price = double.tryParse(controller.text);
            if (price != null && price > 0) {
              subscriptionPackages![key] = price;
            }
          }
        });
      }

      await _amenityService.addAmenity(
        name: _nameController.text.trim(),
        type: type,
        isFree: _pricingType == 'free',
        buildingId: _selectedBuildingId!,
        buildingName: _selectedBuildingName!,
        pricePerDay: _pricingType == 'free'
            ? 0
            : double.tryParse(_priceController.text) ?? 0,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        iconName: _selectedIcon,
        timeSlots: _selectedTimeSlots.isEmpty ? null : _selectedTimeSlots,
        maxCapacity: _allowMultipleBookings
            ? int.tryParse(_maxCapacityController.text) ?? 1
            : 1,
        allowMultipleBookings: _allowMultipleBookings,
        bookingDurations: _selectedDurations,
        hasSubscriptionPackages: _hasSubscriptionPackages,
        subscriptionPackages: subscriptionPackages,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Amenity added successfully'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
