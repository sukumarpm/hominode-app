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
  static const background = Color(0xFFF6F8FC);
  static const border = Color(0xFFE8ECF3);
  static const text = Color(0xFF0A1837);
  static const muted = Color(0xFF68738A);
  static const radius = 14.0;
  static const pagePadding = 18.0;

  static const shadow = BoxShadow(
    color: Color(0x0C0B1B3B),
    blurRadius: 20,
    offset: Offset(0, 6),
  );

  static BoxDecoration get cardDecoration => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: border),
    boxShadow: const [shadow],
  );
}
