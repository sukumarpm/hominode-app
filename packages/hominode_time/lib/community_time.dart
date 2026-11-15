import 'package:timezone/data/latest.dart' as zones;
import 'package:timezone/timezone.dart' as tz;

/// Community wall time is never inferred from the device, GPS, or country.
/// Date-only picker values are calendar components, not event instants.
class CommunityTime {
  static bool _initialized = false;
  static String canonical(String? zone) {
    if (zone == null || zone.trim().isEmpty) {
      throw const FormatException(
        'Community timezone is not configured. Contact your Community Admin.',
      );
    }
    if (!_initialized) {
      zones.initializeTimeZones();
      _initialized = true;
    }
    final name = zone.trim() == 'Asia/Calcutta' ? 'Asia/Kolkata' : zone.trim();
    try {
      tz.getLocation(name);
    } on tz.LocationNotFoundException {
      throw FormatException(
        'Unsupported community timezone: $zone. Contact your Community Admin.',
      );
    }
    return name;
  }

  static tz.TZDateTime inZone(DateTime instant, String? zone) =>
      tz.TZDateTime.from(instant, tz.getLocation(canonical(zone)));

  static String local(DateTime instant, String? zone) {
    final d = inZone(instant, zone);
    return '${d.year.toString().padLeft(4, '0')}-${_two(d.month)}-${_two(d.day)}T${_two(d.hour)}:${_two(d.minute)}';
  }

  /// Reject DST gaps and folds: do not silently normalize or guess an offset.
  static DateTime instant(String value, String? zone) {
    final location = tz.getLocation(canonical(zone));
    if (!RegExp(r'^\d{4}-\d\d-\d\dT\d\d:\d\d$').hasMatch(value)) {
      throw const FormatException('Enter a complete date and time.');
    }
    final naive = DateTime.tryParse('$value:00Z');
    if (naive == null || naive.toIso8601String().substring(0, 16) != value) {
      throw const FormatException('Choose a valid date and time.');
    }
    final offsets = <int>{};
    for (int h = -48; h <= 48; h += 6) {
      offsets.add(
        tz.TZDateTime.fromMillisecondsSinceEpoch(
          location,
          naive.millisecondsSinceEpoch + h * 3600000,
        ).timeZoneOffset.inMilliseconds,
      );
    }
    final matches = offsets
        .map(
          (offset) => DateTime.fromMillisecondsSinceEpoch(
            naive.millisecondsSinceEpoch - offset,
            isUtc: true,
          ),
        )
        .where((candidate) => local(candidate, zone) == value)
        .toList();
    if (matches.length != 1) {
      throw const FormatException(
        'This community-local time is skipped or repeated by daylight saving. Choose an unambiguous time.',
      );
    }
    return matches.single;
  }

  /// UTC is used only as a date-only container; never submit it as an event.
  static DateTime calendarDate(DateTime instant, String? zone) {
    final d = inZone(instant, zone);
    return DateTime.utc(d.year, d.month, d.day);
  }

  static int dayDifference(DateTime instant, DateTime now, String? zone) =>
      calendarDate(instant, zone).difference(calendarDate(now, zone)).inDays;

  static String label(String? zone, {DateTime? at}) {
    final name = canonical(zone);
    final d = inZone(at ?? DateTime.now(), name);
    return 'Community time · $name (${d.timeZoneName})';
  }

  static String format(
    DateTime? instant,
    String? zone, {
    String Function(DateTime)? dateFormat,
  }) {
    if (instant == null) return '—';
    try {
      final d = inZone(instant, zone);
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      final date =
          dateFormat?.call(d) ??
          '${d.day} ${months[d.month - 1]} ${d.year}, ${d.hour % 12 == 0 ? 12 : d.hour % 12}:${_two(d.minute)} ${d.hour < 12 ? 'AM' : 'PM'}';
      return '$date ${d.timeZoneName} (${canonical(zone)})';
    } on FormatException catch (error) {
      return error.message;
    }
  }

  static String _two(int value) => '$value'.padLeft(2, '0');
}
