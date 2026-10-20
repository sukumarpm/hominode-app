// lib/src/services/announcements_events_service.dart
// Service for fetching tenant-scoped announcements and events from Firestore

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../models/announcement_model.dart';
import '../models/event_model.dart';
import 'subscription_entitlement_service.dart';

class AnnouncementsEventsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Fresh read for list taps and notification deep links; never trust a pushed
  /// community or an old card as proof of event access.
  Future<EventModel?> getEvent(String eventId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || eventId.isEmpty || eventId.contains('/')) return null;
    final community = await currentCommunityId();
    if (community == null || !await eventsAllowed(community)) return null;
    final document = await _firestore
        .collection('events_announcements')
        .doc(eventId)
        .get(const GetOptions(source: Source.server))
        .timeout(const Duration(seconds: 20));
    final data = document.data();
    if (_auth.currentUser?.uid != uid ||
        await currentCommunityId() != community ||
        data == null ||
        data['communityId'] != community ||
        data['type'] != 'event') {
      return null;
    }
    return EventModel.fromFirestore(document);
  }

  Query<Map<String, dynamic>> _visibleEventsQuery(String communityId) {
    return _firestore
        .collection('events_announcements')
        .where('communityId', isEqualTo: communityId)
        .where('type', isEqualTo: 'event');
  }

  Future<bool> eventsAllowed(String communityId) async {
    final entitlement = await ResidentSubscriptionEntitlementService()
        .getEntitlement(communityId);
    return entitlement?.canUseFeature('events') == true;
  }

  /// Get current resident's community ID
  Future<String?> _getCurrentCommunityId() async {
    final user = _auth.currentUser;

    if (user == null) {
      print('❌ AnnouncementsEventsService: User not authenticated');
      return null;
    }

    final userDoc = await _firestore.collection('users').doc(user.uid).get();

    if (!userDoc.exists) {
      print('❌ AnnouncementsEventsService: User document not found');
      return null;
    }

    final data = userDoc.data();
    final communityId = data?['communityId'] as String?;

    if (communityId == null || communityId.isEmpty) {
      print(
        '❌ AnnouncementsEventsService: communityId missing for ${user.uid}',
      );
      return null;
    }

    return communityId;
  }

  Future<String?> currentCommunityId() => _getCurrentCommunityId();

  /// Stream active announcements for current resident's community
  Stream<List<AnnouncementModel>> streamAnnouncements() async* {
    try {
      final communityId = await _getCurrentCommunityId();

      if (communityId == null) {
        yield [];
        return;
      }

      final user = _auth.currentUser;
      if (user == null) {
        yield [];
        return;
      }
      final profile = await _firestore.collection('users').doc(user.uid).get();
      final flatId = profile.data()?['flatId'] as String?;
      if (flatId == null ||
          flatId.isEmpty ||
          profile.data()?['communityId'] != communityId) {
        yield [];
        return;
      }

      final response = await FirebaseFunctions.instanceFor(
        region: 'asia-southeast1',
      ).httpsCallable('getResidentNoticeIds').call();
      final result = Map<String, dynamic>.from(response.data as Map);
      if (result['communityId'] != communityId || result['flatId'] != flatId) {
        throw StateError('Resident announcement scope could not be verified.');
      }

      final output = StreamController<List<AnnouncementModel>>();
      final canonical = <String, AnnouncementModel>{};
      final oldAnnouncements = <String, AnnouncementModel>{};
      final legacy = <String, AnnouncementModel>{};
      void publish() {
        final values = <AnnouncementModel>[
          ...canonical.values,
          ...oldAnnouncements.values,
          ...legacy.values,
        ];
        final seen = <String>{};
        final unique = values.where((item) {
          final signature =
              '${item.title.trim().toLowerCase()}\u0000'
              '${item.description.trim().toLowerCase()}\u0000'
              '${item.createdAt.year}-${item.createdAt.month}-${item.createdAt.day}';
          return seen.add(signature);
        }).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        output.add(unique);
      }

      final subscriptions = <StreamSubscription<dynamic>>[];
      subscriptions.add(
        _firestore
            .collection('events_announcements')
            .where('communityId', isEqualTo: communityId)
            .where('type', isEqualTo: 'announcement')
            .snapshots()
            .map((snapshot) {
              canonical
                ..clear()
                ..addEntries(
                  snapshot.docs
                      .where((doc) {
                        final data = doc.data();
                        final expiry = data['expiresAt'] ?? data['expiryDate'];
                        final expiryDate = expiry is Timestamp
                            ? expiry.toDate()
                            : null;
                        final targets = List<String>.from(
                          data['targetFlats'] ?? const [],
                        );
                        return (data['status'] == 'active' ||
                                data['status'] == 'published') &&
                            (expiryDate == null ||
                                !expiryDate.isBefore(DateTime.now())) &&
                            (targets.isEmpty || targets.contains(flatId));
                      })
                      .map(
                        (doc) => MapEntry(
                          doc.id,
                          AnnouncementModel.fromFirestore(doc),
                        ),
                      ),
                );
              publish();
              return snapshot;
            })
            .listen((_) {}, onError: output.addError),
      );

      subscriptions.add(
        _firestore
            .collection('announcements')
            .where('communityId', isEqualTo: communityId)
            .snapshots()
            .listen((snapshot) {
              oldAnnouncements
                ..clear()
                ..addEntries(
                  snapshot.docs
                      .where((doc) {
                        final data = doc.data();
                        final expiry = data['expiresAt'] ?? data['expiryDate'];
                        final expiryDate = expiry is Timestamp
                            ? expiry.toDate()
                            : null;
                        return (data['status'] == 'active' ||
                                data['status'] == 'published') &&
                            (expiryDate == null ||
                                !expiryDate.isBefore(DateTime.now()));
                      })
                      .map(
                        (doc) => MapEntry(
                          doc.id,
                          AnnouncementModel.fromFirestore(doc),
                        ),
                      ),
                );
              publish();
            }, onError: output.addError),
      );

      final ids = (result['noticeIds'] as List<dynamic>? ?? const [])
          .map((value) => value.toString())
          .where((id) => id.isNotEmpty)
          .toSet();
      for (final id in ids) {
        subscriptions.add(
          _firestore.collection('notices').doc(id).snapshots().listen((doc) {
            final data = doc.data();
            legacy.remove(id);
            if (data != null &&
                doc.exists &&
                data['communityId'] == communityId) {
              final active =
                  data['isActive'] == true || data['status'] == 'published';
              final expiry = data['expiryDate'] ?? data['expiresAt'];
              final expiryDate = expiry is Timestamp ? expiry.toDate() : null;
              if (active &&
                  (expiryDate == null ||
                      !expiryDate.isBefore(DateTime.now()))) {
                final createdAt =
                    data['createdAt'] as Timestamp? ??
                    data['publishDate'] as Timestamp?;
                legacy[id] = AnnouncementModel(
                  id: 'notices:$id',
                  title: data['title']?.toString() ?? '',
                  description:
                      data['content']?.toString() ??
                      data['description']?.toString() ??
                      '',
                  category: data['category']?.toString() ?? 'General',
                  priority: data['priority']?.toString() ?? 'medium',
                  status: 'active',
                  createdAt: createdAt?.toDate() ?? DateTime.now(),
                  updatedAt:
                      (data['updatedAt'] as Timestamp?)?.toDate() ??
                      DateTime.now(),
                  attachments: List<String>.from(
                    data['attachments'] ?? const [],
                  ),
                  authorName:
                      data['authorName']?.toString() ??
                      data['adminName']?.toString() ??
                      '',
                );
              }
            }
            publish();
          }, onError: output.addError),
        );
      }
      if (ids.isEmpty) publish();

      try {
        yield* output.stream;
      } finally {
        for (final subscription in subscriptions) {
          await subscription.cancel();
        }
        await output.close();
      }
    } catch (e) {
      print('❌ Error starting announcements stream: $e');
      rethrow;
    }
  }

  /// Stream published events for current resident's community
  Stream<List<EventModel>> streamEvents() async* {
    try {
      final communityId = await _getCurrentCommunityId();

      if (communityId == null) {
        yield [];
        return;
      }

      if (!await eventsAllowed(communityId)) {
        throw StateError('Events are not available for this community plan.');
      }

      print('📅 Streaming events for community: $communityId');

      yield* _visibleEventsQuery(communityId).snapshots().map((snapshot) {
        final events = snapshot.docs
            .map((doc) => EventModel.fromFirestore(doc))
            .toList();

        events.sort((a, b) {
          final aDate = a.eventDate ?? a.createdAt;
          final bDate = b.eventDate ?? b.createdAt;
          return aDate.compareTo(bDate);
        });

        print('✅ Streamed ${events.length} events');

        return events;
      });
    } catch (e) {
      print('❌ Error starting events stream: $e');
      rethrow;
    }
  }

  /// Count events visible under the same tenant and status rules as streamEvents.
  Future<int> getVisibleEventsCount(String communityId) async {
    if (communityId.isEmpty) return 0;

    final snapshot = await _visibleEventsQuery(communityId).count().get();
    return snapshot.count ?? 0;
  }
}
