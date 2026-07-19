import 'package:flutter/material.dart';

/// Centralized styles and constants for onboarding flow
/// Matches the exact design specifications from reference images
class OnboardingStyles {
  // Color palette
  static const Color primaryBlue = Color(0xFF2563EB);
  static const Color primaryBlueDark = Color(0xFF1E40AF);
  static const Color backgroundColor = Color(0xFFF7F7F7);
  static const Color textPrimary = Color(0xFF111111);
  static const Color textSecondary = Color(0xFF666666);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      primaryBlue,
      primaryBlueDark,
    ],
  );

  // Typography
  static const TextStyle titleTextStyle = TextStyle(
    fontSize: 34,
    fontWeight: FontWeight.w700,
    fontStyle: FontStyle.italic,
    color: textPrimary,
    height: 1.2,
    letterSpacing: -0.5,
  );

  static const TextStyle subtitleTextStyle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: textSecondary,
    height: 1.5,
    letterSpacing: 0,
  );

  static const TextStyle buttonTextStyle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: Colors.white,
    letterSpacing: 0.2,
  );

  static const TextStyle skipTextStyle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: textPrimary,
    letterSpacing: 0,
  );

  // Spacing
  static const double horizontalPadding = 16.0;
  static const double cardBorderRadius = 20.0;
  static const double buttonBorderRadius = 12.0;
  static const double buttonHeight = 56.0;

  // Animation durations
  static const Duration pageTransitionDuration = Duration(milliseconds: 350);
  static const Duration cardAnimationDuration = Duration(milliseconds: 600);
  static const Duration buttonAnimationDuration = Duration(milliseconds: 200);
}
