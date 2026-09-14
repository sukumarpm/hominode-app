import 'package:flutter/material.dart';

import 'admin_desktop_design.dart';

class AdminDesktopPresentationScope extends InheritedWidget {
  const AdminDesktopPresentationScope({required super.child, super.key});

  static bool isActive(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<
            AdminDesktopPresentationScope
          >() !=
      null;

  @override
  bool updateShouldNotify(AdminDesktopPresentationScope oldWidget) => false;
}

class AdminDesktopPageFrame extends StatelessWidget {
  const AdminDesktopPageFrame({
    required this.title,
    required this.subtitle,
    required this.child,
    this.actions = const [],
    super.key,
  });

  final String title;
  final String subtitle;
  final List<Widget> actions;
  final Widget child;

  @override
  Widget build(BuildContext context) => Material(
    color: AdminDesktopDesign.background,
    child: Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFDDEBFF), AdminDesktopDesign.background],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(
        AdminDesktopDesign.pagePadding,
        20,
        AdminDesktopDesign.pagePadding,
        AdminDesktopDesign.pagePadding,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final heading = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AdminDesktopDesign.text,
                      fontSize: 26,
                      height: 1.2,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -.2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AdminDesktopDesign.muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              );
              if (constraints.maxWidth < 820 && actions.isNotEmpty) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    heading,
                    const SizedBox(height: 14),
                    Wrap(spacing: 8, runSpacing: 8, children: actions),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: heading),
                  if (actions.isNotEmpty) ...[
                    const SizedBox(width: 20),
                    Wrap(spacing: 8, runSpacing: 8, children: actions),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          Expanded(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1440),
                child: child,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class AdminDesktopPrimaryAction extends StatelessWidget {
  const AdminDesktopPrimaryAction({
    required this.label,
    required this.icon,
    required this.onPressed,
    super.key,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 42,
    child: FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
      ),
    ),
  );
}
