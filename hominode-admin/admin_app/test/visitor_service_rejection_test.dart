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
}
