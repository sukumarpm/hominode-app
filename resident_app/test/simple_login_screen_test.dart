import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resident_app/src/screens/simple_login_screen.dart';
import 'package:resident_app/src/services/firebase_auth_service.dart';

class _FakePhoneAuthGateway implements ResidentPhoneAuthGateway {
  int sendCount = 0;

  @override
  String formatPhoneNumber(String phone) => phone;

  @override
  bool validatePhoneNumber(String phone) => true;

  @override
  Future<void> sendOtp({
    required String phoneNumber,
    required void Function(String verificationId) onCodeSent,
    required void Function(AuthResult result) onError,
    bool forceResend = false,
  }) async {
    sendCount++;
    onCodeSent('verification-id');
  }
}

Widget _app(_FakePhoneAuthGateway gateway) => ScreenUtilInit(
  designSize: const Size(390, 844),
  builder: (_, __) => MaterialApp(
    home: SimpleLoginScreen(
      authGateway: gateway,
      otpScreenBuilder: (_, __, intent) =>
          Scaffold(body: Text('OTP intent: ${intent.name}')),
    ),
  ),
);

void main() {
  testWidgets('Register link is visible and starts OTP with register intent', (
    tester,
  ) async {
    final gateway = _FakePhoneAuthGateway();
    await tester.pumpWidget(_app(gateway));

    expect(find.byKey(const Key('resident-register-link')), findsOneWidget);
    expect(find.text('Create account'), findsOneWidget);
    await tester.tap(find.byKey(const Key('resident-register-link')));
    await tester.pumpAndSettle();

    expect(gateway.sendCount, 1);
    expect(find.text('OTP intent: register'), findsOneWidget);
  });

  testWidgets('existing Send OTP action keeps login intent', (tester) async {
    final gateway = _FakePhoneAuthGateway();
    await tester.pumpWidget(_app(gateway));

    await tester.tap(find.text('Send OTP'));
    await tester.pumpAndSettle();

    expect(gateway.sendCount, 1);
    expect(find.text('OTP intent: login'), findsOneWidget);
  });
}
