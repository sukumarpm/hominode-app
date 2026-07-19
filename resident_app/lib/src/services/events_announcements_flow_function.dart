// lib/src/services/events_announcements_flow_function.dart
// Complete Events & Announcements Flow Function with proper Firestore integration

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/announcement_model.dart';
import '../models/event_model.dart';

class EventsAnnouncementsFlowFunction {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// STEP 1: Validate Authentication
  /// Check if user is authenticated and get their UID
  Future<String?> _validateAuthentication() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint('❌ EventsFlow: User not authenticated');
        return null;
      }
      debugPrint('✅ EventsFlow STEP 1: Authentication validated - UID: ${user.uid}');
      return user.uid;
    } catch (e) {
      debugPrint('❌ EventsFlow STEP 1 Error: $e');
      return null;
    }
  }

  /// STEP 2: Fetch Active Announcements
  /// Query announcements collection filtered by status = 'active'
  Future<List<AnnouncementModel>> _fetchActiveAnnouncements() async {
    try {
      debugPrint('📋 EventsFlow STEP 2: Fetching active announcements');

      final snapshot = await _firestore
          .collection('announcements')
          .where('status', isEqualTo: 'active')
          .get();

      debugPrint('✅ EventsFlow STEP 2: Found ${snapshot.docs.length} announcements');

      final announcements = snapshot.docs.map((doc) {
        try {
          return AnnouncementModel.fromFirestore(doc);
        } catch (e) {
          debugPrint('⚠️ EventsFlow: Error parsing announcement ${doc.id}: $e');
          return null;
        }
      }).whereType<AnnouncementModel>().toList();

      return announcements;
    } catch (e) {
      debugPrint('❌ EventsFlow STEP 2 Error: $e');
      return [];
    }
  }

  /// STEP 3: Fetch Published Events
  /// Query events collection filtered by status = 'published'
  Future<List<EventModel>> _fetchPublishedEvents() async {
    try {
      debugPrint('📋 EventsFlow STEP 3: Fetching published events');

      final snapshot = await _firestore
          .collection('events')
          .where('status', isEqualTo: 'published')
          .get();

      debugPrint('✅ EventsFlow STEP 3: Found ${snapshot.docs.length} events');

      final events = snapshot.docs.map((doc) {
        try {
          return EventModel.fromFirestore(doc);
        } catch (e) {
          debugPrint('⚠️ EventsFlow: Error parsing event ${doc.id}: $e');
          return null;
        }
      }).whereType<EventModel>().toList();

      return events;
    } catch (e) {
      debugPrint('❌ EventsFlow STEP 3 Error: $e');
      return [];
    }
  }

  /// STEP 4: Process and Sort Data
  /// Sort announcements and events by creation date (newest first)
  Map<String, dynamic> _processData({
    required List<AnnouncementModel> announcements,
    required List<EventModel> events,
  }) {
    try {
      debugPrint('🔄 EventsFlow STEP 4: Processing data');

      // Sort announcements by createdAt (newest first)
      announcements.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      debugPrint('✅ EventsFlow STEP 4: Sorted ${announcements.length} announcements');

      // Sort events by createdAt (newest first)
      events.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      debugPrint('✅ EventsFlow STEP 4: Sorted ${events.length} events');

      return {
        'announcements': announcements,
        'events': events,
        'totalAnnouncements': announcements.length,
        'totalEvents': events.length,
      };
    } catch (e) {
      debugPrint('❌ EventsFlow STEP 4 Error: $e');
      return {
        'announcements': announcements,
        'events': events,
        'totalAnnouncements': announcements.length,
        'totalEvents': events.length,
      };
    }
  }

  /// STEP 5: Return Processed Data
  /// Complete flow function - returns announcements and events ready for display
  Future<Map<String, dynamic>> getEventsAndAnnouncements() async {
    try {
      debugPrint('🚀 EventsFlow: Starting complete flow function');

      // STEP 1: Validate Authentication
      final userId = await _validateAuthentication();
      if (userId == null) {
        return {
          'announcements': [],
          'events': [],
          'totalAnnouncements': 0,
          'totalEvents': 0,
          'error': 'User not authenticated',
        };
      }

      // STEP 2: Fetch Active Announcements
      final announcements = await _fetchActiveAnnouncements();

      // STEP 3: Fetch Published Events
      final events = await _fetchPublishedEvents();

      // STEP 4: Process and Sort Data
      final processedData = _processData(
        announcements: announcements,
        events: events,
      );

      debugPrint('✅ EventsFlow: Complete - Returning ${announcements.length} announcements and ${events.length} events');
      return processedData;
    } catch (e) {
      debugPrint('❌ EventsFlow: Fatal error - $e');
      return {
        'announcements': [],
        'events': [],
        'totalAnnouncements': 0,
        'totalEvents': 0,
        'error': e.toString(),
      };
    }
  }

  /// Stream Announcements in Real-time
  /// Returns a stream of announcements that updates automatically
  Stream<List<AnnouncementModel>> streamAnnouncements() async* {
    try {
      debugPrint('📡 EventsFlow: Starting announcements stream');

      // Validate authentication
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint('❌ EventsFlow Stream: User not authenticated');
        yield [];
        return;
      }

      // Stream announcements
      yield* _firestore
          .collection('announcements')
          .where('status', isEqualTo: 'active')
          .snapshots()
          .map((snapshot) {
        final announcements = snapshot.docs.map((doc) {
          try {
            return AnnouncementModel.fromFirestore(doc);
          } catch (e) {
            debugPrint('⚠️ EventsFlow: Error parsing announcement ${doc.id}: $e');
            return null;
          }
        }).whereType<AnnouncementModel>().toList();

        // Sort by createdAt (newest first)
        announcements.sort((a, b) => b.createdAt.compareTo(a.createdAt));

        debugPrint('📡 EventsFlow: Streamed ${announcements.length} announcements');
        return announcements;
      });
    } catch (e) {
      debugPrint('❌ EventsFlow Stream Error: $e');
      yield [];
    }
  }

  /// Stream Events in Real-time
  /// Returns a stream of events that updates automatically
  Stream<List<EventModel>> streamEvents() async* {
    try {
      debugPrint('📡 EventsFlow: Starting events stream');

      // Validate authentication
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint('❌ EventsFlow Stream: User not authenticated');
        yield [];
        return;
      }

      // Stream events
      yield* _firestore
          .collection('events')
          .where('status', isEqualTo: 'published')
          .snapshots()
          .map((snapshot) {
        final events = snapshot.docs.map((doc) {
          try {
            return EventModel.fromFirestore(doc);
          } catch (e) {
            debugPrint('⚠️ EventsFlow: Error parsing event ${doc.id}: $e');
            return null;
          }
        }).whereType<EventModel>().toList();

        // Sort by createdAt (newest first)
        events.sort((a, b) => b.createdAt.compareTo(a.createdAt));

        debugPrint('📡 EventsFlow: Streamed ${events.length} events');
        return events;
      });
    } catch (e) {
      debugPrint('❌ EventsFlow Stream Error: $e');
      yield [];
    }
  }

  /// Get Announcements Count
  /// Returns the total number of active announcements
  Future<int> getAnnouncementsCount() async {
    try {
      final announcements = await _fetchActiveAnnouncements();
      debugPrint('📊 EventsFlow: Total announcements: ${announcements.length}');
      return announcements.length;
    } catch (e) {
      debugPrint('❌ EventsFlow: Error getting announcements count - $e');
      return 0;
    }
  }

  /// Get Events Count
  /// Returns the total number of published events
  Future<int> getEventsCount() async {
    try {
      final events = await _fetchPublishedEvents();
      debugPrint('📊 EventsFlow: Total events: ${events.length}');
      return events.length;
    } catch (e) {
      debugPrint('❌ EventsFlow: Error getting events count - $e');
      return 0;
    }
  }

  /// Get Upcoming Events
  /// Returns events that are scheduled for future dates
  Future<List<EventModel>> getUpcomingEvents() async {
    try {
      final events = await _fetchPublishedEvents();
      final now = DateTime.now();

      // Filter events that are in the future
      final upcomingEvents = events.where((event) {
        return event.eventDate.isAfter(now);
      }).toList();

      // Sort by event date (earliest first)
      upcomingEvents.sort((a, b) => a.eventDate.compareTo(b.eventDate));

      debugPrint('📅 EventsFlow: Found ${upcomingEvents.length} upcoming events');
      return upcomingEvents;
    } catch (e) {
      debugPrint('❌ EventsFlow: Error getting upcoming events - $e');
      return [];
    }
  }

  /// Get Recent Announcements
  /// Returns the most recent announcements (limit: 5)
  Future<List<AnnouncementModel>> getRecentAnnouncements({int limit = 5}) async {
    try {
      final announcements = await _fetchActiveAnnouncements();

      // Sort by createdAt (newest first)
      announcements.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      // Limit to specified number
      final recentAnnouncements = announcements.take(limit).toList();

      debugPrint('📰 EventsFlow: Found ${recentAnnouncements.length} recent announcements');
      return recentAnnouncements;
    } catch (e) {
      debugPrint('❌ EventsFlow: Error getting recent announcements - $e');
      return [];
    }
  }
}
