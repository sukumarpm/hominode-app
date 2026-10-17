import 'dart:async';

import 'package:admin_app/models/billing_schedule_v2.dart';
import 'package:admin_app/services/billing_service.dart';
import 'package:admin_app/widgets/create_billing_schedule_v2_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeBillingScheduleGateway implements BillingScheduleV2Gateway {
  final requests = <Map<String, dynamic>>[];
  Future<BillingScheduleCreatedV2> Function(Map<String, dynamic>)? onCreate;

  @override
  Future<List<BillingScheduleTargetV2>> loadBillingScheduleBuildings(
    String communityId,
  ) async => const [];

  @override
  Future<List<BillingScheduleTargetV2>> loadBillingScheduleUnits(
    String communityId,
  ) async => const [];

  @override
  Future<BillingScheduleCreatedV2> createBillingScheduleV2(
    Map<String, dynamic> request,
  ) {
    requests.add(Map<String, dynamic>.from(request));
    return onCreate?.call(request) ??
        Future.value(
          const BillingScheduleCreatedV2(
            scheduleId: 'schedule-1',
            revisionId: 'revision-1',
            revisionNo: 1,
            alreadyCompleted: false,
          ),
        );
  }
}

Map<String, dynamic> _validRequest({
  String idempotencyKey = 'schedule_test_1',
}) => {
  'schemaVersion': 2,
  'communityId': 'community-1',
  'currency': 'INR',
  'frequency': 'monthly',
  'idempotencyKey': idempotencyKey,
  'scope': 'community',
  'generationDay': 1,
  'dueDay': 5,
  'startBillingPeriod': '2026-10',
  'endBillingPeriod': null,
  'chargeLines': [
    {
      'lineId': 'maintenance-1',
      'code': 'maintenance',
      'label': 'Maintenance',
      'amountMinor': 150000,
    },
  ],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Billing V2 schedule contracts', () {
    test('parses INR exactly into paise and rejects invalid amounts', () {
      expect(parseBillingScheduleRupeesToMinorUnits('1500'), 150000);
      expect(parseBillingScheduleRupeesToMinorUnits('1500.5'), 150050);
      expect(parseBillingScheduleRupeesToMinorUnits('0.01'), 1);
      for (final value in ['0', '-2', '1.001', '1,000', 'text']) {
        expect(parseBillingScheduleRupeesToMinorUnits(value), isNull);
      }
    });

    test('validates schedule scope, dates and duplicate charge labels', () {
      expect(
        validateBillingScheduleRequestV2(_validRequest()),
        _validRequest(),
      );
      expect(
        () =>
            validateBillingScheduleRequestV2({..._validRequest(), 'dueDay': 0}),
        throwsFormatException,
      );
      expect(
        () => validateBillingScheduleRequestV2({
          ..._validRequest(),
          'endBillingPeriod': '2026-09',
        }),
        throwsFormatException,
      );
      expect(
        () => validateBillingScheduleRequestV2({
          ..._validRequest(),
          'chargeLines': [
            ..._validRequest()['chargeLines'] as List,
            {
              'lineId': 'maintenance-2',
              'code': 'custom',
              'label': ' maintenance ',
              'amountMinor': 100,
            },
          ],
        }),
        throwsFormatException,
      );
    });

    test(
      'service invokes the V2 callable only for the selected community',
      () async {
        String? calledName;
        Map<String, dynamic>? calledPayload;
        final service = BillingService(
          scheduleAdminId: () => 'admin-1',
          scheduleCommunityId: () => 'community-1',
          scheduleCallable: (name, payload) async {
            calledName = name;
            calledPayload = payload;
            return {
              'success': true,
              'scheduleId': 'schedule-1',
              'revisionId': 'revision-1',
              'revisionNo': 1,
              'alreadyCompleted': false,
            };
          },
        );

        final result = await service.createBillingScheduleV2(_validRequest());

        expect(calledName, 'createBillingScheduleV2');
        expect(calledPayload, _validRequest());
        expect(result.scheduleId, 'schedule-1');
        expect(result.revisionId, 'revision-1');
        expect(result.alreadyCompleted, isFalse);
      },
    );

    test(
      'service rejects an unresolved or malformed callable response',
      () async {
        final service = BillingService(
          scheduleAdminId: () => 'admin-1',
          scheduleCommunityId: () => 'community-1',
          scheduleCallable: (_, __) async => {
            'success': true,
            'scheduleId': 'x',
          },
        );
        await expectLater(
          service.createBillingScheduleV2(_validRequest()),
          throwsFormatException,
        );
      },
    );

    test(
      'service rejects community mismatches before invoking callable',
      () async {
        var invoked = false;
        final service = BillingService(
          scheduleAdminId: () => 'admin-1',
          scheduleCommunityId: () => 'community-2',
          scheduleCallable: (_, __) async {
            invoked = true;
            return const {};
          },
        );
        await expectLater(
          service.createBillingScheduleV2(_validRequest()),
          throwsStateError,
        );
        expect(invoked, isFalse);
      },
    );
  });

  group('Admin Billing V2 recurring schedule dialog', () {
    testWidgets('submits a configured recurring schedule and reports success', (
      tester,
    ) async {
      final gateway = _FakeBillingScheduleGateway();
      var createdCount = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CreateBillingScheduleV2Dialog(
              adminUid: 'admin-1',
              communityId: 'community-1',
              gateway: gateway,
              onCreated: () => createdCount++,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(_amountField(), '1500.00');
      await tester.tap(find.text('Create Schedule'));
      await tester.pumpAndSettle();

      expect(gateway.requests, hasLength(1));
      expect(gateway.requests.single['scope'], 'community');
      expect(
        gateway.requests.single['chargeLines'].single['amountMinor'],
        150000,
      );
      expect(gateway.requests.single['currency'], 'INR');
      expect(createdCount, 1);
      expect(
        find.text('Your monthly billing schedule was created successfully.'),
        findsOneWidget,
      );
    });

    testWidgets('blocks repeated taps while a request is pending', (
      tester,
    ) async {
      final gateway = _FakeBillingScheduleGateway();
      final response = Completer<BillingScheduleCreatedV2>();
      gateway.onCreate = (_) => response.future;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CreateBillingScheduleV2Dialog(
              adminUid: 'admin-2',
              communityId: 'community-1',
              gateway: gateway,
              onCreated: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(_amountField(), '10');
      await tester.tap(find.text('Create Schedule'));
      await tester.pump();
      await tester.tap(find.text('Creating…'));
      await tester.pump();

      expect(gateway.requests, hasLength(1));
      response.complete(
        const BillingScheduleCreatedV2(
          scheduleId: 'schedule-1',
          revisionId: 'revision-1',
          revisionNo: 1,
          alreadyCompleted: false,
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Your monthly billing schedule was created successfully.'),
        findsOneWidget,
      );
    });

    testWidgets('retry reuses the exact request and idempotency key', (
      tester,
    ) async {
      final gateway = _FakeBillingScheduleGateway();
      var attempts = 0;
      gateway.onCreate = (_) async {
        attempts++;
        if (attempts == 1) throw StateError('temporary failure');
        return const BillingScheduleCreatedV2(
          scheduleId: 'schedule-1',
          revisionId: 'revision-1',
          revisionNo: 1,
          alreadyCompleted: false,
        );
      };
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CreateBillingScheduleV2Dialog(
              adminUid: 'admin-3',
              communityId: 'community-1',
              gateway: gateway,
              onCreated: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(_amountField(), '10');
      await tester.tap(find.text('Create Schedule'));
      await tester.pumpAndSettle();
      expect(find.text('Retry Saved Request'), findsOneWidget);
      final firstPayload = Map<String, dynamic>.from(gateway.requests.single);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CreateBillingScheduleV2Dialog(
              adminUid: 'admin-3',
              communityId: 'community-1',
              gateway: gateway,
              onCreated: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('An earlier schedule request'),
        findsOneWidget,
      );

      await tester.tap(find.text('Retry Saved Request'));
      await tester.pumpAndSettle();
      expect(gateway.requests, hasLength(2));
      expect(gateway.requests.last, firstPayload);
      expect(
        gateway.requests.last['idempotencyKey'],
        firstPayload['idempotencyKey'],
      );
      expect(
        find.text('Your monthly billing schedule was created successfully.'),
        findsOneWidget,
      );
    });
  });
}

Finder _amountField() => find.byWidgetPredicate(
  (widget) =>
      widget is TextFormField &&
      widget.key is ValueKey<String> &&
      (widget.key as ValueKey<String>).value.startsWith(
        'billing-schedule-amount-',
      ),
);
