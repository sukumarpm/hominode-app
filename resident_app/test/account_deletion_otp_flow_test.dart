import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:resident_app/src/screens/account_deletion_request_screen.dart';
import 'package:resident_app/src/services/account_deletion_request_service.dart';
import 'deletion_test_loader.dart';

class _Token extends Fake implements IdTokenResult {
  _Token(this.authTime);
  @override
  final DateTime authTime;
}

class _Credential extends Fake implements UserCredential {}

class _User extends Fake implements User {
  bool reauthenticated = false;
  bool refreshed = false;
  int verifications = 0;
  @override
  Future<UserCredential> reauthenticateWithCredential(
    AuthCredential credential,
  ) async {
    expect((credential as PhoneAuthCredential).smsCode, '123456');
    verifications++;
    reauthenticated = true;
    return _Credential();
  }

  @override
  Future<String?> getIdToken([bool forceRefresh = false]) async {
    expect(reauthenticated, isTrue);
    expect(forceRefresh, isTrue);
    refreshed = true;
    return 'refreshed-token';
  }

  @override
  Future<IdTokenResult> getIdTokenResult([bool forceRefresh = false]) async =>
      _Token(DateTime.now().subtract(Duration(minutes: refreshed ? 0 : 10)));
}

class _Auth extends Fake implements FirebaseAuth {
  _Auth(this.user);
  final _User user;
  @override
  User get currentUser => user;
}

class _Functions extends Fake implements FirebaseFunctions {}

class _Requests extends AccountDeletionRequestService {
  _Requests(this.user) : super(auth: _Auth(user), functions: _Functions());
  final _User user;
  int otpStarts = 0;
  int statusReads = 0;
  void Function(String)? lateCodeSent;
  final submittedReferences = <String>[];
  Map<String, dynamic> current = {
    'requestId': 'existing-request',
    'status': 'pending_verification',
  };
  var processing = Completer<Map<String, dynamic>>();
  @override
  Future<Map<String, dynamic>?> status() async {
    statusReads++;
    return {...current};
  }

  @override
  Future<void> beginReauthentication(
    void Function(String) onCodeSent,
    void Function(String) onError,
  ) async {
    otpStarts++;
    lateCodeSent = onCodeSent;
    onCodeSent('verification-id');
  }

  @override
  Future<Map<String, dynamic>> submit() async {
    expect(
      user.refreshed,
      isTrue,
      reason: 'The callable must use the refreshed auth_time',
    );
    submittedReferences.add(current['requestId'] as String);
    current = await processing.future;
    return {...current};
  }
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });
  Widget localized(Widget child) => EasyLocalization(
    supportedLocales: const [
      Locale('en'),
      Locale('ta'),
      Locale('hi'),
      Locale('es'),
      Locale('ar'),
      Locale('ml'),
      Locale('te'),
      Locale('kn'),
    ],
    path: 'assets/translations',
    assetLoader: const DeletionTestAssetLoader(),
    fallbackLocale: const Locale('en'),
    startLocale: const Locale('en'),
    saveLocale: false,
    child: Builder(
      builder: (context) => child is MaterialApp
          ? MaterialApp(
              locale: context.locale,
              supportedLocales: context.supportedLocales,
              localizationsDelegates: context.localizationDelegates,
              home: child.home,
              routes: child.routes ?? const {},
            )
          : child,
    ),
  );

  testWidgets(
    'one OTP advances the existing request; retries reuse it and review refresh is read-only',
    (tester) async {
      final user = _User();
      final requests = _Requests(user);
      var logouts = 0;
      Widget app() => localized(
        MaterialApp(
          home: AccountDeletionRequestScreen(
            service: requests,
            onLogout: () async {
              logouts++;
            },
          ),
          routes: {
            '/login': (_) => const Scaffold(body: Text('Resident login')),
          },
        ),
      );
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      final primary = find.byKey(const ValueKey('deletion-primary'));
      void expectOnePrimary() =>
          expect(find.byType(FilledButton), findsOneWidget);
      expectOnePrimary();
      expect(find.text('Continue request'), findsOneWidget);
      expect(find.text('Verification required'), findsOneWidget);
      expect(find.text('Reference: existing-request'), findsOneWidget);
      expect(requests.submittedReferences, isEmpty);

      await tester.tap(primary);
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.textContaining('safety checks'),
        ),
        findsOneWidget,
      );
      expect(requests.otpStarts, 0);
      await tester.tap(find.text('Confirm request'));
      await tester.pumpAndSettle();
      expectOnePrimary();
      expect(find.text('Verify OTP'), findsOneWidget);
      expect(requests.otpStarts, 1);
      expect(requests.submittedReferences, isEmpty);
      await tester.enterText(find.byType(TextField), '123456');
      await tester.tap(primary);
      await tester.tap(primary);
      await tester.pumpAndSettle();
      expect(user.verifications, 1);
      expect(user.refreshed, isTrue);
      expect(requests.submittedReferences, ['existing-request']);
      expect(find.text('Processing…'), findsOneWidget);
      expect(tester.widget<FilledButton>(primary).onPressed, isNull);

      requests.processing.completeError(Exception('response unavailable'));
      await tester.pumpAndSettle();
      expectOnePrimary();
      expect(find.text('Retry processing'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      requests.processing = Completer<Map<String, dynamic>>();
      await tester.tap(primary);
      await tester.pumpAndSettle();
      expect(requests.otpStarts, 1);
      expect(user.verifications, 1);
      expect(requests.submittedReferences, [
        'existing-request',
        'existing-request',
      ]);
      requests.processing.complete({
        'requestId': 'existing-request',
        'status': 'pending_review',
        'communityScopeVerified': true,
        'reviewType': 'processing',
        'reasons': [
          'chatMessages discovery or parent relationship could not be fully verified.',
          'Notification discovery failed, exceeded its bound, or found records without community scope.',
        ],
      });
      await tester.pumpAndSettle();
      expectOnePrimary();
      expect(find.text('Pending processing review'), findsOneWidget);
      expect(
        find.text(
          'chatMessages discovery or parent relationship could not be fully verified.',
        ),
        findsNothing,
      );
      expect(find.text('Refresh status'), findsOneWidget);
      expect(
        requests.statusReads,
        3,
        reason:
            'Recover status after the lost response, then refresh after retry',
      );
      expect(find.text('Continue request'), findsNothing);

      // Firebase's automatic-retrieval timeout can arrive after OTP verification.
      // A late code-sent callback must not resurrect an OTP stage in review.
      requests.lateCodeSent!('late-verification-id');
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
      expect(find.text('Verify OTP'), findsNothing);
      expect(find.text('Refresh status'), findsOneWidget);
      final submissions = requests.submittedReferences.length;
      await tester.tap(primary);
      await tester.pumpAndSettle();
      expect(requests.submittedReferences.length, submissions);
      expect(requests.otpStarts, 1);

      // Reopening reads the same saved request, without starting verification.
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(find.text('Pending processing review'), findsOneWidget);
      expect(find.text('Reference: existing-request'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(find.text('Verify OTP'), findsNothing);
      expect(requests.submittedReferences.length, submissions);
      expect(requests.otpStarts, 1);

      requests.current = {
        'requestId': 'existing-request',
        'status': 'pending_review',
        'communityScopeVerified': true,
        'reviewType': 'community_admin',
        'reasons': [
          'One or more supported bills have a positive outstanding amount.',
        ],
      };
      await tester.tap(primary);
      await tester.pumpAndSettle();
      expect(find.text('Pending Community Admin review'), findsOneWidget);
      expect(find.text('Refresh status'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);

      requests.current = {
        'requestId': 'existing-request',
        'status': 'completed',
      };
      await tester.tap(primary);
      await tester.pumpAndSettle();
      expect(find.text('Resident login'), findsOneWidget);
      expect(find.text('Account deleted successfully'), findsOneWidget);
      expect(logouts, 1);
      expect(requests.submittedReferences.length, 2);
      expect(requests.submittedReferences.toSet(), {'existing-request'});
      expect(requests.otpStarts, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
