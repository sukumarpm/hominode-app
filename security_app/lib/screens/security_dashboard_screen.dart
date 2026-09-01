import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hominode_notifications/hominode_notifications.dart';

import '../models/attendance_model.dart';
import '../models/security_user_model.dart';
import '../services/attendance_service.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../utils/app_colors.dart';
import 'profile_screen.dart';
import 'qr_scanner_screen.dart';
import 'staff_attendance_screen.dart';
import 'visitor_management_screen.dart';

class SecurityDashboardScreen extends StatefulWidget {
  const SecurityDashboardScreen({super.key});

  @override
  State<SecurityDashboardScreen> createState() =>
      _SecurityDashboardScreenState();
}

class _SecurityDashboardScreenState extends State<SecurityDashboardScreen> {
  int _selectedIndex = 0;
  final AuthService _authService = AuthService();
  final AttendanceService _attendanceService = AttendanceService();
  final NotificationService _notificationService = NotificationService();
  SecurityUserModel? _currentUser;
  AttendanceModel? _todayAttendance;
  bool _isCheckingIn = false;
  List<Map<String, dynamic>> _notifications = [];

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    try {
      final user = _authService.currentUser;
      if (user != null) {
        final staffDetails = await _authService.requireSecurityProfile();
        await HominodePushNotifications.instance.activate();
        if (mounted) {
          setState(() {
            _currentUser = staffDetails;
            // Load notifications based on user data
            _notifications = _notificationService.getUserNotifications(
              staffDetails,
            );
          });
          // Load today's attendance
          _loadTodayAttendance();
        }
      } else {
        // User not authenticated, redirect to login
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/login');
        }
      }
    } catch (e) {
      print('Error loading current user: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load user data: $e'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    }
  }

  Future<void> _loadTodayAttendance() async {
    if (_currentUser != null) {
      try {
        final attendance = await _attendanceService.getTodayAttendance(
          _currentUser!,
        );
        if (mounted) {
          setState(() {
            _todayAttendance = attendance;
          });
        }
      } catch (e) {
        print('Error loading today attendance: $e');
      }
    }
  }

  Future<void> _handleCheckIn() async {
    if (_currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User data not loaded. Please try again.'),
          backgroundColor: AppColors.errorRed,
        ),
      );
      return;
    }

    setState(() {
      _isCheckingIn = true;
    });

    HapticFeedback.mediumImpact();

    final result = await _attendanceService.recordCheckIn(_currentUser!);

    if (mounted) {
      setState(() {
        _isCheckingIn = false;
      });

      if (result['success']) {
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']),
            backgroundColor: AppColors.successGreen,
            duration: const Duration(seconds: 2),
          ),
        );
        // StreamBuilder will automatically update the UI
      } else {
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Check-in failed'),
            backgroundColor: AppColors.errorRed,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _handleCheckOut() async {
    if (_currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User data not loaded. Please try again.'),
          backgroundColor: AppColors.errorRed,
        ),
      );
      return;
    }

    // Get the latest attendance from Firestore
    final attendance = await _attendanceService.getTodayAttendance(
      _currentUser!,
    );

    if (attendance == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No active check-in found'),
          backgroundColor: AppColors.errorRed,
        ),
      );
      return;
    }

    setState(() {
      _isCheckingIn = true;
    });

    HapticFeedback.mediumImpact();

    final result = await _attendanceService.recordCheckOut(
      _currentUser!,
      attendance.id,
    );

    if (mounted) {
      setState(() {
        _isCheckingIn = false;
      });

      if (result['success']) {
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']),
            backgroundColor: AppColors.successGreen,
            duration: const Duration(seconds: 2),
          ),
        );
        // StreamBuilder will automatically update the UI
      } else {
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Check-out failed'),
            backgroundColor: AppColors.errorRed,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        toolbarHeight: 76,
        elevation: 0,
        centerTitle: false,
        backgroundColor: AppColors.darkEmerald,
        titleSpacing: 20,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Hominode Security',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.4,
              ),
            ),
            SizedBox(height: 3),
            Text(
              'Security Dashboard',
              style: TextStyle(
                color: Colors.white,
                fontSize: 21,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 18),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              ),
              child: const Icon(
                Icons.shield_outlined,
                color: Color(0xFFD4A72C),
                size: 23,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 110),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPageHeader(),
              _buildNotificationsSection(),
              _buildAttendanceCard(),
              _buildStatisticsCards(),
              _buildQuickActions(),
              _buildRecentActivity(),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const QRScannerScreen()),
          );
        },
        backgroundColor: AppColors.primaryTeal,
        foregroundColor: Colors.white,
        elevation: 5,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        icon: const Icon(Icons.qr_code_scanner_rounded, size: 22),
        label: const Text(
          'Scan QR',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildPageHeader() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.darkEmerald, AppColors.primaryTeal],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.darkEmerald.withValues(alpha: 0.14),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
            ),
            child: const Icon(
              Icons.shield_rounded,
              color: AppColors.goldAccent,
              size: 31,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'SECURITY OFFICER',
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _currentUser?.name ?? 'Loading...',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 13),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildProfileChip(
                      Icons.location_on_rounded,
                      _currentUser?.displayGate ?? 'Not Assigned',
                      AppColors.accentTeal,
                    ),
                    _buildProfileChip(
                      Icons.schedule_rounded,
                      _currentUser?.shiftTiming ?? 'No Shift',
                      AppColors.goldAccent,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileChip(IconData icon, String text, Color accent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: accent, size: 15),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsSection() {
    if (_notifications.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Alerts', Icons.notifications_none_rounded),
          const SizedBox(height: 10),
          ..._notifications.map((notification) {
            final color = _getNotificationColor(notification['color']);
            final icon = _getNotificationIcon(notification['icon']);

            final isWarning = notification['color'] == 'warning';

            return Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 9),
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: isWarning
                    ? AppColors.softGoldBackground
                    : color.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isWarning
                      ? AppColors.goldAccent.withValues(alpha: 0.35)
                      : color.withValues(alpha: 0.20),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 39,
                    height: 39,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          notification['title'],
                          style: const TextStyle(
                            color: AppColors.textDark,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          notification['message'],
                          style: const TextStyle(
                            color: AppColors.textGray,
                            fontSize: 12,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primaryTeal, size: 19),
        const SizedBox(width: 7),
        Text(
          title,
          style: const TextStyle(
            color: AppColors.textDark,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Color _getNotificationColor(String colorType) {
    switch (colorType) {
      case 'success':
        return AppColors.successGreen;
      case 'warning':
        return AppColors.warningOrange;
      case 'error':
        return AppColors.errorRed;
      default:
        return AppColors.primaryBlue;
    }
  }

  IconData _getNotificationIcon(String iconType) {
    switch (iconType) {
      case 'schedule':
        return Icons.schedule;
      case 'location_on':
        return Icons.location_on;
      case 'warning':
        return Icons.warning_rounded;
      default:
        return Icons.info_rounded;
    }
  }

  Widget _buildAttendanceCard() {
    if (_currentUser == null) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<AttendanceModel?>(
      stream: _attendanceService.getTodayAttendanceStream(_currentUser!),
      builder: (context, snapshot) {
        final attendance = snapshot.data;

        final isCheckedIn =
            attendance != null && attendance.checkOutTime == null;

        final statusColor = isCheckedIn
            ? AppColors.successGreen
            : AppColors.warningOrange;

        final statusText = isCheckedIn ? 'On Duty' : 'Not Checked In';

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.divider),
            boxShadow: [
              BoxShadow(
                color: AppColors.darkEmerald.withValues(alpha: 0.05),
                blurRadius: 16,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primaryTeal.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Icon(
                      Icons.badge_outlined,
                      color: AppColors.primaryTeal,
                      size: 23,
                    ),
                  ),
                  const SizedBox(width: 11),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Today\'s Attendance',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Current duty attendance',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textGray,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          statusText,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (isCheckedIn) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.login_rounded,
                        color: AppColors.successGreen,
                        size: 20,
                      ),
                      const SizedBox(width: 9),
                      const Text(
                        'Checked in',
                        style: TextStyle(
                          color: AppColors.textGray,
                          fontSize: 12,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _formatTime(attendance.checkInTime),
                        style: const TextStyle(
                          color: AppColors.textDark,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 17),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _isCheckingIn || isCheckedIn
                            ? null
                            : _handleCheckIn,
                        icon: const Icon(Icons.login_rounded, size: 20),
                        label: const Text(
                          'I AM IN',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryTeal,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: AppColors.divider,
                          disabledForegroundColor: AppColors.textGray,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(13),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: OutlinedButton.icon(
                        onPressed: _isCheckingIn || !isCheckedIn
                            ? null
                            : _handleCheckOut,
                        icon: const Icon(Icons.logout_rounded, size: 20),
                        label: const Text(
                          'I AM OUT',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.darkEmerald,
                          side: const BorderSide(color: AppColors.primaryTeal),
                          disabledForegroundColor: AppColors.textGray,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(13),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // Widget _buildAttendanceDetail(String label, String value, IconData icon) {
  //   return Row(
  //     children: [
  //       Icon(icon, color: AppColors.primaryBlue, size: 18),
  //       const SizedBox(width: 12),
  //       Expanded(
  //         child: Column(
  //           crossAxisAlignment: CrossAxisAlignment.start,
  //           children: [
  //             Text(
  //               label,
  //               style: const TextStyle(
  //                 fontSize: 12,
  //                 fontWeight: FontWeight.w400,
  //                 color: AppColors.textGray,
  //               ),
  //             ),
  //             const SizedBox(height: 2),
  //             Text(
  //               value,
  //               style: const TextStyle(
  //                 fontSize: 14,
  //                 fontWeight: FontWeight.w600,
  //                 color: AppColors.textDark,
  //               ),
  //             ),
  //           ],
  //         ),
  //       ),
  //     ],
  //   );
  // }

  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildStatisticsCards() {
    if (_currentUser == null) {
      return const SizedBox.shrink();
    }

    final user = _currentUser!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('visitors')
                  .where('communityId', isEqualTo: user.communityId)
                  .snapshots(),
              builder: (context, snapshot) {
                int count = 0;

                if (snapshot.hasData) {
                  final now = DateTime.now();

                  final startOfToday = DateTime(now.year, now.month, now.day);

                  final startOfTomorrow = startOfToday.add(
                    const Duration(days: 1),
                  );

                  for (final doc in snapshot.data!.docs) {
                    final data = doc.data() as Map<String, dynamic>;

                    final actualArrival = data['actualArrival'] as Timestamp?;

                    if (actualArrival == null) {
                      continue;
                    }

                    final arrivalDate = actualArrival.toDate();

                    if (!arrivalDate.isBefore(startOfToday) &&
                        arrivalDate.isBefore(startOfTomorrow)) {
                      count++;
                    }
                  }
                }

                return _buildStatCard(
                  'Total',
                  '$count',
                  Icons.people,
                  AppColors.primaryTeal,
                  'Today',
                );
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('visitors')
                  .where('communityId', isEqualTo: user.communityId)
                  .where('status', isEqualTo: 'inside')
                  .snapshots(),
              builder: (context, snapshot) {
                int count = 0;

                if (snapshot.hasData) {
                  for (final doc in snapshot.data!.docs) {
                    final data = doc.data() as Map<String, dynamic>;

                    if (data['actualArrival'] != null &&
                        data['departure'] == null) {
                      count++;
                    }
                  }
                }

                return _buildStatCard(
                  'Active',
                  '$count',
                  Icons.login,
                  AppColors.successGreen,
                  'Inside',
                );
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('visitors')
                  .where('communityId', isEqualTo: user.communityId)
                  .where('status', isEqualTo: 'expected')
                  .snapshots(),
              builder: (context, snapshot) {
                int count = 0;

                if (snapshot.hasData) {
                  for (final doc in snapshot.data!.docs) {
                    final data = doc.data() as Map<String, dynamic>;

                    if (data['isApproved'] == false &&
                        data['actualArrival'] == null &&
                        data['departure'] == null) {
                      count++;
                    }
                  }
                }

                return _buildStatCard(
                  'Pending',
                  '$count',
                  Icons.pending,
                  AppColors.warningOrange,
                  'Requests',
                );
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('visitors')
                  .where('communityId', isEqualTo: user.communityId)
                  .where('status', isEqualTo: 'completed')
                  .snapshots(),
              builder: (context, snapshot) {
                int exitCount = 0;

                if (snapshot.hasData) {
                  final now = DateTime.now();

                  final startOfToday = DateTime(now.year, now.month, now.day);

                  final startOfTomorrow = startOfToday.add(
                    const Duration(days: 1),
                  );

                  for (final doc in snapshot.data!.docs) {
                    final data = doc.data() as Map<String, dynamic>;

                    final departure = data['departure'] as Timestamp?;

                    if (departure == null) {
                      continue;
                    }

                    final departureDate = departure.toDate();

                    if (!departureDate.isBefore(startOfToday) &&
                        departureDate.isBefore(startOfTomorrow)) {
                      exitCount++;
                    }
                  }
                }

                return _buildStatCard(
                  'Exits',
                  '$exitCount',
                  Icons.logout,
                  AppColors.errorRed,
                  'Today',
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
    String subtitle,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 9),
          Text(
            value,
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 9, color: AppColors.textGray),
          ),
        ],
      ),
    );
  }
  // Widget _buildStatCard(
  //   String label,
  //   String value,
  //   IconData icon,
  //   Color color,
  //   String subtitle,
  // ) {
  //   return Container(
  //     padding: const EdgeInsets.all(10),
  //     decoration: BoxDecoration(
  //       color: Colors.white,
  //       borderRadius: BorderRadius.circular(12),
  //       boxShadow: [
  //         BoxShadow(
  //           color: Colors.black.withValues(alpha: 0.05),
  //           blurRadius: 10,
  //           offset: const Offset(0, 2),
  //         ),
  //       ],
  //     ),
  //     child: Column(
  //       children: [
  //         Container(
  //           width: 40,
  //           height: 40,
  //           decoration: BoxDecoration(
  //             color: color.withValues(alpha: 0.1),
  //             shape: BoxShape.circle,
  //           ),
  //           child: Icon(icon, color: color, size: 20),
  //         ),
  //         const SizedBox(height: 8),
  //         Text(
  //           value,
  //           style: TextStyle(
  //             fontSize: 18,
  //             fontWeight: FontWeight.w700,
  //             color: color,
  //           ),
  //         ),
  //         Text(
  //           label,
  //           style: const TextStyle(
  //             fontSize: 11,
  //             fontWeight: FontWeight.w600,
  //             color: AppColors.textDark,
  //           ),
  //         ),
  //         Text(
  //           subtitle,
  //           style: const TextStyle(fontSize: 9, color: AppColors.textGray),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildQuickActionCard(
                  'Scan QR Code',
                  'Quick entry',
                  Icons.qr_code_scanner,
                  AppColors.primaryBlue,
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const QRScannerScreen(),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildQuickActionCard(
                  'View Visitors',
                  'Manage entries',
                  Icons.people,
                  AppColors.successGreen,
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => VisitorManagementScreen(),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionCard(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.divider),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 25),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.textDark,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.textGray,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textGray,
              ),
            ],
          ),
        ),
      ),
    );
  }
  // Widget _buildQuickActionCard(
  //   String title,
  //   String subtitle,
  //   IconData icon,
  //   Color color,
  //   VoidCallback onTap,
  // ) {
  //   return GestureDetector(
  //     onTap: onTap,
  //     child: Container(
  //       padding: const EdgeInsets.all(16),
  //       decoration: BoxDecoration(
  //         color: Colors.white,
  //         borderRadius: BorderRadius.circular(12),
  //         boxShadow: [
  //           BoxShadow(
  //             color: Colors.black.withValues(alpha: 0.05),
  //             blurRadius: 10,
  //             offset: const Offset(0, 2),
  //           ),
  //         ],
  //       ),
  //       child: Column(
  //         children: [
  //           Container(
  //             width: 56,
  //             height: 56,
  //             decoration: BoxDecoration(
  //               color: color.withValues(alpha: 0.1),
  //               borderRadius: BorderRadius.circular(12),
  //             ),
  //             child: Icon(icon, color: color, size: 28),
  //           ),
  //           const SizedBox(height: 12),
  //           Text(
  //             title,
  //             style: const TextStyle(
  //               fontSize: 14,
  //               fontWeight: FontWeight.w600,
  //               color: AppColors.textDark,
  //             ),
  //             textAlign: TextAlign.center,
  //           ),
  //           const SizedBox(height: 4),
  //           Text(
  //             subtitle,
  //             style: const TextStyle(fontSize: 12, color: AppColors.textGray),
  //             textAlign: TextAlign.center,
  //           ),
  //         ],
  //       ),
  //     ),
  //   );
  // }

  Widget _buildRecentActivity() {
    if (_currentUser == null) {
      return const SizedBox.shrink();
    }

    final user = _currentUser!;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recent Activity',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 12),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('staffAttendance')
                .where('communityId', isEqualTo: user.communityId)
                .where('staffId', isEqualTo: user.uid)
                .orderBy('checkInTime', descending: true)
                .limit(5)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Text(
                      'No recent activity',
                      style: TextStyle(fontSize: 14, color: AppColors.textGray),
                    ),
                  ),
                );
              }

              final activities = snapshot.data!.docs;
              return Column(
                children: List.generate(activities.length, (index) {
                  final data = activities[index].data() as Map<String, dynamic>;
                  final staffName = data['staffName'] ?? 'Unknown';
                  final gateName = data['gateName'] ?? 'Unknown Gate';
                  final checkInTime = (data['checkInTime'] as Timestamp?)
                      ?.toDate();
                  final checkOutTime = (data['checkOutTime'] as Timestamp?)
                      ?.toDate();

                  final isCheckOut = checkOutTime != null;
                  final time = isCheckOut ? checkOutTime : checkInTime;
                  final timeStr = time != null
                      ? '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}'
                      : 'N/A';

                  return Column(
                    children: [
                      _buildActivityCard(
                        isCheckOut
                            ? '$staffName checked out'
                            : '$staffName checked in',
                        '$gateName • $timeStr',
                        isCheckOut ? Icons.logout : Icons.login,
                        isCheckOut
                            ? AppColors.errorRed
                            : AppColors.successGreen,
                      ),
                      if (index < activities.length - 1)
                        const SizedBox(height: 8),
                    ],
                  );
                }),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActivityCard(
    String title,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
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
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textGray,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        border: const Border(
          top: BorderSide(color: AppColors.divider, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.darkEmerald.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) {
            if (index == 1) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const VisitorManagementScreen(),
                ),
              );
            } else if (index == 2) {
              final user = _currentUser;

              if (user == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Security profile is still loading. Please try again.',
                    ),
                  ),
                );
                return;
              }

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => StaffAttendanceScreen(user: user),
                ),
              );
            } else if (index == 3) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
            } else {
              setState(() {
                _selectedIndex = index;
              });
            }
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: AppColors.cardBackground,
          selectedItemColor: AppColors.primaryTeal,
          unselectedItemColor: AppColors.textGray,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700),
          selectedFontSize: 11,
          unselectedFontSize: 11,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.grid_view_rounded),
              label: 'Dashboard',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.people_outline_rounded),
              label: 'Visitors',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.schedule_rounded),
              label: 'Attendance',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline_rounded),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }

  // Widget _buildBottomNavigationBar() {
  //   return Container(
  //     decoration: BoxDecoration(
  //       color: Colors.white,
  //       boxShadow: [
  //         BoxShadow(
  //           color: Colors.black.withValues(alpha: 0.05),
  //           blurRadius: 10,
  //           offset: const Offset(0, -2),
  //         ),
  //       ],
  //     ),
  //     child: BottomNavigationBar(
  //       currentIndex: _selectedIndex,
  //       onTap: (index) {
  //         if (index == 1) {
  //           Navigator.push(
  //             context,
  //             MaterialPageRoute(
  //               builder: (context) => const VisitorManagementScreen(),
  //             ),
  //           );
  //         } else if (index == 2) {
  //           Navigator.push(
  //             context,
  //             MaterialPageRoute(
  //               builder: (context) => const StaffAttendanceScreen(),
  //             ),
  //           );
  //         } else if (index == 3) {
  //           Navigator.push(
  //             context,
  //             MaterialPageRoute(builder: (context) => const ProfileScreen()),
  //           );
  //         } else {
  //           setState(() {
  //             _selectedIndex = index;
  //           });
  //         }
  //       },
  //       type: BottomNavigationBarType.fixed,
  //       backgroundColor: Colors.white,
  //       selectedItemColor: AppColors.primaryBlue,
  //       unselectedItemColor: AppColors.textGray,
  //       selectedFontSize: 12,
  //       unselectedFontSize: 12,
  //       elevation: 0,
  //       items: const [
  //         BottomNavigationBarItem(
  //           icon: Icon(Icons.dashboard),
  //           label: 'Dashboard',
  //         ),
  //         BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Visitors'),
  //         BottomNavigationBarItem(
  //           icon: Icon(Icons.access_time),
  //           label: 'Attendance',
  //         ),
  //         BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
  //       ],
  //     ),
  //   );
  // }
}
