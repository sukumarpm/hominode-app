/// Notice Model
/// 
/// Represents a notice sent to a resident.
/// Used in the Send Notice dialog for creating and sending notices.
library;

// ============================================================================
// NOTICE PRIORITY ENUM
// ============================================================================

enum NoticePriority {
  normal,
  high,
  urgent,
}

extension NoticePriorityExtension on NoticePriority {
  String get label {
    switch (this) {
      case NoticePriority.normal:
        return 'Normal';
      case NoticePriority.high:
        return 'High';
      case NoticePriority.urgent:
        return 'Urgent';
    }
  }

  // TODO: Implement visual indicators for priority levels
  // High → amber pill, Urgent → red pill
}

// ============================================================================
// NOTICE MODEL
// ============================================================================

class Notice {
  final String id; // UUID / generated
  final String subject;
  final String message;
  final NoticePriority priority;
  final DateTime dateCreated;
  final String? recipientResidentId; // optional

  Notice({
    required this.id,
    required this.subject,
    required this.message,
    required this.priority,
    required this.dateCreated,
    this.recipientResidentId,
  });

  // TODO: Connect to backend API
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'subject': subject,
      'message': message,
      'priority': priority.name,
      'dateCreated': dateCreated.toIso8601String(),
      'recipientResidentId': recipientResidentId,
    };
  }

  factory Notice.fromJson(Map<String, dynamic> json) {
    return Notice(
      id: json['id'] as String,
      subject: json['subject'] as String,
      message: json['message'] as String,
      priority: NoticePriority.values.firstWhere(
        (e) => e.name == json['priority'],
        orElse: () => NoticePriority.normal,
      ),
      dateCreated: DateTime.parse(json['dateCreated'] as String),
      recipientResidentId: json['recipientResidentId'] as String?,
    );
  }

  @override
  String toString() {
    return 'Notice(id: $id, subject: $subject, priority: ${priority.label}, dateCreated: $dateCreated)';
  }
}

// ============================================================================
// VALIDATION HELPER
// ============================================================================

/// Validates a notice before sending
/// TODO: Add unit tests for this function
bool validateNotice(Notice notice) {
  // Message is required and must be at least 5 characters
  if (notice.message.trim().isEmpty || notice.message.trim().length < 5) {
    return false;
  }

  // Subject is optional but if provided, max 120 characters
  if (notice.subject.trim().length > 120) {
    return false;
  }

  return true;
}

// ============================================================================
// MOCK DATA FOR TESTING
// ============================================================================

/// Sample notice for testing
Notice getMockNotice() {
  return Notice(
    id: 'NOT${DateTime.now().millisecondsSinceEpoch}',
    subject: 'Monthly Maintenance Reminder',
    message: 'This is a reminder to pay your monthly maintenance fees by the 5th of this month.',
    priority: NoticePriority.normal,
    dateCreated: DateTime.now(),
    recipientResidentId: 'RES001',
  );
}
