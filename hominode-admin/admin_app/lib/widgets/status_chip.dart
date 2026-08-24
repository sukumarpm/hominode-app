import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../models/complaint_models.dart';

class StatusChip extends StatelessWidget {
  final ComplaintStatus status;

  const StatusChip({super.key, required this.status});

  IconData get _icon {
    switch (status) {
      case ComplaintStatus.pending:
        return Icons.pending_actions;
      case ComplaintStatus.inProgress:
        return Icons.work_outline;
      case ComplaintStatus.resolved:
        return Icons.check_circle;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: status.color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon, size: 14.w, color: status.color),
          SizedBox(width: 6.w),
          Text(
            status.label,
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
              color: status.color,
            ),
          ),
        ],
      ),
    );
  }
}
