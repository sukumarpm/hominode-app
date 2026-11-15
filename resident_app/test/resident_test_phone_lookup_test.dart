import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:resident_app/src/models/tenant_profile.dart';
import 'package:resident_app/src/services/firebase_auth_service.dart';
import 'package:resident_app/src/services/tenant_resolution_service.dart';

class _PhoneUser extends Fake implements User {
  @override
  String get uid => 'test-phone-uid';
  @override
  String get phoneNumber => '+639400000000';
}

class _Auth extends Fake implements FirebaseAuth {
  @override
  User get currentUser => _PhoneUser();
}

class _Store extends Fake implements FirebaseFirestore {
  Map<String, dynamic>? profile;
  final reads = <String>[];
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) {
    expect(path, 'users');
    return _Users(this);
  }
}

// Test-only Firestore doubles keep this lookup check local and read-only.
// ignore: subtype_of_sealed_class
class _Users extends Fake implements CollectionReference<Map<String, dynamic>> {
  _Users(this.store);
  final _Store store;
  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) {
    store.reads.add('users/$path');
    return _Profile(store);
  }
}

// ignore: subtype_of_sealed_class
class _Profile extends Fake implements DocumentReference<Map<String, dynamic>> {
  _Profile(this.store);
  final _Store store;
  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([
    GetOptions? options,
  ]) async => _Snapshot(store.profile);
}

// ignore: subtype_of_sealed_class
class _Snapshot extends Fake implements DocumentSnapshot<Map<String, dynamic>> {
  _Snapshot(this.value);
  final Map<String, dynamic>? value;
  @override
  Map<String, dynamic>? data() => value;
}

void main() {
  const uid = 'test-phone-uid';
  const phone = '+639400000000';
  Map<String, dynamic> resident({
    String approval = 'approved',
    bool active = true,
  }) => {
    'uid': uid,
    'phoneNumber': phone,
    'communityId': 'community-a',
    'role': 'resident',
    'approvalStatus': approval,
    'isActive': active,
    'residentType': 'owner',
    'identityVerificationStatus': 'not_required',
    'phoneVerified': false,
    'creationSource': 'admin_direct',
  };

  test(
    'authenticated test phone reads only the canonical UID document',
    () async {
      final store = _Store()..profile = resident();
      final resolver = TenantResolutionService(auth: _Auth(), firestore: store);
      final profile = await resolver.loadAuthenticatedProfile();
      expect(profile?.userId, uid);
      expect(profile?.phoneNumber, phone);
      expect(profile?.communityId, 'community-a');
      expect(store.reads, ['users/$uid']);
      store.profile = resident(approval: 'pending', active: false);
      expect(
        (await resolver.loadAuthenticatedProfile())?.approvalStatus,
        'pending',
      );
      store.profile = null;
      expect(await resolver.loadAuthenticatedProfile(), isNull);
      expect(store.reads, everyElement('users/$uid'));
      resolver.dispose();
    },
  );

  test(
    'Admin-created test phone profile matches only its verified phone UID',
    () {
      final profile = TenantProfile.fromMap(uid, resident());
      expect(
        FirebaseAuthService.hasVerifiedPhoneAuth(
          phoneNumber: phone,
          signInProvider: 'phone',
        ),
        isTrue,
      );
      expect(
        FirebaseAuthService.validateResidentIdentity(
          profile,
          uid: uid,
          phone: phone,
        ),
        isNull,
      );
      expect(
        TenantResolutionService.requireApprovedResident(
          uid,
          resident(),
        ).communityId,
        'community-a',
      );
      expect(
        FirebaseAuthService.validateResidentIdentity(
          profile,
          uid: 'another-uid',
          phone: phone,
        ),
        isNotNull,
      );
      expect(
        FirebaseAuthService.validateResidentIdentity(
          profile,
          uid: uid,
          phone: '+639400000001',
        ),
        isNotNull,
      );
      expect(
        FirebaseAuthService.hasVerifiedPhoneAuth(
          phoneNumber: phone,
          signInProvider: 'password',
        ),
        isFalse,
      );
      expect(
        FirebaseAuthService.hasVerifiedPhoneAuth(
          phoneNumber: phone,
          signInProvider: 'custom',
        ),
        isFalse,
      );
    },
  );

  test(
    'test phone metadata exception does not bypass pending or inactive status',
    () {
      for (final data in [
        resident(approval: 'pending', active: false),
        resident(active: false),
      ]) {
        expect(
          FirebaseAuthService.validateResidentIdentity(
            TenantProfile.fromMap(uid, data),
            uid: uid,
            phone: phone,
          ),
          isNull,
        );
        expect(
          () => TenantResolutionService.requireApprovedResident(uid, data),
          throwsA(
            isA<TenantResolutionException>().having(
              (error) => error.reason,
              'reason',
              data['approvalStatus'] == 'pending'
                  ? TenantResolutionFailure.profileNotApproved
                  : TenantResolutionFailure.profileInactive,
            ),
          ),
        );
      }
    },
  );
}
