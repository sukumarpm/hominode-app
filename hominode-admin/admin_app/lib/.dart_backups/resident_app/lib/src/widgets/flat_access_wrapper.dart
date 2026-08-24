import 'package:flutter/material.dart';
import '../screens/access_blocked_screen.dart';
import '../screens/simple_login_screen.dart';
import '../services/flat_access_control_service.dart';

/// Wraps child widgets to enforce flat/resident access control.
class FlatAccessWrapper extends StatelessWidget {
  final Widget child;

  const FlatAccessWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AccessControlResult>(
      stream: FlatAccessControlService.instance.streamFlatAccess(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
              ),
            ),
          );
        }

        final result = snapshot.data;
        if (result == null || result.state == FlatAccessState.error) {
          return Scaffold(
            body: Center(
              child: Text(result?.message ?? 'Unable to check flat access.'),
            ),
          );
        }
        if (result.state == FlatAccessState.unauthenticated) {
          return const SimpleLoginScreen();
        }
        if (result.state == FlatAccessState.denied) {
          return AccessBlockedScreen(
            message:
                result.message ??
                'Your account is not yet assigned to a flat. Please contact admin.',
          );
        }
        return child;
      },
    );
  }
}
