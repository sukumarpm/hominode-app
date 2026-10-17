import 'package:flutter/material.dart';

/// A compact, accessible tap target for Home summary-card navigation.
class ResidentHomeSummaryViewAll extends StatelessWidget {
  const ResidentHomeSummaryViewAll({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 68,
    height: 48,
    child: TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 48),
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        foregroundColor: const Color(0xFF667792),
      ),
      child: Text(label, softWrap: true, textAlign: TextAlign.center),
    ),
  );
}
