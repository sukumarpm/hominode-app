// lib/src/services/announcements_events_service.dart
// Service for fetching announcements and events from Firestore

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/announcement_model.dart';
import '../models/event_model.dart';

class AnnouncementsEventsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Stream active announcements (real-time)
  /// Sorted in memory to avoid composite index requirement
  Stream<List<AnnouncementModel>> streamAnnouncements() {
    return _firestore
        .collection('announcements')
        .where('status', isEqualTo: 'active')
        .snapshots()
        .map((snapshot) {
      final announcements = snapshot.docs
          .map((doc) => AnnouncementModel.fromFirestore(doc))
          .toList();
      
      // Sort in memory by createdAt descending
      announcements.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      return announcements;
    });
  }

  /// Stream all events (real-time)
  /// Fetches events with published status only
  /// Sorted in memory to avoid composite index requirement
  Stream<List<EventModel>> streamEvents() {
    return _firestore
        .collection('events')
        .where('status', isEqualTo: 'published')
        .snapshots()
        .map((snapshot) {
      final events = snapshot.docs
          .map((doc) => EventModel.fromFirestore(doc))
          .toList();
      
      // Sort in memory by createdAt descending (newest first)
      events.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      return events;
    });
  }
}
