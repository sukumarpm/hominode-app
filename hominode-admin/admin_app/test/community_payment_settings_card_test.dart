import 'package:admin_app/models/admin_profile.dart';
import 'package:admin_app/services/admin_tenant_context.dart';
import 'package:admin_app/services/community_payment_config_service.dart';
import 'package:admin_app/widgets/community_payment_settings_card.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _communityId = 'COMMUNITY_A';
final _updatedAt = Timestamp.fromMillisecondsSinceEpoch(1780000000000);

Map<String, dynamic> _configData({
  required bool enabled,
  String vpa = 'association@upi-bank',
  String payeeName = 'Community Association',
}) => {
  'communityId': _communityId,
  'version': 1,
  'directUpi': {
    'enabled': enabled,
    if (enabled) 'vpa': vpa,
    if (enabled) 'payeeName': payeeName,
  },
  'updatedBy': 'admin-a',
  'updatedAt': _updatedAt,
};

void _selectCommunity() {
  AdminTenantContext.instance.initialize(
    const AdminProfile(
      uid: 'admin-a',
      phoneNumber: '+15550000001',
      role: 'admin',
      isActive: true,
      authorizedCommunityIds: [_communityId],
    ),
  );
}

Future<void> _pumpCard(
  WidgetTester tester,
  CommunityPaymentConfigService service,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: CommunityPaymentSettingsCard(service: service)),
    ),
  );
  await tester.pumpAndSettle();
}

CommunityPaymentConfigService _service(
  FakeFirebaseFirestore firestore, {
  CommunityPaymentConfigCallable? onUpdate,
}) => CommunityPaymentConfigService(
  firestore: firestore,
  updateCallable: onUpdate,
);

void main() {
  tearDown(AdminTenantContext.instance.clear);

  testWidgets('missing config displays Disabled and Configure', (tester) async {
    _selectCommunity();
    await _pumpCard(tester, _service(FakeFirebaseFirestore()));

    expect(find.text('Not configured'), findsOneWidget);
    expect(find.text('Configure'), findsOneWidget);
    expect(
      find.text('Residents cannot use Direct UPI until it is configured.'),
      findsOneWidget,
    );
  });

  testWidgets('enabled config displays destination and Edit', (tester) async {
    _selectCommunity();
    final firestore = FakeFirebaseFirestore();
    await firestore
        .collection('communityPaymentConfigs')
        .doc(_communityId)
        .set(_configData(enabled: true));
    await _pumpCard(tester, _service(firestore));

    expect(find.text('Enabled'), findsOneWidget);
    expect(find.text('association@upi-bank'), findsOneWidget);
    expect(find.text('Community Association'), findsOneWidget);
    expect(find.text('Edit'), findsOneWidget);
  });

  testWidgets('configure requires VPA and payee name', (tester) async {
    _selectCommunity();
    final firestore = FakeFirebaseFirestore();
    var updateCount = 0;
    await _pumpCard(
      tester,
      _service(firestore, onUpdate: (_) async => updateCount++),
    );
    await tester.tap(find.text('Configure'));
    await tester.pumpAndSettle();
    expect(find.text('Direct UPI payment settings'), findsOneWidget);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(find.text('UPI ID (VPA)'), findsOneWidget);
    expect(find.text('Payee name'), findsOneWidget);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a UPI ID (VPA).'), findsOneWidget);
    expect(updateCount, 0);

    await tester.enterText(
      find.widgetWithText(TextField, 'UPI ID (VPA)'),
      'assoc@upi',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a payee name.'), findsOneWidget);
    expect(updateCount, 0);
  });

  testWidgets('editing enabled config prefills VPA and payee', (tester) async {
    _selectCommunity();
    final firestore = FakeFirebaseFirestore();
    await firestore
        .collection('communityPaymentConfigs')
        .doc(_communityId)
        .set(_configData(enabled: true));
    await _pumpCard(tester, _service(firestore));
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<TextField>(find.widgetWithText(TextField, 'UPI ID (VPA)'))
          .controller!
          .text,
      'association@upi-bank',
    );
    expect(
      tester
          .widget<TextField>(find.widgetWithText(TextField, 'Payee name'))
          .controller!
          .text,
      'Community Association',
    );
  });

  testWidgets('successful save refreshes authoritative returned config', (
    tester,
  ) async {
    _selectCommunity();
    final firestore = FakeFirebaseFirestore();
    Map<String, dynamic>? submitted;
    final service = _service(
      firestore,
      onUpdate: (payload) async {
        submitted = payload;
        await firestore
            .collection('communityPaymentConfigs')
            .doc(_communityId)
            .set(
              _configData(
                enabled: true,
                vpa: 'server@upi-bank',
                payeeName: 'Authoritative Association',
              ),
            );
      },
    );
    await _pumpCard(tester, service);
    await tester.tap(find.text('Configure'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'UPI ID (VPA)'),
      ' submitted@upi ',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Payee name'),
      ' Submitted Name ',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(submitted, {
      'communityId': _communityId,
      'directUpi': {
        'enabled': true,
        'vpa': 'submitted@upi',
        'payeeName': 'Submitted Name',
      },
    });
    expect(find.text('server@upi-bank'), findsOneWidget);
    expect(find.text('Authoritative Association'), findsOneWidget);
    expect(find.text('Direct UPI settings saved.'), findsOneWidget);
  });

  testWidgets('disabling enabled destination requires confirmation', (
    tester,
  ) async {
    _selectCommunity();
    final firestore = FakeFirebaseFirestore();
    await firestore
        .collection('communityPaymentConfigs')
        .doc(_communityId)
        .set(_configData(enabled: true));
    var updateCount = 0;
    await _pumpCard(
      tester,
      _service(firestore, onUpdate: (_) async => updateCount++),
    );
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(find.text('Disable Direct UPI?'), findsOneWidget);
    expect(
      find.text(
        'Disabling Direct UPI will prevent residents from using this payment destination for new direct UPI payments.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(TextButton, 'Cancel').last);
    await tester.pumpAndSettle();
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(updateCount, 0);
  });

  testWidgets(
    'confirmed disable sends disabled-only update and hides old destination',
    (tester) async {
      _selectCommunity();
      final firestore = FakeFirebaseFirestore();
      await firestore
          .collection('communityPaymentConfigs')
          .doc(_communityId)
          .set(_configData(enabled: true));
      Map<String, dynamic>? submitted;
      final service = _service(
        firestore,
        onUpdate: (payload) async {
          submitted = payload;
          await firestore
              .collection('communityPaymentConfigs')
              .doc(_communityId)
              .set(_configData(enabled: false));
        },
      );
      await _pumpCard(tester, service);
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Disable'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(submitted, {
        'communityId': _communityId,
        'directUpi': {'enabled': false},
      });
      expect(find.text('Disabled'), findsOneWidget);
      expect(find.text('association@upi-bank'), findsNothing);
      expect(find.text('Community Association'), findsNothing);
    },
  );

  testWidgets('malformed config shows safe error and Retry reloads', (
    tester,
  ) async {
    _selectCommunity();
    final firestore = FakeFirebaseFirestore();
    final doc = firestore
        .collection('communityPaymentConfigs')
        .doc(_communityId);
    await doc.set({..._configData(enabled: true), 'version': 99});
    await _pumpCard(tester, _service(firestore));

    expect(find.text('Payment settings could not be loaded.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('association@upi-bank'), findsNothing);
    await doc.set(_configData(enabled: true));
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Enabled'), findsOneWidget);
    expect(find.text('association@upi-bank'), findsOneWidget);
  });
}
