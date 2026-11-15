import 'package:admin_app/services/visitor_policy_service.dart';
import 'package:admin_app/services/admin_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:admin_app/services/admin_tenant_context.dart';
import 'package:admin_app/models/tenant_config.dart';
import 'dart:async';

import 'package:admin_app/services/visitor_service.dart';
import 'package:admin_app/visitor_management_screen.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    for (final locale in ['en', 'ta', 'hi', 'es', 'ar']) {
      await rootBundle.loadString('assets/translations/$locale.json');
    }
  });

  final clock = DateTime.now();
  Map<String, dynamic> approvalPolicy({
    int revision = 4,
    bool enabled = true,
  }) => {
    'enabled': enabled,
    'revision': revision,
    'approvalMode': 'all_approval_required',
    'emergency': null,
  };
  VisitorModel authorized({int approvalRevision = 4}) => VisitorModel(
    id: 'action-visitor',
    visitorName: 'Action Guest',
    phone: '',
    residentId: 'resident',
    residentName: 'Host',
    flatId: 'A1',
    flatLabel: 'A1',
    purpose: 'Visit',
    status: 'approved',
    isApproved: true,
    authorizationState: 'admin_authorized',
    authorizationManaged: true,
    authorizationRevision: 9,
    authorizationPolicyRevision: approvalRevision,
    authorizationActorUid: 'admin',
    approvedBy: 'admin',
    approvedAt: clock.subtract(const Duration(minutes: 1)),
  );

  test(
    'action visibility follows current policy and hides terminal/physical states',
    () {
      final data = authorized().lifecycleData;
      expect(
        visitorDecisionActions({
          ...data,
          'authorizationState': 'pending_admin',
          'isApproved': false,
        }),
        [AdminVisitorAction.approve, AdminVisitorAction.reject],
      );
      expect(
        visitorDecisionActions(data, policy: approvalPolicy(), now: clock),
        [AdminVisitorAction.revoke],
      );
      expect(
        visitorDecisionActions(
          {...data, 'authorizationPolicyRevision': 3},
          policy: approvalPolicy(),
          now: clock,
        ),
        [AdminVisitorAction.reapprove, AdminVisitorAction.revoke],
      );
      expect(
        visitorDecisionActions(
          {...data, 'authorizationPolicyRevision': 3},
          policy: approvalPolicy(enabled: false),
          now: clock,
        ),
        [AdminVisitorAction.revoke],
      );
      final tenantPolicy = {
        ...approvalPolicy(),
        'approvalMode': 'tenant_approval_required',
      };
      expect(
        visitorDecisionActions(
          {...data, 'authorizationPolicyRevision': 3},
          policy: tenantPolicy,
          residentType: 'owner',
          now: clock,
        ),
        [AdminVisitorAction.revoke],
      );
      expect(
        visitorDecisionActions(
          {...data, 'authorizationPolicyRevision': 3},
          policy: tenantPolicy,
          residentType: 'tenant',
          now: clock,
        ),
        [AdminVisitorAction.reapprove, AdminVisitorAction.revoke],
      );
      final emergencyPolicy = {
        ...approvalPolicy(),
        'emergency': {
          'startAt': clock.millisecondsSinceEpoch,
          'endAt': clock.millisecondsSinceEpoch + 1000,
        },
      };
      expect(
        visitorDecisionActions(data, policy: emergencyPolicy, now: clock),
        [AdminVisitorAction.reapprove, AdminVisitorAction.revoke],
      );
      for (final status in [
        'rejected',
        'revoked',
        'cancelled',
        'inside',
        'completed',
        'denied',
      ]) {
        expect(
          visitorDecisionActions(
            {...data, 'status': status},
            policy: approvalPolicy(),
            now: clock,
          ),
          isEmpty,
        );
      }
      for (final state in ['rejected', 'revoked']) {
        expect(
          visitorDecisionActions(
            {...data, 'authorizationState': state},
            policy: approvalPolicy(),
            now: clock,
          ),
          isEmpty,
        );
      }
    },
  );

  testWidgets(
    'valid Admin authorization shows Revoke only and calls revoke with displayed revision',
    (tester) async {
      tester.view.physicalSize = const Size(390, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final service = _FakeVisitorWorkflowService(
        pendingVisitors: [authorized()],
      );
      await _pumpVisitorApp(
        tester,
        service,
        policyService: _ActionPolicy(approvalPolicy(), clock),
      );
      expect(find.text('Revoke'), findsOneWidget);
      for (final label in ['Approve', 'Reject', 'Reapprove']) {
        expect(find.text(label), findsNothing);
      }
      await tester.ensureVisible(find.text('Revoke'));
      await tester.tap(find.text('Revoke'));
      await tester.pumpAndSettle();
      expect(service.revokedVisitorIds, isEmpty);
      await tester.tap(find.text('Confirm revoke'));
      await tester.pumpAndSettle();
      expect(service.revokedVisitorIds, ['action-visitor']);
      expect(service.revokedRevisions, [9]);
      expect(service.rejectedVisitorIds, isEmpty);
    },
  );

  testWidgets(
    'stale authorization shows Reapprove and Revoke; renewal calls approve with revision',
    (tester) async {
      tester.view.physicalSize = const Size(390, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final service = _FakeVisitorWorkflowService(
        pendingVisitors: [authorized(approvalRevision: 3)],
      );
      await _pumpVisitorApp(
        tester,
        service,
        policyService: _ActionPolicy(approvalPolicy(), clock),
      );
      expect(find.text('Reapprove'), findsOneWidget);
      expect(find.text('Revoke'), findsOneWidget);
      expect(find.text('Reject'), findsNothing);
      await tester.ensureVisible(find.text('Reapprove'));
      await tester.tap(find.text('Reapprove'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm reapprove'));
      await tester.pumpAndSettle();
      expect(service.approvedVisitorIds, ['action-visitor']);
      expect(service.approvedRevisions, [9]);
    },
  );

  testWidgets('current policy updates refresh approval action visibility', (
    tester,
  ) async {
    final service = _FakeVisitorWorkflowService(
      pendingVisitors: [authorized()],
    );
    final policy = _ActionPolicy(approvalPolicy(), clock);
    final changes = StreamController<int>.broadcast();
    addTearDown(changes.close);
    policy.changes = changes.stream;
    await _pumpVisitorApp(tester, service, policyService: policy);
    expect(find.text('Reapprove'), findsNothing);
    policy.policy = approvalPolicy(revision: 5);
    changes.add(5);
    await tester.pumpAndSettle();
    expect(find.text('Reapprove'), findsOneWidget);
    expect(find.text('Revoke'), findsOneWidget);
  });

  test(
    'revoke uses the existing callable and revision; parsing retains approval provenance',
    () async {
      final db = FakeFirebaseFirestore();
      await db.collection('visitors').doc('v').set({
        'communityId': 'community-1',
        'authorizationRevision': 11,
      });
      final calls = <Map<String, dynamic>>[];
      final service = VisitorService(
        firestore: db,
        adminService: _ActionAdmin(),
        callable: (name, payload) async {
          calls.add({'name': name, ...payload});
          return {};
        },
      );
      await service.revokeVisitor('v', expectedRevision: 9);
      expect(calls.single, {
        'name': 'decideVisitorInvitation',
        'communityId': 'community-1',
        'visitorId': 'v',
        'action': 'revoke',
        'expectedRevision': 9,
      });
      final model = VisitorModel.fromFirestore('v', {
        'authorizationPolicyRevision': 4,
        'authorizationActorUid': 'admin',
        'approvedBy': 'admin',
        'approvedAt': Timestamp.fromDate(clock),
      });
      expect(model.lifecycleData['authorizationPolicyRevision'], 4);
      expect(model.lifecycleData['authorizationActorUid'], 'admin');
      expect(model.lifecycleData['approvedAt'], clock);
    },
  );

  test(
    'host role comes from the current scoped profile and rejects conflicts',
    () async {
      final db = FakeFirebaseFirestore();
      final service = VisitorService(
        firestore: db,
        adminService: _ActionAdmin(),
      );
      final visitor = VisitorModel.fromFirestore('v', {
        'communityId': 'community-1',
        'residentId': 'host',
      });
      final profile = db.collection('users').doc('host');
      await profile.set({
        'uid': 'host',
        'role': 'resident',
        'communityId': 'community-1',
        'declaredResidentType': ' Tenant ',
      });
      expect(
        await service.watchVisitorHostResidentType(visitor).first,
        'tenant',
      );
      await profile.update({'residentType': 'owner'});
      expect(await service.watchVisitorHostResidentType(visitor).first, isNull);
      await profile.update({'declaredResidentType': 'owner'});
      expect(
        await service.watchVisitorHostResidentType(visitor).first,
        'owner',
      );
      await profile.update({'communityId': 'another-community'});
      expect(await service.watchVisitorHostResidentType(visitor).first, isNull);
    },
  );
  testWidgets(
    'Admin approval shows the same community appointment as other roles',
    (tester) async {
      final context = AdminTenantContext.instance;
      context.addAuthorizedCommunity('timezone-community');
      context.selectTenant(
        const TenantConfig(
          communityId: 'timezone-community',
          name: 'Timezone',
          slug: 'timezone',
          websitePath: 'timezone',
          databaseId: '(default)',
          isActive: true,
          createdBy: 'admin',
          locationConfigured: false,
          timeZone: 'Asia/Calcutta',
        ),
      );
      addTearDown(context.clear);
      final service = _FakeVisitorWorkflowService(
        pendingVisitors: [
          VisitorModel(
            id: 'timezone',
            visitorName: 'Timezone Guest',
            phone: '',
            residentId: 'resident',
            residentName: 'Host',
            flatId: 'A1',
            flatLabel: 'A1',
            purpose: 'Visit',
            status: 'expected',
            expectedTime: DateTime.parse('2036-11-14T17:02:47Z'),
          ),
        ],
      );
      await _pumpVisitorApp(tester, service);
      expect(
        find.text('Expected: 14 Nov 2036, 10:32 PM IST (Asia/Kolkata)'),
        findsOneWidget,
      );
    },
  );
  testWidgets('reject targets the intended visitor document id', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final service = _FakeVisitorWorkflowService(
      pendingVisitors: [
        VisitorModel(
          id: 'queen-doc-id',
          visitorName: 'Queen',
          phone: '9999999999',
          residentId: 'resident-1',
          residentName: 'Asha',
          flatId: 'F-101',
          flatLabel: 'F-101',
          purpose: 'Delivery',
          status: 'expected',
          createdAt: DateTime(2026, 9, 1, 10),
        ),
      ],
    );

    await _pumpVisitorApp(tester, service);

    final rejectButton = tester.widget<OutlinedButton>(
      find.byType(OutlinedButton).first,
    );
    rejectButton.onPressed!.call();
    await tester.pumpAndSettle();
    expect(service.rejectedVisitorIds, isEmpty);
    await tester.tap(find.text('Confirm reject'));
    await tester.pumpAndSettle();

    expect(service.rejectedVisitorIds, ['queen-doc-id']);
    expect(
      find.text(
        'Decision confirmed by the server. Security still verifies entry.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('admin approval does not check the visitor in', (tester) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final service = _FakeVisitorWorkflowService(
      pendingVisitors: [
        VisitorModel(
          id: 'queen-doc-id',
          visitorName: 'Queen',
          phone: '9999999999',
          residentId: 'resident-1',
          residentName: 'Asha',
          flatId: 'F-101',
          flatLabel: 'F-101',
          purpose: 'Delivery',
          status: 'expected',
          createdAt: DateTime(2026, 9, 1, 10),
        ),
      ],
    );

    await _pumpVisitorApp(tester, service);

    final approveButton = tester.widget<ElevatedButton>(
      find.byType(ElevatedButton).first,
    );
    approveButton.onPressed!.call();
    await tester.pumpAndSettle();
    expect(service.approvedVisitorIds, isEmpty);
    await tester.tap(find.text('Confirm approve'));
    await tester.pumpAndSettle();

    expect(service.approvedVisitorIds, ['queen-doc-id']);
    expect(
      find.textContaining(
        'Decision confirmed by the server. Security still verifies entry.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('visitor management uses Arabic text direction', (tester) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpVisitorApp(
      tester,
      _FakeVisitorWorkflowService(),
      locale: const Locale('ar'),
    );

    final title = find.text('إدارة الزوار').last;
    expect(find.text('إدارة الزوار'), findsNWidgets(2));
    expect(Directionality.of(tester.element(title)).name, 'rtl');
  });

  testWidgets('success is reported only after reject write succeeds', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final completer = Completer<void>();
    final service = _FakeVisitorWorkflowService(
      pendingVisitors: [
        VisitorModel(
          id: 'queen-doc-id',
          visitorName: 'Queen',
          phone: '9999999999',
          residentId: 'resident-1',
          residentName: 'Asha',
          flatId: 'F-101',
          flatLabel: 'F-101',
          purpose: 'Delivery',
          status: 'expected',
          createdAt: DateTime(2026, 9, 1, 10),
        ),
      ],
      rejectCompleter: completer,
    );

    await _pumpVisitorApp(tester, service);

    final rejectButton = tester.widget<OutlinedButton>(
      find.byType(OutlinedButton).first,
    );
    rejectButton.onPressed!.call();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm reject'));
    await tester.pump();

    expect(
      find.text(
        'Decision confirmed by the server. Security still verifies entry.',
      ),
      findsNothing,
    );

    completer.complete();
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Decision confirmed by the server. Security still verifies entry.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('failed reject does not report successful rejection', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final service = _FakeVisitorWorkflowService(
      pendingVisitors: [
        VisitorModel(
          id: 'queen-doc-id',
          visitorName: 'Queen',
          phone: '9999999999',
          residentId: 'resident-1',
          residentName: 'Asha',
          flatId: 'F-101',
          flatLabel: 'F-101',
          purpose: 'Delivery',
          status: 'expected',
          createdAt: DateTime(2026, 9, 1, 10),
        ),
      ],
      rejectError: Exception('permission-denied'),
    );

    await _pumpVisitorApp(tester, service);

    final rejectButton = tester.widget<OutlinedButton>(
      find.byType(OutlinedButton).first,
    );
    rejectButton.onPressed!.call();
    await tester.pumpAndSettle();
    expect(service.rejectedVisitorIds, isEmpty);
    await tester.tap(find.text('Confirm reject'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Decision confirmed by the server. Security still verifies entry.',
      ),
      findsNothing,
    );
    expect(find.textContaining('permission-denied'), findsOneWidget);
  });
}

Future<void> _pumpVisitorApp(
  WidgetTester tester,
  VisitorWorkflowService service, {
  Locale locale = const Locale('en'),
  VisitorPolicyService? policyService,
}) async {
  await tester.pumpWidget(
    _testApp(service, locale: locale, policyService: policyService),
  );
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 100)),
  );
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pumpAndSettle();
}

Widget _testApp(
  VisitorWorkflowService service, {
  Locale locale = const Locale('en'),
  VisitorPolicyService? policyService,
}) {
  return EasyLocalization(
    supportedLocales: const [
      Locale('en'),
      Locale('ta'),
      Locale('hi'),
      Locale('es'),
      Locale('ar'),
    ],
    path: 'assets/translations',
    fallbackLocale: const Locale('en'),
    startLocale: locale,
    saveLocale: false,
    child: ScreenUtilInit(
      designSize: const Size(390, 844),
      minTextAdapt: true,
      splitScreenMode: true,
      child: VisitorManagementScreen(
        visitorService: service,
        policyService: policyService,
      ),
      builder: (context, child) => MaterialApp(
        locale: context.locale,
        supportedLocales: context.supportedLocales,
        localizationsDelegates: context.localizationDelegates,
        home: child,
      ),
    ),
  );
}

class _FakeVisitorWorkflowService implements VisitorWorkflowService {
  _FakeVisitorWorkflowService({
    List<VisitorModel>? pendingVisitors,
    this.rejectCompleter,
    this.rejectError,
  }) : _pendingVisitors = pendingVisitors ?? const [];

  final List<VisitorModel> _pendingVisitors;
  final Completer<void>? rejectCompleter;
  final Object? rejectError;
  final List<String> approvedVisitorIds = <String>[];
  final List<String> rejectedVisitorIds = <String>[];
  final List<String> revokedVisitorIds = [];
  final List<int?> approvedRevisions = [],
      revokedRevisions = [],
      rejectedRevisions = [];

  @override
  Stream<String?> watchVisitorHostResidentType(VisitorModel visitor) =>
      Stream.value('tenant');

  @override
  Future<void> revokeVisitor(String visitorId, {int? expectedRevision}) async {
    revokedVisitorIds.add(visitorId);
    revokedRevisions.add(expectedRevision);
  }

  @override
  Stream<List<VisitorModel>> getPendingVisitors() =>
      Stream.value(_pendingVisitors);

  @override
  Stream<List<VisitorModel>> getActiveVisitors() =>
      const Stream<List<VisitorModel>>.empty();

  @override
  Stream<List<VisitorModel>> getHistoryVisitors() =>
      const Stream<List<VisitorModel>>.empty();

  @override
  Future<void> approveVisitor(String visitorId, {int? expectedRevision}) async {
    approvedVisitorIds.add(visitorId);
    approvedRevisions.add(expectedRevision);
  }

  @override
  Future<void> checkOutVisitor(String visitorId) async {}

  @override
  Future<void> rejectVisitor(String visitorId, {int? expectedRevision}) async {
    rejectedVisitorIds.add(visitorId);
    rejectedRevisions.add(expectedRevision);
    if (rejectError != null) {
      throw rejectError!;
    }
    if (rejectCompleter != null) {
      await rejectCompleter!.future;
    }
  }
}

class _ActionPolicy extends Fake implements VisitorPolicyService {
  _ActionPolicy(this.policy, this.clock);
  Map<String, dynamic> policy;
  final DateTime clock;
  Stream<int> changes = const Stream.empty();
  @override
  Stream<int> watch() => changes;
  @override
  Future<VisitorPolicyConfig> load() async => VisitorPolicyConfig.fromMap({
    'communityId': 'community-1',
    'timeZone': 'Asia/Manila',
    'rolloutReady': true,
    'writeRevision': policy['revision'],
    'policy': policy,
    'serverTime': clock.millisecondsSinceEpoch,
  });
}

class _ActionAdmin extends Fake implements AdminService {
  @override
  String? getCurrentAdminId() => 'admin';
  @override
  String requireCurrentCommunityId() => 'community-1';
}
