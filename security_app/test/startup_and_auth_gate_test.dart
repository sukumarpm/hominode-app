import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:security_app/main.dart';
import 'package:security_app/models/security_user_model.dart';
import 'package:security_app/services/auth_service.dart';

void main() {
  testWidgets('startup Retry joins an initialization still in flight', (
    tester,
  ) async {
    final firebaseInitialization = Completer<void>();
    var firebaseAttempts = 0;
    var appCheckActivations = 0;
    var tokenChecks = 0;
    final initializer = SecurityStartupInitializer(
      initializeFirebase: () {
        firebaseAttempts++;
        return firebaseInitialization.future;
      },
      activateAppCheck: () async {
        appCheckActivations++;
      },
      verifyAppCheckToken: () async {
        tokenChecks++;
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: SecurityStartupGate(
          initialize: initializer.initialize,
          child: const Text('Security access gate'),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 31));
    expect(find.text('Secure startup could not complete'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(firebaseAttempts, 1);
    expect(appCheckActivations, 0);

    firebaseInitialization.complete();
    await tester.pumpAndSettle();
    expect(find.text('Security access gate'), findsOneWidget);
    expect(firebaseAttempts, 1);
    expect(appCheckActivations, 1);
    expect(tokenChecks, 1);
  });

  testWidgets('startup failure is recoverable with retry', (tester) async {
    var attempts = 0;
    var readyCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: SecurityStartupGate(
          initialize: () async {
            attempts++;
            if (attempts == 1) throw StateError('temporary startup failure');
          },
          onReady: () async {
            readyCalls++;
          },
          child: const Text('Security access gate'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Secure startup could not complete'), findsOneWidget);
    expect(find.text('Security access gate'), findsNothing);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.text('Security access gate'), findsOneWidget);
    expect(attempts, 2);
    expect(readyCalls, 1);
  });

  testWidgets('profile failure can retry before authorized content is shown', (
    tester,
  ) async {
    final firstProfile = Completer<SecurityUserModel>();
    final auth = _FakeAuthService()
      ..profileResults.add(() => firstProfile.future)
      ..profileResults.add(() => Future.value(_validProfile));
    addTearDown(auth.dispose);

    await tester.pumpWidget(_authGate(auth));
    auth.emitUser(_FakeUser());
    await tester.pump();
    firstProfile.completeError(StateError('temporary profile failure'));
    await tester.pumpAndSettle();

    expect(find.text('Dashboard: Gate'), findsNothing);
    expect(find.text('Access unavailable'), findsOneWidget);
    expect(auth.profileCalls, 1);

    await tester.tap(find.text('Try Again'));
    await tester.pumpAndSettle();

    expect(find.text('Dashboard: Gate'), findsOneWidget);
    expect(auth.profileCalls, 2);
  });

  testWidgets(
    'profile future stays stable across rebuilds and authorizes only on success',
    (tester) async {
      final auth = _FakeAuthService();
      addTearDown(auth.dispose);
      final profileResult = Completer<SecurityUserModel>();
      auth.profileLoader = () => profileResult.future;
      final rebuild = ValueNotifier<int>(0);

      await tester.pumpWidget(
        ValueListenableBuilder<int>(
          valueListenable: rebuild,
          builder: (context, _, __) => _authGate(auth),
        ),
      );
      auth.emitUser(_FakeUser());
      await tester.pump();
      expect(auth.profileCalls, 1);
      expect(find.text('Dashboard: Gate'), findsNothing);

      rebuild.value++;
      await tester.pump();
      expect(auth.profileCalls, 1);
      expect(find.text('Dashboard: Gate'), findsNothing);

      profileResult.complete(_validProfile);
      await tester.pumpAndSettle();
      expect(find.text('Dashboard: Gate'), findsOneWidget);

      rebuild.dispose();
    },
  );
}

Widget _authGate(_FakeAuthService auth) => MaterialApp(
  home: SecurityAuthGate(
    authService: auth,
    authorizedContentBuilder: (context, profile) =>
        Text('Dashboard: ${profile.name}'),
  ),
);

const _validProfile = SecurityUserModel(
  uid: 'security-1',
  communityId: 'community-a',
  role: 'security',
  isActive: true,
  name: 'Gate',
  phoneNumber: '+639171234567',
);

class _FakeUser extends Fake implements User {
  @override
  String get uid => 'security-1';
}

class _FakeAuthService extends Fake implements AuthService {
  final StreamController<User?> _authChanges =
      StreamController<User?>.broadcast(sync: true);
  final List<Future<SecurityUserModel> Function()> profileResults = [];
  int profileCalls = 0;
  Future<SecurityUserModel> Function()? profileLoader;

  @override
  Stream<User?> get authStateChanges => _authChanges.stream;

  @override
  Future<SecurityUserModel> requireSecurityProfile({
    bool Function()? isSessionCurrent,
  }) {
    profileCalls++;
    final loader = profileLoader;
    if (loader != null) return loader();
    if (profileResults.isEmpty) return Future.value(_validProfile);
    return profileResults.removeAt(0)();
  }

  @override
  Future<void> logout() async {}

  void emitUser(User? user) => _authChanges.add(user);

  Future<void> dispose() => _authChanges.close();
}
