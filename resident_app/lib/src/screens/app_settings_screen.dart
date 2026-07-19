// lib/src/screens/app_settings_screen.dart
// App Settings Screen with Language Switcher

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import '../providers/language_provider.dart';

// ============================================================================
// APP SETTINGS SCREEN
// ============================================================================
class AppSettingsScreen extends StatefulWidget {
  const AppSettingsScreen({Key? key}) : super(key: key);

  @override
  State<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends State<AppSettingsScreen> {
  bool _notificationsEnabled = true;
  bool _twoFactorEnabled = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, _) {
        return Scaffold(
          appBar: AppBar(
            title: Text('settings'.tr()),
            backgroundColor: const Color(0xFF2563EB),
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          body: SingleChildScrollView(
            child: Column(
              children: [
                // Language Settings Section
                _buildSectionHeader(context, 'language'),
                _buildLanguageSection(context),
                
                const Divider(height: 32),
                
                // Notification Settings Section
                _buildSectionHeader(context, 'notifications'),
                _buildNotificationSettings(context),
                
                const Divider(height: 32),
                
                // Security Settings Section
                _buildSectionHeader(context, 'settings_security'),
                _buildSecuritySettings(context),
                
                const Divider(height: 32),
                
                // Privacy Settings Section
                _buildSectionHeader(context, 'settings_privacy'),
                _buildPrivacySettings(context),
                
                const Divider(height: 32),
                
                // About Section
                _buildSectionHeader(context, 'about'),
                _buildAboutSection(context),
                
                const SizedBox(height: 32),
              ],
            ),
          ),
        );
      },
    );
  }

  // ========================================================================
  // LANGUAGE SECTION
  // ========================================================================
  Widget _buildLanguageSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Consumer<LanguageProvider>(
        builder: (context, languageProvider, _) {
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 2.5,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: languageProvider.supportedLanguages.length,
            itemBuilder: (context, index) {
              final language = languageProvider.supportedLanguages[index];
              final isSelected = languageProvider.currentLanguageCode == language;

              return GestureDetector(
                onTap: () async {
                  await languageProvider.setLanguage(language, context);
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF2563EB)
                        : Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF2563EB)
                          : Colors.grey[300]!,
                      width: 2,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _getLanguageFlag(language),
                        style: const TextStyle(fontSize: 32),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        languageProvider.getLanguageName(language),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.white : Colors.black,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _getLanguageFlag(String languageCode) {
    const flagMap = {
      'en': '🇬🇧',
      'ta': '🇮🇳',
      'hi': '🇮🇳',
      'es': '🇪🇸',
      'ar': '🇸🇦',
    };
    return flagMap[languageCode] ?? '🌐';
  }

  // ========================================================================
  // NOTIFICATION SETTINGS
  // ========================================================================
  Widget _buildNotificationSettings(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          _buildSettingsTile(
            icon: Icons.notifications,
            title: 'receive_notifications'.tr(),
            subtitle: 'notifications'.tr(),
            trailing: Switch(
              value: _notificationsEnabled,
              onChanged: (value) {
                setState(() => _notificationsEnabled = value);
              },
              activeColor: const Color(0xFF2563EB),
            ),
          ),
          _buildSettingsTile(
            icon: Icons.email,
            title: 'email_notifications'.tr(),
            subtitle: 'email_notifications'.tr(),
            trailing: Switch(
              value: true,
              onChanged: (value) {},
              activeColor: const Color(0xFF2563EB),
            ),
          ),
          _buildSettingsTile(
            icon: Icons.sms,
            title: 'sms_notifications'.tr(),
            subtitle: 'sms_notifications'.tr(),
            trailing: Switch(
              value: false,
              onChanged: (value) {},
              activeColor: const Color(0xFF2563EB),
            ),
          ),
        ],
      ),
    );
  }

  // ========================================================================
  // SECURITY SETTINGS
  // ========================================================================
  Widget _buildSecuritySettings(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          _buildSettingsTile(
            icon: Icons.lock,
            title: 'change_password'.tr(),
            subtitle: 'change_password'.tr(),
            onTap: () {
              _showChangePasswordDialog(context);
            },
          ),
          _buildSettingsTile(
            icon: Icons.security,
            title: 'two_factor_auth'.tr(),
            subtitle: 'two_factor_auth'.tr(),
            trailing: Switch(
              value: _twoFactorEnabled,
              onChanged: (value) {
                setState(() => _twoFactorEnabled = value);
              },
              activeColor: const Color(0xFF2563EB),
            ),
          ),
          _buildSettingsTile(
            icon: Icons.devices,
            title: 'active_sessions'.tr(),
            subtitle: 'active_sessions'.tr(),
            onTap: () {
              _showActiveSessionsDialog(context);
            },
          ),
        ],
      ),
    );
  }

  // ========================================================================
  // PRIVACY SETTINGS
  // ========================================================================
  Widget _buildPrivacySettings(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          _buildSettingsTile(
            icon: Icons.privacy_tip,
            title: 'privacy_policy'.tr(),
            subtitle: 'privacy_policy'.tr(),
            onTap: () {
              _showPrivacyPolicyDialog(context);
            },
          ),
          _buildSettingsTile(
            icon: Icons.description,
            title: 'terms_conditions'.tr(),
            subtitle: 'terms_conditions'.tr(),
            onTap: () {
              _showTermsDialog(context);
            },
          ),
          _buildSettingsTile(
            icon: Icons.delete_outline,
            title: 'delete_account'.tr(),
            subtitle: 'delete_account'.tr(),
            onTap: () {
              _showDeleteAccountDialog(context);
            },
          ),
        ],
      ),
    );
  }

  // ========================================================================
  // ABOUT SECTION
  // ========================================================================
  Widget _buildAboutSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          _buildSettingsTile(
            icon: Icons.info,
            title: 'about'.tr(),
            subtitle: 'version'.tr(),
          ),
          _buildSettingsTile(
            icon: Icons.help,
            title: 'help_support'.tr(),
            subtitle: 'help_support'.tr(),
            onTap: () {
              _showHelpDialog(context);
            },
          ),
          _buildSettingsTile(
            icon: Icons.feedback,
            title: 'send_feedback'.tr(),
            subtitle: 'send_feedback'.tr(),
            onTap: () {
              _showFeedbackDialog(context);
            },
          ),
        ],
      ),
    );
  }

  // ========================================================================
  // HELPER WIDGETS
  // ========================================================================
  Widget _buildSectionHeader(
    BuildContext context,
    String titleKey,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          titleKey.tr(),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2563EB),
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF2563EB)),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey[600],
        ),
      ),
      trailing: trailing,
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(vertical: 8),
    );
  }

  // ========================================================================
  // DIALOGS
  // ========================================================================
  void _showChangePasswordDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('change_password'.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: InputDecoration(
                labelText: 'password'.tr(),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: InputDecoration(
                labelText: 'password'.tr(),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: InputDecoration(
                labelText: 'password'.tr(),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
            ),
            child: Text('update'.tr()),
          ),
        ],
      ),
    );
  }

  void _showActiveSessionsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('active_sessions'.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text('current_device'.tr()),
              subtitle: const Text('Android Phone'),
              trailing: Text('active_sessions'.tr()),
            ),
            ListTile(
              title: const Text('iPad'),
              subtitle: Text('last_active'.tr()),
              trailing: TextButton(
                onPressed: () {},
                child: Text('sign_out'.tr()),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('close'.tr()),
          ),
        ],
      ),
    );
  }

  void _showPrivacyPolicyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('privacy_policy'.tr()),
        content: SingleChildScrollView(
          child: Text('privacy_policy'.tr()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('close'.tr()),
          ),
        ],
      ),
    );
  }

  void _showTermsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('terms_conditions'.tr()),
        content: SingleChildScrollView(
          child: Text('terms_conditions'.tr()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('close'.tr()),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('delete_account'.tr()),
        content: Text('delete_account'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: Text('delete'.tr()),
          ),
        ],
      ),
    );
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('help_support'.tr()),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'faq'.tr(),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text('help_support'.tr()),
              const SizedBox(height: 16),
              Text('contact_support'.tr()),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('close'.tr()),
          ),
        ],
      ),
    );
  }

  void _showFeedbackDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('send_feedback'.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: InputDecoration(
                labelText: 'feedback_subject'.tr(),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: InputDecoration(
                labelText: 'feedback_message'.tr(),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              maxLines: 4,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
            ),
            child: Text('send'.tr()),
          ),
        ],
      ),
    );
  }
}
