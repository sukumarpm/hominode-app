import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../models/complaint_models.dart';

class PriorityChip extends StatelessWidget {
  final ComplaintPriority priority;

  const PriorityChip({super.key, required this.priority});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: priority.color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6.r),
        border: Border.all(color: priority.color.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6.w,
            height: 6.h,
            decoration: BoxDecoration(
              color: priority.color,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 4.w),
          Text(
            priority.label,
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
              color: priority.color,
            ),
          ),
        ],
      ),
    );
  }
}
