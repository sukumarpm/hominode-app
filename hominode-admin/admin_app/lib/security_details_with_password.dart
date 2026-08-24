import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/security_service.dart';

class SecurityDetailsWithPassword extends StatefulWidget {
  final String securityId;

  const SecurityDetailsWithPassword({
    super.key,
    required this.securityId,
  });

  @override
  State<SecurityDetailsWithPassword> createState() =>
      _SecurityDetailsWithPasswordState();
}

class _SecurityDetailsWithPasswordState
    extends State<SecurityDetailsWithPassword> {
  final SecurityService _securityService = SecurityService();
  bool _showPassword = false;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _securityService.getSecurityPersonnelById(widget.securityId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFFF9FAFB),
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError || snapshot.data == null) {
          return Scaffold(
            backgroundColor: const Color(0xFFF9FAFB),
            appBar: AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Color(0xFF111827)),
                onPressed: () => Navigator.of(context).pop(),
              ),
              title: const Text(
                'Security Details',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF111827),
                ),
              ),
            ),
            body: Center(
              child: Text('Error: ${snapshot.error}'),
            ),
          );
        }

        final security = snapshot.data!;

        return Scaffold(
          backgroundColor: const Color(0xFFF9FAFB),
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Color(0xFF111827)),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: const Text(
              'Security Details',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF111827),
              ),
            ),
          ),
          body: SingleChildScrollView(
            child: Column(
              children: [
                // Header with photo and basic info
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // Security Photo
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: const Color(0xFFE5E7EB),
                        child: const Icon(
                          Icons.security,
                          size: 50,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        security['name'] ?? 'N/A',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDEF7EC),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Security Personnel',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF047857),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Contact Information
                Container(
                  color: Colors.white,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Contact Information',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildInfoRow(
                        'Email',
                        security['email'] ?? 'N/A',
                        Icons.email,
                      ),
                      _buildInfoRow(
                        'Phone',
                        security['phone'] ?? 'N/A',
                        Icons.phone,
                      ),
                    ],
                  ),
                ),

                // Login Credentials Section
                Container(
                  color: Colors.white,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Login Credentials',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF111827),
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              setState(() => _showPassword = !_showPassword);
                            },
                            child: Icon(
                              _showPassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: const Color(0xFF3B82F6),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Email Display
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Email (Username)',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    security['email'] ?? 'N/A',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1F2937),
                                    ),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    Clipboard.setData(ClipboardData(
                                      text: security['email'] ?? '',
                                    ));
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(
                                      const SnackBar(
                                        content:
                                            Text('Email copied to clipboard'),
                                        backgroundColor: Color(0xFF3B82F6),
                                      ),
                                    );
                                  },
                                  child: const Icon(
                                    Icons.content_copy,
                                    size: 16,
                                    color: Color(0xFF3B82F6),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Password Display
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _showPassword
                              ? const Color(0xFFFEF3C7)
                              : const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _showPassword
                                ? const Color(0xFFFCD34D)
                                : const Color(0xFFE5E7EB),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Password',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    _showPassword
                                        ? (security['password'] ?? 'N/A')
                                        : '•' *
                                            ((security['password'] ?? '')
                                                .length),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1F2937),
                                      letterSpacing: 2,
                                    ),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    Clipboard.setData(ClipboardData(
                                      text: security['password'] ?? '',
                                    ));
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                            'Password copied to clipboard'),
                                        backgroundColor: Color(0xFF3B82F6),
                                      ),
                                    );
                                  },
                                  child: const Icon(
                                    Icons.content_copy,
                                    size: 16,
                                    color: Color(0xFF3B82F6),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Warning Box
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFFFCA5A5),
                          ),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.warning,
                              size: 16,
                              color: Color(0xFFDC2626),
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Keep password secure. Share only with authorized personnel.',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFFDC2626),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Assignment Details
                if (security['buildingId'] != null)
                  Container(
                    color: Colors.white,
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Assignment Details',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildInfoRow(
                          'Building',
                          security['buildingId'] ?? 'N/A',
                          Icons.apartment,
                        ),
                        if (security['assignedGates'] != null)
                          _buildInfoRow(
                            'Assigned Gates',
                            (security['assignedGates'] as List?)
                                    ?.join(', ') ??
                                'N/A',
                            Icons.location_on,
                          ),
                      ],
                    ),
                  ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF6B7280)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827),
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
