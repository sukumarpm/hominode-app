import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/notice_models.dart';

class NoticeDetailModal extends StatelessWidget {
  final Notice notice;

  const NoticeDetailModal({super.key, required this.notice});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildNoticeHeader(),
                  const SizedBox(height: 20),
                  _buildNoticeContent(),
                  const SizedBox(height: 20),
                  _buildNoticeDetails(),
                  const SizedBox(height: 20),
                  _buildTargetInfo(),
                  if (notice.status == NoticeStatus.published) ...[
                    const SizedBox(height: 20),
                    _buildEngagementStats(),
                  ],
                  const SizedBox(height: 30),
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
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: notice.type.backgroundColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              notice.type.icon,
              color: notice.type.color,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Notice Details',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF111827),
                  ),
                ),
                Text(
                  notice.type.displayName,
                  style: TextStyle(
                    fontSize: 14,
                    color: notice.type.color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: notice.status.color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              notice.status.displayName,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: notice.status.color,
              ),
            ),
          ),
          const SizedBox(width: 8),
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
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF111827),
                  height: 1.3,
                ),
              ),
            ),
            if (notice.isUrgent)
              Container(
                margin: const EdgeInsets.only(left: 12),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'URGENT',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: notice.priority.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${notice.priority.displayName} Priority',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: notice.priority.color,
                ),
              ),
            ),
            if (notice.requiresAcknowledgment) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Requires Acknowledgment',
                  style: TextStyle(
                    fontSize: 12,
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Text(
        notice.content,
        style: const TextStyle(
          fontSize: 16,
          color: Color(0xFF374151),
          height: 1.6,
        ),
      ),
    );
  }

  Widget _buildNoticeDetails() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Notice Information',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 16),
          _buildDetailRow(
            Icons.person_outline,
            'Created by',
            notice.authorName,
          ),
          const SizedBox(height: 12),
          _buildDetailRow(
            Icons.access_time,
            'Created on',
            DateFormat('dd MMM yyyy, hh:mm a').format(notice.createdAt),
          ),
          if (notice.publishedAt != null) ...[
            const SizedBox(height: 12),
            _buildDetailRow(
              Icons.publish,
              'Published on',
              DateFormat('dd MMM yyyy, hh:mm a').format(notice.publishedAt!),
            ),
          ],
          if (notice.expiresAt != null) ...[
            const SizedBox(height: 12),
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

  Widget _buildDetailRow(IconData icon, String label, String value, {bool isExpired = false}) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: isExpired ? const Color(0xFFEF4444) : const Color(0xFF6B7280),
        ),
        const SizedBox(width: 12),
        Text(
          '$label:',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF6B7280),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isExpired ? const Color(0xFFEF4444) : const Color(0xFF111827),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTargetInfo() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Target Audience',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(
                Icons.apartment,
                size: 20,
                color: const Color(0xFF6B7280),
              ),
              const SizedBox(width: 12),
              const Text(
                'Buildings:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF6B7280),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Wrap(
                  spacing: 6,
                  children: notice.targetBuildings.map((building) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        building,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2563EB),
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Engagement Statistics',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Views',
                  notice.viewCount.toString(),
                  Icons.visibility_outlined,
                  const Color(0xFF2563EB),
                ),
              ),
              const SizedBox(width: 12),
              if (notice.requiresAcknowledgment)
                Expanded(
                  child: _buildStatCard(
                    'Acknowledged',
                    notice.acknowledgmentCount.toString(),
                    Icons.check_circle_outline,
                    const Color(0xFF10B981),
                  ),
                ),
              if (notice.requiresAcknowledgment)
                const SizedBox(width: 12),
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

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
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
              icon: const Icon(Icons.publish, size: 20),
              label: const Text('Publish Notice'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        if (notice.status == NoticeStatus.draft)
          const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              // Open edit modal
            },
            icon: const Icon(Icons.edit_outlined, size: 20),
            label: const Text('Edit Notice'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF2563EB),
              side: const BorderSide(color: Color(0xFF2563EB)),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        OutlinedButton.icon(
          onPressed: () {
            Navigator.pop(context);
            // Show delete confirmation
          },
          icon: const Icon(Icons.delete_outline, size: 20),
          label: const Text('Delete'),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFEF4444),
            side: const BorderSide(color: Color(0xFFEF4444)),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }
}