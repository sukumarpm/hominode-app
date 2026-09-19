import 'package:cloud_functions/cloud_functions.dart';

class CommunitySubscription {
  const CommunitySubscription({
    required this.communityId,
    required this.planId,
    required this.planName,
    required this.status,
    required this.startsAtMs,
    required this.endsAtMs,
    required this.features,
    required this.limits,
  });

  final String communityId;
  final String planId;
  final String planName;
  final String status;
  final int? startsAtMs;
  final int? endsAtMs;
  final Map<String, dynamic> features;
  final Map<String, dynamic> limits;

  factory CommunitySubscription.fromMap(Map<String, dynamic> data) {
    return CommunitySubscription(
      communityId: (data['communityId'] ?? '').toString(),
      planId: (data['planId'] ?? '').toString(),
      planName: (data['planName'] ?? '').toString(),
      status: (data['status'] ?? '').toString(),
      startsAtMs: data['startsAtMs'] is num
          ? (data['startsAtMs'] as num).toInt()
          : null,
      endsAtMs: data['endsAtMs'] is num
          ? (data['endsAtMs'] as num).toInt()
          : null,
      features: data['features'] is Map
          ? Map<String, dynamic>.from(data['features'] as Map)
          : const {},
      limits: data['limits'] is Map
          ? Map<String, dynamic>.from(data['limits'] as Map)
          : const {},
    );
  }
}

class SubscriptionService {
  SubscriptionService({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'asia-southeast1');

  final FirebaseFunctions _functions;

  Future<CommunitySubscription?> getSubscription(String communityId) async {
    final response = await _functions
        .httpsCallable('getCommunitySubscription')
        .call({'communityId': communityId});

    final data = response.data;

    if (data == null) return null;

    if (data is! Map) {
      throw StateError('Subscription service returned an invalid response.');
    }

    return CommunitySubscription.fromMap(Map<String, dynamic>.from(data));
  }

  Future<void> createSubscription({
    required String communityId,
    required String planId,
    required String status,
    int? endsAtMs,
    String? notes,
  }) async {
    await _functions.httpsCallable('createCommunitySubscription').call({
      'communityId': communityId,
      'planId': planId,
      'status': status,
      if (endsAtMs != null) 'endsAtMs': endsAtMs,
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
    });
  }

  Future<void> changePlan({
    required String communityId,
    required String planId,
    String? notes,
  }) async {
    await _functions.httpsCallable('changeCommunitySubscriptionPlan').call({
      'communityId': communityId,
      'planId': planId,
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
    });
  }

  Future<void> extendSubscription({
    required String communityId,
    required int endsAtMs,
    String? notes,
  }) async {
    await _functions.httpsCallable('extendCommunitySubscription').call({
      'communityId': communityId,
      'endsAtMs': endsAtMs,
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
    });
  }

  Future<void> setStatus({
    required String communityId,
    required String status,
    String? notes,
  }) async {
    await _functions.httpsCallable('setCommunitySubscriptionStatus').call({
      'communityId': communityId,
      'status': status,
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
    });
  }
}
