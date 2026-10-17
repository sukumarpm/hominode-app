import 'package:flutter_test/flutter_test.dart';
import 'package:resident_app/src/services/resident_notification_router.dart';
import 'package:hominode_notifications/hominode_notifications.dart';

void main() {
  const resident = 'resident-1';
  const community = 'community-1';

  Map<String, dynamic> profile({
    String uid = resident,
    String cid = community,
  }) => {
    'uid': uid,
    'role': 'resident',
    'approvalStatus': 'approved',
    'isActive': true,
    'status': 'active',
    'communityId': cid,
  };

  Map<String, dynamic> notification({
    String uid = resident,
    String cid = community,
    String type = 'payment',
    String? eventType = 'payment_proof_verified',
    Object? route = 'billing',
  }) => {
    'recipientId': uid,
    'communityId': cid,
    'audience': 'resident',
    'role': 'resident',
    'appId': 'resident',
    'type': type,
    if (eventType != null) 'eventType': eventType,
    'data': {if (route != null) 'route': route},
  };

  test('authorized V2 payment lifecycle notifications route to Billing', () {
    final doc = notification(eventType: 'payment_proof_submitted');
    expect(
      ResidentNotificationRouter.isAuthorizedNotification(
        uid: resident,
        payloadCommunityId: community,
        profile: profile(),
        notification: doc,
      ),
      isTrue,
    );
    expect(
      ResidentNotificationRouter.destinationForNotification(doc),
      ResidentNotificationDestination.billing,
    );
  });

  test('resident and community mismatches fail authorization', () {
    expect(
      ResidentNotificationRouter.isAuthorizedNotification(
        uid: resident,
        payloadCommunityId: community,
        profile: profile(),
        notification: notification(uid: 'other-resident'),
      ),
      isFalse,
    );
    expect(
      ResidentNotificationRouter.isAuthorizedNotification(
        uid: resident,
        payloadCommunityId: 'other-community',
        profile: profile(),
        notification: notification(),
      ),
      isFalse,
    );
  });

  test('missing payment metadata falls back to Notifications', () {
    expect(
      ResidentNotificationRouter.destinationForNotification(
        notification(eventType: null),
      ),
      ResidentNotificationDestination.notifications,
    );
    expect(
      ResidentNotificationRouter.destinationForNotification(
        notification(route: null),
      ),
      ResidentNotificationDestination.notifications,
    );
  });

  test('nonpayment notifications preserve the Notices fallback', () {
    expect(
      ResidentNotificationRouter.destinationForNotification(
        notification(type: 'announcement', eventType: null, route: null),
      ),
      ResidentNotificationDestination.notifications,
    );
  });

  test('tap guard suppresses concurrent and repeated notification taps', () {
    final guard = ResidentNotificationTapGuard();
    const key = 'notification|payment-event|community-1';
    expect(guard.begin(key), isTrue);
    expect(guard.begin(key), isFalse);
    guard.complete(key);
    expect(guard.begin(key), isFalse);
    guard.release(key);
  });

  test(
    'reduced push payload retains server-provided Billing routing hints',
    () {
      final payload = HominodeNotificationPayload.tryParse({
        'type': 'notification',
        'entityId': 'payment-event',
        'communityId': community,
        'eventType': 'payment_proof_verified',
        'route': 'billing',
      });
      expect(payload?.eventType, 'payment_proof_verified');
      expect(payload?.route, 'billing');
      expect(payload?.toJson(), {
        'type': 'notification',
        'entityId': 'payment-event',
        'communityId': community,
        'eventType': 'payment_proof_verified',
        'route': 'billing',
      });
    },
  );
}
