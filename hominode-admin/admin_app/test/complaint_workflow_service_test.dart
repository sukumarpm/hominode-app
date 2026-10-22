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
        assignedTo: 'Night supervisor · 555-0100',
        progressNote: 'Guard checked the gate and ordered a replacement part.',
        resolutionNote: null,
      );
      var data = (await firestore.collection('complaints').doc('c-1').get())
          .data()!;
      expect(data['status'], 'inprogress');
      expect(data['assignedTeam'], 'security');
      expect(data['assignedTo'], 'Night supervisor · 555-0100');
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
        assignedTeam: null,
        assignedTo: null,
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
}
