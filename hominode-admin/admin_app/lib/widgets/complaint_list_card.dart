import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../models/complaint_models.dart';
import '../services/complaint_service.dart';
import 'priority_chip.dart';
import 'status_chip.dart';
import 'complaint_detail_modal.dart';

class ComplaintListCard extends StatelessWidget {
  final ComplaintEntry complaint;
  final Function(ComplaintEntry)? onComplaintUpdated;
  final ComplaintService? complaintService;
  @visibleForTesting
  final Widget? attachmentsOverride;

  const ComplaintListCard({
    super.key,
    required this.complaint,
    this.onComplaintUpdated,
    this.complaintService,
    this.attachmentsOverride,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        ComplaintDetailModal.show(
          context,
          complaint: complaint,
          onComplaintUpdated: onComplaintUpdated,
          complaintService: complaintService,
          attachmentsOverride: attachmentsOverride,
        );
      },
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '#${complaint.id}',
              key: const ValueKey('complaint-card-id'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF6B7280),
              ),
            ),
            SizedBox(height: 8.h),
            Wrap(
              key: const ValueKey('complaint-card-badges'),
              spacing: 8.w,
              runSpacing: 8.h,
              children: [
                StatusChip(status: complaint.status),
                PriorityChip(priority: complaint.priority),
              ],
            ),
            SizedBox(height: 12.h),
            Text(
              complaint.title,
              key: const ValueKey('complaint-card-title'),
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF111827),
              ),
            ),
            SizedBox(height: 12.h),
            _detailRow('Resident', complaint.residentName),
            _detailRow('Unit', complaint.unit),
            _detailRow('Reported', _formatDate(complaint.date)),
            _detailRow('Category', complaint.category.label),
            _detailRow('Responsible', _assignmentLabel),
          ],
        ),
      ),
    );
  }

  String get _assignmentLabel {
    final team = complaint.assignedTeam?.trim();
    final person = complaint.assignedTo?.trim();
    final values = [
      if (team != null && team.isNotEmpty) _teamLabel(team),
      if (person != null && person.isNotEmpty) person,
    ];
    return values.isEmpty ? 'Management' : values.join(' · ');
  }

  String _teamLabel(String value) {
    switch (value.toLowerCase()) {
      case 'security':
        return 'Security';
      case 'maintenance':
        return 'Maintenance';
      case 'cleaning':
        return 'Cleaning';
      case 'administration':
        return 'Administration';
      case 'vendor':
        return 'Vendor';
      case 'other':
        return 'Other';
      default:
        return value;
    }
  }

  Widget _detailRow(String label, String value) => Padding(
    padding: EdgeInsets.only(bottom: 6.h),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 76.w,
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13.sp, color: const Color(0xFF6B7280)),
          ),
        ),
        SizedBox(width: 8.w),
        Expanded(
          child: Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF374151),
            ),
          ),
        ),
      ],
    ),
  );

  String _formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
