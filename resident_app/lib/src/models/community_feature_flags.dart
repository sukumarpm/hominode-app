/// Features that can be enabled independently for each community.
class CommunityFeatureFlags {
  final bool visitors;
  final bool amenities;
  final bool complaints;
  final bool notices;
  final bool chat;
  final bool marketplace;
  final bool maintenance;
  final bool payments;

  const CommunityFeatureFlags({
    this.visitors = false,
    this.amenities = false,
    this.complaints = false,
    this.notices = false,
    this.chat = false,
    this.marketplace = false,
    this.maintenance = false,
    this.payments = false,
  });

  factory CommunityFeatureFlags.fromMap(Map<String, dynamic>? map) {
    final data = map ?? const <String, dynamic>{};
    return CommunityFeatureFlags(
      visitors: data['visitors'] == true,
      amenities: data['amenities'] == true,
      complaints: data['complaints'] == true,
      notices: data['notices'] == true,
      chat: data['chat'] == true,
      marketplace: data['marketplace'] == true,
      maintenance: data['maintenance'] == true,
      payments: data['payments'] == true,
    );
  }

  Map<String, bool> toMap() => {
    'visitors': visitors,
    'amenities': amenities,
    'complaints': complaints,
    'notices': notices,
    'chat': chat,
    'marketplace': marketplace,
    'maintenance': maintenance,
    'payments': payments,
  };
}
