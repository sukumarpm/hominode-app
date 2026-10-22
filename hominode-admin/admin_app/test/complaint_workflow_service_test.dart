import 'package:admin_app/models/complaint_models.dart';
import 'package:admin_app/services/complaint_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

Future<ComplaintService> _service(
  FakeFirebaseFirestore firestore, {
  ComplaintNotificationSender? notificationSender,
  String community = 'community-a',
}) async {
  return ComplaintService(
    firestore: firestore,
    adminIdProvider: () => 'admin-1',
    communityIdProvider: () => community,
    notificationSender: notificationSender,
  );
}

Map<String, dynamic> _record({String status = 'pending'}) => {
  'communityId': 'community-a',
  'userId': 'resident-1',
  'residentId': 'resident-1',
  'title': 'Broken gate',
  'status': status,
  'assignedTo': 'Security Desk',
};

void main() {
  test(
    'supports manual assignment, clearing, notes, and reopen transitions',
    () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('complaints').doc('c-1').set(_record());
      var notifications = 0;
      final service = await _service(
        firestore,
        notificationSender:
            ({
              required recipientId,
              required title,
              required message,
              required metadata,
            }) async {
              notifications++;
            },
      );

      await service.updateManualWorkflow(
        complaintId: 'c-1',
        status: ComplaintStatus.inProgress,
        assignedTeam: 'security',
        assignedTo: 'Night supervisor',
        progressNote: 'Guard checked the gate and ordered a replacement part.',
        resolutionNote: null,
      );
      var data = (await firestore.collection('complaints').doc('c-1').get())
          .data()!;
      expect(data['status'], 'inprogress');
      expect(data['assignedTeam'], 'security');
      expect(data['assignedTo'], 'Night supervisor');
      expect(
        (data['progressNotes'] as List).single['text'],
        contains('ordered'),
      );
      expect(notifications, 1);

      await service.updateManualWorkflow(
        complaintId: 'c-1',
        status: ComplaintStatus.resolved,
        assignedTeam: 'vendor',
        assignedTo: 'Gate repair vendor',
        progressNote: null,
        resolutionNote: 'Gate repaired and tested.',
      );
      data = (await firestore.collection('complaints').doc('c-1').get())
          .data()!;
      expect(data['status'], 'completed');
      expect(data['resolvedAt'], isNotNull);
      expect(
        (data['resolutionNotes'] as List).single['text'],
        contains('tested'),
      );

      await service.updateManualWorkflow(
        complaintId: 'c-1',
        status: ComplaintStatus.inProgress,
        assignedTeam: '',
        assignedTo: '',
        progressNote: 'Issue returned; reopening.',
        resolutionNote: null,
      );
      data = (await firestore.collection('complaints').doc('c-1').get())
          .data()!;
      expect(data['status'], 'inprogress');
      expect(data['resolvedAt'], isNotNull);
      expect(data['assignedTeam'], isNull);
      expect(data['assignedTo'], isNull);
      expect((data['progressNotes'] as List), hasLength(2));
    },
  );

  test(
    'team-only status transitions preserve an optional person assignment',
    () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('complaints').doc('c-1').set({
        ..._record(),
        'assignedTeam': 'Management',
        'assignedTo': null,
      });
      final service = await _service(firestore);

      await service.updateManualWorkflow(
        complaintId: 'c-1',
        status: ComplaintStatus.inProgress,
        assignedTeam: null,
        assignedTo: null,
        progressNote: null,
        resolutionNote: null,
      );
      await service.updateManualWorkflow(
        complaintId: 'c-1',
        status: ComplaintStatus.resolved,
        assignedTeam: null,
        assignedTo: null,
        progressNote: null,
        resolutionNote: null,
      );
      await service.updateManualWorkflow(
        complaintId: 'c-1',
        status: ComplaintStatus.inProgress,
        assignedTeam: null,
        assignedTo: null,
        progressNote: null,
        resolutionNote: null,
      );

      final record = (await firestore.collection('complaints').doc('c-1').get())
          .data()!;
      expect(record['status'], 'inprogress');
      expect(record['assignedTeam'], 'Management');
      expect(record['assignedTo'], isNull);
    },
  );

  test('team reassignment works without a person or vendor name', () async {
    final firestore = FakeFirebaseFirestore();
    await firestore.collection('complaints').doc('c-1').set({
      ..._record(),
      'assignedTeam': 'security',
      'assignedTo': null,
    });
    final service = await _service(firestore);
    await service.updateManualWorkflow(
      complaintId: 'c-1',
      status: ComplaintStatus.inProgress,
      assignedTeam: 'maintenance',
      assignedTo: null,
      progressNote: null,
      resolutionNote: null,
    );
    final record = (await firestore.collection('complaints').doc('c-1').get())
        .data()!;
    expect(record['assignedTeam'], 'maintenance');
    expect(record['assignedTo'], isNull);
  });

  test(
    'unchanged legacy private assignment is preserved on status update',
    () async {
      final firestore = FakeFirebaseFirestore();
      const legacy = 'Old contractor · +1 555 123 4567';
      await firestore.collection('complaints').doc('c-1').set({
        ..._record(),
        'assignedTeam': 'security',
        'assignedTo': legacy,
      });
      final service = await _service(firestore);
      await service.updateManualWorkflow(
        complaintId: 'c-1',
        status: ComplaintStatus.inProgress,
        assignedTeam: 'security',
        assignedTo: legacy,
        progressNote: null,
        resolutionNote: null,
      );
      final record = (await firestore.collection('complaints').doc('c-1').get())
          .data()!;
      expect(record['status'], 'inprogress');
      expect(record['assignedTo'], legacy);
    },
  );

  test('rejects cross-community updates before writing', () async {
    final firestore = FakeFirebaseFirestore();
    await firestore.collection('complaints').doc('c-1').set(_record());
    final service = await _service(firestore, community: 'community-b');

    await expectLater(
      service.updateManualWorkflow(
        complaintId: 'c-1',
        status: ComplaintStatus.inProgress,
        assignedTeam: null,
        assignedTo: null,
        progressNote: null,
        resolutionNote: null,
      ),
      throwsStateError,
    );
    expect(
      (await firestore.collection('complaints').doc('c-1').get())
          .data()?['status'],
      'pending',
    );
  });

  test(
    'rejects private contact details in resident-readable assignee text',
    () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('complaints').doc('c-1').set(_record());
      final service = await _service(firestore);

      await expectLater(
        service.updateManualWorkflow(
          complaintId: 'c-1',
          status: ComplaintStatus.inProgress,
          assignedTeam: 'security',
          assignedTo: 'Night supervisor · +1 555 123 4567',
          progressNote: null,
          resolutionNote: null,
        ),
        throwsArgumentError,
      );
      expect(
        (await firestore.collection('complaints').doc('c-1').get())
            .data()?['status'],
        'pending',
      );

      await expectLater(
        service.updateManualWorkflow(
          complaintId: 'c-1',
          status: ComplaintStatus.inProgress,
          assignedTeam: 'security',
          assignedTo: 'Night supervisor',
          progressNote: 'Email the vendor at vendor@example.com.',
          resolutionNote: null,
        ),
        throwsArgumentError,
      );
      expect(
        (await firestore.collection('complaints').doc('c-1').get())
            .data()?['status'],
        'pending',
      );
    },
  );

  test(
    'notification failure is reported after the complaint write succeeds',
    () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('complaints').doc('c-1').set(_record());
      final service = await _service(
        firestore,
        notificationSender:
            ({
              required recipientId,
              required title,
              required message,
              required metadata,
            }) async => throw StateError('notification unavailable'),
      );

      final result = await service.updateManualWorkflow(
        complaintId: 'c-1',
        status: ComplaintStatus.inProgress,
        assignedTeam: null,
        assignedTo: 'Security Desk',
        progressNote: null,
        resolutionNote: null,
      );
      expect(result.notificationSent, isFalse);
      expect(result.notificationError, contains('notification unavailable'));
      expect(
        (await firestore.collection('complaints').doc('c-1').get())
            .data()?['status'],
        'inprogress',
      );
    },
  );

  test(
    'failed Firestore write leaves persisted complaint status unchanged',
    () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('complaints').doc('c-1').set(_record());
      final service = ComplaintService(
        firestore: firestore,
        adminIdProvider: () => 'admin-1',
        communityIdProvider: () => 'community-a',
        transactionRunner: <T>(handler) async =>
            throw StateError('Firestore write failed'),
      );
      await expectLater(
        service.updateManualWorkflow(
          complaintId: 'c-1',
          status: ComplaintStatus.inProgress,
          assignedTeam: null,
          assignedTo: null,
          progressNote: null,
          resolutionNote: null,
        ),
        throwsA(isA<StateError>()),
      );
      expect(
        (await firestore.collection('complaints').doc('c-1').get())
            .data()?['status'],
        'pending',
      );
    },
  );
}
