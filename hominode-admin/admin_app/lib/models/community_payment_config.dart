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
      throw const FormatException('Direct UPI enabled state is invalid.');
    }
    if (!enabled) {
      // Disabled documents may be stale or malformed. Never expose an old
      // payment destination to callers in the disabled state.
      return const DirectUpiConfig.disabled();
    }

    final rawVpa = data['vpa'];
    final rawPayeeName = data['payeeName'];
    if (rawVpa is! String || rawPayeeName is! String) {
      throw const FormatException(
        'Enabled Direct UPI requires a VPA and payee name.',
      );
    }
    final vpa = rawVpa.trim();
    final payeeName = rawPayeeName.trim();
    final vpaParts = vpa.split('@');
    if (vpa.isEmpty ||
        vpa.contains(RegExp(r'\s')) ||
        vpaParts.length != 2 ||
        vpaParts.any((part) => part.isEmpty) ||
        payeeName.isEmpty) {
      throw const FormatException(
        'Enabled Direct UPI contains an unusable destination.',
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
    this.updatedBy,
    this.updatedAt,
  });

  factory CommunityPaymentConfig.unconfigured(String communityId) {
    final id = communityId.trim();
    if (id.isEmpty) throw ArgumentError('Community ID is required.');
    return CommunityPaymentConfig(
      communityId: id,
      version: 1,
      directUpi: const DirectUpiConfig.disabled(),
    );
  }

  final String communityId;
  final int version;
  final DirectUpiConfig directUpi;
  final String? updatedBy;
  final DateTime? updatedAt;

  factory CommunityPaymentConfig.fromMap(
    String documentCommunityId,
    Map<String, dynamic> data,
  ) {
    final id = documentCommunityId.trim();
    if (id.isEmpty || data['communityId'] != id) {
      throw const FormatException(
        'Payment configuration community ID is invalid.',
      );
    }
    if (data['version'] is! int || data['version'] != 1) {
      throw const FormatException(
        'Payment configuration version is unsupported.',
      );
    }
    final rawDirectUpi = data['directUpi'];
    if (rawDirectUpi is! Map ||
        rawDirectUpi.keys.any((key) => key is! String)) {
      throw const FormatException('Direct UPI configuration is invalid.');
    }
    final updatedBy = data['updatedBy'];
    final rawUpdatedAt = data['updatedAt'];
    final updatedAt = rawUpdatedAt is Timestamp
        ? rawUpdatedAt.toDate()
        : rawUpdatedAt is DateTime
        ? rawUpdatedAt
        : null;
    if (updatedBy is! String || updatedBy.trim().isEmpty || updatedAt == null) {
      throw const FormatException('Payment configuration metadata is invalid.');
    }

    return CommunityPaymentConfig(
      communityId: id,
      version: 1,
      directUpi: DirectUpiConfig.fromMap(
        Map<String, dynamic>.from(rawDirectUpi),
      ),
      updatedBy: updatedBy.trim(),
      updatedAt: updatedAt,
    );
  }
}
