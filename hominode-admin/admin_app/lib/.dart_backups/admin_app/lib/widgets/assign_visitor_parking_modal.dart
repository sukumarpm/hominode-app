import 'package:flutter/material.dart';

/// AssignVisitorParkingModal - Center-aligned overlay modal for assigning parking slots to visitors
/// 
/// This modal opens when admin clicks "Assign Visitor Parking" from Parking Management / Visitor screen
/// Features:
/// - Center-aligned modal overlay with dimmed background
/// - Form validation for required fields
/// - Dropdown selections for unit and parking slot
/// - Consistent design system matching app theme
class AssignVisitorParkingModal extends StatefulWidget {
  const AssignVisitorParkingModal({super.key});

  @override
  State<AssignVisitorParkingModal> createState() => _AssignVisitorParkingModalState();
}

class _AssignVisitorParkingModalState extends State<AssignVisitorParkingModal> {
  final _formKey = GlobalKey<FormState>();
  final _visitorNameController = TextEditingController();
  final _vehicleNumberController = TextEditingController();
  
  String? _selectedUnit;
  String? _selectedParkingSlot;
  bool _isFormValid = false;

  // Sample data - TODO: Replace with actual API data
  final List<String> _units = [
    'A-101', 'A-102', 'A-103', 'A-201', 'A-202', 'A-203',
    'B-101', 'B-102', 'B-103', 'B-201', 'B-202', 'B-203',
    'C-101', 'C-102', 'C-103', 'C-201', 'C-202', 'C-203',
  ];

  final List<String> _availableParkingSlots = [
    'V1', 'V2', 'V3', 'V4', 'V5', 'V6', 'V7', 'V8',
  ];

  @override
  void initState() {
    super.initState();
    // Listen to form changes to validate in real-time
    _visitorNameController.addListener(_validateForm);
    _vehicleNumberController.addListener(_validateForm);
  }

  @override
  void dispose() {
    _visitorNameController.dispose();
    _vehicleNumberController.dispose();
    super.dispose();
  }

  /// Validates form and updates button state
  void _validateForm() {
    final isValid = _visitorNameController.text.trim().isNotEmpty &&
        _vehicleNumberController.text.trim().isNotEmpty &&
        _selectedUnit != null &&
        _selectedParkingSlot != null;
    
    if (isValid != _isFormValid) {
      setState(() {
        _isFormValid = isValid;
      });
    }
  }

  /// Handles form submission
  void _onAssignSlot() {
    if (!_isFormValid) return;

    // TODO: Implement API call to assign parking slot
    // Example API call structure:
    // final assignmentData = {
    //   'visitorName': _visitorNameController.text.trim(),
    //   'vehicleNumber': _vehicleNumberController.text.trim(),
    //   'visitingUnit': _selectedUnit,
    //   'parkingSlot': _selectedParkingSlot,
    //   'assignedAt': DateTime.now().toIso8601String(),
    // };
    // 
    // try {
    //   await ParkingService.assignVisitorParking(assignmentData);
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
          'Parking slot $_selectedParkingSlot assigned to ${_visitorNameController.text}',
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
                  _buildVisitorNameField(),
                  const SizedBox(height: 20),
                  
                  _buildVehicleNumberField(),
                  const SizedBox(height: 20),
                  
                  _buildVisitingUnitDropdown(),
                  const SizedBox(height: 20),
                  
                  _buildParkingSlotDropdown(),
                  const SizedBox(height: 32),
                  
                  // Action Button
                  _buildAssignButton(),
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
                'Assign Visitor Parking',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Assign a parking slot to a visitor',
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

  /// Builds visitor name input field
  Widget _buildVisitorNameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Visitor Name',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _visitorNameController,
          decoration: InputDecoration(
            hintText: 'Enter visitor name',
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

  /// Builds visiting unit dropdown field
  Widget _buildVisitingUnitDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Visiting Unit',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _selectedUnit,
          decoration: InputDecoration(
            hintText: 'Select unit',
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
          items: _units.map((String unit) {
            return DropdownMenuItem<String>(
              value: unit,
              child: Text(unit),
            );
          }).toList(),
          onChanged: (String? newValue) {
            setState(() {
              _selectedUnit = newValue;
            });
            _validateForm();
          },
        ),
      ],
    );
  }

  /// Builds parking slot dropdown field
  Widget _buildParkingSlotDropdown() {
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
            hintText: 'Select slot',
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
          items: _availableParkingSlots.map((String slot) {
            return DropdownMenuItem<String>(
              value: slot,
              child: Text(slot),
            );
          }).toList(),
          onChanged: (String? newValue) {
            setState(() {
              _selectedParkingSlot = newValue;
            });
            _validateForm();
          },
        ),
      ],
    );
  }

  /// Builds the primary action button
  Widget _buildAssignButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isFormValid ? _onAssignSlot : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: _isFormValid 
              ? const Color(0xFF2563EB) 
              : const Color(0xFFE5E7EB),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
          disabledBackgroundColor: const Color(0xFFE5E7EB),
          disabledForegroundColor: const Color(0xFF9CA3AF),
        ),
        child: const Text(
          'Assign Slot',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// Utility function to show the AssignVisitorParkingModal
/// 
/// Usage:
/// ```dart
/// final result = await showAssignVisitorParkingModal(context);
/// if (result == true) {
///   // Handle successful assignment
///   // Refresh parking list or update UI
/// }
/// ```
Future<bool?> showAssignVisitorParkingModal(BuildContext context) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black.withOpacity(0.4),
    builder: (BuildContext context) {
      return const AssignVisitorParkingModal();
    },
  );
}