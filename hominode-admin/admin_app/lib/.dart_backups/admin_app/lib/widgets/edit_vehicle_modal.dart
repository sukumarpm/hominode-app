import 'package:flutter/material.dart';
import '../parking_management_vehicles_screen.dart';

/// EditVehicleModal - Modal for editing vehicle details
/// 
/// This modal opens when admin clicks "Edit Vehicle" from vehicle action menu
/// Features:
/// - Pre-filled form with existing vehicle data
/// - Form validation for required fields
/// - Dropdown for vehicle type selection
/// - Owner/resident selection
/// - Save changes functionality
class EditVehicleModal extends StatefulWidget {
  final VehicleEntry vehicle;
  final Function(VehicleEntry) onSave;

  const EditVehicleModal({
    super.key,
    required this.vehicle,
    required this.onSave,
  });

  @override
  State<EditVehicleModal> createState() => _EditVehicleModalState();
}

class _EditVehicleModalState extends State<EditVehicleModal> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _vehicleNumberController;
  late TextEditingController _modelController;
  late TextEditingController _ownerNameController;
  late TextEditingController _flatNumberController;
  
  String? _selectedVehicleType;
  bool _isFormValid = false;

  // Sample data - TODO: Replace with actual API data
  final List<String> _vehicleTypes = ['Car', 'Bike'];
  final List<String> _residents = [
    'Rajesh Kumar',
    'Priya Sharma', 
    'Amit Singh',
    'Neha Gupta',
    'Rohit Verma',
    'Kavya Patel',
  ];
  final List<String> _flats = [
    'A-101', 'A-102', 'A-103', 'A-104', 'A-105',
    'A-201', 'A-202', 'A-203', 'A-204', 'A-205',
    'B-101', 'B-102', 'B-103', 'B-104', 'B-105',
    'C-301', 'C-302', 'C-303', 'C-304', 'C-305',
  ];

  @override
  void initState() {
    super.initState();
    // Pre-fill form with existing vehicle data
    _vehicleNumberController = TextEditingController(text: widget.vehicle.vehicleNumber);
    _modelController = TextEditingController(text: widget.vehicle.model);
    _ownerNameController = TextEditingController(text: widget.vehicle.ownerName);
    _flatNumberController = TextEditingController(text: widget.vehicle.flatNumber);
    _selectedVehicleType = widget.vehicle.vehicleType;
    
    // Listen to form changes
    _vehicleNumberController.addListener(_validateForm);
    _modelController.addListener(_validateForm);
    _ownerNameController.addListener(_validateForm);
    _flatNumberController.addListener(_validateForm);
    
    // Initial validation
    _validateForm();
  }

  @override
  void dispose() {
    _vehicleNumberController.dispose();
    _modelController.dispose();
    _ownerNameController.dispose();
    _flatNumberController.dispose();
    super.dispose();
  }

  /// Validates form and updates save button state
  void _validateForm() {
    final isValid = _vehicleNumberController.text.trim().isNotEmpty &&
        _modelController.text.trim().isNotEmpty &&
        _ownerNameController.text.trim().isNotEmpty &&
        _flatNumberController.text.trim().isNotEmpty &&
        _selectedVehicleType != null;
    
    if (isValid != _isFormValid) {
      setState(() {
        _isFormValid = isValid;
      });
    }
  }

  /// Handles form submission
  void _onSaveChanges() {
    if (!_isFormValid) return;

    final updatedVehicle = widget.vehicle.copyWith(
      vehicleNumber: _vehicleNumberController.text.trim(),
      vehicleType: _selectedVehicleType!,
      model: _modelController.text.trim(),
      ownerName: _ownerNameController.text.trim(),
      flatNumber: _flatNumberController.text.trim(),
    );

    widget.onSave(updatedVehicle);
    Navigator.of(context).pop();
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Vehicle details updated successfully'),
        backgroundColor: Color(0xFF16A34A),
      ),
    );
  }

  /// Handles modal dismissal
  void _onClose() {
    Navigator.of(context).pop();
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
                  _buildVehicleNumberField(),
                  const SizedBox(height: 20),
                  
                  _buildVehicleTypeDropdown(),
                  const SizedBox(height: 20),
                  
                  _buildModelField(),
                  const SizedBox(height: 20),
                  
                  _buildOwnerNameField(),
                  const SizedBox(height: 20),
                  
                  _buildFlatNumberField(),
                  const SizedBox(height: 32),
                  
                  // Action Buttons
                  _buildActionButtons(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Builds the modal header with title and close button
  Widget _buildHeader() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                'Edit Vehicle Details',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Update vehicle information',
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
            child: const Icon(
              Icons.close,
              size: 18,
              color: Color(0xFF6B7280),
            ),
          ),
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
              borderSide: const BorderSide(
                color: Color(0xFFE5E7EB),
                width: 1,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFFE5E7EB),
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFF2563EB),
                width: 2,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
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
            hintText: 'Select vehicle type',
            hintStyle: const TextStyle(
              fontSize: 15,
              color: Color(0xFF9CA3AF),
              fontWeight: FontWeight.w400,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFFE5E7EB),
                width: 1,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFFE5E7EB),
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFF2563EB),
                width: 2,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
          icon: const Icon(
            Icons.keyboard_arrow_down,
            color: Color(0xFF6B7280),
          ),
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: Color(0xFF111827),
          ),
          items: _vehicleTypes.map((String type) {
            return DropdownMenuItem<String>(
              value: type,
              child: Text(type),
            );
          }).toList(),
          onChanged: (String? newValue) {
            setState(() {
              _selectedVehicleType = newValue;
            });
            _validateForm();
          },
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
          'Vehicle Model',
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
            hintText: 'Honda City',
            hintStyle: const TextStyle(
              fontSize: 15,
              color: Color(0xFF9CA3AF),
              fontWeight: FontWeight.w400,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFFE5E7EB),
                width: 1,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFFE5E7EB),
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFF2563EB),
                width: 2,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
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

  /// Builds owner name input field
  Widget _buildOwnerNameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Owner Name',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _ownerNameController,
          decoration: InputDecoration(
            hintText: 'Enter owner name',
            hintStyle: const TextStyle(
              fontSize: 15,
              color: Color(0xFF9CA3AF),
              fontWeight: FontWeight.w400,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFFE5E7EB),
                width: 1,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFFE5E7EB),
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFF2563EB),
                width: 2,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
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

  /// Builds flat number input field
  Widget _buildFlatNumberField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Flat Number',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _flatNumberController,
          decoration: InputDecoration(
            hintText: 'A-204',
            hintStyle: const TextStyle(
              fontSize: 15,
              color: Color(0xFF9CA3AF),
              fontWeight: FontWeight.w400,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFFE5E7EB),
                width: 1,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFFE5E7EB),
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFF2563EB),
                width: 2,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
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

  /// Builds action buttons (Cancel and Save)
  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _onClose,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFE5E7EB)),
              backgroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Cancel',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6B7280),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: _isFormValid ? _onSaveChanges : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: _isFormValid 
                  ? const Color(0xFF2563EB) 
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
              'Save Changes',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

