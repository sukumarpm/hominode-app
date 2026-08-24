import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import '../services/staff_vendor_service.dart';

class AddVendorModal extends StatefulWidget {
  const AddVendorModal({super.key});

  @override
  State<AddVendorModal> createState() => _AddVendorModalState();
}

class _AddVendorModalState extends State<AddVendorModal> {
  final _formKey = GlobalKey<FormState>();
  final _businessNameController = TextEditingController();
  final _contactPersonController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _aadharController = TextEditingController();
  final StaffVendorService _service = StaffVendorService();
  final ImagePicker _picker = ImagePicker();
  
  String? selectedCategory;
  DateTime? contractStartDate;
  DateTime? contractEndDate;
  List<String> selectedServices = [];
  bool isLoading = false;
  
  // Image files
  File? _photoFile;
  File? _aadharFrontFile;
  File? _aadharBackFile;
  
  // Image URLs (after upload)
  String? _photoUrl;
  String? _aadharFrontUrl;
  String? _aadharBackUrl;

  final List<String> categories = [
    'Plumbing',
    'Electrician',
    'Cleaning',
    'Security',
    'Maintenance',
    'Carpentry',
    'Painting',
    'Gardening',
    'HVAC',
    'Pest Control',
    'Landscaping',
    'Other',
  ];

  final List<String> availableServices = [
    'Installation',
    'Repair',
    'Maintenance',
    'Emergency Service',
    'Consultation',
    'Inspection',
    'Replacement',
    'Cleaning',
  ];

  @override
  void dispose() {
    _businessNameController.dispose();
    _contactPersonController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _aadharController.dispose();
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
                          'Add Vendor',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF111827),
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Add a new vendor to the directory',
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
                        'Business/Contact Photo',
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
                      
                      // Business Name Field
                      const Text(
                        'Business Name',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildTextField(
                        controller: _businessNameController,
                        hintText: 'e.g., Quick Fix Plumbing',
                        keyboardType: TextInputType.text,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter business name';
                          }
                          return null;
                        },
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Category Field
                      const Text(
                        'Category',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildDropdownField(
                        value: selectedCategory,
                        hintText: 'Select category',
                        items: categories,
                        onChanged: (value) {
                          setState(() {
                            selectedCategory = value;
                          });
                        },
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Contact Person Field
                      const Text(
                        'Contact Person',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildTextField(
                        controller: _contactPersonController,
                        hintText: 'Name',
                        keyboardType: TextInputType.text,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter contact person name';
                          }
                          return null;
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
                        hintText: 'vendor@example.com',
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
                        hintText: 'Business address',
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
                      
                      // Contract Start Date
                      const Text(
                        'Contract Start Date (Optional)',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildDateField(
                        label: contractStartDate == null 
                            ? 'Select start date' 
                            : _formatDate(contractStartDate!),
                        onTap: () => _selectStartDate(context),
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Contract End Date
                      const Text(
                        'Contract End Date (Optional)',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildDateField(
                        label: contractEndDate == null 
                            ? 'Select end date' 
                            : _formatDate(contractEndDate!),
                        onTap: () => _selectEndDate(context),
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Services Provided
                      const Text(
                        'Services Provided (Optional)',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildServicesSelector(),
                      
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
                  onPressed: isLoading ? null : _handleAddVendor,
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
                          'Add Vendor',
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
        color: Colors.white,
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
        color: Colors.white,
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
            return 'Please select a category';
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

  Widget _buildServicesSelector() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        color: Colors.white,
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: availableServices.map((service) {
              final isSelected = selectedServices.contains(service);
              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      selectedServices.remove(service);
                    } else {
                      selectedServices.add(service);
                    }
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected 
                        ? const Color(0xFF2563EB) 
                        : const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    service,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: isSelected 
                          ? Colors.white 
                          : const Color(0xFF111827),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          if (selectedServices.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Tap to select services',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF9CA3AF),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Future<void> _selectStartDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: contractStartDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
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
    if (picked != null && picked != contractStartDate) {
      setState(() {
        contractStartDate = picked;
      });
    }
  }

  Future<void> _selectEndDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: contractEndDate ?? (contractStartDate ?? DateTime.now()),
      firstDate: contractStartDate ?? DateTime(2020),
      lastDate: DateTime(2030),
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
    if (picked != null && picked != contractEndDate) {
      setState(() {
        contractEndDate = picked;
      });
    }
  }

  Future<void> _handleAddVendor() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a category'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      print('AddVendorModal: Adding vendor to Firestore');
      
      // Upload images to Firebase Storage
      if (_photoFile != null) {
        print('Uploading vendor photo...');
        _photoUrl = await _uploadImage(
          _photoFile!,
          'vendor_photos/${DateTime.now().millisecondsSinceEpoch}_photo.jpg',
        );
      }
      
      if (_aadharFrontFile != null) {
        print('Uploading Aadhar front...');
        _aadharFrontUrl = await _uploadImage(
          _aadharFrontFile!,
          'vendor_documents/${DateTime.now().millisecondsSinceEpoch}_aadhar_front.jpg',
        );
      }
      
      if (_aadharBackFile != null) {
        print('Uploading Aadhar back...');
        _aadharBackUrl = await _uploadImage(
          _aadharBackFile!,
          'vendor_documents/${DateTime.now().millisecondsSinceEpoch}_aadhar_back.jpg',
        );
      }
      
      
      // Add vendor to Firestore with all fields including documents
      final vendorId = await _service.addVendorWithDocuments(
        businessName: _businessNameController.text.trim(),
        category: selectedCategory!,
        contactPerson: _contactPersonController.text.trim(),
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim().isNotEmpty 
            ? _emailController.text.trim() 
            : null,
        address: _addressController.text.trim(),
        aadharNumber: _aadharController.text.trim(),
        contractStartDate: contractStartDate,
        contractEndDate: contractEndDate,
        services: selectedServices.isNotEmpty ? selectedServices : null,
        photoUrl: _photoUrl,
        aadharFrontUrl: _aadharFrontUrl,
        aadharBackUrl: _aadharBackUrl,
      );

      print('AddVendorModal: Vendor added with ID: $vendorId');

      if (mounted) {
        setState(() {
          isLoading = false;
        });

        Navigator.of(context).pop(true); // Return true to indicate success

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vendor added successfully'),
            backgroundColor: Color(0xFF16A34A),
          ),
        );
      }
    } catch (e) {
      print('AddVendorModal ERROR: $e');
      
      if (mounted) {
        setState(() {
          isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding vendor: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }
}
