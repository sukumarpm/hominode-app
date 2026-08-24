import 'package:flutter/material.dart';

class RolePalette {
  const RolePalette({
    required this.primary,
    required this.dark,
    required this.soft,
  });

  final Color primary;
  final Color dark;
  final Color soft;

  LinearGradient get gradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [dark, primary],
  );

  static const superAdmin = RolePalette(
    primary: Color(0xFF1558D6),
    dark: Color(0xFF071E4D),
    soft: Color(0xFFEAF1FF),
  );
  static const admin = RolePalette(
    primary: Color(0xFF008C72),
    dark: Color(0xFF004D43),
    soft: Color(0xFFE7F8F3),
  );
  static const resident = RolePalette(
    primary: Color(0xFF6B35D4),
    dark: Color(0xFF2D126B),
    soft: Color(0xFFF1EBFF),
  );
}

abstract final class WebDesign {
  static const background = Color(0xFFF5F7FB);
  static const border = Color(0xFFE6EAF1);
  static const text = Color(0xFF0B1B3B);
  static const muted = Color(0xFF667085);
  static const radius = 14.0;
  static const pagePadding = 20.0;

  static const shadow = BoxShadow(
    color: Color(0x0A0B1B3B),
    blurRadius: 18,
    offset: Offset(0, 5),
  );
}
