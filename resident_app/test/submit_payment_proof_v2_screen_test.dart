import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:resident_app/src/screens/submit_payment_proof_screen.dart';
import 'package:resident_app/src/services/resident_direct_upi_service.dart';

import 'localization_test_app.dart';

final _bill = <String, dynamic>{
  'id': 'bill-v2',
  'schemaVersion': 2,
  'communityId': 'community',
  'residentId': 'resident',
  'flatId': 'flat',
  'currency': 'INR',
  'status': 'partially_paid',
  'amountMinor': 250000,
  'outstandingAmountMinor': 120000,
  'currentRevisionId': 'revision_4',
};

Map<String, dynamic> _existingProof() => {
  'schemaVersion': 2,
  'id': 'reserved-proof',
  'communityId': 'community',
  'residentId': 'resident',
  'userId': 'resident',
  'billId': 'bill-v2',
  'status': 'pending',
  'submittedAmountMinor': 120000,
  'submittedBillRevisionId': 'revision_4',
  'receiptPath':
      'payment_receipts/community/bill-v2/resident/reserved-proof.jpg',
};

class _Fixture {
  final calls = <Map<String, dynamic>>[];
  final uploads = <Map<String, dynamic>>[];
  Map<String, dynamic>? existingMetadata;
  bool uploadFails = false;

  late final service = ResidentDirectUpiService(
    scopeLoader: () async => const ResidentDirectUpiScope(
      uid: 'resident',
      communityId: 'community',
      flatId: 'flat',
    ),
    billLoader: (_) async =>
        ResidentDirectUpiDocument(exists: true, data: _bill),
    paymentConfigLoader: (_) async => ResidentDirectUpiDocument(
      exists: true,
      data: {
        'communityId': 'community',
        'version': 1,
        'directUpi': {
          'enabled': true,
          'vpa': 'community@upi',
          'payeeName': 'Community',
        },
        'updatedBy': 'admin',
        'updatedAt': Timestamp.fromMillisecondsSinceEpoch(1780000000000),
      },
    ),
    v2ProofLoader:
        ({required communityId, required billId, required residentId}) async =>
            [],
    prepareProof: (payload) async {
      calls.add(Map.of(payload));
      return {
        'paymentId': 'new-proof',
        'receiptPath':
            'payment_receipts/community/bill-v2/resident/new-proof.${payload['receiptExtension']}',
        'status': 'pending',
      };
    },
    receiptMetadataLoader: (_) async => existingMetadata,
    receiptUploader:
        ({
          required receiptPath,
          required bytes,
          required contentType,
          required customMetadata,
        }) async {
          uploads.add({
            'receiptPath': receiptPath,
            'bytes': bytes.toList(),
            'contentType': contentType,
            'metadata': customMetadata,
          });
          if (uploadFails) throw StateError('temporary upload failure');
        },
  );
}

Widget _app(
  _Fixture fixture, {
  Map<String, dynamic>? existingProof,
  required XFile receipt,
  bool flexibleAmountsEnabled = false,
  double width = 390,
  double textScale = 1,
}) => withEnglishLocalization(
  (context) => ScreenUtilInit(
    designSize: const Size(390, 844),
    builder: (_, _) => localizedMaterialApp(
      context,
      home: MediaQuery(
        data: MediaQueryData(
          size: Size(width, 844),
          textScaler: TextScaler.linear(textScale),
        ),
        child: SubmitPaymentProofScreen(
          bill: _bill,
          existingV2Proof: existingProof,
          service: fixture.service,
          receiptPicker: (_) async => receipt,
          flexibleAmountsEnabled: flexibleAmountsEnabled,
        ),
      ),
    ),
  ),
);

XFile _receiptFile() => XFile.fromData(
  base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/7WsAAAAASUVORK5CYII=',
  ),
  name: 'receipt.jpg',
  mimeType: 'image/png',
);

Future<void> _selectReceipt(WidgetTester tester) async {
  await tester.tap(find.text('Take photo or choose from gallery'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Choose Photo'));
  await tester.pumpAndSettle();
}

void _setViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  setUpAll(initializeTestLocalization);

  testWidgets(
    'V2 submission prepares through callable and never writes V1 payments',
    (tester) async {
      _setViewport(tester);
      final fixture = _Fixture();
      final receipt = _receiptFile();

      await tester.pumpWidget(_app(fixture, receipt: receipt));
      await tester.pumpAndSettle();
      expect(find.text('₹1200.00'), findsOneWidget);
      await _selectReceipt(tester);
      await tester.ensureVisible(find.text('Submit for Verification'));
      await tester.tap(find.text('Submit for Verification'));
      await tester.pumpAndSettle();

      expect(fixture.calls, hasLength(1));
      expect(fixture.calls.single['billId'], 'bill-v2');
      expect(fixture.calls.single['submittedAmountMinor'], 120000);
      expect(
        fixture.calls.single.containsKey('amountContractVersion'),
        isFalse,
      );
      expect(fixture.calls.single['submittedBillRevisionId'], 'revision_4');
      expect(
        fixture.uploads.single['receiptPath'],
        'payment_receipts/community/bill-v2/resident/new-proof.jpg',
      );
    },
  );

  testWidgets('proof form remains usable on narrow phones with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _app(_Fixture(), receipt: _receiptFile(), width: 320, textScale: 1.7),
    );
    await tester.pumpAndSettle();

    expect(find.text('Submit Payment Proof'), findsOneWidget);
    expect(find.text('Transaction / Reference No.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('restart recovery resumes the existing pending proof path', (
    tester,
  ) async {
    _setViewport(tester);
    final fixture = _Fixture();
    final receipt = _receiptFile();

    await tester.pumpWidget(
      _app(fixture, existingProof: _existingProof(), receipt: receipt),
    );
    await tester.pumpAndSettle();
    expect(find.text('Reserved Payment Amount'), findsOneWidget);
    await _selectReceipt(tester);
    await tester.tap(find.text('Resume Receipt Upload'));
    await tester.pumpAndSettle();

    expect(fixture.calls, isEmpty);
    expect(
      fixture.uploads.single['receiptPath'],
      _existingProof()['receiptPath'],
    );
    expect(fixture.uploads.single['metadata']['paymentId'], 'reserved-proof');
  });

  testWidgets('flexible excess amount is validated and marked version 2', (
    tester,
  ) async {
    _setViewport(tester);
    final fixture = _Fixture();
    await tester.pumpWidget(
      _app(fixture, receipt: _receiptFile(), flexibleAmountsEnabled: true),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Selected bill outstanding: ₹1200.00'),
      findsOneWidget,
    );
    await tester.enterText(find.byType(TextField).first, '1300.25');
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      '1300.25',
    );
    expect(
      find.textContaining('Difference from selected bill:'),
      findsOneWidget,
    );
    await _selectReceipt(tester);
    await tester.ensureVisible(find.text('Submit for Verification'));
    await tester.tap(find.text('Submit for Verification'));
    await tester.pumpAndSettle();
    expect(fixture.calls.single['submittedAmountMinor'], 130025);
    expect(fixture.calls.single['amountContractVersion'], 2);
  });

  testWidgets('retry reuses the same V2 attempt after receipt upload failure', (
    tester,
  ) async {
    _setViewport(tester);
    final fixture = _Fixture()..uploadFails = true;
    // Fail only the first upload; the prepared proof and operation ID must be
    // retained by the screen for the retry.
    await tester.pumpWidget(_app(fixture, receipt: _receiptFile()));
    await tester.pumpAndSettle();
    await _selectReceipt(tester);
    await tester.ensureVisible(find.text('Submit for Verification'));
    await tester.tap(find.text('Submit for Verification'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Retry this attempt'), findsOneWidget);
    expect(fixture.calls, hasLength(1));
    final originalKey = fixture.calls.single['idempotencyKey'];

    fixture.uploadFails = false;
    await tester.ensureVisible(find.text('Retry payment proof submission'));
    await tester.tap(find.text('Retry payment proof submission'));
    await tester.pumpAndSettle();
    expect(fixture.calls, hasLength(2));
    expect(fixture.calls.last['idempotencyKey'], originalKey);
  });
}
