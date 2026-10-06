import 'package:cloud_firestore/cloud_firestore.dart';

// ============================================================================
// PARCEL ENTRY MODEL
// ============================================================================
// Data model for parcel tracking system

enum ParcelStatus { pending, collected, overdue }

class ParcelEntry {
  final String id;
  final String communityId;
  final String residentId;
  final String flatId;
  final String buildingId;
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
    this.communityId = '',
    this.residentId = '',
    this.flatId = '',
    this.buildingId = '',
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

  factory ParcelEntry.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    if (data == null) throw const FormatException('Parcel does not exist.');
    String text(String key) =>
        data[key] is String ? (data[key] as String).trim() : '';
    DateTime? date(String key) =>
        data[key] is Timestamp ? (data[key] as Timestamp).toDate() : null;
    final receivedAt = date('receivedAt');
    final status = text('status');
    if (receivedAt == null || !['pending', 'collected'].contains(status)) {
      throw const FormatException('Parcel has invalid delivery data.');
    }
    return ParcelEntry(
      id: doc.id,
      communityId: text('communityId'),
      residentId: text('residentId'),
      residentName: text('residentName'),
      flatId: text('flatId'),
      unit: text('flatLabel'),
      buildingId: text('buildingId'),
      courier: text('courier'),
      trackingId: text('trackingId'),
      receivedTime: receivedAt,
      collectedTime: date('collectedAt'),
      status: status == 'collected'
          ? ParcelStatus.collected
          : ParcelStatus.pending,
      isResidentNotified: data['isResidentNotified'] == true,
      notes: text('notes').isEmpty ? null : text('notes'),
    );
  }

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
