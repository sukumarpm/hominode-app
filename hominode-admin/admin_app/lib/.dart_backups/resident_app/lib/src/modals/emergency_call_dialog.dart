import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Emergency Call Confirmation Dialog
/// Pixel-perfect modal that appears when tapping emergency contacts
class EmergencyCallDialog extends StatelessWidget {
  final String title;
  final String phoneNumber;
  final String description;
  final IconData icon;
  final Color iconColor;

  const EmergencyCallDialog({
    super.key,
    required this.title,
    required this.phoneNumber,
    required this.description,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with close button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    'Confirm Emergency Call',
                    style: TextStyle(
                      color: Color(0xFF111111),
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(
                    Icons.close,
                    color: Color(0xFF888888),
                    size: 22,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            // Three-layer icon container
            _buildIconLayers(),
            
            const SizedBox(height: 20),
            
            // Emergency title
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF111111),
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            
            const SizedBox(height: 6),
            
            // Phone number
            Text(
              'Calling: $phoneNumber',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF111111),
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
            
            const SizedBox(height: 8),
            
            // Description
            Text(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFA3A3A3),
                fontSize: 13,
                fontWeight: FontWeight.w400,
                height: 1.3,
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Call Now button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _makePhoneCall(phoneNumber);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.phone, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Call Now',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 10),
            
            // Cancel button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF111111),
                  side: const BorderSide(
                    color: Color(0xFFE5E5E5),
                    width: 1.5,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Three-layer nested icon container (compact)
  Widget _buildIconLayers() {
    return Container(
      width: 160,
      height: 160,
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6FA),
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF1F2F6),
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(16),
        child: Container(
          decoration: BoxDecoration(
            color: iconColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Icon(
              icon,
              color: Colors.white,
              size: 52,
            ),
          ),
        ),
      ),
    );
  }

  /// Make phone call
  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    
    try {
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri);
      } else {
        debugPrint('Could not launch $phoneNumber');
      }
    } catch (e) {
      debugPrint('Error launching phone dialer: $e');
    }
  }
}

/// Show emergency call confirmation dialog
/// 
/// Usage:
/// ```dart
/// showEmergencyCallDialog(
///   context,
///   title: 'Security Emergency',
///   phoneNumber: '+91 98765 00001',
///   description: 'For security emergencies',
///   icon: Icons.shield_outlined,
///   iconColor: Color(0xFF2563EB),
/// );
/// ```
Future<void> showEmergencyCallDialog(
  BuildContext context, {
  required String title,
  required String phoneNumber,
  required String description,
  required IconData icon,
  required Color iconColor,
}) {
  return showDialog(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black.withOpacity(0.5),
    builder: (context) => EmergencyCallDialog(
      title: title,
      phoneNumber: phoneNumber,
      description: description,
      icon: icon,
      iconColor: iconColor,
    ),
  );
}
