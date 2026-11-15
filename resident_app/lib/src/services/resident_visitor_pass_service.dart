import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import 'visitor_qr_contract.dart';
import '../models/resident_visitor_authorization.dart';
import '../models/resident_visitor_timing.dart';
import 'resident_visitor_policy_service.dart';

/// Credentials remain in memory for this host's pass view, never in public data.
class ResidentVisitorPass {
  const ResidentVisitorPass({
    required this.visitor,
    required this.qrToken,
    required this.manualCode,
    required this.timing,
  });
  final Map<String, dynamic> visitor;
  final String qrToken;
  final String manualCode;
  final ResidentVisitorTiming timing;
  String get qrPayload =>
      jsonEncode({'type': 'hominode_visitor', 'version': 1, 'token': qrToken});
}

class ResidentVisitorPassService {
  ResidentVisitorPassService({
    Future<Map<String, dynamic>?> Function(String)? loadVisitor,
    Future<Map<String, dynamic>> Function(String)? loadCredentials,
  }) : _loadVisitor = loadVisitor ?? _firebaseVisitor,
       _loadCredentials = loadCredentials ?? _firebaseCredentials;

  final Future<Map<String, dynamic>?> Function(String) _loadVisitor;
  final Future<Map<String, dynamic>> Function(String) _loadCredentials;

  static Future<Map<String, dynamic>?> _firebaseVisitor(String id) async =>
      (await FirebaseFirestore.instance
              .collection('visitors')
              .doc(id)
              .get(const GetOptions(source: Source.server)))
          .data();

  static Future<Map<String, dynamic>> _firebaseCredentials(String id) async =>
      (await FirebaseFunctions.instanceFor(region: 'asia-southeast1')
              .httpsCallable('getVisitorCredentials')
              .call<Map<String, dynamic>>({'visitorId': id}))
          .data;

  Stream<Map<String, dynamic>?> watchVisitor(String id) => FirebaseFirestore
      .instance
      .collection('visitors')
      .doc(id)
      .snapshots()
      .map((doc) => doc.data());
  Stream<Object?> watchCommunity(String id) =>
      ResidentVisitorPolicyService().watchCommunity(id);

  Future<ResidentVisitorPass> load(String visitorId) async {
    final visitor = await _loadVisitor(visitorId);
    if (visitor == null || !VisitorQrContract.canRequest(visitor)) {
      throw StateError(
        visitor == null
            ? 'This visitor pass is unavailable.'
            : ResidentVisitorAuthorization.passMessage(visitor),
      );
    }
    final elapsed = Stopwatch()..start();
    Map<String, dynamic> credentials;
    try {
      credentials = await _loadCredentials(visitorId);
    } on FirebaseFunctionsException catch (error) {
      final details = error.details;
      if (details is Map &&
          details.containsKey('serverTime') &&
          details.containsKey('revalidateAt')) {
        throw ResidentVisitorPassUnavailable(
          residentVisitorError(error),
          ResidentVisitorTiming.fromMap(details, elapsed: elapsed),
          code: error.code,
        );
      }
      rethrow;
    }
    final token = credentials['qrToken'];
    final code = credentials['visitorPassCode'];
    final normalized = code is String
        ? code.toUpperCase().replaceAll(RegExp('[^A-Z0-9]'), '')
        : '';
    if (credentials['legacy'] == true ||
        token is! String ||
        !RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(token) ||
        code is! String ||
        !RegExp(r'^[A-Z0-9]{8,32}$').hasMatch(normalized)) {
      throw StateError('This visitor pass must be replaced.');
    }
    final timing = ResidentVisitorTiming.fromMap(credentials, elapsed: elapsed);
    final current = await _loadVisitor(visitorId);
    if (current == null ||
        !VisitorQrContract.canRequest(current) ||
        current['authorizationRevision'] != visitor['authorizationRevision'] ||
        ResidentVisitorAuthorization.arrival(current) !=
            ResidentVisitorAuthorization.arrival(visitor)) {
      throw StateError(
        'This invitation changed. Reload to check its current authorization and pass.',
      );
    }
    if (timing.remaining == Duration.zero) {
      throw ResidentVisitorPassUnavailable(
        'Policy availability is being rechecked.',
        timing,
      );
    }
    return ResidentVisitorPass(
      visitor: Map<String, dynamic>.from(current)
        ..remove('qrToken')
        ..remove('visitorPassCode'),
      qrToken: token,
      manualCode: code,
      timing: timing,
    );
  }
}
