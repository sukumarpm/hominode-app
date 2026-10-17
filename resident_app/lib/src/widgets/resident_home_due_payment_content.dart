import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Due-payment card contents used inside the vertically scrolling Home page.
/// Keep this column non-flexible because its scroll parent has unbounded height.
class ResidentHomeDuePaymentContent extends StatelessWidget {
  const ResidentHomeDuePaymentContent({
    super.key,
    required this.amount,
    required this.billTitle,
    required this.onViewBilling,
    this.isEmpty = false,
    this.viewBillingLabel = 'View Billing',
  });

  final String amount;
  final String billTitle;
  final VoidCallback onViewBilling;
  final bool isEmpty;
  final String viewBillingLabel;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (isEmpty)
        Row(
          children: [
            Icon(
              Icons.credit_card_outlined,
              color: const Color(0xFF667792),
              size: 22.w,
            ),
            SizedBox(width: 8.w),
            Expanded(
              child: Text(
                billTitle,
                softWrap: true,
                style: TextStyle(
                  color: const Color(0xFF667792),
                  fontSize: 12.sp,
                ),
              ),
            ),
          ],
        )
      else ...[
        Text(
          amount,
          softWrap: true,
          style: TextStyle(
            color: const Color(0xFF0E2247),
            fontSize: 21.sp,
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: 3.h),
        Text(
          billTitle,
          softWrap: true,
          style: TextStyle(color: const Color(0xFF667792), fontSize: 12.sp),
        ),
      ],
      SizedBox(height: 8.h),
      ConstrainedBox(
        constraints: BoxConstraints(minHeight: 48.h),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: onViewBilling,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF243143),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14.r),
              ),
            ),
            child: Text(
              viewBillingLabel,
              softWrap: true,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11.5.sp, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ),
    ],
  );
}
