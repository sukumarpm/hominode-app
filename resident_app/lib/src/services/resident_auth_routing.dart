import 'package:flutter/material.dart';

import 'firebase_auth_service.dart';

class ResidentAuthRouting {
  const ResidentAuthRouting._();

  /// Resolves the destination route name based on the authentication result.
  static String routeFor(AuthResult result) {
    if (!result.success && result.state == ResidentAuthState.failed) {
      return '/login';
    }

    switch (result.state) {
      case ResidentAuthState.approved:
        return '/home';
      case ResidentAuthState.registrationRequired:
        return '/resident-registration';
      case ResidentAuthState.pendingApproval:
        return '/awaiting-approval';
      case ResidentAuthState.rejected:
      case ResidentAuthState.blocked:
      case ResidentAuthState.flatAssignmentRequired:
        return '/resident-access-blocked';
      case ResidentAuthState.failed:
        return '/login';
    }
  }

  /// Executes safe root navigation, clearing the stack and passing AuthResult data.
  static void navigateToResult(BuildContext context, AuthResult result) {
    final routeName = routeFor(result);

    Navigator.of(context).pushNamedAndRemoveUntil(
      routeName,
      (route) => false,
      arguments: result.message,
    );
  }
}
