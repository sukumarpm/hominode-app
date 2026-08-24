import 'package:flutter/material.dart';
import 'services/auth_service.dart';

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
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1E3A8A), Color(0xFF2563EB), Colors.black],
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 80),
              const Text(
                'Welcome Back Admin',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Sign in securely with phone OTP',
                style: TextStyle(fontSize: 16, color: Color(0xFFD1D5DB)),
              ),
              const SizedBox(height: 40),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _verificationId == null ? 'Admin Login' : 'Verify OTP',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
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
                      const SizedBox(height: 16),
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
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton(
                        onPressed: _busy
                            ? null
                            : (_verificationId == null ? _sendOtp : _verify),
                        child: _busy
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
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
              const SizedBox(height: 80),
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
