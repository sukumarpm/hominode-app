import 'package:flutter_test/flutter_test.dart';
import 'package:hominode_web/src/session/web_session.dart';
import 'package:hominode_web/src/session/web_session_resolver.dart';
import 'package:hominode_web/src/app.dart';

void main() {
  late FakeProfiles profiles;
  late FakeSelections selections;
  late WebSessionResolver resolver;

  setUp(() {
    profiles = FakeProfiles();
    selections = FakeSelections();
    resolver = WebSessionResolver(profiles, selections);
  });

  test('resolves active superAdmin in platform mode', () async {
    profiles.admins['super'] = admin('super', 'superAdmin', const []);
    final session = await resolver.resolve('super');
    expect(session.role, WebRole.superAdmin);
    expect(session.activeTenant, isNull);
  });

  test('ordinary admin auto-selects sole active authorized tenant', () async {
    profiles.admins['admin'] = admin('admin', 'admin', ['a']);
    profiles.tenants['a'] = tenant('A');
    final session = await resolver.resolve('admin');
    expect(session.role, WebRole.admin);
    expect(session.activeTenant?.communityId, 'a');
  });

  test(
    'multi-tenant admin requires selection and rejects unauthorized tenant',
    () async {
      profiles.admins['admin'] = admin('admin', 'admin', ['a', 'b']);
      profiles.tenants['a'] = tenant('A');
      profiles.tenants['b'] = tenant('B');
      final session = await resolver.resolve('admin');
      expect(session.needsTenantSelection, isTrue);
      await expectLater(
        resolver.selectAdminTenant(session, 'c'),
        throwsA(isA<SessionResolutionException>()),
      );
      final selected = await resolver.selectAdminTenant(session, 'b');
      expect(selected.activeTenant?.communityId, 'b');
    },
  );

  test('persisted unauthorized or inactive tenant is never restored', () async {
    profiles.admins['admin'] = admin('admin', 'admin', ['a', 'off']);
    profiles.tenants['a'] = tenant('A');
    profiles.tenants['off'] = tenant('Off', active: false);
    selections.values['admin'] = 'off';
    final session = await resolver.resolve('admin');
    expect(session.activeTenant?.communityId, 'a');
    expect(selections.values['admin'], 'a');
  });

  test('resident resolves only profile community and cannot switch', () async {
    profiles.residents['resident'] = {
      'uid': 'resident',
      'role': 'resident',
      'isActive': true,
      'approvalStatus': 'approved',
      'communityId': 'a',
    };
    profiles.tenants['a'] = tenant('A');
    final session = await resolver.resolve('resident');
    expect(session.role, WebRole.resident);
    expect(session.activeTenant?.communityId, 'a');
    await expectLater(
      resolver.selectAdminTenant(session, 'a'),
      throwsA(isA<SessionResolutionException>()),
    );
  });

  test('inactive profiles and inactive resident tenant fail closed', () async {
    profiles.admins['admin'] = {
      ...admin('admin', 'admin', ['a']),
      'isActive': false,
    };
    await expectLater(
      resolver.resolve('admin'),
      throwsA(isA<SessionResolutionException>()),
    );
    profiles.admins.clear();
    profiles.residents['resident'] = {
      'uid': 'resident',
      'role': 'resident',
      'isActive': true,
      'approvalStatus': 'approved',
      'communityId': 'off',
    };
    profiles.tenants['off'] = tenant('Off', active: false);
    await expectLater(
      resolver.resolve('resident'),
      throwsA(isA<SessionResolutionException>()),
    );
  });

  test(
    'direct role routes are reduced to the authenticated canonical path',
    () {
      const adminSession = WebSession(uid: 'admin', role: WebRole.admin);
      const superSession = WebSession(uid: 'super', role: WebRole.superAdmin);
      expect(
        WebAuthGuardStatePolicy.guardedPath('/super-admin', adminSession),
        '/admin',
      );
      expect(
        WebAuthGuardStatePolicy.guardedPath('/resident', superSession),
        '/super-admin',
      );
      expect(
        WebAuthGuardStatePolicy.guardedPath(
          '/super-admin/communities',
          superSession,
        ),
        '/super-admin/communities',
      );
    },
  );
}

Map<String, dynamic> admin(String uid, String role, List<String> ids) => {
  'uid': uid,
  'phoneNumber': '+15550000000',
  'role': role,
  'isActive': true,
  'authorizedCommunityIds': ids,
};
Map<String, dynamic> tenant(String name, {bool active = true}) => {
  'name': name,
  'isActive': active,
};

class FakeProfiles implements WebProfileStore {
  final admins = <String, Map<String, dynamic>>{};
  final residents = <String, Map<String, dynamic>>{};
  final tenants = <String, Map<String, dynamic>>{};
  @override
  Future<Map<String, dynamic>?> admin(String uid) async => admins[uid];
  @override
  Future<Map<String, dynamic>?> resident(String uid) async => residents[uid];
  @override
  Future<Map<String, dynamic>?> tenant(String id) async => tenants[id];
}

class FakeSelections implements TenantSelectionStore {
  final values = <String, String>{};
  @override
  Future<void> clear(String uid) async => values.remove(uid);
  @override
  Future<String?> read(String uid) async => values[uid];
  @override
  Future<void> write(String uid, String communityId) async =>
      values[uid] = communityId;
}
