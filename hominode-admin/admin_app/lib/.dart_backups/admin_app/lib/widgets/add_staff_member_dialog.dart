import 'package:flutter/material.dart';
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
                          'Add Staff Member',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF111827),
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Add a new staff member to the society',
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
                      // Photo Upload Section
                      const Text(
                        'Profile Photo',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildImagePicker(
                        label: 'Upload Photo',
                        file: _photoFile,
                        onTap: () => _pickImage('photo'),
                      ),
                      
                      const SizedBox(height: 20),
                      
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
                      
                      // Password Section for Security Staff
                      if (selectedRole == 'Security')
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Login Credentials',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF111827),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3F4F6),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFE5E7EB)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (_generatedPassword != null)
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Email (Username):',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF6B7280),
                                          ),
                                        ),
                                        Text(
                                          _emailController.text.isNotEmpty
                                              ? _emailController.text
                                              : 'Enter email above',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF1F2937),
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            const Text(
                                              'Password:',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Color(0xFF6B7280),
                                              ),
                                            ),
                                            GestureDetector(
                                              onTap: () {
                                                setState(() =>
                                                    _showPassword =
                                                        !_showPassword);
                                              },
                                              child: Icon(
                                                _showPassword
                                                    ? Icons.visibility_off
                                                    : Icons.visibility,
                                                size: 18,
                                                color:
                                                    const Color(0xFF3B82F6),
                                              ),
                                            ),
                                          ],
                                        ),
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius:
                                                BorderRadius.circular(6),
                                            border: Border.all(
                                              color: const Color(0xFFE5E7EB),
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment
                                                    .spaceBetween,
                                            children: [
                                              Text(
                                                _showPassword
                                                    ? _generatedPassword!
                                                    : '•' *
                                                        _generatedPassword!
                                                            .length,
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFF1F2937),
                                                  letterSpacing: 2,
                                                ),
                                              ),
                                              GestureDetector(
                                                onTap: _copyPassword,
                                                child: const Icon(
                                                  Icons.content_copy,
                                                  size: 16,
                                                  color: Color(0xFF3B82F6),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFEF3C7),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          child: const Row(
                                            children: [
                                              Icon(
                                                Icons.info,
                                                size: 16,
                                                color: Color(0xFFD97706),
                                              ),
                                              SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  'Share these credentials with the security personnel',
                                                  style: TextStyle(
                                                    fontSize: 11,
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
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Center(
                                        child: Text(
                                          'Password will appear here',
                                          style: TextStyle(
                                            color: Color(0xFF6B7280),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _generatePassword,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF3B82F6),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Text('Generate Password'),
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      
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
                      
                      // Aadhar Card Number
                      const Text(
                        'Aadhar Card Number',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 8),
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
                      
                      const SizedBox(height: 20),
                      
                      // Aadhar Card Front
                      const Text(
                        'Aadhar Card (Front)',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildImagePicker(
                        label: 'Upload Aadhar Front',
                        file: _aadharFrontFile,
                        onTap: () => _pickImage('aadhar_front'),
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Aadhar Card Back
                      const Text(
                        'Aadhar Card (Back)',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildImagePicker(
                        label: 'Upload Aadhar Back',
                        file: _aadharBackFile,
                        onTap: () => _pickImage('aadhar_back'),
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Address Field
                      const Text(
                        'Address',
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
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter address';
                          }
                          return null;
                        },
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Emergency Contact Name
                      const Text(
                        'Emergency Contact Name',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildTextField(
                        controller: _emergencyContactController,
                        hintText: 'Contact person name',
                        keyboardType: TextInputType.text,
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Emergency Contact Phone
                      const Text(
                        'Emergency Contact Phone',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildTextField(
                        controller: _emergencyPhoneController,
                        hintText: '+91 12345 12345',
                        keyboardType: TextInputType.phone,
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Joining Date
                      const Text(
                        'Joining Date',
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
                          'Add Staff',
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

  Widget _buildImagePicker({
    required String label,
    required File? file,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: file != null ? const Color(0xFF2563EB) : const Color(0xFFE5E7EB),
            width: file != null ? 2 : 1,
          ),
          color: file != null ? const Color(0xFF2563EB).withOpacity(0.05) : Colors.white,
        ),
        child: file != null
            ? Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
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
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.check_circle,
                        color: Color(0xFF10B981),
                        size: 20,
                      ),
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.cloud_upload_outlined,
                    size: 40,
                    color: Color(0xFF9CA3AF),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Tap to select image',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF9CA3AF),
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
        email: _emailController.text.trim().isNotEmpty ? _emailController.text.trim() : null,
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