import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:resident_app/src/models/complaint.dart';

void main() {
  test('reads the status values written by existing complaint clients', () {
    expect(complaintStatusFromFirestore('pending'), ComplaintStatus.pending);
    expect(
      complaintStatusFromFirestore('inProgress'),
      ComplaintStatus.inProgress,
    );
    expect(
      complaintStatusFromFirestore('in-progress'),
      ComplaintStatus.inProgress,
    );
    expect(
      complaintStatusFromFirestore('inprogress'),
      ComplaintStatus.inProgress,
    );
    expect(complaintStatusFromFirestore('resolved'), ComplaintStatus.completed);
    expect(
      complaintStatusFromFirestore('completed'),
      ComplaintStatus.completed,
    );
  });

  test('explicit reopened status overrides a historic resolved timestamp', () {
    expect(
      complaintStatusFromFirestore(
        'inprogress',
        isResolved: true,
        hasResolvedAt: true,
      ),
      ComplaintStatus.inProgress,
    );
    expect(
      complaintStatusFromFirestore(null, hasResolvedAt: true),
      ComplaintStatus.completed,
    );
  });

  test('parses admin assignments and notes for the resident detail view', () {
    final complaint = Complaint.fromJson({
      'id': 'c-1',
      'title': 'Gate repair',
      'description': 'The gate is stuck.',
      'category': 'security',
      'status': 'inprogress',
      'createdDate': '2026-10-22T10:00:00.000',
      'assignedTeam': 'security',
      'assignedTo': 'Night supervisor',
      'progressNotes': [
        {'text': 'Replacement part ordered.'},
      ],
      'resolutionNotes': [
        {'text': 'Gate repaired and tested.'},
      ],
    });

    expect(complaint.assignedTeam, 'security');
    expect(complaint.assignedTo, 'Night supervisor');
    expect(complaint.progressNotes, ['Replacement part ordered.']);
    expect(complaint.resolutionNotes, ['Gate repaired and tested.']);
  });

  test(
    'resident list summary shows safe manual assignment and formats team',
    () {
      final complaint = complaintFromFirestoreData('c-list', {
        'title': 'Gate repair',
        'status': 'inprogress',
        'assignedTeam': 'maintenance',
        'assignedTo': 'Rahim',
      });

      expect(
        complaintResponsibilitySummary(complaint),
        'Responsible: Maintenance · Rahim',
      );
      expect(
        complaintResponsibilitySummary(
          complaintFromFirestoreData('c-linked', {
            'assignedStaffId': 'staff-1',
            'assignedTo': 'legacy@example.com',
          }),
          linkedStaffName: 'Linked Technician',
        ),
        'Responsible: Linked Technician',
      );
      expect(
        complaintResponsibilitySummary(
          complaintFromFirestoreData('c-private', {
            'assignedTo': 'Private vendor +1 555 123 4567',
          }),
        ),
        'Responsible: Unassigned',
      );
    },
  );

  test(
    'resident document stream reflects Admin workflow status writes',
    () async {
      final writes = StreamController<Map<String, dynamic>>();
      final statuses = StreamIterator(
        writes.stream.map(
          (data) => complaintFromFirestoreData('cross-client-1', data).status,
        ),
      );

      Future<ComplaintStatus> statusAfterWrite(
        Map<String, dynamic> data,
      ) async {
        final nextStatus = statuses.moveNext();
        writes.add(data);
        expect(await nextStatus, isTrue);
        return statuses.current;
      }

      expect(
        await statusAfterWrite({'status': 'pending'}),
        ComplaintStatus.pending,
      );
      expect(
        await statusAfterWrite({'status': 'inprogress'}),
        ComplaintStatus.inProgress,
      );
      expect(
        await statusAfterWrite({
          'status': 'completed',
          'resolvedAt': DateTime(2026, 10, 23),
        }),
        ComplaintStatus.completed,
      );
      expect(
        await statusAfterWrite({
          'status': 'inprogress',
          'resolvedAt': DateTime(2026, 10, 23),
        }),
        ComplaintStatus.inProgress,
      );
      await statuses.cancel();
      await writes.close();
    },
  );
}
