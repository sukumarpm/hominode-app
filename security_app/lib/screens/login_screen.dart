import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/country_dial_codes.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  static const String _countryPreferenceWriteKey =
      'security_login_country_iso2';
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

  final AuthService _authService = AuthService();

  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  final FocusNode _phoneFocusNode = FocusNode();
  final FocusNode _otpFocusNode = FocusNode();

  late final AnimationController _introController;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _logoScaleAnimation;
  late final Animation<Offset> _cardSlideAnimation;

  bool _otpSent = false;
  bool _loading = false;

  String? _verificationId;
  String? _inlineError;
  String? _sentPhone;
  CountryDialCode _selectedCountry = _defaultCountry;

  @override
  void initState() {
    super.initState();
    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    final curve = CurvedAnimation(
      parent: _introController,
      curve: Curves.easeOutCubic,
    );
    _fadeAnimation = Tween<double>(begin: 1.0, end: 1.0).animate(curve);
    _logoScaleAnimation = Tween<double>(begin: 0.92, end: 1.0).animate(curve);
    _cardSlideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.08),
      end: Offset.zero,
    ).animate(curve);
    _introController.forward();
    _initializeCountrySelection();
  }

  @override
  void dispose() {
    _introController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    _phoneFocusNode.dispose();
    _otpFocusNode.dispose();
    super.dispose();
  }

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
    setState(() => _selectedCountry = selected);
  }

  CountryDialCode? _countryByIso(String? isoCode) {
    if (isoCode == null || isoCode.trim().isEmpty) return null;
    final upper = isoCode.toUpperCase();
    for (final country in kCountryDialCodes) {
      if (country.isoCode == upper) {
        return country;
      }
    }
    return null;
  }

  Future<void> _saveCountryIsoCode(String isoCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_countryPreferenceWriteKey, isoCode.toUpperCase());
  }

  String _composeCanonicalPhone() {
    final raw = _phoneController.text.trim();
    if (raw.isEmpty) return '';

    if (raw.startsWith('+')) {
      final digits = raw.substring(1).replaceAll(RegExp(r'\D'), '');
      return digits.isEmpty ? '' : '+$digits';
    }

    final dialDigits = _selectedCountry.dialCode.substring(1);
    var localDigits = raw.replaceAll(RegExp(r'\D'), '');
    if (localDigits.startsWith(dialDigits)) {
      localDigits = localDigits.substring(dialDigits.length);
    }
    localDigits = localDigits.replaceFirst(RegExp(r'^0+'), '');

    return '${_selectedCountry.dialCode}$localDigits';
  }

  void _showInlineError(String message) {
    final value = message.trim();
    if (value.isEmpty) return;
    setState(() => _inlineError = value);
  }

  Future<void> _sendOtp() async {
    if (_loading) return;

    FocusScope.of(context).unfocus();
    final phone = _composeCanonicalPhone();

    if (!RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(phone)) {
      _showInlineError('Enter a valid phone number.');
      return;
    }

    setState(() {
      _loading = true;
      _inlineError = null;
    });

    try {
      final result = await _authService.sendOtp(phone);

      if (!mounted) return;

      if (result.autoVerified) {
        HapticFeedback.mediumImpact();
        setState(() => _loading = false);
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
        _sentPhone = phone;
        _otpSent = true;
        _loading = false;
      });
    } on SecurityAuthException catch (e) {
      if (!mounted) return;
      _showInlineError(e.message);
    } catch (_) {
      if (!mounted) return;
      _showInlineError('Unable to send OTP. Please try again.');
    } finally {
      if (mounted && _loading) {
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
      _showInlineError('Request a new OTP.');
      return;
    }

    if (!RegExp(r'^\d{6}$').hasMatch(otp)) {
      _showInlineError('Enter the 6-digit OTP.');
      return;
    }

    setState(() {
      _loading = true;
      _inlineError = null;
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
      _showInlineError(e.message);
      if (e.code == 'invalid-verification-code') {
        _otpController.clear();
        _otpFocusNode.requestFocus();
      }
    } catch (_) {
      if (!mounted) return;
      _showInlineError('An error occurred. Please try again.');
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
      _inlineError = null;
    });
    _otpFocusNode.unfocus();
    _phoneFocusNode.requestFocus();
  }

  Future<void> _resendOtp() async {
    await _sendOtp();
    if (!mounted || !_otpSent) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('OTP resent successfully'),
        backgroundColor: Color(0xFF10B981),
      ),
    );
  }

  void _showContactAdmin() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF081B3C),
        title: const Text(
          'Contact Admin',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Your Security account is created and managed by your Community Admin. Contact your Community Admin if you cannot access your account.',
          style: TextStyle(color: Color(0xFFB8D7F6), height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildCountrySelector() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: _loading ? null : _openCountryPicker,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF0A2247),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _loading
                  ? const Color(0xFF18406B)
                  : const Color(0xFF1A4E83),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_selectedCountry.flag, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 6),
              Text(
                _selectedCountry.dialCode,
                style: TextStyle(
                  color: _loading ? const Color(0xFF8BA9C8) : Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                color: _loading
                    ? const Color(0xFF6B89AC)
                    : const Color(0xFF7ADFFF),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openCountryPicker() async {
    final insets = MediaQuery.of(context).viewInsets;
    final selection = await showModalBottomSheet<CountryDialCode>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final searchController = TextEditingController();
        var filteredCountries = List<CountryDialCode>.from(kCountryDialCodes);

        return StatefulBuilder(
          builder: (context, setSheetState) {
            void applySearch(String query) {
              final normalized = query.trim().toLowerCase();
              setSheetState(() {
                if (normalized.isEmpty) {
                  filteredCountries = List<CountryDialCode>.from(
                    kCountryDialCodes,
                  );
                } else {
                  filteredCountries = kCountryDialCodes
                      .where((country) => country.matches(normalized))
                      .toList(growable: false);
                }
              });
            }

            return SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.only(bottom: insets.bottom),
                child: Container(
                  height: MediaQuery.of(context).size.height * 0.82,
                  decoration: BoxDecoration(
                    color: const Color(0xFF061A36),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                    border: Border.all(color: const Color(0xFF1A4E83)),
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 10),
                      Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFF2D5B88),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Select country code',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.of(sheetContext).pop(),
                              icon: const Icon(
                                Icons.close,
                                color: Color(0xFF89CAFF),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                        child: TextField(
                          controller: searchController,
                          style: const TextStyle(color: Colors.white),
                          onChanged: applySearch,
                          decoration: InputDecoration(
                            hintText: 'Search country or code',
                            hintStyle: const TextStyle(
                              color: Color(0xFF7AA4CF),
                            ),
                            prefixIcon: const Icon(
                              Icons.search,
                              color: Color(0xFF34D9FF),
                            ),
                            suffixIcon: searchController.text.isEmpty
                                ? null
                                : IconButton(
                                    onPressed: () {
                                      searchController.clear();
                                      applySearch('');
                                    },
                                    icon: const Icon(
                                      Icons.clear,
                                      color: Color(0xFF9EC8FF),
                                    ),
                                  ),
                            filled: true,
                            fillColor: const Color(0xFF082347),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: Color(0xFF1A5E96),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: Color(0xFF1A5E96),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: Color(0xFF33D6FF),
                                width: 1.4,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: filteredCountries.isEmpty
                            ? const Center(
                                child: Text(
                                  'No countries found',
                                  style: TextStyle(
                                    color: Color(0xFF9EC8FF),
                                    fontSize: 14,
                                  ),
                                ),
                              )
                            : ListView.separated(
                                keyboardDismissBehavior:
                                    ScrollViewKeyboardDismissBehavior.onDrag,
                                itemCount: filteredCountries.length,
                                separatorBuilder: (_, __) => Divider(
                                  height: 1,
                                  color: const Color(
                                    0xFF1C3E65,
                                  ).withValues(alpha: 0.7),
                                  indent: 16,
                                  endIndent: 16,
                                ),
                                itemBuilder: (context, index) {
                                  final country = filteredCountries[index];
                                  final isSelected =
                                      country.isoCode ==
                                      _selectedCountry.isoCode;
                                  return ListTile(
                                    dense: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 1,
                                    ),
                                    title: Row(
                                      children: [
                                        Text(
                                          country.flag,
                                          style: const TextStyle(fontSize: 20),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            country.name,
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 15,
                                              fontWeight: isSelected
                                                  ? FontWeight.w700
                                                  : FontWeight.w500,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          country.dialCode,
                                          style: const TextStyle(
                                            color: Color(0xFF7ADFFF),
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                    subtitle: const SizedBox.shrink(),
                                    trailing: isSelected
                                        ? const Icon(
                                            Icons.check_circle,
                                            color: Color(0xFF31D5FF),
                                          )
                                        : null,
                                    onTap: () =>
                                        Navigator.of(sheetContext).pop(country),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (selection == null || !mounted) return;
    setState(() => _selectedCountry = selection);
    await _saveCountryIsoCode(selection.isoCode);
  }

  Widget _buildInlineError() {
    if (_inlineError == null) {
      return const SizedBox.shrink();
    }
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFDEBEC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFF5B5BB)),
      ),
      child: Text(
        _inlineError!,
        style: const TextStyle(
          color: Color(0xFFB42318),
          fontSize: 13,
          height: 1.35,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildPrimaryButton({
    required String label,
    required VoidCallback? onTap,
  }) {
    final enabled = onTap != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Ink(
          height: 50,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: enabled
                ? const LinearGradient(
                    colors: [Color(0xFF35D8FF), Color(0xFF0F65FF)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  )
                : const LinearGradient(
                    colors: [Color(0xFF335B6B), Color(0xFF2B4570)],
                  ),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: const Color(0xFF22D2FF).withValues(alpha: 0.35),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: _loading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.65),
                          ),
                        ),
                        child: const Icon(
                          Icons.arrow_forward,
                          color: Colors.white,
                          size: 14,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildSecureAccessRow() {
    return Row(
      children: [
        Expanded(
          child: Divider(
            color: const Color(0xFF2D5B88).withValues(alpha: 0.8),
            thickness: 1,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: const [
              Icon(Icons.shield_outlined, size: 18, color: Color(0xFF3ED9FF)),
              SizedBox(width: 8),
              Text(
                'SECURE SECURITY ACCESS',
                style: TextStyle(
                  color: Color(0xFF66E5FF),
                  fontSize: 12,
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Divider(
            color: const Color(0xFF2D5B88).withValues(alpha: 0.8),
            thickness: 1,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.of(context).viewInsets;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'lib/assets/images/security_login_background.png',
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
            ),
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xAA02102B),
                    Color(0xCC031632),
                    Color(0xE603132D),
                  ],
                ),
              ),
            ),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final cardMaxWidth = constraints.maxWidth > 620
                      ? 520.0
                      : 600.0;
                  final logoWidth = (constraints.maxWidth * 0.35).clamp(
                    120.0,
                    210.0,
                  );

                  return SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.fromLTRB(
                      20,
                      12,
                      20,
                      (insets.bottom + 16).clamp(16.0, 220.0),
                    ),
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: Column(
                        children: [
                          ScaleTransition(
                            scale: _logoScaleAnimation,
                            child: Column(
                              children: [
                                const SizedBox(height: 2),
                                Image.asset(
                                  'lib/assets/Security_New.png',
                                  width: logoWidth,
                                  fit: BoxFit.contain,
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'HOMINODE',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    letterSpacing: 1.8,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                const Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(
                                        text: 'Smart ',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      TextSpan(
                                        text: 'place. Better lives.',
                                        style: TextStyle(
                                          color: Color(0xFF30D3FF),
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(999),
                                    color: const Color(0x1A3DD2FF),
                                    border: Border.all(
                                      color: const Color(0x6633D9FF),
                                    ),
                                  ),
                                  child: const Text(
                                    'Security Access',
                                    style: TextStyle(
                                      color: Color(0xFF88E8FF),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          SlideTransition(
                            position: _cardSlideAnimation,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: cardMaxWidth,
                              ),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xCC061B3B),
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                    color: const Color(0xFF1E5E99),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(
                                        0xFF28CFFF,
                                      ).withValues(alpha: 0.25),
                                      blurRadius: 26,
                                      offset: const Offset(0, 14),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Text(
                                      _otpSent
                                          ? 'Verify OTP'
                                          : 'Sign in with OTP',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      _otpSent
                                          ? 'Code sent to ${_sentPhone ?? _composeCanonicalPhone()}'
                                          : 'Use your Admin-registered Security phone number.',
                                      style: const TextStyle(
                                        color: Color(0xFF9EC8FF),
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    if (!_otpSent) ...[
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          _buildCountrySelector(),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: TextField(
                                              controller: _phoneController,
                                              focusNode: _phoneFocusNode,
                                              readOnly: _loading,
                                              keyboardType: TextInputType.phone,
                                              textInputAction:
                                                  TextInputAction.done,
                                              onChanged: (_) {
                                                if (_inlineError != null) {
                                                  setState(
                                                    () => _inlineError = null,
                                                  );
                                                }
                                              },
                                              onSubmitted: (_) => _sendOtp(),
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 15,
                                                fontWeight: FontWeight.w500,
                                              ),
                                              decoration: InputDecoration(
                                                hintText: '912 345 6789',
                                                hintStyle: const TextStyle(
                                                  color: Color(0xFF7AA4CF),
                                                  fontSize: 14,
                                                ),
                                                filled: true,
                                                fillColor: const Color(
                                                  0xFF081E40,
                                                ),
                                                prefixIcon: const Icon(
                                                  Icons.phone,
                                                  color: Color(0xFF2FD5FF),
                                                ),
                                                border: OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(14),
                                                  borderSide: const BorderSide(
                                                    color: Color(0xFF1A5E96),
                                                  ),
                                                ),
                                                enabledBorder:
                                                    OutlineInputBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            14,
                                                          ),
                                                      borderSide:
                                                          const BorderSide(
                                                            color: Color(
                                                              0xFF1A5E96,
                                                            ),
                                                          ),
                                                    ),
                                                focusedBorder:
                                                    OutlineInputBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            14,
                                                          ),
                                                      borderSide:
                                                          const BorderSide(
                                                            color: Color(
                                                              0xFF33D6FF,
                                                            ),
                                                            width: 1.4,
                                                          ),
                                                    ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 14),
                                      _buildPrimaryButton(
                                        label: 'Send OTP',
                                        onTap: _loading ? null : _sendOtp,
                                      ),
                                    ] else ...[
                                      Align(
                                        alignment: Alignment.centerLeft,
                                        child: TextButton(
                                          onPressed: _loading
                                              ? null
                                              : _changeNumber,
                                          style: TextButton.styleFrom(
                                            padding: EdgeInsets.zero,
                                            minimumSize: const Size(0, 30),
                                            tapTargetSize: MaterialTapTargetSize
                                                .shrinkWrap,
                                            foregroundColor: const Color(
                                              0xFF54DFFF,
                                            ),
                                          ),
                                          child: const Text(
                                            'Wrong number? Change number',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ),
                                      TextField(
                                        controller: _otpController,
                                        focusNode: _otpFocusNode,
                                        enabled: !_loading,
                                        keyboardType: TextInputType.number,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 20,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 6,
                                        ),
                                        inputFormatters: [
                                          FilteringTextInputFormatter
                                              .digitsOnly,
                                          LengthLimitingTextInputFormatter(6),
                                        ],
                                        decoration: InputDecoration(
                                          hintText: '------',
                                          hintStyle: const TextStyle(
                                            color: Color(0xFF7AA4CF),
                                            letterSpacing: 6,
                                          ),
                                          filled: true,
                                          fillColor: const Color(0xFF081E40),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                            borderSide: const BorderSide(
                                              color: Color(0xFF1A5E96),
                                            ),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                            borderSide: const BorderSide(
                                              color: Color(0xFF1A5E96),
                                            ),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                            borderSide: const BorderSide(
                                              color: Color(0xFF33D6FF),
                                              width: 1.4,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 14),
                                      _buildPrimaryButton(
                                        label: 'Verify OTP',
                                        onTap: _loading ? null : _verifyOtp,
                                      ),
                                      const SizedBox(height: 6),
                                      Align(
                                        alignment: Alignment.center,
                                        child: TextButton(
                                          onPressed: _loading
                                              ? null
                                              : _resendOtp,
                                          style: TextButton.styleFrom(
                                            minimumSize: const Size(0, 30),
                                            tapTargetSize: MaterialTapTargetSize
                                                .shrinkWrap,
                                            foregroundColor: const Color(
                                              0xFF68E5FF,
                                            ),
                                          ),
                                          child: const Text(
                                            'Resend OTP',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                    _buildInlineError(),
                                    const SizedBox(height: 10),
                                    _buildSecureAccessRow(),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: cardMaxWidth),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xA8071A38),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFF1B4679),
                                ),
                              ),
                              child: const Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.shield_outlined,
                                    color: Color(0xFF32D8FF),
                                  ),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Your Security account must already be created by your Community Admin.',
                                      style: TextStyle(
                                        color: Color(0xFFE5F4FF),
                                        height: 1.4,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextButton(
                            onPressed: _showContactAdmin,
                            child: const Text(
                              'Need help? Contact Admin',
                              style: TextStyle(
                                color: Color(0xFF6CE2FF),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
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
}
