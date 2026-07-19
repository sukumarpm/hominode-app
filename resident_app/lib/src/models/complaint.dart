// lib/src/models/complaint.dart
// Complaint model

enum ComplaintStatus { pending, inProgress, completed }

enum ComplaintCategory { plumbing, electrical, maintenance, cleaning, security, other }

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
      status: ComplaintStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => ComplaintStatus.pending,
      ),
      createdDate: DateTime.parse(json['createdDate'] as String),
      assignedTo: json['assignedTo'] as String?,
      technicianPhone: json['technicianPhone'] as String?,
      assignedStaffId: json['assignedStaffId'] as String?,
      assignedStaffRole: json['assignedStaffRole'] as String?,
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
    };
  }

  String get formattedDate {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
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
