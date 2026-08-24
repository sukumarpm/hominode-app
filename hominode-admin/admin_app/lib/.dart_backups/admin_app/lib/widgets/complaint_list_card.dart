import 'package:flutter/material.dart';
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
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFFE5E7EB),
            width: 1,
          ),
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
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '#${complaint.id}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                PriorityChip(priority: complaint.priority),
                const Spacer(),
                StatusChip(status: complaint.status),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Complaint title
            Text(
              complaint.title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF111827),
              ),
            ),
            
            const SizedBox(height: 8),
            
            // Resident info and date
            Row(
              children: [
                const Icon(
                  Icons.person_outline,
                  size: 16,
                  color: Color(0xFF6B7280),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '${complaint.residentName} • ${complaint.unit}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ),
                const Icon(
                  Icons.access_time,
                  size: 16,
                  color: Color(0xFF6B7280),
                ),
                const SizedBox(width: 4),
                Text(
                  _formatDate(complaint.date),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Category and assignment
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: complaint.category.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  complaint.category.label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF111827),
                  ),
                ),
                if (complaint.assignedTo != null) ...[
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF2563EB)),
                    ),
                    child: Text(
                      'Assigned to ${complaint.assignedTo!}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF2563EB),
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