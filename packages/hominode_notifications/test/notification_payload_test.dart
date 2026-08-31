import 'package:flutter_test/flutter_test.dart';
import 'package:hominode_notifications/hominode_notifications.dart';

void main() {
  test('accepts only the V1 allowlisted payload', () {
    final payload = HominodeNotificationPayload.tryParse({
      'type': 'notification',
      'entityId': 'notification-1',
      'communityId': 'community-1',
    });

    expect(payload?.entityId, 'notification-1');
  });

  test('rejects arbitrary routes and extra payload fields', () {
    expect(
      HominodeNotificationPayload.tryParse({
        'type': 'notification',
        'entityId': 'notification-1',
        'communityId': 'community-1',
        'route': '/admin/users',
      }),
      isNull,
    );
  });

  test('rejects unsupported notification types', () {
    expect(
      HominodeNotificationPayload.tryParse({
        'type': 'open_route',
        'entityId': 'notification-1',
        'communityId': 'community-1',
      }),
      isNull,
    );
  });
}
