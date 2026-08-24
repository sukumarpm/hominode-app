import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'services/auth_service.dart';
import 'theme/hominode_theme.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});
  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _phone = TextEditingController();
  final _otp = TextEditingController();
  final _auth = AuthService();
  String? _verificationId;
  int? _resendToken;
  bool _busy = false;

  Future<void> _sendOtp() async {
    final phone = _phone.text.trim();
    if (!RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(phone)) {
      return _error(
        'Enter the phone number in international format, for example +919876543210.',
      );
    }
    setState(() => _busy = true);
    try {
      await _auth.sendOtp(
        phoneNumber: phone,
        forceResendingToken: _resendToken,
        onCodeSent: (id, token) {
          if (!mounted) return;
          setState(() {
            _verificationId = id;
            _resendToken = token;
            _busy = false;
          });
        },
        onVerificationCompleted: _finish,
        onError: (message) {
          if (!mounted) return;
          setState(() => _busy = false);
          _error(message);
        },
      );
    } catch (_) {
      if (mounted) {
        setState(() => _busy = false);
        _error('Could not send OTP. Please try again.');
      }
    }
  }

  Future<void> _verify() async {
    if (_verificationId == null ||
        !RegExp(r'^\d{6}$').hasMatch(_otp.text.trim())) {
      return _error('Enter the 6-digit OTP.');
    }
    setState(() => _busy = true);
    final result = await _auth.verifyOtp(
      verificationId: _verificationId!,
      smsCode: _otp.text,
    );
    await _finish(result);
  }

  Future<void> _finish(AuthResult result) async {
    if (!mounted) return;
    setState(() => _busy = false);
    if (!result.success) _error(result.message);
    // AuthWrapper observes the successful Firebase session and opens the dashboard.
  }

  void _error(String text) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(text), backgroundColor: Colors.red));

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(gradient: HominodeTheme.primaryGradient),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 24.w),
          child: Column(
            children: [
              SizedBox(height: 80.h),
              Text(
                'Welcome Back Admin',
                style: TextStyle(
                  fontSize: 24.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                'Sign in securely with phone OTP',
                style: TextStyle(
                  fontSize: 16.sp,
                  color: const Color(0xFFD1D5DB),
                ),
              ),
              SizedBox(height: 40.h),
              Container(
                constraints: BoxConstraints(
                  maxWidth: 520.w.clamp(360.0, 520.0),
                ),
                padding: EdgeInsets.all(24.w),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _verificationId == null ? 'Admin Login' : 'Verify OTP',
                      style: TextStyle(
                        fontSize: 22.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 20.h),
                    TextField(
                      controller: _phone,
                      readOnly: _verificationId != null,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Phone number',
                        hintText: '+919876543210',
                        prefixIcon: Icon(Icons.phone_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    if (_verificationId != null) ...[
                      SizedBox(height: 16.h),
                      TextField(
                        controller: _otp,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        decoration: const InputDecoration(
                          labelText: '6-digit OTP',
                          prefixIcon: Icon(Icons.sms_outlined),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                    SizedBox(height: 24.h),
                    SizedBox(
                      width: double.infinity,
                      height: 52.h.clamp(48.0, 58.0),
                      child: FilledButton(
                        onPressed: _busy
                            ? null
                            : (_verificationId == null ? _sendOtp : _verify),
                        child: _busy
                            ? SizedBox(
                                width: 20.w,
                                height: 20.w,
                                child: const CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                _verificationId == null
                                    ? 'Send OTP'
                                    : 'Verify OTP',
                              ),
                      ),
                    ),
                    if (_verificationId != null)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                            onPressed: _busy
                                ? null
                                : () => setState(() {
                                    _verificationId = null;
                                    _otp.clear();
                                  }),
                            child: const Text('Change number'),
                          ),
                          TextButton(
                            onPressed: _busy ? null : _sendOtp,
                            child: const Text('Resend OTP'),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              SizedBox(height: 80.h),
            ],
          ),
        ),
      ),
    ),
  );

  @override
  void dispose() {
    _phone.dispose();
    _otp.dispose();
    super.dispose();
  }
}
