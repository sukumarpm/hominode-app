import 'package:flutter/material.dart';

class AdminDesktopShellScope extends InheritedWidget {
  const AdminDesktopShellScope({
    required this.onSelectModule,
    required super.child,
    super.key,
  });

  final ValueChanged<String> onSelectModule;

  static AdminDesktopShellScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AdminDesktopShellScope>();

  static bool isActive(BuildContext context) => maybeOf(context) != null;

  @override
  bool updateShouldNotify(AdminDesktopShellScope oldWidget) => false;
}

/// Presentation-only tokens for the Admin desktop workspace.
abstract final class AdminDesktopDesign {
  static const primary = Color(0xFF176BFF);
  static const dark = Color(0xFF0A2243);
  static const navy = Color(0xFF071D3D);
  static const soft = Color(0xFFECF4FF);
  static const background = Color(0xFFEDF5FF);
  static const border = Color(0xFFE1EAF6);
  static const text = Color(0xFF0A1837);
  static const muted = Color(0xFF68738A);
  static const radius = 18.0;
  static const pagePadding = 20.0;

  static const sidebarGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [navy, dark],
  );

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
}

ThemeData adminDesktopTheme(BuildContext context) {
  final base = Theme.of(context);
  final compactBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: const BorderSide(color: AdminDesktopDesign.border),
  );

  return base.copyWith(
    scaffoldBackgroundColor: AdminDesktopDesign.background,
    colorScheme: base.colorScheme.copyWith(
      primary: AdminDesktopDesign.primary,
      surface: Colors.white,
      onSurface: AdminDesktopDesign.text,
    ),
    dividerColor: AdminDesktopDesign.border,
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    dataTableTheme: const DataTableThemeData(
      headingRowColor: WidgetStatePropertyAll(AdminDesktopDesign.soft),
      headingTextStyle: TextStyle(
        color: AdminDesktopDesign.text,
        fontWeight: FontWeight.w700,
      ),
      dividerThickness: .5,
      dataRowMinHeight: 52,
      dataRowMaxHeight: 76,
    ),
    cardTheme: const CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(
          Radius.circular(AdminDesktopDesign.radius),
        ),
        side: BorderSide(color: AdminDesktopDesign.border),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      hintStyle: const TextStyle(color: AdminDesktopDesign.muted, fontSize: 13),
      labelStyle: const TextStyle(
        color: AdminDesktopDesign.muted,
        fontSize: 13,
      ),
      border: compactBorder,
      enabledBorder: compactBorder,
      focusedBorder: compactBorder.copyWith(
        borderSide: const BorderSide(
          color: AdminDesktopDesign.primary,
          width: 1.4,
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 42),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 42),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        side: const BorderSide(color: AdminDesktopDesign.border),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        minimumSize: const Size.square(40),
        maximumSize: const Size.square(40),
        iconSize: 19,
      ),
    ),
  );
}

class AdminDesktopSectionCard extends StatelessWidget {
  const AdminDesktopSectionCard({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.compact = false,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final bool compact;

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.all(compact ? 14 : 16),
    decoration: AdminDesktopDesign.cardDecoration,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AdminDesktopDesign.text,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        if (subtitle case final text?) ...[
          const SizedBox(height: 3),
          Text(
            text,
            style: const TextStyle(
              color: AdminDesktopDesign.muted,
              fontSize: 11,
            ),
          ),
        ],
        SizedBox(height: compact ? 12 : 14),
        child,
      ],
    ),
  );
}

class AdminDesktopActionTile extends StatelessWidget {
  const AdminDesktopActionTile({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.color = AdminDesktopDesign.primary,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(10),
    child: Container(
      constraints: const BoxConstraints(minHeight: 78),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: .09)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 6),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AdminDesktopDesign.text,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    ),
  );
}
