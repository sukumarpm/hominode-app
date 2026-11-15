import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:resident_app/src/services/resident_visitor_pass_service.dart';
import 'package:resident_app/src/models/resident_visitor_timing.dart';
import 'package:resident_app/visitor_qr_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

const token = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmno12';
const manualCode = 'ABCD-EFGHJKLM';
Map<String, dynamic> timing() {
  final now = DateTime.now().millisecondsSinceEpoch;
  return {'serverTime': now, 'revalidateAt': now + 3600_000};
}

Map<String, dynamic> visitor() => {
  'status': 'expected',
  'isApproved': false,
  'visitorName': 'Phase One Guest',
  'flatLabel': 'N014',
  'purpose': 'Visit',
  'expectedArrival': Timestamp.fromDate(DateTime.now()),
  'actualArrival': null,
  'departure': null,
};
ResidentVisitorPassService service({
  Map<String, dynamic>? record,
  Map<String, dynamic>? credentials,
}) {
  final committed = record ?? visitor();
  return ResidentVisitorPassService(
    loadVisitor: (_) async => Map<String, dynamic>.from(committed),
    loadCredentials: (_) async =>
        credentials ??
        {...timing(), 'qrToken': token, 'visitorPassCode': manualCode},
  );
}

class _Strings extends AssetLoader {
  const _Strings();
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async => {
    'visitor_status_expected': 'Expected',
    'visitor_qr_pass': 'Visitor pass',
    'visitor_load_error': 'Unable to load visitor pass',
    'back': 'Back',
  };
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    var directory = File(Platform.resolvedExecutable).parent;
    while (!File(
      '${directory.path}/bin/cache/artifacts/material_fonts/Roboto-Regular.ttf',
    ).existsSync()) {
      if (directory.parent.path == directory.path) {
        throw StateError('Flutter font not found');
      }
      directory = directory.parent;
    }
    final loader = FontLoader('Roboto');
    for (final font in ['Roboto-Regular.ttf', 'Roboto-Medium.ttf']) {
      loader.addFont(
        Future.value(
          ByteData.sublistView(
            File(
              '${directory.path}/bin/cache/artifacts/material_fonts/$font',
            ).readAsBytesSync(),
          ),
        ),
      );
    }
    await loader.load();
  });

  test(
    'retrieves both private credentials by visitor ID without trusting public secrets',
    () async {
      final requested = <String>[];
      final row = visitor()
        ..addAll({
          'qrToken': 'public-forgery',
          'visitorPassCode': 'public-forgery',
        });
      final pass = await ResidentVisitorPassService(
        loadVisitor: (id) async {
          requested.add('visitor:$id');
          return row;
        },
        loadCredentials: (id) async {
          requested.add('credentials:$id');
          return {...timing(), 'qrToken': token, 'visitorPassCode': manualCode};
        },
      ).load('invitation-1');
      expect(requested, [
        'visitor:invitation-1',
        'credentials:invitation-1',
        'visitor:invitation-1',
      ]);
      expect(jsonDecode(pass.qrPayload), {
        'type': 'hominode_visitor',
        'version': 1,
        'token': token,
      });
      expect(pass.manualCode, manualCode);
      expect(pass.visitor.containsKey('qrToken'), isFalse);
      expect(pass.visitor.containsKey('visitorPassCode'), isFalse);
      expect(row['qrToken'], 'public-forgery');
    },
  );

  for (final credentials in [
    {'legacy': true, 'qrToken': token, 'visitorPassCode': manualCode},
    {'qrToken': 'visitor-document-id', 'visitorPassCode': manualCode},
    {'qrToken': token},
    {'visitorPassCode': manualCode},
    {'qrToken': token, 'visitorPassCode': '123'},
  ]) {
    test(
      'malformed or legacy credential response cannot display a pass: $credentials',
      () async {
        await expectLater(
          service(credentials: credentials).load('v1'),
          throwsStateError,
        );
      },
    );
  }

  test(
    'denied, terminal and consumed invitations cannot request credentials',
    () async {
      for (final patch in [
        {'gateAccessStatus': 'denied'},
        {'status': 'rejected'},
        {'status': 'cancelled'},
        {'status': 'inside', 'actualArrival': Timestamp.now()},
        {'status': 'completed'},
        {'authorizationState': 'rejected'},
        {'authorizationState': 'revoked'},
      ]) {
        await expectLater(
          service(record: visitor()..addAll(patch)).load('v1'),
          throwsStateError,
        );
      }
    },
  );

  test('an approved invitation remains eligible before arrival', () async {
    final pass = await service(
      record: visitor()..addAll({'status': 'approved', 'isApproved': true}),
    ).load('v1');
    expect(pass.manualCode, manualCode);
  });

  test(
    'a pending invitation requests server availability and may display after relaxation',
    () async {
      final row = visitor()
        ..addAll({
          'authorizationManaged': true,
          'authorizationState': 'pending_admin',
        });
      var requests = 0;
      var allowed = false;
      final passes = ResidentVisitorPassService(
        loadVisitor: (_) async => row,
        loadCredentials: (_) async {
          requests++;
          if (!allowed) {
            throw FirebaseFunctionsException(
              code: 'failed-precondition',
              message: 'Admin approval required',
              details: timing(),
            );
          }
          return {...timing(), 'qrToken': token, 'visitorPassCode': manualCode};
        },
      );
      await expectLater(
        passes.load('v1'),
        throwsA(isA<ResidentVisitorPassUnavailable>()),
      );
      allowed = true;
      expect((await passes.load('v1')).manualCode, manualCode);
      expect(requests, 2);
      expect(row['authorizationState'], 'pending_admin');
    },
  );

  test(
    'server availability decides expiry and a skewed device clock cannot block a valid pass',
    () async {
      final row = visitor()
        ..['expectedArrival'] = Timestamp.fromDate(
          DateTime.now().subtract(const Duration(days: 2)),
        );
      var requests = 0;
      final serverNow = DateTime.utc(2026, 1, 1).millisecondsSinceEpoch;
      final passes = ResidentVisitorPassService(
        loadVisitor: (_) async => row,
        loadCredentials: (_) async {
          requests++;
          if (requests == 1) {
            return {
              'serverTime': serverNow,
              'revalidateAt': serverNow + 3600_000,
              'qrToken': token,
              'visitorPassCode': manualCode,
            };
          }
          throw FirebaseFunctionsException(
            code: 'permission-denied',
            message: 'Expired',
          );
        },
      );
      expect((await passes.load('v1')).qrToken, token);
      await expectLater(
        passes.load('v1'),
        throwsA(isA<FirebaseFunctionsException>()),
      );
      expect(requests, 2);
    },
  );

  test(
    'missing server timing fails closed instead of showing an unbounded pass',
    () async {
      await expectLater(
        service(
          credentials: {'qrToken': token, 'visitorPassCode': manualCode},
        ).load('v1'),
        throwsStateError,
      );
    },
  );

  Future<void> mount(
    WidgetTester tester,
    Future<ResidentVisitorPass> Function(String) load, {
    double width = 393,
    double scale = 1,
    Stream<Map<String, dynamic>?> Function(String)? watchVisitor,
  }) async {
    tester.view.physicalSize = Size(width, 960);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('en')],
        startLocale: const Locale('en'),
        path: 'test',
        assetLoader: const _Strings(),
        child: Builder(
          builder: (context) => ScreenUtilInit(
            designSize: const Size(393, 852),
            minTextAdapt: true,
            builder: (_, _) => MaterialApp(
              locale: context.locale,
              supportedLocales: context.supportedLocales,
              localizationsDelegates: context.localizationDelegates,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: VisitorQRScreen(
                visitorId: 'invitation-1',
                loadPass: load,
                watchVisitor: watchVisitor,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  for (final wrapped in [true, false]) {
    testWidgets(
      'explicit Admin approval denial is neutral pending without Retry (wrapped=$wrapped)',
      (tester) async {
        final passes = ResidentVisitorPassService(
          loadVisitor: (_) async => visitor(),
          loadCredentials: (_) async => throw FirebaseFunctionsException(
            code: 'failed-precondition',
            message:
                'This invitation requires Admin approval under the current policy.',
            details: wrapped
                ? {'serverTime': 1000, 'revalidateAt': null}
                : null,
          ),
        );
        await mount(tester, passes.load, width: 320, scale: 1.5);
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.schedule_outlined), findsOneWidget);
        expect(
          tester.widget<Icon>(find.byIcon(Icons.schedule_outlined)).color,
          const Color(0xFF64748B),
        );
        expect(find.text('Awaiting Admin approval'), findsOneWidget);
        expect(
          find.text(
            'Your QR pass will be available once your Community Admin approves this invitation.',
          ),
          findsOneWidget,
        );
        expect(find.text('Retry'), findsNothing);
        expect(find.text('Back'), findsOneWidget);
        expect(
          tester
              .widget<ElevatedButton>(
                find.widgetWithText(ElevatedButton, 'Back'),
              )
              .onPressed,
          isNotNull,
        );
        expect(find.byType(QrImageView), findsNothing);
        expect(find.text('Pass code: $manualCode'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final code in [
    'unavailable',
    'deadline-exceeded',
    'network-request-failed',
  ]) {
    for (final wrapped in [false, true]) {
      testWidgets('recoverable $code offers Retry (wrapped=$wrapped)', (
        tester,
      ) async {
        var fail = true;
        final row = visitor();
        final passes = ResidentVisitorPassService(
          loadVisitor: (_) async => row,
          loadCredentials: (_) async {
            if (fail) {
              throw FirebaseFunctionsException(
                code: code,
                message: 'Network request could not complete.',
                details: wrapped
                    ? {'serverTime': 1000, 'revalidateAt': null}
                    : null,
              );
            }
            return {
              ...timing(),
              'qrToken': token,
              'visitorPassCode': manualCode,
            };
          },
        );
        await mount(tester, passes.load);
        await tester.pumpAndSettle();
        expect(find.text('Awaiting Admin approval'), findsNothing);
        expect(find.text('Retry'), findsOneWidget);
        expect(find.byType(QrImageView), findsNothing);
        fail = false;
        await tester.tap(find.text('Retry'));
        await tester.pumpAndSettle();
        expect(find.byType(QrImageView), findsOneWidget);
        expect(find.text('Pass code: $manualCode'), findsOneWidget);
      });
    }
  }

  for (final denial in [
    StateError('This visitor pass is unavailable: rejected.'),
    StateError('This visitor pass is unavailable: cancelled.'),
    StateError('This visitor pass has expired.'),
    StateError('This visitor pass is unavailable: revoked.'),
    FirebaseFunctionsException(
      code: 'failed-precondition',
      message: 'This invitation requires authorization review.',
    ),
    FirebaseFunctionsException(
      code: 'failed-precondition',
      message:
          'Pets are not permitted for this visit. You may continue without a pet.',
    ),
    FirebaseFunctionsException(
      code: 'permission-denied',
      message: 'Missing or insufficient permissions.',
    ),
    // Permission errors cannot be relabelled as pending, even with similar wording.
    FirebaseFunctionsException(
      code: 'permission-denied',
      message:
          'This invitation requires Admin approval under the current policy.',
    ),
  ]) {
    testWidgets('denial explains unavailability without Retry ($denial)', (
      tester,
    ) async {
      await mount(tester, (_) async => throw denial);
      await tester.pumpAndSettle();
      expect(find.text('Retry'), findsNothing);
      expect(find.text('Awaiting Admin approval'), findsNothing);
      expect(find.byIcon(Icons.schedule_outlined), findsNothing);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.text('Back'), findsOneWidget);
      expect(find.byType(QrImageView), findsNothing);
      expect(find.text('Pass code: $manualCode'), findsNothing);
      final expected = denial is StateError
          ? denial.message.toString()
          : (denial as FirebaseFunctionsException).code == 'permission-denied'
          ? 'Visitor access denied. Sign in again or contact your Community Admin.'
          : denial.message!;
      expect(find.text(expected), findsOneWidget);
    });
  }

  testWidgets('Admin approval snapshot resumes the existing QR retrieval flow', (
    tester,
  ) async {
    final updates = StreamController<Map<String, dynamic>?>.broadcast();
    addTearDown(updates.close);
    final row = visitor()..['authorizationState'] = 'pending_admin';
    var requests = 0;
    final passes = ResidentVisitorPassService(
      loadVisitor: (_) async => Map<String, dynamic>.from(row),
      loadCredentials: (_) async {
        requests++;
        if (row['authorizationState'] == 'pending_admin') {
          throw FirebaseFunctionsException(
            code: 'failed-precondition',
            message:
                'This invitation requires Admin approval under the current policy.',
            details: {'serverTime': 1000, 'revalidateAt': null},
          );
        }
        return {...timing(), 'qrToken': token, 'visitorPassCode': manualCode};
      },
    );
    await mount(tester, passes.load, watchVisitor: (_) => updates.stream);
    updates.add(Map<String, dynamic>.from(row));
    await tester.pumpAndSettle();
    expect(find.text('Awaiting Admin approval'), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
    row.addAll({
      'authorizationState': 'admin_authorized',
      'authorizationRevision': 2,
      'status': 'approved',
      'isApproved': true,
    });
    updates.add(Map<String, dynamic>.from(row));
    await tester.pumpAndSettle();
    expect(requests, 2);
    expect(find.text('Awaiting Admin approval'), findsNothing);
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.text('Pass code: $manualCode'), findsOneWidget);
  });

  for (final width in [393.0, 600.0, 800.0]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets('actual QR and selectable manual code fit $width at $scale', (
        tester,
      ) async {
        await mount(tester, service().load, width: width, scale: scale);
        await tester.pumpAndSettle();
        expect(find.byType(QrImageView), findsOneWidget);
        if (width == 393 && scale == 1) {
          final paint = tester
              .widgetList<CustomPaint>(
                find.descendant(
                  of: find.byType(QrImageView),
                  matching: find.byType(CustomPaint),
                ),
              )
              .map((widget) => widget.painter)
              .whereType<QrPainter>()
              .single;
          final expected = QrPainter(
            data: jsonEncode({
              'type': 'hominode_visitor',
              'version': 1,
              'token': token,
            }),
            version: QrVersions.auto,
            errorCorrectionLevel: QrErrorCorrectLevel.H,
            gapless: paint.gapless,
            eyeStyle: paint.eyeStyle,
            dataModuleStyle: paint.dataModuleStyle,
          );
          final images = await tester.runAsync(
            () async => [
              (await paint.toImageData(240))!.buffer.asUint8List(),
              (await expected.toImageData(240))!.buffer.asUint8List(),
            ],
          );
          expect(images![0], orderedEquals(images[1]));
        }
        expect(find.text('Pass code: $manualCode'), findsOneWidget);
        expect(find.text('Expected'), findsOneWidget);
        expect(find.text('Approved'), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets(
    'loading and failed retrieval never render a guessed QR; retry loads a real pass',
    (tester) async {
      final pending = Completer<ResidentVisitorPass>();
      var calls = 0;
      await mount(
        tester,
        (_) => ++calls == 1 ? pending.future : service().load('v1'),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(QrImageView), findsNothing);
      pending.completeError(TimeoutException('Visitor request timed out'));
      await tester.pumpAndSettle();
      expect(find.byType(QrImageView), findsNothing);
      expect(find.text('Unable to load visitor pass'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.byType(QrImageView), findsOneWidget);
      expect(find.text('Pass code: $manualCode'), findsOneWidget);
    },
  );

  testWidgets('disposing during private retrieval is safe', (tester) async {
    final pending = Completer<ResidentVisitorPass>();
    await mount(tester, (_) => pending.future);
    await tester.pumpWidget(const SizedBox());
    pending.complete(await service().load('v1'));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'a legacy response explains replacement and never renders a guessed credential',
    (tester) async {
      await mount(
        tester,
        service(
          credentials: {
            'legacy': true,
            'qrToken': token,
            'visitorPassCode': manualCode,
          },
        ).load,
      );
      await tester.pumpAndSettle();
      expect(find.text('This visitor pass must be replaced.'), findsOneWidget);
      expect(find.byType(QrImageView), findsNothing);
    },
  );

  testWidgets(
    'sharing supplies the actual manual code to the platform sheet without exposing the QR token',
    (tester) async {
      Map<Object?, Object?>? shared;
      const channel = MethodChannel('dev.fluttercommunity.plus/share');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        shared = call.arguments as Map<Object?, Object?>;
        return 'shared';
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      await mount(tester, service().load);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('share_pass'));
      await tester.tap(find.text('share_pass'));
      await tester.pumpAndSettle();
      expect(shared?['text'], contains(manualCode));
      expect(shared?['text'], isNot(contains(token)));
      expect(shared?['text'], isNot(contains('invitation-1')));
    },
  );

  testWidgets(
    'scheduled/emergency deadlines hide credentials while revalidating and retry after relaxation',
    (tester) async {
      final row = visitor()
        ..addAll({
          'authorizationManaged': true,
          'authorizationState': 'pending_admin',
        });
      var requests = 0;
      final waiting = Completer<Map<String, dynamic>>();
      final passes = ResidentVisitorPassService(
        loadVisitor: (_) async => row,
        loadCredentials: (_) async {
          requests++;
          if (requests == 1) {
            return {
              'serverTime': 1000,
              'revalidateAt': 3000,
              'qrToken': token,
              'visitorPassCode': manualCode,
            };
          }
          if (requests == 2) return waiting.future;
          return {
            'serverTime': 5000,
            'revalidateAt': null,
            'qrToken': token,
            'visitorPassCode': manualCode,
          };
        },
      );
      await mount(tester, passes.load);
      await tester.pumpAndSettle();
      expect(find.byType(QrImageView), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
      expect(find.byType(QrImageView), findsNothing);
      expect(find.text('Pass code: $manualCode'), findsNothing);
      waiting.completeError(
        FirebaseFunctionsException(
          code: 'failed-precondition',
          message: 'Admin approval required',
          details: {'serverTime': 3000, 'revalidateAt': 5000},
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Awaiting Admin approval'), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
      expect(find.byType(QrImageView), findsNothing);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(find.byType(QrImageView), findsOneWidget);
      expect(requests, 3);
      expect(row['authorizationState'], 'pending_admin');
    },
  );
}
