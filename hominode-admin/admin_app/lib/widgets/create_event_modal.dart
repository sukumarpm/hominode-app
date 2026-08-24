import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'dart:io';
import '../services/image_picker_service.dart';

class CreateEventModal extends StatefulWidget {
  const CreateEventModal({super.key});

  @override
  State<CreateEventModal> createState() => _CreateEventModalState();
}

class _CreateEventModalState extends State<CreateEventModal> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _categoryController = TextEditingController();
  final _dateController = TextEditingController();
  final _timeController = TextEditingController();
  final _locationController = TextEditingController();
  final _descriptionController = TextEditingController();

  File? _selectedImageFile;
  String? _imageError;
  bool _isImageSelected = false;

  @override
  void dispose() {
    _titleController.dispose();
    _categoryController.dispose();
    _dateController.dispose();
    _timeController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.all(20.w),
      child: Container(
        constraints: BoxConstraints(maxHeight: 600.h),
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
            _buildHeader(),

            // Form Content
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 24.w),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: 8.h),

                      // Event Title
                      _buildFieldLabel('Events Title'),
                      SizedBox(height: 8.h),
                      _buildTextField(
                        controller: _titleController,
                        placeholder: 'e.g., Diwali Celebration',
                      ),

                      SizedBox(height: 20.h),

                      // Category
                      _buildFieldLabel('Category'),
                      SizedBox(height: 8.h),
                      _buildTextField(
                        controller: _categoryController,
                        placeholder: 'e.g., Festival, Meeting, Sports',
                      ),

                      SizedBox(height: 20.h),

                      // Date & Time Row
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildFieldLabel('Date'),
                                SizedBox(height: 8.h),
                                _buildTextField(
                                  controller: _dateController,
                                  placeholder: 'dd-mm-yyyy',
                                  onTap: () => _selectDate(context),
                                  readOnly: true,
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: 16.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildFieldLabel('Time'),
                                SizedBox(height: 8.h),
                                _buildTextField(
                                  controller: _timeController,
                                  placeholder: '-- / --',
                                  onTap: () => _selectTime(context),
                                  readOnly: true,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: 20.h),

                      // Location
                      _buildFieldLabel('Location'),
                      SizedBox(height: 8.h),
                      _buildTextField(
                        controller: _locationController,
                        placeholder: 'e.g., Community Hall',
                      ),

                      SizedBox(height: 20.h),

                      // Description
                      _buildFieldLabel('Description'),
                      SizedBox(height: 8.h),
                      _buildTextField(
                        controller: _descriptionController,
                        placeholder: 'Event details...',
                        maxLines: 4,
                      ),

                      SizedBox(height: 20.h),

                      // Attach Photo
                      _buildFieldLabel('Attach photo (optional)'),
                      SizedBox(height: 8.h),
                      _buildUploadButton(),

                      SizedBox(height: 24.h),
                    ],
                  ),
                ),
              ),
            ),

            // Create Button
            _buildCreateButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.all(24.w),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Create New Event',
                  style: TextStyle(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF111827),
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  'Create a new community event',
                  style: TextStyle(fontSize: 14.sp, color: Color(0xFF6B7280)),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: EdgeInsets.all(8.w),
              child: Icon(Icons.close, size: 20.w, color: Color(0xFF6B7280)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 16.sp,
        fontWeight: FontWeight.w600,
        color: Color(0xFF111827),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String placeholder,
    int maxLines = 1,
    bool readOnly = false,
    VoidCallback? onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: TextFormField(
        controller: controller,
        readOnly: readOnly,
        maxLines: maxLines,
        onTap: onTap,
        style: TextStyle(fontSize: 14.sp, color: Color(0xFF111827)),
        decoration: InputDecoration(
          hintText: placeholder,
          hintStyle: TextStyle(fontSize: 14.sp, color: Color(0xFF9CA3AF)),
          border: InputBorder.none,
          contentPadding: EdgeInsets.all(16.w),
          suffixIcon: readOnly && onTap != null
              ? Icon(
                  controller == _dateController
                      ? Icons.calendar_today
                      : Icons.access_time,
                  size: 18.w,
                  color: const Color(0xFF6B7280),
                )
              : null,
        ),
        validator: (value) {
          if (controller == _titleController &&
              (value == null || value.isEmpty)) {
            return 'Event title is required';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildUploadButton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: _pickImage,
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: 16.h),
            decoration: BoxDecoration(
              border: Border.all(
                color: _imageError != null
                    ? const Color(0xFFEF4444)
                    : const Color(0xFFE5E7EB),
              ),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _isImageSelected
                      ? Icons.check_circle_outline
                      : Icons.file_download_outlined,
                  size: 20.w,
                  color: _isImageSelected
                      ? const Color(0xFF10B981)
                      : const Color(0xFF6B7280),
                ),
                SizedBox(width: 8.w),
                Text(
                  _isImageSelected ? 'Photo selected' : 'Upload photo',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w500,
                    color: _isImageSelected
                        ? const Color(0xFF10B981)
                        : const Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Show selected image preview
        if (_isImageSelected && _selectedImageFile != null) ...[
          SizedBox(height: 12.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(8.r),
            child: Image.file(
              _selectedImageFile!,
              width: double.infinity,
              height: 120,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: double.infinity,
                  height: 120.h,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.image, color: Color(0xFF9CA3AF), size: 32.w),
                      SizedBox(height: 4.h),
                      Text(
                        'Image Preview',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: Color(0xFF9CA3AF),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          SizedBox(height: 8.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Image preview',
                    style: TextStyle(fontSize: 12.sp, color: Color(0xFF6B7280)),
                  ),
                  if (_selectedImageFile != null)
                    Text(
                      '${ImagePickerService.getImageSizeInMB(_selectedImageFile!).toStringAsFixed(1)} MB',
                      style: TextStyle(
                        fontSize: 10.sp,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),
                ],
              ),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _isImageSelected = false;
                    _selectedImageFile = null;
                    _imageError = null;
                  });
                },
                child: Text(
                  'Remove',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: Color(0xFFEF4444),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],

        // Show error message
        if (_imageError != null) ...[
          SizedBox(height: 8.h),
          Text(
            _imageError!,
            style: TextStyle(fontSize: 12.sp, color: Color(0xFFEF4444)),
          ),
        ],
      ],
    );
  }

  Widget _buildCreateButton() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24.w),
      child: ElevatedButton(
        onPressed: _handleCreateEvent,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0E4778),
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(vertical: 16.h),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
          elevation: 0,
        ),
        child: Text(
          'Create & Notify All',
          style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: Color(0xFF0E4778)),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _dateController.text =
            '${picked.day.toString().padLeft(2, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.year}';
      });
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: Color(0xFF0E4778)),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _timeController.text = picked.format(context);
      });
    }
  }

  Future<void> _pickImage() async {
    try {
      setState(() {
        _imageError = null;
      });

      final File? imageFile = await ImagePickerService.showImageSourceDialog(
        context,
      );

      if (imageFile != null) {
        // Validate image file
        if (!ImagePickerService.isValidImageFile(imageFile)) {
          setState(() {
            _imageError = 'Please select a valid image file (JPG, PNG, etc.)';
          });
          return;
        }

        // Check file size (max 5MB)
        if (!ImagePickerService.isImageSizeValid(imageFile, maxSizeMB: 5.0)) {
          setState(() {
            _imageError =
                'Image size must be less than 5MB. Current size: ${ImagePickerService.getImageSizeInMB(imageFile).toStringAsFixed(1)}MB';
          });
          return;
        }

        // Image is valid, set it
        setState(() {
          _selectedImageFile = imageFile;
          _isImageSelected = true;
          _imageError = null;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Image selected successfully!'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _imageError = 'Failed to select image. Please try again.';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
  }

  void _handleCreateEvent() {
    if (_formKey.currentState!.validate()) {
      // Parse date from dd-mm-yyyy format
      DateTime? eventDate;
      if (_dateController.text.isNotEmpty) {
        final parts = _dateController.text.split('-');
        if (parts.length == 3) {
          eventDate = DateTime(
            int.parse(parts[2]), // year
            int.parse(parts[1]), // month
            int.parse(parts[0]), // day
          );
        }
      }

      final eventData = {
        'title': _titleController.text,
        'category': _categoryController.text.isEmpty
            ? 'General'
            : _categoryController.text,
        'date': eventDate ?? DateTime.now(),
        'time': _timeController.text.isEmpty ? '6:00 PM' : _timeController.text,
        'location': _locationController.text.isEmpty
            ? 'Community Hall'
            : _locationController.text,
        'description': _descriptionController.text,
        'hasImage': _isImageSelected,
        'imageFile': _selectedImageFile,
        'localImagePath': _selectedImageFile?.path,
        'imageUrl': null, // For network images (future enhancement)
      };

      Navigator.pop(context, eventData);
    }
  }
}

// Helper function to show the modal
Future<Map<String, dynamic>?> showCreateEventModal(BuildContext context) {
  return showDialog<Map<String, dynamic>>(
    context: context,
    barrierDismissible: false, // Prevent dismissing by tapping outside
    barrierColor: Colors.black.withOpacity(0.4), // Dark overlay
    builder: (BuildContext context) {
      return const CreateEventModal();
    },
  );
}
