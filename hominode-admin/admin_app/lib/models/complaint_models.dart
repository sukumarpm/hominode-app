import 'package:flutter/material.dart';

enum ComplaintPriority {
  high,
  medium,
  low,
}

enum ComplaintStatus {
  pending,
  inProgress,
  resolved,
}

enum ComplaintCategory {
  plumbing,
  electrical,
  cleaning,
  maintenance,
  security,
  other,
}

extension ComplaintPriorityExtension on ComplaintPriority {
  String get label {
    switch (this) {
      case ComplaintPriority.high:
        return 'High';
      case ComplaintPriority.medium:
        return 'Medium';
      case ComplaintPriority.low:
        return 'Low';
    }
  }

  Color get color {
    switch (this) {
      case ComplaintPriority.high:
        return const Color(0xFFEF4444);
      case ComplaintPriority.medium:
        return const Color(0xFFF59E0B);
      case ComplaintPriority.low:
        return const Color(0xFF10B981);
    }
  }
}

extension ComplaintStatusExtension on ComplaintStatus {
  String get label {
    switch (this) {
      case ComplaintStatus.pending:
        return 'Pending';
      case ComplaintStatus.inProgress:
        return 'In Progress';
      case ComplaintStatus.resolved:
        return 'Resolved';
    }
  }

  Color get color {
    switch (this) {
      case ComplaintStatus.pending:
        return const Color(0xFFF59E0B);
      case ComplaintStatus.inProgress:
        return const Color(0xFF8B5CF6);
      case ComplaintStatus.resolved:
        return const Color(0xFF10B981);
    }
  }
}

extension ComplaintCategoryExtension on ComplaintCategory {
  String get label {
    switch (this) {
      case ComplaintCategory.plumbing:
        return 'Plumbing';
      case ComplaintCategory.electrical:
        return 'Electrical';
      case ComplaintCategory.cleaning:
        return 'Cleaning';
      case ComplaintCategory.maintenance:
        return 'Maintenance';
      case ComplaintCategory.security:
        return 'Security';
      case ComplaintCategory.other:
        return 'Other';
    }
  }

  Color get color {
    switch (this) {
      case ComplaintCategory.plumbing:
        return const Color(0xFF2563EB);
      case ComplaintCategory.electrical:
        return const Color(0xFFF59E0B);
      case ComplaintCategory.cleaning:
        return const Color(0xFF2563EB);
      case ComplaintCategory.maintenance:
        return const Color(0xFF8B5CF6);
      case ComplaintCategory.security:
        return const Color(0xFFEF4444);
      case ComplaintCategory.other:
        return const Color(0xFF6B7280);
    }
  }
}

class ComplaintEntry {
  final String id;
  final ComplaintPriority priority;
  final ComplaintStatus status;
  final String title;
  final String residentName;
  final String unit;
  final DateTime date;
  final ComplaintCategory category;
  final String? assignedTo;
  final String? description;

  ComplaintEntry({
    required this.id,
    required this.priority,
    required this.status,
    required this.title,
    required this.residentName,
    required this.unit,
    required this.date,
    required this.category,
    this.assignedTo,
    this.description,
  });
}