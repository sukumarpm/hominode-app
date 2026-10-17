import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Readable empty-state surface used by Resident Visitor Management tabs.
class ResidentVisitorEmptyState extends StatelessWidget {
  factory ResidentVisitorEmptyState.forTab(int tabIndex) {
    final state = switch (tabIndex) {
      0 => (
        Icons.pending_outlined,
        'visitor_empty_expected'.tr(),
        'visitor_empty_expected_hint'.tr(),
      ),
      1 => (
        Icons.check_circle_outline,
        'visitor_empty_checked_in'.tr(),
        'visitor_empty_checked_in_hint'.tr(),
      ),
      2 => (
        Icons.cancel_outlined,
        'visitor_empty_history'.tr(),
        'visitor_empty_history_hint'.tr(),
      ),
      _ => (
        Icons.local_shipping_outlined,
        'visitor_empty_deliveries'.tr(),
        'visitor_empty_deliveries_hint'.tr(),
      ),
    };
    return ResidentVisitorEmptyState(
      icon: state.$1,
      title: state.$2,
      description: state.$3,
    );
  }

  const ResidentVisitorEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  static const surfaceColor = Color(0xF5FFFFFF);
  static const titleColor = Color(0xFF17324F);
  static const descriptionColor = Color(0xFF52627A);
  static const iconColor = Color(0xFF41698D);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 520.w),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 24.h),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(22.r),
            border: Border.all(color: const Color(0xD9FFFFFF)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x120E2247),
                blurRadius: 18,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 48.w, color: iconColor),
              SizedBox(height: 14.h),
              Text(
                title,
                textAlign: TextAlign.center,
                softWrap: true,
                style: TextStyle(
                  fontSize: 17.sp,
                  fontWeight: FontWeight.w700,
                  color: titleColor,
                  height: 1.3,
                ),
              ),
              SizedBox(height: 7.h),
              Text(
                description,
                textAlign: TextAlign.center,
                softWrap: true,
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w400,
                  color: descriptionColor,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
