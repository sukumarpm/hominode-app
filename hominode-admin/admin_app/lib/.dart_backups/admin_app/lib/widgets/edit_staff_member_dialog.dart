import 'package:flutter/material.dart';
import '../services/staff_vendor_service.dart';

class EditStaffMemberDialog extends StatefulWidget {
  final StaffMember staff;

  const EditStaffMemberDialog({
    super.key,
    required this.staff,
  });

  @override
  State<EditStaffMemberDialog> createState() => _EditStaffMemberDialogState();
}

class _EditStaffMemberDialogState extends State<EditStaffMemberDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _salaryController;
  late TextEditingController _emailController;
  late TextEditingController _addressController;
  final StaffVendorService _service = StaffVendorService();
  
  String? selectedRole;
  DateTime? joiningDate;
  bool isLoading = false;

  final List<String> roles = [
    'Security',
    'Housekeeping',
    'Electrician',
    'Plumber',
    'Gardener',
    'Maintenance',
    'Supervisor',
  ];

  @override
  void initState() {
    super.initState();
    // Pre-populate with existing data
    _nameController = TextEditingController(text: widget.staff.name);
    _phoneController = TextEditingController(text: widget.staff.phone);
    _salaryController = TextEditingController(
      text: widget.staff.salary != null ? widget.staff.salary!.toStringAsFixed(0) : '',
    );
    _emailController = TextEditingController(text: widget.staff.email ?? '');
    _addressController = TextEditingController(text: widget.staff.address ?? '');
    selectedRole = widget.staff.role;
    joiningDate = widget.staff.joiningDate;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _salaryController.dispose();
    _emailController.dispose();
    _addressController.dispose();
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
          maxHeight: MediaQuery.of(context).size.height * 0.85,
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
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
            ),
            
            // Scrollable Form Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter full name';
                          }
                          return null;
                        },
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
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter phone number';
                          }
                          return null;
                        },
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Email Field (Optional)
                      const Text(
                        'Email (Optional)',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildTextField(
                        controller: _emailController,
                        hintText: 'staff@example.com',
                        keyboardType: TextInputType.emailAddress,
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Address Field (Optional)
                      const Text(
                        'Address (Optional)',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildTextField(
                        controller: _addressController,
                        hintText: 'Residential address',
                        keyboardType: TextInputType.streetAddress,
                        maxLines: 2,
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Joining Date
                      const Text(
                        'Joining Date (Optional)',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildDateField(
                        label: joiningDate == null 
                            ? 'Select joining date' 
                            : _formatDate(joiningDate!),
                        onTap: () => _selectJoiningDate(context),
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
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter monthly salary';
                          }
                          return null;
                        },
                      ),
                      
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ),
            
            // Bottom Button
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: isLoading ? null : _handleAddStaff,
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required TextInputType keyboardType,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        validator: validator,
        maxLines: maxLines,
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
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please select an option';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildDateField({
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          color: Colors.white,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  color: label.startsWith('Select') 
                      ? const Color(0xFF9CA3AF) 
                      : const Color(0xFF111827),
                ),
              ),
            ),
            const Icon(
              Icons.calendar_today,
              color: Color(0xFF9CA3AF),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Future<void> _selectJoiningDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: joiningDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF2563EB),
              onPrimary: Colors.white,
              onSurface: Color(0xFF111827),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != joiningDate) {
      setState(() {
        joiningDate = picked;
      });
    }
  }

  Future<void> _handleAddStaff() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (selectedRole == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a role'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      print('EditStaffMemberDialog: Updating staff member in Firestore');
      
      // Parse salary
      final salary = double.tryParse(_salaryController.text.trim());
      
      // Update staff member in Firestore
      await _service.updateStaffMember(widget.staff.id, {
        'name': _nameController.text.trim(),
        'role': selectedRole!,
        'phone': _phoneController.text.trim(),
        'email': _emailController.text.trim().isNotEmpty ? _emailController.text.trim() : null,
        'address': _addressController.text.trim().isNotEmpty ? _addressController.text.trim() : null,
        'joiningDate': joiningDate,
        'salary': salary,
      });

      print('EditStaffMemberDialog: Staff member updated successfully');

      if (mounted) {
        setState(() {
          isLoading = false;
        });

        Navigator.of(context).pop(true); // Return true to indicate success

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Staff member updated successfully'),
            backgroundColor: Color(0xFF16A34A),
          ),
        );
      }
    } catch (e) {
      print('EditStaffMemberDialog ERROR: $e');
      
      if (mounted) {
        setState(() {
          isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating staff member: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }
}