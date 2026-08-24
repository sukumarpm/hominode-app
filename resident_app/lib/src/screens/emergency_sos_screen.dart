import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../modals/emergency_call_dialog.dart';

/// Emergency SOS Screen - Pixel-perfect implementation
/// Displays emergency contact numbers with call functionality
class EmergencySosScreen extends StatefulWidget {
  const EmergencySosScreen({super.key});

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
                  padding: EdgeInsets.all(16.w),
                  child: Column(
                    children: [
                      // Warning box
                      _buildWarningBox(),
                      SizedBox(height: 16.h),
                      // User's personal emergency contact (if set)
                      if (_userEmergencyContact != null &&
                          _userEmergencyContact!.isNotEmpty) ...[
                        _EmergencyCard(
                          contact: EmergencyContact(
                            title: 'My Emergency Contact',
                            subtitle: 'Personal emergency contact',
                            contact: _userEmergencyContact!,
                            iconColor: const Color(0xFFE53935),
                            icon: Icons.person_outline,
                          ),
                        ),
                        SizedBox(height: 10.h),
                      ],
                      // Emergency contacts list
                      ..._emergencyContacts.map(
                        (contact) => Padding(
                          padding: EdgeInsets.only(bottom: 10.h),
                          child: _EmergencyCard(contact: contact),
                        ),
                      ),
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
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFF7A68), Color(0xFFFF3D35)],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24.r),
          bottomRight: Radius.circular(24.r),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(8.w, 16.h, 16.w, 20.h),
        child: Row(
          children: [
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: Icon(Icons.arrow_back_ios, color: Colors.white, size: 20.w),
              padding: EdgeInsets.all(8.w),
            ),
            SizedBox(width: 4.w),
            Text(
              'Emergency SOS',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20.sp,
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
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: const Color(0xFFFFECEC),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, color: Color(0xFFD32F2F), size: 22.w),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Emergency Use Only',
                  style: TextStyle(
                    color: Color(0xFFD32F2F),
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 3.h),
                Text(
                  'These numbers are for genuine emergencies only. Misuse may lead to penalties.',
                  style: TextStyle(
                    color: Color(0xFFD32F2F),
                    fontSize: 13.sp,
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
    iconColor: Color(0xFF0E4778),
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

  const _EmergencyCard({required this.contact});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showConfirmationDialog(context),
      child: Container(
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14.r),
        ),
        child: Row(
          children: [
            // Icon container
            Container(
              width: 56.w,
              height: 56.h,
              decoration: BoxDecoration(
                color: contact.iconColor,
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Icon(contact.icon, color: Colors.white, size: 28.w),
            ),
            SizedBox(width: 12.w),
            // Text content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    contact.title,
                    style: TextStyle(
                      color: Color(0xFF111111),
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    contact.subtitle,
                    style: TextStyle(
                      color: Color(0xFF9E9E9E),
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    contact.contact,
                    style: TextStyle(
                      color: Color(0xFF9E9E9E),
                      fontSize: 14.sp,
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
                padding: EdgeInsets.all(6.w),
                child: Icon(
                  Icons.phone_outlined,
                  color: Color(0xFFA3A3A3),
                  size: 22.w,
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
