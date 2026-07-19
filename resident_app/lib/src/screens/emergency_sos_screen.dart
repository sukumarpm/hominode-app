import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_localization/easy_localization.dart';
import '../modals/emergency_call_dialog.dart';

/// Emergency SOS Screen - Pixel-perfect implementation
/// Displays emergency contact numbers with call functionality
class EmergencySosScreen extends StatefulWidget {
  const EmergencySosScreen({Key? key}) : super(key: key);

  @override
  State<EmergencySosScreen> createState() => _EmergencySosScreenState();
}

class _EmergencySosScreenState extends State<EmergencySosScreen> {
  String? _userEmergencyContact;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEmergencyContact();
  }

  Future<void> _loadEmergencyContact() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final contact = prefs.getString('emergency_contact');
      setState(() {
        _userEmergencyContact = contact;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading emergency contact: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F7F7),
        body: SafeArea(
          child: Column(
            children: [
              // Custom gradient header
              _buildHeader(context),
              // Scrollable content
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Warning box
                      _buildWarningBox(),
                      const SizedBox(height: 16),
                      // User's personal emergency contact (if set)
                      if (_userEmergencyContact != null && _userEmergencyContact!.isNotEmpty) ...[
                        _EmergencyCard(
                          contact: EmergencyContact(
                            title: 'My Emergency Contact',
                            subtitle: 'Personal emergency contact',
                            contact: _userEmergencyContact!,
                            iconColor: const Color(0xFFE53935),
                            icon: Icons.person_outline,
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                      // Emergency contacts list
                      ..._emergencyContacts.map((contact) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _EmergencyCard(contact: contact),
                          )),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFF7A68), Color(0xFFFF3D35)],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 16, 16, 20),
        child: Row(
          children: [
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
              padding: const EdgeInsets.all(8),
            ),
            const SizedBox(width: 4),
            const Text(
              'Emergency SOS',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWarningBox() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFECEC),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline,
            color: Color(0xFFD32F2F),
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Emergency Use Only',
                  style: TextStyle(
                    color: Color(0xFFD32F2F),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'These numbers are for genuine emergencies only. Misuse may lead to penalties.',
                  style: TextStyle(
                    color: Color(0xFFD32F2F),
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Emergency contact model
class EmergencyContact {
  final String title;
  final String subtitle;
  final String contact;
  final Color iconColor;
  final IconData icon;

  const EmergencyContact({
    required this.title,
    required this.subtitle,
    required this.contact,
    required this.iconColor,
    required this.icon,
  });
}

/// Sample emergency contacts data
final List<EmergencyContact> _emergencyContacts = [
  const EmergencyContact(
    title: 'Security',
    subtitle: 'For security emergencies',
    contact: '+91 98765 00001',
    iconColor: Color(0xFF2563EB),
    icon: Icons.shield_outlined,
  ),
  const EmergencyContact(
    title: 'Fire',
    subtitle: 'Fire emergency',
    contact: '101',
    iconColor: Color(0xFFE53935),
    icon: Icons.local_fire_department_outlined,
  ),
  const EmergencyContact(
    title: 'Medical',
    subtitle: 'Medical Emergency',
    contact: '102',
    iconColor: Color(0xFF34A853),
    icon: Icons.local_hospital_outlined,
  ),
  const EmergencyContact(
    title: 'Police',
    subtitle: 'Police Emergency',
    contact: '100',
    iconColor: Color(0xFFFF6A00),
    icon: Icons.warning_amber_outlined,
  ),
  const EmergencyContact(
    title: 'Maintenance',
    subtitle: 'Maintenance Emergency',
    contact: '+91 98765 00002',
    iconColor: Color(0xFF9C27B0),
    icon: Icons.build_outlined,
  ),
];

/// Emergency card widget - reusable component
class _EmergencyCard extends StatelessWidget {
  final EmergencyContact contact;

  const _EmergencyCard({
    Key? key,
    required this.contact,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showConfirmationDialog(context),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            // Icon container
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: contact.iconColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                contact.icon,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: 12),
            // Text content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    contact.title,
                    style: const TextStyle(
                      color: Color(0xFF111111),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    contact.subtitle,
                    style: const TextStyle(
                      color: Color(0xFF9E9E9E),
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    contact.contact,
                    style: const TextStyle(
                      color: Color(0xFF9E9E9E),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            // Phone icon button
            GestureDetector(
              onTap: () => _showConfirmationDialog(context),
              child: Container(
                padding: const EdgeInsets.all(6),
                child: const Icon(
                  Icons.phone_outlined,
                  color: Color(0xFFA3A3A3),
                  size: 22,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Show confirmation dialog before calling
  void _showConfirmationDialog(BuildContext context) {
    showEmergencyCallDialog(
      context,
      title: '${contact.title} Emergency',
      phoneNumber: contact.contact,
      description: contact.subtitle,
      icon: contact.icon,
      iconColor: contact.iconColor,
    );
  }
}
