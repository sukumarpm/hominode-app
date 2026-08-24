/// Add New Resident Modal - Simplified Version
/// 
/// A centered overlay modal for adding new residents to the society.
/// No unit number field - residents are added without flat assignment.
/// Flat assignment is done separately via Building Management.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';

// ============================================================================
// RESIDENT MODEL
// ============================================================================

class ResidentModel {
  final String id;
  final String fullName;
  final String phone;
  final String email;
  final int membersCount;
  final String generatedPassword;

  ResidentModel({
    required this.id,
    required this.fullName,
    required this.phone,
    required this.email,
    required this.membersCount,
    required this.generatedPassword,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fullName': fullName,
      'phone': phone,
      'email': email,
      'membersCount': membersCount,
      'generatedPassword': generatedPassword,
    };
  }

  @override
  String toString() {
    return 'ResidentModel(id: $id, fullName: $fullName, phone: $phone, email: $email, membersCount: $membersCount, password: $generatedPassword)';
  }
}

// ============================================================================
// ADD RESIDENT MODAL
// ============================================================================

class AddResidentModal extends StatefulWidget {
  final void Function(ResidentModel resident) onSubmit;

  const AddResidentModal({
    super.key,
    required this.onSubmit,
  });

  /// Show the modal with fade and scale animation
  static Future<void> show(
    BuildContext context, {
    required void Function(ResidentModel resident) onSubmit,
  }) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close',
      barrierColor: const Color(0x59000000),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, animation, secondaryAnimation) {
        return AddResidentModal(onSubmit: onSubmit);
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1.0).animate(
              CurvedAnimation(
                parent: animation,
                curve: Curves.easeOut,
              ),
            ),
            child: child,
          ),
        );
      },
    );
  }

  @override
  State<AddResidentModal> createState() => _AddResidentModalState();
}

class _AddResidentModalState extends State<AddResidentModal> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _membersController = TextEditingController(text: '4');

  bool _isSubmitting = false;
  String _generatedPassword = '';

  @override
  void initState() {
    super.initState();
    _generatePassword();
  }

  /// Generate random password for new resident
  void _generatePassword() {
    final random = Random();
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    _generatedPassword = String.fromCharCodes(
      Iterable.generate(8, (_) => chars.codeUnitAt(random.nextInt(chars.length)))
    );
    setState(() {});
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _membersController.dispose();
    super.dispose();
  }

  bool get _isFormValid {
    if (_fullNameController.text.trim().isEmpty) return false;
    if (_phoneController.text.trim().isEmpty) return false;
    
    final phone = _phoneController.text.trim().replaceAll(RegExp(r'[^\d]'), '');
    if (phone.length < 10) return false;
    
    final email = _emailController.text.trim();
    if (email.isNotEmpty) {
      if (!email.contains('@') || !email.contains('.')) return false;
    }
    
    final members = int.tryParse(_membersController.text.trim());
    if (members == null || members < 1) return false;
    
    return true;
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!_isFormValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all required fields correctly'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await Future.delayed(const Duration(milliseconds: 500));

      final id = 'RES${DateTime.now().millisecondsSinceEpoch}';

      final resident = ResidentModel(
        id: id,
        fullName: _fullNameController.text.trim(),
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim(),
        membersCount: int.parse(_membersController.text.trim()),
        generatedPassword: _generatedPassword,
      );

      if (mounted) {
        widget.onSubmit(resident);
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() {
        _isSubmitting = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to add resident. Please try again.'),
            backgroundColor: Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final keyboardInsets = MediaQuery.of(context).viewInsets;

    return Center(
      child: Container(
        constraints: BoxConstraints(
          maxWidth: screenWidth > 720 ? 720 : screenWidth * 0.92,
          maxHeight: screenHeight * 0.85,
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          elevation: 8,
          shadowColor: Colors.black.withOpacity(0.15),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(),
              Flexible(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.only(
                    bottom: keyboardInsets.bottom > 0
                        ? keyboardInsets.bottom + 12
                        : 20,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                    child: Form(
                      key: _formKey,
                      onChanged: () => setState(() {}),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: 18),
                          _buildFullNameField(),
                          const SizedBox(height: 16),
                          _buildPhoneField(),
                          const SizedBox(height: 16),
                          _buildEmailField(),
                          const SizedBox(height: 16),
                          _buildMembersField(),
                          const SizedBox(height: 24),
                          _buildCredentialsInfo(),
                          const SizedBox(height: 24),
                          _buildSubmitButton(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
      child: Stack(
        children: [
          const Padding(
            padding: EdgeInsets.only(right: 40),
            child: Column(
              children: [
                Text(
                  'Add New Resident',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111111),
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Add a new resident to the society',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: -6,
            right: -6,
            child: InkWell(
              onTap: () => Navigator.of(context).pop(),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                child: const Icon(
                  Icons.close,
                  color: Color(0xFF9CA3AF),
                  size: 22,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFullNameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Full Name',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Color(0xFF111111),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _fullNameController,
          textInputAction: TextInputAction.next,
          style: const TextStyle(
            fontSize: 15,
            color: Color(0xFF111111),
          ),
          decoration: InputDecoration(
            hintText: 'Enter full name',
            hintStyle: const TextStyle(
              fontSize: 15,
              color: Color(0xFFD1D5DB),
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFDC2626)),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFDC2626), width: 2),
            ),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Full name is required';
            }
            if (value.trim().length < 2) {
              return 'Name must be at least 2 characters';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildPhoneField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Phone Number',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Color(0xFF111111),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.next,
          style: const TextStyle(
            fontSize: 15,
            color: Color(0xFF111111),
          ),
          decoration: InputDecoration(
            hintText: '+91 XXXXXX XXXXX',
            hintStyle: const TextStyle(
              fontSize: 15,
              color: Color(0xFFD1D5DB),
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFDC2626)),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFDC2626), width: 2),
            ),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Phone number is required';
            }
            final phone = value.trim().replaceAll(RegExp(r'[^\d]'), '');
            if (phone.length < 10) {
              return 'Phone number must be at least 10 digits';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildEmailField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Email',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Color(0xFF111111),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          style: const TextStyle(
            fontSize: 15,
            color: Color(0xFF111111),
          ),
          decoration: InputDecoration(
            hintText: 'email@example.com',
            hintStyle: const TextStyle(
              fontSize: 15,
              color: Color(0xFFD1D5DB),
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFDC2626)),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFDC2626), width: 2),
            ),
          ),
          validator: (value) {
            if (value != null && value.trim().isNotEmpty) {
              if (!value.contains('@') || !value.contains('.')) {
                return 'Please enter a valid email address';
              }
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildMembersField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Number of Members',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Color(0xFF111111),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _membersController,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
          ],
          style: const TextStyle(
            fontSize: 15,
            color: Color(0xFF111111),
          ),
          decoration: InputDecoration(
            hintText: '4',
            hintStyle: const TextStyle(
              fontSize: 15,
              color: Color(0xFFD1D5DB),
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFDC2626)),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFDC2626), width: 2),
            ),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Number of members is required';
            }
            final number = int.tryParse(value.trim());
            if (number == null || number < 1) {
              return 'Must be at least 1 member';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildCredentialsInfo() {
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final username = email.isNotEmpty ? email : phone;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.auto_awesome,
            color: Color(0xFF1D4ED8),
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Login credentials:',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1D4ED8),
                  ),
                ),
                const SizedBox(height: 8),
                _buildBulletPoint(
                  username.isNotEmpty 
                      ? 'Username: $username (Email/Phone)'
                      : 'Username: Email or Phone (enter above)'
                ),
                const SizedBox(height: 4),
                _buildBulletPoint('Password: $_generatedPassword (auto-generated)'),
                const SizedBox(height: 8),
                const Text(
                  'Credentials will be sent via SMS/Email',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF1D4ED8),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBulletPoint(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '• ',
          style: TextStyle(
            fontSize: 14,
            color: Color(0xFF1D4ED8),
            height: 1.5,
          ),
        ),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF1D4ED8),
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    final isEnabled = _isFormValid && !_isSubmitting;

    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: isEnabled ? _handleSubmit : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2563EB),
          disabledBackgroundColor: const Color(0x662563EB),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: _isSubmitting
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Text(
                'Add Resident',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }
}
