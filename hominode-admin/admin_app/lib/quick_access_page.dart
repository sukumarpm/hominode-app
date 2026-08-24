import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'manage_buildings_page.dart';
import 'visitor_management_screen.dart';
import 'complaint_management_screen.dart';
import 'billing_screen.dart';
import 'communication_center_screen.dart';
import 'parking_management_screen.dart';
import 'staff_vendor_management_screen.dart';
import 'reports_analytics_screen.dart';
import 'notices_management_screen.dart';
import 'staff_attendance_screen.dart';
import 'staff_vendors_screen.dart';
import 'admin_residents_page_firestore.dart';
import 'events_announcements_screen.dart';
import 'security_management_screen.dart';
import 'apartment_images_management_screen.dart';
import 'community_settings_screen.dart';
import 'widgets/standard_header.dart';

class QuickAccessPage extends StatelessWidget {
  const QuickAccessPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          const StandardHeader(title: 'Quick Access'),
          SliverPadding(
            padding: EdgeInsets.all(12.w),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 0.9,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              delegate: SliverChildListDelegate(_buildAllGridItems()),
            ),
          ),
          SliverToBoxAdapter(child: SizedBox(height: 80.h)),
        ],
      ),
    );
  }

  List<Widget> _buildAllGridItems() {
    return [
      // Core Management Features
      ModernQuickAccessTile(
        icon: Icons.apartment_rounded,
        label: 'Buildings',
        color: const Color(0xFF0E4778),
        bgColor: const Color(0xFFEEF2FF),
        onTap: (context) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ManageBuildingsPage(),
            ),
          );
        },
      ),
      ModernQuickAccessTile(
        icon: Icons.people_rounded,
        label: 'Residents',
        color: const Color(0xFF059669),
        bgColor: const Color(0xFFECFDF5),
        onTap: (context) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AdminResidentsPageFirestore(),
            ),
          );
        },
      ),
      ModernQuickAccessTile(
        icon: Icons.how_to_reg_rounded,
        label: 'Visitors',
        color: const Color(0xFFF59E0B),
        bgColor: const Color(0xFFFEF3C7),
        onTap: (context) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const VisitorManagementScreen(),
            ),
          );
        },
      ),
      ModernQuickAccessTile(
        icon: Icons.report_problem_rounded,
        label: 'Complaints',
        color: const Color(0xFFEF4444),
        bgColor: const Color(0xFFFFE5E5),
        onTap: (context) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ComplaintManagementScreen(),
            ),
          );
        },
      ),

      // Operations
      ModernQuickAccessTile(
        icon: Icons.receipt_long_rounded,
        label: 'Billing',
        color: const Color(0xFF8B5CF6),
        bgColor: const Color(0xFFEDE9FE),
        onTap: (context) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const BillingScreen()),
          );
        },
      ),
      ModernQuickAccessTile(
        icon: Icons.image_rounded,
        label: 'Apartment Images',
        color: const Color(0xFF0EA5E9),
        bgColor: const Color(0xFFE0F2FE),
        onTap: (context) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ApartmentImagesManagementScreen(),
            ),
          );
        },
      ),
      ModernQuickAccessTile(
        icon: Icons.notifications_active_rounded,
        label: 'Notices',
        color: const Color(0xFF10B981),
        bgColor: const Color(0xFFD1FAE5),
        onTap: (context) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const NoticesManagementScreen(),
            ),
          );
        },
      ),
      ModernQuickAccessTile(
        icon: Icons.event_rounded,
        label: 'Events',
        color: const Color(0xFFD946EF),
        bgColor: const Color(0xFFFAE8FF),
        onTap: (context) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const EventsAnnouncementsScreen(),
            ),
          );
        },
      ),
      // Additional Services
      ModernQuickAccessTile(
        icon: Icons.local_parking_rounded,
        label: 'Parking',
        color: const Color(0xFF14B8A6),
        bgColor: const Color(0xFFCCFBF1),
        onTap: (context) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ParkingManagementScreenEnhanced(),
            ),
          );
        },
      ),
      ModernQuickAccessTile(
        icon: Icons.security_rounded,
        label: 'Security',
        color: const Color(0xFF6366F1),
        bgColor: const Color(0xFFE0E7FF),
        onTap: (context) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const SecurityManagementScreen(),
            ),
          );
        },
      ),
      ModernQuickAccessTile(
        icon: Icons.message_rounded,
        label: 'Messages',
        color: const Color(0xFFF97316),
        bgColor: const Color(0xFFFFEDD5),
        onTap: (context) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const CommunicationCenterScreen(),
            ),
          );
        },
      ),
      ModernQuickAccessTile(
        icon: Icons.group_rounded,
        label: 'Staff',
        color: const Color(0xFF7C3AED),
        bgColor: const Color(0xFFF3E8FF),
        onTap: (context) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const StaffVendorManagementScreen(),
            ),
          );
        },
      ),

      // Analytics & Settings
      ModernQuickAccessTile(
        icon: Icons.group_work_rounded,
        label: 'Community & Invites',
        color: const Color(0xFF0E4778),
        bgColor: const Color(0xFFEEF2FF),
        onTap: (context) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const CommunitySettingsScreen(),
            ),
          );
        },
      ),
      ModernQuickAccessTile(
        icon: Icons.bar_chart_rounded,
        label: 'Reports',
        color: const Color(0xFF059669),
        bgColor: const Color(0xFFECFDF5),
        onTap: (context) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ReportsAnalyticsScreen(),
            ),
          );
        },
      ),

      ModernQuickAccessTile(
        icon: Icons.business_rounded,
        label: 'Vendors',
        color: const Color(0xFF7C3AED),
        bgColor: const Color(0xFFF3E8FF),
        onTap: (context) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => StaffVendorsScreen()),
          );
        },
      ),
      ModernQuickAccessTile(
        icon: Icons.access_time_rounded,
        label: 'Attendance',
        color: const Color(0xFF8B5CF6),
        bgColor: const Color(0xFFEDE9FE),
        onTap: (context) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const StaffAttendanceScreen(),
            ),
          );
        },
      ),
    ];
  }
}

class ModernQuickAccessTile extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color bgColor;
  final Function(BuildContext)? onTap;

  const ModernQuickAccessTile({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.bgColor,
    this.onTap,
  });

  @override
  State<ModernQuickAccessTile> createState() => _ModernQuickAccessTileState();
}

class _ModernQuickAccessTileState extends State<ModernQuickAccessTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _animationController.forward(),
      onTapUp: (_) => _animationController.reverse(),
      onTapCancel: () => _animationController.reverse(),
      onTap: () {
        if (widget.onTap != null) {
          widget.onTap!(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${widget.label} - Coming soon')),
          );
        }
      },
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              width: double.infinity,
              height: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Padding(
                padding: EdgeInsets.all(12.w),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 48.w,
                      height: 48.h,
                      decoration: BoxDecoration(
                        color: widget.bgColor,
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Icon(widget.icon, color: widget.color, size: 24.w),
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      widget.label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF111827),
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
