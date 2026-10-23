import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:security_app/main.dart';

void main() {
  test(
    'transient App Check failure retries while initializing Firebase once',
    () async {
      var firebaseCalls = 0;
      var activationCalls = 0;
      var tokenCalls = 0;
      final initializer = SecurityStartupInitializer(
        initializeFirebase: () async {
          firebaseCalls++;
        },
        activateAppCheck: () async {
          activationCalls++;
        },
        verifyAppCheckToken: () async {
          tokenCalls++;
          if (tokenCalls == 1)
            throw StateError('temporary attestation failure');
        },
        retryDelays: const [Duration.zero, Duration.zero],
      );

      await initializer.initialize();
      expect(firebaseCalls, 1);
      expect(activationCalls, 1);
      expect(tokenCalls, 2);
    },
  );

  test('Firebase initialization can recover on a later attempt', () async {
    var firebaseCalls = 0;
    var activationCalls = 0;
    var tokenCalls = 0;
    final initializer = SecurityStartupInitializer(
      initializeFirebase: () async {
        firebaseCalls++;
        if (firebaseCalls == 1)
          throw StateError('temporary initialization failure');
      },
      activateAppCheck: () async {
        activationCalls++;
      },
      verifyAppCheckToken: () async {
        tokenCalls++;
      },
      retryDelays: const [Duration.zero, Duration.zero],
    );

    await initializer.initialize();
    expect(firebaseCalls, 2);
    expect(activationCalls, 1);
    expect(tokenCalls, 1);
  });

  test(
    'persistent attestation failure rejects access after bounded retries',
    () async {
      var tokenCalls = 0;
      final initializer = SecurityStartupInitializer(
        initializeFirebase: () async {},
        activateAppCheck: () async {},
        verifyAppCheckToken: () async {
          tokenCalls++;
          throw StateError('attestation refused');
        },
        retryDelays: const [Duration.zero, Duration.zero],
      );

      await expectLater(initializer.initialize(), throwsStateError);
      expect(tokenCalls, 3);
    },
  );

  test('a later user retry starts a new verification attempt', () async {
    var calls = 0;
    final initializer = SecurityStartupInitializer(
      initializeFirebase: () async {},
      activateAppCheck: () async {},
      verifyAppCheckToken: () async {
        calls++;
        if (calls <= 3) throw StateError('temporary error');
      },
      retryDelays: const [Duration.zero, Duration.zero],
    );

    await expectLater(initializer.initialize(), throwsStateError);
    await initializer.initialize();
    expect(calls, 4);
  });

  test(
    'simultaneous startup calls share the same in-flight verification',
    () async {
      final pending = Completer<void>();
      var tokenCalls = 0;
      final initializer = SecurityStartupInitializer(
        initializeFirebase: () async {},
        activateAppCheck: () async {},
        verifyAppCheckToken: () {
          tokenCalls++;
          return pending.future;
        },
        retryDelays: const [Duration.zero, Duration.zero],
      );

      final first = initializer.initialize();
      final second = initializer.initialize();
      expect(identical(first, second), isTrue);
      await Future<void>.delayed(Duration.zero);
      pending.complete();
      await Future.wait([first, second]);
      expect(tokenCalls, 1);
    },
  );

  testWidgets('startup gate keeps restricted content hidden on failure', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SecurityStartupGate(
          initialize: () async => throw StateError('verification failed'),
          child: const Text('AUTHORIZED CONTENT'),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('AUTHORIZED CONTENT'), findsNothing);
    expect(find.text('Secure startup could not complete'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });
}
