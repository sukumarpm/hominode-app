enum HominodeSubscriptionStatus {
  trial,
  active,
  grace,
  expired,
  suspended,
  cancelled;

  static HominodeSubscriptionStatus? fromValue(Object? value) {
    final normalized = value?.toString().trim().toLowerCase();

    for (final status in HominodeSubscriptionStatus.values) {
      if (status.name == normalized) return status;
    }

    return null;
  }
}

class HominodeEntitlement {
  const HominodeEntitlement({
    required this.communityId,
    required this.planId,
    required this.status,
    required this.features,
    required this.limits,
    this.startsAtMs,
    this.endsAtMs,
  });

  final String communityId;
  final String planId;
  final HominodeSubscriptionStatus status;
  final int? startsAtMs;
  final int? endsAtMs;
  final Map<String, dynamic> features;
  final Map<String, dynamic> limits;

  factory HominodeEntitlement.fromMap(Map<String, dynamic> data) {
    final status = HominodeSubscriptionStatus.fromValue(data['status']);

    if (status == null) {
      throw ArgumentError('Unsupported subscription status: ${data['status']}');
    }

    return HominodeEntitlement(
      communityId: (data['communityId'] ?? '').toString().trim(),
      planId: (data['planId'] ?? '').toString().trim().toLowerCase(),
      status: status,
      startsAtMs: _asInt(data['startsAtMs']),
      endsAtMs: _asInt(data['endsAtMs']),
      features: data['features'] is Map
          ? Map<String, dynamic>.from(data['features'] as Map)
          : const {},
      limits: data['limits'] is Map
          ? Map<String, dynamic>.from(data['limits'] as Map)
          : const {},
    );
  }

  bool isUsable({DateTime? now}) {
    final currentMs = (now ?? DateTime.now()).millisecondsSinceEpoch;

    if (startsAtMs != null && currentMs < startsAtMs!) {
      return false;
    }

    switch (status) {
      case HominodeSubscriptionStatus.active:
        return endsAtMs == null || currentMs < endsAtMs!;

      case HominodeSubscriptionStatus.trial:
      case HominodeSubscriptionStatus.grace:
        return endsAtMs != null && currentMs < endsAtMs!;

      case HominodeSubscriptionStatus.expired:
      case HominodeSubscriptionStatus.suspended:
      case HominodeSubscriptionStatus.cancelled:
        return false;
    }
  }

  bool canUseFeature(String featureKey, {DateTime? now}) {
    if (!isUsable(now: now)) return false;
    return features[featureKey] == true;
  }

  bool hasLimit(String limitKey) => limits.containsKey(limitKey);

  int? getIntLimit(String limitKey) {
    final value = limits[limitKey];

    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();

    return null;
  }

  bool isUnlimited(String limitKey) =>
      limits.containsKey(limitKey) && limits[limitKey] == null;

  static int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return null;
  }
}
