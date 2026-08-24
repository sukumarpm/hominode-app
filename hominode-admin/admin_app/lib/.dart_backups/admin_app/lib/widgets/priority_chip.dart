import 'package:flutter/material.dart';
import '../models/complaint_models.dart';

class PriorityChip extends StatelessWidget {
  final ComplaintPriority priority;

  const PriorityChip({
    super.key,
    required this.priority,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: priority.color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: priority.color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: priority.color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            priority.label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: priority.color,
            ),
          ),
        ],
      ),
    );
  }
}