// lib/src/models/event_model.dart
// Event data model

import 'package:cloud_firestore/cloud_firestore.dart';

class EventModel {
  final String id;
  final String title;
  final String description;
  final String category;
  final String priority; // 'high', 'medium', 'low'
  final String status; // 'upcoming', 'active', 'completed', 'cancelled'
  final DateTime? eventDate;
  final String? time;
  final String? location;
  final String? imageUrl;
  final String? localImagePath;
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
    this.imageUrl,
    this.localImagePath,
    this.rsvpCount,
    this.totalCapacity,
    required this.createdAt,
    required this.updatedAt,
  });

  factory EventModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    // Parse date field (can be Timestamp or String)
    DateTime? parsedEventDate;
    if (data['date'] != null) {
      if (data['date'] is Timestamp) {
        parsedEventDate = (data['date'] as Timestamp).toDate();
      } else if (data['date'] is String) {
        try {
          parsedEventDate = DateTime.parse(data['date']);
        } catch (e) {
          // If parsing fails, leave as null
        }
      }
    }
    
    return EventModel(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      category: data['category'] ?? 'General',
      priority: data['priority'] ?? 'medium',
      status: data['status'] ?? 'upcoming',
      eventDate: parsedEventDate ?? (data['eventDate'] as Timestamp?)?.toDate(),
      time: data['time'],
      location: data['location'],
      imageUrl: data['imageUrl'],
      localImagePath: data['localImagePath'],
      rsvpCount: data['rsvpCount'] ?? 0,
      totalCapacity: data['totalCapacity'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'category': category,
      'priority': priority,
      'status': status,
      'date': eventDate != null ? Timestamp.fromDate(eventDate!) : null,
      'eventDate': eventDate != null ? Timestamp.fromDate(eventDate!) : null,
      'time': time,
      'location': location,
      'imageUrl': imageUrl,
      'localImagePath': localImagePath,
      'rsvpCount': rsvpCount,
      'totalCapacity': totalCapacity,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}
