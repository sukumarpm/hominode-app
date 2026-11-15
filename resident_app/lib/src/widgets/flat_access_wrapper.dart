import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../screens/access_blocked_screen.dart';
import '../screens/simple_login_screen.dart';
import '../services/flat_access_control_service.dart';

/// Wraps child widgets to enforce live flat and resident lifecycle access.
class FlatAccessWrapper extends StatefulWidget {
  final Widget child;
  final Stream<AccessControlResult>? accessStream;
  final Duration verificationTimeout;

  const FlatAccessWrapper({
    super.key,
    required this.child,
    this.accessStream,
    this.verificationTimeout = const Duration(seconds: 15),
  });

  @override
  State<FlatAccessWrapper> createState() => _FlatAccessWrapperState();
}

class _FlatAccessWrapperState extends State<FlatAccessWrapper> {
  late Stream<AccessControlResult> _accessStream;
  bool _identityRedirectScheduled = false;
  Timer? _verificationTimer;
  bool _verificationTimedOut = false;

  @override
  void initState() {
    super.initState();
    _accessStream =
        widget.accessStream ??
        FlatAccessControlService.instance.streamFlatAccess();
  }

  @override
  void didUpdateWidget(covariant FlatAccessWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.accessStream != widget.accessStream) {
      _resetVerification();
      _accessStream =
          widget.accessStream ??
          FlatAccessControlService.instance.streamFlatAccess();
    }
  }

  void _resetVerification() {
    _verificationTimer?.cancel();
    _verificationTimer = null;
    _verificationTimedOut = false;
  }

  @override
  void dispose() {
    _verificationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AccessControlResult>(
      stream: _accessStream,
      builder: (context, snapshot) {
        if (!snapshot.hasError &&
            (snapshot.connectionState == ConnectionState.waiting ||
                snapshot.data?.state == FlatAccessState.verifying)) {
          _verificationTimer ??= Timer(widget.verificationTimeout, () {
            if (mounted) setState(() => _verificationTimedOut = true);
          });
          if (_verificationTimedOut) return _buildTransientError();
          return Scaffold(
            backgroundColor: const Color(0xFF06182B),
            body: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  'lib/assets/images/resident_login_background.png',
                  fit: BoxFit.cover,
                ),
                Container(
                  color: const Color(0xFF06182B).withValues(alpha: 0.18),
                ),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        'lib/assets/branding/resident_transparent.png',
                        width: 130,
                        height: 130,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 24),
                      const SizedBox(
                        width: 32,
                        height: 32,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: Color(0xFF31D6E5),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        _resetVerification();
        final result = snapshot.data;
        if (snapshot.hasError) {
          return FlatAccessControlService.failureResult(
                snapshot.error!,
              ).isTransient
              ? _buildTransientError()
              : _buildMembershipError();
        }

        if (result?.isTransient == true) {
          return _buildTransientError();
        }

        if (result == null || result.state == FlatAccessState.error) {
          return _buildMembershipError();
        }
        if (result.state == FlatAccessState.unauthenticated) {
          return const SimpleLoginScreen();
        }
        if (result.state == FlatAccessState.denied) {
          if (result.identityVerificationRequired) {
            if (!_identityRedirectScheduled) {
              _identityRedirectScheduled = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                Navigator.of(context).pushNamedAndRemoveUntil(
                  '/resident-identity-verification',
                  (_) => false,
                );
              });
            }
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          return AccessBlockedScreen(
            message:
                result.message ??
                'Your account is not yet assigned to a flat. Please contact admin.',
          );
        }
        return widget.child;
      },
    );
  }

  Widget _buildMembershipError() => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'community_resolution_error'.tr(),
          textAlign: TextAlign.center,
        ),
      ),
    ),
  );

  Widget _buildTransientError() => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('community_access_error'.tr(), textAlign: TextAlign.center),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _retryAccessCheck,
              icon: const Icon(Icons.refresh),
              label: Text('retry'.tr()),
            ),
          ],
        ),
      ),
    ),
  );

  void _retryAccessCheck() {
    setState(() {
      _resetVerification();
      _accessStream =
          widget.accessStream ??
          FlatAccessControlService.instance.streamFlatAccess();
    });
  }
}
