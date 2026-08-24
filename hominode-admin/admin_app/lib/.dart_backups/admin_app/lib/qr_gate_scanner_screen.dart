import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'services/visitor_service.dart';

/// QR Gate Scanner Screen - Real Firestore Integration
/// 
/// Features:
/// - Real camera scanning with mobile_scanner
/// - Fetches visitor data from Firestore
/// - Sets actualArrival timestamp on check-in
/// - Sets departure timestamp on check-out
/// - Shows duration in history

class QrGateScannerScreen extends StatefulWidget {
  const QrGateScannerScreen({super.key});

  @override
  State<QrGateScannerScreen> createState() => _QrGateScannerScreenState();
}

class _QrGateScannerScreenState extends State<QrGateScannerScreen>
    with TickerProviderStateMixin {
  
  // Camera and scanning state
  MobileScannerController? _cameraController;
  bool _isCameraInitialized = false;
  bool _hasPermission = false;
  bool _flashOn = false;
  bool _isProcessing = false;
  
  // Firestore service
  final VisitorService _visitorService = VisitorService();
  
  // Animation controllers
  late AnimationController _scanLineController;
  late AnimationController _fadeController;
  late Animation<double> _scanLineAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    
    // Initialize scan line animation
    _scanLineController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    
    _scanLineAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scanLineController,
      curve: Curves.easeInOut,
    ));
    
    // Initialize fade animation
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));
    
    // Start animations
    _scanLineController.repeat();
    _fadeController.forward();
    
    // Initialize camera
    _initializeCamera();
  }

  @override
  void dispose() {
    _scanLineController.dispose();
    _fadeController.dispose();
    _cameraController?.dispose();
    super.dispose();
  }

  // Initialize camera and permissions
  Future<void> _initializeCamera() async {
    try {
      // Request camera permission
      final permission = await Permission.camera.request();
      
      if (permission.isGranted) {
        setState(() => _hasPermission = true);
        
        // Initialize camera controller
        _cameraController = MobileScannerController(
          detectionSpeed: DetectionSpeed.noDuplicates,
          facing: CameraFacing.back,
          torchEnabled: _flashOn,
        );
        
        setState(() => _isCameraInitialized = true);
      } else {
        setState(() => _hasPermission = false);
        _showPermissionDialog();
      }
    } catch (e) {
      print('Error initializing camera: $e');
      _showCameraErrorDialog();
    }
  }

  // Handle QR code detection
  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing) return;
    
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty) {
      final String? qrCode = barcodes.first.rawValue;
      if (qrCode != null && qrCode.isNotEmpty) {
        _onQRScanned(qrCode);
      }
    }
  }

  // Toggle flash
  Future<void> _toggleFlash() async {
    if (_cameraController != null) {
      setState(() => _flashOn = !_flashOn);
      await _cameraController!.toggleTorch();
      HapticFeedback.lightImpact();
    }
  }

  // Camera preview with scanning frame overlay
  Widget _buildCameraPreview() {
    if (!_hasPermission) {
      return _buildPermissionDeniedView();
    }
    
    if (!_isCameraInitialized || _cameraController == null) {
      return _buildLoadingView();
    }
    
    return Stack(
      children: [
        // Camera preview
        MobileScanner(
          controller: _cameraController!,
          onDetect: _onDetect,
        ),
        
        // Scanning frame overlay
        Center(
          child: _buildScanningFrame(),
        ),
      ],
    );
  }

  // Permission denied view
  Widget _buildPermissionDeniedView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.camera_alt_outlined,
              size: 64,
              color: Colors.white.withOpacity(0.6),
            ),
            const SizedBox(height: 20),
            Text(
              'Camera Permission Required',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.white.withOpacity(0.9),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Please grant camera permission to scan QR codes',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _initializeCamera,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Grant Permission',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Loading view
  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            color: Color(0xFF2563EB),
            strokeWidth: 3,
          ),
          const SizedBox(height: 20),
          Text(
            'Initializing Camera...',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.white.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  // Permission dialog
  void _showPermissionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.camera_alt,
                  color: Color(0xFF2563EB),
                  size: 36,
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Title
              const Text(
                'Camera Permission Required',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 12),
              
              // Message
              const Text(
                'This app needs camera access to scan QR codes. Please grant permission in your device settings.',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF6B7280),
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 24),
              
              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).pop(); // Go back to previous screen
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: Color(0xFFE5E7EB)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.of(context).pop();
                        await openAppSettings();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Settings',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Camera error dialog
  void _showCameraErrorDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Error Icon
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.camera_alt_outlined,
                  color: Color(0xFFEF4444),
                  size: 36,
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Title
              const Text(
                'Camera Error',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFEF4444),
                ),
              ),
              
              const SizedBox(height: 12),
              
              // Message
              const Text(
                'Unable to initialize camera. Please check if camera is available and try again.',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF6B7280),
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 24),
              
              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).pop(); // Go back to previous screen
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: Color(0xFFE5E7EB)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _initializeCamera();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Retry',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  Future<void> _onQRScanned(String qrCode) async {
    if (_isProcessing) return;
    
    setState(() => _isProcessing = true);
    HapticFeedback.mediumImpact();
    
    print('QR Scanner: Scanned code - $qrCode');
    
    try {
      // Parse QR code - handle both JSON and plain ID formats
      String visitorId = qrCode.trim();
      
      // Check if QR code is JSON format
      if (visitorId.startsWith('{')) {
        try {
          final jsonData = jsonDecode(visitorId);
          visitorId = jsonData['visitorId'] ?? visitorId;
          print('QR Scanner: Extracted visitor ID from JSON - $visitorId');
        } catch (e) {
          print('QR Scanner: Failed to parse JSON, using raw code - $e');
        }
      }
      
      print('QR Scanner: Using visitor ID - $visitorId');
      
      // Fetch visitor from Firestore using the extracted document ID
      final visitor = await _visitorService.getVisitorById(visitorId);
      
      if (visitor == null) {
        _showErrorDialog(
          'Invalid QR Code',
          'Visitor not found in the system. Please check the QR code and try again.',
          Icons.error_outline,
          const Color(0xFFEF4444),
        );
        setState(() => _isProcessing = false);
        return;
      }
      
      // Check if visitor is approved
      if (!visitor.isApproved) {
        _showErrorDialog(
          'Visitor Not Approved',
          'This visitor request is still pending approval. Please approve the request first.',
          Icons.pending_actions,
          const Color(0xFFF59E0B),
        );
        setState(() => _isProcessing = false);
        return;
      }
      
      // Determine if this is check-in or check-out
      final bool isCheckIn = visitor.actualArrival == null;
      
      if (isCheckIn) {
        // Check-in: Set actualArrival timestamp
        await _visitorService.checkInVisitor(visitorId);
        print('QR Scanner: Visitor checked in - $visitorId');
        
        // Fetch updated visitor data
        final updatedVisitor = await _visitorService.getVisitorById(visitorId);
        if (updatedVisitor != null) {
          _showSuccessDialog(updatedVisitor, true);
        }
      } else {
        // Check-out: Set departure timestamp
        await _visitorService.checkOutVisitor(visitorId);
        print('QR Scanner: Visitor checked out - $visitorId');
        
        // Fetch updated visitor data
        final updatedVisitor = await _visitorService.getVisitorById(visitorId);
        if (updatedVisitor != null) {
          _showSuccessDialog(updatedVisitor, false);
        }
      }
      
    } catch (e) {
      print('QR Scanner ERROR: $e');
      _showErrorDialog(
        'Error',
        'Failed to process visitor: $e',
        Icons.error_outline,
        const Color(0xFFEF4444),
      );
    }
    
    if (mounted) {
      setState(() => _isProcessing = false);
    }
  }

  // Success dialog with Flow UI design - Enhanced with flat details
  void _showSuccessDialog(VisitorModel visitor, bool isEntry) {
    final color = isEntry ? const Color(0xFF16A34A) : const Color(0xFFF59E0B);
    final title = isEntry ? 'Entry Granted ✓' : 'Exit Recorded ✓';
    final icon = isEntry ? Icons.login_rounded : Icons.logout_rounded;
    final timestamp = isEntry ? visitor.actualArrival : visitor.departure;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Status Icon with animation effect
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Icon(icon, color: color, size: 40),
              ),
              
              const SizedBox(height: 20),
              
              // Title
              Text(
                title,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: color,
                  height: 1.2,
                ),
              ),
              
              const SizedBox(height: 8),
              
              // Subtitle
              Text(
                isEntry ? 'Visitor has been checked in' : 'Visitor has been checked out',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF6B7280),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Visitor Information Card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Column(
                  children: [
                    // Visitor Name (Prominent)
                    _buildInfoRow(
                      Icons.person_rounded, 
                      'Visitor Name', 
                      visitor.visitorName.isNotEmpty ? visitor.visitorName : 'N/A',
                      isHeader: true,
                    ),
                    
                    const SizedBox(height: 16),
                    const Divider(height: 1, color: Color(0xFFE5E7EB)),
                    const SizedBox(height: 16),
                    
                    // Flat Details Section
                    _buildSectionHeader('Visiting Details'),
                    const SizedBox(height: 12),
                    
                    _buildInfoRow(
                      Icons.home_rounded, 
                      'Flat Number', 
                      visitor.flatLabel.isNotEmpty ? visitor.flatLabel : 'N/A',
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRow(
                      Icons.person_outline_rounded, 
                      'Resident Name', 
                      visitor.residentName.isNotEmpty ? visitor.residentName : 'N/A',
                    ),
                    
                    const SizedBox(height: 16),
                    const Divider(height: 1, color: Color(0xFFE5E7EB)),
                    const SizedBox(height: 16),
                    
                    // Contact & Purpose
                    _buildInfoRow(
                      Icons.phone_rounded, 
                      'Phone', 
                      visitor.phone.isNotEmpty ? visitor.phone : 'N/A',
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRow(
                      Icons.description_rounded, 
                      'Purpose', 
                      visitor.purpose.isNotEmpty ? visitor.purpose : 'N/A',
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Time Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color.withOpacity(0.15), color.withOpacity(0.05)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.access_time_rounded, size: 20, color: color),
                    const SizedBox(width: 10),
                    Text(
                      '${isEntry ? 'Entry' : 'Exit'} Time: ${timestamp != null ? _formatTime(timestamp) : _formatTime(DateTime.now())}',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Action Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop(); // Close dialog
                    Navigator.of(context).pop(); // Return to previous screen
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                    shadowColor: color.withOpacity(0.3),
                  ),
                  child: const Text(
                    'Done',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Error dialog with Flow UI design
  void _showErrorDialog(String title, String message, IconData icon, Color color) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Error Icon
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 36),
              ),
              
              const SizedBox(height: 20),
              
              // Title
              Text(
                title,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: color,
                  height: 1.2,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 12),
              
              // Message
              Text(
                message,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF6B7280),
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 24),
              
              // Action Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'OK',
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
    );
  }

  // Section header helper
  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 16,
          decoration: BoxDecoration(
            color: const Color(0xFF2563EB),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF374151),
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  // Info row helper for dialogs - Enhanced version
  Widget _buildInfoRow(IconData icon, String label, String value, {bool isHeader = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: isHeader ? 40 : 36,
          height: isHeader ? 40 : 36,
          decoration: BoxDecoration(
            color: isHeader ? const Color(0xFF2563EB).withOpacity(0.1) : const Color(0xFFE5E7EB),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon, 
            size: isHeader ? 22 : 18, 
            color: isHeader ? const Color(0xFF2563EB) : const Color(0xFF6B7280),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: isHeader ? 12 : 11,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF6B7280),
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: TextStyle(
                  fontSize: isHeader ? 17 : 15,
                  fontWeight: isHeader ? FontWeight.w700 : FontWeight.w600,
                  color: const Color(0xFF111827),
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Manual entry dialog - Modern Design
  void _showManualEntryDialog() {
    final controller = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.keyboard_rounded,
                  color: Color(0xFF2563EB),
                  size: 32,
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Title
              const Text(
                'Manual Entry',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
              ),
              
              const SizedBox(height: 8),
              
              // Subtitle
              const Text(
                'Enter visitor ID manually',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF6B7280),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Input Field
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  labelText: 'Visitor ID',
                  hintText: 'Enter document ID',
                  prefixIcon: const Icon(Icons.qr_code_rounded, color: Color(0xFF6B7280)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2),
                  ),
                  contentPadding: const EdgeInsets.all(18),
                  filled: true,
                  fillColor: const Color(0xFFF9FAFB),
                ),
                autofocus: true,
              ),
              
              const SizedBox(height: 24),
              
              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFE5E7EB), width: 1.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () {
                          final qrCode = controller.text.trim();
                          if (qrCode.isNotEmpty) {
                            Navigator.pop(context);
                            _onQRScanned(qrCode);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Process',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Main Content
          FadeTransition(
            opacity: _fadeAnimation,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // Custom Header for Scanner - Clean Design
                SliverAppBar(
                  expandedHeight: 100,
                  floating: true,
                  pinned: false,
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  automaticallyImplyLeading: false,
                  flexibleSpace: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.8),
                          Colors.black.withOpacity(0.4),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        child: Row(
                          children: [
                            // Back Button
                            GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.3),
                                    width: 1.5,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.arrow_back_ios_new_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                            
                            const SizedBox(width: 16),
                            
                            // Title
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'QR Gate Scanner',
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Scan visitor QR code',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w400,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            // Flash Toggle
                            GestureDetector(
                              onTap: _toggleFlash,
                              child: Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: _flashOn 
                                      ? const Color(0xFF2563EB).withOpacity(0.9)
                                      : Colors.white.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: _flashOn 
                                        ? const Color(0xFF2563EB)
                                        : Colors.white.withOpacity(0.3),
                                    width: 1.5,
                                  ),
                                  boxShadow: _flashOn ? [
                                    BoxShadow(
                                      color: const Color(0xFF2563EB).withOpacity(0.4),
                                      blurRadius: 12,
                                      spreadRadius: 2,
                                    ),
                                  ] : null,
                                ),
                                child: Icon(
                                  _flashOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                                  color: Colors.white,
                                  size: 22,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                
                // Scanner Content
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: MediaQuery.of(context).size.height - 200,
                    child: Column(
                      children: [
                        // Camera Preview Area
                        Expanded(
                          child: Container(
                            width: double.infinity,
                            decoration: const BoxDecoration(
                              color: Colors.black,
                            ),
                            child: _buildCameraPreview(),
                          ),
                        ),
                        
                        // Bottom Controls - Clean Design
                        Container(
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                Colors.black.withOpacity(0.8),
                                Colors.black.withOpacity(0.4),
                                Colors.transparent,
                              ],
                            ),
                          ),
                          child: Column(
                            children: [
                              // Instruction text
                              Text(
                                'Align QR code within the frame',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white.withOpacity(0.8),
                                ),
                              ),
                              const SizedBox(height: 16),
                              // Manual entry button
                              _buildControlButton(
                                Icons.keyboard_rounded,
                                'Manual Entry',
                                _showManualEntryDialog,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Processing Overlay
          if (_isProcessing) _buildProcessingOverlay(),
        ],
      ),
    );
  }

  // Scanning Frame with Animation (updated for real camera) - Clean & Modern Design
  Widget _buildScanningFrame() {
    return Container(
      width: 300,
      height: 300,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Stack(
        children: [
          // Corner Indicators - Modern style
          ...List.generate(4, (index) => _buildCornerIndicator(index)),
          
          // Animated Scan Line (only show when camera is active and not processing)
          if (_isCameraInitialized && !_isProcessing)
            AnimatedBuilder(
              animation: _scanLineAnimation,
              builder: (context, child) {
                return Positioned(
                  top: 30 + (240 * _scanLineAnimation.value),
                  left: 30,
                  right: 30,
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Colors.transparent,
                          Color(0xFF2563EB),
                          Color(0xFF3B82F6),
                          Color(0xFF2563EB),
                          Colors.transparent,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(2),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF2563EB).withOpacity(0.5),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          
          // Center content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (!_isCameraInitialized) ...[
                  // Camera initializing state
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.qr_code_scanner_rounded,
                          color: Colors.white.withOpacity(0.9),
                          size: 56,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Position QR Code',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.95),
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            height: 1.3,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Align within the frame',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB).withOpacity(0.3),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: const Color(0xFF2563EB).withOpacity(0.5),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white.withOpacity(0.9),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Initializing camera...',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (_isProcessing) ...[
                  // Processing state
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        const SizedBox(
                          width: 48,
                          height: 48,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Color(0xFF2563EB),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Processing...',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.95),
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Corner Indicators for Scanning Frame - Modern Design
  Widget _buildCornerIndicator(int index) {
    final positions = [
      const Alignment(-1, -1), // Top-left
      const Alignment(1, -1),  // Top-right
      const Alignment(-1, 1),  // Bottom-left
      const Alignment(1, 1),   // Bottom-right
    ];
    
    return Align(
      alignment: positions[index],
      child: Container(
        width: 32,
        height: 32,
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border(
            top: index < 2 
                ? const BorderSide(color: Color(0xFF2563EB), width: 5)
                : BorderSide.none,
            bottom: index >= 2 
                ? const BorderSide(color: Color(0xFF2563EB), width: 5)
                : BorderSide.none,
            left: index % 2 == 0 
                ? const BorderSide(color: Color(0xFF2563EB), width: 5)
                : BorderSide.none,
            right: index % 2 == 1 
                ? const BorderSide(color: Color(0xFF2563EB), width: 5)
                : BorderSide.none,
          ),
          borderRadius: BorderRadius.circular(4),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2563EB).withOpacity(0.4),
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ],
        ),
      ),
    );
  }

  // Control Button - Modern Design
  Widget _buildControlButton(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF2563EB), Color(0xFF3B82F6)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2563EB).withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(0, 6),
              spreadRadius: 1,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Processing Overlay
  Widget _buildProcessingOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.7),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                color: Color(0xFF2563EB),
                strokeWidth: 3,
              ),
              SizedBox(height: 20),
              Text(
                'Processing QR Code...',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF111827),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Time formatting helper
  String _formatTime(DateTime time) {
    final hour = time.hour > 12 ? time.hour - 12 : (time.hour == 0 ? 12 : time.hour);
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }
}