import 'package:flutter/material.dart';

/// Keeps the current navigation page visible during a scoped access check.
class ResidentNavigationLoadingOverlay extends StatelessWidget {
  const ResidentNavigationLoadingOverlay({
    required this.loading,
    required this.child,
    super.key,
  });

  final bool loading;
  final Widget child;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      child,
      if (loading) ...[
        const ModalBarrier(dismissible: false, color: Color(0x520A1A2B)),
        const Center(
          child: SizedBox(
            width: 34,
            height: 34,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
        ),
      ],
    ],
  );
}

/// Shows a scoped busy state and always clears it when the operation finishes.
Future<T> runWithNavigationLoading<T>({
  required ValueChanged<bool> onLoadingChanged,
  required Future<T> Function() operation,
}) async {
  onLoadingChanged(true);
  try {
    return await operation();
  } finally {
    onLoadingChanged(false);
  }
}
