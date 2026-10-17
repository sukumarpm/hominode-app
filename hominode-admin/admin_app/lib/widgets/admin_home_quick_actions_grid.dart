import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Retains the approved four-column Home grid at every mobile text size.
class AdminHomeQuickActionsGrid extends StatelessWidget {
  const AdminHomeQuickActionsGrid({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => GridView.count(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    padding: EdgeInsets.zero,
    crossAxisCount: 4,
    crossAxisSpacing: 9.w,
    mainAxisSpacing: 10.h,
    mainAxisExtent:
        125.h +
        (MediaQuery.textScalerOf(context).scale(1) - 1).clamp(0.0, 2.0) * 40.h,
    children: children,
  );
}
