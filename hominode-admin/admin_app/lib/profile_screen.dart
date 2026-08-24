import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'theme/hominode_theme.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'widgets/standard_bottom_nav.dart';
import 'widgets/edit_profile_modal.dart';
import 'services/auth_service.dart';
import 'services/admin_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _userName = '';
  String _userEmail = '';
  String _userRole = '';
  int _totalProperties = 0;
  int _totalResidents = 0;
  String _joinYear = '';
  bool _isLoading = true;

  final AdminService _adminService = AdminService();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      print('🔵 PROFILE LOAD: Starting...');

      // STEP 1: Validate Admin Authentication
      print('🔐 STEP 1: Validating admin authentication...');
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }
      print('✅ STEP 1 PASSED: Admin authenticated');

      // STEP 2: Fetch Admin Profile Data
      print('📋 STEP 2: Fetching admin profile data...');
      final adminProfile = await _adminService.getAdminProfile();
      if (adminProfile == null) {
        throw Exception('Admin profile not found');
      }
      print('✅ STEP 2 PASSED: Admin profile fetched');

      // STEP 3: Fetch Building and Resident Statistics
      print('📝 STEP 3: Fetching statistics...');
      final buildingIds = await _adminService.getAdminBuildingIds();
      int totalResidents = 0;

      // Count residents across all buildings
      for (String buildingId in buildingIds) {
        final residentsSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .where('buildingId', isEqualTo: buildingId)
            .where('role', isEqualTo: 'resident')
            .get();
        totalResidents += residentsSnapshot.docs.length;
      }

      final createdAt = adminProfile['createdAt'] as Timestamp?;
      final joinYear = createdAt != null
          ? createdAt.toDate().year.toString()
          : DateTime.now().year.toString();

      print('✅ STEP 3 PASSED: Statistics calculated');

      // STEP 4: Update UI with Real Data
      print('🔔 STEP 4: Updating UI...');
      if (mounted) {
        setState(() {
          _userName = adminProfile['name'] ?? 'Admin';
          _userEmail = adminProfile['email'] ?? user.email ?? '';
          _userRole = _formatRole(adminProfile['role'] ?? 'admin');
          _totalProperties = buildingIds.length;
          _totalResidents = totalResidents;
          _joinYear = joinYear;
          _isLoading = false;
        });
      }
      print('✅ STEP 4 PASSED: UI updated');
      print('✅ PROFILE LOAD: COMPLETE');
    } catch (e) {
      print('❌ ERROR: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _formatRole(String role) {
    switch (role.toLowerCase()) {
      case 'super_admin':
      case 'superadmin':
        return 'Super Admin';
      case 'admin':
        return 'Admin';
      case 'manager':
        return 'Manager';
      case 'staff':
        return 'Staff';
      default:
        return 'Admin';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                _buildProfileHeader(),
                SliverToBoxAdapter(
                  child: Column(
                    children: [
                      _buildQuickActions(),
                      _buildAccountSection(),
                      _buildSupportSection(),
                      SizedBox(height: 100.h),
                    ],
                  ),
                ),
              ],
            ),
      bottomNavigationBar: const StandardBottomNav(selectedIndex: 4),
    );
  }

  Widget _buildProfileHeader() {
    return SliverToBoxAdapter(
      child: Container(
        margin: EdgeInsets.only(
          top: 50.h,
          left: 16.w,
          right: 16.w,
          bottom: 16.h,
        ),
        padding: EdgeInsets.all(24.w),
        decoration: BoxDecoration(
          gradient: HominodeTheme.primaryGradient,
          borderRadius: BorderRadius.circular(20.r),
          boxShadow: [
            BoxShadow(
              color: HominodeTheme.blue.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Stack(
                  children: [
                    Container(
                      width: 80.w,
                      height: 80.h,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(40.r),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 3,
                        ),
                      ),
                      child: Icon(
                        Icons.person,
                        color: Colors.white,
                        size: 40.w,
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: EdgeInsets.all(6.w),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981),
                          borderRadius: BorderRadius.circular(20.r),
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: Icon(
                          Icons.verified,
                          color: Colors.white,
                          size: 16.w,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(width: 20.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _userName,
                        style: TextStyle(
                          fontSize: 24.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        _userEmail,
                        style: TextStyle(
                          fontSize: 16.sp,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                      SizedBox(height: 8.h),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12.w,
                          vertical: 6.h,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20.r),
                        ),
                        child: Text(
                          _userRole,
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 20.h),
            Row(
              children: [
                Expanded(
                  child: _buildHeaderStat(
                    'Properties',
                    _totalProperties.toString(),
                  ),
                ),
                Container(
                  width: 1.w,
                  height: 40.h,
                  color: Colors.white.withOpacity(0.3),
                ),
                Expanded(
                  child: _buildHeaderStat(
                    'Residents',
                    _totalResidents.toString(),
                  ),
                ),
                Container(
                  width: 1.w,
                  height: 40.h,
                  color: Colors.white.withOpacity(0.3),
                ),
                Expanded(child: _buildHeaderStat('Member Since', _joinYear)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20.sp,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        SizedBox(height: 4.h),
        Text(
          label,
          style: TextStyle(
            fontSize: 12.sp,
            color: Colors.white.withOpacity(0.8),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickStats() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              'Today\'s Tasks',
              '12',
              Icons.task_alt,
              const Color(0xFF10B981),
              const Color(0xFFECFDF5),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: _buildStatCard(
              'Notifications',
              '5',
              Icons.notifications_active,
              const Color(0xFFF59E0B),
              const Color(0xFFFEF3C7),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: _buildStatCard(
              'Messages',
              '8',
              Icons.message,
              const Color(0xFF8B5CF6),
              const Color(0xFFF3E8FF),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
    Color bgColor,
  ) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(8.w),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Icon(icon, color: color, size: 20.w),
          ),
          SizedBox(height: 8.h),
          Text(
            value,
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            title,
            style: TextStyle(fontSize: 11.sp, color: Color(0xFF6B7280)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Container(
      margin: EdgeInsets.all(16.w),
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: HominodeTheme.teal.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Icon(
                  Icons.flash_on,
                  color: HominodeTheme.blue,
                  size: 20.w,
                ),
              ),
              SizedBox(width: 12.w),
              Text(
                'Quick Actions',
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF111827),
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Row(
            children: [
              Expanded(
                child: _buildQuickActionButton(
                  'Edit Profile',
                  Icons.edit,
                  HominodeTheme.blue,
                  () async {
                    await showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) => const EditProfileModal(),
                    );
                    // Reload user data after modal closes
                    _loadUserData();
                  },
                ),
              ),
              SizedBox(width: 12.w),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24.w),
            SizedBox(height: 8.h),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountSection() {
    return _buildSection(
      'Account',
      Icons.account_circle_outlined,
      const Color(0xFF10B981),
      [
        _buildSectionItem(
          'Edit Profile',
          'Update your information',
          Icons.person_outline,
          () async {
            await showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (context) => const EditProfileModal(),
            );
            _loadUserData();
          },
        ),
      ],
    );
  }

  Widget _buildSupportSection() {
    return _buildSection(
      'Support',
      Icons.help_outline,
      const Color(0xFFF59E0B),
      [
        _buildSectionItem(
          'Sign Out',
          'Sign out of your account',
          Icons.logout,
          () {
            _showSignOutDialog();
          },
          isDestructive: true,
        ),
      ],
    );
  }

  Widget _buildSection(
    String title,
    IconData icon,
    Color color,
    List<Widget> children,
  ) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(20.w),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8.w),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Icon(icon, color: color, size: 20.w),
                ),
                SizedBox(width: 12.w),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF111827),
                  ),
                ),
              ],
            ),
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSectionItem(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap, {
    bool isDestructive = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12.r),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
        child: Row(
          children: [
            Icon(
              icon,
              color: isDestructive
                  ? const Color(0xFFEF4444)
                  : const Color(0xFF6B7280),
              size: 20.w,
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                      color: isDestructive
                          ? const Color(0xFFEF4444)
                          : const Color(0xFF111827),
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 14.sp, color: Color(0xFF6B7280)),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: const Color(0xFF9CA3AF),
              size: 20.w,
            ),
          ],
        ),
      ),
    );
  }

  void _showSignOutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text(
          'Are you sure you want to sign out of your account?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // Close dialog

              // Show loading indicator
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => WillPopScope(
                  onWillPop: () async => false,
                  child: const Center(child: CircularProgressIndicator()),
                ),
              );

              try {
                // Sign out using AuthService
                await AuthService().signOut();

                // Wait a moment for Firebase to process the sign out
                await Future.delayed(const Duration(milliseconds: 300));

                if (mounted) {
                  // Close loading dialog
                  Navigator.of(context).pop();

                  // Navigate to login and remove all previous routes
                  Navigator.of(
                    context,
                  ).pushNamedAndRemoveUntil('/login', (route) => false);
                }
              } catch (e) {
                if (mounted) {
                  // Close loading dialog
                  Navigator.of(context).pop();

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Sign out failed: ${e.toString()}'),
                      backgroundColor: const Color(0xFFEF4444),
                    ),
                  );
                }
              }
            },
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFEF4444),
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }
}
