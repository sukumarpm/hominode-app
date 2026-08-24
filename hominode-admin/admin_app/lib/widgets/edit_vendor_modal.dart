import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../services/staff_vendor_service.dart';

class EditVendorModal extends StatefulWidget {
  final VendorModel vendor;

  const EditVendorModal({super.key, required this.vendor});

  @override
  State<EditVendorModal> createState() => _EditVendorModalState();
}

class _EditVendorModalState extends State<EditVendorModal> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _businessNameController;
  late TextEditingController _contactPersonController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _addressController;
  final StaffVendorService _service = StaffVendorService();

  String? selectedCategory;
  DateTime? contractStartDate;
  DateTime? contractEndDate;
  List<String> selectedServices = [];
  bool isLoading = false;

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
  void initState() {
    super.initState();
    // Pre-populate with existing data
    _businessNameController = TextEditingController(
      text: widget.vendor.businessName,
    );
    _contactPersonController = TextEditingController(
      text: widget.vendor.contactPerson,
    );
    _phoneController = TextEditingController(text: widget.vendor.phone);
    _emailController = TextEditingController(text: widget.vendor.email ?? '');
    _addressController = TextEditingController(
      text: widget.vendor.address ?? '',
    );
    selectedCategory = widget.vendor.category;
    contractStartDate = widget.vendor.contractStartDate;
    contractEndDate = widget.vendor.contractEndDate;
    selectedServices = List<String>.from(widget.vendor.services);
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _contactPersonController.dispose();
    _phoneController.dispose();
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
                          'Edit Vendor',
                          style: TextStyle(
                            fontSize: 20.sp,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF111827),
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          'Update vendor information',
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
                      // Business Name Field
                      Text(
                        'Business Name',
                        style: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF111827),
                        ),
                      ),
                      SizedBox(height: 8.h),
                      _buildTextField(
                        controller: _businessNameController,
                        hintText: 'Enter business name',
                        keyboardType: TextInputType.text,
                      ),

                      SizedBox(height: 20.h),

                      // Category Field
                      Text(
                        'Category',
                        style: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF111827),
                        ),
                      ),
                      SizedBox(height: 8.h),
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

                      SizedBox(height: 20.h),

                      // Contact Person Field
                      Text(
                        'Contact Person',
                        style: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF111827),
                        ),
                      ),
                      SizedBox(height: 8.h),
                      _buildTextField(
                        controller: _contactPersonController,
                        hintText: 'Enter contact person name',
                        keyboardType: TextInputType.text,
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
                        hintText: 'vendor@example.com',
                        keyboardType: TextInputType.emailAddress,
                        isRequired: false,
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
                        hintText: 'Business address',
                        keyboardType: TextInputType.streetAddress,
                        isRequired: false,
                        maxLines: 2,
                      ),

                      SizedBox(height: 20.h),

                      // Contract Start Date
                      Text(
                        'Contract Start Date (Optional)',
                        style: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF111827),
                        ),
                      ),
                      SizedBox(height: 8.h),
                      _buildDateField(
                        label: contractStartDate == null
                            ? 'Select start date'
                            : _formatDate(contractStartDate!),
                        onTap: () => _selectStartDate(context),
                      ),

                      SizedBox(height: 20.h),

                      // Contract End Date
                      Text(
                        'Contract End Date (Optional)',
                        style: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF111827),
                        ),
                      ),
                      SizedBox(height: 8.h),
                      _buildDateField(
                        label: contractEndDate == null
                            ? 'Select end date'
                            : _formatDate(contractEndDate!),
                        onTap: () => _selectEndDate(context),
                      ),

                      SizedBox(height: 20.h),

                      // Services Provided
                      Text(
                        'Services Provided (Optional)',
                        style: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF111827),
                        ),
                      ),
                      SizedBox(height: 8.h),
                      _buildServicesSelector(),

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
                  onPressed: isLoading ? null : _handleUpdateVendor,
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
                          'Update Vendor',
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
    bool isRequired = true,
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
        validator: (value) {
          if (isRequired && (value == null || value.trim().isEmpty)) {
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

  Widget _buildServicesSelector() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        color: Colors.white,
      ),
      padding: EdgeInsets.all(12.w),
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
                  padding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 8.h,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF0E4778)
                        : const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Text(
                    service,
                    style: TextStyle(
                      fontSize: 13.sp,
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
            Padding(
              padding: EdgeInsets.only(top: 8.h),
              child: Text(
                'Tap to select services',
                style: TextStyle(fontSize: 13.sp, color: Color(0xFF9CA3AF)),
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
              primary: Color(0xFF0E4778),
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
              primary: Color(0xFF0E4778),
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

  Future<void> _handleUpdateVendor() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      print('EditVendorModal: Updating vendor in Firestore');

      // Update vendor in Firestore
      await _service.updateVendor(widget.vendor.id, {
        'businessName': _businessNameController.text.trim(),
        'category': selectedCategory,
        'contactPerson': _contactPersonController.text.trim(),
        'phone': _phoneController.text.trim(),
        'email': _emailController.text.trim().isNotEmpty
            ? _emailController.text.trim()
            : null,
        'address': _addressController.text.trim().isNotEmpty
            ? _addressController.text.trim()
            : null,
        'contractStartDate': contractStartDate,
        'contractEndDate': contractEndDate,
        'services': selectedServices,
      });

      print('EditVendorModal: Vendor updated successfully');

      if (mounted) {
        setState(() {
          isLoading = false;
        });

        Navigator.of(context).pop(true);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vendor updated successfully'),
            backgroundColor: Color(0xFF16A34A),
          ),
        );
      }
    } catch (e) {
      print('EditVendorModal ERROR: $e');

      if (mounted) {
        setState(() {
          isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating vendor: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }
}
