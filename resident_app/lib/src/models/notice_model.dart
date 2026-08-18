// lib/src/models/notice_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class NoticeModel {
  final String id;
  final String communityId;
  final String title;
  final String content;
  final String category; // 'general', 'maintenance', 'event', 'urgent'
  final String priority; // 'low', 'medium', 'high'
  final String authorId;
  final String authorName;
  final List<String> attachments;
  final DateTime publishDate;
  final DateTime? expiryDate;
  final bool isActive;
  final List<String> targetFlats; // Empty means all flats
  final DateTime createdAt;
  final DateTime updatedAt;

  NoticeModel({
    required this.id,
    this.communityId = '',
    required this.title,
    required this.content,
    this.category = 'general',
    this.priority = 'medium',
    required this.authorId,
    required this.authorName,
    this.attachments = const [],
    required this.publishDate,
    this.expiryDate,
    this.isActive = true,
    this.targetFlats = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'communityId': communityId,
      'title': title,
      'content': content,
      'category': category,
      'priority': priority,
      'authorId': authorId,
      'authorName': authorName,
      'attachments': attachments,
      'publishDate': Timestamp.fromDate(publishDate),
      'expiryDate': expiryDate != null ? Timestamp.fromDate(expiryDate!) : null,
      'isActive': isActive,
      'targetFlats': targetFlats,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  // JSON serialization methods
  Map<String, dynamic> toJson() => toMap();

  factory NoticeModel.fromJson(Map<String, dynamic> json) {
    return NoticeModel(
      id: json['id'] as String? ?? '',
      communityId: json['communityId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      category: json['category'] as String? ?? 'general',
      priority: json['priority'] as String? ?? 'medium',
      authorId: json['authorId'] as String? ?? '',
      authorName: json['authorName'] as String? ?? '',
      attachments:
          (json['attachments'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      publishDate:
          (json['publishDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      expiryDate: (json['expiryDate'] as Timestamp?)?.toDate(),
      isActive: json['isActive'] as bool? ?? true,
      targetFlats:
          (json['targetFlats'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (json['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  factory NoticeModel.fromMap(Map<String, dynamic> map, String documentId) {
    return NoticeModel(
      id: documentId,
      communityId: map['communityId'] as String? ?? '',
      title: map['title'] ?? '',
      content: map['content'] ?? '',
      category: map['category'] ?? 'general',
      priority: map['priority'] ?? 'medium',
      authorId: map['authorId'] ?? '',
      authorName: map['authorName'] ?? '',
      attachments: List<String>.from(map['attachments'] ?? []),
      publishDate:
          (map['publishDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      expiryDate: (map['expiryDate'] as Timestamp?)?.toDate(),
      isActive: map['isActive'] ?? true,
      targetFlats: List<String>.from(map['targetFlats'] ?? []),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  factory NoticeModel.fromSnapshot(DocumentSnapshot snapshot) {
    return NoticeModel.fromMap(
      snapshot.data() as Map<String, dynamic>,
      snapshot.id,
    );
  }

  factory NoticeModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return NoticeModel.fromMap(data, doc.id);
  }

  bool get isExpired {
    return expiryDate != null && DateTime.now().isAfter(expiryDate!);
  }

  NoticeModel copyWith({
    String? id,
    String? communityId,
    String? title,
    String? content,
    String? category,
    String? priority,
    String? authorId,
    String? authorName,
    List<String>? attachments,
    DateTime? publishDate,
    DateTime? expiryDate,
    bool? isActive,
    List<String>? targetFlats,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return NoticeModel(
      id: id ?? this.id,
      communityId: communityId ?? this.communityId,
      title: title ?? this.title,
      content: content ?? this.content,
      category: category ?? this.category,
      priority: priority ?? this.priority,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      attachments: attachments ?? this.attachments,
      publishDate: publishDate ?? this.publishDate,
      expiryDate: expiryDate ?? this.expiryDate,
      isActive: isActive ?? this.isActive,
      targetFlats: targetFlats ?? this.targetFlats,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
