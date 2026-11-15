import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
// Use the installed Firebase SDK's test helper without adding a package.
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resident_app/src/screens/account_deletion_request_screen.dart';
import 'package:resident_app/src/services/account_deletion_request_service.dart';
import 'package:resident_app/src/services/firebase_auth_service.dart';
import 'package:resident_app/src/services/resident_private_images.dart';
import 'package:resident_app/src/services/tenant_resolution_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'deletion_test_loader.dart';

class _Requests implements AccountDeletionRequests {
  Map<String, dynamic>? current;
  Object? statusError;
  bool completeOnSubmit = false;
  Object? submissionError;
  Map<String, dynamic>? persistedOnSubmit;
  Map<String, dynamic>? response;
  int submissions = 0;
  int reads = 0;

  @override
  Future<Map<String, dynamic>?> status() async {
    reads++;
    if (statusError != null) throw statusError!;
    return current == null ? null : {...current!};
  }

  @override
  Future<Map<String, dynamic>> submit() async {
    submissions++;
    if (persistedOnSubmit != null) current = persistedOnSubmit;
    if (submissionError != null) throw submissionError!;
    if (response != null) return response!;
    if (completeOnSubmit) {
      statusError = FirebaseFunctionsException(
        code: 'unauthenticated',
        message: 'Deleted session',
      );
      return {'requestId': 'request', 'status': 'completed'};
    }
    throw StateError('Unexpected submission');
  }

  @override
  Future<bool> requiresReauthentication() async => false;
  @override
  Future<void> beginReauthentication(
    void Function(String) onCodeSent,
    void Function(String) onError,
  ) async => throw StateError('Unexpected OTP');
  @override
  Future<void> completeReauthentication(String id, String code) async =>
      throw StateError('Unexpected OTP');
}

class _CallableResult<T> extends Fake implements HttpsCallableResult<T> {
  _CallableResult(this.data);
  @override
  final T data;
}

class _Callable extends Fake implements HttpsCallable {
  @override
  Future<HttpsCallableResult<T>> call<T>([dynamic parameters]) async {
    expect(parameters, {'sourceApp': 'resident'});
    return _CallableResult<T>(
      {'requestId': 'request', 'status': 'completed'} as T,
    );
  }
}

class _Functions extends Fake implements FirebaseFunctions {
  HttpsCallableOptions? options;
  @override
  HttpsCallable httpsCallable(String name, {HttpsCallableOptions? options}) {
    expect(name, 'submitAccountDeletionRequest');
    this.options = options;
    return _Callable();
  }
}

class _CoveredResident extends StatefulWidget {
  const _CoveredResident({required this.onDispose, required this.child});
  final VoidCallback onDispose;
  final Widget child;
  @override
  State<_CoveredResident> createState() => _CoveredResidentState();
}

class _CoveredResidentState extends State<_CoveredResident> {
  @override
  void dispose() {
    widget.onDispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _Auth extends Fake implements FirebaseAuth {
  int signOuts = 0;
  @override
  Future<void> signOut() async {
    signOuts++;
  }
}

class _Tenant extends Fake implements TenantResolutionService {
  bool cleared = false;
  @override
  void clear() {
    cleared = true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  Widget app(
    _Requests requests,
    Future<void> Function() logout,
  ) => EasyLocalization(
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
      builder: (context) => MaterialApp(
        locale: context.locale,
        supportedLocales: context.supportedLocales,
        localizationsDelegates: context.localizationDelegates,
        home: AccountDeletionRequestScreen(service: requests, onLogout: logout),
        routes: {'/login': (_) => const Scaffold(body: Text('Resident login'))},
      ),
    ),
  );

  testWidgets(
    'completed on reopening signs out and removes all protected routes once',
    (tester) async {
      final requests = _Requests()
        ..current = {'requestId': 'request', 'status': 'completed'};
      var logouts = 0;
      final logout = Completer<void>();
      await tester.pumpWidget(
        app(requests, () {
          logouts++;
          return logout.future;
        }),
      );
      await tester.pumpAndSettle();
      expect(logouts, 1);
      expect(tester.widget<PopScope>(find.byType(PopScope)).canPop, false);
      logout.complete();
      await tester.pumpAndSettle();
      expect(find.text('Account deleted successfully'), findsOneWidget);
      expect(find.text('Resident login'), findsOneWidget);
      expect(
        Navigator.of(tester.element(find.text('Resident login'))).canPop(),
        false,
      );
      expect(find.text('Return to sign in'), findsNothing);
      await tester.pump(const Duration(seconds: 30));
      expect(logouts, 1);
      expect(requests.submissions, 0);
    },
  );

  testWidgets('asynchronous completion is detected by read-only polling', (
    tester,
  ) async {
    final requests = _Requests()
      ..current = {'requestId': 'request', 'status': 'pending_review'};
    var logouts = 0;
    await tester.pumpWidget(
      app(requests, () async {
        logouts++;
      }),
    );
    await tester.pumpAndSettle();
    expect(logouts, 0);
    requests.current = {'requestId': 'request', 'status': 'completed'};
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();
    expect(logouts, 1);
    expect(find.text('Resident login'), findsOneWidget);
    expect(requests.submissions, 0);
  });

  testWidgets(
    'completed submission redirects without requiring another authenticated status read',
    (tester) async {
      final requests = _Requests()..completeOnSubmit = true;
      var logouts = 0;
      await tester.pumpWidget(
        app(requests, () async {
          logouts++;
        }),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('deletion-primary')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm request'));
      await tester.pumpAndSettle();
      expect(logouts, 1);
      expect(requests.reads, 1);
      expect(requests.submissions, 1);
      expect(find.text('Resident login'), findsOneWidget);
    },
  );

  testWidgets(
    'pending, failed, denied and missing sessions do not imply completion',
    (tester) async {
      for (final outcome in [
        'pending_review',
        'failed',
        'permission-denied',
        'unauthenticated',
        'unavailable',
        'missing',
      ]) {
        final requests = _Requests()
          ..current = {'requestId': 'request', 'status': 'pending_review'};
        var logouts = 0;
        await tester.pumpWidget(
          app(requests, () async {
            logouts++;
          }),
        );
        await tester.pumpAndSettle();
        if (['pending_review', 'failed'].contains(outcome)) {
          requests.current = {'requestId': 'request', 'status': outcome};
        } else if (outcome == 'missing') {
          requests.current = null;
        } else {
          requests.statusError = FirebaseFunctionsException(
            code: outcome,
            message: 'Status unavailable',
          );
        }
        await tester.pump(const Duration(seconds: 10));
        await tester.pumpAndSettle();
        expect(logouts, 0, reason: outcome);
        expect(find.text('Account deleted successfully'), findsNothing);
        expect(find.text('Resident login'), findsNothing);
        expect(requests.submissions, 0);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      }
    },
  );

  Future<void> confirm(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('deletion-primary')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm request'));
    await tester.pumpAndSettle();
  }

  test(
    'submission transport timeout exceeds the 540-second backend budget',
    () async {
      final functions = _Functions();
      final result = await AccountDeletionRequestService(
        functions: functions,
        auth: _Auth(),
      ).submit();
      expect(functions.options!.timeout, const Duration(minutes: 10));
      expect(result['status'], 'completed');
    },
  );

  testWidgets(
    'deadline after request commit recovers processing and polls the same request to completion',
    (tester) async {
      final requests = _Requests()
        ..submissionError = FirebaseFunctionsException(
          code: 'deadline-exceeded',
          message: '504',
        )
        ..persistedOnSubmit = {
          'requestId': 'request',
          'status': 'deletion_in_progress',
        };
      var logouts = 0;
      await tester.pumpWidget(
        app(requests, () async {
          logouts++;
        }),
      );
      await tester.pumpAndSettle();
      await confirm(tester);
      expect(find.text('Processing'), findsOneWidget);
      expect(find.textContaining('Processing failed'), findsNothing);
      expect(requests.submissions, 1);
      requests.current = {'requestId': 'request', 'status': 'completed'};
      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();
      expect(logouts, 1);
      expect(requests.submissions, 1);
      expect(find.text('Resident login'), findsOneWidget);
    },
  );

  testWidgets(
    'lost submission response can recover trusted completion before any retry',
    (tester) async {
      final requests = _Requests()
        ..submissionError = FirebaseFunctionsException(
          code: 'internal',
          message: 'response lost',
        )
        ..persistedOnSubmit = {'requestId': 'request', 'status': 'completed'};
      var logouts = 0;
      await tester.pumpWidget(
        app(requests, () async {
          logouts++;
        }),
      );
      await tester.pumpAndSettle();
      await confirm(tester);
      expect(logouts, 1);
      expect(find.text('Resident login'), findsOneWidget);
      expect(find.textContaining('Processing failed'), findsNothing);
    },
  );

  testWidgets(
    'timeout plus permission-denied status never claims successful deletion',
    (tester) async {
      final requests = _Requests()
        ..submissionError = FirebaseFunctionsException(
          code: 'deadline-exceeded',
          message: 'timeout',
        );
      var logouts = 0;
      await tester.pumpWidget(
        app(requests, () async {
          logouts++;
        }),
      );
      await tester.pumpAndSettle();
      requests.statusError = FirebaseFunctionsException(
        code: 'permission-denied',
        message: 'auth revoked',
      );
      await confirm(tester);
      expect(logouts, 0);
      expect(requests.submissions, 1);
      expect(find.text('Account deleted successfully'), findsNothing);
      expect(
        find.textContaining('Final status is not confirmed'),
        findsOneWidget,
      );
      expect(find.textContaining('Processing failed'), findsNothing);
      expect(find.text('Refresh status'), findsOneWidget);
    },
  );

  testWidgets(
    'queued response stays processing and does not request a new OTP or resubmit',
    (tester) async {
      final requests = _Requests()
        ..response = {'requestId': 'request', 'status': 'queued'};
      await tester.pumpWidget(app(requests, () async {}));
      await tester.pumpAndSettle();
      await confirm(tester);
      expect(find.text('Processing'), findsOneWidget);
      expect(find.textContaining('Processing failed'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('deletion-primary')));
      await tester.pumpAndSettle();
      expect(requests.submissions, 1);
    },
  );

  testWidgets(
    'genuine failed response retains Retry processing and reuses the same request',
    (tester) async {
      final requests = _Requests()
        ..response = {'requestId': 'request', 'status': 'failed'};
      var logouts = 0;
      await tester.pumpWidget(
        app(requests, () async {
          logouts++;
        }),
      );
      await tester.pumpAndSettle();
      await confirm(tester);
      expect(find.text('Retry processing'), findsOneWidget);
      expect(logouts, 0);
      requests.response = {'requestId': 'request', 'status': 'completed'};
      await tester.tap(find.byKey(const ValueKey('deletion-primary')));
      await tester.pumpAndSettle();
      expect(requests.submissions, 2);
      expect(logouts, 1);
      expect(find.text('Resident login'), findsOneWidget);
    },
  );

  testWidgets(
    'confirmed completion disposes covered Resident listeners before delayed sign-out ends',
    (tester) async {
      final requests = _Requests()
        ..current = {'requestId': 'request', 'status': 'completed'};
      final logout = Completer<void>();
      var disposed = false;
      await tester.pumpWidget(
        EasyLocalization(
          supportedLocales: const [Locale('en')],
          path: 'assets/translations',
          assetLoader: const DeletionTestAssetLoader(),
          startLocale: const Locale('en'),
          saveLocale: false,
          child: MaterialApp(
            routes: {
              '/login': (_) => const Scaffold(body: Text('Resident login')),
            },
            home: Builder(
              builder: (context) => _CoveredResident(
                onDispose: () => disposed = true,
                child: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => AccountDeletionRequestScreen(
                        service: requests,
                        onLogout: () => logout.future,
                      ),
                    ),
                  ),
                  child: const Text('Delete'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(disposed, true);
      logout.complete();
      await tester.pumpAndSettle();
      expect(find.text('Resident login'), findsOneWidget);
    },
  );

  test(
    'logout clears Resident caches and Firebase even if notification cleanup fails',
    () async {
      setupFirebaseCoreMocks();
      await Firebase.initializeApp();
      SharedPreferences.setMockInitialValues({
        'is_logged_in': true,
        'user_mobile': '+639400000000',
        'auth_token': 'token',
        'user_id': 'resident',
        'user_email': 'resident@example.test',
        'building_id': 'building',
        'flat_id': 'unit',
        'language': 'en',
      });
      final images = ResidentPrivateImageStore(
        call: (_, _) async => {},
        scope: () => 'resident/community',
      );
      ResidentPrivateImages.install(images);
      final auth = _Auth();
      final tenant = _Tenant();
      final service = FirebaseAuthService.forTesting(
        auth: auth,
        deactivateNotifications: () async {
          throw FirebaseFunctionsException(
            code: 'unauthenticated',
            message: 'Deleted session',
          );
        },
      );
      final result = await service.signOut(tenant);
      expect(result.success, true);
      expect(auth.signOuts, 1);
      expect(tenant.cleared, true);
      expect(images.epoch, greaterThan(0));
      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getKeys(), {'language'});
      ResidentPrivateImages.install(null);
    },
  );
}
