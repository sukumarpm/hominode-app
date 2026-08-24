import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();

  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();

  bool _otpSent = false;
  bool _loading = false;

  String? _verificationId;
  String? _error;

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    final phone = _phoneController.text.trim();

    if (!RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(phone)) {
      setState(() {
        _error =
            'Enter phone number with country code, for example +639123456789.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await _authService.sendOtp(phone);

      if (!mounted) return;

      if (result.autoVerified) {
        return;
      }

      if (result.verificationId == null) {
        throw const SecurityAuthException(
          'verification-failed',
          'Unable to start OTP verification.',
        );
      }

      setState(() {
        _verificationId = result.verificationId;
        _otpSent = true;
      });
    } on SecurityAuthException catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _error = 'Unable to send OTP. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _verifyOtp() async {
    final verificationId = _verificationId;
    final otp = _otpController.text.trim();

    if (verificationId == null) {
      setState(() {
        _error = 'Request a new OTP.';
      });
      return;
    }

    if (!RegExp(r'^\d{6}$').hasMatch(otp)) {
      setState(() {
        _error = 'Enter the 6-digit OTP.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await _authService.verifyOtp(
        verificationId: verificationId,
        smsCode: otp,
      );

      if (mounted) {
        HapticFeedback.mediumImpact();
      }
    } on SecurityAuthException catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.message;
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  void _changeNumber() {
    setState(() {
      _otpSent = false;
      _verificationId = null;
      _otpController.clear();
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E4778),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                children: [
                  const Icon(
                    Icons.security_rounded,
                    color: Colors.white,
                    size: 64,
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Hominode Security',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Authorized security staff access',
                    style: TextStyle(color: Colors.white70, fontSize: 15),
                  ),
                  const SizedBox(height: 32),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_error != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              _error!,
                              style: TextStyle(color: Colors.red.shade700),
                            ),
                          ),
                          const SizedBox(height: 18),
                        ],
                        if (!_otpSent) ...[
                          const Text(
                            'Phone Number',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _phoneController,
                            enabled: !_loading,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              hintText: '+639123456789',
                              prefixIcon: Icon(Icons.phone_outlined),
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton(
                            onPressed: _loading ? null : _sendOtp,
                            child: _loading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Send OTP'),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Your Security account must already be created by your Community Admin.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.black54,
                              fontSize: 12,
                            ),
                          ),
                        ] else ...[
                          Text(
                            'OTP sent to ${_phoneController.text.trim()}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _otpController,
                            enabled: !_loading,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(6),
                            ],
                            decoration: const InputDecoration(
                              hintText: '6-digit OTP',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton(
                            onPressed: _loading ? null : _verifyOtp,
                            child: _loading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Verify & Continue'),
                          ),
                          TextButton(
                            onPressed: _loading ? null : _sendOtp,
                            child: const Text('Resend OTP'),
                          ),
                          TextButton(
                            onPressed: _loading ? null : _changeNumber,
                            child: const Text('Change phone number'),
                          ),
                        ],
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
