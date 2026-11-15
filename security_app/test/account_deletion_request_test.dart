import 'dart:async';
import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:security_app/models/security_user_model.dart';
import 'package:security_app/screens/account_deletion_request_screen.dart';
import 'package:security_app/screens/profile_screen.dart';
import 'package:security_app/services/account_deletion_request_service.dart';
import 'package:security_app/services/auth_service.dart';

const _reference = 'SDR-0123456789ABCDEF01234567';
const _empty = SecurityDeletionStatus(communityName: 'Community One');
const _received = SecurityDeletionStatus(
  communityName: 'Community One',
  reference: _reference,
  status: 'pending_review',
  submitted: true,
);

class _Requests implements SecurityDeletionRequests {
  SecurityDeletionStatus current = _empty;
  Object? statusError, submitError;
  Completer<SecurityDeletionStatus>? pendingStatus, pendingSubmit;
  int reads = 0, submits = 0;
  @override
  Future<SecurityDeletionStatus> status() async {
    reads++;
    if (statusError != null) throw statusError!;
    return pendingStatus == null ? current : await pendingStatus!.future;
  }

  @override
  Future<SecurityDeletionStatus> submit() async {
    submits++;
    if (submitError != null) throw submitError!;
    return current = pendingSubmit == null
        ? _received
        : await pendingSubmit!.future;
  }
}

class _User extends Fake implements User {}

class _Auth extends Fake implements AuthService {
  int profileChecks = 0;
  @override
  User get currentUser => _User();
  @override
  Future<SecurityUserModel> requireSecurityProfile({
    bool Function()? isSessionCurrent,
  }) async {
    profileChecks++;
    return const SecurityUserModel(
      uid: 'guard-a',
      communityId: 'C1',
      role: 'security',
      isActive: true,
      name: 'Officer A',
      phoneNumber: '+639171234567',
      securityId: 'SEC-001',
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    // Use mobile typography instead of the test font's square glyph widths.
    var directory = File(Platform.resolvedExecutable).parent;
    while (!File(
      '${directory.path}/bin/cache/artifacts/material_fonts/Roboto-Regular.ttf',
    ).existsSync()) {
      final parent = directory.parent;
      if (parent.path == directory.path) {
        throw StateError('Flutter Roboto font not found');
      }
      directory = parent;
    }
    final fonts = FontLoader('Roboto');
    for (final font in ['Roboto-Regular.ttf', 'Roboto-Medium.ttf']) {
      final bytes = File(
        '${directory.path}/bin/cache/artifacts/material_fonts/$font',
      ).readAsBytesSync();
      fonts.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await fonts.load();
  });

  Future<void> open(
    WidgetTester tester,
    _Requests requests, {
    bool profile = false,
    Size size = const Size(393, 852),
    double scale = 1,
    _Auth? auth,
    bool settle = true,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              child: const Text('Open'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => profile
                      ? ProfileScreen(
                          authService: auth ?? _Auth(),
                          deletionRequests: requests,
                        )
                      : SecurityAccountDeletionRequestScreen(
                          requests: requests,
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
  }

  Future<void> confirm(WidgetTester tester) async {
    await tester.ensureVisible(find.byType(CheckboxListTile));
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.widgetWithText(FilledButton, 'Submit deletion request'),
    );
  }

  testWidgets(
    'profile exposes deletion entry after P1 cleanup and retains Notifications',
    (tester) async {
      final requests = _Requests(), auth = _Auth();
      await open(tester, requests, profile: true, auth: auth);
      expect(auth.profileChecks, 1);
      for (final label in [
        'Notifications',
        'Help & Support',
        'Contact Admin',
        'Logout',
      ]) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.text('Change Password'), findsNothing);
      await tester.ensureVisible(find.text('Request Account Deletion'));
      await tester.tap(find.text('Request Account Deletion'));
      await tester.pumpAndSettle();
      expect(find.byType(SecurityAccountDeletionRequestScreen), findsOneWidget);
      expect(find.text('Community: Community One'), findsOneWidget);
      expect(requests.reads, 1);
      expect(requests.submits, 0);
      await tester.ensureVisible(find.text('Cancel'));
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.byType(ProfileScreen), findsOneWidget);
      expect(requests.submits, 0);
      expect(tester.takeException(), isNull);
    },
  );

  for (final size in [
    const Size(393, 852),
    const Size(600, 960),
    const Size(800, 1280),
  ]) {
    for (final scale in [1.0, 1.3, 1.5]) {
      testWidgets('consent and confirmed receipt fit ${size.width} / $scale', (
        tester,
      ) async {
        final requests = _Requests();
        await open(tester, requests, size: size, scale: scale);
        expect(
          tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
          isNull,
        );
        expect(
          find.textContaining('will not be deleted immediately'),
          findsWidgets,
        );
        await confirm(tester);
        await tester.tap(
          find.widgetWithText(FilledButton, 'Submit deletion request'),
        );
        await tester.pumpAndSettle();
        expect(requests.submits, 1);
        expect(find.text('Request submitted for review'), findsOneWidget);
        expect(find.text('Reference: $_reference'), findsOneWidget);
        expect(
          find.textContaining('not deletion of your account'),
          findsOneWidget,
        );
        await tester.ensureVisible(find.text('Done'));
        expect(
          tester.getRect(find.text('Done')).bottom,
          lessThanOrEqualTo(size.height),
        );
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets(
    'pending submission stays visible and blocks duplicate taps and cancellation',
    (tester) async {
      final requests = _Requests()
        ..pendingSubmit = Completer<SecurityDeletionStatus>();
      await open(tester, requests);
      await confirm(tester);
      final submit = find.widgetWithText(
        FilledButton,
        'Submit deletion request',
      );
      await tester.tap(submit);
      await tester.tap(submit);
      await tester.pump();
      expect(requests.submits, 1);
      expect(find.text('Submitting…'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Cancel'))
            .onPressed,
        isNull,
      );
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.byType(SecurityAccountDeletionRequestScreen), findsOneWidget);
      expect(find.text('Request submitted for review'), findsNothing);
      requests.pendingSubmit!.complete(_received);
      await tester.pumpAndSettle();
      expect(find.text('Request submitted for review'), findsOneWidget);
    },
  );

  testWidgets(
    'submission failure shows no false success and keeps retry available',
    (tester) async {
      final requests = _Requests()
        ..submitError = FirebaseFunctionsException(
          code: 'unavailable',
          message: 'Synthetic failure',
        );
      await open(tester, requests);
      await confirm(tester);
      await tester.tap(
        find.widgetWithText(FilledButton, 'Submit deletion request'),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('could not be confirmed'), findsOneWidget);
      expect(find.text('Request submitted for review'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      requests.submitError = null;
      await tester.ensureVisible(
        find.widgetWithText(FilledButton, 'Submit deletion request'),
      );
      await tester.tap(
        find.widgetWithText(FilledButton, 'Submit deletion request'),
      );
      await tester.pumpAndSettle();
      expect(requests.submits, 2);
      expect(find.text('Reference: $_reference'), findsOneWidget);
    },
  );

  testWidgets('existing pending request is recognized without resubmitting', (
    tester,
  ) async {
    final requests = _Requests()..current = _received;
    await open(tester, requests);
    expect(find.text('Reference: $_reference'), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
    expect(find.byType(CheckboxListTile), findsNothing);
    expect(requests.submits, 0);
  });

  testWidgets(
    'saved unconfirmed intake remains retryable and never shows success',
    (tester) async {
      final requests = _Requests()
        ..current = const SecurityDeletionStatus(
          communityName: 'Community One',
          reference: _reference,
          status: 'pending_review',
        );
      await open(tester, requests);
      expect(find.text('Saved reference: $_reference'), findsOneWidget);
      expect(find.text('Request submitted for review'), findsNothing);
      await confirm(tester);
      await tester.tap(
        find.widgetWithText(FilledButton, 'Submit deletion request'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Reference: $_reference'), findsOneWidget);
    },
  );

  testWidgets(
    'status failure is actionable and can retry without creating a request',
    (tester) async {
      final requests = _Requests()
        ..statusError = FirebaseFunctionsException(
          code: 'permission-denied',
          message: 'Synthetic failure',
        );
      await open(tester, requests);
      expect(find.textContaining('could not be verified'), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);
      requests.statusError = null;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('Community: Community One'), findsOneWidget);
      expect(requests.reads, 2);
      expect(requests.submits, 0);
    },
  );

  for (final submitting in [false, true]) {
    testWidgets(
      'disposal during ${submitting ? 'submission' : 'status lookup'} is safe',
      (tester) async {
        final pending = Completer<SecurityDeletionStatus>();
        final requests = _Requests();
        if (submitting) {
          requests.pendingSubmit = pending;
        } else {
          requests.pendingStatus = pending;
        }
        await open(tester, requests, settle: submitting);
        if (submitting) {
          await confirm(tester);
          await tester.tap(
            find.widgetWithText(FilledButton, 'Submit deletion request'),
          );
          await tester.pump();
        }
        await tester.pumpWidget(const SizedBox());
        pending.completeError(StateError('Synthetic failure'));
        await tester.pump();
        expect(tester.takeException(), isNull);
      },
    );
  }

  test(
    'transport sends no UID, community, phone, recipient or token in payload',
    () async {
      final sent = <Map<String, dynamic>>[];
      final service = SecurityAccountDeletionRequestService(
        call: (data) async {
          sent.add(data);
          return {
            'communityName': 'Community One',
            'request': data['action'] == 'status'
                ? null
                : {
                    'reference': _reference,
                    'status': 'pending_review',
                    'submitted': true,
                  },
          };
        },
      );
      expect((await service.status()).reference, isNull);
      expect((await service.submit()).submitted, isTrue);
      expect(sent, [
        {'action': 'status'},
        {'action': 'submit', 'confirmed': true},
      ]);
    },
  );

  test(
    'unconfirmed or malformed server replies never become submission success',
    () async {
      for (final response in [
        {'communityName': 'Community One', 'request': null},
        {
          'communityName': 'Community One',
          'request': {
            'reference': _reference,
            'status': 'pending_review',
            'submitted': false,
          },
        },
        {
          'communityName': 'Community One',
          'request': {
            'reference': 'invalid',
            'status': 'pending_review',
            'submitted': true,
          },
        },
      ]) {
        final service = SecurityAccountDeletionRequestService(
          call: (_) async => response,
        );
        await expectLater(service.submit(), throwsFormatException);
      }
    },
  );
}
