import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../session/web_session.dart';

class ResidentVisitor {
  const ResidentVisitor({
    required this.id,
    required this.name,
    required this.purpose,
    required this.status,
    required this.isApproved,
    this.expectedArrival,
    this.actualArrival,
    this.departure,
    this.phoneNumber,
    this.vehicleNumber,
    this.visitorPassCode,
  });

  final String id;
  final String name;
  final String purpose;
  final String status;
  final bool isApproved;
  final DateTime? expectedArrival;
  final DateTime? actualArrival;
  final DateTime? departure;
  final String? phoneNumber;
  final String? vehicleNumber;
  final String? visitorPassCode;
}

class ResidentVisitorException implements Exception {
  const ResidentVisitorException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ResidentVisitorService {
  ResidentVisitorService({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  static const String visitorsCollection = 'visitors';
  static const String _passAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  final FirebaseFirestore _db;
  final Random _secureRandom = Random.secure();

  Stream<List<ResidentVisitor>> watchMyVisitors(WebSession session) async* {
    final profile = await _loadValidatedProfile(session);
    yield* _db
        .collection(visitorsCollection)
        .where('communityId', isEqualTo: profile.communityId)
        .where('hostUserId', isEqualTo: session.uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          final visitors = snapshot.docs
              .where((doc) {
                final data = doc.data();
                return data['communityId'] == profile.communityId &&
                    data['hostUserId'] == session.uid;
              })
              .map(_visitorFromDocument)
              .toList(growable: false);
          return visitors;
        });
  }

  Future<void> addExpectedVisitor({
    required WebSession session,
    required String visitorName,
    required String purpose,
    required DateTime expectedArrival,
    String? phoneNumber,
    String? vehicleNumber,
  }) async {
    final name = visitorName.trim();
    final visitPurpose = purpose.trim();
    if (name.isEmpty || visitPurpose.isEmpty) {
      throw const ResidentVisitorException(
        'Visitor name and purpose are required.',
      );
    }

    final profile = await _loadValidatedProfile(session);
    final now = DateTime.now();
    if (expectedArrival.isBefore(DateTime(now.year, now.month, now.day))) {
      throw const ResidentVisitorException(
        'Expected arrival cannot be in the past.',
      );
    }

    await _db.collection(visitorsCollection).add({
      'hostUserId': session.uid,
      'hostName': profile.name,
      'hostEmail': profile.email,
      'flatId': profile.flatId,
      'flatLabel': profile.flatLabel,
      'adminId': profile.adminId,
      'communityId': profile.communityId,
      'visitorName': name,
      'purpose': visitPurpose,
      'expectedArrival': Timestamp.fromDate(expectedArrival),
      'phoneNumber': _nullableTrim(phoneNumber),
      'vehicleNumber': _nullableTrim(vehicleNumber),
      'visitorPassCode': _generateVisitorPassCode(),
      'qrToken': _generateQrToken(),
      'status': 'expected',
      'isApproved': false,
      'approvedBy': null,
      'approvedAt': null,
      'actualArrival': null,
      'departure': null,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<_ResidentVisitorProfile> _loadValidatedProfile(
    WebSession session,
  ) async {
    final communityId = session.activeTenant?.communityId.trim() ?? '';
    final sessionFlatId = session.flatId?.trim() ?? '';
    if (session.role != WebRole.resident ||
        communityId.isEmpty ||
        sessionFlatId.isEmpty) {
      throw const ResidentVisitorException(
        'An authenticated resident with a unit assignment is required.',
      );
    }

    final document = await _db.collection('users').doc(session.uid).get();
    final data = document.data();
    if (!document.exists || data == null) {
      throw const ResidentVisitorException('Resident profile not found.');
    }
    if (data['role'] != 'resident' ||
        data['isActive'] != true ||
        data['approvalStatus'] != 'approved') {
      throw const ResidentVisitorException(
        'Your resident profile is not active and approved.',
      );
    }

    final profileCommunityId = data['communityId']?.toString().trim() ?? '';
    final profileFlatId = data['flatId']?.toString().trim() ?? '';
    if (profileCommunityId != communityId || profileFlatId != sessionFlatId) {
      throw const ResidentVisitorException(
        'Your resident community or unit assignment has changed. Sign in again.',
      );
    }

    return _ResidentVisitorProfile(
      communityId: profileCommunityId,
      flatId: profileFlatId,
      flatLabel:
          _firstString(data, const ['flatLabel', 'flatNumber']) ??
          session.flatLabel ??
          profileFlatId,
      name:
          _firstString(data, const ['name', 'fullName']) ??
          session.displayName ??
          'Resident',
      email: _firstString(data, const ['email']) ?? '',
      adminId: data['adminId'],
    );
  }

  ResidentVisitor _visitorFromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    return ResidentVisitor(
      id: document.id,
      name: _firstString(data, const ['visitorName']) ?? 'Visitor',
      purpose: _firstString(data, const ['purpose']) ?? 'Visit',
      status: data['status']?.toString().trim().toLowerCase() ?? 'expected',
      isApproved: data['isApproved'] == true,
      expectedArrival: _timestampDate(data['expectedArrival']),
      actualArrival: _timestampDate(data['actualArrival']),
      departure: _timestampDate(data['departure']),
      phoneNumber: _firstString(data, const ['phoneNumber']),
      vehicleNumber: _firstString(data, const ['vehicleNumber']),
      visitorPassCode: _firstString(data, const ['visitorPassCode']),
    );
  }

  String _generateVisitorPassCode() {
    final raw = List.generate(
      8,
      (_) => _passAlphabet[_secureRandom.nextInt(_passAlphabet.length)],
    ).join();
    return '${raw.substring(0, 4)}-${raw.substring(4)}';
  }

  String _generateQrToken() {
    final bytes = List<int>.generate(24, (_) => _secureRandom.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }
}

class _ResidentVisitorProfile {
  const _ResidentVisitorProfile({
    required this.communityId,
    required this.flatId,
    required this.flatLabel,
    required this.name,
    required this.email,
    required this.adminId,
  });

  final String communityId;
  final String flatId;
  final String flatLabel;
  final String name;
  final String email;
  final Object? adminId;
}

String? _firstString(Map<String, dynamic> data, List<String> keys) {
  for (final key in keys) {
    final value = data[key]?.toString().trim();
    if (value != null && value.isNotEmpty) return value;
  }
  return null;
}

String? _nullableTrim(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

DateTime? _timestampDate(Object? value) => switch (value) {
  Timestamp timestamp => timestamp.toDate(),
  DateTime date => date,
  String text => DateTime.tryParse(text),
  _ => null,
};
