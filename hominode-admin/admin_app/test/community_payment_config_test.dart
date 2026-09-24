import 'package:admin_app/models/admin_profile.dart';
import 'package:admin_app/models/community_payment_config.dart';
import 'package:admin_app/services/admin_tenant_context.dart';
import 'package:admin_app/services/community_payment_config_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

const _communityId = 'COMMUNITY_A';
final _updatedAt = Timestamp.fromMillisecondsSinceEpoch(1780000000000);

Map<String, dynamic> _configData({
  Map<String, dynamic>? directUpi,
  String communityId = _communityId,
}) => {
  'communityId': communityId,
  'version': 1,
  'directUpi':
      directUpi ??
      {
        'enabled': true,
        'vpa': 'association@upi-bank',
        'payeeName': 'Community Association',
      },
  'updatedBy': 'admin-a',
  'updatedAt': _updatedAt,
};

void _selectCommunity(String communityId) {
  AdminTenantContext.instance.initialize(
    AdminProfile(
      uid: 'admin-a',
      phoneNumber: '+15550000001',
      role: 'admin',
      isActive: true,
      authorizedCommunityIds: [communityId],
    ),
  );
}

void main() {
  tearDown(AdminTenantContext.instance.clear);

  test('parses enabled Direct UPI configuration and metadata', () {
    final config = CommunityPaymentConfig.fromMap(
      _communityId,
      _configData(
        directUpi: {
          'enabled': true,
          'vpa': '  association@upi-bank  ',
          'payeeName': '  Community Association  ',
        },
      ),
    );

    expect(config.communityId, _communityId);
    expect(config.version, 1);
    expect(config.directUpi.enabled, isTrue);
    expect(config.directUpi.isUsable, isTrue);
    expect(config.directUpi.vpa, 'association@upi-bank');
    expect(config.directUpi.payeeName, 'Community Association');
    expect(config.updatedBy, 'admin-a');
    expect(config.updatedAt, _updatedAt.toDate());
  });

  test('disabled config exposes no stale VPA or payee name', () {
    final config = CommunityPaymentConfig.fromMap(
      _communityId,
      _configData(
        directUpi: {
          'enabled': false,
          'vpa': 'stale@upi',
          'payeeName': 'Stale Name',
        },
      ),
    );

    expect(config.directUpi.enabled, isFalse);
    expect(config.directUpi.isUsable, isFalse);
    expect(config.directUpi.vpa, isNull);
    expect(config.directUpi.payeeName, isNull);
  });

  test('unconfigured factory is a safe disabled config', () {
    final config = CommunityPaymentConfig.unconfigured(_communityId);

    expect(config.communityId, _communityId);
    expect(config.version, 1);
    expect(config.directUpi.enabled, isFalse);
    expect(config.directUpi.vpa, isNull);
    expect(config.directUpi.payeeName, isNull);
    expect(config.updatedBy, isNull);
    expect(config.updatedAt, isNull);
  });

  test('malformed enabled config throws instead of becoming usable', () {
    for (final directUpi in <Map<String, dynamic>>[
      {'enabled': true, 'vpa': '', 'payeeName': 'Association'},
      {'enabled': true, 'vpa': 'not-a-vpa', 'payeeName': 'Association'},
      {'enabled': true, 'vpa': 'association@upi', 'payeeName': '  '},
      {'enabled': true, 'vpa': 123, 'payeeName': 'Association'},
      {'enabled': 'true', 'vpa': 'association@upi', 'payeeName': 'Association'},
    ]) {
      expect(
        () => CommunityPaymentConfig.fromMap(
          _communityId,
          _configData(directUpi: directUpi),
        ),
        throwsFormatException,
      );
    }
  });

  test(
    'missing selected-community document returns safe disabled config',
    () async {
      _selectCommunity(_communityId);
      final firestore = FakeFirebaseFirestore();
      final config = await CommunityPaymentConfigService(
        firestore: firestore,
      ).getSelectedCommunityPaymentConfig();

      expect(config.communityId, _communityId);
      expect(config.directUpi.enabled, isFalse);
      expect(config.directUpi.vpa, isNull);
    },
  );

  test('service reads one selected-community config document', () async {
    _selectCommunity(_communityId);
    final firestore = FakeFirebaseFirestore();
    await firestore
        .collection('communityPaymentConfigs')
        .doc(_communityId)
        .set(_configData());

    final config = await CommunityPaymentConfigService(
      firestore: firestore,
    ).getSelectedCommunityPaymentConfig();

    expect(config.communityId, _communityId);
    expect(config.directUpi.vpa, 'association@upi-bank');
    expect(
      (await firestore.collection('communityPaymentConfigs').get()).docs,
      hasLength(1),
    );
  });

  test(
    'enabled update payload trims fields and uses selected community ID',
    () {
      _selectCommunity(_communityId);
      final selectedCommunityId = AdminTenantContext.instance
          .requireCommunityId();
      final payload = CommunityPaymentConfigService.updatePayload(
        communityId: selectedCommunityId,
        enabled: true,
        vpa: '  association@upi-bank  ',
        payeeName: '  Community Association  ',
      );

      expect(payload, {
        'communityId': _communityId,
        'directUpi': {
          'enabled': true,
          'vpa': 'association@upi-bank',
          'payeeName': 'Community Association',
        },
      });
    },
  );

  test('disabled update payload omits destination fields even if passed', () {
    _selectCommunity(_communityId);
    final payload = CommunityPaymentConfigService.updatePayload(
      communityId: AdminTenantContext.instance.requireCommunityId(),
      enabled: false,
      vpa: 'stale@upi',
      payeeName: 'Stale Name',
    );

    expect(payload, {
      'communityId': _communityId,
      'directUpi': {'enabled': false},
    });
    expect((payload['directUpi'] as Map).containsKey('vpa'), isFalse);
    expect((payload['directUpi'] as Map).containsKey('payeeName'), isFalse);
  });

  test('successful update returns the freshly read server config', () async {
    _selectCommunity(_communityId);
    final firestore = FakeFirebaseFirestore();
    Map<String, dynamic>? sentPayload;
    final service = CommunityPaymentConfigService(
      firestore: firestore,
      updateCallable: (payload) async {
        sentPayload = payload;
        await firestore
            .collection('communityPaymentConfigs')
            .doc(_communityId)
            .set(
              _configData(
                directUpi: {
                  'enabled': true,
                  'vpa': 'server-authoritative@upi',
                  'payeeName': 'Server Association',
                },
              ),
            );
      },
    );

    final config = await service.updateDirectUpi(
      enabled: true,
      vpa: '  submitted@upi  ',
      payeeName: '  Submitted Association  ',
    );

    expect(sentPayload, {
      'communityId': _communityId,
      'directUpi': {
        'enabled': true,
        'vpa': 'submitted@upi',
        'payeeName': 'Submitted Association',
      },
    });
    expect(config.directUpi.vpa, 'server-authoritative@upi');
    expect(config.directUpi.payeeName, 'Server Association');
  });
}
