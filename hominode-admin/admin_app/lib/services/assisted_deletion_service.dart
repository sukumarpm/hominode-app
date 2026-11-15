import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'admin_tenant_context.dart';

const assistedVerificationMethods = {
  'in_person_with_community_records': 'In person with community records',
  'live_video_with_community_records': 'Live video with community records',
  'document_and_community_records': 'Document and community records',
};

class AssistedDeletionResident {
  const AssistedDeletionResident({required this.uid, required this.communityId, required this.name, required this.building, required this.unit});
  final String uid, communityId, name, building, unit;
  String get label => '$name · $building · $unit';
}

typedef AssistedDeletionCall = Future<Map<String, dynamic>> Function(String name, Map<String, dynamic> data);
abstract interface class AssistedDeletionGateway {
  Future<List<AssistedDeletionResident>> residents(String communityId);
  Future<Map<String, dynamic>> createIntake(Map<String, dynamic> data);
  Future<Map<String, dynamic>> verify({required String communityId, required String requestId, required String intakeDigest});
}

class AssistedDeletionService implements AssistedDeletionGateway {
  AssistedDeletionService({AssistedDeletionCall? call}) : _call = call ?? _firebaseCall;
  final AssistedDeletionCall _call;
  static Future<Map<String, dynamic>> _firebaseCall(String name, Map<String, dynamic> data) async {
    final result = await FirebaseFunctions.instanceFor(region: 'asia-southeast1').httpsCallable(name).call(data);
    if (result.data is! Map) throw StateError('The service returned an unconfirmed result. Refresh before retrying.');
    return Map<String, dynamic>.from(result.data as Map);
  }
  void _scope(String communityId) {
    if (AdminTenantContext.instance.requireCommunityId() != communityId) throw StateError('Community changed. Close and reopen the request.');
  }
  @override
  Future<List<AssistedDeletionResident>> residents(String communityId) async {
    _scope(communityId);
    final db = FirebaseFirestore.instance;
    // Same authorized community/Resident query as Resident Management.
    final results = await Future.wait([
      db.collection('users').where('role', isEqualTo: 'resident').where('communityId', isEqualTo: communityId).get(),
      db.collection('buildings').where('communityId', isEqualTo: communityId).get(),
      db.collection('flats').where('communityId', isEqualTo: communityId).get(),
    ]);
    _scope(communityId);
    final buildings = {for (final doc in results[1].docs) doc.id: doc.data()};
    final units = {for (final doc in results[2].docs) doc.id: doc.data()};
    String text(dynamic value) => value is String ? value.trim() : '';
    String first(List<dynamic> values, String fallback) => values.map(text).firstWhere((v) => v.isNotEmpty, orElse: () => fallback);
    final residents = <AssistedDeletionResident>[];
    for (final doc in results[0].docs) {
      final data = doc.data();
      if (data['uid'] != doc.id || data['communityId'] != communityId || data['role'] != 'resident' || ['deleted', 'completed'].contains(data['status']) ||
          (data['communityIds'] != null && (data['communityIds'] is! List || (data['communityIds'] as List).any((c) => c != communityId)))) {
        continue;
      }
      final unit = units[text(data['flatId'])];
      final building = buildings[text(data['buildingId'] ?? unit?['buildingId'])];
      residents.add(AssistedDeletionResident(uid: doc.id, communityId: communityId,
        name: first([data['fullName'], data['name']], 'Name not provided'),
        building: first([building?['name'], building?['buildingName'], data['buildingName']], 'Building not provided'),
        unit: first([data['flatLabel'], unit?['flatLabel'], unit?['unitLabel'], unit?['flatNumber'], unit?['unitId']], 'Unit not provided')));
    }
    residents.sort((a,b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
    return residents;
  }
  @override
  Future<Map<String, dynamic>> createIntake(Map<String, dynamic> data) {
    _scope(data['communityId'] as String);
    return _call('createAdminAssistedDeletionRequest', data);
  }
  @override
  Future<Map<String, dynamic>> verify({required String communityId, required String requestId, required String intakeDigest}) {
    _scope(communityId);
    return _call('verifyAdminAssistedDeletionRequest', {'requestId': requestId, 'intakeDigest': intakeDigest, 'identityConfirmed': true, 'consentConfirmed': true});
  }
}

String assistedDeletionError(Object error) {
  if (error is FirebaseFunctionsException) {
    return switch (error.code) {
      'unauthenticated' => 'Sign in again using your Admin phone verification, then retry.',
      'permission-denied' => 'Access denied. Use an authorized Community Admin phone session and the approved Admin app.',
      'failed-precondition' => 'Reauthenticate with your Admin phone and refresh this request. If it still fails, the Resident, community or existing request requires reconciliation.',
      'already-exists' => 'An intake already exists with different evidence. Refresh the queue; saved evidence cannot be overwritten.',
      'invalid-argument' => 'Check required fields, protected references, verification method and explicit consent. Document links and image data are not accepted.',
      'not-found' => 'The Resident or request is no longer available. Refresh the queue.',
      'unavailable' || 'deadline-exceeded' => 'The service could not confirm the result. Refresh before retrying; repeated requests are safe.',
      _ => 'The request could not be confirmed. Refresh and retry. If the problem continues, contact support.',
    };
  }
  return 'The request could not be confirmed. Check community access, refresh and retry.';
}
