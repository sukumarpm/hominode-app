import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import '../services/staff_vendor_service.dart';

class AddStaffMemberDialog extends StatefulWidget {
  const AddStaffMemberDialog({super.key});

  @override
  State<AddStaffMemberDialog> createState() => _AddStaffMemberDialogState();
}

class _AddStaffMemberDialogState extends State<AddStaffMemberDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _salaryController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _aadharController = TextEditingController();
  final _emergencyContactController = TextEditingController();
  final _emergencyPhoneController = TextEditingController();
  final StaffVendorService _service = StaffVendorService();
  final ImagePicker _picker = ImagePicker();

  String? selectedRole;
  DateTime? joiningDate;
  bool isLoading = false;

  // Image files
  File? _photoFile;
  File? _aadharFrontFile;
  File? _aadharBackFile;

  // Image URLs (after upload)
  String? _photoUrl;
  String? _aadharFrontUrl;
  String? _aadharBackUrl;

  // Security staff password
  String? _generatedPassword;
  bool _showPassword = false;

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
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _salaryController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _aadharController.dispose();
    _emergencyContactController.dispose();
    _emergencyPhoneController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(String type) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          switch (type) {
            case 'photo':
              _photoFile = File(image.path);
              break;
            case 'aadhar_front':
              _aadharFrontFile = File(image.path);
              break;
            case 'aadhar_back':
              _aadharBackFile = File(image.path);
              break;
          }
        });
      }
    } catch (e) {
      print('Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error selecting image: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  Future<String?> _uploadImage(File file, String path) async {
    try {
      final ref = FirebaseStorage.instance.ref().child(path);
      final uploadTask = await ref.putFile(file);
      final url = await uploadTask.ref.getDownloadURL();
      return url;
    } catch (e) {
      print('Error uploading image: $e');
      return null;
    }
  }

  String _generateSecurePassword() {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#\$%^&*';
    final random = DateTime.now().microsecond;
    String password = '';

    for (int i = 0; i < 12; i++) {
      password += chars[(random + i) % chars.length];
    }

    return password;
  }

  void _generatePassword() {
    setState(() {
      _generatedPassword = _generateSecurePassword();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Secure password generated'),
        backgroundColor: Color(0xFF10B981),
      ),
    );
  }

  Future<void> _copyPassword() async {
    if (_generatedPassword != null) {
      await Clipboard.setData(ClipboardData(text: _generatedPassword!));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password copied to clipboard'),
          backgroundColor: Color(0xFF3B82F6),
        ),
      );
    }
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
                          'Add Staff Member',
                          style: TextStyle(
                            fontSize: 20.sp,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF111827),
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          'Add a new staff member to the society',
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
                      // Photo Upload Section
                      Text(
                        'Profile Photo',
                        style: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF111827),
                        ),
                      ),
                      SizedBox(height: 8.h),
                      _buildImagePicker(
                        label: 'Upload Photo',
                        file: _photoFile,
                        onTap: () => _pickImage('photo'),
                      ),

                      SizedBox(height: 20.h),

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

                      // Password Section for Security Staff
                      if (selectedRole == 'Security')
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Login Credentials',
                              style: TextStyle(
                                fontSize: 15.sp,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF111827),
                              ),
                            ),
                            SizedBox(height: 8.h),
                            Container(
                              padding: EdgeInsets.all(16.w),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3F4F6),
                                borderRadius: BorderRadius.circular(8.r),
                                border: Border.all(
                                  color: const Color(0xFFE5E7EB),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (_generatedPassword != null)
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Email (Username):',
                                          style: TextStyle(
                                            fontSize: 12.sp,
                                            color: Color(0xFF6B7280),
                                          ),
                                        ),
                                        Text(
                                          _emailController.text.isNotEmpty
                                              ? _emailController.text
                                              : 'Enter email above',
                                          style: TextStyle(
                                            fontSize: 13.sp,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF1F2937),
                                          ),
                                        ),
                                        SizedBox(height: 12.h),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              'Password:',
                                              style: TextStyle(
                                                fontSize: 12.sp,
                                                color: Color(0xFF6B7280),
                                              ),
                                            ),
                                            GestureDetector(
                                              onTap: () {
                                                setState(
                                                  () => _showPassword =
                                                      !_showPassword,
                                                );
                                              },
                                              child: Icon(
                                                _showPassword
                                                    ? Icons.visibility_off
                                                    : Icons.visibility,
                                                size: 18.w,
                                                color: const Color(0xFF3B82F6),
                                              ),
                                            ),
                                          ],
                                        ),
                                        Container(
                                          padding: EdgeInsets.all(8.w),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(
                                              6.r,
                                            ),
                                            border: Border.all(
                                              color: const Color(0xFFE5E7EB),
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                _showPassword
                                                    ? _generatedPassword!
                                                    : '•' *
                                                          _generatedPassword!
                                                              .length,
                                                style: TextStyle(
                                                  fontSize: 13.sp,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFF1F2937),
                                                  letterSpacing: 2,
                                                ),
                                              ),
                                              GestureDetector(
                                                onTap: _copyPassword,
                                                child: Icon(
                                                  Icons.content_copy,
                                                  size: 16.w,
                                                  color: Color(0xFF3B82F6),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        SizedBox(height: 12.h),
                                        Container(
                                          padding: EdgeInsets.all(8.w),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFEF3C7),
                                            borderRadius: BorderRadius.circular(
                                              6.r,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.info,
                                                size: 16.w,
                                                color: Color(0xFFD97706),
                                              ),
                                              SizedBox(width: 8.w),
                                              Expanded(
                                                child: Text(
                                                  'Share these credentials with the security personnel',
                                                  style: TextStyle(
                                                    fontSize: 11.sp,
                                                    color: Color(0xFFD97706),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    )
                                  else
                                    Container(
                                      padding: EdgeInsets.all(12.w),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(
                                          6.r,
                                        ),
                                      ),
                                      child: Center(
                                        child: Text(
                                          'Password will appear here',
                                          style: TextStyle(
                                            color: Color(0xFF6B7280),
                                            fontSize: 12.sp,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            SizedBox(height: 12.h),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _generatePassword,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF3B82F6),
                                  padding: EdgeInsets.symmetric(vertical: 12.h),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8.r),
                                  ),
                                ),
                                child: const Text('Generate Password'),
                              ),
                            ),
                            SizedBox(height: 20.h),
                          ],
                        ),

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

                      // Aadhar Card Number
                      Text(
                        'Aadhar Card Number',
                        style: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF111827),
                        ),
                      ),
                      SizedBox(height: 8.h),
                      _buildTextField(
                        controller: _aadharController,
                        hintText: 'XXXX XXXX XXXX',
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter Aadhar number';
                          }
                          if (value.replaceAll(' ', '').length != 12) {
                            return 'Aadhar number must be 12 digits';
                          }
                          return null;
                        },
                      ),

                      SizedBox(height: 20.h),

                      // Aadhar Card Front
                      Text(
                        'Aadhar Card (Front)',
                        style: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF111827),
                        ),
                      ),
                      SizedBox(height: 8.h),
                      _buildImagePicker(
                        label: 'Upload Aadhar Front',
                        file: _aadharFrontFile,
                        onTap: () => _pickImage('aadhar_front'),
                      ),

                      SizedBox(height: 20.h),

                      // Aadhar Card Back
                      Text(
                        'Aadhar Card (Back)',
                        style: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF111827),
                        ),
                      ),
                      SizedBox(height: 8.h),
                      _buildImagePicker(
                        label: 'Upload Aadhar Back',
                        file: _aadharBackFile,
                        onTap: () => _pickImage('aadhar_back'),
                      ),

                      SizedBox(height: 20.h),

                      // Address Field
                      Text(
                        'Address',
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
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter address';
                          }
                          return null;
                        },
                      ),

                      SizedBox(height: 20.h),

                      // Emergency Contact Name
                      Text(
                        'Emergency Contact Name',
                        style: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF111827),
                        ),
                      ),
                      SizedBox(height: 8.h),
                      _buildTextField(
                        controller: _emergencyContactController,
                        hintText: 'Contact person name',
                        keyboardType: TextInputType.text,
                      ),

                      SizedBox(height: 20.h),

                      // Emergency Contact Phone
                      Text(
                        'Emergency Contact Phone',
                        style: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF111827),
                        ),
                      ),
                      SizedBox(height: 8.h),
                      _buildTextField(
                        controller: _emergencyPhoneController,
                        hintText: '+91 12345 12345',
                        keyboardType: TextInputType.phone,
                      ),

                      SizedBox(height: 20.h),

                      // Joining Date
                      Text(
                        'Joining Date',
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
                          'Add Staff',
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

  Widget _buildImagePicker({
    required String label,
    required File? file,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 120.h,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: file != null
                ? const Color(0xFF0E4778)
                : const Color(0xFFE5E7EB),
            width: file != null ? 2 : 1,
          ),
          color: file != null
              ? const Color(0xFF0E4778).withOpacity(0.05)
              : Colors.white,
        ),
        child: file != null
            ? Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12.r),
                    child: Image.file(
                      file,
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: EdgeInsets.all(4.w),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20.r),
                      ),
                      child: Icon(
                        Icons.check_circle,
                        color: Color(0xFF10B981),
                        size: 20.w,
                      ),
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.cloud_upload_outlined,
                    size: 40.w,
                    color: Color(0xFF9CA3AF),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    'Tap to select image',
                    style: TextStyle(fontSize: 12.sp, color: Color(0xFF9CA3AF)),
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

    // Check if password is generated for Security staff
    if (selectedRole == 'Security' && _generatedPassword == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please generate password for security personnel'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      print('AddStaffMemberDialog: Adding staff member to Firestore');

      // Upload images to Firebase Storage
      if (_photoFile != null) {
        print('Uploading profile photo...');
        _photoUrl = await _uploadImage(
          _photoFile!,
          'staff_photos/${DateTime.now().millisecondsSinceEpoch}_photo.jpg',
        );
      }

      if (_aadharFrontFile != null) {
        print('Uploading Aadhar front...');
        _aadharFrontUrl = await _uploadImage(
          _aadharFrontFile!,
          'staff_documents/${DateTime.now().millisecondsSinceEpoch}_aadhar_front.jpg',
        );
      }

      if (_aadharBackFile != null) {
        print('Uploading Aadhar back...');
        _aadharBackUrl = await _uploadImage(
          _aadharBackFile!,
          'staff_documents/${DateTime.now().millisecondsSinceEpoch}_aadhar_back.jpg',
        );
      }

      // Parse salary
      final salary = double.tryParse(_salaryController.text.trim());

      // Add staff member to Firestore with all details
      final staffId = await _service.addStaffMemberWithDocuments(
        name: _nameController.text.trim(),
        role: selectedRole!,
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim().isNotEmpty
            ? _emailController.text.trim()
            : null,
        address: _addressController.text.trim(),
        aadharNumber: _aadharController.text.trim(),
        emergencyContact: _emergencyContactController.text.trim().isNotEmpty
            ? _emergencyContactController.text.trim()
            : null,
        emergencyPhone: _emergencyPhoneController.text.trim().isNotEmpty
            ? _emergencyPhoneController.text.trim()
            : null,
        joiningDate: joiningDate,
        salary: salary,
        photoUrl: _photoUrl,
        aadharFrontUrl: _aadharFrontUrl,
        aadharBackUrl: _aadharBackUrl,
        password: selectedRole == 'Security' ? _generatedPassword : null,
      );

      print('AddStaffMemberDialog: Staff member added with ID: $staffId');

      if (mounted) {
        setState(() {
          isLoading = false;
        });

        Navigator.of(context).pop(true); // Return true to indicate success

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Staff member added successfully'),
            backgroundColor: Color(0xFF16A34A),
          ),
        );
      }
    } catch (e) {
      print('AddStaffMemberDialog ERROR: $e');

      if (mounted) {
        setState(() {
          isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding staff member: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }
}
