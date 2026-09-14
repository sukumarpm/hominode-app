import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'admin_login_desktop.dart';
import 'data/country_dial_codes.dart';
import 'services/auth_service.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen>
    with SingleTickerProviderStateMixin {
  static const String _countryPreferenceWriteKey = 'admin_login_country_iso2';

  static const List<String> _countryPreferenceReadKeys = [
    _countryPreferenceWriteKey,
    'phone_country_iso2',
    'selected_country_iso2',
    'phone_country_code',
    'selected_country_code',
  ];

  static const CountryDialCode _defaultCountry = CountryDialCode(
    isoCode: 'PH',
    name: 'Philippines',
    dialCode: '+63',
  );

  // Desktop keeps its existing controller/behavior.
  final _phone = TextEditingController();

  // Mobile uses a separate local-number controller so the country selector
  // can compose a proper international number without affecting desktop UI.
  final _mobilePhone = TextEditingController();

  final _otp = TextEditingController();
  final _mobilePhoneFocusNode = FocusNode();
  final _otpFocusNode = FocusNode();

  final _auth = AuthService();

  String? _verificationId;
  String? _activePhoneNumber;
  int? _resendToken;

  bool _busy = false;
  String? _inlineError;

  // Preserve existing desktop country state.
  String _desktopCountryCode = '+91';

  CountryDialCode _selectedCountry = _defaultCountry;

  late final AnimationController _introController;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _logoScaleAnimation;
  late final Animation<Offset> _cardSlideAnimation;

  bool get _isOtpSent => _verificationId != null;

  @override
  void initState() {
    super.initState();

    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );

    final curve = CurvedAnimation(
      parent: _introController,
      curve: Curves.easeOutCubic,
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(curve);

    _logoScaleAnimation = Tween<double>(begin: 0.92, end: 1).animate(curve);

    _cardSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.07),
      end: Offset.zero,
    ).animate(curve);

    _introController.forward();
    _initializeCountrySelection();
  }

  // ---------------------------------------------------------------------------
  // COUNTRY
  // ---------------------------------------------------------------------------

  Future<void> _initializeCountrySelection() async {
    final prefs = await SharedPreferences.getInstance();

    String? savedIsoCode;

    for (final key in _countryPreferenceReadKeys) {
      final value = prefs.getString(key)?.trim();

      if (value != null && value.isNotEmpty) {
        savedIsoCode = value.toUpperCase();
        break;
      }
    }

    final localeIsoCode =
        WidgetsBinding.instance.platformDispatcher.locale.countryCode;

    final selected =
        _countryByIso(savedIsoCode) ??
        _countryByIso(localeIsoCode) ??
        _countryByIso('PH') ??
        _defaultCountry;

    if (!mounted) return;

    setState(() {
      _selectedCountry = selected;
    });
  }

  CountryDialCode? _countryByIso(String? isoCode) {
    if (isoCode == null || isoCode.trim().isEmpty) return null;

    final target = isoCode.toUpperCase();

    for (final country in kCountryDialCodes) {
      if (country.isoCode.toUpperCase() == target) {
        return country;
      }
    }

    return null;
  }

  Future<void> _saveCountryIsoCode(String isoCode) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(_countryPreferenceWriteKey, isoCode.toUpperCase());
  }

  String _composeMobilePhone() {
    final raw = _mobilePhone.text.trim();

    if (raw.isEmpty) return '';

    // User pasted a complete international number.
    if (raw.startsWith('+')) {
      final digits = raw.substring(1).replaceAll(RegExp(r'\D'), '');

      return digits.isEmpty ? '' : '+$digits';
    }

    final dialDigits = _selectedCountry.dialCode.substring(1);

    var localDigits = raw.replaceAll(RegExp(r'\D'), '');

    // Avoid:
    // +63 + 63917...
    if (localDigits.startsWith(dialDigits)) {
      localDigits = localDigits.substring(dialDigits.length);
    }

    // Remove local trunk prefix.
    localDigits = localDigits.replaceFirst(RegExp(r'^0+'), '');

    return '${_selectedCountry.dialCode}$localDigits';
  }

  // ---------------------------------------------------------------------------
  // AUTH
  // ---------------------------------------------------------------------------

  Future<void> _sendOtpForPhone(String phone, {bool resend = false}) async {
    if (_busy) return;

    FocusScope.of(context).unfocus();

    if (!RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(phone)) {
      _showInlineError('Enter a valid phone number.');
      return;
    }

    setState(() {
      _busy = true;
      _inlineError = null;
      _activePhoneNumber = phone;
    });

    try {
      await _auth.sendOtp(
        phoneNumber: phone,
        forceResendingToken: resend ? _resendToken : null,
        onCodeSent: (id, token) {
          if (!mounted) return;

          setState(() {
            _verificationId = id;
            _resendToken = token;
            _busy = false;
            _inlineError = null;
          });
        },
        onVerificationCompleted: _finish,
        onError: (message) {
          if (!mounted) return;

          setState(() {
            _busy = false;
          });

          _showInlineError(message);
        },
      );
    } catch (e, stackTrace) {
      debugPrint('Admin OTP send failed: $e');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      setState(() {
        _busy = false;
      });

      _showInlineError('Could not send OTP. Please try again.');
    }
  }

  Future<void> _sendOtpMobile() async {
    final phone = _composeMobilePhone();

    await _sendOtpForPhone(phone);
  }

  // Desktop keeps the existing international-number expectation.
  Future<void> _sendOtpDesktop() async {
    final phone = _phone.text.trim();

    if (!RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(phone)) {
      return _error(
        'Enter the phone number in international format, '
        'for example +919876543210.',
      );
    }

    await _sendOtpForPhone(phone);
  }

  Future<void> _resendOtp() async {
    final phone = _activePhoneNumber;

    if (phone == null || phone.isEmpty) {
      _showInlineError('Enter your phone number again.');
      return;
    }

    await _sendOtpForPhone(phone, resend: true);
  }

  Future<void> _verify() async {
    final code = _otp.text.trim();

    if (_verificationId == null || !RegExp(r'^\d{6}$').hasMatch(code)) {
      _showInlineError('Enter the 6-digit OTP.');
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _busy = true;
      _inlineError = null;
    });

    try {
      final result = await _auth.verifyOtp(
        verificationId: _verificationId!,
        smsCode: code,
      );

      await _finish(result);
    } catch (e, stackTrace) {
      debugPrint('Admin OTP verification failed: $e');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      setState(() {
        _busy = false;
      });

      _showInlineError('Unable to verify OTP. Please try again.');
    }
  }

  Future<void> _finish(AuthResult result) async {
    if (!mounted) return;

    setState(() {
      _busy = false;
    });

    if (!result.success) {
      _showInlineError(result.message);
    }

    // IMPORTANT:
    // Do not navigate here.
    //
    // AuthWrapper observes the authenticated Firebase session, validates:
    // - Admin profile
    // - role
    // - status
    // - authorized community
    // - legal acceptance
    //
    // and then opens Admin / Super Admin.
  }

  void _changeNumber() {
    if (_busy) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _verificationId = null;
      _resendToken = null;
      _activePhoneNumber = null;
      _otp.clear();
      _inlineError = null;
    });

    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        _mobilePhoneFocusNode.requestFocus();
      }
    });
  }

  void _error(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), backgroundColor: const Color(0xFFB42318)),
    );
  }

  void _showInlineError(String message) {
    if (!mounted) return;

    final value = message.trim();

    if (value.isEmpty) return;

    setState(() {
      _inlineError = value;
    });
  }

  // ---------------------------------------------------------------------------
  // DESKTOP
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (adminLoginLayoutForWidth(MediaQuery.sizeOf(context).width) ==
        AdminLoginLayout.desktop) {
      return AdminLoginDesktop(
        phoneController: _phone,
        otpController: _otp,
        countryCode: _desktopCountryCode,
        isOtpSent: _isOtpSent,
        isBusy: _busy,
        onCountryCodeChanged: (value) {
          setState(() {
            _desktopCountryCode = value;
          });
        },
        onSendOtp: _sendOtpDesktop,
        onVerifyOtp: _verify,
        onChangeNumber: () {
          setState(() {
            _verificationId = null;
            _resendToken = null;
            _activePhoneNumber = null;
            _otp.clear();
            _inlineError = null;
          });
        },
        onResendOtp: _resendOtp,
      );
    }

    return _buildMobile(context);
  }

  // ---------------------------------------------------------------------------
  // MOBILE UI
  // ---------------------------------------------------------------------------

  Widget _buildMobile(BuildContext context) {
    final insets = MediaQuery.of(context).viewInsets;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: const Color(0xFF041A21),
        body: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/images/admin_login_background.png',
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
            ),

            // Admin role overlay:
            // deep navy + dark green rather than Resident purple/cyan.
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xA8031720),
                    Color(0xD0052025),
                    Color(0xF004171B),
                  ],
                ),
              ),
            ),

            // Small role-colored atmospheric accents.
            Positioned(
              top: -80,
              right: -80,
              child: _GlowOrb(
                size: 220,
                color: const Color(0xFF16C79A).withValues(alpha: 0.13),
              ),
            ),
            Positioned(
              bottom: 20,
              left: -80,
              child: _GlowOrb(
                size: 190,
                color: const Color(0xFF0E7490).withValues(alpha: 0.10),
              ),
            ),

            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final cardMaxWidth = constraints.maxWidth > 620
                      ? 520.0
                      : 600.0;

                  return SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.fromLTRB(
                      20.w,
                      10.h,
                      20.w,
                      (insets.bottom + 18.h).clamp(18.0, 220.0),
                    ),
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: Column(
                        children: [
                          _buildBranding(constraints),

                          SizedBox(height: 18.h),

                          SlideTransition(
                            position: _cardSlideAnimation,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: cardMaxWidth,
                              ),
                              child: _buildLoginCard(),
                            ),
                          ),

                          SizedBox(height: 12.h),

                          ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: cardMaxWidth),
                            child: _buildAccountInformation(),
                          ),

                          SizedBox(height: 16.h),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBranding(BoxConstraints constraints) {
    return ScaleTransition(
      scale: _logoScaleAnimation,
      child: Column(
        children: [
          SizedBox(height: 2.h),

          Image.asset(
            'assets/Admin_New.png',
            width: (constraints.maxWidth * 0.31).clamp(112.0, 185.0),
            fit: BoxFit.contain,
          ),

          SizedBox(height: 3.h),

          Text(
            'HOMINODE',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24.sp.clamp(20.0, 24.0),
              letterSpacing: 1.8,
              fontWeight: FontWeight.w700,
            ),
          ),

          SizedBox(height: 4.h),

          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              children: [
                TextSpan(
                  text: 'Smart ',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14.sp.clamp(12.0, 14.0),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                TextSpan(
                  text: 'place. Better lives.',
                  style: TextStyle(
                    color: const Color(0xFF55E3BE),
                    fontSize: 14.sp.clamp(12.0, 14.0),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 9.h),

          Container(
            padding: EdgeInsets.symmetric(horizontal: 11.w, vertical: 5.h),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: const Color(0x1A42E2B8),
              border: Border.all(color: const Color(0x6655E3BE)),
            ),
            child: Text(
              'Admin Access',
              style: TextStyle(
                color: const Color(0xFF91F2D8),
                fontSize: 11.sp.clamp(11.0, 12.0),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: const Color(0xD3062429),
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: const Color(0xFF1D625D)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF29D6A6).withValues(alpha: 0.20),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: _isOtpSent ? _buildOtpContent() : _buildPhoneContent(),
    );
  }

  Widget _buildPhoneContent() {
    return Column(
      key: const ValueKey('phone-entry'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Phone Number',
          style: TextStyle(
            color: Colors.white,
            fontSize: 17.sp.clamp(15.0, 17.0),
            fontWeight: FontWeight.w600,
          ),
        ),

        SizedBox(height: 5.h),

        Text(
          'Use the mobile number registered with your Admin account.',
          style: TextStyle(
            color: const Color(0xFFA5C9C2),
            fontSize: 12.sp.clamp(11.0, 13.0),
            height: 1.35,
          ),
        ),

        SizedBox(height: 13.h),

        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildCountrySelector(),

            SizedBox(width: 9.w),

            Expanded(
              child: TextField(
                controller: _mobilePhone,
                focusNode: _mobilePhoneFocusNode,
                enabled: !_busy,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.telephoneNumber],
                onChanged: (_) {
                  if (_inlineError != null) {
                    setState(() {
                      _inlineError = null;
                    });
                  }
                },
                onSubmitted: (_) {
                  if (!_busy) {
                    _sendOtpMobile();
                  }
                },
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15.sp.clamp(14.0, 16.0),
                  fontWeight: FontWeight.w500,
                ),
                decoration: _fieldDecoration(
                  hintText: '912 345 6789',
                  prefixIcon: Icons.phone_outlined,
                ),
              ),
            ),
          ],
        ),

        _buildInlineError(),

        SizedBox(height: 15.h),

        _buildPrimaryButton(
          label: 'Send OTP',
          onTap: _busy ? null : _sendOtpMobile,
        ),

        SizedBox(height: 14.h),

        _buildSecureAccessRow(),
      ],
    );
  }

  Widget _buildOtpContent() {
    final destination = _activePhoneNumber ?? _composeMobilePhone();

    return Column(
      key: const ValueKey('otp-entry'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Verify OTP',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18.sp.clamp(16.0, 18.0),
            fontWeight: FontWeight.w700,
          ),
        ),

        SizedBox(height: 5.h),

        Text(
          destination.isEmpty
              ? 'Enter the 6-digit verification code.'
              : 'Enter the code sent to $destination',
          style: TextStyle(
            color: const Color(0xFFA5C9C2),
            fontSize: 12.sp.clamp(11.0, 13.0),
            height: 1.35,
          ),
        ),

        SizedBox(height: 14.h),

        TextField(
          controller: _otp,
          focusNode: _otpFocusNode,
          enabled: !_busy,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          maxLength: 6,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          onChanged: (_) {
            if (_inlineError != null) {
              setState(() {
                _inlineError = null;
              });
            }
          },
          onSubmitted: (_) {
            if (!_busy) {
              _verify();
            }
          },
          style: TextStyle(
            color: Colors.white,
            fontSize: 20.sp.clamp(18.0, 22.0),
            fontWeight: FontWeight.w600,
            letterSpacing: 5,
          ),
          decoration: _fieldDecoration(
            hintText: '000000',
            prefixIcon: Icons.sms_outlined,
          ).copyWith(counterText: ''),
        ),

        _buildInlineError(),

        SizedBox(height: 15.h),

        _buildPrimaryButton(label: 'Verify OTP', onTap: _busy ? null : _verify),

        SizedBox(height: 8.h),

        Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: _busy ? null : _changeNumber,
                child: Text(
                  'Change number',
                  style: TextStyle(
                    color: const Color(0xFF90D8C8),
                    fontSize: 12.sp.clamp(11.0, 13.0),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            Container(width: 1, height: 18, color: const Color(0xFF275D59)),
            Expanded(
              child: TextButton(
                onPressed: _busy ? null : _resendOtp,
                child: Text(
                  'Resend OTP',
                  style: TextStyle(
                    color: const Color(0xFF58E3BE),
                    fontSize: 12.sp.clamp(11.0, 13.0),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),

        SizedBox(height: 5.h),

        _buildSecureAccessRow(),
      ],
    );
  }

  InputDecoration _fieldDecoration({
    required String hintText,
    required IconData prefixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(color: const Color(0xFF779B96), fontSize: 14.sp),
      prefixIcon: Icon(prefixIcon, color: const Color(0xFF51DFB9)),
      filled: true,
      fillColor: const Color(0xFF082C31),
      contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 14.h),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14.r),
        borderSide: const BorderSide(color: Color(0xFF25645E)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14.r),
        borderSide: const BorderSide(color: Color(0xFF25645E)),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14.r),
        borderSide: const BorderSide(color: Color(0xFF244B48)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14.r),
        borderSide: const BorderSide(color: Color(0xFF54E0BA), width: 1.4),
      ),
    );
  }

  Widget _buildCountrySelector() {
    final disabled = _busy || _isOtpSent;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14.r),
        onTap: disabled ? null : _openCountryPicker,
        child: Ink(
          height: 52.h.clamp(48.0, 56.0),
          padding: EdgeInsets.symmetric(horizontal: 10.w),
          decoration: BoxDecoration(
            color: const Color(0xFF0A3034),
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(
              color: disabled
                  ? const Color(0xFF244B48)
                  : const Color(0xFF28675F),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_selectedCountry.flag, style: TextStyle(fontSize: 16.sp)),

              SizedBox(width: 6.w),

              Text(
                _selectedCountry.dialCode,
                style: TextStyle(
                  color: disabled ? const Color(0xFF71948F) : Colors.white,
                  fontSize: 14.sp.clamp(13.0, 15.0),
                  fontWeight: FontWeight.w600,
                ),
              ),

              SizedBox(width: 2.w),

              Icon(
                Icons.keyboard_arrow_down_rounded,
                color: disabled
                    ? const Color(0xFF567772)
                    : const Color(0xFF58E3BE),
                size: 19,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openCountryPicker() async {
    final selection = await showModalBottomSheet<CountryDialCode>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final searchController = TextEditingController();

        var filtered = List<CountryDialCode>.from(kCountryDialCodes);

        return StatefulBuilder(
          builder: (context, setSheetState) {
            void applySearch(String query) {
              final normalized = query.trim().toLowerCase();

              setSheetState(() {
                if (normalized.isEmpty) {
                  filtered = List<CountryDialCode>.from(kCountryDialCodes);
                } else {
                  filtered = kCountryDialCodes
                      .where((country) => country.matches(normalized))
                      .toList(growable: false);
                }
              });
            }

            return SafeArea(
              top: false,
              child: Container(
                height: MediaQuery.sizeOf(context).height * 0.80,
                decoration: BoxDecoration(
                  color: const Color(0xFF061F24),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(24.r),
                    topRight: Radius.circular(24.r),
                  ),
                  border: Border.all(color: const Color(0xFF28675F)),
                ),
                child: Column(
                  children: [
                    SizedBox(height: 10.h),

                    Container(
                      width: 44.w,
                      height: 4.h,
                      decoration: BoxDecoration(
                        color: const Color(0xFF41736D),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),

                    SizedBox(height: 12.h),

                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.w),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Select country code',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 17.sp.clamp(16.0, 18.0),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(sheetContext).pop(),
                            icon: const Icon(
                              Icons.close,
                              color: Color(0xFF75E5C9),
                            ),
                          ),
                        ],
                      ),
                    ),

                    Padding(
                      padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 12.h),
                      child: TextField(
                        controller: searchController,
                        autofocus: true,
                        style: const TextStyle(color: Colors.white),
                        onChanged: applySearch,
                        decoration: InputDecoration(
                          hintText: 'Search country or code',
                          hintStyle: const TextStyle(color: Color(0xFF769B95)),
                          prefixIcon: const Icon(
                            Icons.search,
                            color: Color(0xFF56E0BC),
                          ),
                          filled: true,
                          fillColor: const Color(0xFF092D32),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14.r),
                            borderSide: const BorderSide(
                              color: Color(0xFF28675F),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14.r),
                            borderSide: const BorderSide(
                              color: Color(0xFF28675F),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14.r),
                            borderSide: const BorderSide(
                              color: Color(0xFF58E3BE),
                              width: 1.4,
                            ),
                          ),
                        ),
                      ),
                    ),

                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                              child: Text(
                                'No countries found',
                                style: TextStyle(
                                  color: const Color(0xFFA3C5C0),
                                  fontSize: 14.sp,
                                ),
                              ),
                            )
                          : ListView.separated(
                              keyboardDismissBehavior:
                                  ScrollViewKeyboardDismissBehavior.onDrag,
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) => Divider(
                                height: 1,
                                color: const Color(
                                  0xFF214744,
                                ).withValues(alpha: 0.8),
                                indent: 16.w,
                                endIndent: 16.w,
                              ),
                              itemBuilder: (context, index) {
                                final country = filtered[index];

                                final selected =
                                    country.isoCode == _selectedCountry.isoCode;

                                return ListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 16.w,
                                    vertical: 1.h,
                                  ),
                                  leading: Text(
                                    country.flag,
                                    style: TextStyle(fontSize: 20.sp),
                                  ),
                                  title: Text(
                                    country.name,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 15.sp,
                                      fontWeight: selected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                    ),
                                  ),
                                  subtitle: Text(
                                    country.isoCode,
                                    style: TextStyle(
                                      color: const Color(0xFF789D97),
                                      fontSize: 12.sp,
                                    ),
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        country.dialCode,
                                        style: TextStyle(
                                          color: const Color(0xFF75E5C9),
                                          fontSize: 14.sp,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      if (selected) ...[
                                        SizedBox(width: 8.w),
                                        const Icon(
                                          Icons.check_circle,
                                          color: Color(0xFF58E3BE),
                                          size: 20,
                                        ),
                                      ],
                                    ],
                                  ),
                                  onTap: () {
                                    Navigator.of(sheetContext).pop(country);
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (selection == null || !mounted) return;

    setState(() {
      _selectedCountry = selection;
      _inlineError = null;
    });

    await _saveCountryIsoCode(selection.isoCode);
  }

  Widget _buildPrimaryButton({
    required String label,
    required VoidCallback? onTap,
  }) {
    final enabled = onTap != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18.r),
        onTap: onTap,
        child: Ink(
          height: 50.h.clamp(46.0, 54.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18.r),
            gradient: enabled
                ? const LinearGradient(
                    colors: [Color(0xFF32D5AD), Color(0xFF087A74)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  )
                : const LinearGradient(
                    colors: [Color(0xFF375A56), Color(0xFF294843)],
                  ),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: const Color(0xFF2AD5AA).withValues(alpha: 0.30),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: _busy
                ? SizedBox(
                    width: 20.w,
                    height: 20.w,
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15.sp.clamp(14.0, 16.0),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Container(
                        width: 24.w.clamp(22.0, 28.0),
                        height: 24.w.clamp(22.0, 28.0),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.60),
                          ),
                        ),
                        child: Icon(
                          Icons.arrow_forward_rounded,
                          color: Colors.white,
                          size: 14.w,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildInlineError() {
    final message = _inlineError;

    if (message == null || message.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(top: 10.h),
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: const Color(0x66391020),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: const Color(0xFFB9556F)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFFF9AAF), size: 18),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: const Color(0xFFFFDCE4),
                fontSize: 12.sp.clamp(12.0, 13.0),
                height: 1.35,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecureAccessRow() {
    return Row(
      children: [
        Expanded(child: Container(height: 1, color: const Color(0xFF28635D))),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 10.w),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.admin_panel_settings_outlined,
                color: Color(0xFF58E3BE),
                size: 17,
              ),
              SizedBox(width: 6.w),
              Text(
                'SECURE ADMIN ACCESS',
                style: TextStyle(
                  color: const Color(0xFF70E7C8),
                  fontSize: 10.sp.clamp(9.5, 11.0),
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.7,
                ),
              ),
            ],
          ),
        ),
        Expanded(child: Container(height: 1, color: const Color(0xFF28635D))),
      ],
    );
  }

  Widget _buildAccountInformation() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: const Color(0xB0062024),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFF285A55)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.shield_outlined, color: Color(0xFF59E2BF), size: 21),

          SizedBox(width: 10.w),

          Expanded(
            child: Text(
              'Access is restricted to authorized Hominode community administrators.',
              style: TextStyle(
                color: const Color(0xFFE0F3EE),
                height: 1.4,
                fontSize: 12.sp.clamp(11.0, 12.0),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _introController.dispose();

    _phone.dispose();
    _mobilePhone.dispose();
    _otp.dispose();

    _mobilePhoneFocusNode.dispose();
    _otpFocusNode.dispose();

    super.dispose();
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          boxShadow: [
            BoxShadow(color: color, blurRadius: 80, spreadRadius: 28),
          ],
        ),
      ),
    );
  }
}
