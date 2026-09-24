import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../models/community_payment_config.dart';
import 'admin_tenant_context.dart';

typedef CommunityPaymentConfigCallable =
    Future<void> Function(Map<String, dynamic> payload);

class CommunityPaymentConfigService {
  CommunityPaymentConfigService({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
    CommunityPaymentConfigCallable? updateCallable,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _functions = functions,
       _updateCallable = updateCallable;

  final FirebaseFirestore _firestore;
  final FirebaseFunctions? _functions;
  final CommunityPaymentConfigCallable? _updateCallable;

  FirebaseFunctions get _regionalFunctions =>
      _functions ?? FirebaseFunctions.instanceFor(region: 'asia-southeast1');

  String _requireSelectedCommunityId() =>
      AdminTenantContext.instance.requireCommunityId();

  Future<CommunityPaymentConfig> getSelectedCommunityPaymentConfig() async {
    final communityId = _requireSelectedCommunityId();
    final snapshot = await _firestore
        .collection('communityPaymentConfigs')
        .doc(communityId)
        .get(const GetOptions(source: Source.server));
    if (!snapshot.exists) {
      return CommunityPaymentConfig.unconfigured(communityId);
    }
    final data = snapshot.data();
    if (data == null) {
      throw const FormatException('Payment configuration document is invalid.');
    }
    return CommunityPaymentConfig.fromMap(snapshot.id, data);
  }

  static Map<String, dynamic> updatePayload({
    required String communityId,
    required bool enabled,
    String? vpa,
    String? payeeName,
  }) {
    final id = communityId.trim();
    if (id.isEmpty) throw ArgumentError('Community ID is required.');

    if (!enabled) {
      return {
        'communityId': id,
        'directUpi': {'enabled': false},
      };
    }

    final trimmedVpa = vpa?.trim() ?? '';
    final trimmedPayeeName = payeeName?.trim() ?? '';
    if (trimmedVpa.isEmpty || trimmedPayeeName.isEmpty) {
      throw ArgumentError(
        'VPA and payee name are required when Direct UPI is enabled.',
      );
    }
    return {
      'communityId': id,
      'directUpi': {
        'enabled': true,
        'vpa': trimmedVpa,
        'payeeName': trimmedPayeeName,
      },
    };
  }

  Future<CommunityPaymentConfig> updateDirectUpi({
    required bool enabled,
    String? vpa,
    String? payeeName,
  }) async {
    final communityId = _requireSelectedCommunityId();
    final payload = updatePayload(
      communityId: communityId,
      enabled: enabled,
      vpa: vpa,
      payeeName: payeeName,
    );
    final updateCallable = _updateCallable;
    if (updateCallable != null) {
      await updateCallable(payload);
    } else {
      await _regionalFunctions
          .httpsCallable('updateCommunityPaymentConfig')
          .call(payload);
    }

    // Return the server's committed document, never a client-manufactured
    // representation of a successful configuration change.
    return getSelectedCommunityPaymentConfig();
  }
}
