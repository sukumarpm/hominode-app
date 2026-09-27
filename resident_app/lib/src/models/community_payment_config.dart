import 'package:cloud_firestore/cloud_firestore.dart';

class DirectUpiConfig {
  const DirectUpiConfig._({required this.enabled, this.vpa, this.payeeName});

  const DirectUpiConfig.disabled() : this._(enabled: false);

  final bool enabled;
  final String? vpa;
  final String? payeeName;

  bool get isUsable =>
      enabled &&
      vpa != null &&
      vpa!.isNotEmpty &&
      payeeName != null &&
      payeeName!.isNotEmpty;

  factory DirectUpiConfig.fromMap(Map<String, dynamic> data) {
    final enabled = data['enabled'];
    if (enabled is! bool) {
      throw const FormatException(
        'Community payment configuration is invalid.',
      );
    }
    if (!enabled) return const DirectUpiConfig.disabled();

    final rawVpa = data['vpa'];
    final rawPayeeName = data['payeeName'];
    if (rawVpa is! String || rawPayeeName is! String) {
      throw const FormatException(
        'Community payment configuration is invalid.',
      );
    }
    final vpa = rawVpa.trim();
    final payeeName = rawPayeeName.trim();
    final parts = vpa.split('@');
    if (vpa.isEmpty ||
        vpa.contains(RegExp(r'\s')) ||
        parts.length != 2 ||
        parts.any((part) => part.isEmpty) ||
        payeeName.isEmpty) {
      throw const FormatException(
        'Community payment configuration is invalid.',
      );
    }
    return DirectUpiConfig._(enabled: true, vpa: vpa, payeeName: payeeName);
  }
}

class CommunityPaymentConfig {
  const CommunityPaymentConfig({
    required this.communityId,
    required this.version,
    required this.directUpi,
    required this.configured,
    this.updatedBy,
    this.updatedAt,
  });

  factory CommunityPaymentConfig.unconfigured(String communityId) {
    final id = communityId.trim();
    if (id.isEmpty) {
      throw ArgumentError('Community ID is required.');
    }
    return CommunityPaymentConfig(
      communityId: id,
      version: 1,
      directUpi: const DirectUpiConfig.disabled(),
      configured: false,
    );
  }

  final String communityId;
  final int version;
  final DirectUpiConfig directUpi;
  final String? updatedBy;
  final DateTime? updatedAt;
  final bool configured;

  factory CommunityPaymentConfig.fromMap(
    String documentCommunityId,
    Map<String, dynamic> data,
  ) {
    final id = documentCommunityId.trim();
    if (id.isEmpty ||
        data['communityId'] != id ||
        data['version'] is! int ||
        data['version'] != 1) {
      throw const FormatException(
        'Community payment configuration is invalid.',
      );
    }

    final rawDirectUpi = data['directUpi'];
    if (rawDirectUpi is! Map ||
        rawDirectUpi.keys.any((key) => key is! String)) {
      throw const FormatException(
        'Community payment configuration is invalid.',
      );
    }

    final updatedBy = data['updatedBy'];
    final rawUpdatedAt = data['updatedAt'];
    final updatedAt = rawUpdatedAt is Timestamp
        ? rawUpdatedAt.toDate()
        : rawUpdatedAt is DateTime
        ? rawUpdatedAt
        : null;
    if (updatedBy is! String || updatedBy.trim().isEmpty || updatedAt == null) {
      throw const FormatException(
        'Community payment configuration is invalid.',
      );
    }

    return CommunityPaymentConfig(
      communityId: id,
      version: 1,
      directUpi: DirectUpiConfig.fromMap(
        Map<String, dynamic>.from(rawDirectUpi),
      ),
      updatedBy: updatedBy.trim(),
      updatedAt: updatedAt,
      configured: true,
    );
  }
}
