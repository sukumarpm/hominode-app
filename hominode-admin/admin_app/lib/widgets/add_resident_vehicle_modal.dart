import 'package:flutter/material.dart';

/// AddResidentVehicleModal - Center-aligned overlay modal for adding resident vehicles
///
/// This modal opens when admin clicks "Add Vehicle" from Parking Management / Vehicles screen
/// Features:
/// - Center-aligned modal overlay with dimmed background
/// - Form validation for required fields
/// - Dropdown selections for resident and vehicle type
/// - Consistent design system matching app theme
class AddResidentVehicleModal extends StatefulWidget {
  const AddResidentVehicleModal({super.key});

  @override
  State<AddResidentVehicleModal> createState() =>
      _AddResidentVehicleModalState();
}

class _AddResidentVehicleModalState extends State<AddResidentVehicleModal> {
  final _formKey = GlobalKey<FormState>();
  final _vehicleNumberController = TextEditingController();
  final _modelController = TextEditingController();

  String? _selectedResident;
  String? _selectedVehicleType;
  String? _selectedParkingSlot;
  bool _isFormValid = false;

  // Sample data - TODO: Replace with actual API data
  final List<ResidentOption> _residents = [
    ResidentOption(id: '1', name: 'Rajesh Kumar', unit: 'A-204'),
    ResidentOption(id: '2', name: 'Priya Sharma', unit: 'B-102'),
    ResidentOption(id: '3', name: 'Amit Singh', unit: 'C-301'),
    ResidentOption(id: '4', name: 'Neha Gupta', unit: 'A-105'),
    ResidentOption(id: '5', name: 'Rohit Verma', unit: 'B-205'),
    ResidentOption(id: '6', name: 'Kavya Patel', unit: 'C-103'),
  ];

  final List<String> _vehicleTypes = [
    'Two Wheeler',
    'Four Wheeler',
    'Electric Vehicle',
    'Guest Vehicle',
  ];

  final List<ParkingSlotOption> _availableParkingSlots = [
    ParkingSlotOption(
      id: 'A1',
      slotNumber: 'A-1',
      type: 'Car',
      isAvailable: true,
    ),
    ParkingSlotOption(
      id: 'A2',
      slotNumber: 'A-2',
      type: 'Car',
      isAvailable: true,
    ),
    ParkingSlotOption(
      id: 'A3',
      slotNumber: 'A-3',
      type: 'Car',
      isAvailable: true,
    ),
    ParkingSlotOption(
      id: 'B1',
      slotNumber: 'B-1',
      type: 'Bike',
      isAvailable: true,
    ),
    ParkingSlotOption(
      id: 'B2',
      slotNumber: 'B-2',
      type: 'Bike',
      isAvailable: true,
    ),
    ParkingSlotOption(
      id: 'B3',
      slotNumber: 'B-3',
      type: 'Bike',
      isAvailable: true,
    ),
    ParkingSlotOption(
      id: 'C1',
      slotNumber: 'C-1',
      type: 'Car',
      isAvailable: true,
    ),
    ParkingSlotOption(
      id: 'C2',
      slotNumber: 'C-2',
      type: 'Car',
      isAvailable: true,
    ),
  ];

  @override
  void initState() {
    super.initState();
    // Listen to form changes to validate in real-time
    _vehicleNumberController.addListener(_validateForm);
    _modelController.addListener(_validateForm);
  }

  @override
  void dispose() {
    _vehicleNumberController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  /// Validates form and updates button state
  void _validateForm() {
    final isValid =
        _selectedResident != null &&
        _selectedVehicleType != null &&
        _vehicleNumberController.text.trim().isNotEmpty &&
        _modelController.text.trim().isNotEmpty &&
        _selectedParkingSlot != null;

    if (isValid != _isFormValid) {
      setState(() {
        _isFormValid = isValid;
      });
    }
  }

  /// Handles form submission
  void _onAddVehicle() {
    if (!_isFormValid) return;

    // TODO: Implement API call to add vehicle
    // Example API call structure:
    // final vehicleData = {
    //   'residentId': _selectedResident,
    //   'vehicleType': _selectedVehicleType,
    //   'vehicleNumber': _vehicleNumberController.text.trim(),
    //   'model': _modelController.text.trim(),
    //   'parkingSlotId': _selectedParkingSlot,
    //   'registeredAt': DateTime.now().toIso8601String(),
    // };
    //
    // try {
    //   await VehicleService.addResidentVehicle(vehicleData);
    //   Navigator.of(context).pop(true); // Return success
    // } catch (error) {
    //   // Handle error
    // }

    // For now, simulate success
    Navigator.of(context).pop(true);

    // Show success message in parent screen
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Vehicle ${_vehicleNumberController.text} added successfully',
        ),
        backgroundColor: const Color(0xFF16A34A),
      ),
    );
  }

  /// Handles modal dismissal
  void _onClose() {
    Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(maxWidth: 400),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFFFF),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
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
                  // Header Section
                  _buildHeader(),
                  const SizedBox(height: 24),

                  // Form Fields
                  _buildResidentDropdown(),
                  const SizedBox(height: 20),

                  _buildVehicleTypeDropdown(),
                  const SizedBox(height: 20),

                  _buildVehicleNumberField(),
                  const SizedBox(height: 20),

                  _buildModelField(),
                  const SizedBox(height: 20),

                  _buildParkingSlotDropdown(),
                  const SizedBox(height: 32),

                  // Action Button
                  _buildAddButton(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Builds the modal header with title, subtitle and close button
  Widget _buildHeader() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                'Add Resident Vehicle',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Register a new resident vehicle',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF6B7280),
                ),
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: _onClose,
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.close, size: 18, color: Color(0xFF6B7280)),
          ),
        ),
      ],
    );
  }

  /// Builds resident/unit dropdown field
  Widget _buildResidentDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Resident / Unit',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _selectedResident,
          decoration: InputDecoration(
            hintText: 'Select resident',
            hintStyle: const TextStyle(
              fontSize: 15,
              color: Color(0xFF9CA3AF),
              fontWeight: FontWeight.w400,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFD1D5DB), width: 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFD1D5DB), width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF0E4778), width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            filled: true,
            fillColor: const Color(0xFFFFFFFF),
          ),
          icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF6B7280)),
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: Color(0xFF111827),
          ),
          isExpanded: true,
          items: _residents.map((ResidentOption resident) {
            return DropdownMenuItem<String>(
              value: resident.id,
              child: Text('${resident.name} – ${resident.unit}'),
            );
          }).toList(),
          onChanged: (String? newValue) {
            setState(() {
              _selectedResident = newValue;
            });
            _validateForm();
          },
        ),
      ],
    );
  }

  /// Builds vehicle type dropdown field
  Widget _buildVehicleTypeDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Vehicle Type',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _selectedVehicleType,
          decoration: InputDecoration(
            hintText: 'Select type',
            hintStyle: const TextStyle(
              fontSize: 15,
              color: Color(0xFF9CA3AF),
              fontWeight: FontWeight.w400,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFD1D5DB), width: 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFD1D5DB), width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF0E4778), width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            filled: true,
            fillColor: const Color(0xFFFFFFFF),
          ),
          icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF6B7280)),
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: Color(0xFF111827),
          ),
          isExpanded: true,
          items: _vehicleTypes.map((String type) {
            return DropdownMenuItem<String>(value: type, child: Text(type));
          }).toList(),
          onChanged: (String? newValue) {
            setState(() {
              _selectedVehicleType = newValue;
              // Reset parking slot when vehicle type changes
              _selectedParkingSlot = null;
            });
            _validateForm();
          },
        ),
      ],
    );
  }

  /// Builds vehicle number input field
  Widget _buildVehicleNumberField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Vehicle Number',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _vehicleNumberController,
          decoration: InputDecoration(
            hintText: 'DL 01 AB 1234',
            hintStyle: const TextStyle(
              fontSize: 15,
              color: Color(0xFF9CA3AF),
              fontWeight: FontWeight.w400,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFD1D5DB), width: 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFD1D5DB), width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF0E4778), width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            filled: true,
            fillColor: const Color(0xFFFFFFFF),
          ),
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: Color(0xFF111827),
          ),
          textCapitalization: TextCapitalization.characters,
        ),
      ],
    );
  }

  /// Builds model input field
  Widget _buildModelField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Model',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _modelController,
          decoration: InputDecoration(
            hintText: 'e.g., Honda City',
            hintStyle: const TextStyle(
              fontSize: 15,
              color: Color(0xFF9CA3AF),
              fontWeight: FontWeight.w400,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFD1D5DB), width: 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFD1D5DB), width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF0E4778), width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            filled: true,
            fillColor: const Color(0xFFFFFFFF),
          ),
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: Color(0xFF111827),
          ),
        ),
      ],
    );
  }

  /// Builds parking slot dropdown field
  Widget _buildParkingSlotDropdown() {
    // Filter slots based on selected vehicle type
    List<ParkingSlotOption> filteredSlots = _availableParkingSlots.where((
      slot,
    ) {
      if (_selectedVehicleType == null) return true;

      // Match vehicle type to slot type
      if (_selectedVehicleType == 'Two Wheeler' && slot.type == 'Bike') {
        return true;
      }
      if ((_selectedVehicleType == 'Four Wheeler' ||
              _selectedVehicleType == 'Electric Vehicle' ||
              _selectedVehicleType == 'Guest Vehicle') &&
          slot.type == 'Car') {
        return true;
      }

      return false;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Parking Slot',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _selectedParkingSlot,
          decoration: InputDecoration(
            hintText: _selectedVehicleType == null
                ? 'Select vehicle type first'
                : 'Select parking slot',
            hintStyle: const TextStyle(
              fontSize: 15,
              color: Color(0xFF9CA3AF),
              fontWeight: FontWeight.w400,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFD1D5DB), width: 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFD1D5DB), width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF0E4778), width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            filled: true,
            fillColor: const Color(0xFFFFFFFF),
          ),
          icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF6B7280)),
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: Color(0xFF111827),
          ),
          isExpanded: true,
          items: filteredSlots.map((ParkingSlotOption slot) {
            return DropdownMenuItem<String>(
              value: slot.id,
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: slot.type == 'Car'
                          ? const Color(0xFFDCFDF7)
                          : const Color(0xFFF3E8FF),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      slot.type == 'Car'
                          ? Icons.directions_car_rounded
                          : Icons.two_wheeler_rounded,
                      size: 16,
                      color: slot.type == 'Car'
                          ? const Color(0xFF059669)
                          : const Color(0xFF7C3AED),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text('${slot.slotNumber} (${slot.type})')),
                  if (slot.isAvailable)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Available',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF059669),
                        ),
                      ),
                    ),
                ],
              ),
            );
          }).toList(),
          onChanged: _selectedVehicleType == null
              ? null
              : (String? newValue) {
                  setState(() {
                    _selectedParkingSlot = newValue;
                  });
                  _validateForm();
                },
        ),
        if (_selectedVehicleType != null && filteredSlots.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'No available slots for ${_selectedVehicleType?.toLowerCase()}',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFFEF4444),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }

  /// Builds the primary action button
  Widget _buildAddButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isFormValid ? _onAddVehicle : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: _isFormValid
              ? const Color(0xFF0E4778)
              : const Color(0xFFE5E7EB),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
          disabledBackgroundColor: const Color(0xFFE5E7EB),
          disabledForegroundColor: const Color(0xFF9CA3AF),
        ),
        child: const Text(
          'Add Vehicle',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

/// Resident Option Data Model
///
/// Represents a resident with their unit for dropdown selection
class ResidentOption {
  final String id;
  final String name;
  final String unit;

  ResidentOption({required this.id, required this.name, required this.unit});
}

/// Parking Slot Option Data Model
///
/// Represents an available parking slot for dropdown selection
class ParkingSlotOption {
  final String id;
  final String slotNumber;
  final String type; // 'Car' or 'Bike'
  final bool isAvailable;

  ParkingSlotOption({
    required this.id,
    required this.slotNumber,
    required this.type,
    required this.isAvailable,
  });
}

/// Utility function to show the AddResidentVehicleModal
///
/// Usage:
/// ```dart
/// final result = await showAddResidentVehicleModal(context);
/// if (result == true) {
///   // Handle successful vehicle addition
///   // Refresh vehicle list or update UI
/// }
/// ```
Future<bool?> showAddResidentVehicleModal(BuildContext context) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black.withOpacity(0.4),
    builder: (BuildContext context) {
      return const AddResidentVehicleModal();
    },
  );
}
