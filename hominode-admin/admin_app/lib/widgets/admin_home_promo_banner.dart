import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Presentation for the Home promotion, independent of dashboard data loading.
class AdminHomePromoBanner extends StatelessWidget {
  const AdminHomePromoBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 15.w),
      child: Container(
        width: double.infinity,
        constraints: BoxConstraints(
          minHeight:
              104.h +
              (MediaQuery.textScalerOf(context).scale(1) - 1).clamp(0.0, 2.0) *
                  60.h,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22.r),
          gradient: const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [Color(0xFFDCE7FF), Color(0xFFCFEFFF), Color(0xFFD9FBF7)],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.035),
              blurRadius: 12,
              offset: Offset(0, 4.h),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22.r),
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              Positioned(
                left: 10.w,
                bottom: -8.h,
                child: Opacity(
                  opacity: 0.22,
                  child: Icon(
                    Icons.phone_iphone_rounded,
                    size: 82.w,
                    color: const Color(0xFF17489B),
                  ),
                ),
              ),
              Positioned(
                left: 58.w,
                top: 18.h,
                child: _buildPromoBubble(Icons.person_outline_rounded),
              ),
              Positioned(
                left: 47.w,
                bottom: 16.h,
                child: _buildPromoBubble(Icons.receipt_long_rounded),
              ),
              // This non-positioned content determines the banner height.
              // Keep the original illustration/arrow gutters and phone minimum.
              Padding(
                padding: EdgeInsets.fromLTRB(108.w, 16.h, 56.w, 16.h),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Smart Community,\nBetter Living',
                      style: TextStyle(
                        color: const Color(0xFF0B2D6A),
                        fontSize: 15.sp,
                        height: 1.10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 7.h),
                    Text(
                      'Manage your society, connect with residents and simplify everyday tasks.',
                      style: TextStyle(
                        color: const Color(0xFF18375F),
                        fontSize: 8.8.sp,
                        height: 1.22,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                right: 14.w,
                top: 0,
                bottom: 0,
                child: Center(
                  child: Container(
                    width: 42.w,
                    height: 42.w,
                    decoration: const BoxDecoration(
                      color: Color(0xFF103A8D),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.white,
                      size: 21.w,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPromoBubble(IconData icon) {
    return Container(
      width: 27.w,
      height: 20.h,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(6.r),
      ),
      child: Icon(icon, size: 12.w, color: const Color(0xFF1E64C8)),
    );
  }
}
