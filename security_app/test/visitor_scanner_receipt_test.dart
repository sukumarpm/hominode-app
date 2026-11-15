import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:security_app/screens/qr_scanner_screen.dart';
import 'package:security_app/services/visitor_service.dart';

class _Workflow extends Fake implements VisitorWorkflow {
  _Workflow(this.response);
  final Map<String, dynamic> response;
  @override
  String newOperationId() => 'operation-scanner-regression-0001';
  @override
  Future<Map<String, dynamic>> verifyVisitorCredential({
    String? qrToken,
    String? manualCode,
    required String operationId,
  }) async => response;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('flutter.baseflow.com/permissions/methods'),
      (_) async => 1,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('dev.steenbakker.mobile_scanner/scanner/method'),
      (call) async {
        if (call.method == 'state') return 1;
        if (call.method == 'start') {
          return <String, Object>{
            'textureId': 1,
            'cameraDirection': 1,
            'numberOfCameras': 1,
            'currentTorchState': -1,
            'size': <String, double>{'width': 640, 'height': 480},
            'initialDeviceOrientation': 'portraitUp',
          };
        }
        return null;
      },
    );
    for (final name in ['event', 'deviceOrientation']) {
      messenger.setMockStreamHandler(
        EventChannel('dev.steenbakker.mobile_scanner/scanner/$name'),
        MockStreamHandler.inline(onListen: (_, __) {}),
      );
    }
  });

  for (final replay in [true, false, null]) {
    for (final pet in [true, false, null]) {
      testWidgets(
        'scanner displays pet declaration without changing receipt (idempotent=$replay, pet=$pet)',
        (tester) async {
          tester.view.physicalSize = const Size(393, 1000);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final response = <String, dynamic>{
            'visitorName': 'Guest',
            if (pet != null) 'bringingPet': pet,
            'status': 'inside',
            if (replay != null) 'idempotent': replay,
            'currentStatus': replay == false ? 'inside' : 'completed',
            'processedAt': DateTime.utc(
              2026,
              11,
              1,
              2,
              3,
            ).millisecondsSinceEpoch,
          };
          await tester.pumpWidget(
            MaterialApp(
              home: QRScannerScreen(visitorWorkflow: _Workflow(response)),
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));
          tester.widget<MobileScanner>(find.byType(MobileScanner)).onDetect!(
            BarcodeCapture(
              barcodes: [
                Barcode(
                  rawValue: jsonEncode({
                    'type': 'hominode_visitor',
                    'version': 1,
                    'token': 'Q' * 43,
                  }),
                ),
              ],
            ),
          );
          await tester.pumpAndSettle();
          if (replay == false) {
            expect(find.text('Pet declared: '), findsOneWidget);
            expect(
              find.text(
                pet == null
                    ? 'Not recorded'
                    : pet
                    ? 'Yes'
                    : 'No',
              ),
              findsOneWidget,
            );
            expect(find.text('Entry Granted ✓'), findsOneWidget);
            expect(
              find.textContaining('2026-11-01T02:03:00.000Z'),
              findsOneWidget,
            );
          } else {
            expect(
              find.textContaining(
                'Pet declared on receipt: ${pet == null
                    ? 'Not recorded'
                    : pet
                    ? 'Yes'
                    : 'No'}',
              ),
              findsOneWidget,
            );
            expect(find.text('Entry Granted ✓'), findsNothing);
            expect(
              find.textContaining('No new entry was granted.'),
              findsOneWidget,
            );
            expect(
              find.textContaining('Current visit state: Checked out'),
              findsOneWidget,
            );
          }
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }
}
