import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:hominode_time/community_time.dart';

import 'admin_tenant_context.dart';

typedef VisitorPolicyCallable =
    Future<Map<String, dynamic>> Function(
      String name,
      Map<String, dynamic> payload,
    );

const visitorApprovalOptions = {
  'resident_authorized': 'No Admin approval required',
  'tenant_approval_required': 'Tenant invitations require approval',
  'all_approval_required': 'All invitations require approval',
};
const visitorApprovalDescriptions = {
  'resident_authorized':
      'Eligible owners and tenants can invite visitors directly.',
  'tenant_approval_required':
      'Eligible owners invite directly. Tenant invitations wait for a Community Admin.',
  'all_approval_required':
      'All owner and tenant invitations wait for a Community Admin.',
};

class VisitorPolicyConfig {
  VisitorPolicyConfig.fromMap(Map<String, dynamic> value)
    : communityId = value['communityId'] as String,
      policy = Map<String, dynamic>.from(value['policy'] as Map),
      writeRevision = (value['writeRevision'] as num).toInt(),
      rolloutReady = value['rolloutReady'] == true,
      timeZone = value['timeZone'] as String?,
      pendingSchedule = value['pendingSchedule'] == null
          ? null
          : VisitorPolicySchedule.fromMap(
              Map<String, dynamic>.from(value['pendingSchedule'] as Map),
            ),
      serverTime = (value['serverTime'] as num).toInt();
  final String communityId;
  final Map<String, dynamic> policy;
  final int writeRevision;
  final bool rolloutReady;
  final String? timeZone;
  final VisitorPolicySchedule? pendingSchedule;
  final int serverTime;
  final Stopwatch _elapsed = Stopwatch()..start();
  int get currentServerTime => serverTime + _elapsed.elapsedMilliseconds;
  int get revision => (policy['revision'] as num).toInt();
  bool get enabled => policy['enabled'] == true;
  String? get timeZoneError {
    try {
      CommunityTime.canonical(timeZone);
      return null;
    } on FormatException catch (error) {
      return error.message;
    }
  }
}

class VisitorPolicySchedule {
  VisitorPolicySchedule.fromMap(Map<String, dynamic> value)
    : effectiveAt = (value['effectiveAt'] as num).toInt(),
      revision = (value['revision'] as num).toInt(),
      policy = Map<String, dynamic>.from(value['policy'] as Map);
  final int effectiveAt;
  final int revision;
  final Map<String, dynamic> policy;
}

Map<String, dynamic> visitorPolicyInput(Map<String, dynamic> policy) {
  final pets = Map<String, dynamic>.from(policy['pets'] as Map);
  return {
    'schemaVersion': 1,
    'enabled': policy['enabled'],
    'timeZone': policy['timeZone'],
    'approvalMode': policy['approvalMode'],
    'emergency': policy['emergency'],
    'pets': {
      'mode': pets['mode'],
      'normalMode': pets['normalMode'],
      'restriction': pets['restriction'],
    },
  };
}

class VisitorPolicyService {
  VisitorPolicyService({
    VisitorPolicyCallable? callable,
    String Function()? community,
    FirebaseFirestore? firestore,
  }) : _callable = callable,
       _community = community,
       _firestore = firestore;
  final VisitorPolicyCallable? _callable;
  final String Function()? _community;
  final FirebaseFirestore? _firestore;
  VisitorPolicyConfig? _loaded;
  String get communityId =>
      (_community ?? AdminTenantContext.instance.requireCommunityId)();
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

  Future<VisitorPolicyConfig> load() async {
    final id = communityId;
    final result = VisitorPolicyConfig.fromMap(
      await _call('getCommunityVisitorPolicy', {'communityId': id}),
    );
    if (result.communityId != id || communityId != id) {
      throw StateError('Community changed. Reload visitor settings.');
    }
    _loaded = result;
    return result;
  }

  Future<VisitorPolicyConfig> save(
    Map<String, dynamic> policy,
    int revision, {
    int? effectiveAt,
  }) async {
    final id = communityId;
    final config = _loaded;
    if (config == null || config.communityId != id) {
      throw StateError('Reload visitor settings before saving.');
    }
    if (policy['enabled'] == true && !config.rolloutReady) {
      throw StateError(
        'Saving is blocked until visitor policy rollout is ready for this community.',
      );
    }
    if (config.timeZoneError != null) {
      throw FormatException(config.timeZoneError!);
    }
    if (effectiveAt != null && effectiveAt <= config.currentServerTime) {
      throw const FormatException('Choose a future policy effective time.');
    }
    await _call('updateCommunityVisitorPolicy', {
      'communityId': id,
      'policy': {...visitorPolicyInput(policy), 'timeZone': config.timeZone},
      'expectedRevision': revision,
      if (effectiveAt != null) 'effectiveAt': effectiveAt,
    });
    if (communityId != id) {
      throw StateError('Community changed. Reload visitor settings.');
    }
    return load();
  }

  Stream<int> watch() {
    final id = communityId;
    return (_firestore ?? FirebaseFirestore.instance)
        .collection('communities')
        .doc(id)
        .snapshots()
        .map((doc) {
          if (communityId != id) {
            throw StateError('Community changed. Reload visitor settings.');
          }
          final value = doc.data();
          final active =
              ((value?['visitorPolicy'] as Map?)?['revision'] as num?)
                  ?.toInt() ??
              0;
          final scheduled =
              ((value?['scheduledVisitorPolicy'] as Map?)?['revision'] as num?)
                  ?.toInt() ??
              0;
          return active > scheduled ? active : scheduled;
        });
  }
}

String visitorPolicyError(Object error) {
  if (error is FirebaseFunctionsException) {
    if (error.code == 'aborted') {
      return 'This record changed on another device. Reload, review the latest state, and try again.';
    }
    if (error.code == 'permission-denied' || error.code == 'unauthenticated') {
      return 'Community access denied. Sign in again or contact your Community Admin.';
    }
    return error.message ?? 'The request could not be completed. Please retry.';
  }
  return error.toString().replaceFirst(
    RegExp(r'^(Bad state: |FormatException: )'),
    '',
  );
}

class VisitorSchedule {
  static String local(int? milliseconds, String? zone) => milliseconds == null
      ? ''
      : CommunityTime.local(
          DateTime.fromMillisecondsSinceEpoch(milliseconds, isUtc: true),
          zone,
        );

  static int instant(String value, String? zone) =>
      CommunityTime.instant(value, zone).millisecondsSinceEpoch;

  static Map<String, int> period(String start, String end, String? zone) {
    final from = instant(start, zone), until = instant(end, zone);
    if (until <= from) throw const FormatException('End must be after start.');
    return {'startAt': from, 'endAt': until};
  }

  static int futureInstant(
    String value,
    String? zone,
    int serverTime, {
    int? originalInstant,
  }) {
    final parsed = VisitorSchedule.instant(value, zone);
    // Controls show minutes; preserve stored seconds when the time is unchanged.
    final instant =
        originalInstant != null && local(originalInstant, zone) == value
        ? originalInstant
        : parsed;
    if (instant <= serverTime) {
      throw const FormatException('Choose a future policy effective time.');
    }
    return instant;
  }

  static String status(Map? period, int serverTime) => period == null
      ? 'Off'
      : serverTime < (period['startAt'] as num)
      ? 'Scheduled'
      : serverTime >= (period['endAt'] as num)
      ? 'Expired'
      : 'Active';
}
