import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:security_app/models/security_user_model.dart';
import 'package:security_app/services/auth_service.dart';

void main() {
  test('offline profile lookup can retry without signing out', () async {
    final user = _FakeUser(uid: 'security-a');
    final auth = _FakeFirebaseAuth(user);
    var profileReads = 0;
    final store = _FakeProfileStore(
      getProfile: (uid) async {
        profileReads++;
        if (profileReads == 1) {
          throw FirebaseException(
            plugin: 'cloud_firestore',
            code: 'unavailable',
          );
        }
        return _activeProfile(uid, user.phoneNumber!);
      },
      getCommunityStatus: (_) async => true,
    );
    final service = _service(auth, store);

    await expectLater(
      service.requireSecurityProfile(),
      throwsA(isA<FirebaseException>()),
    );
    expect(auth.signOutCalls, 0);
    expect(auth.currentUser, same(user));

    final profile = await service.requireSecurityProfile();
    expect(profile.uid, user.uid);
    expect(auth.signOutCalls, 0);
    expect(auth.currentUser, same(user));
  });

  test('disabled account remains denied and is signed out', () async {
    final user = _FakeUser(uid: 'security-a');
    final auth = _FakeFirebaseAuth(user);
    final store = _FakeProfileStore(
      getProfile: (uid) async => SecurityUserModel(
        uid: uid,
        communityId: 'community-a',
        role: 'security',
        isActive: false,
        name: 'Guard',
        phoneNumber: user.phoneNumber!,
      ),
      getCommunityStatus: (_) async => true,
    );
    final service = _service(auth, store);

    await expectLater(
      service.requireSecurityProfile(),
      throwsA(
        isA<SecurityAuthException>().having(
          (error) => error.code,
          'code',
          'account-disabled',
        ),
      ),
    );
    expect(auth.signOutCalls, 1);
    expect(auth.currentUser, isNull);
  });

  test('stale profile denial cannot sign out a newer account', () async {
    final userA = _FakeUser(uid: 'security-a');
    final userB = _FakeUser(uid: 'security-b');
    final auth = _FakeFirebaseAuth(userA);
    final profileRead = Completer<SecurityUserModel?>();
    final store = _FakeProfileStore(
      getProfile: (_) => profileRead.future,
      getCommunityStatus: (_) async => true,
    );
    final service = _service(auth, store);
    var profileGeneration = 1;
    final oldCheck = service.requireSecurityProfile(
      isSessionCurrent: () =>
          profileGeneration == 1 && auth.currentUser?.uid == userA.uid,
    );

    auth.current = userB;
    profileGeneration++;
    profileRead.complete(
      SecurityUserModel(
        uid: userA.uid,
        communityId: 'community-a',
        role: 'security',
        isActive: false,
        name: 'Guard',
        phoneNumber: userA.phoneNumber!,
      ),
    );

    await expectLater(oldCheck, throwsA(isA<SecurityAuthException>()));
    expect(auth.currentUser, same(userB));
    expect(auth.signOutCalls, 0);
  });
}

AuthService _service(_FakeFirebaseAuth auth, _FakeProfileStore store) =>
    AuthService(
      auth: auth,
      profileStore: store,
      deactivateNotifications: () async {},
    );

SecurityUserModel _activeProfile(String uid, String phone) => SecurityUserModel(
  uid: uid,
  communityId: 'community-a',
  role: 'security',
  isActive: true,
  name: 'Guard',
  phoneNumber: phone,
);

class _FakeFirebaseAuth extends Fake implements FirebaseAuth {
  _FakeFirebaseAuth(this.current);

  User? current;
  int signOutCalls = 0;

  @override
  User? get currentUser => current;

  @override
  Future<void> signOut() async {
    signOutCalls++;
    current = null;
  }
}

class _FakeUser extends Fake implements User {
  _FakeUser({required this.uid});

  @override
  final String uid;

  @override
  String? get phoneNumber => '+639171234567';

  @override
  Future<IdTokenResult> getIdTokenResult([bool forceRefresh = false]) async =>
      _FakeIdTokenResult();
}

class _FakeIdTokenResult extends Fake implements IdTokenResult {
  @override
  String? get signInProvider => PhoneAuthProvider.PROVIDER_ID;
}

typedef _GetProfile = Future<SecurityUserModel?> Function(String uid);
typedef _GetCommunityStatus = Future<bool?> Function(String communityId);

class _FakeProfileStore implements SecurityProfileStore {
  const _FakeProfileStore({
    required this.getProfile,
    required this.getCommunityStatus,
  });

  final _GetProfile getProfile;
  final _GetCommunityStatus getCommunityStatus;

  @override
  Future<SecurityUserModel?> getSecurityProfile(String uid) => getProfile(uid);

  @override
  Future<bool?> isCommunityActive(String communityId) =>
      getCommunityStatus(communityId);
}
