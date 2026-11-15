import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:security_app/models/visitor_model.dart';

void main() {
  for (final declaration in [true, false, null, 'true']) {
    test('preserves only explicit boolean pet declarations ($declaration)', () {
      final data = <String, dynamic>{
        if (declaration != null) 'bringingPet': declaration,
      };
      final expected = declaration is bool ? declaration : null;
      for (final visitor in [
        VisitorModel.fromSanitizedMap(data),
        VisitorModel.fromFirestore('visitor-1', data),
      ]) {
        expect(visitor.bringingPet, expected);
        expect(
          visitor.petDeclaration,
          expected == null
              ? 'Not recorded'
              : expected
              ? 'Yes'
              : 'No',
        );
        if (expected == null) {
          expect(visitor.toMap().containsKey('bringingPet'), isFalse);
        } else {
          expect(visitor.toMap()['bringingPet'], expected);
        }
      }
    });
  }

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
