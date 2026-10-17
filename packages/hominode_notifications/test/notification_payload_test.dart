import 'dart:convert';

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

  test('preserves the allowlisted Billing V2 routing hints', () {
    final payload = HominodeNotificationPayload.tryParse({
      'type': 'notification',
      'entityId': 'notification-1',
      'communityId': 'community-1',
      'eventType': 'payment_proof_verified',
      'route': 'billing',
    });

    expect(payload?.eventType, 'payment_proof_verified');
    expect(payload?.route, 'billing');
    expect(payload?.toJson()['route'], 'billing');
    final restored = HominodeNotificationPayload.tryParseJson(
      jsonEncode(payload!.toJson()),
    );
    expect(restored?.eventType, 'payment_proof_verified');
    expect(restored?.route, 'billing');
  });

  test(
    'still rejects unrecognized payload fields and malformed routing hints',
    () {
      expect(
        HominodeNotificationPayload.tryParse({
          'type': 'notification',
          'entityId': 'notification-1',
          'communityId': 'community-1',
          'admin': 'true',
        }),
        isNull,
      );
      expect(
        HominodeNotificationPayload.tryParse({
          'type': 'notification',
          'entityId': 'notification-1',
          'communityId': 'community-1',
          'eventType': '',
        }),
        isNull,
      );
    },
  );

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
