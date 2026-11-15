import 'dart:async';
import 'dart:io';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:security_app/models/security_user_model.dart';
import 'package:security_app/screens/profile_screen.dart';
import 'package:security_app/screens/help_support_screen.dart';
import 'package:security_app/screens/account_deletion_request_screen.dart';
import 'package:security_app/services/auth_service.dart';
import 'package:security_app/services/support_request_service.dart';
import 'package:security_app/services/account_deletion_request_service.dart';

const _reference = 'HSP-0123456789ABCDEF01234567';

class _Support implements SecuritySupportRequests {
  final calls = <({String topic, String message, String requestKey})>[];
  Object? error, contextError;
  Completer<String>? pendingContext;
  Completer<SecuritySupportReceipt>? pending;
  @override
  Future<String> communityName() async {
    if (contextError != null) throw contextError!;
    return pendingContext == null
        ? 'Community One'
        : await pendingContext!.future;
  }

  @override
  Future<SecuritySupportReceipt> submit({
    required String topic,
    required String message,
    required String requestKey,
  }) async {
    calls.add((topic: topic, message: message, requestKey: requestKey));
    if (error != null) throw error!;
    return pending == null
        ? SecuritySupportReceipt(
            reference: _reference,
            destination: securityTopicGoesToAdmin(topic)
                ? 'community_admin'
                : 'hominode_support',
            communityName: 'Community One',
          )
        : await pending!.future;
  }
}

class _User extends Fake implements User {}

class _Auth extends Fake implements AuthService {
  @override
  User get currentUser => _User();
  @override
  Future<SecurityUserModel> requireSecurityProfile({
    bool Function()? isSessionCurrent,
  }) async => const SecurityUserModel(
    uid: 'guard-a',
    communityId: 'C1',
    role: 'security',
    isActive: true,
    name: 'Officer A',
    phoneNumber: '+639171234567',
    securityId: 'SEC-001',
  );
}

class _Deletion implements SecurityDeletionRequests {
  @override
  Future<SecurityDeletionStatus> status() async =>
      const SecurityDeletionStatus(communityName: 'Community One');
  @override
  Future<SecurityDeletionStatus> submit() =>
      throw StateError('Deletion must not be invoked by support');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
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
    _Support support, {
    bool profile = false,
    String topic = 'technical_issue',
    Size size = const Size(393, 852),
    double scale = 1,
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
                          authService: _Auth(),
                          deletionRequests: _Deletion(),
                          supportRequests: support,
                        )
                      : HelpSupportScreen(
                          requests: support,
                          initialTopic: topic,
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

  Future<void> describe(WidgetTester tester) async {
    await tester.ensureVisible(find.byType(TextFormField));
    await tester.enterText(
      find.byType(TextFormField),
      'The gate scanner screen is not responding.',
    );
    await tester.ensureVisible(
      find.widgetWithText(FilledButton, 'Send request'),
    );
  }

  for (final contactAdmin in [false, true]) {
    testWidgets(
      '${contactAdmin ? 'Contact Admin' : 'Help & Support'} opens one shared support flow and preserves deletion access',
      (tester) async {
        final support = _Support();
        await open(tester, support, profile: true);
        expect(find.text('Change Password'), findsNothing);
        expect(find.text('Notifications'), findsOneWidget);
        expect(find.text('Request Account Deletion'), findsOneWidget);
        final entry = find.text(
          contactAdmin ? 'Contact Admin' : 'Help & Support',
        );
        await tester.ensureVisible(entry);
        await tester.tap(entry);
        await tester.pumpAndSettle();
        expect(find.byType(HelpSupportScreen), findsOneWidget);
        expect(
          find.textContaining(
            'registered phone-number changes, gate and shift assignments, account provisioning and access issues',
          ),
          findsOneWidget,
        );
        expect(
          find.text(
            contactAdmin
                ? 'Send to: Community Admin'
                : 'Send to: Hominode Support',
          ),
          findsOneWidget,
        );
        expect(support.calls, isEmpty);
        await describe(tester);
        await tester.tap(find.text('Send request'));
        await tester.pumpAndSettle();
        expect(
          support.calls.single.topic,
          contactAdmin ? 'account_access' : 'technical_issue',
        );
        expect(find.text('Request sent'), findsOneWidget);
        await tester.ensureVisible(find.text('Done'));
        await tester.tap(find.text('Done'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Request Account Deletion'));
        await tester.tap(find.text('Request Account Deletion'));
        await tester.pumpAndSettle();
        expect(
          find.byType(SecurityAccountDeletionRequestScreen),
          findsOneWidget,
        );
        expect(find.text('Community: Community One'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final size in [
    const Size(393, 852),
    const Size(600, 960),
    const Size(800, 1280),
  ]) {
    for (final scale in [1.0, 1.3, 1.5]) {
      for (final topic in ['technical_issue', 'account_access']) {
        testWidgets('support fits ${size.width} / $scale / $topic', (
          tester,
        ) async {
          final support = _Support();
          await open(tester, support, size: size, scale: scale, topic: topic);
          final selected = find.descendant(
            of: find.byType(DropdownButtonFormField<String>),
            matching: find.text(securitySupportTopics[topic]!),
          );
          expect(selected, findsOneWidget);
          final paragraph = tester.renderObject<RenderParagraph>(selected);
          final text = tester.widget<Text>(selected),
              context = tester.element(selected);
          final painter = TextPainter(
            text: TextSpan(
              text: text.data,
              style: DefaultTextStyle.of(context).style.merge(text.style),
            ),
            textDirection: TextDirection.ltr,
            textScaler: MediaQuery.textScalerOf(context),
          )..layout(maxWidth: paragraph.size.width);
          expect(
            paragraph.size.height,
            greaterThanOrEqualTo(painter.height - 0.01),
          );
          painter.dispose();
          await describe(tester);
          await tester.tap(find.text('Send request'));
          await tester.pumpAndSettle();
          expect(find.text('Reference: $_reference'), findsOneWidget);
          await tester.ensureVisible(find.text('Done'));
          expect(
            tester.getRect(find.text('Done')).bottom,
            lessThanOrEqualTo(size.height),
          );
          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  testWidgets('message validation and cancellation never submit', (
    tester,
  ) async {
    final support = _Support();
    await open(tester, support);
    await tester.ensureVisible(find.text('Send request'));
    await tester.tap(find.text('Send request'));
    await tester.pumpAndSettle();
    expect(
      find.text('Describe the issue in at least 10 characters.'),
      findsOneWidget,
    );
    expect(support.calls, isEmpty);
    await tester.ensureVisible(find.text('Cancel'));
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(HelpSupportScreen), findsNothing);
    expect(support.calls, isEmpty);
  });

  testWidgets('loading prevents duplicate submission and back navigation', (
    tester,
  ) async {
    final support = _Support()..pending = Completer<SecuritySupportReceipt>();
    await open(tester, support);
    await describe(tester);
    await tester.tap(find.text('Send request'));
    await tester.tap(find.text('Send request'));
    await tester.pump();
    expect(support.calls, hasLength(1));
    expect(find.text('Sending…'), findsOneWidget);
    expect(find.text('Request sent'), findsNothing);
    expect(
      tester.widget<TextFormField>(find.byType(TextFormField)).enabled,
      isFalse,
    );
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.byType(HelpSupportScreen), findsOneWidget);
    support.pending!.complete(
      const SecuritySupportReceipt(
        reference: _reference,
        destination: 'hominode_support',
        communityName: 'Community One',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Request sent'), findsOneWidget);
  });

  testWidgets(
    'failure retains message and same retry key without false success',
    (tester) async {
      final support = _Support()
        ..error = FirebaseFunctionsException(
          code: 'unavailable',
          message: 'Synthetic',
        );
      await open(tester, support);
      await describe(tester);
      await tester.tap(find.text('Send request'));
      await tester.pumpAndSettle();
      expect(find.textContaining('could not be confirmed'), findsOneWidget);
      expect(find.text('Request sent'), findsNothing);
      expect(
        find.text('The gate scanner screen is not responding.'),
        findsOneWidget,
      );
      support.error = null;
      await tester.ensureVisible(find.text('Send request'));
      await tester.tap(find.text('Send request'));
      await tester.pumpAndSettle();
      expect(support.calls, hasLength(2));
      expect(support.calls[1], support.calls[0]);
      expect(find.text('Request sent'), findsOneWidget);
    },
  );

  testWidgets('context authorization failure can retry and cannot submit', (
    tester,
  ) async {
    final support = _Support()
      ..contextError = FirebaseFunctionsException(
        code: 'permission-denied',
        message: 'Synthetic',
      );
    await open(tester, support);
    expect(find.textContaining('could not be verified'), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
    support.contextError = null;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Community: Community One'), findsOneWidget);
    expect(support.calls, isEmpty);
  });

  for (final submitting in [false, true]) {
    testWidgets(
      'disposal during ${submitting ? 'submission' : 'context loading'} is safe',
      (tester) async {
        final support = _Support();
        if (submitting) {
          support.pending = Completer<SecuritySupportReceipt>();
        } else {
          support.pendingContext = Completer<String>();
        }
        await open(tester, support, settle: submitting);
        if (submitting) {
          await describe(tester);
          await tester.tap(find.text('Send request'));
          await tester.pump();
        }
        await tester.pumpWidget(const SizedBox());
        if (submitting) {
          support.pending!.completeError(StateError('Synthetic'));
        } else {
          support.pendingContext!.completeError(StateError('Synthetic'));
        }
        await tester.pump();
        expect(tester.takeException(), isNull);
      },
    );
  }

  test(
    'service sends only message/topic/idempotency key; never client identity or community',
    () async {
      final sent = <Map<String, dynamic>>[];
      final service = SecuritySupportRequestService(
        call: (data) async {
          sent.add(data);
          return data['action'] == 'context'
              ? {'communityName': 'Community One'}
              : {
                  'status': 'received',
                  'reference': _reference,
                  'destination': 'hominode_support',
                  'communityName': 'Community One',
                };
        },
      );
      expect(await service.communityName(), 'Community One');
      expect(
        (await service.submit(
          topic: 'technical_issue',
          message: 'My scanner is not working.',
          requestKey: 'a' * 32,
        )).reference,
        _reference,
      );
      expect(sent, [
        {'action': 'context'},
        {
          'action': 'submit',
          'topic': 'technical_issue',
          'message': 'My scanner is not working.',
          'requestKey': 'a' * 32,
        },
      ]);
    },
  );

  test(
    'malformed, unconfirmed or incorrectly routed replies never produce success',
    () async {
      for (final changes in [
        {'status': 'pending_delivery'},
        {'reference': 'invalid'},
        {'destination': 'community_admin'},
        {'communityName': ''},
      ]) {
        final service = SecuritySupportRequestService(
          call: (_) async => {
            'status': 'received',
            'reference': _reference,
            'destination': 'hominode_support',
            'communityName': 'Community One',
            ...changes,
          },
        );
        await expectLater(
          service.submit(
            topic: 'technical_issue',
            message: 'My scanner is not working.',
            requestKey: 'a' * 32,
          ),
          throwsFormatException,
        );
      }
    },
  );
}
