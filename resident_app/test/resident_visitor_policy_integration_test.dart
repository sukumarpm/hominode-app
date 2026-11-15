import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:resident_app/add_expected_visitor_modal.dart';
import 'package:resident_app/src/models/resident_visitor_authorization.dart';
import 'package:resident_app/src/providers/language_provider.dart';
import 'package:resident_app/src/screens/visitor_management_screen_new.dart';
import 'package:resident_app/src/services/resident_visitor_pass_service.dart';
import 'package:resident_app/src/services/resident_visitor_policy_service.dart';
import 'package:resident_app/src/services/visitor_firestore_service.dart';
import 'package:resident_app/src/services/visitor_qr_contract.dart';
import 'package:resident_app/visitor_qr_screen.dart';
import 'localization_test_app.dart';

const token = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmno12';
const code = 'ABCD-EFGHJKLM';
Map<String, dynamic> shared() =>
    jsonDecode(
          File(
            '../docs/fixtures/resident_visitor_contract.json',
          ).readAsStringSync(),
        )
        as Map<String, dynamic>;
Map<String, dynamic> record({String state = 'pending_admin'}) => {
  'id': 'visitor-1',
  'hostUserId': 'resident-1',
  'residentId': 'resident-1',
  'communityId': 'community-1',
  'visitorName': 'Contract Guest',
  'purpose': 'Visit',
  'flatLabel': 'N014',
  'status': 'expected',
  'isApproved': false,
  'expectedArrival': Timestamp.fromDate(
    DateTime.now().add(const Duration(hours: 1)),
  ),
  'authorizationManaged': true,
  'authorizationState': state,
  'authorizationRevision': 7,
  'bringingPet': false,
};

class _Auth extends Fake implements FirebaseAuth {
  @override
  User? get currentUser => _User();
}

class _User extends Fake implements User {
  @override
  String get uid => 'resident-1';
}

class _Db extends Fake implements FirebaseFirestore {}

class _Language extends Fake implements LanguageProvider {
  @override
  void addListener(VoidCallback listener) {}
  @override
  void removeListener(VoidCallback listener) {}
}

ResidentVisitorPolicyService policy({
  ResidentVisitorCallable? call,
  Stream<Object?> Function(String)? changes,
  String? zone = 'Asia/Manila',
}) => ResidentVisitorPolicyService(
  policyChanges: changes ?? (_) => const Stream.empty(),
  scopeLoader: () async => ResidentVisitorScope(
    uid: 'resident-1',
    communityId: 'community-1',
    timeZone: zone,
  ),
  callable:
      call ??
      (name, data) async => name == 'getResidentVisitorContext'
          ? {...shared()['context'] as Map, 'petPermitted': true}
          : {
              'visitorId': 'visitor-1',
              'authorizationState': 'revoked',
              'authorizationRevision': 8,
            },
);
VisitorFirestoreService creator(
  Future<Map<String, dynamic>> Function(Map<String, dynamic>) call,
) => VisitorFirestoreService.withDependencies(
  firestore: _Db(),
  auth: _Auth(),
  createInvitation: call,
);

Future<void> _mount(
  WidgetTester tester,
  Widget child, {
  double width = 600,
  double scale = 1,
}) async {
  tester.view.physicalSize = Size(width, 1100);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(393, 852),
      minTextAdapt: true,
      builder: (_, _) => withEnglishLocalization(
        (context) => localizedMaterialApp(
          context,
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(width, 1100),
              textScaler: TextScaler.linear(scale),
            ),
            child: ListenableProvider<LanguageProvider>.value(
              value: _Language(),
              child: Scaffold(body: child),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pump();
}

void main() {
  setUpAll(() async {
    await initializeTestLocalization();
    var directory = File(Platform.resolvedExecutable).parent;
    while (!File(
      '${directory.path}/bin/cache/artifacts/material_fonts/Roboto-Regular.ttf',
    ).existsSync()) {
      if (directory.parent.path == directory.path) {
        throw StateError('Flutter font not found');
      }
      directory = directory.parent;
    }
    final loader = FontLoader('Roboto')
      ..addFont(
        Future.value(
          ByteData.sublistView(
            File(
              '${directory.path}/bin/cache/artifacts/material_fonts/Roboto-Regular.ttf',
            ).readAsBytesSync(),
          ),
        ),
      );
    await loader.load();
  });

  test(
    'foreign-device creation sends exactly one community conversion',
    () async {
      for (final entry in {
        'Asia/Kolkata': '2026-11-14T17:02Z',
        'Asia/Manila': '2026-11-14T14:32Z',
        'America/New_York': '2026-11-15T03:32Z',
      }.entries) {
        Map<String, dynamic>? captured;
        final service = creator((data) async {
          captured = data;
          return {'visitorId': 'visitor-1'};
        });
        final result = await service.addExpectedVisitor(
          visitorName: 'Guest',
          purpose: 'Visit',
          expectedDate: DateTime.utc(2026, 11, 14),
          expectedTime: DateTime.utc(2000, 1, 1, 22, 32),
          timeZone: entry.key,
        );
        expect(result.success, true);
        expect(
          captured!['expectedArrival'],
          DateTime.parse(entry.value).millisecondsSinceEpoch,
        );
      }
    },
  );
  testWidgets(
    'rejected visitor card keeps one Rejected badge and rejection timestamp',
    (tester) async {
      await _mount(
        tester,
        VisitorManagementScreenNew(
          policyService: policy(),
          visitorService: creator((_) async => {}),
          visitors: Stream.value([
            {
              ...record(state: 'rejected'),
              'status': 'rejected',
              'rejectedAt': Timestamp.fromDate(
                DateTime.now().subtract(const Duration(minutes: 2)),
              ),
            },
          ]),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('History'));
      await tester.tap(find.text('History'));
      await tester.pumpAndSettle();
      expect(find.text('Rejected'), findsOneWidget);
      expect(find.textContaining('Rejected '), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'card, QR, and reschedule share canonical India appointment time',
    (tester) async {
      final row = {
        ...record(state: 'auto_authorized'),
        'expectedArrival': Timestamp.fromDate(
          DateTime.parse('2036-11-14T17:02:47Z'),
        ),
      };
      final scoped = policy(zone: 'Asia/Calcutta');
      await _mount(
        tester,
        VisitorManagementScreenNew(
          policyService: scoped,
          visitorService: creator((_) async => {}),
          visitors: Stream.value([row]),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('14 Nov 2036, 10:32 PM IST (Asia/Kolkata)'),
        findsOneWidget,
      );
      await _mount(
        tester,
        AddExpectedVisitorModal(
          visitor: row,
          policyService: scoped,
          visitorService: creator((_) async => {}),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('10:32 PM'), findsOneWidget);
      expect(find.text('14-11-2036'), findsOneWidget);
      expect(find.text('Community time · Asia/Kolkata (IST)'), findsOneWidget);
      final pass = ResidentVisitorPassService(
        loadVisitor: (_) async => row,
        loadCredentials: (_) async => {
          'qrToken': token,
          'visitorPassCode': code,
          'serverTime': DateTime.now().millisecondsSinceEpoch,
          'revalidateAt': null,
        },
      );
      await _mount(
        tester,
        VisitorQRScreen(
          visitorId: 'visitor-1',
          loadPass: pass.load,
          loadTimeZone: () async => 'Asia/Calcutta',
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('14 Nov 2036, 10:32 PM IST (Asia/Kolkata)'),
        findsOneWidget,
      );
    },
  );
  for (final zone in [null, '', 'Invalid/Zone']) {
    testWidgets(
      'invalid community zone reports configuration and disables scheduling ($zone)',
      (tester) async {
        await _mount(
          tester,
          AddExpectedVisitorModal(
            visitor: record(),
            policyService: policy(zone: zone),
            visitorService: creator((_) async => {}),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.textContaining('Community Admin'), findsWidgets);
        expect(
          tester
              .widget<ElevatedButton>(find.byType(ElevatedButton).last)
              .onPressed,
          isNull,
        );
      },
    );
  }
  test(
    'creation uses the shared contract, explicit pet boolean, and pending acknowledgement',
    () async {
      final request = shared()['create'] as Map<String, dynamic>;
      Map<String, dynamic>? captured;
      final service = creator((data) async {
        captured = data;
        return Map<String, dynamic>.from(shared()['pending'] as Map);
      });
      final time = DateTime.utc(2026, 11, 10, 8);
      final result = await service.addExpectedVisitor(
        visitorName: 'Contract Guest',
        purpose: 'Visit',
        expectedDate: time,
        expectedTime: time,
        bringingPet: true,
        timeZone: 'Asia/Manila',
      );
      expect(captured, request);
      expect(result.success, true);
      expect(result.authorizationState, 'pending_admin');
      expect(result.message, contains('Waiting for your Community Admin'));
    },
  );
  test(
    'new pet disclosure defaults false and backend pet failures retain generic wording',
    () async {
      Map<String, dynamic>? captured;
      final service = creator((data) async {
        captured = data;
        throw FirebaseFunctionsException(
          code: 'failed-precondition',
          message: residentPetVisitMessage,
        );
      });
      final result = await service.addExpectedVisitor(
        visitorName: 'Guest',
        purpose: 'Visit',
        expectedDate: DateTime.now(),
        expectedTime: DateTime.now(),
        timeZone: 'Asia/Manila',
      );
      expect(captured!['bringingPet'], false);
      expect(result.success, false);
      expect(result.message, residentPetVisitMessage);
    },
  );
  test(
    'context and mutation payloads exactly match the shared Web contract',
    () async {
      final calls = <Map<String, dynamic>>[];
      final service = policy(
        call: (name, data) async {
          calls.add({'name': name, 'data': data});
          return name == 'getResidentVisitorContext'
              ? Map<String, dynamic>.from(shared()['context'] as Map)
              : {
                  'visitorId': 'visitor-1',
                  'authorizationState': 'revoked',
                  'authorizationRevision': 8,
                };
        },
      );
      final instant = DateTime.fromMillisecondsSinceEpoch(
        (shared()['create'] as Map)['expectedArrival'] as int,
        isUtc: true,
      );
      await service.contextFor(instant);
      await service.mutate(record(), action: 'cancel');
      await service.mutate(
        record(),
        action: 'reschedule',
        arrival: instant,
        bringingPet: false,
      );
      expect(calls[0]['data'], shared()['contextRequest']);
      expect(calls[1]['data'], shared()['cancel']);
      expect(calls[2]['data'], shared()['reschedule']);
    },
  );
  test(
    'foreign host/community, stale revision, and unconfirmed mutation fail safely',
    () async {
      int calls = 0;
      final service = policy(
        call: (_, _) async {
          calls++;
          throw FirebaseFunctionsException(code: 'aborted', message: 'changed');
        },
      );
      for (final extra in [
        {'hostUserId': 'foreign'},
        {'communityId': 'foreign'},
      ]) {
        await expectLater(
          service.mutate({...record(), ...extra}, action: 'cancel'),
          throwsStateError,
        );
      }
      expect(calls, 0);
      await expectLater(
        service.mutate(record(), action: 'cancel'),
        throwsA(isA<FirebaseFunctionsException>()),
      );
      expect(
        residentVisitorError(
          FirebaseFunctionsException(code: 'aborted', message: 'changed'),
        ),
        contains('This invitation changed'),
      );
      await expectLater(
        policy(call: (_, _) async => {}).mutate(record(), action: 'cancel'),
        throwsStateError,
      );
    },
  );
  test(
    'authorization controls pass presentation without treating check-in as Admin approval',
    () {
      for (final state in ['rejected', 'revoked']) {
        expect(VisitorQrContract.canDisplay(record(state: state)), false);
      }
      for (final state in [
        'pending_admin',
        'auto_authorized',
        'admin_authorized',
      ]) {
        expect(VisitorQrContract.canDisplay(record(state: state)), true);
      }
      expect(
        ResidentVisitorAuthorization.label(record(state: 'auto_authorized')),
        'Resident authorized',
      );
      expect(
        VisitorQrContract.canDisplay({
          ...record(state: 'admin_authorized'),
          'actualArrival': Timestamp.now(),
        }),
        false,
      );
    },
  );
  test(
    'community timezone conversion rejects skipped/repeated DST and matches Web',
    () {
      expect(
        ResidentVisitTime.instant(
          '2026-11-10T08:00',
          'Asia/Manila',
        ).millisecondsSinceEpoch,
        (shared()['create'] as Map)['expectedArrival'],
      );
      for (final wall in ['2026-03-08T02:30', '2026-11-01T01:30']) {
        expect(
          () => ResidentVisitTime.instant(wall, 'America/New_York'),
          throwsFormatException,
        );
      }
    },
  );
  test(
    'private pass retrieval refuses an invitation revoked during retrieval',
    () async {
      int reads = 0;
      final row = record(state: 'auto_authorized');
      final service = ResidentVisitorPassService(
        loadVisitor: (_) async => reads++ == 0
            ? row
            : {
                ...row,
                'authorizationState': 'revoked',
                'authorizationRevision': 8,
              },
        loadCredentials: (_) async => {
          'serverTime': DateTime.now().millisecondsSinceEpoch,
          'revalidateAt': null,
          'qrToken': token,
          'visitorPassCode': code,
        },
      );
      await expectLater(service.load('visitor-1'), throwsStateError);
    },
  );
  for (final width in [393.0, 600.0, 800.0]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets(
        'Resident form fits $width at $scale and pet checkbox starts clear',
        (tester) async {
          await _mount(
            tester,
            AddExpectedVisitorModal(
              visitorService: creator(
                (_) async => shared()['pending'] as Map<String, dynamic>,
              ),
              policyService: policy(),
            ),
            width: width,
            scale: scale,
          );
          expect(
            tester
                .widget<CheckboxListTile>(find.byType(CheckboxListTile))
                .value,
            false,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  testWidgets(
    'pending approval is visible and Admin approval updates the Resident card',
    (tester) async {
      final updates = StreamController<List<Map<String, dynamic>>>.broadcast();
      addTearDown(updates.close);
      await _mount(
        tester,
        VisitorManagementScreenNew(
          visitors: updates.stream,
          policyService: policy(),
        ),
      );
      updates.add([record()]);
      await tester.pumpAndSettle();
      expect(find.text('Pending Admin approval'), findsOneWidget);
      expect(find.text('View QR Pass'), findsOneWidget);
      updates.add([
        {
          ...record(state: 'admin_authorized'),
          'status': 'approved',
          'isApproved': true,
          'authorizationRevision': 8,
        },
      ]);
      await tester.pumpAndSettle();
      expect(find.text('Admin authorized'), findsOneWidget);
      expect(
        find.textContaining('Waiting for your Community Admin'),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'rescheduling removes a pet, uses the displayed revision and locks duplicate saves',
    (tester) async {
      final pending = Completer<Map<String, dynamic>>();
      final calls = <Map<String, dynamic>>[];
      final service = policy(
        call: (name, data) async {
          if (name == 'getResidentVisitorContext') {
            return {...shared()['context'] as Map, 'petPermitted': true};
          }
          calls.add(data);
          return pending.future;
        },
      );
      await _mount(
        tester,
        AddExpectedVisitorModal(
          visitor: {
            ...record(state: 'auto_authorized'),
            'bringingPet': true,
          },
          visitorService: creator((_) async => {}),
          policyService: service,
        ),
      );
      await tester.ensureVisible(find.text('Visitor will bring a pet'));
      await tester.tap(find.text('Visitor will bring a pet'));
      await tester.pump();
      await tester.ensureVisible(find.text('Save new visit'));
      await tester.tap(find.text('Save new visit'));
      await tester.pump();
      expect(calls.single, {
        'visitorId': 'visitor-1',
        'action': 'reschedule',
        'expectedRevision': 7,
        'bringingPet': false,
      });
      expect(
        tester
            .widget<ElevatedButton>(find.byType(ElevatedButton).last)
            .onPressed,
        isNull,
      );
      pending.complete({
        'visitorId': 'visitor-1',
        'authorizationState': 'auto_authorized',
        'authorizationRevision': 8,
      });
      await tester.pumpAndSettle();
    },
  );
  testWidgets(
    'a live revocation clears an already displayed QR and private manual code',
    (tester) async {
      final updates = StreamController<Map<String, dynamic>?>.broadcast();
      addTearDown(updates.close);
      var current = record(state: 'auto_authorized');
      final service = ResidentVisitorPassService(
        loadVisitor: (_) async => current,
        loadCredentials: (_) async => {
          'serverTime': DateTime.now().millisecondsSinceEpoch,
          'revalidateAt': null,
          'qrToken': token,
          'visitorPassCode': code,
        },
      );
      await _mount(
        tester,
        VisitorQRScreen(
          visitorId: 'visitor-1',
          loadPass: service.load,
          watchVisitor: (_) => updates.stream,
          watchCommunity: (_) => const Stream.empty(),
        ),
      );
      updates.add(current);
      await tester.pumpAndSettle();
      expect(find.byType(QrImageView), findsOneWidget);
      current = {
        ...current,
        'authorizationState': 'revoked',
        'authorizationRevision': 8,
      };
      updates.add(current);
      await tester.pumpAndSettle();
      expect(find.byType(QrImageView), findsNothing);
      expect(find.text('Pass code: $code'), findsNothing);
    },
  );
  testWidgets(
    'cancellation requires confirmation and keeps the cancelled record in History',
    (tester) async {
      final updates = StreamController<List<Map<String, dynamic>>>.broadcast();
      addTearDown(updates.close);
      final calls = <Map<String, dynamic>>[];
      await _mount(
        tester,
        VisitorManagementScreenNew(
          visitors: updates.stream,
          policyService: policy(
            call: (_, data) async {
              calls.add(data);
              return {
                'visitorId': 'visitor-1',
                'authorizationState': 'revoked',
                'authorizationRevision': 8,
              };
            },
          ),
        ),
      );
      updates.add([record()]);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel Request'));
      await tester.pumpAndSettle();
      expect(calls, isEmpty);
      await tester.tap(find.text('Yes, Cancel'));
      await tester.pumpAndSettle();
      expect(calls.single, {
        'visitorId': 'visitor-1',
        'action': 'cancel',
        'expectedRevision': 7,
      });
      expect(find.textContaining('Cancellation confirmed.'), findsOneWidget);
      updates.add([
        {
          ...record(state: 'revoked'),
          'status': 'cancelled',
          'authorizationRevision': 8,
        },
      ]);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('History'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('History'));
      await tester.pumpAndSettle();
      expect(find.text('Contract Guest'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'pet guidance blocks a prohibited visit and allows removing the declaration',
    (tester) async {
      await _mount(
        tester,
        AddExpectedVisitorModal(
          visitor: {
            ...record(state: 'auto_authorized'),
            'bringingPet': true,
          },
          visitorService: creator((_) async => {}),
          policyService: policy(
            call: (_, _) async =>
                Map<String, dynamic>.from(shared()['context'] as Map),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();
      expect(find.text(residentPetVisitMessage), findsOneWidget);
      expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNull,
      );
      await tester.ensureVisible(find.text('Visitor will bring a pet'));
      await tester.tap(find.text('Visitor will bring a pet'));
      await tester.pump();
      expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNotNull,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'pending schedule metadata changes invalidate an open pass even with the same active revision',
    (tester) async {
      final updates = StreamController<Map<String, dynamic>?>.broadcast();
      final community = StreamController<Object?>.broadcast();
      addTearDown(updates.close);
      addTearDown(community.close);
      final row = record(state: 'auto_authorized');
      var requests = 0;
      final pending = Completer<Map<String, dynamic>>();
      final passes = ResidentVisitorPassService(
        loadVisitor: (_) async => row,
        loadCredentials: (_) async {
          requests++;
          if (requests > 1) return pending.future;
          return {
            'serverTime': 1000,
            'revalidateAt': null,
            'qrToken': token,
            'visitorPassCode': code,
          };
        },
      );
      await _mount(
        tester,
        VisitorQRScreen(
          visitorId: 'visitor-1',
          loadPass: passes.load,
          watchVisitor: (_) => updates.stream,
          watchCommunity: (_) => community.stream,
        ),
      );
      updates.add(row);
      await tester.pumpAndSettle();
      expect(find.byType(QrImageView), findsOneWidget);
      community.add({
        'visitorPolicy': {'revision': 1},
        'scheduledVisitorPolicy': {'revision': 2},
      });
      await tester.pump();
      await tester.pump();
      expect(requests, 2);
      expect(find.byType(QrImageView), findsNothing);
      expect(find.text('Pass code: $code'), findsNothing);
      pending.completeError(
        FirebaseFunctionsException(
          code: 'failed-precondition',
          message: 'Admin approval required',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(QrImageView), findsNothing);
    },
  );

  testWidgets(
    'policy boundaries and schedule snapshots refresh open form guidance without input changes',
    (tester) async {
      final changes = StreamController<Object?>.broadcast();
      addTearDown(changes.close);
      var calls = 0;
      final service = policy(
        changes: (_) => changes.stream,
        call: (name, _) async {
          if (name != 'getResidentVisitorContext') {
            throw StateError('No mutation expected');
          }
          calls++;
          return {
            'communityId': 'community-1',
            'petPermitted': calls != 2,
            'authorizationState': calls == 2
                ? 'pending_admin'
                : 'auto_authorized',
            'serverTime': calls == 1 ? 1000 : 3000,
            'revalidateAt': calls == 1 ? 3000 : null,
          };
        },
      );
      await _mount(
        tester,
        AddExpectedVisitorModal(
          visitor: {
            ...record(state: 'auto_authorized'),
            'bringingPet': true,
          },
          policyService: service,
          visitorService: creator((_) async => {}),
        ),
      );
      expect(calls, 1);
      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(find.text(residentPetVisitMessage), findsOneWidget);
      expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNull,
      );
      changes.add({
        'visitorPolicy': {'revision': 1},
        'scheduledVisitorPolicy': {'revision': 3},
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(calls, 3);
      expect(find.text(residentPetVisitMessage), findsNothing);
      expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNotNull,
      );
    },
  );
}
