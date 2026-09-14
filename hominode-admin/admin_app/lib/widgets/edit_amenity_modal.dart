import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../services/amenity_service.dart';

class EditAmenityModal extends StatefulWidget {
  final AmenityModel amenity;

  final AmenityService? amenityService;

  const EditAmenityModal({
    super.key,
    required this.amenity,
    this.amenityService,
  });

  @override
  State<EditAmenityModal> createState() => _EditAmenityModalState();
}

class _EditAmenityModalState extends State<EditAmenityModal> {
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
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _priceController;
  late TextEditingController _ownerPriceController;
  late TextEditingController _tenantPriceController;

  late final AmenityService _amenityService =
      widget.amenityService ?? AmenityService();
  late TextEditingController _typeController;
  late TextEditingController _customTypeController;
  late TextEditingController _imageUrlController;
  final _customTimeSlotController = TextEditingController();
  late final Map<String, dynamic> _initialValues;
  late String _selectedIcon;
  late String _selectedFacilityType;
  late String _pricingMode;
  bool _isLoading = false;

  // Time slots
  final List<String> _availableTimeSlots = [
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

  late List<String> _selectedTimeSlots;

  final Map<String, IconData> _icons = {
    'pool': Icons.pool,
    'gym': Icons.fitness_center,
    'hall': Icons.home,
    'lawn': Icons.grass,
    'parking': Icons.local_parking,
    'playground': Icons.sports_soccer,
  };
  String _priceText(double? value) {
    if (value == null) return '';
    return value.toString().replaceFirst(RegExp(r'\.0$'), '');
  }

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.amenity.name);
    _descriptionController = TextEditingController(
      text: widget.amenity.description ?? '',
    );
    _pricingMode = widget.amenity.pricingMode;

    _priceController = TextEditingController(
      text: _pricingMode == 'flat'
          ? _priceText(widget.amenity.pricePerDay)
          : '',
    );

    _ownerPriceController = TextEditingController(
      text: _pricingMode == 'resident_type'
          ? _priceText(widget.amenity.ownerPricePerDay)
          : '',
    );

    _tenantPriceController = TextEditingController(
      text: _pricingMode == 'resident_type'
          ? _priceText(widget.amenity.tenantPricePerDay)
          : '',
    );
    final existingType = widget.amenity.type.trim();
    final isPredefinedType =
        _facilityTypeOptions.contains(existingType) && existingType != 'Other';
    _selectedFacilityType = isPredefinedType ? existingType : 'Other';
    _typeController = TextEditingController(text: existingType);
    _customTypeController = TextEditingController(
      text: isPredefinedType ? '' : existingType,
    );
    _imageUrlController = TextEditingController(
      text: widget.amenity.imageUrl ?? '',
    );
    _selectedIcon = widget.amenity.iconName ?? '';
    _selectedTimeSlots = List<String>.from(widget.amenity.timeSlots ?? []);
    _initialValues = _formValues();
  }

  Map<String, dynamic> _formValues() {
    final values = <String, dynamic>{
      'name': _nameController.text.trim(),
      'type': _typeController.text.trim(),
      'description': _descriptionController.text.trim(),
      'imageUrl': _imageUrlController.text.trim(),
      'iconName': _selectedIcon,
      'pricingMode': _pricingMode,
      'isFree': _pricingMode == 'free',
      'pricePerDay': _pricingMode == 'flat'
          ? double.tryParse(_priceController.text.trim())
          : 0,
      'timeSlots': List<String>.from(_selectedTimeSlots),
    };

    if (_pricingMode == 'resident_type') {
      values['ownerPricePerDay'] = double.tryParse(
        _ownerPriceController.text.trim(),
      );
      values['tenantPricePerDay'] = double.tryParse(
        _tenantPriceController.text.trim(),
      );
    }

    return values;
  }

  void _addCustomSlot() {
    final slot = _customTimeSlotController.text.trim();
    if (slot.isEmpty) return;
    setState(() {
      if (!_selectedTimeSlots.contains(slot)) _selectedTimeSlots.add(slot);
      _customTimeSlotController.clear();
    });
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
    _customTimeSlotController.dispose();
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
                      'Edit Amenity',
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

                // Facilities V1 preserves the original building assignment.
                InputDecorator(
                  decoration: const InputDecoration(labelText: 'Building'),
                  child: Text(
                    widget.amenity.buildingName.isNotEmpty
                        ? widget.amenity.buildingName
                        : widget.amenity.buildingId,
                  ),
                ),
                SizedBox(height: 16.h),

                // Name
                TextFormField(
                  key: const ValueKey('facility-name'),
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Amenity Name *',
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
                TextFormField(
                  key: const ValueKey('facility-image'),
                  controller: _imageUrlController,
                  decoration: InputDecoration(
                    labelText: 'Image URL (optional)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                  ),
                  validator: AmenityService.imageUrlValidationError,
                ),
                SizedBox(height: 16.h),

                // Icon
                Text(
                  'Icon *',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF6B7280),
                  ),
                ),
                SizedBox(height: 8.h),
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
                      child: Container(
                        width: 56.w,
                        height: 56.h,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF0E4778).withOpacity(0.1)
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12.r),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF0E4778)
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          entry.value,
                          color: isSelected
                              ? const Color(0xFF0E4778)
                              : Colors.grey.shade600,
                          size: 28.w,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                SizedBox(height: 16.h),
                // Facility fee
                Text(
                  'Facility fee *',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF111827),
                  ),
                ),

                SizedBox(height: 12.h),

                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _pricingMode = 'free';
                          });
                        },
                        child: Container(
                          padding: EdgeInsets.all(16.w),
                          decoration: BoxDecoration(
                            color: _pricingMode == 'free'
                                ? const Color(0xFF10B981).withOpacity(0.1)
                                : const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(8.r),
                            border: Border.all(
                              color: _pricingMode == 'free'
                                  ? const Color(0xFF10B981)
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _pricingMode == 'free'
                                    ? Icons.check_circle
                                    : Icons.circle_outlined,
                                color: _pricingMode == 'free'
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
                                  color: _pricingMode == 'free'
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
                            if (_pricingMode == 'free') {
                              _pricingMode = 'flat';
                            }
                          });
                        },
                        child: Container(
                          padding: EdgeInsets.all(16.w),
                          decoration: BoxDecoration(
                            color: _pricingMode != 'free'
                                ? const Color(0xFF0E4778).withOpacity(0.1)
                                : const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(8.r),
                            border: Border.all(
                              color: _pricingMode != 'free'
                                  ? const Color(0xFF0E4778)
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _pricingMode != 'free'
                                    ? Icons.check_circle
                                    : Icons.circle_outlined,
                                color: _pricingMode != 'free'
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
                                  color: _pricingMode != 'free'
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

                if (_pricingMode != 'free') ...[
                  SizedBox(height: 16.h),

                  Text(
                    'Chargeable pricing',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF111827),
                    ),
                  ),

                  RadioListTile<String>(
                    contentPadding: EdgeInsets.zero,
                    value: 'flat',
                    groupValue: _pricingMode,
                    title: const Text('Same fee for everyone'),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _pricingMode = value;
                      });
                    },
                  ),

                  RadioListTile<String>(
                    contentPadding: EdgeInsets.zero,
                    value: 'resident_type',
                    groupValue: _pricingMode,
                    title: const Text('Different fee by resident type'),
                    subtitle: const Text(
                      'Separate fee for Owner and Tenant / Lease',
                    ),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _pricingMode = value;
                      });
                    },
                  ),
                ],

                if (_pricingMode == 'flat') ...[
                  SizedBox(height: 8.h),
                  TextFormField(
                    key: const ValueKey('facility-price'),
                    controller: _priceController,
                    decoration: InputDecoration(
                      labelText: 'Fee per Day *',
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

                if (_pricingMode == 'resident_type') ...[
                  SizedBox(height: 8.h),

                  TextFormField(
                    key: const ValueKey('facility-owner-price'),
                    controller: _ownerPriceController,
                    decoration: InputDecoration(
                      labelText: 'Owner fee per Day *',
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
                SizedBox(height: 12.h),
                // Time Slots Section
                Text(
                  'Time Slots',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827),
                  ),
                ),
                SizedBox(height: 8.h),

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
                                    for (final slot in _availableTimeSlots) {
                                      if (!_selectedTimeSlots.contains(slot)) {
                                        _selectedTimeSlots.add(slot);
                                      }
                                    }
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

                      Wrap(
                        spacing: 8,
                        children: [
                          for (var i = 0; i < _selectedTimeSlots.length; i++)
                            InputChip(
                              key: ValueKey('selected-slot-$i'),
                              label: Text(_selectedTimeSlots[i]),
                              onDeleted: () => setState(
                                () => _selectedTimeSlots.removeAt(i),
                              ),
                            ),
                        ],
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              key: const ValueKey('custom-time-slot'),
                              controller: _customTimeSlotController,
                              decoration: const InputDecoration(
                                labelText: 'Custom time slot',
                              ),
                              onSubmitted: (_) => _addCustomSlot(),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Add time slot',
                            onPressed: _addCustomSlot,
                            icon: const Icon(Icons.add),
                          ),
                        ],
                      ),
                      SizedBox(height: 8.h),

                      // Time Slot Chips
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _availableTimeSlots.map((slot) {
                          final isSelected = _selectedTimeSlots.contains(slot);
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                if (isSelected) {
                                  _selectedTimeSlots.remove(slot);
                                } else {
                                  _selectedTimeSlots.add(slot);
                                }
                              });
                            },
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 14.w,
                                vertical: 10.h,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFF0E4778)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(6.r),
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFF0E4778)
                                      : const Color(0xFFE5E7EB),
                                ),
                              ),
                              child: Text(
                                slot,
                                style: TextStyle(
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w500,
                                  color: isSelected
                                      ? Colors.white
                                      : const Color(0xFF374151),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
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
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                  ),
                  maxLines: 3,
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
                            'Update Amenity',
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

    setState(() {
      _isLoading = true;
    });

    try {
      final values = _formValues();
      final updates = <String, dynamic>{};
      for (final entry in values.entries) {
        final unchanged = entry.key == 'timeSlots'
            ? listEquals(
                entry.value as List<String>,
                _initialValues[entry.key] as List<String>,
              )
            : entry.value == _initialValues[entry.key];
        if (!unchanged) updates[entry.key] = entry.value;
      }
      if (updates.isNotEmpty) {
        await _amenityService.updateAmenity(widget.amenity.id, updates);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Amenity updated successfully'),
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
