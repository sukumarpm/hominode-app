import 'package:cloud_functions/cloud_functions.dart';

class SecurityVisitorSummary {
  const SecurityVisitorSummary({
    required this.communityId,
    required this.timeZone,
    required this.localDate,
    required this.refreshedAt,
    required this.totalToday,
    required this.activeInside,
    required this.pendingRequests,
    required this.exitsToday,
  });

  final String communityId;
  final String timeZone;
  final String localDate;
  final DateTime refreshedAt;
  final int totalToday, activeInside, pendingRequests, exitsToday;

  factory SecurityVisitorSummary.fromMap(Map<String, dynamic> data) {
    String text(String key) {
      final value = data[key];
      if (value is! String || value.trim().isEmpty) {
        throw const FormatException('Visitor summary is unavailable.');
      }
      return value;
    }

    int count(String key) {
      final value = data[key];
      if (value is! int || value < 0) {
        throw const FormatException('Visitor count is unavailable.');
      }
      return value;
    }

    final refreshedAt = data['refreshedAt'];
    if (refreshedAt is! int || refreshedAt <= 0) {
      throw const FormatException('Visitor summary time is unavailable.');
    }
    return SecurityVisitorSummary(
      communityId: text('communityId'),
      timeZone: text('timeZone'),
      localDate: text('localDate'),
      refreshedAt: DateTime.fromMillisecondsSinceEpoch(
        refreshedAt,
        isUtc: true,
      ),
      totalToday: count('totalToday'),
      activeInside: count('activeInside'),
      pendingRequests: count('pendingRequests'),
      exitsToday: count('exitsToday'),
    );
  }
}

typedef SummaryCallable =
    Future<Object?> Function(String name, Map<String, dynamic> payload);

class SecurityVisitorSummaryService {
  SecurityVisitorSummaryService({SummaryCallable? invoke})
    : _invoke = invoke ?? _call;
  final SummaryCallable _invoke;

  static Future<Object?> _call(
    String name,
    Map<String, dynamic> payload,
  ) async => (await FirebaseFunctions.instanceFor(
    region: 'asia-southeast1',
  ).httpsCallable(name).call(payload)).data;

  Future<SecurityVisitorSummary> load() async {
    // Staff identity and community scope are resolved exclusively on the server.
    final response = await _invoke('getSecurityVisitorSummary', {});
    if (response is! Map) {
      throw const FormatException('Visitor summary is unavailable.');
    }
    return SecurityVisitorSummary.fromMap(Map<String, dynamic>.from(response));
  }
}
