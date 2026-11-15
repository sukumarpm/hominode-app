import 'package:cloud_functions/cloud_functions.dart';

class SecurityDeletionStatus {
  const SecurityDeletionStatus({
    required this.communityName,
    this.reference,
    this.status,
    this.submitted = false,
  });
  final String communityName;
  final String? reference;
  final String? status;
  final bool submitted;
}

abstract interface class SecurityDeletionRequests {
  Future<SecurityDeletionStatus> status();
  Future<SecurityDeletionStatus> submit();
}

typedef SecurityDeletionCall =
    Future<Map<String, dynamic>> Function(Map<String, dynamic> data);

class SecurityAccountDeletionRequestService
    implements SecurityDeletionRequests {
  SecurityAccountDeletionRequestService({SecurityDeletionCall? call})
    : _call = call ?? _firebaseCall;
  final SecurityDeletionCall _call;

  static Future<Map<String, dynamic>> _firebaseCall(
    Map<String, dynamic> data,
  ) async {
    final result =
        await FirebaseFunctions.instanceFor(region: 'asia-southeast1')
            .httpsCallable(
              'securityAccountDeletionRequest',
              options: HttpsCallableOptions(
                timeout: const Duration(seconds: 60),
              ),
            )
            .call<Map<String, dynamic>>(data);
    return Map<String, dynamic>.from(result.data);
  }

  Future<SecurityDeletionStatus> _request(String action) async {
    final data = await _call({
      'action': action,
      if (action == 'submit') 'confirmed': true,
    });
    final community = data['communityName'];
    final request = data['request'];
    if (community is! String || community.trim().isEmpty) {
      throw const FormatException('The request could not be confirmed.');
    }
    if (request == null && action == 'status') {
      return SecurityDeletionStatus(communityName: community);
    }
    if (request is! Map ||
        request['reference'] is! String ||
        !RegExp(
          r'^SDR-[A-F0-9]{24}$',
        ).hasMatch(request['reference'] as String) ||
        request['status'] is! String ||
        request['submitted'] is! bool ||
        (action == 'submit' && request['submitted'] != true)) {
      throw const FormatException('The request could not be confirmed.');
    }
    return SecurityDeletionStatus(
      communityName: community,
      reference: request['reference'] as String,
      status: request['status'] as String,
      submitted: request['submitted'] as bool,
    );
  }

  @override
  Future<SecurityDeletionStatus> status() => _request('status');
  @override
  Future<SecurityDeletionStatus> submit() => _request('submit');
}

String securityDeletionError(Object error) {
  if (error is FirebaseFunctionsException) {
    switch (error.code) {
      case 'unauthenticated':
        return 'Please sign in again with your Security account.';
      case 'permission-denied':
        return 'Your Security account or community could not be verified. Contact your Community Admin.';
      case 'failed-precondition':
        return 'Your community may need to configure deletion-request routing, or your assignment has changed. Contact your Community Admin or Hominode Support at hominodecare@gmail.com.';
      case 'aborted':
        return 'Your request may still be processing. Wait a moment, then check again.';
      case 'not-found':
      case 'unimplemented':
        return 'Account deletion requests are temporarily unavailable. Contact Hominode Support at hominodecare@gmail.com.';
    }
  }
  return 'Your request could not be confirmed. Check your connection and try again. Any saved reference will be reused.';
}
