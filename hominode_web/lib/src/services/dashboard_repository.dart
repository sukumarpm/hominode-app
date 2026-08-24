import 'package:cloud_firestore/cloud_firestore.dart';

class PlatformMetrics {
  const PlatformMetrics({
    required this.communities,
    required this.activeCommunities,
    required this.admins,
    required this.activeAdmins,
  });

  final int communities;
  final int activeCommunities;
  final int admins;
  final int activeAdmins;

  int get inactiveCommunities => communities - activeCommunities;
}

class DashboardMetrics {
  const DashboardMetrics(this.values);

  final Map<String, int?> values;

  int? operator [](String key) => values[key];
}

class DashboardRepository {
  DashboardRepository([FirebaseFirestore? firestore])
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  Future<PlatformMetrics> platformMetrics() async {
    final results = await Future.wait([
      _db.collection('communities').get(),
      _db.collection('admins').where('role', isEqualTo: 'admin').get(),
    ]);

    final communities = results[0].docs;
    final admins = results[1].docs;

    return PlatformMetrics(
      communities: communities.length,
      activeCommunities: communities
          .where((doc) => doc.data()['isActive'] == true)
          .length,
      admins: admins.length,
      activeAdmins: admins
          .where((doc) => doc.data()['isActive'] == true)
          .length,
    );
  }

  Future<DashboardMetrics> adminMetrics(String communityId) async =>
      DashboardMetrics({
        'residents': await _safeCount(
          'users',
          communityId,
          extra: (query) => query.where('role', isEqualTo: 'resident'),
        ),
        'buildings': await _safeCount('buildings', communityId),
        'visitors': await _safeCount('visitors', communityId),
        'complaints': await _safeCount('complaints', communityId),
      });

  Future<DashboardMetrics> residentMetrics({
    required String communityId,
    required String uid,
    String? flatId,
  }) async => DashboardMetrics({
    'complaints': await _safeCount(
      'complaints',
      communityId,
      extra: (query) => query.where('userId', isEqualTo: uid),
    ),
    'visitors': await _safeCount(
      'visitors',
      communityId,
      extra: (query) => query.where('hostUserId', isEqualTo: uid),
    ),
    'bills': flatId == null || flatId.isEmpty
        ? null
        : await _safeCount(
            'bills',
            communityId,
            extra: (query) => query.where('flatId', isEqualTo: flatId),
          ),
    'notices': await _safeCount('notices', communityId),
    'events': await _safeCount('events', communityId),
  });

  Future<int?> _safeCount(
    String collection,
    String communityId, {
    Query<Map<String, dynamic>> Function(Query<Map<String, dynamic>>)? extra,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _db
          .collection(collection)
          .where('communityId', isEqualTo: communityId);

      if (extra != null) {
        query = extra(query);
      }

      return (await query.count().get()).count;
    } on FirebaseException {
      return null;
    }
  }
}
