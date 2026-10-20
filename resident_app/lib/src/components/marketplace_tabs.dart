import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'app_segmented_control.dart';

class MarketplaceTabs extends StatelessWidget {
  const MarketplaceTabs({
    super.key,
    required this.selectedIndex,
    required this.onChanged,
  });
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => AppSegmentedControl(
    segments: const ['Browse', 'Your Products', 'History'],
    selectedIndex: selectedIndex,
    onChanged: onChanged,
    horizontalMargin: 0,
    scrollable: true,
    height: (MediaQuery.textScalerOf(context).scale(15.sp) * 1.5 + 16).clamp(
      48.0,
      double.infinity,
    ),
  );
}
