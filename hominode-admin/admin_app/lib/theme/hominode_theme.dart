import 'package:flutter/material.dart';

abstract final class HominodeTheme {
  static const Color navy = Color(0xFF061C4C);
  static const Color blue = Color(0xFF0E4778);
  static const Color teal = Color(0xFF3AA6C8);

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [navy, blue, teal],
  );

  static ThemeData get light {
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: blue,
          brightness: Brightness.light,
        ).copyWith(
          primary: blue,
          onPrimary: Colors.white,
          secondary: teal,
          onSecondary: navy,
          surface: Colors.white,
        );

    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      fontFamily: 'Inter',
      scaffoldBackgroundColor: const Color(0xFFF7F9FC),
      appBarTheme: const AppBarTheme(
        backgroundColor: blue,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: blue,
          foregroundColor: Colors.white,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: blue,
          foregroundColor: Colors.white,
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: blue,
        foregroundColor: Colors.white,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: teal),
      navigationBarTheme: NavigationBarThemeData(
        indicatorColor: teal.withValues(alpha: 0.18),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected) ? blue : null,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            color: states.contains(WidgetState.selected) ? blue : null,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
