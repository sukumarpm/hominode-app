import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../models/complaint_models.dart';
import 'priority_chip.dart';
import 'status_chip.dart';
import 'complaint_detail_modal.dart';

class ComplaintListCard extends StatelessWidget {
  final ComplaintEntry complaint;
  final Function(ComplaintEntry)? onComplaintUpdated;

  const ComplaintListCard({
    super.key,
    required this.complaint,
    this.onComplaintUpdated,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        ComplaintDetailModal.show(
          context,
          complaint: complaint,
          onComplaintUpdated: onComplaintUpdated,
        );
      },
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: ID, Priority, Status
            Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                  child: Text(
                    '#${complaint.id}',
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                PriorityChip(priority: complaint.priority),
                const Spacer(),
                StatusChip(status: complaint.status),
              ],
            ),

            SizedBox(height: 12.h),

            // Complaint title
            Text(
              complaint.title,
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
                color: Color(0xFF111827),
              ),
            ),

            SizedBox(height: 8.h),

            // Resident info and date
            Row(
              children: [
                Icon(
                  Icons.person_outline,
                  size: 16.w,
                  color: Color(0xFF6B7280),
                ),
                SizedBox(width: 4.w),
                Expanded(
                  child: Text(
                    '${complaint.residentName} • ${complaint.unit}',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ),
                Icon(Icons.access_time, size: 16.w, color: Color(0xFF6B7280)),
                SizedBox(width: 4.w),
                Text(
                  _formatDate(complaint.date),
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),

            SizedBox(height: 12.h),

            // Category and assignment
            Row(
              children: [
                Container(
                  width: 8.w,
                  height: 8.h,
                  decoration: BoxDecoration(
                    color: complaint.category.color,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: 8.w),
                Text(
                  complaint.category.label,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF111827),
                  ),
                ),
                if (complaint.assignedTo != null) ...[
                  const Spacer(),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 8.w,
                      vertical: 4.h,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(6.r),
                      border: Border.all(color: const Color(0xFF0E4778)),
                    ),
                    child: Text(
                      'Assigned to ${complaint.assignedTo!}',
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF0E4778),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
