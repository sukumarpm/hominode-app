// lib/src/models/complaint.dart
// Complaint model

import 'package:cloud_firestore/cloud_firestore.dart';

enum ComplaintStatus { pending, inProgress, completed }

ComplaintStatus complaintStatusFromFirestore(
  String? rawStatus, {
  bool? isResolved,
  bool hasResolvedAt = false,
}) {
  final normalized = rawStatus?.toLowerCase().replaceAll(RegExp(r'[ _-]'), '');
  switch (normalized) {
    case 'pending':
    case 'open':
    case 'new':
      return ComplaintStatus.pending;
    case 'inprogress':
    case 'assigned':
      return ComplaintStatus.inProgress;
    case 'completed':
    case 'resolved':
    case 'closed':
      return ComplaintStatus.completed;
  }
  if (isResolved == true || hasResolvedAt) return ComplaintStatus.completed;
  return ComplaintStatus.pending;
}

enum ComplaintCategory {
  plumbing,
  electrical,
  maintenance,
  cleaning,
  security,
  other,
}

extension ComplaintCategoryExtension on ComplaintCategory {
  String get categoryDisplayName {
    switch (this) {
      case ComplaintCategory.plumbing:
        return 'Plumbing';
      case ComplaintCategory.electrical:
        return 'Electrical';
      case ComplaintCategory.maintenance:
        return 'Maintenance';
      case ComplaintCategory.cleaning:
        return 'Cleaning';
      case ComplaintCategory.security:
        return 'Security';
      case ComplaintCategory.other:
        return 'Other';
    }
  }
}

class Complaint {
  final String id;
  final String title;
  final String description;
  final ComplaintCategory category;
  final ComplaintStatus status;
  final DateTime createdDate;
  final String? assignedTo; // Staff name
  final String? technicianPhone; // Staff phone
  final String? assignedStaffId; // Staff ID for fetching full details
  final String? assignedStaffRole; // Staff role
  final String? assignedTeam;
  final String? communityId;
  final String? imageUrl;
  final List<String> progressNotes;
  final List<String> resolutionNotes;

  Complaint({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.status,
    required this.createdDate,
    this.assignedTo,
    this.technicianPhone,
    this.assignedStaffId,
    this.assignedStaffRole,
    this.assignedTeam,
    this.communityId,
    this.imageUrl,
    this.progressNotes = const [],
    this.resolutionNotes = const [],
  });

  factory Complaint.fromJson(Map<String, dynamic> json) {
    return Complaint(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      category: ComplaintCategory.values.firstWhere(
        (e) => e.name == json['category'],
        orElse: () => ComplaintCategory.other,
      ),
      status: complaintStatusFromFirestore(json['status'] as String?),
      createdDate: DateTime.parse(json['createdDate'] as String),
      assignedTo: json['assignedTo'] as String?,
      technicianPhone: json['technicianPhone'] as String?,
      assignedStaffId: json['assignedStaffId'] as String?,
      assignedStaffRole: json['assignedStaffRole'] as String?,
      assignedTeam: json['assignedTeam'] as String?,
      communityId: json['communityId'] as String?,
      imageUrl: json['imageUrl'] as String?,
      progressNotes: _complaintNotesFromJson(json['progressNotes']),
      resolutionNotes: _complaintNotesFromJson(json['resolutionNotes']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'category': category.name,
      'status': status.name,
      'createdDate': createdDate.toIso8601String(),
      'assignedTo': assignedTo,
      'technicianPhone': technicianPhone,
      'assignedStaffId': assignedStaffId,
      'assignedStaffRole': assignedStaffRole,
      'assignedTeam': assignedTeam,
      'communityId': communityId,
      'imageUrl': imageUrl,
      'progressNotes': progressNotes,
      'resolutionNotes': resolutionNotes,
    };
  }

  String get formattedDate {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[createdDate.month - 1]} ${createdDate.day}, ${createdDate.year}';
  }

  String get categoryDisplayName {
    switch (category) {
      case ComplaintCategory.plumbing:
        return 'Plumbing';
      case ComplaintCategory.electrical:
        return 'Electrical';
      case ComplaintCategory.maintenance:
        return 'Maintenance';
      case ComplaintCategory.cleaning:
        return 'Cleaning';
      case ComplaintCategory.security:
        return 'Security';
      case ComplaintCategory.other:
        return 'Other';
    }
  }
}

/// Formats the persisted assignment for resident-facing UI without exposing
/// private phone numbers or email addresses from legacy free-text values.
String? complaintResidentVisibleAssignee(String? value) {
  final name = value?.trim();
  if (name == null || name.isEmpty) return null;
  final email = RegExp(r'\b[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}\b');
  final digitCount = RegExp(r'\d').allMatches(name).length;
  if (email.hasMatch(name) || digitCount >= 7) return null;
  return name;
}

String? complaintAssignmentTeamDisplay(String? value) {
  final team = value?.trim();
  if (team == null || team.isEmpty) return null;
  return team
      .split(RegExp(r'[\s_-]+'))
      .where((part) => part.isNotEmpty)
      .map(
        (part) => '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}',
      )
      .join(' ');
}

String complaintResponsibilitySummary(
  Complaint complaint, {
  String? linkedStaffName,
}) {
  final team = complaintAssignmentTeamDisplay(complaint.assignedTeam);
  final person =
      complaintResidentVisibleAssignee(complaint.assignedTo) ??
      (complaint.assignedStaffId?.trim().isNotEmpty == true
          ? complaintResidentVisibleAssignee(linkedStaffName)
          : null);
  final assignment = [
    if (team != null) team,
    if (person != null) person,
  ].join(' · ');
  return assignment.isEmpty
      ? 'Responsible: Unassigned'
      : 'Responsible: $assignment';
}

Complaint complaintFromFirestoreData(String id, Map<String, dynamic> data) {
  final rawCreatedAt = data['createdAt'];
  final createdDate = rawCreatedAt is Timestamp
      ? rawCreatedAt.toDate()
      : rawCreatedAt is DateTime
      ? rawCreatedAt
      : DateTime.tryParse(data['createdDate']?.toString() ?? '') ??
            DateTime.now();
  final rawCategory = data['category']?.toString();
  final category = ComplaintCategory.values.firstWhere(
    (candidate) => candidate.name == rawCategory,
    orElse: () => ComplaintCategory.other,
  );

  return Complaint(
    id: id,
    title: data['title']?.toString() ?? 'Untitled',
    description: data['description']?.toString() ?? '',
    category: category,
    status: complaintStatusFromFirestore(
      data['status'] as String?,
      isResolved: data['isResolved'] as bool?,
      hasResolvedAt: data['resolvedAt'] != null,
    ),
    createdDate: createdDate,
    assignedTo: data['assignedTo'] as String?,
    technicianPhone: data['technicianPhone'] as String?,
    assignedStaffId: data['assignedStaffId'] as String?,
    assignedStaffRole: data['assignedStaffRole'] as String?,
    assignedTeam: data['assignedTeam'] as String?,
    communityId: data['communityId'] as String?,
    imageUrl: data['imageUrl'] as String?,
    progressNotes: _complaintNotesFromJson(data['progressNotes']),
    resolutionNotes: _complaintNotesFromJson(data['resolutionNotes']),
  );
}

List<String> _complaintNotesFromJson(dynamic raw) {
  if (raw is! List) return const [];
  return raw
      .map((entry) {
        if (entry is String) return entry;
        if (entry is Map) return entry['text']?.toString() ?? '';
        return '';
      })
      .where((note) => note.trim().isNotEmpty)
      .toList(growable: false);
}
