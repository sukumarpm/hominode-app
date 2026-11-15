import 'dart:math';
import 'package:cloud_functions/cloud_functions.dart';

const securitySupportTopics = {
  'technical_issue': 'App or technical issue',
  'phone_number': 'Registered phone number',
  'gate_shift': 'Gate or shift assignment',
  'account_access': 'Account provisioning or access',
  'other': 'Other support',
};
bool securityTopicGoesToAdmin(String topic) =>
    const {'phone_number', 'gate_shift', 'account_access'}.contains(topic);

class SecuritySupportReceipt {
  const SecuritySupportReceipt({
    required this.reference,
    required this.destination,
    required this.communityName,
  });
  final String reference, destination, communityName;
}

abstract interface class SecuritySupportRequests {
  Future<String> communityName();
  Future<SecuritySupportReceipt> submit({
    required String topic,
    required String message,
    required String requestKey,
  });
}

typedef SecuritySupportCall =
    Future<Map<String, dynamic>> Function(Map<String, dynamic> data);

class SecuritySupportRequestService implements SecuritySupportRequests {
  SecuritySupportRequestService({SecuritySupportCall? call})
    : _call = call ?? _firebaseCall;
  final SecuritySupportCall _call;
  static Future<Map<String, dynamic>> _firebaseCall(
    Map<String, dynamic> data,
  ) async {
    final result =
        await FirebaseFunctions.instanceFor(region: 'asia-southeast1')
            .httpsCallable(
              'securitySupportRequest',
              options: HttpsCallableOptions(
                timeout: const Duration(seconds: 60),
              ),
            )
            .call<Map<String, dynamic>>(data);
    return Map<String, dynamic>.from(result.data);
  }

  @override
  Future<String> communityName() async {
    final response = await _call({'action': 'context'});
    final name = response['communityName'];
    if (name is! String || name.trim().isEmpty) {
      throw const FormatException('Unconfirmed community');
    }
    return name;
  }

  @override
  Future<SecuritySupportReceipt> submit({
    required String topic,
    required String message,
    required String requestKey,
  }) async {
    final result = await _call({
      'action': 'submit',
      'topic': topic,
      'message': message.trim(),
      'requestKey': requestKey,
    });
    final reference = result['reference'],
        destination = result['destination'],
        community = result['communityName'];
    if (result['status'] != 'received' ||
        reference is! String ||
        !RegExp(r'^HSP-[A-F0-9]{24}$').hasMatch(reference) ||
        !['community_admin', 'hominode_support'].contains(destination) ||
        community is! String ||
        community.trim().isEmpty ||
        destination !=
            (securityTopicGoesToAdmin(topic)
                ? 'community_admin'
                : 'hominode_support')) {
      throw const FormatException('Your request could not be confirmed.');
    }
    return SecuritySupportReceipt(
      reference: reference,
      destination: destination as String,
      communityName: community,
    );
  }
}

String newSecuritySupportRequestKey() {
  final random = Random.secure();
  return List.generate(
    16,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}

String securitySupportError(Object error) {
  if (error is FirebaseFunctionsException) {
    switch (error.code) {
      case 'invalid-argument':
        return 'Choose a support topic and describe the issue in 10–2000 characters.';
      case 'unauthenticated':
        return 'Please sign in again with your Security account.';
      case 'permission-denied':
        return 'Your Security account or community could not be verified. Please contact your Community Admin.';
      case 'failed-precondition':
        return 'Your community administrator may be unavailable, or your account assignment changed. Choose Other support to contact Hominode Support, or reopen this screen.';
      case 'resource-exhausted':
        return 'Please wait before sending another request. If you reached the daily limit, try again tomorrow.';
      case 'aborted':
        return 'Your request may still be processing. Wait a moment, then retry with the same message.';
      case 'not-found':
      case 'unimplemented':
        return 'Support requests are temporarily unavailable. Please contact hominodecare@gmail.com.';
    }
  }
  return 'Your request could not be confirmed. Check your connection and retry with the same message.';
}
