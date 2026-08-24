import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class NotificationBadge extends StatelessWidget {
  final Widget child;
  final bool showBadge;
  final int count;
  final Color badgeColor;
  final Color textColor;
  final double? top;
  final double? right;
  final double? left;
  final double? bottom;

  const NotificationBadge({
    super.key,
    required this.child,
    this.showBadge = false,
    this.count = 0,
    this.badgeColor = const Color(0xFFEF4444),
    this.textColor = Colors.white,
    this.top,
    this.right,
    this.left,
    this.bottom,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        if (showBadge && count > 0)
          Positioned(
            top: top ?? -4,
            right: right ?? -4,
            left: left,
            bottom: bottom,
            child: Container(
              constraints: BoxConstraints(minWidth: 18.w, minHeight: 18.h),
              padding: EdgeInsets.symmetric(horizontal: 6.w),
              decoration: BoxDecoration(
                color: badgeColor,
                borderRadius: BorderRadius.circular(9.r),
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  count > 99 ? '99+' : count.toString(),
                  style: TextStyle(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class NotificationDot extends StatelessWidget {
  final Widget child;
  final bool showDot;
  final Color dotColor;
  final double size;
  final double? top;
  final double? right;
  final double? left;
  final double? bottom;

  const NotificationDot({
    super.key,
    required this.child,
    this.showDot = false,
    this.dotColor = const Color(0xFFEF4444),
    this.size = 8,
    this.top,
    this.right,
    this.left,
    this.bottom,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        if (showDot)
          Positioned(
            top: top ?? 0,
            right: right ?? 0,
            left: left,
            bottom: bottom,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
