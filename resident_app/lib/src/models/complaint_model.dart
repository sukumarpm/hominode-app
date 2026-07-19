// lib/src/models/complaint_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class ComplaintModel {
  final String id;
  final String flatId;
  final String? flatLabel;
  final String? adminId;
  final String userId;
  final String title;
  final String description;
  final String category; // 'maintenance', 'security', 'noise', 'parking', 'other'
  final String priority; // 'low', 'medium', 'high', 'urgent'
  final String status; // 'open', 'in_progress', 'resolved', 'closed', 'rejected'
  final List<String> attachments;
  final String? assignedTo;
  final String? resolution;
  final DateTime? resolvedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  ComplaintModel({
    required this.id,
    required this.flatId,
    this.flatLabel,
    this.adminId,
    required this.userId,
    required this.title,
    required this.description,
    required this.category,
    this.priority = 'medium',
    this.status = 'open',
    this.attachments = const [],
    this.assignedTo,
    this.resolution,
    this.resolvedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'flatId': flatId,
      'flatLabel': flatLabel,
      'adminId': adminId,
      'userId': userId,
      'title': title,
      'description': description,
      'category': category,
      'priority': priority,
      'status': status,
      'attachments': attachments,
      'assignedTo': assignedTo,
      'resolution': resolution,
      'resolvedAt': resolvedAt != null ? Timestamp.fromDate(resolvedAt!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  // JSON serialization methods
  Map<String, dynamic> toJson() => toMap();

  factory ComplaintModel.fromJson(Map<String, dynamic> json) {
    return ComplaintModel(
      id: json['id'] as String? ?? '',
      flatId: json['flatId'] as String? ?? '',
      flatLabel: json['flatLabel'] as String?,
      adminId: json['adminId'] as String?,
      userId: json['userId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      category: json['category'] as String? ?? '',
      priority: json['priority'] as String? ?? 'medium',
      status: json['status'] as String? ?? 'open',
      attachments: (json['attachments'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      assignedTo: json['assignedTo'] as String?,
      resolution: json['resolution'] as String?,
      resolvedAt: (json['resolvedAt'] as Timestamp?)?.toDate(),
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (json['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  factory ComplaintModel.fromMap(Map<String, dynamic> map, String documentId) {
    return ComplaintModel(
      id: documentId,
      flatId: map['flatId'] ?? '',
      flatLabel: map['flatLabel'],
      adminId: map['adminId'],
      userId: map['userId'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      category: map['category'] ?? '',
      priority: map['priority'] ?? 'medium',
      status: map['status'] ?? 'open',
      attachments: List<String>.from(map['attachments'] ?? []),
      assignedTo: map['assignedTo'],
      resolution: map['resolution'],
      resolvedAt: (map['resolvedAt'] as Timestamp?)?.toDate(),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  factory ComplaintModel.fromSnapshot(DocumentSnapshot snapshot) {
    return ComplaintModel.fromMap(snapshot.data() as Map<String, dynamic>, snapshot.id);
  }

  factory ComplaintModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ComplaintModel.fromMap(data, doc.id);
  }

  bool get isOpen => status == 'open';
  bool get isResolved => status == 'resolved' || status == 'closed';
  bool get isInProgress => status == 'in_progress';

  ComplaintModel copyWith({
    String? id,
    String? flatId,
    String? flatLabel,
    String? adminId,
    String? userId,
    String? title,
    String? description,
    String? category,
    String? priority,
    String? status,
    List<String>? attachments,
    String? assignedTo,
    String? resolution,
    DateTime? resolvedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ComplaintModel(
      id: id ?? this.id,
      flatId: flatId ?? this.flatId,
      flatLabel: flatLabel ?? this.flatLabel,
      adminId: adminId ?? this.adminId,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      attachments: attachments ?? this.attachments,
      assignedTo: assignedTo ?? this.assignedTo,
      resolution: resolution ?? this.resolution,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
