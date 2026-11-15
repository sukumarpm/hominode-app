import 'dart:async';

import 'package:admin_app/models/admin_profile.dart';
import 'package:admin_app/services/admin_tenant_context.dart';
import 'package:admin_app/services/assisted_deletion_service.dart';
import 'package:admin_app/widgets/assisted_deletion_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _resident = AssistedDeletionResident(
  uid: 'resident-one',
  communityId: 'community-a',
  name: 'Mira Example',
  building: 'Tower One',
  unit: 'A101',
);

class _AssistedGateway implements AssistedDeletionGateway {
  int createCalls = 0;
  int verifyCalls = 0;
  Map<String, dynamic>? intakePayload;
  String? receivedDigest;
  Completer<Map<String, dynamic>>? pendingCreate;
  bool failCreate = false;

  @override
  Future<List<AssistedDeletionResident>> residents(String communityId) async =>
      [_resident, const AssistedDeletionResident(uid: 'other', communityId: 'other-community', name: 'Other Community', building: 'Other', unit: 'B100')];

  @override
  Future<Map<String, dynamic>> createIntake(Map<String, dynamic> data) async {
    createCalls++;
    intakePayload = data;
    if (failCreate) throw StateError('Simulated network failure');
    if (pendingCreate != null) return pendingCreate!.future;
    return {'requestId': 'assisted-001', 'sourceApp': 'admin_assisted', 'status': 'pending_assisted_verification', 'intakeDigest': 'a' * 64};
  }

  @override
  Future<Map<String, dynamic>> verify({required String communityId, required String requestId, required String intakeDigest}) async {
    verifyCalls++;
    receivedDigest = intakeDigest;
    return {'verificationStatus': 'verified', 'status': 'pending_review'};
  }
}

void _authorize() {
  AdminTenantContext.instance.initialize(const AdminProfile(
    uid: 'admin-a',
    phoneNumber: '+15550000001',
    role: 'admin',
    isActive: true,
    authorizedCommunityIds: ['community-a'],
  ));
}

Future<void> _mount(WidgetTester tester, _AssistedGateway gateway) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(body: Builder(builder: (context) => FilledButton(
      onPressed: () => showDialog<String>(
        context: context,
        builder: (_) => AssistedDeletionDialog(communityId: 'community-a', service: gateway),
      ),
      child: const Text('Open assisted deletion'),
    ))),
  ));
  await tester.tap(find.text('Open assisted deletion'));
  await tester.pumpAndSettle();
}

Future<void> _fillForm(WidgetTester tester) async {
  final selectResident = find.byType(DropdownButtonFormField<String>).first;
  await tester.ensureVisible(selectResident);
  await tester.tap(selectResident);
  await tester.pumpAndSettle();
  await tester.tap(find.textContaining('Mira Example').last);
  await tester.pumpAndSettle();

  final fields = find.byType(TextField);
  expect(fields, findsNWidgets(4));
  await tester.enterText(fields.at(1), 'CASE-001');

  final selectMethod = find.byType(DropdownButtonFormField<String>).last;
  await tester.ensureVisible(selectMethod);
  await tester.tap(selectMethod);
  await tester.pumpAndSettle();
  await tester.tap(find.text('In person with community records').last);
  await tester.pumpAndSettle();

  await tester.enterText(fields.at(2), 'EVIDENCE-001');
  await tester.enterText(fields.at(3), 'Resident identity and deletion consent checked in person.');
  await tester.ensureVisible(find.byType(CheckboxListTile));
  await tester.tap(find.byType(CheckboxListTile));
  await tester.pumpAndSettle();
}

void main() {
  tearDown(AdminTenantContext.instance.clear);

  testWidgets('intake requires confirmation and saves pending without automatic verification', (tester) async {
    _authorize();
    // A roomy viewport keeps the long dialog reachable, while ensureVisible
    // independently handles scrolling on mobile-sized viewports.
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final gateway = _AssistedGateway();
    await _mount(tester, gateway);
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Save pending intake')).onPressed, isNull);
    await _fillForm(tester);
    final save = find.widgetWithText(FilledButton, 'Save pending intake');
    expect(tester.widget<FilledButton>(save).onPressed, isNotNull);
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(gateway.createCalls, 1);
    expect(gateway.verifyCalls, 0);
    expect(gateway.intakePayload, containsPair('residentUid', 'resident-one'));
    expect(gateway.intakePayload, containsPair('communityId', 'community-a'));
    expect(gateway.intakePayload, containsPair('consentAttested', true));
    expect(gateway.intakePayload, containsPair('verificationEvidenceReference', 'EVIDENCE-001'));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('intake disables repeated submissions while backend request is in flight', (tester) async {
    _authorize();
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final gateway = _AssistedGateway()..pendingCreate = Completer<Map<String, dynamic>>();
    await _mount(tester, gateway);
    await _fillForm(tester);
    final save = find.widgetWithText(FilledButton, 'Save pending intake');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pump();
    expect(gateway.createCalls, 1);
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Saving…')).onPressed, isNull);
    gateway.pendingCreate!.complete({'requestId': 'assisted-001', 'sourceApp': 'admin_assisted', 'status': 'pending_assisted_verification', 'intakeDigest': 'a' * 64});
    await tester.pumpAndSettle();
    expect(gateway.createCalls, 1);
    expect(gateway.verifyCalls, 0);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  test('gateway sends the saved server digest unchanged with explicit confirmations', () async {
    _authorize();
    final sent = <String, dynamic>{};
    final service = AssistedDeletionService(call: (name, data) async {
      sent['name'] = name;
      sent['data'] = Map<String, dynamic>.from(data);
      return {'verificationStatus': 'verified', 'status': 'pending_review'};
    });
    final digest = 'b' * 64;
    await service.verify(communityId: 'community-a', requestId: 'assisted-002', intakeDigest: digest);
    expect(sent['name'], 'verifyAdminAssistedDeletionRequest');
    expect(sent['data'], {
      'requestId': 'assisted-002',
      'intakeDigest': digest,
      'identityConfirmed': true,
      'consentConfirmed': true,
    });
  });
}
