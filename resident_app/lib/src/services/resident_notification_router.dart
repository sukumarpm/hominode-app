import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:hominode_notifications/hominode_notifications.dart';
import 'package:hominode_sos/hominode_sos.dart';

import '../screens/notifications_screen.dart';
import '../../events_announcements_screen.dart';
import 'notice_firestore_service.dart';
import '../../resident_billing_statement_screen.dart';

final residentNotificationNavigatorKey = GlobalKey<NavigatorState>();

enum ResidentNotificationDestination { billing, sos, events, notifications }

class ResidentNotificationTapGuard {
  final Set<String> _inFlight = <String>{};
  final Set<String> _handled = <String>{};

  bool begin(String key) => !_handled.contains(key) && _inFlight.add(key);

  void complete(String key) {
    _inFlight.remove(key);
    _handled.add(key);
    if (_handled.length > 100) _handled.remove(_handled.first);
  }

  void release(String key) => _inFlight.remove(key);
}

class ResidentNotificationRouter {
  const ResidentNotificationRouter._();

  static final ResidentNotificationTapGuard _tapGuard =
      ResidentNotificationTapGuard();
  static const Set<String> _billingEventTypes = {
    'payment_proof_submitted',
    'payment_proof_verified',
    'payment_proof_rejected',
    'offline_payment_settled',
  };

  @visibleForTesting
  static bool isAuthorizedNotification({
    required String uid,
    required String payloadCommunityId,
    required Map<String, dynamic>? profile,
    required Map<String, dynamic>? notification,
  }) {
    final canonicalCommunityId = profile?['communityId'];
    return profile != null &&
        profile['uid'] == uid &&
        profile['role'] == 'resident' &&
        profile['approvalStatus'] == 'approved' &&
        profile['isActive'] == true &&
        (profile['status'] == null || profile['status'] == 'active') &&
        canonicalCommunityId == payloadCommunityId &&
        notification != null &&
        notification['recipientId'] == uid &&
        notification['communityId'] == canonicalCommunityId &&
        notification['audience'] == 'resident' &&
        notification['role'] == 'resident' &&
        notification['appId'] == 'resident';
  }

  @visibleForTesting
  static ResidentNotificationDestination destinationForNotification(
    Map<String, dynamic> notification, {
    bool isSos = false,
  }) {
    final data = notification['data'];
    final eventType = notification['eventType'];
    if (notification['type'] == 'payment' &&
        eventType is String &&
        _billingEventTypes.contains(eventType) &&
        data is Map &&
        data['route'] == 'billing') {
      return ResidentNotificationDestination.billing;
    }
    if (notification['type'] == 'event' &&
        eventType == 'community_event_created' &&
        data is Map &&
        data['route'] == 'events' &&
        data['eventId'] is String &&
        (data['eventId'] as String).isNotEmpty &&
        !(data['eventId'] as String).contains('/')) {
      return ResidentNotificationDestination.events;
    }
    return isSos
        ? ResidentNotificationDestination.sos
        : ResidentNotificationDestination.notifications;
  }

  static Future<NavigatorState?> _waitForNavigator() async {
    for (var attempt = 0; attempt < 20; attempt++) {
      final navigator = residentNotificationNavigatorKey.currentState;
      if (navigator != null) return navigator;

      await Future<void>.delayed(const Duration(milliseconds: 150));
    }

    return residentNotificationNavigatorKey.currentState;
  }

  static Future<void> handle(HominodeNotificationPayload payload) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final tapKey = payload.dedupeKey;
    if (!_tapGuard.begin(tapKey)) return;

    try {
      final firestore = FirebaseFirestore.instance;
      final results = await Future.wait([
        firestore
            .collection('users')
            .doc(user.uid)
            .get(const GetOptions(source: Source.server)),
        firestore
            .collection('notifications')
            .doc(payload.entityId)
            .get(const GetOptions(source: Source.server)),
      ]);
      final profile = results[0].data();
      final notification = results[1].data();
      if (FirebaseAuth.instance.currentUser?.uid != user.uid ||
          notification == null ||
          !isAuthorizedNotification(
            uid: user.uid,
            payloadCommunityId: payload.communityId,
            profile: profile,
            notification: notification,
          )) {
        return;
      }

      final navigator = await _waitForNavigator();
      if (navigator == null) {
        throw StateError('Resident navigation is not ready.');
      }
      if (FirebaseAuth.instance.currentUser?.uid != user.uid) return;

      final sosId = sosAlertIdFromNotification(notification);
      final destination = destinationForNotification(
        notification,
        isSos: sosId != null,
      );
      if (destination == ResidentNotificationDestination.billing) {
        await navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => const ResidentBillingStatementScreen(),
          ),
        );
      } else if (destination == ResidentNotificationDestination.events) {
        await NoticeFirestoreService.instance.markAsRead(
          '${NoticeFirestoreService.eventNotificationPrefix}${payload.entityId}',
        );
        await navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => EventsAnnouncementsScreen(
              eventsOnly: true,
              eventId: (notification['data'] as Map)['eventId'] as String,
            ),
          ),
        );
      } else if (destination == ResidentNotificationDestination.sos &&
          sosId != null) {
        await navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => SosDetailPage(
              communityId: payload.communityId,
              alertId: sosId,
              responder: false,
            ),
          ),
        );
      } else {
        await navigator.push(
          MaterialPageRoute<void>(builder: (_) => const NotificationsScreen()),
        );
      }

      _tapGuard.complete(tapKey);
    } finally {
      _tapGuard.release(tapKey);
    }
  }
}
