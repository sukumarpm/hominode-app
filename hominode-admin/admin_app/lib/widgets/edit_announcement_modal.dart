import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../events_announcements_screen.dart';

class EditAnnouncementModal extends StatefulWidget {
  final AnnouncementData announcement;
  final Function(AnnouncementData) onSave;

  const EditAnnouncementModal({
    super.key,
    required this.announcement,
    required this.onSave,
  });

  @override
  State<EditAnnouncementModal> createState() => _EditAnnouncementModalState();
}

class _EditAnnouncementModalState extends State<EditAnnouncementModal> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late String _selectedCategory;
  late String _selectedPriority;
  bool _isLoading = false;

  final List<String> _categories = [
    'Festival',
    'Security',
    'General',
    'Maintenance',
    'Meeting',
  ];
  final List<String> _priorities = ['High', 'Medium', 'Low'];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.announcement.title);
    _descriptionController = TextEditingController(
      text: widget.announcement.description,
    );
    _selectedCategory = widget.announcement.category;
    _selectedPriority = widget.announcement.priority;
  }

  @override
  void dispose() {
    _titleController.dispose();
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

                      // Title Field
                      _buildFieldLabel('Announcement Title'),
                      SizedBox(height: 8.h),
                      _buildTextField(
                        controller: _titleController,
                        placeholder: 'Enter announcement title',
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Title is required';
                          }
                          return null;
                        },
                      ),

                      SizedBox(height: 20.h),

                      // Category and Priority Row
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildFieldLabel('Category'),
                                SizedBox(height: 8.h),
                                _buildDropdown(
                                  value: _selectedCategory,
                                  items: _categories,
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedCategory = value!;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: 16.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildFieldLabel('Priority'),
                                SizedBox(height: 8.h),
                                _buildDropdown(
                                  value: _selectedPriority,
                                  items: _priorities,
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedPriority = value!;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: 20.h),

                      // Description Field
                      _buildFieldLabel('Description'),
                      SizedBox(height: 8.h),
                      _buildTextField(
                        controller: _descriptionController,
                        placeholder: 'Enter announcement description',
                        maxLines: 4,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Description is required';
                          }
                          return null;
                        },
                      ),

                      SizedBox(height: 24.h),
                    ],
                  ),
                ),
              ),
            ),

            // Action Buttons
            _buildActionButtons(),
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
          Container(
            width: 40.w,
            height: 40.h,
            decoration: BoxDecoration(
              color: const Color(0xFF0E4778).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Icon(Icons.edit, color: Color(0xFF0E4778), size: 20.w),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Edit Announcement',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF111827),
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  'Update announcement details',
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
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        validator: validator,
        style: TextStyle(fontSize: 14.sp, color: Color(0xFF111827)),
        decoration: InputDecoration(
          hintText: placeholder,
          hintStyle: TextStyle(fontSize: 14.sp, color: Color(0xFF9CA3AF)),
          border: InputBorder.none,
          contentPadding: EdgeInsets.all(16.w),
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        onChanged: onChanged,
        decoration: InputDecoration(
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
            horizontal: 16.w,
            vertical: 12.h,
          ),
        ),
        style: TextStyle(fontSize: 14.sp, color: Color(0xFF111827)),
        items: items.map((String item) {
          return DropdownMenuItem<String>(value: item, child: Text(item));
        }).toList(),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: EdgeInsets.all(24.w),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _isLoading ? null : () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF6B7280),
                side: const BorderSide(color: Color(0xFFE5E7EB)),
                padding: EdgeInsets.symmetric(vertical: 16.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
              ),
              child: Text(
                'Cancel',
                style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w500),
              ),
            ),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleSaveAnnouncement,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0E4778),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 16.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
                elevation: 0,
              ),
              child: _isLoading
                  ? SizedBox(
                      width: 20.w,
                      height: 20.h,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      'Save Changes',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSaveAnnouncement() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      // Simulate API call
      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        // Create updated announcement
        final updatedAnnouncement = AnnouncementData(
          title: _titleController.text,
          category: _selectedCategory,
          priority: _selectedPriority,
          description: _descriptionController.text,
          date: widget.announcement.date, // Keep original date
        );

        Navigator.pop(context);
        widget.onSave(updatedAnnouncement);

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 20.w),
                SizedBox(width: 12.w),
                Expanded(
                  child: Text(
                    'Announcement updated successfully',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.r),
            ),
          ),
        );
      }
    }
  }
}

// Helper function to show the modal
void showEditAnnouncementModal(
  BuildContext context,
  AnnouncementData announcement,
  Function(AnnouncementData) onSave,
) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return EditAnnouncementModal(announcement: announcement, onSave: onSave);
    },
  );
}
