import 'package:flutter/material.dart';
import 'widgets/standard_header.dart';
import 'widgets/edit_profile_modal.dart';
import 'widgets/login_history_modal.dart';
import 'widgets/storage_usage_modal.dart';
import 'services/auth_service.dart';
import 'community_settings_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool notificationsEnabled = true;
  bool emailNotifications = true;
  bool smsNotifications = false;
  bool pushNotifications = true;
  bool darkMode = false;
  bool autoBackup = true;
  bool biometricAuth = false;
  bool twoFactorAuth = false;
  String selectedLanguage = 'English';
  String selectedTheme = 'System';
  String selectedTimeZone = 'Asia/Kolkata';

  final List<String> languages = [
    'English',
    'Hindi',
    'Tamil',
    'Telugu',
    'Marathi',
    'Gujarati',
  ];
  final List<String> themes = ['Light', 'Dark', 'System'];
  final List<String> timeZones = [
    'Asia/Kolkata',
    'Asia/Mumbai',
    'Asia/Delhi',
    'UTC',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          const StandardHeader(title: 'Settings'),
          SliverToBoxAdapter(
            child: Column(
              children: [
                _buildProfileSection(),
                _buildNotificationSettings(),
                _buildAppearanceSettings(),
                _buildSecuritySettings(),
                _buildDataSettings(),
                _buildSystemSettings(),
                _buildSupportSection(),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileSection() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0E4778), Color(0xFF061C4C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0E4778).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(30),
            ),
            child: const Icon(Icons.person, color: Colors.white, size: 30),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Admin User',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'admin@lyvo.com',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Super Admin',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => const EditProfileModal(),
              );
            },
            icon: const Icon(Icons.edit, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationSettings() {
    return _buildSettingsSection(
      'Notifications',
      Icons.notifications_outlined,
      const Color(0xFF10B981),
      [
        _buildSwitchTile(
          'Enable Notifications',
          'Receive all notifications',
          notificationsEnabled,
          (value) => setState(() => notificationsEnabled = value),
        ),
        _buildSwitchTile(
          'Email Notifications',
          'Get notified via email',
          emailNotifications,
          (value) => setState(() => emailNotifications = value),
          enabled: notificationsEnabled,
        ),
        _buildSwitchTile(
          'SMS Notifications',
          'Get notified via SMS',
          smsNotifications,
          (value) => setState(() => smsNotifications = value),
          enabled: notificationsEnabled,
        ),
        _buildSwitchTile(
          'Push Notifications',
          'Get push notifications',
          pushNotifications,
          (value) => setState(() => pushNotifications = value),
          enabled: notificationsEnabled,
        ),
      ],
    );
  }

  Widget _buildAppearanceSettings() {
    return _buildSettingsSection(
      'Appearance',
      Icons.palette_outlined,
      const Color(0xFF8B5CF6),
      [
        _buildActionTile(
          'Community & Invites',
          'Manage resident registration codes',
          Icons.apartment_outlined,
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CommunitySettingsScreen()),
          ),
        ),
        _buildDropdownTile(
          'Theme',
          'Choose app theme',
          selectedTheme,
          themes,
          (value) => setState(() => selectedTheme = value!),
        ),
        _buildDropdownTile(
          'Language',
          'Select app language',
          selectedLanguage,
          languages,
          (value) => setState(() => selectedLanguage = value!),
        ),
        _buildSwitchTile(
          'Dark Mode',
          'Enable dark theme',
          darkMode,
          (value) => setState(() => darkMode = value),
        ),
      ],
    );
  }

  Widget _buildSecuritySettings() {
    return _buildSettingsSection(
      'Security',
      Icons.security_outlined,
      const Color(0xFFEF4444),
      [
        _buildSwitchTile(
          'Biometric Authentication',
          'Use fingerprint or face unlock',
          biometricAuth,
          (value) => setState(() => biometricAuth = value),
        ),
        _buildSwitchTile(
          'Two-Factor Authentication',
          'Add extra security layer',
          twoFactorAuth,
          (value) => setState(() => twoFactorAuth = value),
        ),
        _buildActionTile(
          'Login History',
          'View recent login activity',
          Icons.history,
          () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (context) => const LoginHistoryModal(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildDataSettings() {
    return _buildSettingsSection(
      'Data & Storage',
      Icons.storage_outlined,
      const Color(0xFF0EA5E9),
      [
        _buildSwitchTile(
          'Auto Backup',
          'Automatically backup data',
          autoBackup,
          (value) => setState(() => autoBackup = value),
        ),
        _buildActionTile(
          'Export Data',
          'Download your data',
          Icons.download,
          () {
            _showExportDataDialog();
          },
        ),
        _buildActionTile(
          'Clear Cache',
          'Free up storage space',
          Icons.cleaning_services,
          () {
            _showClearCacheDialog();
          },
        ),
        _buildActionTile(
          'Storage Usage',
          'View storage details',
          Icons.pie_chart,
          () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (context) => const StorageUsageModal(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSystemSettings() {
    return _buildSettingsSection(
      'System',
      Icons.settings_outlined,
      const Color(0xFF6B7280),
      [
        _buildDropdownTile(
          'Time Zone',
          'Select your time zone',
          selectedTimeZone,
          timeZones,
          (value) => setState(() => selectedTimeZone = value!),
        ),
        _buildActionTile(
          'App Version',
          'v1.0.0 (Build 100)',
          Icons.info_outline,
          () {
            _showVersionDialog();
          },
        ),
        _buildActionTile(
          'Check for Updates',
          'Update to latest version',
          Icons.system_update,
          () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('You are using the latest version'),
                backgroundColor: Color(0xFF10B981),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSupportSection() {
    return _buildSettingsSection(
      'Support',
      Icons.help_outline,
      const Color(0xFFF59E0B),
      [
        _buildActionTile(
          'Help Center',
          'Get help and support',
          Icons.help_center,
          () {
            _showHelpCenterDialog();
          },
        ),
        _buildActionTile(
          'Contact Support',
          'Reach out to our team',
          Icons.support_agent,
          () {
            _showContactSupportDialog();
          },
        ),
        _buildActionTile(
          'Privacy Policy',
          'Read our privacy policy',
          Icons.privacy_tip,
          () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Privacy policy - Coming soon')),
            );
          },
        ),
        _buildActionTile(
          'Terms of Service',
          'View terms and conditions',
          Icons.description,
          () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Terms of service - Coming soon')),
            );
          },
        ),
        _buildActionTile(
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

  Widget _buildSettingsSection(
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

  Widget _buildSwitchTile(
    String title,
    String subtitle,
    bool value,
    Function(bool) onChanged, {
    bool enabled = true,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: enabled
                        ? const Color(0xFF111827)
                        : const Color(0xFF9CA3AF),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 14,
                    color: enabled
                        ? const Color(0xFF6B7280)
                        : const Color(0xFF9CA3AF),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: enabled ? value : false,
            onChanged: enabled ? onChanged : null,
            activeThumbColor: const Color(0xFF10B981),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownTile(
    String title,
    String subtitle,
    String value,
    List<String> options,
    Function(String?) onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827),
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButton<String>(
              value: value,
              onChanged: onChanged,
              underline: const SizedBox(),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF111827),
              ),
              items: options.map((String option) {
                return DropdownMenuItem<String>(
                  value: option,
                  child: Text(option),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap, {
    bool isDestructive = false,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
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
            Icon(
              icon,
              color: isDestructive
                  ? const Color(0xFFEF4444)
                  : const Color(0xFF6B7280),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  void _showClearCacheDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Cache'),
        content: const Text(
          'This will clear all cached data and free up storage space. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Cache cleared successfully'),
                  backgroundColor: Color(0xFF10B981),
                ),
              );
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _showVersionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('App Version'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('HOMINODE Property Management'),
            SizedBox(height: 8),
            Text('Version: 1.0.0'),
            Text('Build: 100'),
            Text('Release Date: December 2025'),
            SizedBox(height: 16),
            Text('© 2025 HOMINODE Technologies'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
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

  void _showExportDataDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export Data'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Select data to export:'),
            const SizedBox(height: 16),
            CheckboxListTile(
              title: const Text('User Profile'),
              value: true,
              onChanged: (value) {},
              dense: true,
            ),
            CheckboxListTile(
              title: const Text('Settings & Preferences'),
              value: true,
              onChanged: (value) {},
              dense: true,
            ),
            CheckboxListTile(
              title: const Text('Activity Logs'),
              value: false,
              onChanged: (value) {},
              dense: true,
            ),
            const SizedBox(height: 8),
            const Text(
              'Data will be exported as JSON format and sent to your email.',
              style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Data export initiated. You will receive an email shortly.',
                  ),
                  backgroundColor: Color(0xFF10B981),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0E4778),
            ),
            child: const Text('Export', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showHelpCenterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Help Center'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.book, color: Color(0xFF0E4778)),
              title: const Text('User Guide'),
              subtitle: const Text('Complete app documentation'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Opening user guide...')),
                );
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.video_library,
                color: Color(0xFF10B981),
              ),
              title: const Text('Video Tutorials'),
              subtitle: const Text('Step-by-step video guides'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Opening video tutorials...')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.quiz, color: Color(0xFFF59E0B)),
              title: const Text('FAQ'),
              subtitle: const Text('Frequently asked questions'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Opening FAQ section...')),
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showContactSupportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Contact Support'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.email, color: Color(0xFF0E4778)),
              title: const Text('Email Support'),
              subtitle: const Text('support@lyvo.com'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Opening email client...')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.phone, color: Color(0xFF10B981)),
              title: const Text('Phone Support'),
              subtitle: const Text('+91 1800-123-4567'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Calling support...')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.chat, color: Color(0xFFF59E0B)),
              title: const Text('Live Chat'),
              subtitle: const Text('Available 24/7'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Starting live chat...')),
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
