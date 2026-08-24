/// Send Notice Dialog
///
/// A centered overlay modal for sending notices to residents.
/// Matches the admin app visual system with blue theme and rounded cards.
///
/// Usage:
/// ```dart
/// SendNoticeDialog.show(
///   context,
///   residentName: 'Rajesh Kumar',
///   unitNumber: 'A-204',
///   onSent: (notice) {
///     setState(() => notices.add(notice));
///     ScaffoldMessenger.of(context).showSnackBar(
///       SnackBar(content: Text('Notice sent to Rajesh Kumar')),
///     );
///   },
/// );
/// ```
library;

import 'package:flutter/material.dart';
import '../models/notice.dart';

// ============================================================================
// SEND NOTICE DIALOG
// ============================================================================

class SendNoticeDialog extends StatefulWidget {
  final String residentName;
  final String unitNumber;
  final void Function(Notice notice) onSent;

  const SendNoticeDialog({
    super.key,
    required this.residentName,
    required this.unitNumber,
    required this.onSent,
  });

  /// Show the dialog with fade and scale animation
  static Future<void> show(
    BuildContext context, {
    required String residentName,
    required String unitNumber,
    required void Function(Notice notice) onSent,
  }) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close',
      barrierColor: const Color(0x59000000), // rgba(0, 0, 0, 0.35)
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, animation, secondaryAnimation) {
        return SendNoticeDialog(
          residentName: residentName,
          unitNumber: unitNumber,
          onSent: onSent,
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOut),
            ),
            child: child,
          ),
        );
      },
    );
  }

  @override
  State<SendNoticeDialog> createState() => _SendNoticeDialogState();
}

class _SendNoticeDialogState extends State<SendNoticeDialog> {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();

  NoticePriority _selectedPriority = NoticePriority.normal;
  bool _isSending = false;
  String? _errorMessage;

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  bool get _isFormValid {
    // Message is required and must be at least 5 characters
    if (_messageController.text.trim().isEmpty ||
        _messageController.text.trim().length < 5) {
      return false;
    }

    // Subject is optional but if provided, max 120 characters
    if (_subjectController.text.trim().length > 120) {
      return false;
    }

    return true;
  }

  Future<void> _handleSend() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!_isFormValid) {
      setState(() {
        _errorMessage = 'Please fill in all required fields correctly';
      });
      return;
    }

    setState(() {
      _isSending = true;
      _errorMessage = null;
    });

    try {
      // Simulate API call
      // TODO: Replace with real API call (POST /notices)
      await Future.delayed(const Duration(milliseconds: 800));

      // Generate notice ID
      final id = 'NOT${DateTime.now().millisecondsSinceEpoch}';

      final notice = Notice(
        id: id,
        subject: _subjectController.text.trim(),
        message: _messageController.text.trim(),
        priority: _selectedPriority,
        dateCreated: DateTime.now(),
        recipientResidentId: null, // TODO: Add resident ID
      );

      // TODO: Add audit logging (who sent notice)
      // TODO: Hook push notifications / SMS provider

      if (mounted) {
        widget.onSent(notice);
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() {
        _isSending = false;
        _errorMessage = 'Failed to send notice. Please try again.';
      });
    }
  }

  void _showPriorityPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Select Priority',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF111111),
                ),
              ),
              const SizedBox(height: 16),
              ...NoticePriority.values.map((priority) {
                final isSelected = priority == _selectedPriority;

                return InkWell(
                  onTap: () {
                    setState(() {
                      _selectedPriority = priority;
                    });
                    Navigator.of(context).pop();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFFEFF6FF)
                          : Colors.white,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          priority.label,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: isSelected
                                ? const Color(0xFF0E4778)
                                : const Color(0xFF111111),
                          ),
                        ),
                        if (isSelected)
                          const Icon(
                            Icons.check_circle,
                            color: Color(0xFF0E4778),
                            size: 22,
                          ),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
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
          maxHeight: screenHeight * 0.80,
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
                          if (_errorMessage != null) ...[
                            const SizedBox(height: 12),
                            _buildErrorBanner(),
                          ],
                          const SizedBox(height: 18),
                          _buildSubjectField(),
                          const SizedBox(height: 16),
                          _buildPriorityField(),
                          const SizedBox(height: 16),
                          _buildMessageField(),
                          const SizedBox(height: 16),
                          _buildInfoBanner(),
                          const SizedBox(height: 20),
                          _buildSendButton(),
                          const SizedBox(height: 10),
                          _buildCancelButton(),
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
          Padding(
            padding: const EdgeInsets.only(right: 40),
            child: Column(
              children: [
                const Text(
                  'Send Notice',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111111),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Send a notice to ${widget.residentName} (${widget.unitNumber})',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
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
            child: Semantics(
              label: 'Close',
              button: true,
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
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _errorMessage!,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFFDC2626),
              ),
            ),
          ),
          InkWell(
            onTap: () => setState(() => _errorMessage = null),
            child: const Icon(Icons.close, color: Color(0xFFDC2626), size: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Subject',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Color(0xFF111111),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _subjectController,
          textInputAction: TextInputAction.next,
          style: const TextStyle(fontSize: 15, color: Color(0xFF111111)),
          decoration: InputDecoration(
            hintText: 'Enter notice Subject',
            hintStyle: const TextStyle(fontSize: 15, color: Color(0xFFB9BDC1)),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE6E9EC)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE6E9EC)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF0E4778), width: 2),
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
            if (value != null && value.trim().length > 120) {
              return 'Subject must be 120 characters or less';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildPriorityField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Priority',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Color(0xFF111111),
          ),
        ),
        const SizedBox(height: 8),
        Semantics(
          label: 'Select priority',
          button: true,
          child: InkWell(
            onTap: _showPriorityPicker,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: const Color(0xFFE6E9EC)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _selectedPriority.label,
                    style: const TextStyle(
                      fontSize: 15,
                      color: Color(0xFFB9BDC1),
                    ),
                  ),
                  const Icon(
                    Icons.keyboard_arrow_down,
                    color: Color(0xFF9CA3AF),
                    size: 24,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMessageField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            Text(
              'Message',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF111111),
              ),
            ),
            SizedBox(width: 4),
            Text(
              '*',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFFDC2626),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _messageController,
          maxLines: 6,
          textInputAction: TextInputAction.newline,
          style: const TextStyle(fontSize: 15, color: Color(0xFF111111)),
          decoration: InputDecoration(
            hintText: 'Type your notice message here .....',
            hintStyle: const TextStyle(fontSize: 15, color: Color(0xFFB9BDC1)),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE6E9EC)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE6E9EC)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF0E4778), width: 2),
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
              return 'Message is required';
            }
            if (value.trim().length < 5) {
              return 'Message must be at least 5 characters';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: const [
          Icon(Icons.info_outline, color: Color(0xFF0E4778), size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Notice will be sent via SMS and Email',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF0E4778),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSendButton() {
    final isEnabled = _isFormValid && !_isSending;

    return Semantics(
      label: 'Send notice',
      button: true,
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton(
          onPressed: isEnabled ? _handleSend : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0E4778),
            disabledBackgroundColor: const Color(0x662563EB), // 40% opacity
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: _isSending
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text(
                  'Send Notice',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                ),
        ),
      ),
    );
  }

  Widget _buildCancelButton() {
    return Semantics(
      label: 'Cancel',
      button: true,
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: OutlinedButton(
          onPressed: _isSending ? null : () => Navigator.of(context).pop(),
          style: OutlinedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF111111),
            side: const BorderSide(color: Color(0xFFE5E7EB)),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: const Text(
            'Cancel',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}
