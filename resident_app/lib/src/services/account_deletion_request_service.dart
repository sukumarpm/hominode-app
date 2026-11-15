import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

abstract interface class AccountDeletionRequests {
  Future<Map<String, dynamic>?> status();
  Future<Map<String, dynamic>> submit();
  Future<bool> requiresReauthentication();
  Future<void> beginReauthentication(
    void Function(String) onCodeSent,
    void Function(String) onError,
  );
  Future<void> completeReauthentication(String verificationId, String code);
}

class AccountDeletionRequestService implements AccountDeletionRequests {
  AccountDeletionRequestService({
    FirebaseFunctions? functions,
    FirebaseAuth? auth,
  }) : _functions =
           functions ??
           FirebaseFunctions.instanceFor(region: 'asia-southeast1'),
       _auth = auth ?? FirebaseAuth.instance;
  final FirebaseFunctions _functions;
  final FirebaseAuth _auth;

  @override
  Future<Map<String, dynamic>?> status() async {
    final result = await _functions
        .httpsCallable('getAccountDeletionRequestStatus')
        .call();
    final data = Map<String, dynamic>.from(result.data as Map);
    final request = data['request'];
    return request is Map ? Map<String, dynamic>.from(request) : null;
  }

  @override
  Future<Map<String, dynamic>> submit() async {
    final result = await _functions
        .httpsCallable(
          'submitAccountDeletionRequest',
          options: HttpsCallableOptions(timeout: const Duration(minutes: 10)),
        )
        .call({'sourceApp': 'resident'});
    return Map<String, dynamic>.from(result.data as Map);
  }

  @override
  Future<bool> requiresReauthentication() async {
    final user = _auth.currentUser;
    final time = (await user?.getIdTokenResult())?.authTime;
    return time == null || DateTime.now().difference(time).inSeconds > 300;
  }

  @override
  Future<void> beginReauthentication(
    void Function(String) onCodeSent,
    void Function(String) onError,
  ) async {
    final phone = _auth.currentUser?.phoneNumber;
    if (phone == null || phone.isEmpty) {
      throw StateError('A verified phone session is required.');
    }
    await _auth.verifyPhoneNumber(
      phoneNumber: phone,
      verificationCompleted: (_) {},
      verificationFailed: (error) =>
          onError(error.message ?? 'Could not send OTP.'),
      codeSent: (id, _) => onCodeSent(id),
      // A timeout ends automatic code retrieval; it is not a new OTP session.
      codeAutoRetrievalTimeout: (_) {},
    );
  }

  @override
  Future<void> completeReauthentication(
    String verificationId,
    String code,
  ) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('Sign in before continuing.');
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: code,
    );
    await user.reauthenticateWithCredential(credential);
    // The next callable must receive the new auth_time, not a cached ID token.
    await user.getIdToken(true);
  }
}
