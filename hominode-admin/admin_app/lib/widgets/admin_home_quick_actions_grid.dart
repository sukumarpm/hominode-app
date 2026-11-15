import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Retains the approved four-column Home grid at every mobile text size.
class AdminHomeQuickActionsGrid extends StatelessWidget {
  const AdminHomeQuickActionsGrid({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final minimumHeight =
        125.h +
        (MediaQuery.textScalerOf(context).scale(1) - 1).clamp(0.0, 2.0) * 40.h;

    // Fixed grid extents can clip a Flexible label without a RenderFlex warning.
    // Let each four-card row grow to fit its contents while keeping the phone
    // minimum height, spacing and column count.
    return Column(
      children: [
        for (var index = 0; index < children.length; index += 4) ...[
          if (index > 0) SizedBox(height: 10.h),
          ConstrainedBox(
            constraints: BoxConstraints(minHeight: minimumHeight),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var column = 0; column < 4; column++) ...[
                    if (column > 0) SizedBox(width: 9.w),
                    Expanded(
                      child: index + column < children.length
                          ? children[index + column]
                          : const SizedBox(),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
