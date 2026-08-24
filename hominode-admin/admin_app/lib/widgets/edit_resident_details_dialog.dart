/// Edit Resident Details Dialog
///
/// A centered overlay modal for editing resident information.
/// Matches the admin app visual system with blue theme and rounded cards.
///
/// Usage:
/// ```dart
/// EditResidentDetailsDialog.show(
///   context,
///   resident: resident,
///   onSaved: (updated) {
///     setState(() {
///       residents[index] = updated;
///     });
///     ScaffoldMessenger.of(context).showSnackBar(
///       SnackBar(content: Text('Resident details updated')),
///     );
///   },
/// );
/// ```
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ============================================================================
// RESIDENT MODEL (Simplified for Edit Dialog)
// ============================================================================

class EditableResident {
  final String id;
  String fullName;
  String unitNumber;
  String phoneNumber;
  int familyMembers;
  int vehicles;

  EditableResident({
    required this.id,
    required this.fullName,
    required this.unitNumber,
    required this.phoneNumber,
    required this.familyMembers,
    required this.vehicles,
  });

  // TODO: Connect to backend API
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fullName': fullName,
      'unitNumber': unitNumber,
      'phoneNumber': phoneNumber,
      'familyMembers': familyMembers,
      'vehicles': vehicles,
    };
  }

  factory EditableResident.fromJson(Map<String, dynamic> json) {
    return EditableResident(
      id: json['id'] as String,
      fullName: json['fullName'] as String,
      unitNumber: json['unitNumber'] as String,
      phoneNumber: json['phoneNumber'] as String,
      familyMembers: json['familyMembers'] as int? ?? 0,
      vehicles: json['vehicles'] as int? ?? 0,
    );
  }

  EditableResident copyWith({
    String? id,
    String? fullName,
    String? unitNumber,
    String? phoneNumber,
    int? familyMembers,
    int? vehicles,
  }) {
    return EditableResident(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      unitNumber: unitNumber ?? this.unitNumber,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      familyMembers: familyMembers ?? this.familyMembers,
      vehicles: vehicles ?? this.vehicles,
    );
  }
}

// ============================================================================
// EDIT RESIDENT DETAILS DIALOG
// ============================================================================

class EditResidentDetailsDialog extends StatefulWidget {
  final EditableResident resident;
  final ValueChanged<EditableResident> onSaved;

  const EditResidentDetailsDialog({
    super.key,
    required this.resident,
    required this.onSaved,
  });

  /// Show the dialog with fade and scale animation
  static Future<void> show(
    BuildContext context, {
    required EditableResident resident,
    required ValueChanged<EditableResident> onSaved,
  }) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close',
      barrierColor: const Color(0x59000000), // rgba(0, 0, 0, 0.35)
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, animation, secondaryAnimation) {
        return EditResidentDetailsDialog(resident: resident, onSaved: onSaved);
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOut),
            ),
            child: child,
          ),
        );
      },
    );
  }

  @override
  State<EditResidentDetailsDialog> createState() =>
      _EditResidentDetailsDialogState();
}

class _EditResidentDetailsDialogState extends State<EditResidentDetailsDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _fullNameController;
  late final TextEditingController _unitNumberController;
  late final TextEditingController _phoneController;
  late final TextEditingController _familyMembersController;
  late final TextEditingController _vehiclesController;

  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Pre-fill with existing data
    _fullNameController = TextEditingController(text: widget.resident.fullName);
    _unitNumberController = TextEditingController(
      text: widget.resident.unitNumber,
    );
    _phoneController = TextEditingController(text: widget.resident.phoneNumber);
    _familyMembersController = TextEditingController(
      text: widget.resident.familyMembers.toString(),
    );
    _vehiclesController = TextEditingController(
      text: widget.resident.vehicles.toString(),
    );
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _unitNumberController.dispose();
    _phoneController.dispose();
    _familyMembersController.dispose();
    _vehiclesController.dispose();
    super.dispose();
  }

  bool get _isFormValid {
    // Full name required, min 2 chars
    if (_fullNameController.text.trim().isEmpty ||
        _fullNameController.text.trim().length < 2) {
      return false;
    }

    // Unit number required
    if (_unitNumberController.text.trim().isEmpty) {
      return false;
    }

    // Phone required, min 10 digits
    final phone = _phoneController.text.trim().replaceAll(RegExp(r'[^\d]'), '');
    if (phone.length < 10) {
      return false;
    }

    // Family members must be valid integer >= 0
    final familyMembers = int.tryParse(_familyMembersController.text.trim());
    if (familyMembers == null || familyMembers < 0) {
      return false;
    }

    // Vehicles must be valid integer >= 0
    final vehicles = int.tryParse(_vehiclesController.text.trim());
    if (vehicles == null || vehicles < 0) {
      return false;
    }

    return true;
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!_isFormValid) {
      setState(() {
        _errorMessage = 'Please fill in all required fields correctly';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      // Simulate API call
      // TODO: Replace with real API call (PUT /residents/{id})
      await Future.delayed(const Duration(milliseconds: 800));

      final updatedResident = widget.resident.copyWith(
        fullName: _fullNameController.text.trim(),
        unitNumber: _unitNumberController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        familyMembers: int.parse(_familyMembersController.text.trim()),
        vehicles: int.parse(_vehiclesController.text.trim()),
      );

      // TODO: Add audit logging (who updated resident)

      if (mounted) {
        widget.onSaved(updatedResident);
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() {
        _isSaving = false;
        _errorMessage = 'Unable to save changes. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final keyboardInsets = MediaQuery.of(context).viewInsets;

    return Center(
      child: Container(
        constraints: BoxConstraints(
          maxWidth: screenWidth > 720 ? 720 : screenWidth * 0.92,
          maxHeight: screenHeight * 0.80,
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          elevation: 8,
          shadowColor: Colors.black.withOpacity(0.15),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(),
              Flexible(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.only(
                    bottom: keyboardInsets.bottom > 0
                        ? keyboardInsets.bottom + 12
                        : 20,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                    child: Form(
                      key: _formKey,
                      onChanged: () => setState(() {}),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_errorMessage != null) ...[
                            const SizedBox(height: 12),
                            _buildErrorBanner(),
                          ],
                          const SizedBox(height: 18),
                          _buildFullNameField(),
                          const SizedBox(height: 16),
                          _buildUnitNumberField(),
                          const SizedBox(height: 16),
                          _buildPhoneField(),
                          const SizedBox(height: 16),
                          _buildFamilyAndVehiclesRow(),
                          const SizedBox(height: 20),
                          _buildSaveButton(),
                          const SizedBox(height: 10),
                          _buildCancelButton(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 40),
            child: Column(
              children: [
                const Text(
                  'Edit Resident Details',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111111),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Update information for ${widget.resident.fullName}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: -6,
            right: -6,
            child: Semantics(
              label: 'Close',
              button: true,
              child: InkWell(
                onTap: () => Navigator.of(context).pop(),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.close,
                    color: Color(0xFF9CA3AF),
                    size: 22,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _errorMessage!,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFFDC2626),
              ),
            ),
          ),
          InkWell(
            onTap: () => setState(() => _errorMessage = null),
            child: const Icon(Icons.close, color: Color(0xFFDC2626), size: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildFullNameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            Text(
              'Full Name',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF111111),
              ),
            ),
            SizedBox(width: 4),
            Text(
              '*',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFFDC2626),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _fullNameController,
          textInputAction: TextInputAction.next,
          style: const TextStyle(fontSize: 15, color: Color(0xFF111111)),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE6E9EC)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE6E9EC)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF0E4778), width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFDC2626)),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFDC2626), width: 2),
            ),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Full name is required';
            }
            if (value.trim().length < 2) {
              return 'Name must be at least 2 characters';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildUnitNumberField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            Text(
              'Unit Number',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF111111),
              ),
            ),
            SizedBox(width: 4),
            Text(
              '*',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFFDC2626),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _unitNumberController,
          textInputAction: TextInputAction.next,
          style: const TextStyle(fontSize: 15, color: Color(0xFF111111)),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE6E9EC)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE6E9EC)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF0E4778), width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFDC2626)),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFDC2626), width: 2),
            ),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Unit number is required';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildPhoneField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            Text(
              'Phone Number',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF111111),
              ),
            ),
            SizedBox(width: 4),
            Text(
              '*',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFFDC2626),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.next,
          style: const TextStyle(fontSize: 15, color: Color(0xFF111111)),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE6E9EC)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE6E9EC)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF0E4778), width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFDC2626)),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFDC2626), width: 2),
            ),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Phone number is required';
            }
            final phone = value.trim().replaceAll(RegExp(r'[^\d]'), '');
            if (phone.length < 10) {
              return 'Phone number must be at least 10 digits';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildFamilyAndVehiclesRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Family Members',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF111111),
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _familyMembersController,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(fontSize: 15, color: Color(0xFF111111)),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE6E9EC)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE6E9EC)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFF0E4778),
                      width: 2,
                    ),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFDC2626)),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFFDC2626),
                      width: 2,
                    ),
                  ),
                ),
                validator: (value) {
                  if (value != null && value.trim().isNotEmpty) {
                    final number = int.tryParse(value.trim());
                    if (number == null || number < 0) {
                      return 'Must be 0 or more';
                    }
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Vehicles',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF111111),
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _vehiclesController,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(fontSize: 15, color: Color(0xFF111111)),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE6E9EC)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE6E9EC)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFF0E4778),
                      width: 2,
                    ),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFDC2626)),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFFDC2626),
                      width: 2,
                    ),
                  ),
                ),
                validator: (value) {
                  if (value != null && value.trim().isNotEmpty) {
                    final number = int.tryParse(value.trim());
                    if (number == null || number < 0) {
                      return 'Must be 0 or more';
                    }
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    final isEnabled = _isFormValid && !_isSaving;

    return Semantics(
      label: 'Save changes',
      button: true,
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton(
          onPressed: isEnabled ? _handleSave : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0E4778),
            disabledBackgroundColor: const Color(0x662563EB), // 40% opacity
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: _isSaving
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text(
                  'Save Changes',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                ),
        ),
      ),
    );
  }

  Widget _buildCancelButton() {
    return Semantics(
      label: 'Cancel',
      button: true,
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: OutlinedButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          style: OutlinedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF111111),
            side: const BorderSide(color: Color(0xFFE5E7EB)),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: const Text(
            'Cancel',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}
