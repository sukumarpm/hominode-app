import 'package:flutter/material.dart';
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
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
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
                    const Text(
                      'Add Amenity',
                      style: TextStyle(
                        fontSize: 20,
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
                const SizedBox(height: 24),

                // Building Selection
                DropdownButtonFormField<String>(
                  initialValue: _selectedBuildingId,
                  decoration: InputDecoration(
                    labelText: 'Building *',
                    hintText: 'Select building',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
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
                const SizedBox(height: 16),

                // Name
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Amenity Name *',
                    hintText: 'e.g., Swimming Pool',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter amenity name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Icon Selection
                const Text(
                  'Select Icon *',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 12),
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
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF2563EB).withOpacity(0.1)
                                  : const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFF2563EB)
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: Icon(
                              entry.value['icon'] as IconData,
                              color: isSelected
                                  ? const Color(0xFF2563EB)
                                  : const Color(0xFF6B7280),
                              size: 32,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            entry.value['name'] as String,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                              color: isSelected
                                  ? const Color(0xFF2563EB)
                                  : const Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),

                // Pricing Type
                const Text(
                  'Pricing *',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 12),
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
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _pricingType == 'free'
                                ? const Color(0xFF10B981).withOpacity(0.1)
                                : const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(8),
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
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Free',
                                style: TextStyle(
                                  fontSize: 15,
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
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _pricingType = 'paid';
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _pricingType == 'paid'
                                ? const Color(0xFF2563EB).withOpacity(0.1)
                                : const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _pricingType == 'paid'
                                  ? const Color(0xFF2563EB)
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
                                    ? const Color(0xFF2563EB)
                                    : const Color(0xFF6B7280),
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Paid',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: _pricingType == 'paid'
                                      ? const Color(0xFF2563EB)
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
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _priceController,
                    decoration: InputDecoration(
                      labelText: 'Price per Day *',
                      hintText: 'Enter amount',
                      prefixText: '₹ ',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (_pricingType == 'paid' && !_hasSubscriptionPackages && (value == null || value.isEmpty)) {
                        return 'Please enter price';
                      }
                      return null;
                    },
                  ),
                ],
                
                // Subscription Packages (if paid)
                if (_pricingType == 'paid') ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(8),
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
                                  const Text(
                                    'Subscription Packages',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF111827),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Offer weekly, monthly, or yearly packages (e.g., gym membership)',
                                    style: TextStyle(
                                      fontSize: 12,
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
                              activeThumbColor: const Color(0xFF2563EB),
                            ),
                          ],
                        ),
                        
                        if (_hasSubscriptionPackages) ...[
                          const SizedBox(height: 16),
                          ...['Weekly', 'Monthly', 'Yearly'].map((packageType) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: TextFormField(
                                controller: _packageControllers[packageType],
                                decoration: InputDecoration(
                                  labelText: '$packageType Package',
                                  hintText: 'Enter price',
                                  prefixText: '₹ ',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
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
                const SizedBox(height: 20),

                // Time Slots Section
                const Text(
                  'Time Slots (Optional)',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 12),
                
                // Time Slot Grid
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(8),
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
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                          Row(
                            children: [
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    _selectedTimeSlots.clear();
                                    _selectedTimeSlots.addAll(_predefinedTimeSlots);
                                  });
                                },
                                style: TextButton.styleFrom(
                                  foregroundColor: const Color(0xFF2563EB),
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  minimumSize: const Size(0, 28),
                                ),
                                child: const Text('All', style: TextStyle(fontSize: 11)),
                              ),
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    _selectedTimeSlots.clear();
                                  });
                                },
                                style: TextButton.styleFrom(
                                  foregroundColor: const Color(0xFFEF4444),
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  minimumSize: const Size(0, 28),
                                ),
                                child: const Text('Clear', style: TextStyle(fontSize: 11)),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      
                      // Time Slot Chips
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _selectedTimeSlots.map((slot) {
                          final isPredefined = _predefinedTimeSlots.contains(slot);
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2563EB),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  slot,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _selectedTimeSlots.remove(slot);
                                    });
                                  },
                                  child: const Icon(
                                    Icons.close,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),
                      
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
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFE5E7EB)),
                              ),
                              child: Text(
                                slot,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF374151),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      
                      // Custom Time Slot Entry
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _customTimeSlotController,
                              decoration: InputDecoration(
                                hintText: 'e.g., 10:00 PM - 11:00 PM',
                                hintStyle: const TextStyle(fontSize: 12),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6),
                                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6),
                                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                                ),
                              ),
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () {
                              if (_customTimeSlotController.text.trim().isNotEmpty) {
                                setState(() {
                                  _selectedTimeSlots.add(_customTimeSlotController.text.trim());
                                  _customTimeSlotController.clear();
                                });
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              minimumSize: const Size(0, 32),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            child: const Text('Add', style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Description
                TextFormField(
                  controller: _descriptionController,
                  decoration: InputDecoration(
                    labelText: 'Description (Optional)',
                    hintText: 'Enter amenity description',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 20),

                // Booking Configuration Section
                const Text(
                  'Booking Configuration',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 12),

                // Allow Multiple Bookings
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(8),
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
                                const Text(
                                  'Allow Multiple Bookings',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF111827),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Allow multiple residents to book the same time slot',
                                  style: TextStyle(
                                    fontSize: 12,
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
                            activeThumbColor: const Color(0xFF2563EB),
                          ),
                        ],
                      ),
                      
                      // Max Capacity (shown only if multiple bookings allowed)
                      if (_allowMultipleBookings) ...[
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _maxCapacityController,
                          decoration: InputDecoration(
                            labelText: 'Maximum Capacity *',
                            hintText: 'e.g., 30 for swimming pool',
                            helperText: 'Maximum number of people allowed at the same time',
                            helperStyle: const TextStyle(fontSize: 11),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (_allowMultipleBookings && (value == null || value.isEmpty)) {
                              return 'Please enter maximum capacity';
                            }
                            if (_allowMultipleBookings && int.tryParse(value!) == null) {
                              return 'Please enter a valid number';
                            }
                            if (_allowMultipleBookings && int.parse(value!) < 2) {
                              return 'Capacity must be at least 2';
                            }
                            return null;
                          },
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Booking Duration Options
                const Text(
                  'Booking Duration Options',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Select how residents can book this amenity',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      // Selected Durations
                      if (_selectedDurations.isNotEmpty)
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _selectedDurations.map((duration) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2563EB),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    duration,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white,
                                    ),
                                  ),
                                  if (_selectedDurations.length > 1) ...[
                                    const SizedBox(width: 6),
                                    GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _selectedDurations.remove(duration);
                                        });
                                      },
                                      child: const Icon(
                                        Icons.close,
                                        size: 14,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      const SizedBox(height: 12),
                      
                      // Available Durations
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _predefinedDurations.map((duration) {
                          final isSelected = _selectedDurations.contains(duration);
                          if (isSelected) return const SizedBox.shrink();
                          
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedDurations.add(duration);
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFE5E7EB)),
                              ),
                              child: Text(
                                duration,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF374151),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      
                      // Custom Duration Entry
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _customDurationController,
                              decoration: InputDecoration(
                                hintText: 'e.g., 4 hours',
                                hintStyle: const TextStyle(fontSize: 12),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6),
                                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6),
                                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                                ),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () {
                              if (_customDurationController.text.trim().isNotEmpty) {
                                setState(() {
                                  _selectedDurations.add(_customDurationController.text.trim());
                                  _customDurationController.clear();
                                });
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              minimumSize: const Size(0, 32),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            child: const Text('Add', style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submitForm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'Add Amenity',
                            style: TextStyle(
                              fontSize: 16,
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
        pricePerDay: _pricingType == 'free' ? 0 : double.tryParse(_priceController.text) ?? 0,
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
