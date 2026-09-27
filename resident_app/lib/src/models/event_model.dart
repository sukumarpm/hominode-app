// lib/src/models/event_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class EventModel {
  final String id;
  final String title;
  final String description;
  final String category;
  final String priority;
  final String status;
  final DateTime? eventDate;
  final String? time;
  final String? location;

  final List<String> imageUrls;

  final int? rsvpCount;
  final int? totalCapacity;
  final DateTime createdAt;
  final DateTime updatedAt;

  EventModel({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.priority,
    required this.status,
    this.eventDate,
    this.time,
    this.location,
    this.imageUrls = const [],
    this.rsvpCount,
    this.totalCapacity,
    required this.createdAt,
    required this.updatedAt,
  });

  String? get imageUrl => imageUrls.isEmpty ? null : imageUrls.first;

  static List<String> _readImages(Map<String, dynamic> data) {
    final urls = <String>[];

    final rawUrls = data['imageUrls'];
    if (rawUrls is List) {
      for (final item in rawUrls) {
        if (item is String && item.trim().isNotEmpty) {
          urls.add(item.trim());
        }
      }
    }

    final rawImages = data['images'];
    if (rawImages is List) {
      for (final item in rawImages) {
        if (item is Map) {
          final url = item['url'];
          if (url is String && url.trim().isNotEmpty) {
            urls.add(url.trim());
          }
        }
      }
    }

    final legacy = data['imageUrl'];
    if (legacy is String && legacy.trim().isNotEmpty) {
      urls.add(legacy.trim());
    }

    return urls.toSet().toList();
  }

  factory EventModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    DateTime? parsedEventDate;

    final rawDate = data['eventDate'] ?? data['date'];

    if (rawDate is Timestamp) {
      parsedEventDate = rawDate.toDate();
    } else if (rawDate is String) {
      parsedEventDate = DateTime.tryParse(rawDate);
    }

    return EventModel(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      category: data['category'] ?? 'General',
      priority: data['priority'] ?? 'medium',
      status: data['status'] ?? 'upcoming',
      eventDate: parsedEventDate,
      time: data['time'],
      location: data['location'],
      imageUrls: _readImages(data),
      rsvpCount: data['rsvpCount'] is num
          ? (data['rsvpCount'] as num).toInt()
          : 0,
      totalCapacity: data['totalCapacity'] is num
          ? (data['totalCapacity'] as num).toInt()
          : null,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
