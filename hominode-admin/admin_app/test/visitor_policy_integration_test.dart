import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:admin_app/services/admin_service.dart';
import 'package:admin_app/services/admin_tenant_context.dart';
import 'package:admin_app/services/visitor_policy_service.dart';
import 'package:admin_app/services/visitor_service.dart';
import 'package:admin_app/widgets/visitor_policy_settings_card.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> fixture() {
  final value =
      jsonDecode(
            File(
              '../../docs/fixtures/visitor_policy_contract.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;
  (value['loaded'] as Map).addAll(<String, dynamic>{
    'writeRevision': 4,
    'rolloutReady': true,
    'timeZone': 'Asia/Manila',
    'pendingSchedule': null,
  });
  ((value['loaded'] as Map)['policy'] as Map)['enabled'] = true;
  return value;
}

Map<String, dynamic> copy(Map value) =>
    Map<String, dynamic>.from(jsonDecode(jsonEncode(value)) as Map);

class _Admin extends Fake implements AdminService {
  @override
  String? getCurrentAdminId() => 'admin-1';
  @override
  String requireCurrentCommunityId() => 'community-1';
}

class _Policy extends Fake implements VisitorPolicyService {
  Map<String, dynamic> value = copy(fixture()['loaded'] as Map);
  Object? error;
  Completer<VisitorPolicyConfig>? loading, saving;
  final updates = StreamController<int>.broadcast();
  final saves = <Map<String, dynamic>>[];
  @override
  String get communityId => value['communityId'] as String;
  @override
  Stream<int> watch() => updates.stream;
  @override
  Future<VisitorPolicyConfig> load() async {
    if (error != null) throw error!;
    return loading?.future ?? VisitorPolicyConfig.fromMap(copy(value));
  }

  @override
  Future<VisitorPolicyConfig> save(
    Map<String, dynamic> policy,
    int revision, {
    int? effectiveAt,
  }) async {
    saves.add({
      'communityId': communityId,
      'policy': copy(policy),
      'expectedRevision': revision,
      if (effectiveAt != null) 'effectiveAt': effectiveAt,
    });
    if (error != null) throw error!;
    if (saving != null) return saving!.future;
    value['writeRevision'] = revision + 1;
    if (effectiveAt != null) {
      value['pendingSchedule'] = {
        'policy': copy(policy),
        'revision': revision + 1,
        'effectiveAt': effectiveAt,
      };
    } else {
      value['policy'] = {...copy(policy), 'revision': revision + 1};
      value['pendingSchedule'] = null;
    }
    return VisitorPolicyConfig.fromMap(copy(value));
  }
}

Future<void> _mount(
  WidgetTester tester,
  _Policy service, {
  double width = 600,
  double scale = 1,
}) async {
  tester.view.physicalSize = Size(width, 1280);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: Size(width, 1280),
          textScaler: TextScaler.linear(scale),
        ),
        child: Scaffold(
          body: SingleChildScrollView(
            child: VisitorPolicySettingsCard(service: service),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

Future<void> save(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Save visitor settings'));
  await tester.tap(find.text('Save visitor settings'));
  await tester.pumpAndSettle();
}

Future<void> choose(WidgetTester tester, String label, String option) async {
  final select = find.byKey(ValueKey(label));
  await tester.ensureVisible(select);
  await tester.tap(select);
  await tester.pumpAndSettle();
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'loading and duplicate-save protection wait for confirmed backend success',
    (tester) async {
      final service = _Policy()..loading = Completer<VisitorPolicyConfig>();
      addTearDown(service.updates.close);
      await _mount(tester, service);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      service.loading!.complete(
        VisitorPolicyConfig.fromMap(copy(service.value)),
      );
      await tester.pumpAndSettle();
      service.saving = Completer<VisitorPolicyConfig>();
      await save(tester);
      expect(service.saves.length, 1);
      expect(find.textContaining('saved and reloaded'), findsNothing);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Saving…'))
            .onPressed,
        isNull,
      );
      service.saving!.complete(
        VisitorPolicyConfig.fromMap(copy(service.value)),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('saved and reloaded'), findsOneWidget);
    },
  );
  testWidgets(
    'an enabled policy stays editable and Save enforces the edited rules',
    (tester) async {
      final service = _Policy();
      (service.value['policy'] as Map)['enabled'] = true;
      addTearDown(service.updates.close);
      await _mount(tester, service);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Save visitor settings'),
            )
            .onPressed,
        isNotNull,
      );
      await choose(
        tester,
        'Approval mode:tenant_approval_required',
        'All invitations require approval',
      );
      await save(tester);
      expect((service.saves.single['policy'] as Map)['enabled'], true);
      expect(
        (service.saves.single['policy'] as Map)['approvalMode'],
        'all_approval_required',
      );
      expect(find.text('Enforce'), findsNothing);
      expect(find.textContaining('Enforcement is active.'), findsOneWidget);
    },
  );
  for (final selected in [true, false]) {
    testWidgets(
      'enforcement toggle saves $selected without a separate action',
      (tester) async {
        final service = _Policy();
        (service.value['policy'] as Map)['enabled'] = !selected;
        service.value['rolloutReady'] = selected;
        addTearDown(service.updates.close);
        await _mount(tester, service);
        await tester.pumpAndSettle();
        final toggle = find.byKey(const ValueKey('visitor-enforcement-toggle'));
        tester.widget<SwitchListTile>(toggle).onChanged!(selected);
        await tester.pumpAndSettle();
        await save(tester);
        expect((service.saves.single['policy'] as Map)['enabled'], selected);
        expect(find.text('Enforce'), findsNothing);
      },
    );
  }
  test(
    'service preserves OFF and permits disabling without rollout readiness',
    () async {
      final response = copy(fixture()['loaded'] as Map)
        ..['rolloutReady'] = false;
      final calls = <Map<String, dynamic>>[];
      final service = VisitorPolicyService(
        community: () => 'community-1',
        callable: (name, payload) async {
          if (name == 'updateCommunityVisitorPolicy') calls.add(payload);
          return name == 'getCommunityVisitorPolicy' ? response : {};
        },
      );
      final loaded = await service.load();
      await service.save({
        ...loaded.policy,
        'enabled': false,
      }, loaded.writeRevision);
      expect((calls.single['policy'] as Map)['enabled'], false);
      await expectLater(
        service.save({...loaded.policy, 'enabled': true}, loaded.writeRevision),
        throwsStateError,
      );
    },
  );

  test(
    'Admin Save sends enabled policy and the current write revision',
    () async {
      final shared = fixture(), calls = <Map<String, dynamic>>[];
      final service = VisitorPolicyService(
        community: () => 'community-1',
        callable: (name, payload) async {
          calls.add({'name': name, 'payload': payload});
          return name == 'getCommunityVisitorPolicy'
              ? copy(shared['loaded'] as Map)
              : {};
        },
      );
      final value = await service.load();
      await service.save(visitorPolicyInput(value.policy), value.writeRevision);
      expect(calls.map((c) => c['name']), [
        'getCommunityVisitorPolicy',
        'updateCommunityVisitorPolicy',
        'getCommunityVisitorPolicy',
      ]);
      expect(calls[1]['payload'], {
        ...(shared['save'] as Map),
        'policy': {
          ...((shared['save'] as Map)['policy'] as Map),
          'enabled': true,
        },
      });
    },
  );
  test(
    'mismatched community response and changed scope are rejected',
    () async {
      final value = copy(fixture()['loaded'] as Map)
        ..['communityId'] = 'foreign';
      final service = VisitorPolicyService(
        community: () => 'community-1',
        callable: (_, _) async => value,
      );
      await expectLater(service.load(), throwsStateError);
    },
  );
  for (final action in ['approve', 'reject']) {
    test(
      '$action uses decideVisitorInvitation with displayed revision, no direct state mutation',
      () async {
        final db = FakeFirebaseFirestore();
        await db.collection('visitors').doc('visitor-1').set({
          'communityId': 'community-1',
          'status': 'expected',
          'authorizationRevision': 8,
        });
        final calls = <Map<String, dynamic>>[];
        final service = VisitorService(
          firestore: db,
          adminService: _Admin(),
          callable: (name, payload) async {
            calls.add({'name': name, 'payload': payload});
            return {};
          },
        );
        if (action == 'approve') {
          await service.approveVisitor('visitor-1', expectedRevision: 7);
        } else {
          await service.rejectVisitor('visitor-1', expectedRevision: 7);
        }
        expect(calls.single['name'], 'decideVisitorInvitation');
        expect(calls.single['payload'], {
          ...(fixture()['decision'] as Map),
          'action': action,
        });
        expect(
          (await db.collection('visitors').doc('visitor-1').get())
              .data()!['status'],
          'expected',
        );
        await db.collection('visitors').doc('visitor-1').update({
          'communityId': 'foreign',
        });
        await expectLater(
          service.approveVisitor('visitor-1'),
          throwsStateError,
        );
        expect(calls.length, 1);
      },
    );
  }
  test(
    'managed queue counts ignore auto authorization and separate physical entry',
    () {
      final expected = {'status': 'expected', 'isApproved': false};
      expect(
        visitorRequiresAdminApproval({
          ...expected,
          'authorizationState': 'pending_admin',
        }),
        true,
      );
      expect(
        visitorBelongsInPendingQueue({
          ...expected,
          'authorizationState': 'auto_authorized',
        }),
        false,
      );
      expect(
        visitorBelongsInPendingQueue({
          ...expected,
          'visitorPolicySnapshot': {'enforced': false},
        }),
        false,
      );
      expect(
        visitorBelongsInActiveQueue({
          ...expected,
          'authorizationState': 'admin_authorized',
        }),
        false,
      );
      expect(
        visitorBelongsInActiveQueue({
          ...expected,
          'actualArrival': DateTime.now(),
          'authorizationState': 'admin_authorized',
        }),
        true,
      );
      for (final state in ['rejected', 'revoked']) {
        expect(
          visitorBelongsInHistoryQueue({
            ...expected,
            'authorizationState': state,
          }),
          true,
        );
      }
    },
  );
  test(
    'community time conversion rejects ambiguous/skipped DST and calendar errors',
    () {
      expect(
        VisitorSchedule.local(
          VisitorSchedule.instant('2026-11-09T08:00', 'Asia/Manila'),
          'Asia/Manila',
        ),
        '2026-11-09T08:00',
      );
      for (final time in [
        '2026-03-08T02:30',
        '2026-11-01T01:30',
        '2026-02-30T12:00',
      ]) {
        expect(
          () => VisitorSchedule.instant(time, 'America/New_York'),
          throwsFormatException,
        );
      }
      expect(
        () => VisitorSchedule.period(
          '2026-11-09T09:00',
          '2026-11-09T08:00',
          'Asia/Manila',
        ),
        throwsFormatException,
      );
      expect(
        [99, 100, 199, 200].map(
          (now) => VisitorSchedule.status({'startAt': 100, 'endAt': 200}, now),
        ),
        ['Scheduled', 'Active', 'Active', 'Expired'],
      );
    },
  );
  for (final width in [393.0, 600.0, 800.0]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets('policy controls fit $width at scale $scale', (tester) async {
        final service = _Policy();
        addTearDown(service.updates.close);
        await _mount(tester, service, width: width, scale: scale);
        await tester.pumpAndSettle();
        expect(find.text('Visitor Policies'), findsOneWidget);
        await tester.ensureVisible(find.text('Save visitor settings'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }
  for (final mode in visitorApprovalOptions.keys) {
    testWidgets('saves and reloads $mode as enforced settings', (tester) async {
      final service = _Policy();
      addTearDown(service.updates.close);
      await _mount(tester, service);
      await choose(
        tester,
        'Approval mode:tenant_approval_required',
        visitorApprovalOptions[mode]!,
      );
      await save(tester);
      expect(service.saves.single['expectedRevision'], 4);
      final policy = service.saves.single['policy'] as Map;
      expect(policy['enabled'], true);
      expect(policy['approvalMode'], mode);
      expect(policy.containsKey('revision'), false);
      expect(find.textContaining('saved and reloaded'), findsOneWidget);
    });
  }
  for (final mode in ['allowed', 'not_allowed', 'temporarily_restricted']) {
    testWidgets('pet mode $mode uses shared schema', (tester) async {
      final service = _Policy();
      addTearDown(service.updates.close);
      await _mount(tester, service);
      await choose(
        tester,
        'Pet entry rule:temporarily_restricted',
        {
          'allowed': 'Pets allowed',
          'not_allowed': 'Pets not allowed',
          'temporarily_restricted': 'Temporarily restricted',
        }[mode]!,
      );
      await save(tester);
      final pets = ((service.saves.single['policy'] as Map)['pets'] as Map);
      expect(pets['mode'], mode);
      expect(pets['restriction'] != null, mode == 'temporarily_restricted');
    });
  }
  testWidgets(
    'invalid emergency interval prevents submission; unchecking cancels through null',
    (tester) async {
      final service = _Policy();
      addTearDown(service.updates.close);
      await _mount(tester, service);
      await tester.enterText(
        find.widgetWithText(TextField, 'Emergency end'),
        '2026-11-09T07:59',
      );
      await save(tester);
      expect(service.saves, isEmpty);
      expect(find.text('End must be after start.'), findsOneWidget);
      await tester.ensureVisible(find.text('Set temporary approval period'));
      await tester.tap(find.text('Set temporary approval period'));
      await tester.pumpAndSettle();
      await save(tester);
      expect((service.saves.single['policy'] as Map)['emergency'], null);
    },
  );
  testWidgets('loading, permission error and retry are explicit', (
    tester,
  ) async {
    final service = _Policy()
      ..error = FirebaseFunctionsException(
        code: 'permission-denied',
        message: 'denied',
      );
    addTearDown(service.updates.close);
    await _mount(tester, service);
    await tester.pumpAndSettle();
    expect(find.textContaining('Community access denied'), findsOneWidget);
    expect(find.text('Save visitor settings'), findsNothing);
    service.error = null;
    await tester.tap(find.text('Reload'));
    await tester.pumpAndSettle();
    expect(find.text('Save visitor settings'), findsOneWidget);
  });
  testWidgets(
    'other-platform changes refresh untouched settings and flag edited drafts',
    (tester) async {
      final service = _Policy();
      addTearDown(service.updates.close);
      await _mount(tester, service);
      (service.value['policy'] as Map)['revision'] = 5;
      service.value['writeRevision'] = 5;
      (service.value['policy'] as Map)['approvalMode'] =
          'all_approval_required';
      service.updates.add(5);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('Approval mode:all_approval_required')),
        findsOneWidget,
      );
      await choose(
        tester,
        'Approval mode:all_approval_required',
        'No Admin approval required',
      );
      (service.value['policy'] as Map)['revision'] = 6;
      service.value['writeRevision'] = 6;
      service.updates.add(6);
      await tester.pumpAndSettle();
      expect(
        find.text('Policy changed on another device. Reload before saving.'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Save visitor settings'),
            )
            .onPressed,
        isNull,
      );
    },
  );
  testWidgets(
    'backend revision conflict prevents repeated saves and optimistic success',
    (tester) async {
      final service = _Policy();
      addTearDown(service.updates.close);
      await _mount(tester, service);
      service.error = FirebaseFunctionsException(
        code: 'aborted',
        message: 'stale',
      );
      await save(tester);
      expect(find.textContaining('This record changed'), findsOneWidget);
      expect(find.textContaining('saved and reloaded'), findsNothing);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Save visitor settings'),
            )
            .onPressed,
        isNull,
      );
    },
  );

  test(
    'service uses canonical zone and pending write revision when replacing a schedule',
    () async {
      final response = copy(fixture()['loaded'] as Map);
      final effectiveAt = VisitorSchedule.instant(
        '2026-11-10T09:00',
        'Asia/Manila',
      );
      response['writeRevision'] = 8;
      response['pendingSchedule'] = {
        'policy': {...copy(response['policy'] as Map), 'enabled': true},
        'revision': 8,
        'effectiveAt': effectiveAt,
      };
      final calls = <Map<String, dynamic>>[];
      final service = VisitorPolicyService(
        community: () => 'community-1',
        callable: (name, payload) async {
          calls.add({'name': name, 'payload': payload});
          return name == 'getCommunityVisitorPolicy' ? response : {};
        },
      );
      final config = await service.load();
      expect(config.revision, 4);
      expect(config.writeRevision, 8);
      expect(config.pendingSchedule!.effectiveAt, effectiveAt);
      await service.save(
        {...config.pendingSchedule!.policy, 'timeZone': 'Europe/London'},
        config.writeRevision,
        effectiveAt: effectiveAt + 60_000,
      );
      final sent = calls[1]['payload'] as Map;
      expect(sent['expectedRevision'], 8);
      expect(sent['effectiveAt'], effectiveAt + 60_000);
      expect((sent['policy'] as Map)['timeZone'], 'Asia/Manila');
      expect((sent['policy'] as Map)['enabled'], true);
    },
  );

  test(
    'service blocks saves before rollout readiness and rejects elapsed schedules',
    () async {
      final response = copy(fixture()['loaded'] as Map)
        ..['rolloutReady'] = false;
      var writes = 0;
      final service = VisitorPolicyService(
        community: () => 'community-1',
        callable: (name, _) async {
          if (name == 'updateCommunityVisitorPolicy') writes++;
          return response;
        },
      );
      var config = await service.load();
      await expectLater(
        service.save(config.policy, config.writeRevision),
        throwsStateError,
      );
      response['rolloutReady'] = true;
      config = await service.load();
      for (final instant in [config.serverTime - 1, config.serverTime]) {
        await expectLater(
          service.save(
            config.policy,
            config.writeRevision,
            effectiveAt: instant,
          ),
          throwsFormatException,
        );
      }
      expect(writes, 0);
    },
  );

  test(
    'watch includes scheduled revisions and readiness changes at the same revision',
    () async {
      final db = FakeFirebaseFirestore();
      final ref = db.collection('communities').doc('community-1');
      await ref.set({
        'visitorPolicy': {'revision': 4},
        'scheduledVisitorPolicy': {'revision': 7},
        'visitorPolicyRolloutReady': false,
      });
      final service = VisitorPolicyService(
        community: () => 'community-1',
        firestore: db,
      );
      final iterator = StreamIterator(service.watch());
      addTearDown(iterator.cancel);
      expect(await iterator.moveNext(), true);
      expect(iterator.current, 7);
      await ref.update({
        'scheduledVisitorPolicy': {'revision': 8},
      });
      expect(await iterator.moveNext(), true);
      expect(iterator.current, 8);
      await ref.update({'visitorPolicyRolloutReady': true});
      expect(await iterator.moveNext(), true);
      expect(iterator.current, 8);
    },
  );

  test(
    'scope changes during load and save never reload a foreign community',
    () async {
      var community = 'community-1';
      final pending = Completer<Map<String, dynamic>>();
      final loading = VisitorPolicyService(
        community: () => community,
        callable: (_, _) => pending.future,
      );
      final load = loading.load();
      community = 'foreign';
      pending.complete(copy(fixture()['loaded'] as Map));
      await expectLater(load, throwsStateError);
      community = 'community-1';
      final calls = <String>[];
      final service = VisitorPolicyService(
        community: () => community,
        callable: (name, _) async {
          calls.add(name);
          if (name == 'updateCommunityVisitorPolicy') community = 'foreign';
          return copy(fixture()['loaded'] as Map);
        },
      );
      final config = await service.load();
      await expectLater(
        service.save(config.policy, config.writeRevision),
        throwsStateError,
      );
      expect(calls, [
        'getCommunityVisitorPolicy',
        'updateCommunityVisitorPolicy',
      ]);
    },
  );

  testWidgets('rollout readiness blocks Save while displaying current policy', (
    tester,
  ) async {
    final service = _Policy();
    service.value['rolloutReady'] = false;
    addTearDown(service.updates.close);
    await _mount(tester, service);
    await tester.pumpAndSettle();
    expect(
      find.textContaining(
        'Enabling is blocked until visitor policy rollout is ready',
      ),
      findsOneWidget,
    );
    expect(find.text('Current Effective Policy'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Save visitor settings'),
          )
          .onPressed,
      isNull,
    );
    service.value['rolloutReady'] = true;
    service.updates.add(4);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Save visitor settings'),
          )
          .onPressed,
      isNotNull,
    );
  });

  for (final zone in [null, 'Invalid/Zone']) {
    testWidgets(
      'missing or unsupported canonical time zone blocks Save ($zone)',
      (tester) async {
        final service = _Policy();
        service.value['timeZone'] = zone;
        addTearDown(service.updates.close);
        await _mount(tester, service);
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Save visitor settings'),
              )
              .onPressed,
          isNull,
        );
        expect(service.saves, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'scheduled Save uses community-local instant and displays both policies',
    (tester) async {
      final service = _Policy();
      addTearDown(service.updates.close);
      await _mount(tester, service);
      await choose(tester, 'Apply policy:immediate', 'At a scheduled time');
      await tester.enterText(
        find.widgetWithText(TextField, 'Policy effective time'),
        '2026-11-10T09:00',
      );
      await save(tester);
      expect(
        service.saves.single['effectiveAt'],
        DateTime.utc(2026, 11, 10, 1).millisecondsSinceEpoch,
      );
      expect((service.saves.single['policy'] as Map)['enabled'], true);
      expect(find.text('Current Effective Policy'), findsOneWidget);
      expect(find.text('Scheduled Policy'), findsOneWidget);
      expect(find.text('2026-11-10 09:00 (Asia/Manila)'), findsOneWidget);
      expect(find.textContaining('Enforcement scheduled for'), findsOneWidget);
      expect(
        find.textContaining('Existing authorized passes remain valid'),
        findsNothing,
      );
    },
  );

  for (final local in ['2026-11-09T08:00', 'invalid']) {
    testWidgets('invalid or past policy schedule prevents Save: $local', (
      tester,
    ) async {
      final service = _Policy();
      addTearDown(service.updates.close);
      await _mount(tester, service);
      await choose(tester, 'Apply policy:immediate', 'At a scheduled time');
      await tester.enterText(
        find.widgetWithText(TextField, 'Policy effective time'),
        local,
      );
      await save(tester);
      expect(service.saves, isEmpty);
      expect(
        find.byKey(const ValueKey('visitor-policy-feedback')),
        findsOneWidget,
      );
    });
  }

  for (final local in ['2026-03-08T02:30', '2026-11-01T01:30']) {
    testWidgets(
      'DST skipped or repeated policy schedule prevents Save: $local',
      (tester) async {
        final service = _Policy();
        service.value['timeZone'] = 'America/New_York';
        service.value['serverTime'] = DateTime.utc(
          2026,
          1,
          1,
        ).millisecondsSinceEpoch;
        addTearDown(service.updates.close);
        await _mount(tester, service);
        await choose(tester, 'Apply policy:immediate', 'At a scheduled time');
        await tester.enterText(
          find.widgetWithText(TextField, 'Policy effective time'),
          local,
        );
        await save(tester);
        expect(service.saves, isEmpty);
        expect(
          find.textContaining('skipped or repeated by daylight saving'),
          findsOneWidget,
        );
      },
    );
  }

  testWidgets(
    'pending schedule replacement uses write revision and immediate Save clears it',
    (tester) async {
      final service = _Policy();
      final time =
          VisitorSchedule.instant('2026-11-10T09:00', 'Asia/Manila') + 37_234;
      service.value['writeRevision'] = 7;
      service.value['pendingSchedule'] = {
        'revision': 7,
        'effectiveAt': time,
        'policy': {
          ...copy(service.value['policy'] as Map),
          'enabled': true,
          'approvalMode': 'all_approval_required',
        },
      };
      addTearDown(service.updates.close);
      await _mount(tester, service);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('Approval mode:all_approval_required')),
        findsOneWidget,
      );
      await save(tester);
      expect(service.saves.single['expectedRevision'], 7);
      expect(service.saves.single['effectiveAt'], time);
      await choose(tester, 'Apply policy:scheduled', 'Immediately');
      await save(tester);
      expect(service.saves.last['expectedRevision'], 8);
      expect(service.saves.last.containsKey('effectiveAt'), false);
      expect(find.text('Scheduled Policy'), findsNothing);
      expect(find.textContaining('Enforcement is active.'), findsOneWidget);
    },
  );

  testWidgets('a pending-only remote revision conflicts with an edited draft', (
    tester,
  ) async {
    final service = _Policy();
    addTearDown(service.updates.close);
    await _mount(tester, service);
    await choose(
      tester,
      'Approval mode:tenant_approval_required',
      'No Admin approval required',
    );
    service.value['writeRevision'] = 5;
    service.value['pendingSchedule'] = {
      'revision': 5,
      'effectiveAt': service.value['serverTime'] + 3600000,
      'policy': copy(service.value['policy'] as Map),
    };
    service.updates.add(5);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('Approval mode:resident_authorized')),
      findsOneWidget,
    );
    expect(
      find.text('Policy changed on another device. Reload before saving.'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Save visitor settings'),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('scheduled activation refreshes without a Firestore write', (
    tester,
  ) async {
    final service = _Policy();
    final current = service.value['serverTime'] as int;
    final next = {
      ...copy(service.value['policy'] as Map),
      'enabled': true,
      'approvalMode': 'all_approval_required',
      'revision': 5,
    };
    service.value['writeRevision'] = 5;
    service.value['pendingSchedule'] = {
      'revision': 5,
      'effectiveAt': current + 60_000,
      'policy': next,
    };
    addTearDown(service.updates.close);
    await _mount(tester, service);
    await tester.pumpAndSettle();
    expect(find.text('Scheduled Policy'), findsOneWidget);
    service.value['serverTime'] = current + 60_000;
    service.value['pendingSchedule'] = null;
    service.value['policy'] = next;
    await tester.pump(const Duration(seconds: 61));
    await tester.pumpAndSettle();
    expect(find.text('Scheduled Policy'), findsNothing);
    expect(
      find.byKey(const ValueKey('Apply policy:immediate')),
      findsOneWidget,
    );
    expect(service.saves, isEmpty);
  });

  testWidgets(
    'a save completing after community switch cannot update the new policy view',
    (tester) async {
      final service = _Policy();
      final context = AdminTenantContext.instance;
      addTearDown(context.clear);
      addTearDown(service.updates.close);
      await _mount(tester, service);
      await tester.pumpAndSettle();
      final original = VisitorPolicyConfig.fromMap(copy(service.value));
      final pending = Completer<VisitorPolicyConfig>();
      service.saving = pending;
      await save(tester);
      service.value = copy(fixture()['loaded'] as Map)
        ..['communityId'] = 'foreign';
      (service.value['policy'] as Map)['approvalMode'] =
          'all_approval_required';
      service.saving = null;
      context.addAuthorizedCommunity('foreign');
      await tester.pumpAndSettle();
      pending.complete(original);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('Approval mode:all_approval_required')),
        findsOneWidget,
      );
      expect(find.textContaining('saved and reloaded'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  for (final width in [393.0, 600.0, 800.0]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets('current and scheduled policy fit $width at scale $scale', (
        tester,
      ) async {
        final service = _Policy();
        (service.value['policy'] as Map)['enabled'] = true;
        service.value['writeRevision'] = 5;
        service.value['pendingSchedule'] = {
          'revision': 5,
          'effectiveAt': VisitorSchedule.instant(
            '2026-11-10T09:00',
            'Asia/Manila',
          ),
          'policy': {
            ...copy(service.value['policy'] as Map),
            'approvalMode': 'all_approval_required',
          },
        };
        addTearDown(service.updates.close);
        await _mount(tester, service, width: width, scale: scale);
        await tester.pumpAndSettle();
        expect(find.text('Current Effective Policy'), findsOneWidget);
        expect(find.text('Scheduled Policy'), findsOneWidget);
        await tester.ensureVisible(find.text('Save visitor settings'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }
}
