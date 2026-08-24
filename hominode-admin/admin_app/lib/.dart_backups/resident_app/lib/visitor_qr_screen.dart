import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:convert';

/// Visitor QR Pass Screen
/// Displays the QR code for an approved visitor
/// Fetches visitor data from Firestore
class VisitorQRScreen extends StatefulWidget {
  final String visitorId;

  const VisitorQRScreen({
    super.key,
    required this.visitorId,
  });

  @override
  State<VisitorQRScreen> createState() => _VisitorQRScreenState();
}

class _VisitorQRScreenState extends State<VisitorQRScreen> {
  final _firestore = FirebaseFirestore.instance;
  Map<String, dynamic>? _visitorData;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadVisitorData();
  }

  Future<void> _loadVisitorData() async {
    print('🔵 QR Screen: Loading visitor data for ID: ${widget.visitorId}');
    
    try {
      final doc = await _firestore
          .collection('visitors')
          .doc(widget.visitorId)
          .get();

      if (doc.exists && mounted) {
        final data = doc.data()!;
        print('✅ QR Screen: Visitor data loaded: $data');
        
        setState(() {
          _visitorData = data;
          _isLoading = false;
        });
      } else {
        print('❌ QR Screen: Visitor document not found');
        setState(() {
          _error = 'Visitor not found';
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ QR Screen: Error loading visitor: $e');
      setState(() {
        _error = 'Failed to load visitor data';
        _isLoading = false;
      });
    }
  }

  String _generateQRData() {
    if (_visitorData == null) return '';
    
    // Create JSON data for QR code
    final qrData = {
      'visitorId': widget.visitorId,
      'name': _visitorData!['visitorName'] ?? '',
      'phone': _visitorData!['visitorPhone'] ?? '',
      'purpose': _visitorData!['purpose'] ?? '',
      'flatId': _visitorData!['flatId'] ?? '',
      'flatLabel': _visitorData!['flatLabel'] ?? '',
      'expectedArrival': (_visitorData!['expectedArrival'] as Timestamp?)?.toDate().toIso8601String() ?? '',
      'isApproved': _visitorData!['isApproved'] ?? false,
      'approvedAt': (_visitorData!['approvedAt'] as Timestamp?)?.toDate().toIso8601String() ?? '',
      'vehicleNumber': _visitorData!['vehicleNumber'] ?? '',
    };
    
    return jsonEncode(qrData);
  }

  @override
  Widget build(BuildContext context) {
    // Set status bar to black background with white icons
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.black,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
    );

    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          // Status bar spacer
          Container(
            color: Colors.black,
            height: MediaQuery.of(context).padding.top,
          ),
          
          // Main content
          Expanded(
            child: Container(
              color: const Color(0xFFF8F9FA),
              child: Column(
                children: [
                  _buildHeader(context),
            
                  Expanded(
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _error != null
                            ? _buildError()
                            : SingleChildScrollView(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  children: [
                                    const SizedBox(height: 20),
                                    _buildQRCard(),
                                    const SizedBox(height: 24),
                                    _buildVisitorDetails(),
                                    const SizedBox(height: 32),
                                    _buildInstructions(),
                                    const SizedBox(height: 24),
                                    _buildShareButton(context),
                                  ],
                                ),
                              ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2563EB), Color(0xFF1E40AF)],
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
              'Visitor QR Pass',
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

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Color(0xFFDC2626)),
            const SizedBox(height: 16),
            Text(
              _error ?? 'An error occurred',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E293B),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQRCard() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Actual QR Code
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5E7EB), width: 2),
            ),
            child: QrImageView(
              data: _generateQRData(),
              version: QrVersions.auto,
              size: 240,
              backgroundColor: Colors.white,
              errorCorrectionLevel: QrErrorCorrectLevel.H,
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Pass ID
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF1FF),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Pass ID: ${widget.visitorId.substring(0, 12).toUpperCase()}',
              style: const TextStyle(
                color: Color(0xFF2563EB),
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVisitorDetails() {
    if (_visitorData == null) return const SizedBox();
    
    final visitorName = _visitorData!['visitorName'] ?? 'N/A';
    final purpose = _visitorData!['purpose'] ?? 'N/A';
    final expectedArrival = _visitorData!['expectedArrival'] as Timestamp?;
    final timeString = expectedArrival != null
        ? '${expectedArrival.toDate().day}/${expectedArrival.toDate().month}/${expectedArrival.toDate().year} ${expectedArrival.toDate().hour}:${expectedArrival.toDate().minute.toString().padLeft(2, '0')}'
        : 'N/A';
    final flatLabel = _visitorData!['flatLabel'] ?? _visitorData!['flatId'] ?? 'N/A';
    final vehicleNumber = _visitorData!['vehicleNumber'] ?? 'N/A';
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Visitor Details',
            style: TextStyle(
              color: Color(0xFF1E293B),
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          _buildDetailRow(
            icon: Icons.person_outline,
            label: 'Name',
            value: visitorName,
          ),
          const SizedBox(height: 12),
          _buildDetailRow(
            icon: Icons.home_outlined,
            label: 'Visiting',
            value: 'Flat $flatLabel',
          ),
          const SizedBox(height: 12),
          _buildDetailRow(
            icon: Icons.category_outlined,
            label: 'Purpose',
            value: purpose,
          ),
          const SizedBox(height: 12),
          _buildDetailRow(
            icon: Icons.access_time,
            label: 'Expected Time',
            value: timeString,
          ),
          if (vehicleNumber != 'N/A') ...[
            const SizedBox(height: 12),
            _buildDetailRow(
              icon: Icons.directions_car_outlined,
              label: 'Vehicle',
              value: vehicleNumber,
            ),
          ],
          const SizedBox(height: 12),
          _buildDetailRow(
            icon: Icons.check_circle_outline,
            label: 'Status',
            value: 'Approved',
            valueColor: const Color(0xFF10B981),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: const Color(0xFF64748B)),
        const SizedBox(width: 12),
        Text(
          '$label: ',
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: valueColor ?? const Color(0xFF1E293B),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInstructions() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF1FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF2563EB).withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.info_outline, color: Color(0xFF2563EB), size: 20),
              SizedBox(width: 8),
              Text(
                'Instructions',
                style: TextStyle(
                  color: Color(0xFF2563EB),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInstructionItem('Show this QR code at the security gate'),
          _buildInstructionItem('Valid for single entry only'),
          _buildInstructionItem('Pass expires after scheduled time'),
          _buildInstructionItem('Visitor must carry valid ID proof'),
        ],
      ),
    );
  }

  Widget _buildInstructionItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 6),
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Color(0xFF2563EB),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFF1E40AF),
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShareButton(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2563EB), Color(0xFF1E40AF)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _handleSharePass(context),
          borderRadius: BorderRadius.circular(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.share_outlined, color: Colors.white, size: 24),
              SizedBox(width: 12),
              Text(
                'Share Pass',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleSharePass(BuildContext context) {
    final visitorName = _visitorData?['visitorName'] ?? 'Visitor';
    final flatLabel = _visitorData?['flatLabel'] ?? _visitorData?['flatId'] ?? '';
    
    final shareText = '''
Visitor Pass - Approved

Name: $visitorName
Visiting: Flat $flatLabel
Pass ID: ${widget.visitorId.substring(0, 12).toUpperCase()}

Please show this QR code at the security gate.
''';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Share QR Pass',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildShareOption(
              context,
              icon: Icons.message_outlined,
              label: 'Share via SMS',
              onTap: () {
                Navigator.pop(context);
                _showShareSuccess(context, 'SMS');
              },
            ),
            const SizedBox(height: 12),
            _buildShareOption(
              context,
              icon: Icons.email_outlined,
              label: 'Share via Email',
              onTap: () {
                Navigator.pop(context);
                _showShareSuccess(context, 'Email');
              },
            ),
            const SizedBox(height: 12),
            _buildShareOption(
              context,
              icon: Icons.chat_bubble_outline,
              label: 'Share via WhatsApp',
              onTap: () {
                Navigator.pop(context);
                _showShareSuccess(context, 'WhatsApp');
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShareOption(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F9FA),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFEAF1FF),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: const Color(0xFF2563EB), size: 24),
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF1E293B),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showShareSuccess(BuildContext context, String method) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Pass shared via $method'),
        backgroundColor: const Color(0xFF10B981),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
