import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:admin_app/services/auth_service.dart';

void main() {
  test('admin operational sessions require current Phone Auth token', () {
    expect(
      AuthService.hasVerifiedPhoneAuth(
        phoneNumber: '+639171234567',
        signInProvider: PhoneAuthProvider.PROVIDER_ID,
      ),
      isTrue,
    );
    for (final provider in ['password', 'custom', 'anonymous', null]) {
      expect(
        AuthService.hasVerifiedPhoneAuth(
          phoneNumber: '+639171234567',
          signInProvider: provider,
        ),
        isFalse,
      );
    }
    expect(
      AuthService.hasVerifiedPhoneAuth(
        phoneNumber: '  ',
        signInProvider: PhoneAuthProvider.PROVIDER_ID,
      ),
      isFalse,
    );
  });
}
