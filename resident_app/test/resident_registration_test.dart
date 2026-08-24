import 'package:flutter_test/flutter_test.dart';
import 'package:resident_app/src/models/resident_registration_model.dart';
import 'package:resident_app/src/services/firebase_auth_service.dart';
import 'package:resident_app/src/services/resident_auth_routing.dart';
import 'package:resident_app/src/services/resident_registration_service.dart';

void main() {
  test('normalizes invite codes without enabling collection browsing', () {
    expect(
      ResidentRegistrationService.normalizeInviteCode('  home-2026 '),
      'HOME-2026',
    );
    expect(
      ResidentRegistrationService.normalizeInviteCode(' Society 42! '),
      'SOCIETY42',
    );
  });

  test('registration payload is pending, inactive, resident-only', () {
    const registration = ResidentRegistrationModel(
      uid: 'uid-1',
      phoneNumber: '+919876543210',
      name: 'Resident Name',
      communityId: 'community-a',
      communityInviteCode: 'HOME-2026',
      buildingReference: 'Tower A',
      unitReference: 'A-101',
    );
    final data = registration.toFirestore();
    expect(data['role'], 'resident');
    expect(data['isActive'], isFalse);
    expect(data['approvalStatus'], 'pending');
    expect(data['communityId'], 'community-a');
    expect(data.containsKey('password'), isFalse);
  });

  test(
    'trusted callable payload excludes identity and authorization fields',
    () {
      const registration = ResidentRegistrationModel(
        uid: 'client-supplied-uid-is-not-sent',
        phoneNumber: '+919876543210',
        name: ' Resident Name ',
        communityId: 'client-community-is-not-sent',
        communityInviteCode: 'HOME-2026',
        buildingReference: ' Tower A ',
        unitReference: ' A-101 ',
      );
      final payload = ResidentRegistrationService.callablePayload(registration);
      expect(payload, {
        'inviteCode': 'HOME-2026',
        'fullName': 'Resident Name',
        'email': null,
        'buildingReference': 'Tower A',
        'unitReference': 'A-101',
      });
      expect(payload.containsKey('uid'), isFalse);
      expect(payload.containsKey('phoneNumber'), isFalse);
      expect(payload.containsKey('communityId'), isFalse);
      expect(payload.containsKey('role'), isFalse);
      expect(payload.containsKey('approvalStatus'), isFalse);
    },
  );

  test('post-OTP states map to deterministic routes', () {
    AuthResult result(ResidentAuthState state) =>
        AuthResult(success: true, state: state);

    expect(
      ResidentAuthRouting.routeFor(
        result(ResidentAuthState.registrationRequired),
      ),
      '/resident-registration',
    );
    expect(
      ResidentAuthRouting.routeFor(result(ResidentAuthState.pendingApproval)),
      '/awaiting-approval',
    );
    expect(
      ResidentAuthRouting.routeFor(result(ResidentAuthState.approved)),
      '/home',
    );
    expect(
      ResidentAuthRouting.routeFor(result(ResidentAuthState.rejected)),
      '/resident-access-blocked',
    );
    expect(
      ResidentAuthRouting.routeFor(
        result(ResidentAuthState.flatAssignmentRequired),
      ),
      '/resident-access-blocked',
    );
    expect(
      ResidentAuthRouting.routeFor(
        AuthResult.failure(message: 'Not authenticated'),
      ),
      '/login',
    );
  });
}
