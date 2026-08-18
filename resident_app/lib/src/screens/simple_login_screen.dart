import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../components/auth_primary_button.dart';
import '../components/auth_text_field.dart';
import '../services/firebase_auth_service.dart';
import '../services/tenant_resolution_service.dart';
import 'verify_otp_screen_single_field.dart';

class SimpleLoginScreen extends StatefulWidget {
  const SimpleLoginScreen({super.key});

  @override
  State<SimpleLoginScreen> createState() => _SimpleLoginScreenState();
}

class _SimpleLoginScreenState extends State<SimpleLoginScreen> {
  final _phoneController = TextEditingController(text: '+91');
  final _phoneFocusNode = FocusNode();
  final _authService = FirebaseAuthService();
  bool _isLoading = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _phoneFocusNode.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    final phone = _authService.formatPhoneNumber(_phoneController.text);
    if (!_authService.validatePhoneNumber(phone)) {
      _showError('Enter a valid phone number including country code.');
      return;
    }
    setState(() => _isLoading = true);
    final resolver = context.read<TenantResolutionService>();
    try {
      await _authService.sendOtp(
        phoneNumber: phone,
        tenantResolver: resolver,
        onCodeSent: (verificationId) {
          if (!mounted) return;
          setState(() => _isLoading = false);
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => VerifyOTPScreenSingleField(
                mobileNumber: phone,
                verificationId: verificationId,
              ),
            ),
          );
        },
        onVerificationCompleted: _handleCompletedVerification,
        onError: (result) {
          if (!mounted) return;
          setState(() => _isLoading = false);
          _showError(result.message ?? 'Unable to send OTP.');
        },
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showError('Unable to send OTP. Please try again.');
    }
  }

  void _handleCompletedVerification(AuthResult result) {
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (result.success) {
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (_) => false);
    } else {
      _showError(result.message ?? 'Phone verification failed.');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
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
              colors: [Color(0xFF2F80ED), Color(0xFF2563EB)],
            ),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  const SizedBox(height: 120),
                  const Text(
                    'Welcome Back',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Login with your registered mobile number',
                    style: TextStyle(fontSize: 16, color: Color(0xFFF0F0F0)),
                  ),
                  const SizedBox(height: 48),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 32,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Mobile Number',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 10),
                        AuthTextField(
                          controller: _phoneController,
                          focusNode: _phoneFocusNode,
                          hintText: '+91 98765 43210',
                          keyboardType: TextInputType.phone,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _sendOtp(),
                        ),
                        const SizedBox(height: 28),
                        AuthPrimaryButton(
                          text: 'Send OTP',
                          onPressed: _sendOtp,
                          isLoading: _isLoading,
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
    );
  }
}
