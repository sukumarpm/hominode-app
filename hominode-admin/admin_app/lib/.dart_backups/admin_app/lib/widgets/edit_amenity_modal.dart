import 'package:flutter/material.dart';
import '../services/amenity_service.dart';
import '../services/building_service.dart';

class EditAmenityModal extends StatefulWidget {
  final AmenityModel amenity;
  
  const EditAmenityModal({
    super.key,
    required this.amenity,
  });

  @override
  State<EditAmenityModal> createState() => _EditAmenityModalState();
}

class _EditAmenityModalState extends State<EditAmenityModal> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _priceController;
  
  final AmenityService _amenityService = AmenityService();
  final BuildingService _buildingService = BuildingService();
  
  late String _selectedType;
  late String _selectedIcon;
  late bool _isFree;
  bool _isLoading = false;
  
  // Building selection
  late String _selectedBuildingId;
  late String _selectedBuildingName;
  List<BuildingModel> _buildings = [];
  
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

  final List<String> _types = ['Recreation', 'Sports', 'Event', 'Facility'];
  final Map<String, IconData> _icons = {
    'pool': Icons.pool,
    'gym': Icons.fitness_center,
    'hall': Icons.home,
    'lawn': Icons.grass,
    'parking': Icons.local_parking,
    'playground': Icons.sports_soccer,
  };

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.amenity.name);
    _descriptionController = TextEditingController(text: widget.amenity.description ?? '');
    _priceController = TextEditingController(
      text: widget.amenity.isFree ? '' : widget.amenity.pricePerDay.toStringAsFixed(0),
    );
    _selectedType = widget.amenity.type;
    _selectedIcon = widget.amenity.iconName ?? 'pool';
    _isFree = widget.amenity.isFree;
    _selectedTimeSlots = List<String>.from(widget.amenity.timeSlots ?? []);
    _selectedBuildingId = widget.amenity.buildingId;
    _selectedBuildingName = widget.amenity.buildingName;
    _loadBuildings();
  }

  void _loadBuildings() {
    _buildingService.getBuildings().listen((buildings) {
      if (mounted) {
        setState(() {
          _buildings = buildings;
        });
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
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
                      'Edit Amenity',
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
                      _selectedBuildingId = value!;
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

                // Type
                DropdownButtonFormField<String>(
                  initialValue: _selectedType,
                  decoration: InputDecoration(
                    labelText: 'Type *',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  items: _types.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(type),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedType = value!;
                    });
                  },
                ),
                const SizedBox(height: 16),

                // Icon
                const Text(
                  'Icon *',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 8),
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
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF2563EB).withOpacity(0.1)
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF2563EB)
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          entry.value,
                          color: isSelected
                              ? const Color(0xFF2563EB)
                              : Colors.grey.shade600,
                          size: 28,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // Free/Paid
                Row(
                  children: [
                    Checkbox(
                      value: _isFree,
                      onChanged: (value) {
                        setState(() {
                          _isFree = value!;
                          if (_isFree) {
                            _priceController.clear();
                          }
                        });
                      },
                      activeColor: const Color(0xFF2563EB),
                    ),
                    const Text(
                      'Free Amenity',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF111111),
                      ),
                    ),
                  ],
                ),

                // Price (if not free)
                if (!_isFree) ...[
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _priceController,
                    decoration: InputDecoration(
                      labelText: 'Price per Day *',
                      prefixText: '₹ ',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (!_isFree && (value == null || value.isEmpty)) {
                        return 'Please enter price';
                      }
                      return null;
                    },
                  ),
                ],
                const SizedBox(height: 16),

                // Time Slots Section
                const Text(
                  'Time Slots',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 8),
                
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
                                    _selectedTimeSlots.addAll(_availableTimeSlots);
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
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFF2563EB) : Colors.white,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFE5E7EB),
                                ),
                              ),
                              child: Text(
                                slot,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: isSelected ? Colors.white : const Color(0xFF374151),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
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
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  maxLines: 3,
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
                            'Update Amenity',
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

    setState(() {
      _isLoading = true;
    });

    try {
      await _amenityService.updateAmenity(widget.amenity.id, {
        'name': _nameController.text.trim(),
        'type': _selectedType,
        'isFree': _isFree,
        'pricePerDay': _isFree ? 0 : double.tryParse(_priceController.text) ?? 0,
        'description': _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        'iconName': _selectedIcon,
        'timeSlots': _selectedTimeSlots.isEmpty ? null : _selectedTimeSlots,
        'buildingId': _selectedBuildingId,
        'buildingName': _selectedBuildingName,
      });

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
