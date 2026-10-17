// Read-only Firestore/Auth doubles verify that visitor creation writes the QR
// credential without requiring Firebase emulator access.
// ignore_for_file: subtype_of_sealed_class

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resident_app/src/services/visitor_firestore_service.dart';
import 'package:resident_app/src/services/visitor_qr_contract.dart';

void main() {
  final now = DateTime.utc(2026, 10, 11, 8);

  Map<String, dynamic> visitor({
    String status = 'expected',
    bool isApproved = false,
    Object? qrToken = 'opaque-token-123',
    Object? actualArrival,
    Object? departure,
    Object? expectedArrival,
  }) => {
    'status': status,
    'isApproved': isApproved,
    'qrToken': qrToken,
    'expectedArrival': expectedArrival ?? Timestamp.fromDate(now),
    'actualArrival': actualArrival,
    'departure': departure,
  };

  group('VisitorQrContract', () {
    test('status label reflects physical state independently of approval', () {
      expect(VisitorQrContract.statusLabel(visitor()), 'Expected');
      expect(
        VisitorQrContract.statusLabel(
          visitor(status: 'approved', isApproved: true),
        ),
        'Expected',
      );
      expect(
        VisitorQrContract.statusLabel(visitor(status: 'rejected')),
        'Rejected by Admin',
      );
      expect(
        VisitorQrContract.statusLabel(
          visitor(status: 'inside', isApproved: true),
        ),
        'Checked In',
      );
      expect(
        VisitorQrContract.statusLabel(
          visitor(status: 'inside', isApproved: false),
        ),
        'Checked In',
      );
      expect(
        VisitorQrContract.statusLabel(
          visitor(status: 'completed', isApproved: true),
        ),
        'Checked Out',
      );
    });

    test('share text uses the persisted state without changing it', () {
      final pending = visitor();
      final text = VisitorQrContract.shareTextFor(
        pending,
        visitorId: 'visitor-1234567890',
      );

      expect(text, contains('Visitor Pass - Expected'));
      expect(text, isNot(contains('Awaiting Approval')));
      expect(text, isNot(contains('Visitor Pass - Approved')));
      expect(pending['status'], 'expected');
      expect(pending['isApproved'], isFalse);

      final approvedText = VisitorQrContract.shareTextFor(
        visitor(status: 'approved', isApproved: true),
        visitorId: 'visitor-1234567890',
      );
      expect(approvedText, contains('Visitor Pass - Expected'));
    });

    test('eligible pending and approved records reuse the persisted token', () {
      final pending = visitor();
      final first = VisitorQrContract.payloadFor(
        pending,
        visitorId: 'visitor-1',
        now: now,
      );
      final reopened = VisitorQrContract.payloadFor(
        pending,
        visitorId: 'visitor-1',
        now: now,
      );

      expect(first, reopened);
      expect(jsonDecode(first!), <String, dynamic>{
        'type': 'hominode_visitor',
        'version': 1,
        'token': 'opaque-token-123',
      });
      expect(
        VisitorQrContract.payloadFor(
          visitor(status: 'approved', isApproved: true),
          visitorId: 'visitor-1',
          now: now,
        ),
        first,
      );
    });

    test('rejects rejected, cancelled, completed, and checked-in records', () {
      final ineligible = <Map<String, dynamic>>[
        visitor(status: 'rejected'),
        visitor(status: 'cancelled'),
        visitor(status: 'completed', isApproved: true),
        visitor(status: 'inside', isApproved: true),
        visitor(actualArrival: Timestamp.fromDate(now)),
        visitor(departure: Timestamp.fromDate(now)),
      ];

      for (final record in ineligible) {
        expect(
          VisitorQrContract.payloadFor(
            record,
            visitorId: 'visitor-1',
            now: now,
          ),
          isNull,
        );
      }
    });

    test('enforces the Security gate visit window', () {
      expect(
        VisitorQrContract.canDisplay(
          visitor(
            expectedArrival: Timestamp.fromDate(
              now.add(const Duration(hours: 25)),
            ),
          ),
          now: now,
        ),
        isFalse,
      );
      expect(
        VisitorQrContract.canDisplay(
          visitor(
            expectedArrival: Timestamp.fromDate(
              now.subtract(const Duration(hours: 24)),
            ),
          ),
          now: now,
        ),
        isTrue,
      );
    });

    test('uses legacy document ID only when qrToken is absent', () {
      final missingTokenRecord = visitor();
      missingTokenRecord.remove('qrToken');
      final payload = VisitorQrContract.payloadFor(
        missingTokenRecord,
        visitorId: 'legacy-visitor',
        now: now,
      );

      expect(jsonDecode(payload!), {
        'visitorId': 'legacy-visitor',
        'legacy': true,
      });
      expect(
        VisitorQrContract.payloadFor(
          visitor(qrToken: ''),
          visitorId: 'visitor-1',
          now: now,
        ),
        isNull,
      );
      expect(
        VisitorQrContract.payloadFor(
          visitor(qrToken: 'bad token'),
          visitorId: 'visitor-1',
          now: now,
        ),
        isNull,
      );
    });

    test('diagnostic message does not include token or visitor details', () {
      final record = {
        ...visitor(),
        'visitorName': 'Sensitive Name',
        'phoneNumber': '+639171234567',
      };

      final diagnostic = VisitorQrContract.safeLoadDiagnostic(record);
      expect(diagnostic, contains('status=expected'));
      expect(diagnostic, isNot(contains('opaque-token-123')));
      expect(diagnostic, isNot(contains('Sensitive Name')));
      expect(diagnostic, isNot(contains('+639171234567')));
    });
  });

  test(
    'new invitation uses the server callable and sends no credentials or trusted scope',
    () async {
      final firestore = _VisitorFirestore({
        'uid-1': {
          'name': 'Resident',
          'email': 'resident@example.test',
          'flatId': 'N014',
          'flatLabel': 'N014',
          'communityId': 'green-wave',
        },
      });
      Map<String, dynamic>? request;
      final service = VisitorFirestoreService.withDependencies(
        firestore: firestore,
        auth: _VisitorAuth(_VisitorUser('uid-1')),
        createInvitation: (data) async {
          request = data;
          return {'visitorId': 'visitor-1'};
        },
      );

      final result = await service.addExpectedVisitor(
        visitorName: 'Akil',
        purpose: 'Visit',
        expectedDate: now,
        expectedTime: now,
      );

      expect(result.success, isTrue);
      expect(result.visitorId, 'visitor-1');
      expect(firestore.createdVisitor, isNull);
      expect(request, containsPair('visitorName', 'Akil'));
      expect(request, containsPair('purpose', 'Visit'));
      expect(request, isNot(contains('qrToken')));
      expect(request, isNot(contains('visitorPassCode')));
      expect(request, isNot(contains('communityId')));
      expect(request, isNot(contains('flatId')));
      final saved = visitor(qrToken: 'server-issued-persisted-token');
      expect(
        VisitorQrContract.payloadFor(
          saved,
          visitorId: result.visitorId!,
          now: now,
        ),
        isNotNull,
      );
    },
  );
}

class _VisitorFirestore implements FirebaseFirestore {
  _VisitorFirestore(this.users);
  final Map<String, Map<String, dynamic>> users;
  Map<String, dynamic>? createdVisitor;

  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      _VisitorCollection(this, path);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _VisitorCollection implements CollectionReference<Map<String, dynamic>> {
  _VisitorCollection(this.firestore, this.path);
  @override
  final _VisitorFirestore firestore;
  @override
  final String path;

  @override
  DocumentReference<Map<String, dynamic>> doc([String? id]) =>
      _VisitorDocument(path, id ?? '', firestore.users[id]);

  @override
  Future<DocumentReference<Map<String, dynamic>>> add(
    Map<String, dynamic> data,
  ) async {
    firestore.createdVisitor = Map<String, dynamic>.from(data);
    return _VisitorDocument(path, 'visitor-created', data);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _VisitorDocument implements DocumentReference<Map<String, dynamic>> {
  _VisitorDocument(this.collectionPath, this.id, this.value);
  final String collectionPath;
  @override
  final String id;
  final Map<String, dynamic>? value;

  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([
    GetOptions? options,
  ]) async => _VisitorSnapshot(id, value);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _VisitorSnapshot implements DocumentSnapshot<Map<String, dynamic>> {
  _VisitorSnapshot(this.id, this.value);
  @override
  final String id;
  final Map<String, dynamic>? value;

  @override
  bool get exists => value != null;

  @override
  Map<String, dynamic>? data() => value;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _VisitorAuth implements FirebaseAuth {
  _VisitorAuth(this.currentUser);
  @override
  final User? currentUser;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _VisitorUser implements User {
  _VisitorUser(this.uid);
  @override
  final String uid;
  @override
  String? get displayName => 'Resident';
  @override
  String? get email => 'resident@example.test';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
