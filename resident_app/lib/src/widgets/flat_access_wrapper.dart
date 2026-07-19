// lib/src/widgets/flat_access_wrapper.dart
// Flat Access Wrapper - Wraps app content with access control

import 'package:flutter/material.dart';
import '../services/flat_access_control_service.dart';
import '../screens/access_blocked_screen.dart';

class FlatAccessWrapper extends StatelessWidget {
  final Widget child;

  const FlatAccessWrapper({
    Key? key,
    required this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AccessControlResult>(
      stream: FlatAccessControlService.instance.streamFlatAccess(),
      builder: (context, snapshot) {
        // Loading state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // Error state
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red.shade300,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error checking access',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please try again',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // Check access result
        final accessResult = snapshot.data;

        if (accessResult == null || !accessResult.hasAccess) {
          // Access denied - show blocked screen
          return AccessBlockedScreen(
            message: accessResult?.message ?? 
                'Your account is not yet assigned to a flat. Please contact admin.',
          );
        }

        // Access granted - show app content
        return child;
      },
    );
  }
}
