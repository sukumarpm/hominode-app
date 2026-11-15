import 'package:test/test.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:hominode_time/community_time.dart';

void main() {
  test(
    'community appointments ignore the device zone, round-trip exactly once',
    () {
      CommunityTime.canonical('Asia/Kolkata');
      for (final device in [
        'Asia/Manila',
        'Asia/Kolkata',
        'America/New_York',
      ]) {
        tz.setLocalLocation(tz.getLocation(device));
        final cases = {
          'Asia/Kolkata': ['2026-11-14T22:32', '2026-11-14T17:02:00Z'],
          'Asia/Manila': ['2026-11-15T01:02', '2026-11-14T17:02:00Z'],
          'America/New_York': ['2026-11-14T22:32', '2026-11-15T03:32:00Z'],
        };
        for (final entry in cases.entries) {
          final instant = CommunityTime.instant(entry.value[0], entry.key);
          expect(instant, DateTime.parse(entry.value[1]));
          expect(instant.isUtc, isTrue);
          expect(CommunityTime.local(instant, entry.key), entry.value[0]);
          expect(
            CommunityTime.inZone(
              CommunityTime.inZone(instant, entry.key),
              entry.key,
            ).millisecondsSinceEpoch,
            instant.millisecondsSinceEpoch,
          );
        }
      }
    },
  );
  test(
    'London and New York gaps and folds reject; adjacent minutes resolve',
    () {
      for (final entry in {
        'Europe/London': ['2026-03-29T01:30', '2026-10-25T01:30'],
        'America/New_York': ['2026-03-08T02:30', '2026-11-01T01:30'],
      }.entries) {
        for (final wall in entry.value) {
          expect(
            () => CommunityTime.instant(wall, entry.key),
            throwsFormatException,
          );
        }
      }
      expect(
        CommunityTime.instant('2026-03-29T02:30', 'Europe/London'),
        DateTime.parse('2026-03-29T01:30Z'),
      );
      expect(
        CommunityTime.instant('2026-10-25T02:30', 'Europe/London'),
        DateTime.parse('2026-10-25T02:30Z'),
      );
    },
  );
  test(
    'community calendar controls Today/Tomorrow across device midnight and DST',
    () {
      final now = DateTime.parse('2026-11-14T17:02Z'); // Nov 15 in Manila
      expect(CommunityTime.dayDifference(now, now, 'Asia/Kolkata'), 0);
      expect(
        CommunityTime.dayDifference(
          DateTime.parse('2026-11-14T18:31Z'),
          now,
          'Asia/Kolkata',
        ),
        1,
      );
      expect(
        CommunityTime.dayDifference(
          DateTime.parse('2026-03-30T00:00Z'),
          DateTime.parse('2026-03-28T23:30Z'),
          'Europe/London',
        ),
        2,
      );
    },
  );
  test('aliases, missing zones, fixed offsets, invalid dates', () {
    expect(CommunityTime.canonical(' Asia/Calcutta '), 'Asia/Kolkata');
    for (final zone in [null, '', 'Invalid/Zone', '+05:30']) {
      expect(
        () => CommunityTime.instant('2026-11-14T22:32', zone),
        throwsFormatException,
      );
      expect(
        () => CommunityTime.local(DateTime.now(), zone),
        throwsFormatException,
      );
      expect(
        CommunityTime.format(DateTime.now(), zone),
        contains('Community Admin'),
      );
    }
    expect(
      () => CommunityTime.instant('2026-02-30T12:00', 'Asia/Kolkata'),
      throwsFormatException,
    );
  });
  test(
    'all roles receive identical canonical display without changing stored seconds',
    () {
      final instant = DateTime.parse('2026-11-14T17:02:47Z');
      expect(
        CommunityTime.format(instant, 'Asia/Calcutta'),
        '14 Nov 2026, 10:32 PM IST (Asia/Kolkata)',
      );
      expect(
        CommunityTime.format(instant, 'Asia/Calcutta'),
        CommunityTime.format(instant.toLocal(), 'Asia/Kolkata'),
      );
      expect(CommunityTime.inZone(instant, 'Asia/Kolkata').second, 47);
    },
  );
}
