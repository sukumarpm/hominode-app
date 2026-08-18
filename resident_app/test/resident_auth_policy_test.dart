import 'package:flutter_test/flutter_test.dart';
import 'package:resident_app/src/models/tenant_profile.dart';
import 'package:resident_app/src/services/firebase_auth_service.dart';

void main() {
  group('resident authorization after OTP', () {
    TenantProfile profile({
      String communityId = 'community-a',
      String role = 'resident',
      bool isActive = true,
    }) => TenantProfile(
      userId: 'uid-1',
      communityId: communityId,
      role: role,
      isActive: isActive,
    );

    test('accepts only an active resident with a community', () {
      expect(FirebaseAuthService.validateResidentProfile(profile()), isNull);
    });

    test('rejects inactive resident', () {
      expect(
        FirebaseAuthService.validateResidentProfile(profile(isActive: false)),
        contains('inactive'),
      );
    });

    test('rejects missing community', () {
      expect(
        FirebaseAuthService.validateResidentProfile(profile(communityId: '')),
        contains('not assigned'),
      );
    });

    test('rejects non-resident role', () {
      expect(
        FirebaseAuthService.validateResidentProfile(profile(role: 'admin')),
        contains('resident accounts only'),
      );
    });
  });
}
