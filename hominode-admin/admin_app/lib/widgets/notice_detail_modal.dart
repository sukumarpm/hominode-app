import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import '../models/notice_models.dart';

class NoticeDetailModal extends StatelessWidget {
  final Notice notice;

  const NoticeDetailModal({super.key, required this.notice});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20.r),
          topRight: Radius.circular(20.r),
        ),
      ),
      child: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(20.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildNoticeHeader(),
                  SizedBox(height: 20.h),
                  _buildNoticeContent(),
                  SizedBox(height: 20.h),
                  _buildNoticeDetails(),
                  SizedBox(height: 20.h),
                  _buildTargetInfo(),
                  if (notice.status == NoticeStatus.published) ...[
                    SizedBox(height: 20.h),
                    _buildEngagementStats(),
                  ],
                  SizedBox(height: 30.h),
                  _buildActionButtons(context),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8.w),
            decoration: BoxDecoration(
              color: notice.type.backgroundColor,
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Icon(notice.type.icon, color: notice.type.color, size: 24.w),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Notice Details',
                  style: TextStyle(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF111827),
                  ),
                ),
                Text(
                  notice.type.displayName,
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: notice.type.color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
            decoration: BoxDecoration(
              color: notice.status.color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20.r),
            ),
            child: Text(
              notice.status.displayName,
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                color: notice.status.color,
              ),
            ),
          ),
          SizedBox(width: 8.w),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, color: Color(0xFF6B7280)),
          ),
        ],
      ),
    );
  }

  Widget _buildNoticeHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                notice.title,
                style: TextStyle(
                  fontSize: 24.sp,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF111827),
                  height: 1.3,
                ),
              ),
            ),
            if (notice.isUrgent)
              Container(
                margin: EdgeInsets.only(left: 12.w),
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444),
                  borderRadius: BorderRadius.circular(6.r),
                ),
                child: Text(
                  'URGENT',
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
        SizedBox(height: 12.h),
        Row(
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: notice.priority.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6.r),
              ),
              child: Text(
                '${notice.priority.displayName} Priority',
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  color: notice.priority.color,
                ),
              ),
            ),
            if (notice.requiresAcknowledgment) ...[
              SizedBox(width: 8.w),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6.r),
                ),
                child: Text(
                  'Requires Acknowledgment',
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF10B981),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildNoticeContent() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Text(
        notice.content,
        style: TextStyle(
          fontSize: 16.sp,
          color: Color(0xFF374151),
          height: 1.6,
        ),
      ),
    );
  }

  Widget _buildNoticeDetails() {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Notice Information',
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: Color(0xFF111827),
            ),
          ),
          SizedBox(height: 16.h),
          _buildDetailRow(
            Icons.person_outline,
            'Created by',
            notice.authorName,
          ),
          SizedBox(height: 12.h),
          _buildDetailRow(
            Icons.access_time,
            'Created on',
            DateFormat('dd MMM yyyy, hh:mm a').format(notice.createdAt),
          ),
          if (notice.publishedAt != null) ...[
            SizedBox(height: 12.h),
            _buildDetailRow(
              Icons.publish,
              'Published on',
              DateFormat('dd MMM yyyy, hh:mm a').format(notice.publishedAt!),
            ),
          ],
          if (notice.expiresAt != null) ...[
            SizedBox(height: 12.h),
            _buildDetailRow(
              Icons.schedule,
              'Expires on',
              DateFormat('dd MMM yyyy').format(notice.expiresAt!),
              isExpired: notice.expiresAt!.isBefore(DateTime.now()),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    IconData icon,
    String label,
    String value, {
    bool isExpired = false,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20.w,
          color: isExpired ? const Color(0xFFEF4444) : const Color(0xFF6B7280),
        ),
        SizedBox(width: 12.w),
        Text(
          '$label:',
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.w500,
            color: Color(0xFF6B7280),
          ),
        ),
        SizedBox(width: 8.w),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              color: isExpired
                  ? const Color(0xFFEF4444)
                  : const Color(0xFF111827),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTargetInfo() {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Target Audience',
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: Color(0xFF111827),
            ),
          ),
          SizedBox(height: 16.h),
          Row(
            children: [
              Icon(Icons.apartment, size: 20.w, color: const Color(0xFF6B7280)),
              SizedBox(width: 12.w),
              Text(
                'Buildings:',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF6B7280),
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: Wrap(
                  spacing: 6,
                  children: notice.targetBuildings.map((building) {
                    return Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 8.w,
                        vertical: 4.h,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0E4778).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4.r),
                      ),
                      child: Text(
                        building,
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0E4778),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEngagementStats() {
    final acknowledgmentRate = notice.viewCount > 0
        ? (notice.acknowledgmentCount / notice.viewCount * 100).round()
        : 0;

    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Engagement Statistics',
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: Color(0xFF111827),
            ),
          ),
          SizedBox(height: 16.h),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Views',
                  notice.viewCount.toString(),
                  Icons.visibility_outlined,
                  const Color(0xFF0E4778),
                ),
              ),
              SizedBox(width: 12.w),
              if (notice.requiresAcknowledgment)
                Expanded(
                  child: _buildStatCard(
                    'Acknowledged',
                    notice.acknowledgmentCount.toString(),
                    Icons.check_circle_outline,
                    const Color(0xFF10B981),
                  ),
                ),
              if (notice.requiresAcknowledgment) SizedBox(width: 12.w),
              if (notice.requiresAcknowledgment)
                Expanded(
                  child: _buildStatCard(
                    'Rate',
                    '$acknowledgmentRate%',
                    Icons.trending_up,
                    acknowledgmentRate >= 80
                        ? const Color(0xFF10B981)
                        : acknowledgmentRate >= 50
                        ? const Color(0xFFF59E0B)
                        : const Color(0xFFEF4444),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24.w),
          SizedBox(height: 8.h),
          Text(
            value,
            style: TextStyle(
              fontSize: 20.sp,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      children: [
        if (notice.status == NoticeStatus.draft)
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Notice published successfully'),
                    backgroundColor: Color(0xFF10B981),
                  ),
                );
              },
              icon: Icon(Icons.publish, size: 20.w),
              label: const Text('Publish Notice'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 16.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
            ),
          ),
        if (notice.status == NoticeStatus.draft) SizedBox(width: 12.w),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              // Open edit modal
            },
            icon: Icon(Icons.edit_outlined, size: 20.w),
            label: const Text('Edit Notice'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF0E4778),
              side: const BorderSide(color: Color(0xFF0E4778)),
              padding: EdgeInsets.symmetric(vertical: 16.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
            ),
          ),
        ),
        SizedBox(width: 12.w),
        OutlinedButton.icon(
          onPressed: () {
            Navigator.pop(context);
            // Show delete confirmation
          },
          icon: Icon(Icons.delete_outline, size: 20.w),
          label: const Text('Delete'),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFEF4444),
            side: const BorderSide(color: Color(0xFFEF4444)),
            padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 20.w),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.r),
            ),
          ),
        ),
      ],
    );
  }
}
