import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hominode_legal/hominode_legal.dart';
import 'package:resident_app/src/widgets/resident_legal_session_gate.dart';

class _User extends Fake implements User {
  _User(this.uid);
  @override
  final String uid;
}

class _Auth extends Fake implements FirebaseAuth {
  User? user = _User('a');
  final changes = StreamController<User?>.broadcast();
  @override
  User? get currentUser => user;
  @override
  Stream<User?> authStateChanges() => changes.stream;
  void change(String? uid) {
    user = uid == null ? null : _User(uid);
    changes.add(user);
  }
}

// Models the per-session memory in the unchanged shared legal gate.
class _RememberedGate extends StatefulWidget {
  @override
  State<_RememberedGate> createState() => _RememberedGateState();
}

class _RememberedGateState extends State<_RememberedGate> {
  bool accepted = false;
  @override
  Widget build(BuildContext context) => accepted
      ? const Text('Home')
      : TextButton(
          onPressed: () => setState(() => accepted = true),
          child: const Text('Accept'),
        );
}

void main() {
  testWidgets(
    'actual acceptance button waits for persistence, blocks duplicate taps, then reveals Home',
    (tester) async {
      final persisted = Completer<void>();
      var calls = 0;
      var accepted = false;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) => accepted
                ? const Scaffold(body: Text('Home'))
                : LegalAcceptanceScreen(
                    onAccept: () async {
                      calls++;
                      await persisted.future;
                      if (context.mounted) setState(() => accepted = true);
                    },
                  ),
          ),
        ),
      );
      final button = tester
          .widget<FilledButton>(find.byType(FilledButton))
          .onPressed!;
      button();
      button();
      await tester.pump();
      expect(calls, 1);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Home'), findsNothing);
      persisted.complete();
      await tester.pumpAndSettle();
      expect(find.text('Home'), findsOneWidget);
      expect(
        find.textContaining('Acceptance could not be saved'),
        findsNothing,
      );
    },
  );

  for (final code in ['unavailable', 'permission-denied']) {
    testWidgets(
      '$code persistence failure stays on acceptance and allows explicit retry',
      (tester) async {
        var calls = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: LegalAcceptanceScreen(
              onAccept: () async {
                calls++;
                throw FirebaseFunctionsException(
                  code: code,
                  message: 'synthetic failure',
                );
              },
            ),
          ),
        );
        await tester.tap(find.text('Accept and continue'));
        await tester.pumpAndSettle();
        expect(
          find.textContaining('Acceptance could not be saved'),
          findsOneWidget,
        );
        expect(find.text('Home'), findsNothing);
        await tester.tap(find.text('Accept and continue'));
        await tester.pumpAndSettle();
        expect(calls, 2);
      },
    );
  }

  testWidgets(
    'temporary network failure can be retried successfully without a stale error',
    (tester) async {
      var calls = 0;
      var accepted = false;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) => accepted
                ? const Scaffold(body: Text('Home'))
                : LegalAcceptanceScreen(
                    onAccept: () async {
                      if (++calls == 1) {
                        throw FirebaseFunctionsException(
                          code: 'unavailable',
                          message: 'temporary failure',
                        );
                      }
                      if (context.mounted) setState(() => accepted = true);
                    },
                  ),
          ),
        ),
      );
      await tester.tap(find.text('Accept and continue'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Acceptance could not be saved'),
        findsOneWidget,
      );
      await tester.tap(find.text('Accept and continue'));
      await tester.pumpAndSettle();
      expect(find.text('Home'), findsOneWidget);
      expect(
        find.textContaining('Acceptance could not be saved'),
        findsNothing,
      );
    },
  );

  testWidgets(
    'an auth change discards acceptance state and sign-out hides Home',
    (tester) async {
      final auth = _Auth();
      addTearDown(auth.changes.close);
      await tester.pumpWidget(
        MaterialApp(
          home: ResidentLegalSessionGate(auth: auth, child: _RememberedGate()),
        ),
      );
      await tester.tap(find.text('Accept'));
      await tester.pump();
      expect(find.text('Home'), findsOneWidget);
      auth.change('b');
      await tester.pumpAndSettle();
      expect(find.text('Home'), findsNothing);
      expect(find.text('Accept'), findsOneWidget);
      auth.change(null);
      await tester.pumpAndSettle();
      expect(find.text('Accept'), findsNothing);
      expect(find.text('Please sign in again to continue.'), findsOneWidget);
    },
  );

  testWidgets(
    'late acceptance error for a replaced account cannot update the new account screen',
    (tester) async {
      final auth = _Auth();
      addTearDown(auth.changes.close);
      final pending = Completer<void>();
      await tester.pumpWidget(
        MaterialApp(
          home: ResidentLegalSessionGate(
            auth: auth,
            child: LegalAcceptanceScreen(onAccept: () => pending.future),
          ),
        ),
      );
      await tester.tap(find.text('Accept and continue'));
      await tester.pump();
      auth.change('b');
      await tester.pumpAndSettle();
      pending.completeError(StateError('old account failure'));
      await tester.pump();
      expect(
        find.textContaining('Acceptance could not be saved'),
        findsNothing,
      );
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );
      expect(tester.takeException(), isNull);
    },
  );

  test('only both current saved policy versions qualify as accepted', () {
    expect(
      HominodeLegalAcceptance.isCurrent({
        'termsVersion': HominodeLegalAcceptance.termsVersion,
        'privacyVersion': HominodeLegalAcceptance.privacyVersion,
        'acceptedAt': DateTime(2026),
      }),
      true,
    );
    expect(
      HominodeLegalAcceptance.isCurrent({
        'termsVersion': HominodeLegalAcceptance.termsVersion,
        'privacyVersion': 'old',
        'acceptedAt': DateTime(2026),
      }),
      false,
    );
    expect(
      HominodeLegalAcceptance.isCurrent({
        'termsVersion': HominodeLegalAcceptance.termsVersion,
        'privacyVersion': HominodeLegalAcceptance.privacyVersion,
      }),
      false,
    );
  });
}
