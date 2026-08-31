import 'package:flutter/material.dart';

import 'services/auth_service.dart';

/// Access Restricted Screen - Shown when user loses building/flat access
/// Displays error message and logout option
class AccessRestrictedScreen extends StatelessWidget {
  final String? reason;
  final VoidCallback? onLogout;

  const AccessRestrictedScreen({super.key, this.reason, this.onLogout});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Error Icon
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(40),
                  ),
                  child: const Icon(
                    Icons.lock_outline,
                    size: 40,
                    color: Color(0xFFEF4444),
                  ),
                ),
                const SizedBox(height: 24),

                // Title
                const Text(
                  'Access Restricted',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),

                // Reason
                Text(
                  reason ?? 'Your access to the app has been restricted.',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF6B7280),
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // Reason Details
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Why is my access restricted?',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0x00dc2626),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildReasonItem(
                        'Your building has been deleted',
                        reason?.contains('Building') ?? false,
                      ),
                      _buildReasonItem(
                        'Your flat has been deleted',
                        reason?.contains('Flat') ?? false,
                      ),
                      _buildReasonItem(
                        'You have been unassigned from your flat',
                        reason?.contains('unassigned') ?? false,
                      ),
                      _buildReasonItem(
                        'Your user account has been deleted',
                        reason?.contains('deleted') ?? false,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Contact Support
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F9FF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'What should I do?',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF061C4C),
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Please contact your building administrator to restore your access. They can reassign you to a flat or create a new account for you.',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          color: Color(0xFF061C4C),
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Logout Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () async {
                      try {
                        await AuthService().signOut();
                        if (onLogout != null) {
                          onLogout!();
                        }
                      } catch (e) {
                        print('Error logging out: $e');
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEF4444),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Logout',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReasonItem(String text, bool isActive) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            isActive ? Icons.check_circle : Icons.circle_outlined,
            size: 18,
            color: isActive ? const Color(0xFFDC2626) : const Color(0xFFFCA5A5),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: isActive
                    ? const Color(0xFFDC2626)
                    : const Color(0xFFFCA5A5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
