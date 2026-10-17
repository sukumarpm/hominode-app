import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../billing_screen.dart';
import '../complaint_management_screen.dart';
import '../visitor_management_screen.dart';
import '../services/dashboard_service.dart';

/// The approved compact Home statistics row. It never changes column count.
class AdminHomeStatistics extends StatelessWidget {
  const AdminHomeStatistics({super.key, required this.statsStream});

  final Stream<DashboardStats> statsStream;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DashboardStats>(
      stream: statsStream,
      builder: (context, snapshot) {
        final loading = snapshot.connectionState == ConnectionState.waiting;
        final stats = snapshot.data;

        return Padding(
          padding: EdgeInsets.symmetric(horizontal: 12.w),
          child: SizedBox(
            height:
                150.h +
                (MediaQuery.textScalerOf(context).scale(1) - 1).clamp(
                      0.0,
                      2.0,
                    ) *
                    85.h,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _buildStatTile(
                    icon: Icons.people_alt_rounded,
                    iconColor: const Color(0xFF2F61D7),
                    iconBg: const Color(0xFFEAF0FF),
                    value: loading ? '—' : '${stats?.totalResidents ?? 0}',
                    label: 'Total\nResidents',
                    subtitle: 'Active users',
                    subtitleColor: const Color(0xFF2F61D7),
                  ),
                ),
                SizedBox(width: 6.w),
                Expanded(
                  child: _buildStatTile(
                    icon: Icons.apartment_rounded,
                    iconColor: const Color(0xFF19956F),
                    iconBg: const Color(0xFFE3F8EF),
                    value: loading ? '—' : '${stats?.totalFlats ?? 0}',
                    label: 'Total Flats',
                    subtitle: 'All units',
                    subtitleColor: const Color(0xFF19956F),
                  ),
                ),
                SizedBox(width: 6.w),
                Expanded(
                  child: _buildStatTile(
                    icon: Icons.person_outline_rounded,
                    iconColor: const Color(0xFF8054D7),
                    iconBg: const Color(0xFFF0E9FF),
                    value: loading ? '—' : '${stats?.pendingVisitors ?? 0}',
                    label: 'Pending\nVisitors',
                    subtitle: 'Awaiting\napproval',
                    subtitleColor: const Color(0xFF8054D7),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const VisitorManagementScreen(),
                        ),
                      );
                    },
                  ),
                ),
                SizedBox(width: 6.w),
                Expanded(
                  child: _buildStatTile(
                    icon: Icons.warning_rounded,
                    iconColor: const Color(0xFFEB3535),
                    iconBg: const Color(0xFFFFE8E4),
                    value: loading ? '—' : '${stats?.pendingComplaints ?? 0}',
                    label: 'Pending\nComplaints',
                    subtitle: 'Needs\nattention',
                    subtitleColor: const Color(0xFFEB3535),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const ComplaintManagementScreen(),
                        ),
                      );
                    },
                  ),
                ),
                SizedBox(width: 6.w),
                Expanded(
                  child: _buildStatTile(
                    icon: Icons.account_balance_wallet_rounded,
                    iconColor: const Color(0xFF14966F),
                    iconBg: const Color(0xFFE4F8EF),
                    value: loading ? '—' : (stats?.formattedCollection ?? '₹0'),
                    label: 'This Month\nCollection',
                    subtitle: 'Paid bills',
                    subtitleColor: const Color(0xFF14966F),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const BillingScreen(),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatTile({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String value,
    required String label,
    required String subtitle,
    required Color subtitleColor,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18.r),
        child: Ink(
          // Keep the approved card height; allow for fractional text rounding.
          padding: EdgeInsets.fromLTRB(4.w, 12.h, 4.w, 9.h),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18.r),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.045),
                blurRadius: 14,
                offset: Offset(0, 4.h),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Container(
                width: 42.w,
                height: 42.w,
                decoration: BoxDecoration(
                  color: iconBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 21.w),
              ),
              SizedBox(height: 8.h),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 19.sp,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF111418),
                    height: 1,
                  ),
                ),
              ),
              SizedBox(height: 7.h),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: const Color(0xFF42464D),
                  fontSize: 9.5.sp,
                  height: 1.12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: subtitleColor,
                  fontSize: 8.8.sp,
                  height: 1.1,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
