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
    primary: Color(0xFF155ACB),
    dark: Color(0xFF071D49),
    soft: Color(0xFFEAF1FF),
  );
  static const admin = RolePalette(
    primary: Color(0xFF176BFF),
    dark: Color(0xFF0A2243),
    soft: Color(0xFFECF4FF),
  );
  static const resident = RolePalette(
    primary: Color(0xFF88572F),
    dark: Color(0xFF292724),
    soft: Color(0xFFFAF2E5),
  );

  bool get isResident => this == resident;
  bool get isCommunityRole => this == admin || isResident;
  Color get canvas =>
      isResident ? const Color(0xFFF6F3ED) : const Color(0xFFEDF5FF);
  Color get selection => isResident ? const Color(0xFFE7C58B) : primary;
  Color get selectionText =>
      isResident ? const Color(0xFF241E16) : Colors.white;
  LinearGradient get sidebar => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: isResident
        ? const [Color(0xFF292929), Color(0xFF332B22)]
        : const [Color(0xFF071D3D), Color(0xFF102E50)],
  );
}

/// Scoped presentation tokens; platform administration keeps its existing theme.
class WebRoleStyle extends InheritedTheme {
  const WebRoleStyle({super.key, required this.palette, required super.child});
  final RolePalette palette;
  static RolePalette? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<WebRoleStyle>()?.palette;
  @override
  bool updateShouldNotify(WebRoleStyle oldWidget) =>
      palette != oldWidget.palette;
  @override
  Widget wrap(BuildContext context, Widget child) =>
      WebRoleStyle(palette: palette, child: child);
}

ThemeData communityWebTheme(ThemeData base, RolePalette palette) {
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: WebDesign.border),
  );
  return base.copyWith(
    scaffoldBackgroundColor: palette.canvas,
    colorScheme: base.colorScheme.copyWith(
      primary: palette.primary,
      onPrimary: Colors.white,
      secondary: palette.isResident
          ? const Color(0xFF267760)
          : const Color(0xFF00A6BF),
      surface: Colors.white,
      onSurface: WebDesign.text,
    ),
    dividerColor: WebDesign.border,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: BorderSide(color: palette.primary, width: 2),
      ),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(44, 44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(44, 44),
        side: BorderSide(color: palette.primary.withValues(alpha: .22)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    dataTableTheme: DataTableThemeData(
      headingRowColor: WidgetStatePropertyAll(palette.soft),
      headingTextStyle: const TextStyle(
        color: WebDesign.text,
        fontWeight: FontWeight.w700,
      ),
      dataRowMinHeight: 52,
      dataRowMaxHeight: 76,
      dividerThickness: .5,
    ),
  );
}

abstract final class WebDesign {
  static const background = Color(0xFFF5F7FB);
  static const border = Color(0xFFE2E8F0);
  static const text = Color(0xFF0A1837);
  static const muted = Color(0xFF68738A);
  static const radius = 12.0;
  static const pagePadding = 20.0;

  static const shadow = BoxShadow(
    color: Color(0x0A0B1B3B),
    blurRadius: 14,
    offset: Offset(0, 4),
  );

  static BoxDecoration get cardDecoration => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: border),
    boxShadow: const [shadow],
  );

  static BoxDecoration cardFor(BuildContext context) {
    final palette = WebRoleStyle.maybeOf(context);
    if (palette == null) return cardDecoration;
    return BoxDecoration(
      color: Colors.white.withValues(alpha: .96),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(
        color: palette.isResident
            ? const Color(0xFFF0EBE3)
            : const Color(0xFFE1EDFD),
      ),
      boxShadow: const [
        BoxShadow(
          color: Color(0x050A2243),
          blurRadius: 18,
          offset: Offset(0, 5),
        ),
      ],
    );
  }

  static BoxDecoration get adminPageHeader => BoxDecoration(
    color: Colors.white,
    border: Border.all(color: const Color(0xFFE1EDFD)),
    borderRadius: BorderRadius.circular(18),
  );
}
