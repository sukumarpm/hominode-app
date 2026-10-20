import '../services/notification_preferences_service.dart';
// lib/src/screens/notifications_settings_screen.dart
// Notifications Preferences Screen

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../widgets/resident_visitor_page_background.dart';
// import 'package:shared_preferences/shared_preferences.dart'; // Uncomment when ready to use

class NotificationsSettingsScreen extends StatefulWidget {
  const NotificationsSettingsScreen({super.key});

  @override
  State<NotificationsSettingsScreen> createState() =>
      _NotificationsSettingsScreenState();
}

class _NotificationsSettingsScreenState
    extends State<NotificationsSettingsScreen> {
  // Only essential notifications
  bool _pushNotifications = true;
  bool _emailNotifications = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        toolbarHeight: 56 + (textScale > 1.2 ? 24 : 0),
        title: const Row(
          children: [
            Expanded(child: Text('Notification Settings', softWrap: true)),
          ],
        ),
        backgroundColor: Colors.white.withValues(alpha: 0.82),
        foregroundColor: const Color(0xFF172B4D),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: const Color(0xFF172B4D),
          fontSize: 20.sp,
          fontWeight: FontWeight.w700,
        ),
      ),
      body: ResidentVisitorPageBackground(
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: EdgeInsets.all(16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildNotificationsCard(),
                SizedBox(height: 20.h),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationsCard() {
    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(16.w),
            child: Row(
              children: [
                Container(
                  width: 40.w,
                  height: 40.h,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDBEAFE),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: Icon(
                    Icons.notifications,
                    color: Color(0xFF172B4D),
                    size: 22.w,
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Text(
                    'Notifications',
                    softWrap: true,
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF172B4D),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2EAF3)),
          _buildToggleRow(
            title: 'Push Notifications',
            subtitle: 'Get notified about updates',
            value: _pushNotifications,
            onChanged: (value) {
              setState(() => _pushNotifications = value);
              _savePreference('push_notifications', value);
            },
          ),
          const Divider(
            height: 1,
            color: Color(0xFFE2EAF3),
            indent: 16,
            endIndent: 16,
          ),
          _buildToggleRow(
            title: 'Email Notifications',
            subtitle: 'Receive emails about bills',
            value: _emailNotifications,
            onChanged: (value) {
              setState(() => _emailNotifications = value);
              _savePreference('email_notifications', value);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildToggleRow({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF172B4D),
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 13.sp, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: const Color(0xFF172B4D),
            activeTrackColor: const Color(0xFFDCE6F2),
          ),
        ],
      ),
    );
  }

  // Persistence Methods
  Future<void> _loadPreferences() async {
    final values = await NotificationPreferencesService().getAllPreferences();
    if (!mounted) return;
    setState(() {
      _pushNotifications = values['push_notifications'] as bool? ?? true;
      _emailNotifications = values['email_notifications'] as bool? ?? false;
    });
  }

  Future<void> _savePreference(String key, bool value) async {
    try {
      await NotificationPreferencesService().savePreference(key, value);
    } catch (_) {
      await _loadPreferences();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not update notification preferences. Please retry.',
            ),
          ),
        );
      }
    }
  }
}
