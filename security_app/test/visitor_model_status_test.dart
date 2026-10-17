import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:security_app/models/visitor_model.dart';

void main() {
  test('inside status is preserved when Admin approval is false', () {
    final visitor = VisitorModel.fromFirestore('visitor-1', {
      'visitorName': 'Guest',
      'status': 'inside',
      'isApproved': false,
      'actualArrival': Timestamp.fromDate(DateTime(2026, 10, 11)),
    });

    expect(visitor.status, 'inside');
    expect(visitor.isApproved, isFalse);
    expect(visitor.actualArrival, isNotNull);
  });

  test('legacy arrival timestamp derives inside independent of approval', () {
    final visitor = VisitorModel.fromFirestore('visitor-1', {
      'visitorName': 'Guest',
      'isApproved': false,
      'actualArrival': Timestamp.fromDate(DateTime(2026, 10, 11)),
    });

    expect(visitor.status, 'inside');
  });

  test('stored terminal and denial states are not replaced by approval', () {
    final denied = VisitorModel.fromFirestore('visitor-1', {
      'status': 'expected',
      'isApproved': false,
      'gateAccessStatus': 'denied',
    });
    final checkedOut = VisitorModel.fromFirestore('visitor-2', {
      'status': 'completed',
      'isApproved': false,
    });

    expect(denied.status, 'expected');
    expect(denied.gateAccessStatus, 'denied');
    expect(checkedOut.status, 'completed');
  });
}
