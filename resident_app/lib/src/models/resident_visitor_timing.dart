/// Server-owned refresh deadlines. The device wall clock never grants a pass.
class ResidentVisitorTiming {
  ResidentVisitorTiming.fromMap(
    Map<dynamic, dynamic> value, {
    Stopwatch? elapsed,
  }) : serverTime = _instant(value['serverTime']),
       revalidateAt = value['revalidateAt'] == null
           ? null
           : _instant(value['revalidateAt']),
       _elapsed = elapsed ?? (Stopwatch()..start()) {
    if (!value.containsKey('revalidateAt') ||
        (revalidateAt != null && revalidateAt! <= serverTime)) {
      throw StateError(
        'Visitor pass timing is unavailable. Reload to check availability.',
      );
    }
  }

  final int serverTime;
  final int? revalidateAt;
  final Stopwatch _elapsed;

  static int _instant(dynamic value) {
    if (value is! int || value < 0) {
      throw StateError(
        'Visitor pass timing is unavailable. Reload to check availability.',
      );
    }
    return value;
  }

  // Subtract the whole request duration conservatively, so network latency
  // cannot extend the display lease beyond a server policy boundary.
  Duration? get remaining => revalidateAt == null
      ? null
      : Duration(
          milliseconds:
              (revalidateAt! - serverTime - _elapsed.elapsedMilliseconds).clamp(
                0,
                8640000000000000,
              ),
        );
}

class ResidentVisitorPassUnavailable implements Exception {
  const ResidentVisitorPassUnavailable(this.message, this.timing, {this.code});
  final String message;
  final ResidentVisitorTiming timing;
  final String? code;
  @override
  String toString() => message;
}
