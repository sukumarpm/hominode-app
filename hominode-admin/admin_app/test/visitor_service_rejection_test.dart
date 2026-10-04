import 'package:admin_app/services/visitor_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reject update writes canonical rejected visitor state', () {
    final update = rejectedVisitorUpdate(adminId: 'admin-123');

    expect(update['status'], 'rejected');
    expect(update['isApproved'], isFalse);
    expect(update['rejectedBy'], 'admin-123');
    expect(update['rejectedAt'], isA<FieldValue>());
    expect(update['updatedAt'], isA<FieldValue>());
  });

  test('pending queue keeps expected requests and excludes rejected ones', () {
    expect(
      visitorBelongsInPendingQueue({
        'status': 'expected',
        'isApproved': false,
        'actualArrival': null,
        'departure': null,
      }),
      isTrue,
    );

    expect(
      visitorBelongsInPendingQueue({
        'status': 'rejected',
        'isApproved': false,
        'actualArrival': null,
        'departure': null,
      }),
      isFalse,
    );
  });

  test(
    'pending queue accepts pending and excludes terminal or arrived states',
    () {
      expect(
        visitorBelongsInPendingQueue({
          'status': 'pending',
          'isApproved': false,
          'actualArrival': null,
          'departure': null,
        }),
        isTrue,
      );

      for (final status in [
        'rejected',
        'cancelled',
        'canceled',
        'arrived',
        'inside',
        'departed',
        'completed',
      ]) {
        expect(
          visitorBelongsInPendingQueue({
            'status': status,
            'isApproved': false,
            'actualArrival': null,
            'departure': null,
          }),
          isFalse,
          reason: '$status must not reappear in Pending',
        );
      }
    },
  );

  test('canonical visitor status respects stored rejected status', () {
    expect(
      canonicalVisitorStatus({'status': 'rejected', 'isApproved': false}),
      'rejected',
    );
  });

  test('canonical visitor status preserves approve and exit lifecycle', () {
    expect(
      canonicalVisitorStatus({
        'status': 'expected',
        'isApproved': true,
        'actualArrival': Timestamp.fromDate(DateTime(2026, 9, 1, 10)),
      }),
      'inside',
    );

    expect(
      canonicalVisitorStatus({'status': 'approved', 'isApproved': true}),
      'approved',
    );

    expect(
      canonicalVisitorStatus({
        'status': 'approved',
        'isApproved': true,
        'departure': Timestamp.fromDate(DateTime(2026, 9, 1, 12)),
      }),
      'departed',
    );
  });

  test('visitor model uses canonical rejected status from firestore data', () {
    final visitor = VisitorModel.fromFirestore('visitor-doc-1', {
      'visitorName': 'Queen',
      'phone': '9999999999',
      'residentId': 'resident-1',
      'residentName': 'Resident',
      'flatId': 'F-101',
      'flatLabel': 'F-101',
      'purpose': 'Delivery',
      'status': 'rejected',
      'isApproved': false,
      'rejectedAt': Timestamp.fromDate(DateTime(2026, 9, 1, 10)),
    });

    expect(visitor.id, 'visitor-doc-1');
    expect(visitor.status, 'rejected');
  });

  test('active queue includes only an approved visitor currently inside', () {
    expect(
      visitorBelongsInActiveQueue({
        'status': 'inside',
        'isApproved': true,
        'actualArrival': Timestamp.fromDate(DateTime(2026, 10, 2, 10)),
        'departure': null,
      }),
      isTrue,
    );
  });

  test('completed visitor with departure is excluded from active queue', () {
    final data = {
      'status': 'completed',
      'isApproved': true,
      'actualArrival': Timestamp.fromDate(DateTime(2026, 9, 16, 11, 59)),
      'departure': Timestamp.fromDate(DateTime(2026, 10, 2, 12, 48)),
    };

    expect(canonicalVisitorStatus(data), 'departed');
    expect(visitorBelongsInActiveQueue(data), isFalse);
    expect(visitorBelongsInHistoryQueue(data), isTrue);
  });

  test('terminal status cannot reappear active if departure is missing', () {
    final data = {
      'status': 'completed',
      'isApproved': true,
      'actualArrival': Timestamp.fromDate(DateTime(2026, 10, 2, 10)),
      'departure': null,
    };

    expect(canonicalVisitorStatus(data), 'departed');
    expect(visitorBelongsInActiveQueue(data), isFalse);
    expect(visitorBelongsInHistoryQueue(data), isFalse);
  });

  test('visitor terminal status variants normalize consistently', () {
    expect(canonicalVisitorStatus({'status': 'completed'}), 'departed');
    expect(canonicalVisitorStatus({'status': 'departed'}), 'departed');
    expect(canonicalVisitorStatus({'status': 'checked_out'}), 'departed');
    expect(canonicalVisitorStatus({'status': 'checked-out'}), 'departed');
    expect(canonicalVisitorStatus({'status': 'exited'}), 'departed');
    expect(canonicalVisitorStatus({'status': 'canceled'}), 'cancelled');
  });
}
