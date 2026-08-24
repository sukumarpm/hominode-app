import 'package:flutter/material.dart';

enum NoticeType {
  general,
  maintenance,
  emergency,
  event,
  billing,
  security,
}

enum NoticePriority {
  low,
  medium,
  high,
  urgent,
}

enum NoticeStatus {
  draft,
  published,
  archived,
}

class Notice {
  final String id;
  final String title;
  final String content;
  final NoticeType type;
  final NoticePriority priority;
  final NoticeStatus status;
  final DateTime createdAt;
  final DateTime? publishedAt;
  final DateTime? expiresAt;
  final String authorId;
  final String authorName;
  final List<String> targetBuildings;
  final List<String> targetFloors;
  final bool isUrgent;
  final bool requiresAcknowledgment;
  final int viewCount;
  final int acknowledgmentCount;
  final List<String> attachments;

  Notice({
    required this.id,
    required this.title,
    required this.content,
    required this.type,
    required this.priority,
    required this.status,
    required this.createdAt,
    this.publishedAt,
    this.expiresAt,
    required this.authorId,
    required this.authorName,
    this.targetBuildings = const [],
    this.targetFloors = const [],
    this.isUrgent = false,
    this.requiresAcknowledgment = false,
    this.viewCount = 0,
    this.acknowledgmentCount = 0,
    this.attachments = const [],
  });

  Notice copyWith({
    String? id,
    String? title,
    String? content,
    NoticeType? type,
    NoticePriority? priority,
    NoticeStatus? status,
    DateTime? createdAt,
    DateTime? publishedAt,
    DateTime? expiresAt,
    String? authorId,
    String? authorName,
    List<String>? targetBuildings,
    List<String>? targetFloors,
    bool? isUrgent,
    bool? requiresAcknowledgment,
    int? viewCount,
    int? acknowledgmentCount,
    List<String>? attachments,
  }) {
    return Notice(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      type: type ?? this.type,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      publishedAt: publishedAt ?? this.publishedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      targetBuildings: targetBuildings ?? this.targetBuildings,
      targetFloors: targetFloors ?? this.targetFloors,
      isUrgent: isUrgent ?? this.isUrgent,
      requiresAcknowledgment: requiresAcknowledgment ?? this.requiresAcknowledgment,
      viewCount: viewCount ?? this.viewCount,
      acknowledgmentCount: acknowledgmentCount ?? this.acknowledgmentCount,
      attachments: attachments ?? this.attachments,
    );
  }
}

extension NoticeTypeExtension on NoticeType {
  String get displayName {
    switch (this) {
      case NoticeType.general:
        return 'General';
      case NoticeType.maintenance:
        return 'Maintenance';
      case NoticeType.emergency:
        return 'Emergency';
      case NoticeType.event:
        return 'Event';
      case NoticeType.billing:
        return 'Billing';
      case NoticeType.security:
        return 'Security';
    }
  }

  IconData get icon {
    switch (this) {
      case NoticeType.general:
        return Icons.info_outline;
      case NoticeType.maintenance:
        return Icons.build_outlined;
      case NoticeType.emergency:
        return Icons.warning_outlined;
      case NoticeType.event:
        return Icons.event_outlined;
      case NoticeType.billing:
        return Icons.receipt_long_outlined;
      case NoticeType.security:
        return Icons.security_outlined;
    }
  }

  Color get color {
    switch (this) {
      case NoticeType.general:
        return const Color(0xFF2563EB);
      case NoticeType.maintenance:
        return const Color(0xFFF59E0B);
      case NoticeType.emergency:
        return const Color(0xFFEF4444);
      case NoticeType.event:
        return const Color(0xFF8B5CF6);
      case NoticeType.billing:
        return const Color(0xFF059669);
      case NoticeType.security:
        return const Color(0xFF6366F1);
    }
  }

  Color get backgroundColor {
    switch (this) {
      case NoticeType.general:
        return const Color(0xFFEEF2FF);
      case NoticeType.maintenance:
        return const Color(0xFFFEF3C7);
      case NoticeType.emergency:
        return const Color(0xFFFEE2E2);
      case NoticeType.event:
        return const Color(0xFFF3E8FF);
      case NoticeType.billing:
        return const Color(0xFFECFDF5);
      case NoticeType.security:
        return const Color(0xFFE0E7FF);
    }
  }
}

extension NoticePriorityExtension on NoticePriority {
  String get displayName {
    switch (this) {
      case NoticePriority.low:
        return 'Low';
      case NoticePriority.medium:
        return 'Medium';
      case NoticePriority.high:
        return 'High';
      case NoticePriority.urgent:
        return 'Urgent';
    }
  }

  Color get color {
    switch (this) {
      case NoticePriority.low:
        return const Color(0xFF6B7280);
      case NoticePriority.medium:
        return const Color(0xFF2563EB);
      case NoticePriority.high:
        return const Color(0xFFF59E0B);
      case NoticePriority.urgent:
        return const Color(0xFFEF4444);
    }
  }
}

extension NoticeStatusExtension on NoticeStatus {
  String get displayName {
    switch (this) {
      case NoticeStatus.draft:
        return 'Draft';
      case NoticeStatus.published:
        return 'Published';
      case NoticeStatus.archived:
        return 'Archived';
    }
  }

  Color get color {
    switch (this) {
      case NoticeStatus.draft:
        return const Color(0xFF6B7280);
      case NoticeStatus.published:
        return const Color(0xFF059669);
      case NoticeStatus.archived:
        return const Color(0xFF8B5CF6);
    }
  }
}

class NoticeFilter {
  final NoticeType? type;
  final NoticePriority? priority;
  final NoticeStatus? status;
  final String? building;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final bool? isUrgent;

  NoticeFilter({
    this.type,
    this.priority,
    this.status,
    this.building,
    this.dateFrom,
    this.dateTo,
    this.isUrgent,
  });

  NoticeFilter copyWith({
    NoticeType? type,
    NoticePriority? priority,
    NoticeStatus? status,
    String? building,
    DateTime? dateFrom,
    DateTime? dateTo,
    bool? isUrgent,
  }) {
    return NoticeFilter(
      type: type ?? this.type,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      building: building ?? this.building,
      dateFrom: dateFrom ?? this.dateFrom,
      dateTo: dateTo ?? this.dateTo,
      isUrgent: isUrgent ?? this.isUrgent,
    );
  }

  bool get hasActiveFilters {
    return type != null ||
        priority != null ||
        status != null ||
        building != null ||
        dateFrom != null ||
        dateTo != null ||
        isUrgent != null;
  }
}