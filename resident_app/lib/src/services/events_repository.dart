// lib/src/services/events_repository.dart
// Repository for events data with API stubs

import '../models/event.dart';

/// API Contract:
/// GET /events?tab=upcoming -> List of upcoming events
/// GET /events?tab=past -> List of past events
/// POST /events/{id}/rsvp -> Toggle RSVP status

class EventsRepository {
  static final EventsRepository _instance = EventsRepository._internal();
  factory EventsRepository() => _instance;
  EventsRepository._internal();

  /// Fetch upcoming events
  /// API: GET /events?tab=upcoming
  Future<List<Event>> fetchUpcomingEvents() async {
    await Future.delayed(const Duration(milliseconds: 500));
    return _getMockUpcomingEvents();
  }

  /// Fetch past events
  /// API: GET /events?tab=past
  Future<List<Event>> fetchPastEvents() async {
    await Future.delayed(const Duration(milliseconds: 500));
    return _getMockPastEvents();
  }

  /// Toggle RSVP for an event
  /// API: POST /events/{id}/rsvp
  Future<void> toggleRsvp(String eventId, bool isAttending) async {
    await Future.delayed(const Duration(milliseconds: 300));
    // Mock success - replace with actual API call
  }

  List<Event> _getMockUpcomingEvents() {
    return [
      Event(
        id: 'evt_1',
        title: 'Holi Celebration 2025',
        description: 'Join us for a colorful Holi celebration with your neighbors! Enjoy traditional music, delicious food, and fun activities for all ages.',
        imageUrl: 'https://images.unsplash.com/photo-1583241800698-2d3d3d0c6b2e?w=800',
        date: DateTime(2025, 3, 25),
        startTime: '10:00 AM',
        endTime: '2:00 PM',
        location: 'Community Ground',
        attendees: 45,
        capacity: 100,
      ),
      Event(
        id: 'evt_2',
        title: 'Yoga Session',
        description: 'Start your day with a refreshing yoga session on the terrace. Suitable for all levels.',
        imageUrl: 'https://images.unsplash.com/photo-1544367567-0f2fcb009e0b?w=800',
        date: DateTime(2025, 11, 5),
        startTime: '6:00 AM',
        endTime: '7:00 AM',
        location: 'Terrace Garden',
        attendees: 12,
        capacity: 20,
      ),
      Event(
        id: 'evt_3',
        title: 'New Year Celebration 2026',
        description: 'Ring in the new year with music, dance, and celebration!',
        imageUrl: 'https://images.unsplash.com/photo-1470229722913-7c0e2dbbafd3?w=800',
        date: DateTime(2026, 1, 1),
        startTime: '10:00 PM',
        endTime: '2:00 AM',
        location: 'Community Ground',
        attendees: 450,
        capacity: 1000,
      ),
    ];
  }

  List<Event> _getMockPastEvents() {
    return [
      Event(
        id: 'evt_4',
        title: 'Diwali Celebration',
        description: 'A memorable Diwali celebration with lights and festivities.',
        imageUrl: 'https://images.unsplash.com/photo-1605461415907-3e5c0f3c4f2f?w=400',
        date: DateTime(2025, 11, 1),
        startTime: '6:00 PM',
        endTime: '9:00 PM',
        location: 'Community Ground',
        attendees: 450,
        capacity: 500,
        isPast: true,
      ),
    ];
  }
}
