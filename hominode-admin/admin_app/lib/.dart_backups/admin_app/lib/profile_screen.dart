import 'package:flutter/material.dart';
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
                      const SizedBox(height: 100),
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
        margin: const EdgeInsets.only(top: 50, left: 16, right: 16, bottom: 16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2563EB).withOpacity(0.3),
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
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(40),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 3,
                        ),
                      ),
                      child: const Icon(
                        Icons.person,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(
                          Icons.verified,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _userName,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _userEmail,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _userRole,
                          style: const TextStyle(
                            fontSize: 12,
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
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildHeaderStat(
                    'Properties',
                    _totalProperties.toString(),
                  ),
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: Colors.white.withOpacity(0.3),
                ),
                Expanded(
                  child: _buildHeaderStat(
                    'Residents',
                    _totalResidents.toString(),
                  ),
                ),
                Container(
                  width: 1,
                  height: 40,
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
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.8)),
        ),
      ],
    );
  }

  Widget _buildQuickStats() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'Notifications',
              '5',
              Icons.notifications_active,
              const Color(0xFFF59E0B),
              const Color(0xFFFEF3C7),
            ),
          ),
          const SizedBox(width: 12),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.flash_on,
                  color: Color(0xFF2563EB),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Quick Actions',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF111827),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildQuickActionButton(
                  'Edit Profile',
                  Icons.edit,
                  const Color(0xFF2563EB),
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
              const SizedBox(width: 12),
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
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
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
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
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
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Icon(
              icon,
              color: isDestructive
                  ? const Color(0xFFEF4444)
                  : const Color(0xFF6B7280),
              size: 20,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDestructive
                          ? const Color(0xFFEF4444)
                          : const Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: const Color(0xFF9CA3AF), size: 20),
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
