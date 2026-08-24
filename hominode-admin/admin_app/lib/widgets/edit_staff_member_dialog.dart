import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../services/staff_vendor_service.dart';

class EditStaffMemberDialog extends StatefulWidget {
  final StaffMember staff;

  const EditStaffMemberDialog({super.key, required this.staff});

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
      text: widget.staff.salary != null
          ? widget.staff.salary!.toStringAsFixed(0)
          : '',
    );
    _emailController = TextEditingController(text: widget.staff.email ?? '');
    _addressController = TextEditingController(
      text: widget.staff.address ?? '',
    );
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
      insetPadding: EdgeInsets.symmetric(horizontal: 20.w),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.r),
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
              padding: EdgeInsets.all(24.w),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          'Edit Staff Member',
                          style: TextStyle(
                            fontSize: 20.sp,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF111827),
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          'Update staff member information',
                          style: TextStyle(
                            fontSize: 14.sp,
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
                      padding: EdgeInsets.all(4.w),
                      child: Icon(
                        Icons.close,
                        color: Color(0xFF9CA3AF),
                        size: 24.w,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Scrollable Form Content
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 24.w),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Full Name Field
                      Text(
                        'Full Name',
                        style: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF111827),
                        ),
                      ),
                      SizedBox(height: 8.h),
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

                      SizedBox(height: 20.h),

                      // Role Field
                      Text(
                        'Role',
                        style: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF111827),
                        ),
                      ),
                      SizedBox(height: 8.h),
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

                      SizedBox(height: 20.h),

                      // Phone Number Field
                      Text(
                        'Phone Number',
                        style: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF111827),
                        ),
                      ),
                      SizedBox(height: 8.h),
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

                      SizedBox(height: 20.h),

                      // Email Field (Optional)
                      Text(
                        'Email (Optional)',
                        style: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF111827),
                        ),
                      ),
                      SizedBox(height: 8.h),
                      _buildTextField(
                        controller: _emailController,
                        hintText: 'staff@example.com',
                        keyboardType: TextInputType.emailAddress,
                      ),

                      SizedBox(height: 20.h),

                      // Address Field (Optional)
                      Text(
                        'Address (Optional)',
                        style: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF111827),
                        ),
                      ),
                      SizedBox(height: 8.h),
                      _buildTextField(
                        controller: _addressController,
                        hintText: 'Residential address',
                        keyboardType: TextInputType.streetAddress,
                        maxLines: 2,
                      ),

                      SizedBox(height: 20.h),

                      // Joining Date
                      Text(
                        'Joining Date (Optional)',
                        style: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF111827),
                        ),
                      ),
                      SizedBox(height: 8.h),
                      _buildDateField(
                        label: joiningDate == null
                            ? 'Select joining date'
                            : _formatDate(joiningDate!),
                        onTap: () => _selectJoiningDate(context),
                      ),

                      SizedBox(height: 20.h),

                      // Monthly Salary Field
                      Text(
                        'Monthly Salary',
                        style: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF111827),
                        ),
                      ),
                      SizedBox(height: 8.h),
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

                      SizedBox(height: 8.h),
                    ],
                  ),
                ),
              ),
            ),

            // Bottom Button
            Padding(
              padding: EdgeInsets.all(24.w),
              child: SizedBox(
                width: double.infinity,
                height: 52.h,
                child: ElevatedButton(
                  onPressed: isLoading ? null : _handleAddStaff,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0E4778),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                    disabledBackgroundColor: const Color(
                      0xFF0E4778,
                    ).withOpacity(0.6),
                  ),
                  child: isLoading
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
                          'Update Staff',
                          style: TextStyle(
                            fontSize: 16.sp,
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
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        validator: validator,
        maxLines: maxLines,
        style: TextStyle(fontSize: 15.sp, color: Color(0xFF111827)),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(fontSize: 15.sp, color: Color(0xFF9CA3AF)),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
            horizontal: 16.w,
            vertical: 16.h,
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
      height: 52.h,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(fontSize: 15.sp, color: Color(0xFF9CA3AF)),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
            horizontal: 16.w,
            vertical: 16.h,
          ),
        ),
        style: TextStyle(fontSize: 15.sp, color: Color(0xFF111827)),
        icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF9CA3AF)),
        items: items.map((String item) {
          return DropdownMenuItem<String>(value: item, child: Text(item));
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

  Widget _buildDateField({required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52.h,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          color: Colors.white,
        ),
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15.sp,
                  color: label.startsWith('Select')
                      ? const Color(0xFF9CA3AF)
                      : const Color(0xFF111827),
                ),
              ),
            ),
            Icon(Icons.calendar_today, color: Color(0xFF9CA3AF), size: 20.w),
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
              primary: Color(0xFF0E4778),
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
        'email': _emailController.text.trim().isNotEmpty
            ? _emailController.text.trim()
            : null,
        'address': _addressController.text.trim().isNotEmpty
            ? _addressController.text.trim()
            : null,
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
