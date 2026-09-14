import 'package:flutter/material.dart';

import 'theme/hominode_theme.dart';

const double adminLoginDesktopBreakpoint = 1024;

enum AdminLoginLayout { mobile, desktop }

AdminLoginLayout adminLoginLayoutForWidth(double width) =>
    width < adminLoginDesktopBreakpoint
    ? AdminLoginLayout.mobile
    : AdminLoginLayout.desktop;

class AdminLoginDesktop extends StatelessWidget {
  const AdminLoginDesktop({
    required this.phoneController,
    required this.otpController,
    required this.countryCode,
    required this.isOtpSent,
    required this.isBusy,
    required this.onCountryCodeChanged,
    required this.onSendOtp,
    required this.onVerifyOtp,
    required this.onChangeNumber,
    required this.onResendOtp,
    super.key,
  });

  static const countryCodes = <String>['+91', '+63', '+1', '+44', '+65'];

  final TextEditingController phoneController;
  final TextEditingController otpController;
  final String countryCode;
  final bool isOtpSent;
  final bool isBusy;
  final ValueChanged<String> onCountryCodeChanged;
  final Future<void> Function() onSendOtp;
  final Future<void> Function() onVerifyOtp;
  final VoidCallback onChangeNumber;
  final Future<void> Function() onResendOtp;

  Future<void> _submitPhoneNumber() {
    final number = phoneController.text.trim().replaceAll(RegExp(r'\s+'), '');
    if (number.isNotEmpty && !number.startsWith('+')) {
      phoneController.text = '$countryCode$number';
      phoneController.selection = TextSelection.collapsed(
        offset: phoneController.text.length,
      );
    }
    return onSendOtp();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF4F7FA),
    body: Row(
      children: [
        const Expanded(child: _BrandPanel()),
        Expanded(
          child: ColoredBox(
            color: const Color(0xFFF4F7FA),
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 32,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight:
                        (MediaQuery.sizeOf(context).height -
                                MediaQuery.paddingOf(context).vertical -
                                64)
                            .clamp(0, double.infinity),
                  ),
                  child: Center(
                    child: Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(maxWidth: 460),
                      padding: const EdgeInsets.all(36),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE3EAF1)),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x12061C4C),
                            blurRadius: 28,
                            offset: Offset(0, 12),
                          ),
                        ],
                      ),
                      child: _LoginForm(
                        phoneController: phoneController,
                        otpController: otpController,
                        countryCode: countryCode,
                        isOtpSent: isOtpSent,
                        isBusy: isBusy,
                        onCountryCodeChanged: onCountryCodeChanged,
                        onSendOtp: _submitPhoneNumber,
                        onVerifyOtp: onVerifyOtp,
                        onChangeNumber: onChangeNumber,
                        onResendOtp: onResendOtp,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: HominodeTheme.navy,
    child: Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/images/admin_login_background.png',
          fit: BoxFit.cover,
          alignment: Alignment.center,
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xB3061C4C), Color(0xE6061C4C)],
            ),
          ),
        ),
        SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(48),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight:
                    (MediaQuery.sizeOf(context).height -
                            MediaQuery.paddingOf(context).vertical -
                            96)
                        .clamp(0, double.infinity),
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.asset(
                          'assets/Admin_New.png',
                          width: 112,
                          height: 112,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(height: 28),
                      const Text(
                        'HOMINODE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2.4,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Property management, connected.',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          height: 1.2,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Secure access to your community administration workspace.',
                        style: TextStyle(
                          color: Color(0xFFD2E8F2),
                          fontSize: 16,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _LoginForm extends StatelessWidget {
  const _LoginForm({
    required this.phoneController,
    required this.otpController,
    required this.countryCode,
    required this.isOtpSent,
    required this.isBusy,
    required this.onCountryCodeChanged,
    required this.onSendOtp,
    required this.onVerifyOtp,
    required this.onChangeNumber,
    required this.onResendOtp,
  });

  final TextEditingController phoneController;
  final TextEditingController otpController;
  final String countryCode;
  final bool isOtpSent;
  final bool isBusy;
  final ValueChanged<String> onCountryCodeChanged;
  final Future<void> Function() onSendOtp;
  final Future<void> Function() onVerifyOtp;
  final VoidCallback onChangeNumber;
  final Future<void> Function() onResendOtp;

  InputDecoration _decoration({required String label, String? hint}) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFCDD8E3)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final phoneHasInternationalPrefix = phoneController.text.trim().startsWith(
      '+',
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isOtpSent ? 'Verify your number' : 'Welcome back',
          style: const TextStyle(
            color: Color(0xFF102A43),
            fontSize: 28,
            height: 1.2,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          isOtpSent
              ? 'Enter the 6-digit code sent to your phone.'
              : 'Sign in to the Admin workspace with phone OTP.',
          style: const TextStyle(
            color: Color(0xFF66788A),
            fontSize: 14,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 28),
        const Text(
          'Phone number',
          style: TextStyle(
            color: Color(0xFF243B53),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 120,
              height: 54,
              child: DropdownButtonFormField<String>(
                initialValue: countryCode,
                isExpanded: true,
                decoration: _decoration(label: 'Country'),
                items: AdminLoginDesktop.countryCodes
                    .map(
                      (code) =>
                          DropdownMenuItem(value: code, child: Text(code)),
                    )
                    .toList(growable: false),
                onChanged: isBusy || isOtpSent
                    ? null
                    : (value) {
                        if (value != null) onCountryCodeChanged(value);
                      },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 54,
                child: TextField(
                  controller: phoneController,
                  readOnly: isOtpSent,
                  keyboardType: TextInputType.phone,
                  decoration: _decoration(label: 'Number', hint: '9876543210')
                      .copyWith(
                        prefixText: phoneHasInternationalPrefix
                            ? null
                            : '$countryCode ',
                      ),
                ),
              ),
            ),
          ],
        ),
        if (isOtpSent) ...[
          const SizedBox(height: 20),
          const Text(
            'One-time password',
            style: TextStyle(
              color: Color(0xFF243B53),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 54,
            child: TextField(
              controller: otpController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: _decoration(
                label: '6-digit OTP',
                hint: 'Enter code',
              ).copyWith(counterText: ''),
            ),
          ),
        ],
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: FilledButton(
            onPressed: isBusy ? null : (isOtpSent ? onVerifyOtp : onSendOtp),
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: isBusy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(isOtpSent ? 'Verify OTP' : 'Send OTP'),
          ),
        ),
        if (isOtpSent) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: isBusy ? null : onChangeNumber,
                child: const Text('Change number'),
              ),
              TextButton(
                onPressed: isBusy ? null : onResendOtp,
                child: const Text('Resend OTP'),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
