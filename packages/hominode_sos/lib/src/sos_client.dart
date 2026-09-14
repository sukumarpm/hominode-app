import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

const activeSosStatuses = ['triggered', 'acknowledged', 'responding'];

class SosAlert {
  const SosAlert(this.id, this.data);
  final String id;
  final Map<String, dynamic> data;
  String get status => data['status'] as String? ?? 'unknown';
  String get communityId => data['communityId'] as String? ?? '';
  String get residentName => data['residentName'] as String? ?? 'Resident';
  String get unitDescription => [
    data['buildingName'],
    data['unitLabel'],
  ].whereType<String>().where((v) => v.isNotEmpty).join(' / ');
  String get statusLabel => switch (status) {
    'triggered' => 'Waiting for acknowledgement',
    'acknowledged' => 'Acknowledged',
    'responding' => 'Security responding',
    'resolved' => 'Resolved',
    'cancelled' => 'Cancelled',
    _ => 'Status unavailable',
  };
  DateTime? time(String field) {
    final value = data[field];
    return value is Timestamp
        ? value.toDate()
        : value is DateTime
        ? value
        : null;
  }

  bool get active => activeSosStatuses.contains(status);
}

class SosContext {
  const SosContext({
    required this.communityId,
    required this.residentUid,
    this.activeAlertId,
    this.securityPhone,
    this.emergencyPhone,
  });
  final String communityId;
  final String residentUid;
  final String? activeAlertId;
  final String? securityPhone;
  final String? emergencyPhone;
}

abstract class SosClient {
  Future<SosContext> context();
  Future<String> trigger(String requestId, Map<String, dynamic>? location);
  Future<void> transition(
    String communityId,
    String alertId,
    String action, {
    String? note,
  });
  Stream<SosAlert?> watchAlert(String communityId, String alertId);
  Stream<List<SosAlert>> watchAlerts(
    String communityId, {
    bool active = true,
    String? residentUid,
  });
}

class FirebaseSosClient implements SosClient {
  FirebaseSosClient({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _functions =
           functions ??
           FirebaseFunctions.instanceFor(region: 'asia-southeast1');
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  @override
  Future<SosContext> context() async {
    final result = await _functions.httpsCallable('getSosContext').call({});
    final data = Map<String, dynamic>.from(result.data as Map);
    final communityId = data['communityId'] as String?;
    final uid = data['residentUid'] as String?;
    if (communityId == null ||
        communityId.isEmpty ||
        uid == null ||
        uid.isEmpty) {
      throw StateError('Emergency community is unavailable.');
    }
    return SosContext(
      communityId: communityId,
      residentUid: uid,
      activeAlertId: data['activeAlertId'] as String?,
      securityPhone: data['securityPhone'] as String?,
      emergencyPhone: data['emergencyPhone'] as String?,
    );
  }

  @override
  Future<String> trigger(
    String requestId,
    Map<String, dynamic>? location,
  ) async {
    final response = await _functions.httpsCallable('triggerSos').call({
      'requestId': requestId,
      if (location != null) 'location': location,
    });
    return (response.data as Map)['alertId'] as String;
  }

  @override
  Future<void> transition(
    String communityId,
    String alertId,
    String action, {
    String? note,
  }) async {
    _requireCommunity(communityId);
    await _functions.httpsCallable('transitionSos').call({
      'communityId': communityId,
      'alertId': alertId,
      'action': action,
      if (note != null) 'resolutionNote': note,
    });
  }

  void _requireCommunity(String communityId) {
    if (communityId.trim().isEmpty)
      throw StateError('Select an authorized community.');
  }

  void _requireAlertId(String alertId) {
    final value = alertId.trim();

    if (value.isEmpty ||
        value.length > 128 ||
        !RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(value)) {
      throw StateError('Emergency reference is invalid.');
    }
  }

  @override
  Stream<SosAlert?> watchAlert(String communityId, String alertId) {
    _requireCommunity(communityId);
    _requireAlertId(alertId);
    return _firestore.collection('sosAlerts').doc(alertId).snapshots().map((
      snapshot,
    ) {
      final data = snapshot.data();
      if (data == null) return null;
      if (data['communityId'] != communityId)
        throw StateError('Emergency is outside the selected community.');
      return SosAlert(snapshot.id, data);
    });
  }

  @override
  Stream<List<SosAlert>> watchAlerts(
    String communityId, {
    bool active = true,
    String? residentUid,
  }) {
    _requireCommunity(communityId);
    Query<Map<String, dynamic>> query = _firestore
        .collection('sosAlerts')
        .where('communityId', isEqualTo: communityId)
        .where(
          'status',
          whereIn: active ? activeSosStatuses : ['resolved', 'cancelled'],
        );
    if (residentUid != null)
      query = query.where('residentUid', isEqualTo: residentUid);
    query = query.orderBy('triggeredAt', descending: !active);
    if (!active) query = query.limit(50);
    return query.snapshots().map(
      (snapshot) =>
          snapshot.docs.map((doc) => SosAlert(doc.id, doc.data())).toList(),
    );
  }
}

String newSosRequestId() {
  final random = Random.secure();
  return List.generate(
    24,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}

String sosErrorMessage(Object error) {
  if (error is FirebaseFunctionsException &&
      const [
        'permission-denied',
        'failed-precondition',
        'invalid-argument',
      ].contains(error.code) &&
      error.message?.isNotEmpty == true)
    return error.message!;
  return 'Unable to confirm this request. Check your connection and retry, or call Security for urgent assistance.';
}

// Notification IDs remain handled by the existing authorized notification router.
// Only a trusted notification document may provide an SOS destination.
String? sosAlertIdFromNotification(Map<String, dynamic> notification) {
  final id = notification['sourceEntityId'];
  return notification['type'] == 'sos' &&
          id is String &&
          RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(id)
      ? id
      : null;
}
