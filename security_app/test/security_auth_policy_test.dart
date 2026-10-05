import 'package:flutter_test/flutter_test.dart';
import 'package:security_app/models/security_user_model.dart';
import 'package:security_app/services/auth_service.dart';

void main() {
  test('operational Security sessions require current Phone Auth token', () {
    expect(
      AuthService.hasVerifiedPhoneAuth(
        phoneNumber: '+639171234567',
        signInProvider: 'phone',
      ),
      isTrue,
    );
    expect(
      AuthService.hasVerifiedPhoneAuth(
        phoneNumber: '+639171234567',
        signInProvider: 'password',
      ),
      isFalse,
    );
    expect(
      AuthService.hasVerifiedPhoneAuth(
        phoneNumber: null,
        signInProvider: 'phone',
      ),
      isFalse,
    );
    for (final provider in ['custom', 'anonymous']) {
      expect(
        AuthService.hasVerifiedPhoneAuth(
          phoneNumber: '+639171234567',
          signInProvider: provider,
        ),
        isFalse,
      );
    }
  });

  test('Security profile must bind UID and verified phone', () {
    const profile = SecurityUserModel(
      uid: 'security-1',
      communityId: 'community-a',
      role: 'security',
      isActive: true,
      name: 'Guard',
      phoneNumber: '+639171234567',
    );
    expect(profile.isValidSecurityProfile, isTrue);
    expect(
      profile.matchesVerifiedPhone(
        expectedUid: 'security-1',
        phone: '+639171234567',
      ),
      isTrue,
    );
    expect(
      profile.matchesVerifiedPhone(
        expectedUid: 'security-1',
        phone: '+639179999999',
      ),
      isFalse,
    );
    expect(
      profile.matchesVerifiedPhone(
        expectedUid: 'another-uid',
        phone: '+639171234567',
      ),
      isFalse,
    );
    expect(
      const SecurityUserModel(
        uid: 'security-1',
        communityId: 'community-a',
        role: 'security',
        isActive: true,
        name: 'Guard',
        phoneNumber: '',
      ).isValidSecurityProfile,
      isFalse,
    );
  });
}
