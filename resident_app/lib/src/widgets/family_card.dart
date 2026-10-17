import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../models/family_member.dart';

class FamilyCard extends StatelessWidget {
  final FamilyMember member;
  final VoidCallback? onDelete;
  final VoidCallback? onTap;

  const FamilyCard({
    super.key,
    required this.member,
    this.onDelete,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: const Color(0xFFE2EAF3)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF172B4D).withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20.r),
          child: Padding(
            padding: EdgeInsets.all(16.w),
            child: Row(
              children: [
                // Icon container
                Container(
                  width: 48.w,
                  height: 48.h,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Icon(
                    Icons.people,
                    color: Color(0xFF16A34A),
                    size: 24.w,
                  ),
                ),
                SizedBox(width: 14.w),
                // Text content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        member.name,
                        style: TextStyle(
                          fontSize: 17.sp,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF172B4D),
                          height: 1.3,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        '${member.relation} • ${member.age} years',
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: const Color(0xFF52627A),
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                // Delete button
                if (onDelete != null)
                  IconButton(
                    onPressed: onDelete,
                    icon: Icon(
                      Icons.delete_outline,
                      color: Color(0xFFEF4444),
                      size: 22.w,
                    ),
                    padding: EdgeInsets.all(8.w),
                    constraints: BoxConstraints(
                      minWidth: 44.w,
                      minHeight: 44.h,
                    ),
                    splashRadius: 20,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
