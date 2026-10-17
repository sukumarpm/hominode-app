import 'package:flutter/material.dart';

/// Back action for Resident pages opened above the tab shell.
class ResidentNavigationBackButton extends StatelessWidget {
  const ResidentNavigationBackButton({super.key});

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: MaterialLocalizations.of(context).backButtonTooltip,
    onPressed: () => returnFromResidentRoute(context),
    icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF172B4D), size: 20),
    constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
  );
}

void returnFromResidentRoute(BuildContext context) {
  final navigator = Navigator.of(context);
  if (navigator.canPop()) {
    navigator.pop();
  } else {
    navigator.pushNamedAndRemoveUntil('/home', (_) => false);
  }
}

/// Gives system Back the same Home fallback as the visible Back action.
class ResidentNavigationBackHandler extends StatelessWidget {
  const ResidentNavigationBackHandler({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final navigator = Navigator.of(context);
    final canPop = navigator.canPop();
    return PopScope<void>(
      canPop: canPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !canPop) returnFromResidentRoute(context);
      },
      child: child,
    );
  }
}
