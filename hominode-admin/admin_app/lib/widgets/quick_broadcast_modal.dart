import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class QuickBroadcastModal extends StatefulWidget {
  const QuickBroadcastModal({super.key});

  @override
  State<QuickBroadcastModal> createState() => _QuickBroadcastModalState();
}

class _QuickBroadcastModalState extends State<QuickBroadcastModal> {
  final _formKey = GlobalKey<FormState>();
  final _messageController = TextEditingController();
  String selectedPriority = 'Normal';
  bool sendToAllStaff = true;
  bool sendSMS = false;
  bool sendPushNotification = true;
  bool isLoading = false;

  final List<String> priorities = ['Low', 'Normal', 'High', 'Urgent'];

  @override
  void dispose() {
    _messageController.dispose();
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
          maxHeight: MediaQuery.of(context).size.height * 0.8,
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
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(24.w),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Quick Broadcast',
                              style: TextStyle(
                                fontSize: 20.sp,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF111827),
                              ),
                            ),
                            SizedBox(height: 4.h),
                            Text(
                              'Send instant notification to staff members',
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

                  SizedBox(height: 32.h),

                  // Message Field
                  Text(
                    'Message',
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF111827),
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                      color: Colors.white,
                    ),
                    child: TextFormField(
                      controller: _messageController,
                      maxLines: 4,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a message';
                        }
                        return null;
                      },
                      style: TextStyle(
                        fontSize: 15.sp,
                        color: Color(0xFF111827),
                      ),
                      decoration: InputDecoration(
                        hintText: 'Enter your broadcast message...',
                        hintStyle: TextStyle(
                          fontSize: 15.sp,
                          color: Color(0xFF9CA3AF),
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.all(16.w),
                      ),
                    ),
                  ),

                  SizedBox(height: 20.h),

                  // Priority Field
                  Text(
                    'Priority',
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF111827),
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                      color: Colors.white,
                    ),
                    child: DropdownButtonFormField<String>(
                      initialValue: selectedPriority,
                      onChanged: (value) {
                        setState(() {
                          selectedPriority = value!;
                        });
                      },
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16.w,
                          vertical: 16.h,
                        ),
                      ),
                      style: TextStyle(
                        fontSize: 15.sp,
                        color: Color(0xFF111827),
                      ),
                      icon: const Icon(
                        Icons.keyboard_arrow_down,
                        color: Color(0xFF9CA3AF),
                      ),
                      items: priorities.map((String priority) {
                        return DropdownMenuItem<String>(
                          value: priority,
                          child: Row(
                            children: [
                              Container(
                                width: 8.w,
                                height: 8.h,
                                decoration: BoxDecoration(
                                  color: _getPriorityColor(priority),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              SizedBox(width: 8.w),
                              Text(priority),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  SizedBox(height: 20.h),

                  // Recipients Section
                  Text(
                    'Recipients',
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF111827),
                    ),
                  ),
                  SizedBox(height: 12.h),

                  // Send to All Staff Toggle
                  Container(
                    padding: EdgeInsets.all(16.w),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.people_outline,
                          color: Colors.grey[600],
                          size: 20.w,
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Text(
                            'Send to all staff members',
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF111827),
                            ),
                          ),
                        ),
                        Switch(
                          value: sendToAllStaff,
                          onChanged: (value) {
                            setState(() {
                              sendToAllStaff = value;
                            });
                          },
                          activeThumbColor: const Color(0xFF0E4778),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 20.h),

                  // Delivery Options
                  Text(
                    'Delivery Options',
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF111827),
                    ),
                  ),
                  SizedBox(height: 12.h),

                  // Push Notification Toggle
                  _buildToggleOption(
                    icon: Icons.notifications_outlined,
                    title: 'Push Notification',
                    subtitle: 'Send via app notification',
                    value: sendPushNotification,
                    onChanged: (value) {
                      setState(() {
                        sendPushNotification = value;
                      });
                    },
                  ),

                  SizedBox(height: 12.h),

                  // SMS Toggle
                  _buildToggleOption(
                    icon: Icons.sms_outlined,
                    title: 'SMS Message',
                    subtitle: 'Send via text message',
                    value: sendSMS,
                    onChanged: (value) {
                      setState(() {
                        sendSMS = value;
                      });
                    },
                  ),

                  SizedBox(height: 32.h),

                  // Send Button
                  SizedBox(
                    width: double.infinity,
                    height: 52.h,
                    child: ElevatedButton(
                      onPressed: isLoading ? null : _handleSendBroadcast,
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
                              'Send Broadcast',
                              style: TextStyle(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildToggleOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey[600], size: 20.w),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF111827),
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w400,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: const Color(0xFF0E4778),
          ),
        ],
      ),
    );
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'Low':
        return const Color(0xFF10B981);
      case 'Normal':
        return const Color(0xFF0E4778);
      case 'High':
        return const Color(0xFFF59E0B);
      case 'Urgent':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF0E4778);
    }
  }

  Future<void> _handleSendBroadcast() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!sendPushNotification && !sendSMS) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one delivery option'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    // Simulate API call
    await Future.delayed(const Duration(seconds: 2));

    setState(() {
      isLoading = false;
    });

    Navigator.of(context).pop(true);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Broadcast sent to ${sendToAllStaff ? 'all staff members' : 'selected staff'}',
        ),
        backgroundColor: const Color(0xFF16A34A),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
