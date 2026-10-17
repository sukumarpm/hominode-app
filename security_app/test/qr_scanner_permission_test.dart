import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:security_app/screens/qr_scanner_screen.dart';

const _permissionChannel = MethodChannel(
  'flutter.baseflow.com/permissions/methods',
);
const _scannerMethodChannel = MethodChannel(
  'dev.steenbakker.mobile_scanner/scanner/method',
);
const _scannerEventChannel = EventChannel(
  'dev.steenbakker.mobile_scanner/scanner/event',
);
const _orientationEventChannel = EventChannel(
  'dev.steenbakker.mobile_scanner/scanner/deviceOrientation',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('starts the scanner when camera permission is already granted', (
    tester,
  ) async {
    var startCalls = 0;
    var requestCalls = 0;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    messenger.setMockMethodCallHandler(_permissionChannel, (call) async {
      switch (call.method) {
        case 'checkPermissionStatus':
          return 1; // PermissionStatus.granted.
        case 'requestPermissions':
          requestCalls++;
          return <int, int>{1: 1};
        default:
          return null;
      }
    });
    messenger.setMockMethodCallHandler(_scannerMethodChannel, (call) async {
      switch (call.method) {
        case 'state':
          return 1; // Camera authorization is already granted.
        case 'start':
          startCalls++;
          return <String, Object>{
            'textureId': 1,
            'cameraDirection': 1,
            'numberOfCameras': 1,
            'currentTorchState': -1,
            'size': <String, double>{'width': 640, 'height': 480},
            'initialDeviceOrientation': 'portraitUp',
          };
        default:
          return null;
      }
    });
    for (final channel in [_scannerEventChannel, _orientationEventChannel]) {
      messenger.setMockStreamHandler(
        channel,
        MockStreamHandler.inline(onListen: (_, __) {}),
      );
    }

    await tester.pumpWidget(const MaterialApp(home: QRScannerScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(startCalls, 1);
    expect(requestCalls, 0);
    expect(find.text('Camera Permission Required'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
