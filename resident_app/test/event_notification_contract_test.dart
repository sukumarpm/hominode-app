import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resident_app/src/services/notice_firestore_service.dart';
import 'package:resident_app/src/services/resident_notification_router.dart';
import 'package:resident_app/src/services/notification_preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Map<String, dynamic> event() => {
    'recipientId': 'resident',
    'communityId': 'community',
    'audience': 'resident',
    'role': 'resident',
    'appId': 'resident',
    'type': 'event',
    'eventType': 'community_event_created',
    'title': 'Synthetic event',
    'message': 'Open event details',
    'createdAt': Timestamp.fromDate(DateTime(2026, 10, 20)),
    'data': {'route': 'events', 'eventId': 'event-1'},
  };
  test(
    'canonical inbox adapter preserves event identity, title and ordering date',
    () {
      final notice = NoticeFirestoreService.eventNotice(
        'notification-1',
        event(),
        'resident',
        'community',
      );
      expect(notice?.id, 'notification:notification-1');
      expect(notice?.eventId, 'event-1');
      expect(notice?.title, 'Synthetic event');
      expect(notice?.publishDate, DateTime(2026, 10, 20));
      expect(notice?.copyWith(title: 'Updated').eventId, 'event-1');
      expect(
        ResidentNotificationRouter.destinationForNotification(event()),
        ResidentNotificationDestination.events,
      );
    },
  );
  test(
    'foreign recipients, communities and malformed deep links are rejected',
    () {
      for (final change in [
        {'recipientId': 'other'},
        {'communityId': 'other'},
        {'audience': 'admin'},
        {'role': 'admin'},
        {'appId': 'admin'},
        {
          'data': {'route': 'events', 'eventId': 'foreign/path'},
        },
        {
          'data': {'route': 'events'},
        },
      ]) {
        expect(
          NoticeFirestoreService.eventNotice(
            'id',
            {...event(), ...change},
            'resident',
            'community',
          ),
          isNull,
        );
      }
      expect(
        ResidentNotificationRouter.destinationForNotification({
          ...event(),
          'data': {'route': 'events', 'eventId': '../other'},
        }),
        ResidentNotificationDestination.notifications,
      );
    },
  );
  test(
    'preferences persist per resident and reach the registration contract',
    () async {
      SharedPreferences.setMockInitialValues({});
      String? uid = 'resident';
      var refreshes = 0;
      final service = NotificationPreferencesService.forTesting(
        currentUid: () => uid,
        refreshRegistration: () async {
          refreshes++;
        },
      );
      await service.savePreference('push_notifications', false);
      await service.savePreference('event_reminders', false);
      await service.saveTimePreference('dnd_start_hour', 21);
      expect(await service.isPushEnabled(), isFalse);
      expect(
        (await service.registrationPreferences())['event_reminders'],
        false,
      );
      expect((await service.registrationPreferences())['dnd_start_hour'], 21);
      expect(refreshes, 3);
      uid = 'other';
      expect(await service.isPushEnabled(), isTrue);
      uid = null;
      await expectLater(
        service.savePreference('push_notifications', false),
        throwsStateError,
      );
    },
  );
  test(
    'failed registration rolls back the preference instead of promising opt-out',
    () async {
      SharedPreferences.setMockInitialValues({});
      final service = NotificationPreferencesService.forTesting(
        currentUid: () => 'resident',
        refreshRegistration: () async {
          throw StateError('synthetic failure');
        },
      );
      await expectLater(
        service.savePreference('push_notifications', false),
        throwsStateError,
      );
      expect(await service.isPushEnabled(), isTrue);
      await expectLater(
        service.saveTimePreference('dnd_end_hour', 99),
        throwsArgumentError,
      );
    },
  );
}
