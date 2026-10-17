import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'admin_service.dart';

class EventAnnouncementService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AdminService _adminService = AdminService();
  final String _eventsCollection = 'events_announcements';
  final String _announcementsCollection = 'events_announcements';

  // ==================== EVENTS ====================

  /// Get all events (real-time stream) filtered by adminId
  Stream<List<EventModel>> getEvents() {
    final adminId = _adminService.getCurrentAdminId();
    if (adminId == null) return Stream.value([]);

    print('EventService: Fetching events from Firestore for admin: $adminId');
    return _firestore
        .collection(_eventsCollection)
        .where(
          'communityId',
          isEqualTo: _adminService.requireCurrentCommunityId(),
        )
        .where('type', isEqualTo: 'event')
        .snapshots()
        .map((snapshot) {
          print('EventService: Received ${snapshot.docs.length} events');
          final events = snapshot.docs.map((doc) {
            final data = doc.data();
            return EventModel.fromFirestore(doc.id, data);
          }).toList();

          // Sort in memory instead of using orderBy to avoid composite index
          events.sort((a, b) {
            final dateA = a.date ?? DateTime.now();
            final dateB = b.date ?? DateTime.now();
            return dateA.compareTo(dateB);
          });

          return events;
        })
        .handleError((error) {
          print('EventService ERROR: $error');
          throw Exception('Failed to fetch events: $error');
        });
  }

  /// Create new event
  Future<String> createEvent({
    required String title,
    required String category,
    required String description,
    required DateTime date,
    required String time,
    required String location,
    int totalCapacity = 248,
    String? imageUrl,
    String? localImagePath,
  }) async {
    try {
      print('EventService: Creating event - $title');

      final adminId = _adminService.getCurrentAdminId();
      if (adminId == null) throw Exception('Admin not logged in');

      final adminProfile = await _adminService.getAdminProfile();

      final docRef = await _firestore.collection(_eventsCollection).add({
        'type': 'event',
        'title': title,
        'category': category,
        'description': description,
        'date': Timestamp.fromDate(date),
        'time': time,
        'location': location,
        'rsvpCount': 0,
        'totalCapacity': totalCapacity,
        'imageUrl': imageUrl,
        'localImagePath': localImagePath,
        'status': 'upcoming', // upcoming, ongoing, completed, cancelled
        'adminId': adminId,
        'communityId': _adminService.requireCurrentCommunityId(),
        'adminName': adminProfile?['name'] ?? '',
        'adminEmail': adminProfile?['email'] ?? '',
        'adminPhone': adminProfile?['phone'] ?? '',
        'organization': adminProfile?['organization'] ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('EventService: Event created with ID: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      print('EventService ERROR: Failed to create event: $e');
      throw Exception('Failed to create event: $e');
    }
  }

  /// Update event
  Future<void> updateEvent({
    required String eventId,
    String? title,
    String? category,
    String? description,
    DateTime? date,
    String? time,
    String? location,
    int? totalCapacity,
    String? imageUrl,
    String? status,
  }) async {
    try {
      final updates = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (title != null) updates['title'] = title;
      if (category != null) updates['category'] = category;
      if (description != null) updates['description'] = description;
      if (date != null) updates['date'] = Timestamp.fromDate(date);
      if (time != null) updates['time'] = time;
      if (location != null) updates['location'] = location;
      if (totalCapacity != null) updates['totalCapacity'] = totalCapacity;
      if (imageUrl != null) updates['imageUrl'] = imageUrl;
      if (status != null) updates['status'] = status;

      await _firestore
          .collection(_eventsCollection)
          .doc(eventId)
          .update(updates);
      print('EventService: Event updated - $eventId');
    } catch (e) {
      print('EventService ERROR: Failed to update event: $e');
      throw Exception('Failed to update event: $e');
    }
  }

  /// Delete event
  Future<void> deleteEvent(String eventId) async {
    try {
      await _firestore.collection(_eventsCollection).doc(eventId).delete();
      print('EventService: Event deleted - $eventId');
    } catch (e) {
      print('EventService ERROR: Failed to delete event: $e');
      throw Exception('Failed to delete event: $e');
    }
  }

  /// Update RSVP count
  Future<void> updateRsvpCount(String eventId, int newCount) async {
    try {
      await _firestore.collection(_eventsCollection).doc(eventId).update({
        'rsvpCount': newCount,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to update RSVP count: $e');
    }
  }

  // ==================== ANNOUNCEMENTS ====================

  /// Get all announcements (real-time stream) filtered by adminId
  Stream<List<AnnouncementModel>> getAnnouncements() async* {
    final adminId = _adminService.getCurrentAdminId();
    if (adminId == null) {
      yield [];
      return;
    }

    print(
      'AnnouncementService: Fetching announcements from Firestore for admin: $adminId',
    );
    final communityId = _adminService.requireCurrentCommunityId();
    final controller = StreamController<List<AnnouncementModel>>();
    final sources = <String, List<AnnouncementModel>>{
      'events_announcements': [],
      'notices': [],
      'announcements': [],
    };
    void publish() {
      final all = [...sources.values.expand((items) => items)];
      final seen = <String>{};
      final unique =
          all.where((item) {
            final signature =
                '${item.title.trim().toLowerCase()}\u0000'
                '${item.description.trim().toLowerCase()}\u0000'
                '${item.createdAt?.year ?? 0}-${item.createdAt?.month ?? 0}-${item.createdAt?.day ?? 0}';
            return seen.add(signature);
          }).toList()..sort(
            (a, b) => (b.createdAt ?? DateTime(0)).compareTo(
              a.createdAt ?? DateTime(0),
            ),
          );
      controller.add(unique);
    }

    final subscriptions = <StreamSubscription<dynamic>>[
      _firestore
          .collection(_announcementsCollection)
          .where('communityId', isEqualTo: communityId)
          .where('type', isEqualTo: 'announcement')
          .snapshots()
          .listen((snapshot) {
            sources['events_announcements'] = snapshot.docs
                .map(
                  (doc) => AnnouncementModel.fromFirestore(
                    doc.id,
                    doc.data(),
                    sourceCollection: 'events_announcements',
                  ),
                )
                .toList();
            publish();
          }, onError: controller.addError),
      _firestore
          .collection('notices')
          .where('communityId', isEqualTo: communityId)
          .snapshots()
          .listen((snapshot) {
            sources['notices'] = snapshot.docs.map((doc) {
              final data = doc.data();
              return AnnouncementModel.fromFirestore(doc.id, {
                ...data,
                'description': data['content'] ?? data['description'] ?? '',
                'status': data['status'] == 'draft'
                    ? 'inactive'
                    : data['status'] == 'archived'
                    ? 'archived'
                    : 'active',
              }, sourceCollection: 'notices');
            }).toList();
            publish();
          }, onError: controller.addError),
      _firestore
          .collection('announcements')
          .where('communityId', isEqualTo: communityId)
          .snapshots()
          .listen((snapshot) {
            sources['announcements'] = snapshot.docs
                .where(
                  (doc) =>
                      doc.data()['status'] == 'active' ||
                      doc.data()['status'] == 'published',
                )
                .map(
                  (doc) => AnnouncementModel.fromFirestore(
                    doc.id,
                    doc.data(),
                    sourceCollection: 'announcements',
                  ),
                )
                .toList();
            publish();
          }, onError: controller.addError),
    ];
    controller.onCancel = () async {
      for (final subscription in subscriptions) {
        await subscription.cancel();
      }
    };
    yield* controller.stream;
  }

  /// Create new announcement
  Future<String> createAnnouncement({
    required String title,
    required String category,
    required String priority,
    required String description,
  }) async {
    try {
      print('AnnouncementService: Creating announcement - $title');

      final adminId = _adminService.getCurrentAdminId();
      if (adminId == null) throw Exception('Admin not logged in');

      final adminProfile = await _adminService.getAdminProfile();

      final docRef = await _firestore.collection(_announcementsCollection).add({
        'type': 'announcement',
        'title': title,
        'category': category,
        'priority': priority, // high, medium, low
        'description': description,
        'status': 'active', // active, archived
        'adminId': adminId,
        'communityId': _adminService.requireCurrentCommunityId(),
        'adminName': adminProfile?['name'] ?? '',
        'adminEmail': adminProfile?['email'] ?? '',
        'adminPhone': adminProfile?['phone'] ?? '',
        'organization': adminProfile?['organization'] ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('AnnouncementService: Announcement created with ID: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      print('AnnouncementService ERROR: Failed to create announcement: $e');
      throw Exception('Failed to create announcement: $e');
    }
  }

  /// Update announcement
  Future<void> updateAnnouncement({
    required String announcementId,
    String? title,
    String? category,
    String? priority,
    String? description,
    String? status,
    String sourceCollection = 'events_announcements',
  }) async {
    try {
      final updates = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (title != null) updates['title'] = title;
      if (category != null) updates['category'] = category;
      if (priority != null) updates['priority'] = priority;
      if (description != null) updates['description'] = description;
      if (status != null) updates['status'] = status;

      await _firestore
          .collection(sourceCollection)
          .doc(announcementId)
          .update(
            sourceCollection != 'events_announcements'
                ? {
                    'title': title,
                    'content': description,
                    if (category != null) 'category': category,
                    if (priority != null) 'priority': priority,
                    if (status != null) ...{
                      'status': status == 'inactive' ? 'archived' : 'published',
                      'isActive': status != 'inactive',
                    },
                    'updatedAt': FieldValue.serverTimestamp(),
                  }
                : updates,
          );
      print('AnnouncementService: Announcement updated - $announcementId');
    } catch (e) {
      print('AnnouncementService ERROR: Failed to update announcement: $e');
      throw Exception('Failed to update announcement: $e');
    }
  }

  /// Delete announcement
  Future<void> deleteAnnouncement(
    String announcementId, {
    String sourceCollection = 'events_announcements',
  }) async {
    try {
      await _firestore
          .collection(sourceCollection)
          .doc(announcementId)
          .delete();
      print('AnnouncementService: Announcement deleted - $announcementId');
    } catch (e) {
      print('AnnouncementService ERROR: Failed to delete announcement: $e');
      throw Exception('Failed to delete announcement: $e');
    }
  }

  /// Send reminder for announcement (placeholder - implement notification logic)
  Future<void> sendReminder(
    String announcementId, {
    String sourceCollection = 'events_announcements',
  }) async {
    try {
      // TODO: Implement actual notification/reminder logic
      // This could involve:
      // 1. Sending push notifications
      // 2. Sending SMS
      // 3. Sending emails
      // 4. Creating in-app notifications

      print(
        'AnnouncementService: Sending reminder for announcement - $announcementId',
      );

      // For now, just log the action
      await _firestore.collection(sourceCollection).doc(announcementId).update({
        'lastReminderSent': FieldValue.serverTimestamp(),
      });

      print('AnnouncementService: Reminder sent successfully');
    } catch (e) {
      print('AnnouncementService ERROR: Failed to send reminder: $e');
      throw Exception('Failed to send reminder: $e');
    }
  }
}

// ==================== MODELS ====================

class EventModel {
  final String id;
  final String title;
  final String category;
  final String description;
  final DateTime date;
  final String time;
  final String location;
  final int rsvpCount;
  final int totalCapacity;
  final String? imageUrl;
  final String? localImagePath;
  final String status; // upcoming, ongoing, completed, cancelled
  final DateTime? createdAt;
  final DateTime? updatedAt;

  EventModel({
    required this.id,
    required this.title,
    required this.category,
    required this.description,
    required this.date,
    required this.time,
    required this.location,
    required this.rsvpCount,
    required this.totalCapacity,
    this.imageUrl,
    this.localImagePath,
    required this.status,
    this.createdAt,
    this.updatedAt,
  });

  factory EventModel.fromFirestore(String id, Map<String, dynamic> data) {
    return EventModel(
      id: id,
      title: data['title'] ?? '',
      category: data['category'] ?? 'General',
      description: data['description'] ?? '',
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      time: data['time'] ?? '',
      location: data['location'] ?? '',
      rsvpCount: data['rsvpCount'] ?? 0,
      totalCapacity: data['totalCapacity'] ?? 248,
      imageUrl: data['imageUrl'],
      localImagePath: data['localImagePath'],
      status: data['status'] ?? 'upcoming',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'category': category,
      'description': description,
      'date': Timestamp.fromDate(date),
      'time': time,
      'location': location,
      'rsvpCount': rsvpCount,
      'totalCapacity': totalCapacity,
      'imageUrl': imageUrl,
      'localImagePath': localImagePath,
      'status': status,
    };
  }

  bool get hasImage => imageUrl != null || localImagePath != null;

  String get formattedDate {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

class AnnouncementModel {
  final String id;
  final String title;
  final String category;
  final String priority; // high, medium, low
  final String description;
  final String status; // active, archived
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? lastReminderSent;
  final String sourceCollection;
  final List<String> attachments;

  AnnouncementModel({
    required this.id,
    required this.title,
    required this.category,
    required this.priority,
    required this.description,
    required this.status,
    this.createdAt,
    this.updatedAt,
    this.lastReminderSent,
    this.sourceCollection = 'events_announcements',
    this.attachments = const [],
  });

  factory AnnouncementModel.fromFirestore(
    String id,
    Map<String, dynamic> data, {
    String sourceCollection = 'events_announcements',
  }) {
    return AnnouncementModel(
      id: id,
      title: data['title'] ?? '',
      category: data['category'] ?? 'General',
      priority: data['priority'] ?? 'medium',
      description: data['description'] ?? data['content'] ?? '',
      status: data['status'] ?? 'active',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      lastReminderSent: (data['lastReminderSent'] as Timestamp?)?.toDate(),
      sourceCollection: sourceCollection,
      attachments:
          List<String>.from(
            data['attachments'] ?? data['imageUrls'] ?? const [],
          )..addAll(
            data['imageUrl'] is String &&
                    (data['imageUrl'] as String).isNotEmpty
                ? [data['imageUrl'] as String]
                : const [],
          ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'category': category,
      'priority': priority,
      'description': description,
      'status': status,
    };
  }

  String get formattedDate {
    if (createdAt == null) return '';
    return '${createdAt!.year}-${createdAt!.month.toString().padLeft(2, '0')}-${createdAt!.day.toString().padLeft(2, '0')}';
  }
}
