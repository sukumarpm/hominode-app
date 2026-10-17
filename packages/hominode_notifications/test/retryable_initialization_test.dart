import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hominode_notifications/src/retryable_initialization.dart';

void main() {
  test(
    'failed initialization cleans up and can retry without duplicate listeners',
    () async {
      final initialization = RetryableInitialization();
      final firstAttempt = Completer<void>();
      var attempts = 0;
      var activeListeners = 0;

      Future<void> initialize() async {
        attempts++;
        activeListeners++;
        if (attempts == 1) await firstAttempt.future;
      }

      Future<void> cleanup() async {
        activeListeners--;
      }

      final failed = expectLater(
        initialization.run(initialize, onFailure: cleanup),
        throwsA(isA<StateError>()),
      );
      final concurrent = expectLater(
        initialization.run(initialize, onFailure: cleanup),
        throwsA(isA<StateError>()),
      );
      expect(attempts, 1);

      firstAttempt.completeError(StateError('temporary plugin failure'));
      await Future.wait([failed, concurrent]);
      expect(activeListeners, 0);

      await initialization.run(initialize, onFailure: cleanup);
      expect(attempts, 2);
      expect(activeListeners, 1);

      await initialization.run(initialize, onFailure: cleanup);
      expect(attempts, 2);
      expect(activeListeners, 1);
    },
  );
}
