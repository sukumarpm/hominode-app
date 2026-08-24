import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class CreatePinnedPostModal extends StatefulWidget {
  const CreatePinnedPostModal({super.key});

  @override
  State<CreatePinnedPostModal> createState() => _CreatePinnedPostModalState();
}

class _CreatePinnedPostModalState extends State<CreatePinnedPostModal> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  String selectedCategory = 'General';
  bool isLoading = false;

  final List<String> categories = [
    'General',
    'Rules & Regulations',
    'Emergency Contacts',
    'Maintenance',
    'Events',
    'Announcements',
    'Safety Guidelines',
    'Community Updates',
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _createPinnedPost() async {
    // Validate inputs
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter a title')));
      return;
    }

    if (_contentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter content')));
      return;
    }

    setState(() {
      isLoading = true;
    });

    // TODO: Implement create pinned post API call
    await Future.delayed(const Duration(seconds: 2)); // Simulate API call

    setState(() {
      isLoading = false;
    });

    // TODO: Add the new post to the list and refresh the screen
    if (mounted) {
      Navigator.of(context).pop({
        'title': _titleController.text.trim(),
        'content': _contentController.text.trim(),
        'category': selectedCategory,
        'date': DateTime.now(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pinned post created successfully!')),
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
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(24.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Create Pinned Post',
                            style: TextStyle(
                              fontSize: 20.sp,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            'Create an important post for all residents',
                            style: TextStyle(
                              fontSize: 14.sp,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(
                        Icons.close,
                        color: Color(0xFF6B7280),
                        size: 24.w,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 24.h),

                // Category Selector
                Text(
                  'Category',
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                ),
                SizedBox(height: 8.h),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedCategory,
                      isExpanded: true,
                      padding: EdgeInsets.symmetric(
                        horizontal: 16.w,
                        vertical: 14.h,
                      ),
                      icon: Icon(
                        Icons.keyboard_arrow_down,
                        color: Color(0xFF6B7280),
                        size: 20.w,
                      ),
                      style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF1F2937),
                      ),
                      dropdownColor: Colors.white,
                      items: categories.map((String category) {
                        return DropdownMenuItem<String>(
                          value: category,
                          child: _buildCategoryItem(category),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            selectedCategory = newValue;
                          });
                        }
                      },
                    ),
                  ),
                ),
                SizedBox(height: 20.h),

                // Title Input
                Text(
                  'Title',
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                ),
                SizedBox(height: 8.h),
                TextField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    hintText: 'Enter post title',
                    hintStyle: TextStyle(
                      color: Color(0xFF9CA3AF),
                      fontSize: 15.sp,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.r),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.r),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.r),
                      borderSide: const BorderSide(color: Color(0xFF0E4778)),
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 14.h,
                    ),
                  ),
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLength: 100,
                ),
                SizedBox(height: 20.h),

                // Content Text Area
                Text(
                  'Content',
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                ),
                SizedBox(height: 8.h),
                TextField(
                  controller: _contentController,
                  maxLines: 6,
                  minLines: 6,
                  decoration: InputDecoration(
                    hintText: 'Enter post content...',
                    hintStyle: TextStyle(
                      color: Color(0xFF9CA3AF),
                      fontSize: 15.sp,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.r),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.r),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.r),
                      borderSide: const BorderSide(color: Color(0xFF0E4778)),
                    ),
                    contentPadding: EdgeInsets.all(16.w),
                  ),
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLength: 500,
                ),
                SizedBox(height: 24.h),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: isLoading
                            ? null
                            : () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFE5E7EB)),
                          padding: EdgeInsets.symmetric(vertical: 14.h),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : _createPinnedPost,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0E4778),
                          disabledBackgroundColor: const Color(0xFF9CA3AF),
                          padding: EdgeInsets.symmetric(vertical: 14.h),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          elevation: 0,
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
                                'Create Post',
                                style: TextStyle(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryItem(String category) {
    IconData icon;
    Color iconColor;

    switch (category) {
      case 'Rules & Regulations':
        icon = Icons.gavel;
        iconColor = const Color(0xFFEF4444);
        break;
      case 'Emergency Contacts':
        icon = Icons.emergency;
        iconColor = const Color(0xFFF59E0B);
        break;
      case 'Maintenance':
        icon = Icons.build;
        iconColor = const Color(0xFF8B5CF6);
        break;
      case 'Events':
        icon = Icons.event;
        iconColor = const Color(0xFF10B981);
        break;
      case 'Announcements':
        icon = Icons.campaign;
        iconColor = const Color(0xFF0E4778);
        break;
      case 'Safety Guidelines':
        icon = Icons.security;
        iconColor = const Color(0xFF059669);
        break;
      case 'Community Updates':
        icon = Icons.group;
        iconColor = const Color(0xFF6366F1);
        break;
      default:
        icon = Icons.info;
        iconColor = const Color(0xFF6B7280);
    }

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        children: [
          Container(
            width: 32.w,
            height: 32.h,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Icon(icon, size: 16.w, color: iconColor),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              category,
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w500,
                color: Color(0xFF1F2937),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Helper function to show the modal
void showCreatePinnedPostModal(BuildContext context) {
  showDialog(
    context: context,
    barrierColor: const Color(0x80000000), // Semi-transparent black background
    barrierDismissible: true,
    builder: (BuildContext context) {
      return const CreatePinnedPostModal();
    },
  ).then((result) {
    // Handle the result if a new post was created
    if (result != null) {
      // TODO: Refresh the pinned posts list
      print('New pinned post created: $result');
    }
  });
}
