import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'quick_access_page.dart';
import 'manage_buildings_page.dart';
import 'visitor_management_screen.dart';
import 'complaint_management_screen.dart';
import 'events_announcements_screen.dart';
import 'billing_screen.dart';
import 'admin_residents_page_firestore.dart';
import 'parking_management_screen.dart';
import 'notifications_screen.dart';
import 'amenities_management_screen.dart';
import 'widgets/standard_bottom_nav.dart';
import 'widgets/notification_badge.dart';
import 'services/notification_service.dart';
import 'services/dashboard_service.dart';
import 'services/admin_tenant_context.dart';
import 'security_management_screen.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  final NotificationService _notificationService = NotificationService();
  final DashboardService _dashboardService = DashboardService();

  String _adminName = 'Admin';
  String _adminRole = 'Administrator';
  String _buildingName = 'Loading...';
  bool _isLoadingUserData = true;

  // Get current admin ID
  String get _adminId => FirebaseAuth.instance.currentUser?.uid ?? '';
  String get _communityId => AdminTenantContext.instance.requireCommunityId();

  @override
  void initState() {
    super.initState();
    _notificationService.initializeNotifications();
    _notificationService.addListener(_onNotificationUpdate);
    _loadAdminData();
  }

  Future<void> _loadAdminData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('DEBUG Dashboard: No user logged in');
        return;
      }

      print('=== DEBUG: Dashboard Data Fetch ===');
      print('Auth UID: ${user.uid}');
      print('Auth Email: ${user.email}');
      print('Fetching from: admins/${user.uid}');

      final userDoc = await FirebaseFirestore.instance
          .collection('admins')
          .doc(user.uid)
          .get();

      print('Document exists: ${userDoc.exists}');

      if (userDoc.exists && mounted) {
        final data = userDoc.data()!;
        print('Fetched data: $data');

        setState(() {
          _adminName = data['name'] ?? 'Admin';
          _adminRole = _formatRole(data['role'] ?? 'admin');
          _buildingName =
              data['organization'] ?? 'HOMINODE Property Management';
          _isLoadingUserData = false;
        });

        print('Admin Name: $_adminName');
        print('Admin Role: $_adminRole');
        print('Building Name: $_buildingName');
      } else if (mounted) {
        print('WARNING: Admin document does not exist');
        setState(() {
          _buildingName = 'HOMINODE Property Management';
          _isLoadingUserData = false;
        });
      }
      print('===================================');
    } catch (e) {
      print('ERROR loading admin data: $e');
      if (mounted) {
        setState(() {
          _buildingName = 'HOMINODE Property Management';
          _isLoadingUserData = false;
        });
      }
    }
  }

  String _formatRole(String role) {
    switch (role.toLowerCase()) {
      case 'super_admin':
      case 'superadmin':
        return 'Super Administrator';
      case 'admin':
        return 'Administrator';
      case 'manager':
        return 'Manager';
      case 'staff':
        return 'Staff Member';
      default:
        return 'Administrator';
    }
  }

  @override
  void dispose() {
    _notificationService.removeListener(_onNotificationUpdate);
    super.dispose();
  }

  void _onNotificationUpdate() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildModernHeader(),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                _buildStatisticCards(),
                const SizedBox(height: 12),
                _buildAlertCards(),
                const SizedBox(height: 16),
                _buildQuickAccess(),
                const SizedBox(height: 16),
                _buildRealTimeAlerts(),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: const StandardBottomNav(selectedIndex: 0),
    );
  }

  // Modern Flow UI Header
  Widget _buildModernHeader() {
    return SliverAppBar(
      expandedHeight: 180,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: Colors.white,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF2563EB), Color(0xFF1E40AF)],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Top Row - Profile & Notifications
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Profile Section
                      Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.3),
                                width: 2,
                              ),
                            ),
                            child: const Icon(
                              Icons.person,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Welcome back,',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _adminName,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black.withOpacity(0.1),
                                      offset: const Offset(0, 1),
                                      blurRadius: 2,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      // Notification Bell
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const NotificationsScreen(),
                            ),
                          );
                        },
                        child: NotificationBadge(
                          showBadge: _notificationService.unreadCount > 0,
                          count: _notificationService.unreadCount,
                          top: -2,
                          right: -2,
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.notifications_outlined,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Society Name & Info
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.apartment,
                              color: Colors.white,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _buildingName,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withOpacity(0.9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'Active',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Date & Time
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        color: Colors.white70,
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _getCurrentDate(),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Icon(Icons.access_time, color: Colors.white70, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        _getCurrentTime(),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _getCurrentDate() {
    final now = DateTime.now();
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${now.day} ${months[now.month - 1]}, ${now.year}';
  }

  String _getCurrentTime() {
    final now = DateTime.now();
    final hour = now.hour > 12
        ? now.hour - 12
        : (now.hour == 0 ? 12 : now.hour);
    final minute = now.minute.toString().padLeft(2, '0');
    final period = now.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  // 3️⃣ Statistic Cards Row with Real-time Data
  Widget _buildStatisticCards() {
    return StreamBuilder<DashboardStats>(
      stream: _dashboardService.getDashboardStats(_communityId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(child: _buildLoadingCard()),
                const SizedBox(width: 12),
                Expanded(child: _buildLoadingCard()),
                const SizedBox(width: 12),
                Expanded(child: _buildLoadingCard()),
              ],
            ),
          );
        }

        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final stats = snapshot.data!;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  icon: Icons.people,
                  iconColor: const Color(0xFF2563EB),
                  iconBg: const Color(0xFFE0EDFF),
                  value: '${stats.totalResidents}',
                  label: 'Total Residents',
                  subtitle: 'Active users',
                  subtitleColor: const Color(0xFF2563EB),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  icon: Icons.apartment,
                  iconColor: const Color(0xFF10B981),
                  iconBg: const Color(0xFFD1FAE5),
                  value: '${stats.totalFlats}',
                  label: 'Total Flats',
                  subtitle: 'All units',
                  subtitleColor: const Color(0xFF10B981),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  icon: Icons.person_outline,
                  iconColor: const Color(0xFF8B5CF6),
                  iconBg: const Color(0xFFEDE9FE),
                  value: '${stats.pendingVisitors}',
                  label: 'Pending Visitors',
                  subtitle: 'Awaiting approval',
                  subtitleColor: const Color(0xFF8B5CF6),
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
            ],
          ),
        );
      },
    );
  }

  Widget _buildLoadingCard() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: 40,
            height: 18,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: 60,
            height: 11,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String value,
    required String label,
    required String subtitle,
    required Color subtitleColor,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap ?? () {},
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111111),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w400,
                color: Color(0xFF6A6A6A),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: subtitleColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 4️⃣ Alert Highlight Cards Row with Real-time Data
  Widget _buildAlertCards() {
    return StreamBuilder<DashboardStats>(
      stream: _dashboardService.getDashboardStats(_communityId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(child: _buildLoadingAlertCard()),
                const SizedBox(width: 12),
                Expanded(child: _buildLoadingAlertCard()),
              ],
            ),
          );
        }

        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final stats = snapshot.data!;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ComplaintManagementScreen(),
                      ),
                    );
                  },
                  child: _buildAlertCard(
                    icon: Icons.warning_rounded,
                    iconColor: const Color(0xFFFF4747),
                    iconBg: const Color(0xFFFFE5E5),
                    value: '${stats.pendingComplaints}',
                    label: 'Pending Complaints',
                    subtitle: 'Needs attention',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const BillingScreen(),
                      ),
                    );
                  },
                  child: _buildAlertCard(
                    icon: Icons.account_balance_wallet,
                    iconColor: const Color(0xFF10B981),
                    iconBg: const Color(0xFFD1FAE5),
                    value: stats.formattedCollection,
                    label: 'This Month Collection',
                    subtitle: 'Paid bills',
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLoadingAlertCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 22,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: 80,
                  height: 13,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String value,
    required String label,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            child: Icon(icon, color: iconColor, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111111),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF6A6A6A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    color: iconColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 5️⃣ Quick Access Section
  Widget _buildQuickAccess() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Quick Actions',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111111),
                ),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const QuickAccessPage(),
                    ),
                  );
                },
                child: const Text(
                  'View All',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF2563EB),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildQuickAccessButton(
                icon: Icons.apartment,
                label: 'Add Building',
                color: const Color(0xFF2563EB),
                bgColor: const Color(0xFFE0EDFF),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ManageBuildingsPage(),
                    ),
                  );
                },
              ),
              _buildQuickAccessButton(
                icon: Icons.receipt_long,
                label: 'Add Bill',
                color: const Color(0xFF10B981),
                bgColor: const Color(0xFFD1FAE5),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const BillingScreen(),
                    ),
                  );
                },
              ),
              _buildQuickAccessButton(
                icon: Icons.how_to_reg,
                label: 'Approve Visitor',
                color: const Color(0xFFF4A100),
                bgColor: const Color(0xFFFFF4E5),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const VisitorManagementScreen(),
                    ),
                  );
                },
              ),
              _buildQuickAccessButton(
                icon: Icons.security,
                label: 'Security',
                color: const Color(0xFF8B5CF6),
                bgColor: const Color(0xFFEDE9FE),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SecurityManagementScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildQuickAccessButton(
                icon: Icons.people,
                label: 'Residents',
                color: const Color(0xFF059669),
                bgColor: const Color(0xFFECFDF5),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AdminResidentsPageFirestore(),
                    ),
                  );
                },
              ),
              _buildQuickAccessButton(
                icon: Icons.event,
                label: 'Events',
                color: const Color(0xFF8B5CF6),
                bgColor: const Color(0xFFEDE9FE),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const EventsAnnouncementsScreen(),
                    ),
                  );
                },
              ),
              _buildQuickAccessButton(
                icon: Icons.local_parking,
                label: 'Parking',
                color: const Color(0xFF6366F1),
                bgColor: const Color(0xFFEEF2FF),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          const ParkingManagementScreenEnhanced(),
                    ),
                  );
                },
              ),
              _buildQuickAccessButton(
                icon: Icons.apartment,
                label: 'Amenities',
                color: const Color(0xFF8B5CF6),
                bgColor: const Color(0xFFF3E8FF),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AmenitiesManagementScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickAccessButton({
    required IconData icon,
    required String label,
    required Color color,
    required Color bgColor,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap ?? () {},
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 75,
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Color(0xFF111111),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 7️⃣ Real-time Alerts Section - Real Data Only
  Widget _buildRealTimeAlerts() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Real-time Alerts',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111111),
                ),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const NotificationsScreen(),
                    ),
                  );
                },
                child: const Text(
                  'View All',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF2563EB),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _buildRealNotificationsStream(),
      ],
    );
  }

  Widget _buildRealNotificationsStream() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _getAdminNotifications(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Column(
            children: [
              _buildLoadingAlertItem(),
              _buildLoadingAlertItem(),
              _buildLoadingAlertItem(),
            ],
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Center(
              child: Text(
                'No alerts at the moment',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
            ),
          );
        }

        final notifications = snapshot.data!;
        return Column(
          children: notifications
              .take(4) // Show only last 4 notifications
              .map((notification) => _buildRealAlertItem(notification))
              .toList(),
        );
      },
    );
  }

  Stream<List<Map<String, dynamic>>> _getAdminNotifications() {
    try {
      print('🔵 NOTIFICATIONS LOAD: Starting...');

      // STEP 1: Validate Admin Authentication
      print('🔐 STEP 1: Validating admin authentication...');
      final adminId = _adminId;
      if (adminId.isEmpty) {
        throw Exception('Admin not authenticated');
      }
      print('✅ STEP 1 PASSED: Admin authenticated');

      // STEP 2: Fetch Real Notifications from Firestore
      print('📋 STEP 2: Fetching real notifications...');
      return FirebaseFirestore.instance
          .collection('notifications')
          .where('communityId', isEqualTo: _communityId)
          .orderBy('timestamp', descending: true)
          .limit(10)
          .snapshots()
          .map((snapshot) {
            print('✅ STEP 2 PASSED: Notifications fetched');

            // STEP 3: Transform Firestore Data
            print('📝 STEP 3: Transforming notification data...');
            final notifications = snapshot.docs.map((doc) {
              final data = doc.data();
              return {
                'id': doc.id,
                'title': data['title'] ?? 'Notification',
                'message': data['message'] ?? '',
                'type': data['type'] ?? 'general',
                'priority': data['priority'] ?? 'medium',
                'timestamp': data['timestamp'] as Timestamp?,
                'isRead': data['isRead'] ?? false,
                'metadata': data['metadata'] ?? {},
              };
            }).toList();
            print('✅ STEP 3 PASSED: Data transformed');

            // STEP 4: Return Real Data
            print('🔔 STEP 4: Returning real notifications...');
            print('✅ NOTIFICATIONS LOAD: COMPLETE');
            return notifications;
          });
    } catch (e) {
      print('❌ ERROR: $e');
      return Stream.value([]);
    }
  }

  Widget _buildLoadingAlertItem() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 150,
                  height: 13,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: 80,
                  height: 11,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRealAlertItem(Map<String, dynamic> notification) {
    final type = notification['type'] as String;
    final timestamp = notification['timestamp'] as Timestamp?;
    final timeAgo = _getTimeAgo(timestamp?.toDate());

    // Determine icon and color based on notification type
    IconData icon = Icons.notifications;
    Color iconColor = const Color(0xFF6A6A6A);
    Color iconBg = const Color(0xFFF1F1F1);

    switch (type.toLowerCase()) {
      case 'visitor':
        icon = Icons.person_add;
        iconColor = const Color(0xFF10B981);
        iconBg = const Color(0xFFD1FAE5);
        break;
      case 'complaint':
        icon = Icons.warning_rounded;
        iconColor = const Color(0xFFF4A100);
        iconBg = const Color(0xFFFFF4E5);
        break;
      case 'payment':
        icon = Icons.payment;
        iconColor = const Color(0xFF2563EB);
        iconBg = const Color(0xFFE0EDFF);
        break;
      case 'security':
        icon = Icons.security;
        iconColor = const Color(0xFFEF4444);
        iconBg = const Color(0xFFFFE5E5);
        break;
      case 'maintenance':
        icon = Icons.build;
        iconColor = const Color(0xFF8B5CF6);
        iconBg = const Color(0xFFEDE9FE);
        break;
      case 'event':
        icon = Icons.event;
        iconColor = const Color(0xFF06B6D4);
        iconBg = const Color(0xFFCFFAFE);
        break;
      default:
        icon = Icons.check_circle;
        iconColor = const Color(0xFF6A6A6A);
        iconBg = const Color(0xFFF1F1F1);
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notification['title'] ?? 'Notification',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111111),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  timeAgo,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF6A6A6A),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getTimeAgo(DateTime? dateTime) {
    if (dateTime == null) return 'Just now';

    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} min${difference.inMinutes > 1 ? 's' : ''} ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }
}
