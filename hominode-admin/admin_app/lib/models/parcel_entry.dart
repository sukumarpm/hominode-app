// ============================================================================
// PARCEL ENTRY MODEL
// ============================================================================
// Data model for parcel tracking system

enum ParcelStatus {
  pending,
  collected,
  overdue,
}

class ParcelEntry {
  final String id;
  final String residentName;
  final String unit;
  final String courier;
  final String trackingId;
  final DateTime receivedTime;
  DateTime? collectedTime;
  ParcelStatus status;
  final bool isResidentNotified;
  final String? notes;

  ParcelEntry({
    required this.id,
    required this.residentName,
    required this.unit,
    required this.courier,
    required this.trackingId,
    required this.receivedTime,
    this.collectedTime,
    required this.status,
    required this.isResidentNotified,
    this.notes,
  });

  String get formattedReceivedTime {
    final now = DateTime.now();
    final difference = now.difference(receivedTime);
    
    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  String get formattedCollectedTime {
    if (collectedTime == null) return '';
    
    final now = DateTime.now();
    final difference = now.difference(collectedTime!);
    
    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  bool get isOverdue {
    final now = DateTime.now();
    final daysSinceReceived = now.difference(receivedTime).inDays;
    return status == ParcelStatus.pending && daysSinceReceived >= 3;
  }
}