import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class CreateAnnouncementModal extends StatefulWidget {
  const CreateAnnouncementModal({super.key});

  @override
  State<CreateAnnouncementModal> createState() =>
      _CreateAnnouncementModalState();
}

class _CreateAnnouncementModalState extends State<CreateAnnouncementModal> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  String _selectedPriority = 'Low';
  bool _isLoading = false;

  final List<String> _priorities = ['Low', 'Medium', 'High'];

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.all(20.w),
      child: Container(
        constraints: BoxConstraints(maxWidth: 400.w, maxHeight: 600.h),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20.r),
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
                      _buildFieldLabel('Title'),
                      SizedBox(height: 8.h),
                      _buildTextField(
                        controller: _titleController,
                        placeholder: 'Announcement title',
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Title is required';
                          }
                          return null;
                        },
                      ),

                      SizedBox(height: 24.h),

                      // Priority Field
                      _buildFieldLabel('Priority'),
                      SizedBox(height: 8.h),
                      _buildPriorityDropdown(),

                      SizedBox(height: 24.h),

                      // Message Field
                      _buildFieldLabel('Message'),
                      SizedBox(height: 8.h),
                      _buildTextField(
                        controller: _messageController,
                        placeholder: 'Announcement details...',
                        maxLines: 5,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Message is required';
                          }
                          return null;
                        },
                      ),

                      SizedBox(height: 32.h),
                    ],
                  ),
                ),
              ),
            ),

            // Primary Action Button
            _buildPrimaryButton(),
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
              children: [
                Text(
                  'Create Announcement',
                  style: TextStyle(
                    fontSize: 24.sp,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF111827),
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 8.h),
                Text(
                  'Post a new announcement to all residents',
                  style: TextStyle(fontSize: 16.sp, color: Color(0xFF6B7280)),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: EdgeInsets.all(8.w),
                child: Icon(Icons.close, size: 24.w, color: Color(0xFF6B7280)),
              ),
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
        fontSize: 18.sp,
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
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        validator: validator,
        style: TextStyle(fontSize: 16.sp, color: Color(0xFF111827)),
        decoration: InputDecoration(
          hintText: placeholder,
          hintStyle: TextStyle(fontSize: 16.sp, color: Color(0xFF9CA3AF)),
          border: InputBorder.none,
          contentPadding: EdgeInsets.all(16.w),
        ),
      ),
    );
  }

  Widget _buildPriorityDropdown() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: DropdownButtonFormField<String>(
        initialValue: _selectedPriority,
        onChanged: (String? newValue) {
          setState(() {
            _selectedPriority = newValue!;
          });
        },
        decoration: InputDecoration(
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
            horizontal: 16.w,
            vertical: 16.h,
          ),
        ),
        style: TextStyle(fontSize: 16.sp, color: Color(0xFF111827)),
        icon: Icon(
          Icons.keyboard_arrow_down,
          color: Color(0xFF6B7280),
          size: 24.w,
        ),
        items: _priorities.map<DropdownMenuItem<String>>((String value) {
          return DropdownMenuItem<String>(
            value: value,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 16.sp,
                color: value == _selectedPriority
                    ? const Color(0xFF111827)
                    : const Color(0xFF9CA3AF),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPrimaryButton() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24.w),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleCreateAnnouncement,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0E4778),
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(vertical: 18.h),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
          elevation: 0,
        ),
        child: _isLoading
            ? SizedBox(
                width: 24.w,
                height: 24.h,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                'Post & Notify All',
                style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w600),
              ),
      ),
    );
  }

  Future<void> _handleCreateAnnouncement() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      // TODO: Implement backend integration
      // - Save announcement to database
      // - Send push notifications to all residents
      // - Send in-app notifications
      // - Update announcements list

      // Simulate API call
      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        final announcementData = {
          'title': _titleController.text,
          'priority': _selectedPriority,
          'message': _messageController.text,
          'createdAt': DateTime.now().toIso8601String(),
        };

        Navigator.pop(context, announcementData);

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 20.w),
                SizedBox(width: 12.w),
                Expanded(
                  child: Text(
                    'Announcement posted successfully! All residents have been notified.',
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
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }
}

// Helper function to show the modal
Future<Map<String, dynamic>?> showCreateAnnouncementModal(
  BuildContext context,
) async {
  return await showDialog<Map<String, dynamic>>(
    context: context,
    barrierDismissible: true, // Allow dismissing by tapping outside
    barrierColor: Colors.black.withOpacity(0.5), // Semi-transparent background
    builder: (BuildContext context) {
      return const CreateAnnouncementModal();
    },
  );
}
