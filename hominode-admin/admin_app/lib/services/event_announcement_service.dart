import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:typed_data';
import 'admin_service.dart';

class EventAnnouncementService {
  EventAnnouncementService({
    FirebaseFirestore? firestore,
    AdminService? adminService,
    FirebaseStorage? storage,
    this.uploadTimeout = const Duration(seconds: 60),
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _adminService = adminService ?? AdminService(),
       _storage = storage;

  final FirebaseFirestore _firestore;
  final AdminService _adminService;
  final FirebaseStorage? _storage;
  final Duration uploadTimeout;
  final _pendingImages = <String, _PendingEventImage>{};
  final _pendingWrites = <String, Future<void>>{};
  final _pendingDeletes = <String, (String, List<String>)>{};

  Future<void> _awaitEventWrite(String id) async {
    final write = _pendingWrites[id];
    if (write == null) return;
    try {
      await write.timeout(uploadTimeout);
    } on TimeoutException {
      // Retain the original write; a retry/cancel must not race its late commit.
      rethrow;
    } catch (_) {
      _pendingWrites.remove(id);
      rethrow;
    }
    _pendingWrites.remove(id);
  }

  Future<Map<String, dynamic>?> _findEvent(
    String id,
    String communityId,
  ) async {
    // Existing Rules do not allow reading a missing unscoped document. A scoped
    // query permits safe recovery without broadening those Rules.
    final result = await _firestore
        .collection(_eventsCollection)
        .where('communityId', isEqualTo: communityId)
        .where('type', isEqualTo: 'event')
        .get(const GetOptions(source: Source.server))
        .timeout(uploadTimeout);
    for (final document in result.docs) {
      if (document.id == id) return document.data();
    }
    return null;
  }

  FirebaseStorage get _eventStorage => _storage ?? FirebaseStorage.instance;

  String newEventId() => _firestore.collection(_eventsCollection).doc().id;

  void _checkEventScope(String uid, String communityId) {
    if (_adminService.getCurrentAdminId() != uid ||
        _adminService.requireCurrentCommunityId() != communityId) {
      throw StateError(
        'Your session or community changed. Reopen the event form.',
      );
    }
  }

  Future<Map<String, dynamic>> _eventAuthority(
    String uid,
    String communityId,
  ) async {
    final profile = await _adminService.getAdminProfile().timeout(
      uploadTimeout,
    );
    _checkEventScope(uid, communityId);
    if (profile == null ||
        profile['uid'] != uid ||
        profile['role'] != 'admin' ||
        profile['isActive'] != true ||
        profile['authorizedCommunityIds'] is! List ||
        !(profile['authorizedCommunityIds'] as List).contains(communityId)) {
      throw StateError(
        'An active administrator for this community is required.',
      );
    }
    // Canonical identity, active community and tenant checks remain authoritative
    // in Firestore/Storage Rules. This client check never grants permission.
    return profile;
  }

  Future<Map<String, String>> _uploadEventImage(
    String eventId,
    File file,
    String uid,
    String communityId,
  ) async {
    final stat = await file.stat();
    const maxBytes = 5 * 1024 * 1024;
    if (stat.size < 1 || stat.size > maxBytes) {
      throw ArgumentError(
        'Choose a JPG, PNG or WebP image no larger than 5 MB.',
      );
    }
    final identity =
        '${file.path}/${stat.size}/${stat.modified.microsecondsSinceEpoch}';
    var pending = _pendingImages[eventId];
    if (pending != null &&
        (pending.uid != uid || pending.communityId != communityId)) {
      throw StateError('This upload belongs to another session or community.');
    }
    if (pending != null && pending.identity != identity) {
      // The caller has just confirmed the event does not exist on the server.
      // Do not discard an old attempt until its unreferenced object is removed.
      try {
        await _eventStorage.ref(pending.path).delete().timeout(uploadTimeout);
      } on FirebaseException catch (error) {
        if (error.code != 'object-not-found') rethrow;
      }
      _pendingImages.remove(eventId);
      pending = null;
    }
    final bytes = <int>[];
    if (pending == null || !pending.stored) {
      await for (final chunk in file.openRead(0, maxBytes + 1)) {
        bytes.addAll(chunk);
      }
      if (bytes.isEmpty || bytes.length > maxBytes) {
        throw ArgumentError('Image size is invalid.');
      }
      final String type, extension;
      if (bytes.length >= 3 &&
          bytes[0] == 255 &&
          bytes[1] == 216 &&
          bytes[2] == 255) {
        type = 'image/jpeg';
        extension = 'jpg';
      } else if (bytes.length >= 8 &&
          bytes.take(8).join(',') == '137,80,78,71,13,10,26,10') {
        type = 'image/png';
        extension = 'png';
      } else if (bytes.length >= 12 &&
          String.fromCharCodes(bytes.take(4)) == 'RIFF' &&
          String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP') {
        type = 'image/webp';
        extension = 'webp';
      } else {
        throw ArgumentError('Choose a JPG, PNG or WebP image.');
      }
      pending ??= _PendingEventImage(
        uid: uid,
        communityId: communityId,
        identity: identity,
        path: 'event_images/$communityId/$eventId/${newEventId()}.$extension',
        contentType: type,
        name: file.uri.pathSegments.last,
      );
      _pendingImages[eventId] = pending;
      _checkEventScope(uid, communityId);
      final task = _eventStorage
          .ref(pending.path)
          .putData(
            Uint8List.fromList(bytes),
            SettableMetadata(contentType: pending.contentType),
          );
      await task
          .then<void>((_) {})
          .timeout(
            uploadTimeout,
            onTimeout: () {
              unawaited(
                task.cancel().then<void>(
                  (_) {},
                  onError: (Object _, StackTrace _) {},
                ),
              );
              throw TimeoutException(
                'Event photo upload timed out. Please retry.',
              );
            },
          );
      pending.stored = true;
    }
    _checkEventScope(uid, communityId);
    pending.url ??= await _eventStorage
        .ref(pending.path)
        .getDownloadURL()
        .timeout(uploadTimeout);
    final uri = Uri.tryParse(pending.url!);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      throw StateError(
        'The event photo URL could not be confirmed. Please retry.',
      );
    }
    _checkEventScope(uid, communityId);
    return {
      'url': pending.url!,
      'storagePath': pending.path,
      'name': pending.name,
    };
  }

  /// Cancel only a confirmed unpublished attempt. Never remove bytes after an
  /// ambiguous save: the transaction might have committed despite a lost reply.
  Future<void> discardEventAttempt(String eventId) async {
    final pending = _pendingImages[eventId];
    if (pending == null) return;
    _checkEventScope(pending.uid, pending.communityId);
    await _awaitEventWrite(eventId);
    final existing = await _findEvent(eventId, pending.communityId);
    _checkEventScope(pending.uid, pending.communityId);
    if (existing == null) {
      try {
        await _eventStorage.ref(pending.path).delete().timeout(uploadTimeout);
      } on FirebaseException catch (error) {
        if (error.code != 'object-not-found') rethrow;
      }
    }
    _pendingImages.remove(eventId);
  }

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

  /// Firebase event URL contract shared with Admin Web. Download URLs are
  /// shareable bearer links for non-sensitive event imagery, not private assets.
  Future<String> createEvent({
    required String title,
    required String category,
    required String description,
    required DateTime date,
    required String time,
    required String location,
    int totalCapacity = 248,
    String? imageUrl,
    File? imageFile,
    String? eventId,
  }) async {
    final uid = _adminService.getCurrentAdminId();
    if (uid == null) throw StateError('Sign in to create an event.');
    final communityId = _adminService.requireCurrentCommunityId();
    final profile = await _eventAuthority(uid, communityId);
    final id = eventId ?? newEventId();
    if (id.isEmpty || id.contains('/') || id == '.' || id == '..') {
      throw ArgumentError('Invalid event ID.');
    }
    final ref = _firestore.collection(_eventsCollection).doc(id);
    await _awaitEventWrite(id);
    final existing = await _findEvent(id, communityId);
    _checkEventScope(uid, communityId);
    void checkExisting(Map<String, dynamic> data) {
      if (data['communityId'] != communityId ||
          data['adminId'] != uid ||
          data['type'] != 'event') {
        throw StateError('This event ID is unavailable.');
      }
    }

    if (existing != null) {
      checkExisting(existing);
      _pendingImages.remove(id);
      return id;
    }
    final legacy = imageUrl == null
        ? <String>[]
        : EventModel.readImageUrls({'imageUrl': imageUrl});
    if (imageUrl != null && imageUrl.isNotEmpty && legacy.isEmpty) {
      throw ArgumentError('The event image must be a network URL.');
    }
    if (imageFile == null && _pendingImages.containsKey(id)) {
      await discardEventAttempt(id);
    }
    final image = imageFile == null
        ? null
        : await _uploadEventImage(id, imageFile, uid, communityId);
    final urls = [if (image != null) image['url']! else ...legacy];
    _checkEventScope(uid, communityId);
    _pendingWrites[id] = ref.set({
      'type': 'event',
      'title': title,
      'category': category,
      'description': description,
      'date': Timestamp.fromDate(date),
      'time': time,
      'location': location,
      'rsvpCount': 0,
      'totalCapacity': totalCapacity,
      'imageUrl': urls.isEmpty ? null : urls.first,
      if (image != null) 'images': [image],
      if (urls.isNotEmpty) 'imageUrls': urls,
      'status': 'upcoming',
      'adminId': uid,
      'communityId': communityId,
      'adminName': profile['name'] ?? '',
      'adminEmail': profile['email'] ?? '',
      'adminPhone': profile['phone'] ?? '',
      'organization': profile['organization'] ?? '',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await _awaitEventWrite(id);
    _checkEventScope(uid, communityId);
    _pendingImages.remove(id);
    return id;
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
      if (imageUrl != null) {
        final urls = EventModel.readImageUrls({'imageUrl': imageUrl});
        if (imageUrl.isNotEmpty && urls.isEmpty) {
          throw ArgumentError('The event image must be a network URL.');
        }
        final uid = _adminService.getCurrentAdminId();
        if (uid == null) throw StateError('Sign in to edit an event image.');
        final community = _adminService.requireCurrentCommunityId();
        final current = await _findEvent(eventId, community);
        _checkEventScope(uid, community);
        final ordered = [
          ...urls,
          if (imageUrl.isNotEmpty && current != null)
            ...EventModel.readImageUrls(
              current,
            ).where((url) => url != imageUrl),
        ];
        updates['imageUrl'] = ordered.isEmpty ? '' : ordered.first;
        updates['imageUrls'] = ordered;
        if (current?['images'] is List) {
          // Preserve each stored object's path/name while following the primary
          // and ordered URL fields consumed by both mobile and Admin Web.
          updates['images'] = [
            for (final url in ordered)
              for (final image in current!['images'] as List)
                if (image is Map && image['url'] == url) image,
          ];
        }
      }
      updates['localImagePath'] = FieldValue.delete();
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

  /// Detach the event first; only then delete its scoped Firebase objects.
  /// Historical external URLs are display-only and are never deleted here.
  Future<void> deleteEvent(String eventId) async {
    final uid = _adminService.getCurrentAdminId();
    if (uid == null) throw StateError('Sign in to delete an event.');
    final communityId = _adminService.requireCurrentCommunityId();
    await _eventAuthority(uid, communityId);
    final pending = _pendingDeletes[eventId];
    if (pending != null && pending.$1 != communityId) {
      throw StateError('This deletion belongs to another community.');
    }
    final event = await _findEvent(eventId, communityId);
    _checkEventScope(uid, communityId);
    final prefix = 'event_images/$communityId/$eventId/';
    final paths = <String>{...?pending?.$2};
    if (event != null) {
      if (event['images'] is List) {
        for (final image in event['images'] as List) {
          final path = image is Map ? image['storagePath'] : null;
          if (path is String &&
              path.startsWith(prefix) &&
              path.substring(prefix.length).isNotEmpty &&
              RegExp(
                r'^[A-Za-z0-9_-]+\.(jpg|jpeg|png|webp)$',
              ).hasMatch(path.substring(prefix.length))) {
            paths.add(path);
          }
        }
      }
      _pendingDeletes[eventId] = (communityId, paths.toList());
      await _firestore
          .collection(_eventsCollection)
          .doc(eventId)
          .delete()
          .timeout(uploadTimeout);
    }
    for (final path in paths) {
      _checkEventScope(uid, communityId);
      try {
        await _eventStorage.ref(path).delete().timeout(uploadTimeout);
      } on FirebaseException catch (error) {
        if (error.code != 'object-not-found') rethrow;
      }
    }
    _pendingDeletes.remove(eventId);
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
  // Kept for source compatibility only; device-local paths are not shared media.
  final String? localImagePath;
  final List<String> imageUrls;
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
    this.imageUrls = const [],
    required this.status,
    this.createdAt,
    this.updatedAt,
  });

  static List<String> readImageUrls(Map<String, dynamic> data) {
    final values = <Object?>[
      if (data['imageUrls'] is List) ...data['imageUrls'] as List,
      if (data['images'] is List)
        for (final image in data['images'] as List)
          if (image is Map) image['url'],
      data['imageUrl'],
    ];
    final result = <String>[];
    for (final value in values) {
      if (value is! String) continue;
      final url = value.trim();
      final uri = Uri.tryParse(url);
      if (uri != null &&
          ['https', 'http'].contains(uri.scheme) &&
          uri.host.isNotEmpty &&
          !result.contains(url)) {
        result.add(url);
      }
    }
    return result;
  }

  factory EventModel.fromFirestore(String id, Map<String, dynamic> data) {
    final urls = readImageUrls(data);
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
      imageUrl: urls.isEmpty ? null : urls.first,
      imageUrls: urls,
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
      if (imageUrls.isNotEmpty) 'imageUrls': imageUrls,
      'status': status,
    };
  }

  bool get hasImage => imageUrl != null || imageUrls.isNotEmpty;

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

class _PendingEventImage {
  _PendingEventImage({
    required this.uid,
    required this.communityId,
    required this.identity,
    required this.path,
    required this.contentType,
    required this.name,
  });
  final String uid, communityId, identity, path, contentType, name;
  bool stored = false;
  String? url;
}
