import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';

import '../services/amenity_service.dart';
import '../services/building_service.dart';
import '../services/image_picker_service.dart';

class AddAmenityModal extends StatefulWidget {
  final AmenityService? amenityService;
  final Stream<List<BuildingModel>>? buildings;
  final bool bookingConfigurationEnabled;

  const AddAmenityModal({
    super.key,
    this.amenityService,
    this.buildings,
    this.bookingConfigurationEnabled = true,
  });

  @override
  State<AddAmenityModal> createState() => _AddAmenityModalState();
}

class _AddAmenityModalState extends State<AddAmenityModal> {
  static const List<String> _facilityTypeOptions = [
    'Gym',
    'Swimming Pool',
    'Clubhouse',
    'Function Hall',
    'Sports Court',
    'Playground',
    'Garden / Park',
    'Meeting Room',
    'Multipurpose Hall',
    'Recreation Area',
    'Other',
  ];

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _ownerPriceController = TextEditingController();
  final _tenantPriceController = TextEditingController();
  final _typeController = TextEditingController(text: 'Recreation Area');
  final _customTypeController = TextEditingController();
  final _imageUrlController = TextEditingController();
  bool _isAvailable = true;
  String? _buildingError;
  StreamSubscription<List<BuildingModel>>? _buildingSubscription;
  final _customTimeSlotController = TextEditingController();
  final _maxCapacityController = TextEditingController(text: '1');
  final _customDurationController = TextEditingController();

  late final AmenityService _amenityService =
      widget.amenityService ?? AmenityService();

  String _selectedIcon = 'pool';
  String _selectedFacilityType = 'Recreation Area';
  String _pricingType = 'free'; // free | flat | resident_type
  bool _isLoading = false;
  bool _allowMultipleBookings = false;
  bool _hasSubscriptionPackages = false;

  final List<XFile> _facilityImages = [];

  // Building selection
  String? _selectedBuildingId;
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
    _buildingSubscription =
        (widget.buildings ?? BuildingService().getBuildings()).listen(
          (buildings) {
            if (!mounted) return;
            setState(() {
              _buildingError = null;
              _buildings = buildings;
              if (!_buildings.any(
                (building) => building.id == _selectedBuildingId,
              )) {
                _selectedBuildingId = _buildings.isEmpty
                    ? null
                    : _buildings.first.id;
              }
            });
          },
          onError: (Object error) {
            if (!mounted) return;
            setState(() {
              _buildings = [];
              _selectedBuildingId = null;
              _buildingError =
                  'Unable to load buildings. Reopen this form to retry.';
            });
          },
        );
  }

  Future<void> _pickFacilityImagesFromGallery() async {
    final remaining =
        ImagePickerService.maxFacilityImages - _facilityImages.length;
    if (remaining <= 0) {
      _showImageMessage('You can add up to 6 facility photos.');
      return;
    }

    final picked = await ImagePickerService.pickMultipleFromGallery(
      maxImages: remaining,
    );
    await _addValidatedFacilityImages(picked);
  }

  Future<void> _pickFacilityImageFromCamera() async {
    if (_facilityImages.length >= ImagePickerService.maxFacilityImages) {
      _showImageMessage('You can add up to 6 facility photos.');
      return;
    }

    final image = await ImagePickerService.pickXFileFromCamera();
    if (image == null) return;
    await _addValidatedFacilityImages([image]);
  }

  Future<void> _addValidatedFacilityImages(List<XFile> images) async {
    if (images.isEmpty) return;

    final valid = <XFile>[];
    for (final image in images) {
      final error = await ImagePickerService.facilityImageValidationError(
        image,
      );
      if (error != null) {
        _showImageMessage(error);
        continue;
      }
      valid.add(image);
    }

    if (!mounted || valid.isEmpty) return;

    final available =
        ImagePickerService.maxFacilityImages - _facilityImages.length;
    setState(() {
      _facilityImages.addAll(valid.take(available));
    });

    if (valid.length > available) {
      _showImageMessage('Only the first $available photos were added.');
    }
  }

  void _setFacilityImagePrimary(int index) {
    if (index <= 0 || index >= _facilityImages.length) return;
    setState(() {
      final image = _facilityImages.removeAt(index);
      _facilityImages.insert(0, image);
    });
  }

  void _removeFacilityImage(int index) {
    if (index < 0 || index >= _facilityImages.length) return;
    setState(() {
      _facilityImages.removeAt(index);
    });
  }

  void _showImageMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildFacilityPhotosSection() {
    final canAdd =
        _facilityImages.length < ImagePickerService.maxFacilityImages;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Facility photos',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Up to 6 photos. The first photo is the primary image.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              Text(
                '${_facilityImages.length}/6',
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0E4778),
                ),
              ),
            ],
          ),
          SizedBox(height: 14.h),
          Wrap(
            spacing: 10.w,
            runSpacing: 10.h,
            children: [
              OutlinedButton.icon(
                key: const ValueKey('facility-add-gallery-photos'),
                onPressed: canAdd ? _pickFacilityImagesFromGallery : null,
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Gallery'),
              ),
              OutlinedButton.icon(
                key: const ValueKey('facility-add-camera-photo'),
                onPressed: canAdd ? _pickFacilityImageFromCamera : null,
                icon: const Icon(Icons.photo_camera_outlined),
                label: const Text('Camera'),
              ),
            ],
          ),
          if (_facilityImages.isNotEmpty) ...[
            SizedBox(height: 14.h),
            Wrap(
              spacing: 10.w,
              runSpacing: 10.h,
              children: List.generate(_facilityImages.length, (index) {
                final image = _facilityImages[index];
                return _FacilityPickedImageTile(
                  key: ValueKey('facility-picked-photo-$index'),
                  file: image,
                  isPrimary: index == 0,
                  onSetPrimary: index == 0
                      ? null
                      : () => _setFacilityImagePrimary(index),
                  onRemove: () => _removeFacilityImage(index),
                );
              }),
            ),
          ],
        ],
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _ownerPriceController.dispose();
    _tenantPriceController.dispose();
    _typeController.dispose();
    _customTypeController.dispose();
    _imageUrlController.dispose();
    _buildingSubscription?.cancel();
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
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        debugPrint('ADD_AMENITY_CLOSE_TAPPED');

                        final navigator = Navigator.of(context);
                        debugPrint('ADD_AMENITY_CAN_POP=${navigator.canPop()}');

                        navigator.pop();
                      },
                      child: SizedBox(
                        width: 56.w,
                        height: 56.h,
                        child: const Center(child: Icon(Icons.close, size: 30)),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 24.h),

                // Building Selection
                DropdownButtonFormField<String>(
                  key: ValueKey('facility-building-$_selectedBuildingId'),
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
                    });
                  },
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please select a building';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16.h),

                if (_buildingError != null)
                  Text(
                    _buildingError!,
                    style: const TextStyle(color: Colors.red),
                  ),
                if (_buildingError == null && _buildings.isEmpty)
                  const Text(
                    'A building is required before adding a facility.',
                  ),

                // Name
                TextFormField(
                  key: const ValueKey('facility-name'),
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Amenity Name *',
                    hintText: 'e.g., Swimming Pool',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter amenity name';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16.h),

                DropdownButtonFormField<String>(
                  key: const ValueKey('facility-type'),
                  initialValue: _selectedFacilityType,
                  decoration: InputDecoration(
                    labelText: 'Facility type *',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                  ),
                  items: _facilityTypeOptions
                      .map(
                        (type) => DropdownMenuItem<String>(
                          value: type,
                          child: Text(type),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _selectedFacilityType = value;
                      _typeController.text = value == 'Other'
                          ? _customTypeController.text.trim()
                          : value;
                    });
                  },
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Please select facility type'
                      : null,
                ),
                if (_selectedFacilityType == 'Other') ...[
                  SizedBox(height: 12.h),
                  TextFormField(
                    key: const ValueKey('facility-type-custom'),
                    controller: _customTypeController,
                    decoration: InputDecoration(
                      labelText: 'Specify facility type *',
                      hintText: 'Enter facility type',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                    ),
                    onChanged: (value) {
                      _typeController.text = value.trim();
                    },
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Please specify facility type'
                        : null,
                  ),
                ],
                SizedBox(height: 16.h),
                SwitchListTile(
                  title: const Text('Available'),
                  value: _isAvailable,
                  onChanged: (value) => setState(() => _isAvailable = value),
                  contentPadding: EdgeInsets.zero,
                ),
                _buildFacilityPhotosSection(),
                SizedBox(height: 12.h),
                TextFormField(
                  key: const ValueKey('facility-image'),
                  controller: _imageUrlController,
                  decoration: InputDecoration(
                    labelText: 'Legacy image URL (optional)',
                    helperText:
                        'Optional compatibility field. Selected photos take priority.',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                  ),
                  validator: AmenityService.imageUrlValidationError,
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
                            if (_pricingType == 'free') {
                              _pricingType = 'flat';
                            }
                          });
                        },
                        child: Container(
                          padding: EdgeInsets.all(16.w),
                          decoration: BoxDecoration(
                            color: _pricingType != 'free'
                                ? const Color(0xFF0E4778).withOpacity(0.1)
                                : const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(8.r),
                            border: Border.all(
                              color: _pricingType != 'free'
                                  ? const Color(0xFF0E4778)
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _pricingType != 'free'
                                    ? Icons.check_circle
                                    : Icons.circle_outlined,
                                color: _pricingType != 'free'
                                    ? const Color(0xFF0E4778)
                                    : const Color(0xFF6B7280),
                                size: 20.w,
                              ),
                              SizedBox(width: 8.w),
                              Text(
                                'Chargeable',
                                style: TextStyle(
                                  fontSize: 15.sp,
                                  fontWeight: FontWeight.w600,
                                  color: _pricingType != 'free'
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
                if (_pricingType != 'free') ...[
                  SizedBox(height: 16.h),

                  Text(
                    'Chargeable pricing',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF111827),
                    ),
                  ),

                  SizedBox(height: 10.h),

                  RadioListTile<String>(
                    contentPadding: EdgeInsets.zero,
                    value: 'flat',
                    groupValue: _pricingType,
                    title: const Text('Same fee for everyone'),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _pricingType = value;
                      });
                    },
                  ),

                  RadioListTile<String>(
                    contentPadding: EdgeInsets.zero,
                    value: 'resident_type',
                    groupValue: _pricingType,
                    title: const Text('Different fee by resident type'),
                    subtitle: const Text(
                      'Separate fee for Owner and Tenant / Lease',
                    ),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _pricingType = value;
                      });
                    },
                  ),
                ],

                if (_pricingType == 'flat') ...[
                  SizedBox(height: 8.h),
                  TextFormField(
                    key: const ValueKey('facility-price'),
                    controller: _priceController,
                    decoration: InputDecoration(
                      labelText: 'Fee per Day *',
                      hintText: 'Enter amount',
                      prefixText: '₹ ',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (value) {
                      // Existing package-only behavior may use a zero daily fee.
                      if (_hasSubscriptionPackages &&
                          (value?.trim().isEmpty ?? true)) {
                        return null;
                      }

                      return AmenityService.priceValidationError(value);
                    },
                  ),
                ],

                if (_pricingType == 'resident_type') ...[
                  SizedBox(height: 8.h),

                  TextFormField(
                    key: const ValueKey('facility-owner-price'),
                    controller: _ownerPriceController,
                    decoration: InputDecoration(
                      labelText: 'Owner fee per Day *',
                      hintText: 'Enter owner amount',
                      prefixText: '₹ ',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: AmenityService.priceValidationError,
                  ),

                  SizedBox(height: 12.h),

                  TextFormField(
                    key: const ValueKey('facility-tenant-price'),
                    controller: _tenantPriceController,
                    decoration: InputDecoration(
                      labelText: 'Tenant / Lease fee per Day *',
                      hintText: 'Enter tenant amount',
                      prefixText: '₹ ',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: AmenityService.priceValidationError,
                  ),
                ],
                // Subscription Packages (if paid)
                if (_pricingType != 'free') ...[
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

                if (widget.bookingConfigurationEnabled) ...[
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
                            final isSelected = _selectedTimeSlots.contains(
                              slot,
                            );
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
                ],

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

                if (widget.bookingConfigurationEnabled) ...[
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
                                  (value == null || value.trim().isEmpty)) {
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
                ],

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
    if (_isLoading || !_formKey.currentState!.validate()) return;

    if (_selectedBuildingId == null ||
        !_buildings.any((b) => b.id == _selectedBuildingId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a building'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    if (widget.bookingConfigurationEnabled && _selectedDurations.isEmpty) {
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

      final name = _nameController.text.trim();
      final type = _typeController.text.trim();
      final imageUrl = _imageUrlController.text.trim();
      final isFree = _pricingType == 'free';
      final buildingId = _selectedBuildingId!;
      final double pricePerDay = _pricingType == 'flat'
          ? double.tryParse(_priceController.text.trim()) ?? 0.0
          : 0.0;
      final ownerPricePerDay = _pricingType == 'resident_type'
          ? double.tryParse(_ownerPriceController.text.trim())
          : null;
      final tenantPricePerDay = _pricingType == 'resident_type'
          ? double.tryParse(_tenantPriceController.text.trim())
          : null;
      final description = _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim();
      final maxCapacity = _allowMultipleBookings
          ? int.tryParse(_maxCapacityController.text) ?? 1
          : 1;

      if (_facilityImages.isEmpty) {
        // Keep the legacy invocation shape for existing callers/tests.
        await _amenityService.addAmenity(
          name: name,
          type: type,
          isAvailable: _isAvailable,
          imageUrl: imageUrl,
          isFree: isFree,
          buildingId: buildingId,
          pricingMode: _pricingType,
          pricePerDay: pricePerDay,
          ownerPricePerDay: ownerPricePerDay,
          tenantPricePerDay: tenantPricePerDay,
          description: description,
          iconName: _selectedIcon,
          timeSlots: widget.bookingConfigurationEnabled
              ? _selectedTimeSlots
              : const <String>[],
          maxCapacity: widget.bookingConfigurationEnabled ? maxCapacity : 1,
          allowMultipleBookings:
              widget.bookingConfigurationEnabled && _allowMultipleBookings,
          bookingDurations: widget.bookingConfigurationEnabled
              ? _selectedDurations
              : const <String>[],
          hasSubscriptionPackages: _hasSubscriptionPackages,
          subscriptionPackages: subscriptionPackages,
        );
      } else {
        await _amenityService.addAmenity(
          name: name,
          type: type,
          isAvailable: _isAvailable,
          imageUrl: imageUrl,
          imageFiles: List<XFile>.from(_facilityImages),
          isFree: isFree,
          buildingId: buildingId,
          pricingMode: _pricingType,
          pricePerDay: pricePerDay,
          ownerPricePerDay: ownerPricePerDay,
          tenantPricePerDay: tenantPricePerDay,
          description: description,
          iconName: _selectedIcon,
          timeSlots: widget.bookingConfigurationEnabled
              ? _selectedTimeSlots
              : const <String>[],
          maxCapacity: widget.bookingConfigurationEnabled ? maxCapacity : 1,
          allowMultipleBookings:
              widget.bookingConfigurationEnabled && _allowMultipleBookings,
          bookingDurations: widget.bookingConfigurationEnabled
              ? _selectedDurations
              : const <String>[],
          hasSubscriptionPackages: _hasSubscriptionPackages,
          subscriptionPackages: subscriptionPackages,
        );
      }

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

class _FacilityPickedImageTile extends StatelessWidget {
  final XFile file;
  final bool isPrimary;
  final VoidCallback? onSetPrimary;
  final VoidCallback onRemove;

  const _FacilityPickedImageTile({
    super.key,
    required this.file,
    required this.isPrimary,
    required this.onSetPrimary,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 132,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 132,
                  height: 96,
                  child: FutureBuilder<Uint8List>(
                    future: file.readAsBytes(),
                    builder: (context, snapshot) {
                      if (snapshot.hasData) {
                        return Image.memory(
                          snapshot.data!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _previewFallback(),
                        );
                      }
                      return _previewFallback(showProgress: true);
                    },
                  ),
                ),
              ),
              if (isPrimary)
                Positioned(
                  left: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0E4778),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'PRIMARY',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              Positioned(
                right: 4,
                top: 4,
                child: Material(
                  color: Colors.black54,
                  shape: const CircleBorder(),
                  child: IconButton(
                    key: const ValueKey('facility-remove-photo'),
                    tooltip: 'Remove photo',
                    onPressed: onRemove,
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 17,
                    ),
                    constraints: const BoxConstraints.tightFor(
                      width: 32,
                      height: 32,
                    ),
                    padding: EdgeInsets.zero,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            file.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
          ),
          if (!isPrimary)
            TextButton(
              onPressed: onSetPrimary,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 28),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Set primary', style: TextStyle(fontSize: 11)),
            ),
        ],
      ),
    );
  }

  Widget _previewFallback({bool showProgress = false}) {
    return Container(
      color: const Color(0xFFEFF3F7),
      alignment: Alignment.center,
      child: showProgress
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.image_not_supported_outlined),
    );
  }
}
