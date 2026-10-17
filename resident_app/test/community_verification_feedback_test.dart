import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resident_app/src/widgets/community_verification_feedback.dart';

void main() {
  testWidgets(
    'failed verification retries same operation and clears on success',
    (tester) async {
      _useTallTestView(tester);
      var attempts = 0;
      await tester.pumpWidget(
        _testApp(
          _FeedbackHarness(
            verify: () async {
              attempts++;
              if (attempts == 1) throw StateError('private details');
            },
          ),
        ),
      );

      await tester.tap(find.text('Verify'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Verification failed'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('Access granted'), findsNothing);
      expect(find.text('private details'), findsNothing);

      await tester.tap(find.text('Retry'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(attempts, 2);
      expect(find.text('Verification failed'), findsNothing);
      expect(find.text('Access granted'), findsOneWidget);
    },
  );

  testWidgets('leaving the owner clears its banner and ignores late failure', (
    tester,
  ) async {
    _useTallTestView(tester);
    final completer = Completer<void>();
    await tester.pumpWidget(
      _testApp(_FeedbackHarness(verify: () => completer.future)),
    );

    await tester.tap(find.text('Verify'));
    await tester.pump();
    await tester.tap(find.text('Navigate away'));
    await tester.pump();
    expect(find.text('Verification failed'), findsNothing);
    expect(find.text('Another screen'), findsOneWidget);

    completer.completeError(StateError('late private details'));
    await tester.pump();
    expect(find.text('Verification failed'), findsNothing);
    expect(find.text('Access granted'), findsNothing);
  });

  testWidgets('late failure cannot replace a newer successful verification', (
    tester,
  ) async {
    _useTallTestView(tester);
    final firstAttempt = Completer<void>();
    var calls = 0;
    await tester.pumpWidget(
      _testApp(
        _FeedbackHarness(
          verify: () {
            calls++;
            return calls == 1 ? firstAttempt.future : Future<void>.value();
          },
        ),
      ),
    );

    await tester.tap(find.text('Verify'));
    await tester.pump();
    await tester.tap(find.text('Navigate away'));
    await tester.pump();
    await tester.tap(find.text('Verify again'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Access granted'), findsOneWidget);

    firstAttempt.completeError(StateError('stale failure'));
    await tester.pump();
    expect(find.text('Verification failed'), findsNothing);
    expect(find.text('Access granted'), findsOneWidget);
    expect(calls, 2);
  });

  testWidgets('concurrent retries are ignored and only one notice is shown', (
    tester,
  ) async {
    _useTallTestView(tester);
    final completer = Completer<void>();
    var calls = 0;
    await tester.pumpWidget(
      _testApp(
        _FeedbackHarness(
          verify: () {
            calls++;
            return completer.future;
          },
        ),
      ),
    );

    await tester.tap(find.text('Verify'));
    await tester.pump();
    final state = tester.state<_FeedbackHarnessState>(
      find.byType(_FeedbackHarness),
    );
    state.startVerification();
    await tester.pump();
    completer.completeError(StateError('private details'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(calls, 1);
    expect(find.text('Verification failed'), findsOneWidget);
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('Access granted'), findsNothing);
    state.cancelFeedback();
    await tester.pump(const Duration(milliseconds: 300));
  });
}

Widget _testApp(Widget child) => MaterialApp(home: child);

void _useTallTestView(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

class _FeedbackHarness extends StatefulWidget {
  const _FeedbackHarness({required this.verify});

  final Future<void> Function() verify;

  @override
  State<_FeedbackHarness> createState() => _FeedbackHarnessState();
}

class _FeedbackHarnessState extends State<_FeedbackHarness> {
  final _feedback = CommunityVerificationFeedback();
  int _successes = 0;
  bool _away = false;

  Future<void> startVerification() => _feedback.run(
    context: context,
    operation: 'test/community-membership',
    verify: widget.verify,
    onFailure: (_) => _feedback.showRetryableNotice(
      context: context,
      message: 'Verification failed',
      retryLabel: 'Retry',
      onRetry: () => unawaited(startVerification()),
    ),
    onSuccess: () => setState(() => _successes++),
  );

  void returnToOwnerAndVerify() {
    setState(() => _away = false);
    unawaited(startVerification());
  }

  void cancelFeedback() => _feedback.cancel();

  @override
  void dispose() {
    _feedback.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      children: [
        Text(_away ? 'Another screen' : 'Access granted' * _successes),
        TextButton(
          onPressed: _away ? returnToOwnerAndVerify : startVerification,
          child: Text(_away ? 'Verify again' : 'Verify'),
        ),
        TextButton(
          onPressed: () {
            _feedback.cancel();
            setState(() => _away = true);
          },
          child: const Text('Navigate away'),
        ),
      ],
    ),
  );
}
