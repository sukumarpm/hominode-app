import 'dart:async';

/// Coalesces concurrent initialization attempts and permits retry after failure.
class RetryableInitialization {
  Future<void>? _inFlight;
  bool _initialized = false;

  bool get isInitialized => _initialized;

  void reset() {
    if (_inFlight == null) _initialized = false;
  }

  Future<void> run(
    Future<void> Function() initialize, {
    Future<void> Function()? onFailure,
  }) {
    if (_initialized) return Future<void>.value();
    final running = _inFlight;
    if (running != null) return running;

    late final Future<void> attempt;
    attempt = Future<void>.sync(initialize)
        .then((_) {
          _initialized = true;
        })
        .catchError((Object error, StackTrace stackTrace) async {
          try {
            await onFailure?.call();
          } catch (_) {
            // Keep the initialization error as the reported failure.
          }
          Error.throwWithStackTrace(error, stackTrace);
        })
        .whenComplete(() {
          if (identical(_inFlight, attempt)) _inFlight = null;
        });
    _inFlight = attempt;
    return attempt;
  }
}
