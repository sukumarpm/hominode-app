import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hominode_time/community_time.dart';
export 'package:hominode_time/community_time.dart';

const residentPetVisitMessage =
    'Pets are not permitted for this visit. You may continue without a pet.';
typedef ResidentVisitorCallable =
    Future<Map<String, dynamic>> Function(String, Map<String, dynamic>);

class ResidentVisitorScope {
  const ResidentVisitorScope({
    required this.uid,
    required this.communityId,
    this.timeZone,
  });
  final String uid, communityId;
  final String? timeZone;
}

class ResidentVisitorPolicyService {
  ResidentVisitorPolicyService({
    ResidentVisitorCallable? callable,
    Future<ResidentVisitorScope> Function()? scopeLoader,
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    Stream<Object?> Function(String)? policyChanges,
  }) : _callable = callable,
       _scopeLoader = scopeLoader,
       _firestore = firestore,
       _auth = auth,
       _policyChanges = policyChanges;
  final ResidentVisitorCallable? _callable;
  final Future<ResidentVisitorScope> Function()? _scopeLoader;
  final FirebaseFirestore? _firestore;
  final FirebaseAuth? _auth;
  final Stream<Object?> Function(String)? _policyChanges;
  // Every community snapshot matters, including schedules that leave the base
  // revision unchanged. Snapshot data is a refresh signal, never permission.
  Stream<Object?> watchCommunity(String id) =>
      _policyChanges?.call(id) ??
      (_firestore ?? FirebaseFirestore.instance)
          .collection('communities')
          .doc(id)
          .snapshots()
          .map((doc) => doc.data());
  Future<ResidentVisitorScope> loadScope() async {
    if (_scopeLoader != null) return _scopeLoader();
    final user = (_auth ?? FirebaseAuth.instance).currentUser;
    if (user == null) throw StateError('Sign in again to manage visitors.');
    final db = _firestore ?? FirebaseFirestore.instance;
    final data =
        (await db
                .collection('users')
                .doc(user.uid)
                .get(const GetOptions(source: Source.server)))
            .data();
    final communityId = data?['communityId'];
    if (data?['role'] != 'resident' ||
        communityId is! String ||
        communityId.isEmpty) {
      throw StateError('Your Resident community is unavailable.');
    }
    final community =
        (await db
                .collection('communities')
                .doc(communityId)
                .get(const GetOptions(source: Source.server)))
            .data();
    return ResidentVisitorScope(
      uid: user.uid,
      communityId: communityId,
      timeZone: community?['timeZone'] is String
          ? community!['timeZone'] as String
          : null,
    );
  }

  Future<Map<String, dynamic>> _call(
    String name,
    Map<String, dynamic> payload,
  ) async {
    if (_callable != null) return _callable(name, payload);
    final result = await FirebaseFunctions.instanceFor(
      region: 'asia-southeast1',
    ).httpsCallable(name).call(payload);
    return Map<String, dynamic>.from(result.data as Map);
  }

  Future<Map<String, dynamic>> contextFor(DateTime arrival) async {
    final scope = await loadScope();
    final result = await _call('getResidentVisitorContext', {
      'expectedArrival': arrival.millisecondsSinceEpoch,
    });
    if (result['communityId'] != scope.communityId ||
        result['petPermitted'] is! bool) {
      throw StateError('Visitor guidance is unavailable for your community.');
    }
    return result;
  }

  Future<Map<String, dynamic>> mutate(
    Map<String, dynamic> visitor, {
    required String action,
    DateTime? arrival,
    bool? bringingPet,
  }) async {
    final scope = await loadScope();
    final host = visitor['hostUserId'] ?? visitor['residentId'];
    if (visitor['communityId'] != scope.communityId ||
        host != scope.uid ||
        (visitor['residentId'] != null && visitor['residentId'] != scope.uid)) {
      throw StateError(
        'This invitation is outside your Resident account or community.',
      );
    }
    if (!const {'cancel', 'reschedule'}.contains(action)) {
      throw ArgumentError('Unsupported visitor action.');
    }
    final payload = <String, dynamic>{
      'visitorId': visitor['id'],
      'action': action,
      'expectedRevision': visitor['authorizationRevision'] ?? 0,
    };
    if (action == 'reschedule') {
      if (arrival != null) {
        payload['expectedArrival'] = arrival.millisecondsSinceEpoch;
      }
      if (bringingPet != null) payload['bringingPet'] = bringingPet;
    }
    final result = await _call('mutateResidentVisitor', payload);
    if (result['visitorId'] != visitor['id'] ||
        result['authorizationRevision'] is! num ||
        result['authorizationState'] is! String) {
      throw StateError(
        'The change could not be confirmed. Reload your visitor list before retrying.',
      );
    }
    return result;
  }
}

String residentVisitorError(Object error) {
  final message = error is FirebaseException
      ? error.message ?? ''
      : error.toString();
  if (message.contains('Pets are not permitted')) {
    return residentPetVisitMessage;
  }
  if (error is FirebaseException) {
    if (error.code == 'aborted') {
      return 'This invitation changed. Reload and review its current status before trying again.';
    }
    if (const {'permission-denied', 'unauthenticated'}.contains(error.code)) {
      return 'Visitor access denied. Sign in again or contact your Community Admin.';
    }
    if (const {'unavailable', 'deadline-exceeded'}.contains(error.code)) {
      return 'The result could not be confirmed. Check your visitor list before retrying.';
    }
    if (error.code == 'not-found') {
      return 'This visitor service or invitation is unavailable. Reload or contact support.';
    }
  }
  return message.replaceFirst(RegExp(r'^(Bad state: |FormatException: )'), '');
}

/// Compatibility entry point for the existing visitor scheduling contract.
class ResidentVisitTime {
  static String local(DateTime instant, String? zone) =>
      CommunityTime.local(instant, zone);
  static DateTime instant(String value, String? zone) =>
      CommunityTime.instant(value, zone);
}
