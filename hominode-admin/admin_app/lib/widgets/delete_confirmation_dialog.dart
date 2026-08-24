import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class DeleteConfirmationDialog extends StatefulWidget {
  final String title;
  final String message;
  final String itemName;
  final String confirmButtonText;
  final bool requireReason;
  final VoidCallback onConfirm;

  const DeleteConfirmationDialog({
    super.key,
    required this.title,
    required this.message,
    required this.itemName,
    this.confirmButtonText = 'Delete',
    this.requireReason = false,
    required this.onConfirm,
  });

  @override
  State<DeleteConfirmationDialog> createState() =>
      _DeleteConfirmationDialogState();
}

class _DeleteConfirmationDialogState extends State<DeleteConfirmationDialog> {
  final TextEditingController _reasonController = TextEditingController();
  bool isLoading = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: 20.w),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
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
        child: Padding(
          padding: EdgeInsets.all(24.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Warning Icon
              Container(
                width: 56.w,
                height: 56.h,
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(28.r),
                ),
                child: Icon(
                  Icons.warning_rounded,
                  color: Color(0xFFDC2626),
                  size: 32.w,
                ),
              ),

              SizedBox(height: 20.h),

              // Title
              Text(
                widget.title,
                style: TextStyle(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
                textAlign: TextAlign.center,
              ),

              SizedBox(height: 12.h),

              // Message
              Text(
                widget.message,
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF6B7280),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),

              SizedBox(height: 8.h),

              // Item Name
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Text(
                  widget.itemName,
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              if (widget.requireReason) ...[
                SizedBox(height: 20.h),

                // Reason Input
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: TextField(
                    controller: _reasonController,
                    maxLines: 3,
                    style: TextStyle(fontSize: 15.sp, color: Color(0xFF111827)),
                    decoration: InputDecoration(
                      hintText: 'Reason for deletion (optional)',
                      hintStyle: TextStyle(
                        fontSize: 15.sp,
                        color: Color(0xFF9CA3AF),
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.all(16.w),
                    ),
                  ),
                ),
              ],

              SizedBox(height: 24.h),

              // Action Buttons
              Row(
                children: [
                  // Cancel Button
                  Expanded(
                    child: SizedBox(
                      height: 48.h,
                      child: OutlinedButton(
                        onPressed: isLoading
                            ? null
                            : () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF6B7280),
                          side: const BorderSide(
                            color: Color(0xFFE5E7EB),
                            width: 1.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),

                  SizedBox(width: 12.w),

                  // Delete Button
                  Expanded(
                    child: SizedBox(
                      height: 48.h,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : _handleDelete,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFDC2626),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          disabledBackgroundColor: const Color(
                            0xFFDC2626,
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
                                widget.confirmButtonText,
                                style: TextStyle(
                                  fontSize: 15.sp,
                                  fontWeight: FontWeight.w600,
                                ),
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
    );
  }

  Future<void> _handleDelete() async {
    setState(() {
      isLoading = true;
    });

    // Simulate API call
    await Future.delayed(const Duration(seconds: 1));

    setState(() {
      isLoading = false;
    });

    Navigator.of(context).pop();
    widget.onConfirm();
  }
}
