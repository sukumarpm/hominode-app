import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'resident_home_summary_view_all.dart';

class ResidentHomeSummaryCard extends StatelessWidget {
  const ResidentHomeSummaryCard({
    super.key,
    required this.icon,
    required this.title,
    required this.action,
    required this.onAction,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String action;
  final VoidCallback onAction;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final stackedHeader =
        (screenWidth >= 376 && screenWidth < 450 && textScale <= 1.2) ||
        textScale > 1.2;
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .78),
        borderRadius: BorderRadius.circular(23.r),
        border: Border.all(color: Colors.white, width: 1.3),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12082F73),
            blurRadius: 16,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (stackedHeader) ...[
            Row(
              children: [
                Icon(icon, color: const Color(0xFF082F73), size: 19.w),
                SizedBox(width: 7.w),
                Expanded(child: _title()),
              ],
            ),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: ResidentHomeSummaryViewAll(
                label: action,
                onPressed: onAction,
              ),
            ),
          ] else
            Row(
              children: [
                Icon(icon, color: const Color(0xFF082F73), size: 19.w),
                SizedBox(width: 7.w),
                Expanded(child: _title()),
                ResidentHomeSummaryViewAll(label: action, onPressed: onAction),
              ],
            ),
          SizedBox(height: 8.h),
          child,
        ],
      ),
    );
  }

  Widget _title() => Text(
    title,
    softWrap: true,
    style: TextStyle(
      color: const Color(0xFF0E2247),
      fontSize: 13.sp,
      fontWeight: FontWeight.w700,
    ),
  );
}
