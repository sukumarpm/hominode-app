import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/security_user_model.dart';
import '../models/attendance_model.dart';
import '../services/attendance_service.dart';
import '../services/security_inbox_service.dart';
import 'security_notifications_screen.dart';
import '../services/auth_service.dart';
import '../services/account_deletion_request_service.dart';
import 'account_deletion_request_screen.dart';
import 'help_support_screen.dart';
import '../services/support_request_service.dart';
import '../utils/app_colors.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    this.authService,
    this.deletionRequests,
    this.supportRequests,
    this.inbox,
    this.attendanceStream,
  });
  final AuthService? authService;
  final SecurityDeletionRequests? deletionRequests;
  final SecuritySupportRequests? supportRequests;
  final SecurityInbox? inbox;
  final Stream<AttendanceModel?> Function(SecurityUserModel)? attendanceStream;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final AuthService _authService = widget.authService ?? AuthService();
  SecurityUserModel? _currentUser;
  bool _isLoading = true;
  bool _isLoggingOut = false;
  Stream<AttendanceModel?>? _attendanceStream;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    try {
      if (_authService.currentUser == null) throw StateError('Sign in again.');
      final staffDetails = await _authService.requireSecurityProfile();
      if (mounted) {
        setState(() {
          _currentUser = staffDetails;
          _attendanceStream =
              widget.attendanceStream?.call(staffDetails) ??
              _watchAttendance(staffDetails);
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _currentUser = null;
          _isLoading = false;
        });
      }
    }
  }

  Stream<AttendanceModel?> _watchAttendance(SecurityUserModel user) async* {
    yield* AttendanceService().getTodayAttendanceStream(user);
  }

  void _showNotifications() {
    HapticFeedback.mediumImpact();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SecurityNotificationsScreen(inbox: widget.inbox),
      ),
    );
  }

  void _showHelpSupport() {
    HapticFeedback.mediumImpact();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => HelpSupportScreen(requests: widget.supportRequests),
      ),
    );
  }

  void _contactAdmin() {
    HapticFeedback.mediumImpact();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => HelpSupportScreen(
          requests: widget.supportRequests,
          initialTopic: 'account_access',
        ),
      ),
    );
  }

  Future<void> _logout() async {
    if (_isLoggingOut) return;

    HapticFeedback.mediumImpact();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.errorRed,
              foregroundColor: Colors.white,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _isLoggingOut = true;
    });

    try {
      await _authService.logout();

      if (!mounted) return;

      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoggingOut = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Logout failed: $e'),
          backgroundColor: AppColors.errorRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.primaryTeal,
        body: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
      );
    }

    if (_currentUser == null) {
      return Scaffold(
        backgroundColor: AppColors.primaryTeal,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.white, size: 48),
              const SizedBox(height: 16),
              const Text(
                'Failed to load profile',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => _loadCurrentUser(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.primaryTeal,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                  const Text(
                    'Profile & Shift',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            // Profile Card
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.accentTeal,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                    ),
                    child: const Icon(
                      Icons.person,
                      size: 40,
                      color: AppColors.primaryTeal,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _currentUser!.name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _currentUser!.role,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _currentUser!.securityId ?? 'Not assigned',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Content Area
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildShiftDetailsCard(),
                      const SizedBox(height: 20),
                      _buildContactInformationCard(),
                      const SizedBox(height: 20),
                      _buildSettingsSection(),
                      const SizedBox(height: 20),
                      _buildContactAdminButton(),
                      const SizedBox(height: 16),
                      _buildLogoutButton(),
                      const SizedBox(height: 24),
                      Center(
                        child: Text(
                          'Security Guard App v1.0.0',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: Colors.grey[400],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShiftDetailsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
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
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primaryTeal.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.access_time,
                  color: AppColors.primaryTeal,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Current Shift Details',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildDetailRow(
            label: 'Shift Timing',
            value: _currentUser?.displayShift ?? 'Not assigned',
            valueColor: AppColors.textDark,
          ),
          const SizedBox(height: 16),
          _buildDetailRow(
            label: 'Gate Assignment',
            value: _currentUser?.displayGate ?? 'Not assigned',
            valueColor: AppColors.textDark,
          ),
          const SizedBox(height: 16),
          _buildDetailRow(
            label: 'Building',
            value: _currentUser?.buildingId ?? 'Not assigned',
            valueColor: AppColors.textDark,
          ),
          const SizedBox(height: 16),
          _buildDetailRow(
            label: 'Community',
            value: _currentUser?.communityId ?? 'Not assigned',
            valueColor: AppColors.textDark,
          ),
          const SizedBox(height: 16),
          _buildDetailRow(
            label: 'Account Status',
            value: _currentUser!.isActive ? 'Active' : 'Inactive',
            valueColor: AppColors.textDark,
          ),
          const SizedBox(height: 16),
          StreamBuilder<AttendanceModel?>(
            stream: _attendanceStream,
            builder: (context, snapshot) {
              final attendance = snapshot.data;
              final onDuty =
                  attendance != null &&
                  attendance.staffId == _currentUser!.uid &&
                  attendance.status == 'checked_in' &&
                  attendance.checkOutTime == null;
              final label = snapshot.hasError
                  ? 'Unavailable — retry'
                  : snapshot.connectionState == ConnectionState.waiting
                  ? 'Checking attendance…'
                  : onDuty
                  ? 'On Duty'
                  : 'Not Checked In';
              return Column(
                children: [
                  _buildDetailRow(
                    label: 'Duty Status',
                    value: label,
                    valueColor: onDuty && !snapshot.hasError
                        ? AppColors.successGreen
                        : AppColors.textGray,
                  ),
                  if (snapshot.hasError)
                    TextButton(
                      onPressed: () => setState(() {
                        _attendanceStream =
                            widget.attendanceStream?.call(_currentUser!) ??
                            _watchAttendance(_currentUser!);
                      }),
                      child: const Text('Retry duty status'),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildContactInformationCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Contact Information',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 20),
          _buildContactItem(
            icon: Icons.phone_outlined,
            iconColor: AppColors.primaryTeal,
            iconBgColor: AppColors.primaryTeal.withValues(alpha: 0.1),
            label: 'Phone Number',
            value: _currentUser?.phoneNumber ?? 'Not provided',
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow({
    required String label,
    required String value,
    required Color valueColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: AppColors.textGray,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: valueColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContactItem({
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: iconBgColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textGray,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            'Settings',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildSettingItem(
                icon: Icons.notifications_outlined,
                title: 'Notifications',
                onTap: _showNotifications,
              ),
              const Divider(height: 1, indent: 68),
              _buildSettingItem(
                icon: Icons.help_outline,
                title: 'Help & Support',
                onTap: _showHelpSupport,
              ),
              const Divider(height: 1, indent: 68),
              _buildSettingItem(
                icon: Icons.person_remove_outlined,
                title: 'Request Account Deletion',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => SecurityAccountDeletionRequestScreen(
                      requests: widget.deletionRequests,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primaryTeal.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.primaryTeal, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textDark,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFF9CA3AF), size: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildContactAdminButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _contactAdmin,
        icon: const Icon(Icons.chat_bubble_outline, size: 20),
        label: const Text(
          'Contact Admin',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryTeal,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
      ),
    );
  }

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: _isLoggingOut ? null : _logout,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.errorRed,
          side: BorderSide(
            color: _isLoggingOut
                ? AppColors.errorRed.withValues(alpha: 0.45)
                : AppColors.errorRed,
            width: 1.5,
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isLoggingOut
            ? const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: AppColors.errorRed,
                    ),
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Signing out…',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ],
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.logout, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Logout',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
      ),
    );
  }
}
