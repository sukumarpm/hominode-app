import 'package:admin_app/models/admin_profile.dart';
import 'package:admin_app/models/tenant_config.dart';
import 'package:admin_app/services/admin_tenant_context.dart';
import 'package:admin_app/services/tenant_registry_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses a complete TenantConfig', () {
    final createdAt = DateTime.utc(2026, 1, 2);
    final tenant = TenantConfig.fromMap('GV-1', {
      'name': 'Green Valley',
      'slug': 'green-valley',
      'websitePath': 'communities/green-valley',
      'databaseId': 'green-valley-db',
      'isActive': true,
      'logoUrl': 'https://example.com/logo.png',
      'brandName': 'Green Valley Living',
      'primaryColor': '#123456',
      'countryCode': 'ph',
      'createdBy': 'super-1',
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(createdAt),
    });

    expect(tenant.communityId, 'GV-1');
    expect(tenant.name, 'Green Valley');
    expect(tenant.slug, 'green-valley');
    expect(tenant.websitePath, 'communities/green-valley');
    expect(tenant.databaseId, 'green-valley-db');
    expect(tenant.brandName, 'Green Valley Living');
    expect(tenant.countryCode, 'PH');
    expect(
      tenant.createdAt?.millisecondsSinceEpoch,
      createdAt.millisecondsSinceEpoch,
    );
  });

  test('legacy documents receive in-memory safe defaults', () {
    final tenant = TenantConfig.fromMap('LEGACY', {
      'name': 'Green Valley',
      'isActive': true,
      'createdBy': 'admin-1',
    });

    expect(tenant.slug, 'green-valley');
    expect(tenant.websitePath, 'green-valley');
    expect(tenant.databaseId, TenantConfig.defaultDatabaseId);
    expect(tenant.brandName, 'Green Valley');
    expect(tenant.logoUrl, isNull);
    expect(tenant.primaryColor, isNull);
  });

  test(
    'fresh community location parses address, radius, place and timestamp',
    () {
      final locationUpdatedAt = DateTime.utc(2026, 8, 24, 10);
      final tenant = TenantConfig.fromMap('GV-1', {
        'name': 'Green Valley',
        'isActive': true,
        'locationConfigured': true,
        'location': {
          'latitude': 14.5995,
          'longitude': 120.9842,
          'formattedAddress': 'Green Valley, Manila',
          'placeId': 'place-green-valley',
          'attendanceRadiusMeters': 200,
          'updatedAt': Timestamp.fromDate(locationUpdatedAt),
        },
      });

      expect(tenant.locationConfigured, isTrue);
      expect(tenant.location?.formattedAddress, 'Green Valley, Manila');
      expect(tenant.location?.attendanceRadiusMeters, 200);
      expect(tenant.location?.placeId, 'place-green-valley');
      expect(
        tenant.location?.updatedAt?.millisecondsSinceEpoch,
        locationUpdatedAt.millisecondsSinceEpoch,
      );
    },
  );

  test('empty or incomplete location maps never become zero coordinates', () {
    for (final location in <Map<String, dynamic>>[
      {},
      {
        'formattedAddress': 'Missing coordinates',
        'attendanceRadiusMeters': 150,
      },
      {
        'latitude': 0,
        'longitude': 0,
        'formattedAddress': '',
        'attendanceRadiusMeters': 150,
      },
    ]) {
      final tenant = TenantConfig.fromMap('LEGACY', {
        'name': 'Legacy',
        'isActive': true,
        'locationConfigured': true,
        'location': location,
      });
      expect(tenant.locationConfigured, isFalse);
      expect(tenant.location, isNull);
    }
  });

  test('malformed or inactive tenant fails active-state validation', () {
    final tenant = TenantConfig.fromMap('INACTIVE', {
      'name': 'Inactive',
      'isActive': 'true',
    });
    expect(tenant.isActive, isFalse);
    expect(
      () => TenantRegistryService.validateActiveState(tenant),
      throwsA(isA<InactiveTenantException>()),
    );
  });

  test('slug lookup uses centralized normalization and legacy values', () {
    final tenant = TenantConfig.fromMap('GV-1', {
      'name': 'Green Valley',
      'isActive': true,
    });
    expect(
      TenantRegistryService.findTenantBySlug([tenant], ' Green Valley '),
      same(tenant),
    );
  });

  test(
    'create form payload applies tenant defaults and slug normalization',
    () {
      final payload = TenantRegistryService.mutationPayload({
        'name': ' Green Valley ',
        'slug': 'Green Valley',
        'websitePath': '',
        'databaseId': '',
        'brandName': '',
      });
      expect(payload['slug'], 'green-valley');
      expect(payload['websitePath'], 'green-valley');
      expect(payload['databaseId'], TenantConfig.defaultDatabaseId);
      expect(payload['brandName'], 'Green Valley');
    },
  );

  test('create form rejects an empty normalized slug', () {
    expect(
      () => TenantRegistryService.mutationPayload({
        'name': 'Valid name',
        'slug': '---',
      }),
      throwsArgumentError,
    );
  });

  test('ordinary Admin selected-community ID flow remains compatible', () {
    final context = AdminTenantContext.instance;
    addTearDown(context.clear);
    context.initialize(
      const AdminProfile(
        uid: 'admin-1',
        phoneNumber: '+15550000001',
        role: 'admin',
        isActive: true,
        authorizedCommunityIds: ['GV-1'],
      ),
    );
    final tenant = TenantConfig.fromMap('GV-1', {
      'name': 'Green Valley',
      'isActive': true,
    });
    context.activateTenant(tenant);

    expect(context.requireCommunityId(), 'GV-1');
    expect(context.communityId, 'GV-1');
    expect(context.name, 'Green Valley');
    expect(context.databaseId, TenantConfig.defaultDatabaseId);
  });
}
