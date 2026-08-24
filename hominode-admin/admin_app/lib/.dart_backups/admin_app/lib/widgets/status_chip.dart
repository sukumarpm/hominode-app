import 'package:flutter/material.dart';
import '../models/complaint_models.dart';

class StatusChip extends StatelessWidget {
  final ComplaintStatus status;

  const StatusChip({
    super.key,
    required this.status,
  });

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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: status.color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _icon,
            size: 14,
            color: status.color,
          ),
          const SizedBox(width: 6),
          Text(
            status.label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: status.color,
            ),
          ),
        ],
      ),
    );
  }
}
