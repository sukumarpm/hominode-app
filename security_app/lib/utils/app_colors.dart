import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ============================================================
  // SECURITY BRAND COLORS
  // ============================================================

  static const Color darkEmerald = Color(0xFF063D35);
  static const Color primaryTeal = Color(0xFF0B6B5A);
  static const Color accentTeal = Color(0xFF14B8A6);

  static const Color goldAccent = Color(0xFFD4A72C);
  static const Color softGoldBackground = Color(0xFFFFF7DD);

  // ============================================================
  // STATUS COLORS
  // ============================================================

  static const Color successGreen = Color(0xFF16A86B);
  static const Color warningOrange = Color(0xFFF59E0B);
  static const Color errorRed = Color(0xFFEF4444);

  // Optional legacy status/accent
  static const Color purple = Color(0xFF9333EA);

  // ============================================================
  // NEUTRAL COLORS
  // ============================================================

  static const Color background = Color(0xFFF5F8F7);
  static const Color cardWhite = Color(0xFFFFFFFF);
  static const Color cardBackground = Color(0xFFFFFFFF);

  static const Color textDark = Color(0xFF16211F);
  static const Color textGray = Color(0xFF6B7774);

  static const Color borderGray = Color(0xFFDCE7E3);
  static const Color divider = Color(0xFFDCE7E3);

  static const Color lightGray = Color(0xFFF5F8F7);

  // ============================================================
  // LEGACY COMPATIBILITY ALIASES
  // ============================================================
  // Keep these so existing Security screens compile while
  // we migrate them gradually to the new emerald/teal theme.

  static const Color primaryBlue = primaryTeal;
  static const Color darkBlue = darkEmerald;
}
