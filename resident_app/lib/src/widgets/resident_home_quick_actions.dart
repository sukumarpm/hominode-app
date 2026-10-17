import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class ResidentHomeAction {
  const ResidentHomeAction({
    required this.icon,
    required this.label,
    required this.iconColor,
    required this.backgroundColor,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color iconColor;
  final Color backgroundColor;
  final VoidCallback onTap;
}

class ResidentHomeQuickActions extends StatelessWidget {
  const ResidentHomeQuickActions({
    required this.items,
    required this.title,
    super.key,
  });

  final List<ResidentHomeAction> items;
  final String title;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: Text(
          title,
          style: TextStyle(
            color: const Color(0xFF0E2247),
            fontSize: 17.sp,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      SizedBox(height: 12.h),
      LayoutBuilder(
        builder: (context, constraints) {
          final textScaler = MediaQuery.textScalerOf(context);
          final labelStyle = TextStyle(
            fontSize: 11.sp,
            height: 1.08,
            fontWeight: FontWeight.w600,
          );
          var longestWordWidth = 0.0;
          for (final item in items) {
            for (final word in item.label.split(RegExp(r'\s+'))) {
              final painter = TextPainter(
                text: TextSpan(text: word, style: labelStyle),
                textDirection: Directionality.of(context),
                textScaler: textScaler,
              )..layout();
              if (painter.width > longestWordWidth) {
                longestWordWidth = painter.width;
              }
              painter.dispose();
            }
          }

          final spacing = 8.w;
          var columns = 4;
          while (columns > 1) {
            final tileWidth =
                (constraints.maxWidth - spacing * (columns - 1)) / columns;
            if (tileWidth - 6.w - 2.4 >= longestWordWidth) break;
            columns--;
          }
          final tileWidth =
              (constraints.maxWidth - spacing * (columns - 1)) / columns;
          return Wrap(
            spacing: spacing,
            runSpacing: 10.h,
            children: [
              for (final item in items)
                SizedBox(
                  width: tileWidth,
                  child: _ActionTile(item: item),
                ),
            ],
          );
        },
      ),
    ],
  );
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.item});

  final ResidentHomeAction item;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(18.r),
      child: Container(
        constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
        padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 5.h),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .82),
          borderRadius: BorderRadius.circular(18.r),
          border: Border.all(color: Colors.white, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF193A65).withValues(alpha: .07),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 40.w,
              height: 40.w,
              decoration: BoxDecoration(
                color: item.backgroundColor,
                shape: BoxShape.circle,
              ),
              child: Icon(item.icon, color: item.iconColor, size: 23.w),
            ),
            SizedBox(height: 4.h),
            Text(
              item.label,
              softWrap: true,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: const Color(0xFF0E2247),
                fontSize: 11.sp,
                height: 1.08,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
