import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Responsive visitor identity/details area used by the visitor cards.
class ResidentVisitorCardHeader extends StatelessWidget {
  const ResidentVisitorCardHeader({
    super.key,
    required this.visitorName,
    required this.purpose,
    required this.timeText,
    this.phoneNumber,
    this.statusLabel,
    this.secondaryStatusLabel,
    this.statusColor,
    this.statusBackgroundColor,
    this.rejectedAtLabel,
  });

  final String visitorName;
  final String purpose;
  final String timeText;
  final String? phoneNumber;
  final String? statusLabel;
  final String? secondaryStatusLabel;
  final Color? statusColor;
  final Color? statusBackgroundColor;
  final String? rejectedAtLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 56.w,
              height: 56.h,
              decoration: const BoxDecoration(
                color: Color(0xFFE0E7FF),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  visitorName.isNotEmpty ? visitorName[0].toUpperCase() : 'V',
                  style: TextStyle(
                    color: const Color(0xFF0E4778),
                    fontSize: 24.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    visitorName,
                    softWrap: true,
                    style: TextStyle(
                      color: const Color(0xFF111111),
                      fontSize: 17.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    purpose,
                    softWrap: true,
                    style: TextStyle(
                      color: const Color(0xFFA3A3A3),
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  _IconTextRow(icon: Icons.access_time, text: timeText),
                  if (phoneNumber != null && phoneNumber!.isNotEmpty) ...[
                    SizedBox(height: 4.h),
                    _IconTextRow(icon: Icons.phone, text: phoneNumber!),
                  ],
                  if (rejectedAtLabel != null) ...[
                    SizedBox(height: 4.h),
                    _IconTextRow(
                      icon: Icons.cancel_outlined,
                      text: rejectedAtLabel!,
                      color: const Color(0xFFDC2626),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        if (statusLabel != null) ...[
          SizedBox(height: 8.h),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
              decoration: BoxDecoration(
                color: statusBackgroundColor,
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Text(
                statusLabel!,
                softWrap: true,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
        if (secondaryStatusLabel != null) ...[
          SizedBox(height: 4.h),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Text(
              secondaryStatusLabel!,
              softWrap: true,
              textAlign: TextAlign.end,
              style: TextStyle(
                color: const Color(0xFF64748B),
                fontSize: 12.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _IconTextRow extends StatelessWidget {
  const _IconTextRow({
    required this.icon,
    required this.text,
    this.color = const Color(0xFFA3A3A3),
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final icon = Padding(
        padding: EdgeInsets.only(top: 2.h),
        child: Icon(this.icon, size: 14.w, color: color),
      );
      final value = Text(
        text,
        softWrap: true,
        style: TextStyle(
          color: color,
          fontSize: 14.sp,
          fontWeight: FontWeight.w400,
        ),
      );

      // At very large text scales or extremely narrow cards, stack the icon
      // over its value instead of allowing the icon and gap to overflow.
      if (constraints.maxWidth < 48.w) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [icon, value],
        );
      }

      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          icon,
          SizedBox(width: 4.w),
          Expanded(child: value),
        ],
      );
    },
  );
}
