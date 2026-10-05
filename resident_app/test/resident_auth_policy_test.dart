import 'package:flutter_test/flutter_test.dart';
import 'package:resident_app/src/models/tenant_profile.dart';
import 'package:resident_app/src/services/firebase_auth_service.dart';
import 'package:resident_app/src/services/flat_access_control_service.dart';

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
        contains('not active'),
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
        contains('not registered as a Resident'),
      );
    });

    test('requires the current ID token to come from Phone Auth', () {
      expect(
        FirebaseAuthService.hasVerifiedPhoneAuth(
          phoneNumber: '+639171234567',
          signInProvider: 'phone',
        ),
        isTrue,
      );
      expect(
        FirebaseAuthService.hasVerifiedPhoneAuth(
          phoneNumber: '+639171234567',
          signInProvider: 'password',
        ),
        isFalse,
      );
      expect(
        FirebaseAuthService.hasVerifiedPhoneAuth(
          phoneNumber: '+639171234567',
          signInProvider: 'custom',
        ),
        isFalse,
      );
      expect(
        FirebaseAuthService.hasVerifiedPhoneAuth(
          phoneNumber: '+639171234567',
          signInProvider: 'anonymous',
        ),
        isFalse,
      );
      expect(
        FirebaseAuthService.hasVerifiedPhoneAuth(
          phoneNumber: null,
          signInProvider: 'phone',
        ),
        isFalse,
      );
    });

    test('binds resident document identity and phone to verified auth', () {
      final canonical = TenantProfile(
        userId: 'uid-1',
        phoneNumber: '+639171234567',
        communityId: 'community-a',
        role: 'resident',
        isActive: true,
      );
      expect(
        FirebaseAuthService.validateResidentIdentity(
          canonical,
          uid: 'uid-1',
          phone: '+639171234567',
        ),
        isNull,
      );
      expect(
        FirebaseAuthService.validateResidentIdentity(
          canonical,
          uid: 'different-uid',
          phone: '+639171234567',
        ),
        isNotNull,
      );
      expect(
        FirebaseAuthService.validateResidentIdentity(
          canonical,
          uid: 'uid-1',
          phone: '+639179999999',
        ),
        isNotNull,
      );
    });
  });

  group('approved resident flat assignment', () {
    test('only a missing flat is a flat-assignment denial', () {
      final result = FlatAccessControlService.evaluateApprovedProfile({
        'role': 'resident',
        'approvalStatus': 'approved',
        'isActive': true,
        'status': 'active',
        'occupancyStatus': 'current',
        'buildingId': 'building-a',
      });
      expect(result.state, FlatAccessState.denied);
      expect(result.message, contains('not yet assigned to a flat'));
    });

    test('a non-empty flat grants access', () {
      final result = FlatAccessControlService.evaluateApprovedProfile({
        'role': 'resident',
        'approvalStatus': 'approved',
        'isActive': true,
        'status': 'active',
        'occupancyStatus': 'current',
        'flatId': ' flat-a ',
        'buildingId': 'building-a',
      });
      expect(result.state, FlatAccessState.granted);
      expect(result.flatId, 'flat-a');
    });

    test(
      'live lifecycle changes revoke access without authentication changes',
      () {
        for (final profile in [
          {
            'role': 'resident',
            'approvalStatus': 'pending',
            'isActive': false,
            'status': 'inactive',
            'occupancyStatus': 'suspended',
            'flatId': 'flat-a',
            'buildingId': 'building-a',
          },
          {
            'role': 'resident',
            'approvalStatus': 'approved',
            'isActive': false,
            'status': 'inactive',
            'occupancyStatus': 'suspended',
            'flatId': 'flat-a',
            'buildingId': 'building-a',
          },
          {
            'role': 'resident',
            'approvalStatus': 'approved',
            'isActive': true,
            'status': 'active',
            'occupancyStatus': 'moved_out',
            'flatId': null,
            'buildingId': null,
          },
        ]) {
          expect(
            FlatAccessControlService.evaluateApprovedProfile(profile).state,
            FlatAccessState.denied,
          );
        }
      },
    );
  });
}
