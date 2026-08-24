import 'package:admin_app/models/admin_profile.dart';
import 'package:admin_app/models/tenant_config.dart';
import 'package:admin_app/services/admin_tenant_context.dart';
import 'package:admin_app/services/admin_tenant_session.dart';
import 'package:flutter_test/flutter_test.dart';

class MemoryTenantStore implements ActiveTenantStore {
  final values = <String, String>{};
  @override
  Future<String?> read(String adminUid) async => values[adminUid];
  @override
  Future<void> remove(String adminUid) async => values.remove(adminUid);
  @override
  Future<void> write(String adminUid, String communityId) async =>
      values[adminUid] = communityId;
}

TenantConfig tenant(String id, {bool active = true}) => TenantConfig.fromMap(
  id,
  {'name': 'Tenant $id', 'slug': id.toLowerCase(), 'isActive': active},
);
AdminProfile profile(List<String> ids) => AdminProfile(
  uid: 'admin-1',
  phoneNumber: '+15550000001',
  role: 'admin',
  isActive: true,
  authorizedCommunityIds: ids,
);

void main() {
  final context = AdminTenantContext.instance;
  tearDown(context.clear);

  AdminTenantSession session(
    MemoryTenantStore store,
    Map<String, TenantConfig> tenants,
  ) => AdminTenantSession(
    store: store,
    context: context,
    tenantLoader: (id) async {
      final value = tenants[id];
      if (value == null) throw StateError('missing');
      return value;
    },
  );

  test('single valid community auto-selects and persists', () async {
    final store = MemoryTenantStore();
    expect(
      await session(store, {'A': tenant('A')}).resolve(profile(['A'])),
      AdminTenantResolution.selected,
    );
    expect(context.requireCommunityId(), 'A');
    expect(store.values['admin-1'], 'A');
  });

  test('multiple valid communities require selection', () async {
    final result = await session(MemoryTenantStore(), {
      'A': tenant('A'),
      'B': tenant('B'),
    }).resolve(profile(['A', 'B']));
    expect(result, AdminTenantResolution.selectionRequired);
    expect(context.hasSelectedCommunity, isFalse);
    expect(context.authorizedTenants, hasLength(2));
  });

  test('valid persisted selection restores', () async {
    final store = MemoryTenantStore()..values['admin-1'] = 'B';
    expect(
      await session(store, {
        'A': tenant('A'),
        'B': tenant('B'),
      }).resolve(profile(['A', 'B'])),
      AdminTenantResolution.selected,
    );
    expect(context.requireTenant().communityId, 'B');
  });

  test('persisted unauthorized selection is rejected', () async {
    final store = MemoryTenantStore()..values['admin-1'] = 'X';
    expect(
      await session(store, {
        'A': tenant('A'),
        'B': tenant('B'),
      }).resolve(profile(['A', 'B'])),
      AdminTenantResolution.selectionRequired,
    );
    expect(store.values.containsKey('admin-1'), isFalse);
  });

  test(
    'persisted inactive tenant is rejected and sole active tenant wins',
    () async {
      final store = MemoryTenantStore()..values['admin-1'] = 'B';
      expect(
        await session(store, {
          'A': tenant('A'),
          'B': tenant('B', active: false),
        }).resolve(profile(['A', 'B'])),
        AdminTenantResolution.selected,
      );
      expect(context.requireCommunityId(), 'A');
    },
  );

  test('switch updates context and replaces old tenant state', () async {
    final store = MemoryTenantStore();
    final resolver = session(store, {'A': tenant('A'), 'B': tenant('B')});
    await resolver.resolve(profile(['A', 'B']));
    await resolver.selectTenant(tenant('A'));
    await resolver.selectTenant(tenant('B'));
    expect(context.requireTenant().communityId, 'B');
    expect(context.name, 'Tenant B');
    expect(store.values['admin-1'], 'B');
  });

  test('unauthorized tenant cannot be selected', () async {
    final resolver = session(MemoryTenantStore(), {'A': tenant('A')});
    await resolver.resolve(profile(['A']));
    expect(() => context.selectTenant(tenant('X')), throwsStateError);
  });

  test('zero valid communities fails closed', () async {
    expect(
      await session(MemoryTenantStore(), {
        'A': tenant('A', active: false),
      }).resolve(profile(['A', 'MISSING'])),
      AdminTenantResolution.noValidTenants,
    );
    expect(context.requireTenant, throwsStateError);
  });
}
