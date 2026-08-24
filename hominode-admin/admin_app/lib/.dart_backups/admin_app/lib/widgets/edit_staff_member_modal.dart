import 'package:flutter/material.dart';
import '../models/staff_models.dart';

class EditStaffMemberModal extends StatefulWidget {
  final StaffMember staffMember;

  const EditStaffMemberModal({
    super.key,
    required this.staffMember,
  });

  @override
  State<EditStaffMemberModal> createState() => _EditStaffMemberModalState();
}

class _EditStaffMemberModalState extends State<EditStaffMemberModal> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _salaryController;
  
  String? selectedRole;
  String? selectedShift;
  bool isLoading = false;

  final List<String> roles = [
    'Security',
    'Housekeeping',
    'Electrician',
    'Plumber',
    'Gardener',
  ];

  final List<String> shifts = [
    'Morning',
    'Evening',
    'Night',
    'Full Day',
  ];

  @override
  void initState() {
    super.initState();
    // Pre-populate with existing data
    _nameController = TextEditingController(text: widget.staffMember.name);
    _phoneController = TextEditingController(text: widget.staffMember.phone);
    _salaryController = TextEditingController(
      text: widget.staffMember.salary.replaceAll(RegExp(r'[₹,/month\s]'), ''),
    );
    selectedRole = widget.staffMember.role;
    selectedShift = widget.staffMember.shift;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _salaryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
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
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              'Edit Staff Member',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF111827),
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Update staff member information',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          child: const Icon(
                            Icons.close,
                            color: Color(0xFF9CA3AF),
                            size: 24,
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Full Name Field
                  const Text(
                    'Full Name',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildTextField(
                    controller: _nameController,
                    hintText: 'Enter name',
                    keyboardType: TextInputType.text,
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Role Field
                  const Text(
                    'Role',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildDropdownField(
                    value: selectedRole,
                    hintText: 'Select role',
                    items: roles,
                    onChanged: (value) {
                      setState(() {
                        selectedRole = value;
                      });
                    },
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Phone Number Field
                  const Text(
                    'Phone Number',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildTextField(
                    controller: _phoneController,
                    hintText: '+91 12345 12345',
                    keyboardType: TextInputType.phone,
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Shift Field
                  const Text(
                    'Shift',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildDropdownField(
                    value: selectedShift,
                    hintText: 'Select slot',
                    items: shifts,
                    onChanged: (value) {
                      setState(() {
                        selectedShift = value;
                      });
                    },
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Monthly Salary Field
                  const Text(
                    'Monthly Salary',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildTextField(
                    controller: _salaryController,
                    hintText: '15000',
                    keyboardType: TextInputType.number,
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Update Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: isLoading ? null : _handleUpdateStaff,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        disabledBackgroundColor: const Color(0xFF2563EB).withOpacity(0.6),
                      ),
                      child: isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text(
                              'Update Staff',
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
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required TextInputType keyboardType,
  }) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        style: const TextStyle(
          fontSize: 15,
          color: Color(0xFF111827),
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(
            fontSize: 15,
            color: Color(0xFF9CA3AF),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'This field is required';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildDropdownField({
    required String? value,
    required String hintText,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(
            fontSize: 15,
            color: Color(0xFF9CA3AF),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
        style: const TextStyle(
          fontSize: 15,
          color: Color(0xFF111827),
        ),
        icon: const Icon(
          Icons.keyboard_arrow_down,
          color: Color(0xFF9CA3AF),
        ),
        items: items.map((String item) {
          return DropdownMenuItem<String>(
            value: item,
            child: Text(item),
          );
        }).toList(),
      ),
    );
  }

  Future<void> _handleUpdateStaff() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      isLoading = true;
    });

    // TODO: Implement API call to update staff member
    await Future.delayed(const Duration(seconds: 2));

    setState(() {
      isLoading = false;
    });

    Navigator.of(context).pop(true);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Staff member updated successfully'),
        backgroundColor: Color(0xFF16A34A),
      ),
    );
  }
}