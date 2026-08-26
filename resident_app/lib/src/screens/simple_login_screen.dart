import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/services.dart';

import '../components/auth_primary_button.dart';
import '../components/auth_text_field.dart';
import '../services/firebase_auth_service.dart';
import '../services/resident_auth_routing.dart';
import 'verify_otp_screen_single_field.dart';

typedef ResidentOtpScreenBuilder =
    Widget Function(
      String phoneNumber,
      String verificationId,
      ResidentAuthenticationIntent intent,
    );

class SimpleLoginScreen extends StatefulWidget {
  const SimpleLoginScreen({super.key, this.authGateway, this.otpScreenBuilder});

  final ResidentPhoneAuthGateway? authGateway;
  final ResidentOtpScreenBuilder? otpScreenBuilder;

  @override
  State<SimpleLoginScreen> createState() => _SimpleLoginScreenState();
}

class _SimpleLoginScreenState extends State<SimpleLoginScreen> {
  final _phoneController = TextEditingController(text: '+91');
  final _phoneFocusNode = FocusNode();
  late final ResidentPhoneAuthGateway _authService;

  bool _isLoading = false;
  bool _navigationStarted = false;

  @override
  void initState() {
    super.initState();
    _authService = widget.authGateway ?? FirebaseAuthService();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _phoneFocusNode.dispose();
    super.dispose();
  }

  Future<void> _sendOtp({
    ResidentAuthenticationIntent intent = ResidentAuthenticationIntent.login,
  }) async {
    if (_isLoading) return;

    FocusScope.of(context).unfocus();

    final phone = _authService.formatPhoneNumber(_phoneController.text.trim());

    if (!_authService.validatePhoneNumber(phone)) {
      _showError('Enter a valid phone number including country code.');
      return;
    }

    setState(() {
      _isLoading = true;
      _navigationStarted = false;
    });

    try {
      await _authService.sendOtp(
        phoneNumber: phone,

        // IMPORTANT:
        // Sending an OTP must only open the OTP verification screen.
        // Do NOT perform flat/access routing here.
        onCodeSent: (verificationId) {
          if (!mounted || _navigationStarted) return;

          _navigationStarted = true;

          setState(() {
            _isLoading = false;
          });

          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  widget.otpScreenBuilder?.call(
                    phone,
                    verificationId,
                    intent,
                  ) ??
                  VerifyOTPScreenSingleField(
                    mobileNumber: phone,
                    verificationId: verificationId,
                    intent: intent,
                  ),
            ),
          );
        },

        onError: (result) {
          if (!mounted) return;

          setState(() {
            _isLoading = false;
          });

          _showError(result.message ?? 'Unable to send OTP.');
        },
      );
    } catch (e, stackTrace) {
      debugPrint('SimpleLoginScreen _sendOtp error: $e');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      _showError('Unable to send OTP. Please try again.');
    }
  }

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final horizontalPadding = (size.width * 0.055).clamp(16.0, 28.0);
    final compactHeight = size.height < 700;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF3AA6C8), Color(0xFF0E4778)],
            ),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: 520.w),
                  child: Column(
                    children: [
                      SizedBox(height: compactHeight ? 56 : 120),

                      Text(
                        'Welcome Back',
                        style: TextStyle(
                          fontSize: (size.width * 0.072).clamp(24.0, 30.0),
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),

                      SizedBox(height: 12.h),

                      Text(
                        'Login with your registered mobile number',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16.sp,
                          color: Color(0xFFF0F0F0),
                        ),
                      ),

                      SizedBox(height: compactHeight ? 28 : 48),

                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: (size.width * 0.07).clamp(20.0, 28.0),
                          vertical: compactHeight ? 24 : 32,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(28.r),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Mobile Number',
                              style: TextStyle(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(height: 10.h),
                            AuthTextField(
                              controller: _phoneController,
                              focusNode: _phoneFocusNode,
                              hintText: '+91 98765 43210',
                              keyboardType: TextInputType.phone,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => _sendOtp(),
                            ),
                            SizedBox(height: 28.h),
                            AuthPrimaryButton(
                              text: 'Send OTP',
                              onPressed: _sendOtp,
                              isLoading: _isLoading,
                            ),
                            SizedBox(height: 14.h),
                            Center(
                              child: TextButton(
                                key: const Key('resident-register-link'),
                                onPressed: _isLoading
                                    ? null
                                    : () => _sendOtp(
                                        intent: ResidentAuthenticationIntent
                                            .register,
                                      ),
                                child: const Text('Create account'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
