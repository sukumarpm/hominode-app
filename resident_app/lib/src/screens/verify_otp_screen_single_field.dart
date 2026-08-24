import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../components/standard_screen.dart';
import '../services/firebase_auth_service.dart';
import '../services/resident_auth_routing.dart';
import '../services/tenant_resolution_service.dart';

/// OTP Screen with Single TextField Input
/// Firebase Phone Authentication OTP Verification
class VerifyOTPScreenSingleField extends StatefulWidget {
  final String? mobileNumber;
  final String? verificationId;

  const VerifyOTPScreenSingleField({
    super.key,
    this.mobileNumber,
    this.verificationId,
  });

  @override
  State<VerifyOTPScreenSingleField> createState() =>
      _VerifyOTPScreenSingleFieldState();
}

class _VerifyOTPScreenSingleFieldState
    extends State<VerifyOTPScreenSingleField> {
  final TextEditingController _otpController = TextEditingController();
  final FocusNode _otpFocusNode = FocusNode();
  final FirebaseAuthService _authService = FirebaseAuthService();
  bool _isLoading = false;
  late String? _verificationId;

  @override
  void initState() {
    super.initState();
    _verificationId = widget.verificationId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _otpFocusNode.requestFocus();
    });

    _otpController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _otpController.dispose();
    _otpFocusNode.dispose();
    super.dispose();
  }

  String get _otp => _otpController.text;
  bool get _isComplete => _otp.length == 6;

  void _onChanged(String value) {
    // Only allow digits
    final digitsOnly = value.replaceAll(RegExp(r'[^\d]'), '');

    // Limit to 6 digits
    if (digitsOnly.length <= 6) {
      _otpController.value = TextEditingValue(
        text: digitsOnly,
        selection: TextSelection.collapsed(offset: digitsOnly.length),
      );
    }

    setState(() {});
  }

  Future<void> _handleVerify() async {
    if (!_isComplete) return;

    setState(() => _isLoading = true);

    try {
      final result = await _authService.verifyOtp(
        smsCode: _otp,
        verificationId: _verificationId,
        tenantResolver: context.read<TenantResolutionService>(),
      );

      if (!mounted) return;

      if (result.success) {
        ResidentAuthRouting.navigateToResult(context, result);
      } else {
        setState(() => _isLoading = false);
        _showSnackBar(
          result.message ?? 'Unable to complete authentication.',
          isError: true,
        );
        if (result.errorCode == 'invalid-verification-code') {
          _clearOTP();
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showSnackBar('An error occurred. Please try again.', isError: true);
    }
  }

  Future<void> _handleResend() async {
    final mobile = widget.mobileNumber ?? '';

    if (mobile.isEmpty) {
      _showSnackBar('Mobile number not found', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    final formattedPhone = _authService.formatPhoneNumber(mobile);

    await _authService.sendOtp(
      phoneNumber: formattedPhone,
      forceResend: true,
      onCodeSent: (verificationId) {
        _verificationId = verificationId;
        setState(() => _isLoading = false);
        _showSnackBar('OTP resent successfully', isError: false);
      },
      onError: (result) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        _showSnackBar(result.message ?? 'Unable to resend OTP.', isError: true);
      },
    );
  }

  void _clearOTP() {
    _otpController.clear();
    _otpFocusNode.requestFocus();
    setState(() {});
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? const Color(0xFFEF4444)
            : const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
        margin: EdgeInsets.all(16.w),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StandardScreen(
      title: 'Verify OTP',
      isScrollable: true,
      padding: EdgeInsets.symmetric(horizontal: 24.w),
      body: Column(
        children: [
          SizedBox(height: 40.h),

          // Main Headline
          Text(
            'Enter OTP',
            style: TextStyle(
              fontSize: 28.sp,
              fontWeight: FontWeight.w600,
              color: Color(0xFF111111),
              letterSpacing: -0.5,
            ),
          ),
          SizedBox(height: 12.h),

          // Subtext with phone number
          Text(
            "We've sent a verification code to",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF111111).withValues(alpha: 0.7),
              height: 1.5,
              letterSpacing: 0.2,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            widget.mobileNumber ?? '',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 17.sp,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0E4778),
              letterSpacing: 0.5,
            ),
          ),
          SizedBox(height: 48.h),

          // OTP INPUT - Single Field with Visual Separation
          _buildOTPInput(),

          SizedBox(height: 48.h),

          // Verify Button
          _buildVerifyButton(),

          SizedBox(height: 20.h),

          // Resend Link
          _buildResendLink(),

          SizedBox(height: 40.h),
        ],
      ),
    );
  }

  Widget _buildOTPInput() {
    return GestureDetector(
      onTap: () => _otpFocusNode.requestFocus(),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(
            color: _otpFocusNode.hasFocus
                ? const Color(0xFF0E4778)
                : const Color(0xFFD1D5DB),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: _otpFocusNode.hasFocus
                  ? const Color(0xFF0E4778).withValues(alpha: 0.12)
                  : Colors.black.withValues(alpha: 0.04),
              blurRadius: _otpFocusNode.hasFocus ? 10 : 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Stack(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(6, (index) {
                final hasDigit = index < _otp.length;
                final digit = hasDigit ? _otp[index] : '';

                return Container(
                  width: 38.w,
                  height: 48.h,
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: hasDigit
                            ? const Color(0xFF0E4778)
                            : const Color(0xFFD1D5DB),
                        width: 2.5,
                      ),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      digit,
                      style: TextStyle(
                        fontSize: 28.sp,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                );
              }),
            ),

            Positioned.fill(
              child: Opacity(
                opacity: 0.01,
                child: TextField(
                  controller: _otpController,
                  focusNode: _otpFocusNode,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  autofocus: true,
                  style: const TextStyle(color: Colors.transparent),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    counterText: '',
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  onChanged: _onChanged,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVerifyButton() {
    final isEnabled = _isComplete && !_isLoading;

    return SizedBox(
      width: double.infinity,
      height: 54.h,
      child: ElevatedButton(
        onPressed: isEnabled ? _handleVerify : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0E4778),
          disabledBackgroundColor: const Color(0xFFE5E7EB),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
          elevation: 0,
          shadowColor: Colors.transparent,
        ),
        child: _isLoading
            ? SizedBox(
                height: 20.h,
                width: 20.w,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                'Verify & Continue',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  letterSpacing: 0.3,
                ),
              ),
      ),
    );
  }

  Widget _buildResendLink() {
    return Center(
      child: TextButton(
        onPressed: _isLoading ? null : _handleResend,
        style: TextButton.styleFrom(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.r),
          ),
        ),
        child: RichText(
          text: TextSpan(
            style: TextStyle(
              fontSize: 15.sp,
              fontWeight: FontWeight.w500,
              color: Color(0xFF6B7280),
              letterSpacing: 0.1,
            ),
            children: [
              TextSpan(text: "Didn't receive code? "),
              TextSpan(
                text: 'Resend',
                style: TextStyle(
                  color: Color(0xFF0E4778),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
