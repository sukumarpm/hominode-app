import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Shared compact header for the Resident Visitor Management page.
class ResidentVisitorPageHeader extends StatelessWidget {
  const ResidentVisitorPageHeader({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(12.w, 8.h, 18.w, 4.h),
    child: Row(
      children: [
        const ResidentVisitorBackButton(),
        SizedBox(width: 6.w),
        Expanded(
          child: Text(
            title,
            softWrap: true,
            style: TextStyle(
              color: const Color(0xFF0E2247),
              fontSize: 23.sp,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        SizedBox(width: 8.w),
        Container(
          width: 42.w,
          height: 42.w,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .9),
            borderRadius: BorderRadius.circular(15.r),
            border: Border.all(color: Colors.white, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF082F73).withValues(alpha: .08),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(
            Icons.groups_2_outlined,
            color: const Color(0xFF1558D6),
            size: 22.w,
          ),
        ),
      ],
    ),
  );
}

class ResidentVisitorBackButton extends StatelessWidget {
  const ResidentVisitorBackButton({super.key});

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'back'.tr(),
    onPressed: () => returnFromResidentVisitors(context),
    icon: const Icon(Icons.arrow_back, color: Color(0xFF172B4D), size: 20),
    padding: EdgeInsets.zero,
    constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
  );
}

void returnFromResidentVisitors(BuildContext context) {
  final navigator = Navigator.of(context);
  if (navigator.canPop()) {
    navigator.pop();
  } else {
    navigator.pushNamedAndRemoveUntil('/home', (_) => false);
  }
}

/// Routes Android/system Back to Home when Visitor Management is the root page.
class ResidentVisitorBackHandler extends StatelessWidget {
  const ResidentVisitorBackHandler({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final navigator = Navigator.of(context);
    final canPop = navigator.canPop();
    return PopScope<void>(
      canPop: canPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !canPop) returnFromResidentVisitors(context);
      },
      child: child,
    );
  }
}
