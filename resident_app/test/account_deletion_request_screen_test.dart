import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:resident_app/src/screens/account_deletion_request_screen.dart';
import 'package:resident_app/src/screens/settings_screen.dart';
import 'package:resident_app/src/services/account_deletion_request_service.dart';
import 'package:resident_app/src/services/firebase_auth_service.dart';
import 'package:resident_app/src/services/resident_auth_routing.dart';
import 'deletion_test_loader.dart';

class FakeDeletionService implements AccountDeletionRequests {
  Map<String, dynamic>? current;
  bool stale = false;
  bool failSubmit = false;
  bool otpStarted = false;
  bool otpCompleted = false;
  @override
  Future<Map<String, dynamic>?> status() async => current;
  @override
  Future<Map<String, dynamic>> submit() async {
    if (failSubmit) throw Exception('offline');
    current = {'requestId': 'request-123', 'status': 'pending_verification'};
    return current!;
  }

  @override
  Future<bool> requiresReauthentication() async => stale;
  @override
  Future<void> beginReauthentication(
    void Function(String) onCodeSent,
    void Function(String) onError,
  ) async {
    otpStarted = true;
    onCodeSent('verification-id');
  }

  @override
  Future<void> completeReauthentication(
    String verificationId,
    String code,
  ) async {
    otpCompleted = true;
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

  Future<void> confirm(WidgetTester tester) async {
    await tester.ensureVisible(find.byType(FilledButton).first);
    await tester.tap(find.byType(FilledButton).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm request'));
    await tester.pumpAndSettle();
  }

  testWidgets('successful request displays reference and status', (
    tester,
  ) async {
    final service = FakeDeletionService();
    await tester.pumpWidget(
      localized(
        MaterialApp(home: AccountDeletionRequestScreen(service: service)),
      ),
    );
    await tester.pumpAndSettle();
    await confirm(tester);
    expect(find.textContaining('request-123'), findsOneWidget);
    expect(find.text('Verification required'), findsOneWidget);
  });

  testWidgets(
    'pending dues explain active account and next review without diagnostics',
    (tester) async {
      final service = FakeDeletionService()
        ..current = {
          'requestId': 'request-123',
          'status': 'pending_review',
          'reviewType': 'community_admin',
          'financialStatus': 'awaiting_settlement',
          'reasons': ['internal query:bills failure diagnostics'],
        };
      var signedOut = false;
      await tester.pumpWidget(
        localized(
          MaterialApp(
            home: AccountDeletionRequestScreen(
              service: service,
              onLogout: () async {
                signedOut = true;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Outstanding dues: settlement must be confirmed before deletion can continue.',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'Your account has not been deleted and remains active while this request is reviewed.',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'your Community Admin reviews financial settlement',
        ),
        findsOneWidget,
      );
      expect(find.text('Reference: request-123'), findsOneWidget);
      expect(find.textContaining('internal query:'), findsNothing);
      expect(signedOut, isFalse);
    },
  );

  testWidgets(
    'stale authentication starts OTP and verifies before submission',
    (tester) async {
      final service = FakeDeletionService()..stale = true;
      await tester.pumpWidget(
        localized(
          MaterialApp(home: AccountDeletionRequestScreen(service: service)),
        ),
      );
      await tester.pumpAndSettle();
      await confirm(tester);
      expect(service.otpStarted, isTrue);
      await tester.enterText(find.byType(TextField), '123456');
      await tester.tap(find.text('Verify OTP'));
      await tester.pumpAndSettle();
      expect(service.otpCompleted, isTrue);
      expect(find.textContaining('request-123'), findsOneWidget);
    },
  );

  testWidgets('failed callable displays error and not success', (tester) async {
    final service = FakeDeletionService()..failSubmit = true;
    await tester.pumpWidget(
      localized(
        MaterialApp(home: AccountDeletionRequestScreen(service: service)),
      ),
    );
    await tester.pumpAndSettle();
    await confirm(tester);
    expect(find.textContaining('Processing failed'), findsOneWidget);
    expect(find.textContaining('request-123'), findsNothing);
  });

  testWidgets('cancel does not submit request', (tester) async {
    final service = FakeDeletionService();
    await tester.pumpWidget(
      localized(
        MaterialApp(home: AccountDeletionRequestScreen(service: service)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(FilledButton).first);
    await tester.tap(find.byType(FilledButton).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(service.current, isNull);
  });

  testWidgets('active Settings opens the request screen', (tester) async {
    await tester.pumpWidget(
      localized(
        ScreenUtilInit(
          designSize: const Size(390, 844),
          builder: (context, _) => MaterialApp(
            locale: context.locale,
            supportedLocales: context.supportedLocales,
            localizationsDelegates: context.localizationDelegates,
            home: const SettingsScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Manage Account'));
    await tester.tap(find.text('Manage Account'));
    await tester.pumpAndSettle();
    expect(find.text('Request account deletion'), findsWidgets);
  });

  testWidgets('sign out ends session and returns to unauthenticated route', (
    tester,
  ) async {
    var signedOut = false;
    await tester.pumpWidget(
      localized(
        MaterialApp(
          home: AccountDeletionRequestScreen(
            onLogout: () async {
              signedOut = true;
            },
          ),
          routes: {
            '/login': (_) =>
                const Scaffold(body: Text('Unauthenticated login')),
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(signedOut, isTrue);
    expect(find.text('Unauthenticated login'), findsOneWidget);
  });

  test('profileless route remains separate from protected Resident routes', () {
    const profileless = AuthResult(
      success: true,
      user: _FakeUser(),
      state: ResidentAuthState.registrationRequired,
    );
    expect(ResidentAuthRouting.routeFor(profileless), '/resident-registration');
    expect(
      ResidentAuthRouting.shouldOpenDeletionRequest(
        profileless,
        ResidentAuthenticationIntent.accountDeletion,
      ),
      isTrue,
    );
    expect(
      ResidentAuthRouting.shouldOpenDeletionRequest(
        profileless,
        ResidentAuthenticationIntent.login,
      ),
      isFalse,
    );
    const unapproved = AuthResult(
      success: true,
      user: _FakeUser(),
      state: ResidentAuthState.pendingApproval,
    );
    expect(ResidentAuthRouting.routeFor(unapproved), '/awaiting-approval');
    expect(
      ResidentAuthRouting.shouldOpenDeletionRequest(
        unapproved,
        ResidentAuthenticationIntent.accountDeletion,
      ),
      isTrue,
    );
    const approved = AuthResult(
      success: true,
      state: ResidentAuthState.approved,
    );
    expect(ResidentAuthRouting.routeFor(approved), '/home');
  });
}

class _FakeUser implements User {
  const _FakeUser();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
