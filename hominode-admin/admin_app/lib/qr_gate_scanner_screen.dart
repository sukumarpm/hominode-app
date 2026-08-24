import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
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

    _scanLineAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scanLineController, curve: Curves.easeInOut),
    );

    // Initialize fade animation
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

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
        MobileScanner(controller: _cameraController!, onDetect: _onDetect),

        // Scanning frame overlay
        Center(child: _buildScanningFrame()),
      ],
    );
  }

  // Permission denied view
  Widget _buildPermissionDeniedView() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.camera_alt_outlined,
              size: 64.w,
              color: Colors.white.withOpacity(0.6),
            ),
            SizedBox(height: 20.h),
            Text(
              'Camera Permission Required',
              style: TextStyle(
                fontSize: 20.sp,
                fontWeight: FontWeight.w600,
                color: Colors.white.withOpacity(0.9),
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 12.h),
            Text(
              'Please grant camera permission to scan QR codes',
              style: TextStyle(
                fontSize: 16.sp,
                color: Colors.white.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24.h),
            ElevatedButton(
              onPressed: _initializeCamera,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0E4778),
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
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
            color: Color(0xFF0E4778),
            strokeWidth: 3,
          ),
          SizedBox(height: 20.h),
          Text(
            'Initializing Camera...',
            style: TextStyle(
              fontSize: 16.sp,
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: Container(
          padding: EdgeInsets.all(24.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon
              Container(
                width: 72.w,
                height: 72.h,
                decoration: BoxDecoration(
                  color: const Color(0xFF0E4778).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.camera_alt,
                  color: Color(0xFF0E4778),
                  size: 36.w,
                ),
              ),

              SizedBox(height: 20.h),

              // Title
              Text(
                'Camera Permission Required',
                style: TextStyle(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
                textAlign: TextAlign.center,
              ),

              SizedBox(height: 12.h),

              // Message
              Text(
                'This app needs camera access to scan QR codes. Please grant permission in your device settings.',
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF6B7280),
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),

              SizedBox(height: 24.h),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        Navigator.of(
                          context,
                        ).pop(); // Go back to previous screen
                      },
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 12.h),
                        side: const BorderSide(color: Color(0xFFE5E7EB)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.of(context).pop();
                        await openAppSettings();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0E4778),
                        padding: EdgeInsets.symmetric(vertical: 12.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'Settings',
                        style: TextStyle(
                          fontSize: 15.sp,
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: Container(
          padding: EdgeInsets.all(24.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Error Icon
              Container(
                width: 72.w,
                height: 72.h,
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.camera_alt_outlined,
                  color: Color(0xFFEF4444),
                  size: 36.w,
                ),
              ),

              SizedBox(height: 20.h),

              // Title
              Text(
                'Camera Error',
                style: TextStyle(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFEF4444),
                ),
              ),

              SizedBox(height: 12.h),

              // Message
              Text(
                'Unable to initialize camera. Please check if camera is available and try again.',
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF6B7280),
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),

              SizedBox(height: 24.h),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        Navigator.of(
                          context,
                        ).pop(); // Go back to previous screen
                      },
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 12.h),
                        side: const BorderSide(color: Color(0xFFE5E7EB)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _initializeCamera();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0E4778),
                        padding: EdgeInsets.symmetric(vertical: 12.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'Retry',
                        style: TextStyle(
                          fontSize: 15.sp,
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Container(
          constraints: BoxConstraints(maxWidth: 400.w),
          padding: EdgeInsets.all(28.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Status Icon with animation effect
              Container(
                width: 80.w,
                height: 80.h,
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
                child: Icon(icon, color: color, size: 40.w),
              ),

              SizedBox(height: 20.h),

              // Title
              Text(
                title,
                style: TextStyle(
                  fontSize: 24.sp,
                  fontWeight: FontWeight.w700,
                  color: color,
                  height: 1.2,
                ),
              ),

              SizedBox(height: 8.h),

              // Subtitle
              Text(
                isEntry
                    ? 'Visitor has been checked in'
                    : 'Visitor has been checked out',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF6B7280),
                ),
              ),

              SizedBox(height: 24.h),

              // Visitor Information Card
              Container(
                padding: EdgeInsets.all(18.w),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Column(
                  children: [
                    // Visitor Name (Prominent)
                    _buildInfoRow(
                      Icons.person_rounded,
                      'Visitor Name',
                      visitor.visitorName.isNotEmpty
                          ? visitor.visitorName
                          : 'N/A',
                      isHeader: true,
                    ),

                    SizedBox(height: 16.h),
                    const Divider(height: 1, color: Color(0xFFE5E7EB)),
                    SizedBox(height: 16.h),

                    // Flat Details Section
                    _buildSectionHeader('Visiting Details'),
                    SizedBox(height: 12.h),

                    _buildInfoRow(
                      Icons.home_rounded,
                      'Flat Number',
                      visitor.flatLabel.isNotEmpty ? visitor.flatLabel : 'N/A',
                    ),
                    SizedBox(height: 12.h),
                    _buildInfoRow(
                      Icons.person_outline_rounded,
                      'Resident Name',
                      visitor.residentName.isNotEmpty
                          ? visitor.residentName
                          : 'N/A',
                    ),

                    SizedBox(height: 16.h),
                    const Divider(height: 1, color: Color(0xFFE5E7EB)),
                    SizedBox(height: 16.h),

                    // Contact & Purpose
                    _buildInfoRow(
                      Icons.phone_rounded,
                      'Phone',
                      visitor.phone.isNotEmpty ? visitor.phone : 'N/A',
                    ),
                    SizedBox(height: 12.h),
                    _buildInfoRow(
                      Icons.description_rounded,
                      'Purpose',
                      visitor.purpose.isNotEmpty ? visitor.purpose : 'N/A',
                    ),
                  ],
                ),
              ),

              SizedBox(height: 20.h),

              // Time Badge
              Container(
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 14.h),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color.withOpacity(0.15), color.withOpacity(0.05)],
                  ),
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: color.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.access_time_rounded, size: 20.w, color: color),
                    SizedBox(width: 10.w),
                    Text(
                      '${isEntry ? 'Entry' : 'Exit'} Time: ${timestamp != null ? _formatTime(timestamp) : _formatTime(DateTime.now())}',
                      style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 24.h),

              // Action Button
              SizedBox(
                width: double.infinity,
                height: 52.h,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop(); // Close dialog
                    Navigator.of(context).pop(); // Return to previous screen
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                    elevation: 0,
                    shadowColor: color.withOpacity(0.3),
                  ),
                  child: Text(
                    'Done',
                    style: TextStyle(
                      fontSize: 16.sp,
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
  void _showErrorDialog(
    String title,
    String message,
    IconData icon,
    Color color,
  ) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: Container(
          padding: EdgeInsets.all(24.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Error Icon
              Container(
                width: 72.w,
                height: 72.h,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 36.w),
              ),

              SizedBox(height: 20.h),

              // Title
              Text(
                title,
                style: TextStyle(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w700,
                  color: color,
                  height: 1.2,
                ),
                textAlign: TextAlign.center,
              ),

              SizedBox(height: 12.h),

              // Message
              Text(
                message,
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF6B7280),
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),

              SizedBox(height: 24.h),

              // Action Button
              SizedBox(
                width: double.infinity,
                height: 48.h,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'OK',
                    style: TextStyle(
                      fontSize: 16.sp,
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
          width: 3.w,
          height: 16.h,
          decoration: BoxDecoration(
            color: const Color(0xFF0E4778),
            borderRadius: BorderRadius.circular(2.r),
          ),
        ),
        SizedBox(width: 8.w),
        Text(
          title,
          style: TextStyle(
            fontSize: 13.sp,
            fontWeight: FontWeight.w700,
            color: Color(0xFF374151),
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  // Info row helper for dialogs - Enhanced version
  Widget _buildInfoRow(
    IconData icon,
    String label,
    String value, {
    bool isHeader = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: isHeader ? 40 : 36,
          height: isHeader ? 40 : 36,
          decoration: BoxDecoration(
            color: isHeader
                ? const Color(0xFF0E4778).withOpacity(0.1)
                : const Color(0xFFE5E7EB),
            borderRadius: BorderRadius.circular(10.r),
          ),
          child: Icon(
            icon,
            size: isHeader ? 22 : 18,
            color: isHeader ? const Color(0xFF0E4778) : const Color(0xFF6B7280),
          ),
        ),
        SizedBox(width: 12.w),
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
              SizedBox(height: 3.h),
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Container(
          padding: EdgeInsets.all(28.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon
              Container(
                width: 64.w,
                height: 64.h,
                decoration: BoxDecoration(
                  color: const Color(0xFF0E4778).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.keyboard_rounded,
                  color: Color(0xFF0E4778),
                  size: 32.w,
                ),
              ),

              SizedBox(height: 20.h),

              // Title
              Text(
                'Manual Entry',
                style: TextStyle(
                  fontSize: 22.sp,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
              ),

              SizedBox(height: 8.h),

              // Subtitle
              Text(
                'Enter visitor ID manually',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF6B7280),
                ),
              ),

              SizedBox(height: 24.h),

              // Input Field
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  labelText: 'Visitor ID',
                  hintText: 'Enter document ID',
                  prefixIcon: const Icon(
                    Icons.qr_code_rounded,
                    color: Color(0xFF6B7280),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14.r),
                    borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14.r),
                    borderSide: const BorderSide(
                      color: Color(0xFF0E4778),
                      width: 2,
                    ),
                  ),
                  contentPadding: EdgeInsets.all(18.w),
                  filled: true,
                  fillColor: const Color(0xFFF9FAFB),
                ),
                autofocus: true,
              ),

              SizedBox(height: 24.h),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 52.h,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                            color: Color(0xFFE5E7EB),
                            width: 1.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14.r),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: SizedBox(
                      height: 52.h,
                      child: ElevatedButton(
                        onPressed: () {
                          final qrCode = controller.text.trim();
                          if (qrCode.isNotEmpty) {
                            Navigator.pop(context);
                            _onQRScanned(qrCode);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0E4778),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14.r),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          'Process',
                          style: TextStyle(
                            fontSize: 15.sp,
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
                        padding: EdgeInsets.symmetric(
                          horizontal: 20.w,
                          vertical: 16.h,
                        ),
                        child: Row(
                          children: [
                            // Back Button
                            GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: Container(
                                width: 48.w,
                                height: 48.h,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(14.r),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.3),
                                    width: 1.5,
                                  ),
                                ),
                                child: Icon(
                                  Icons.arrow_back_ios_new_rounded,
                                  color: Colors.white,
                                  size: 20.w,
                                ),
                              ),
                            ),

                            SizedBox(width: 16.w),

                            // Title
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'QR Gate Scanner',
                                    style: TextStyle(
                                      fontSize: 22.sp,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                  SizedBox(height: 2.h),
                                  Text(
                                    'Scan visitor QR code',
                                    style: TextStyle(
                                      fontSize: 13.sp,
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
                                width: 48.w,
                                height: 48.h,
                                decoration: BoxDecoration(
                                  color: _flashOn
                                      ? const Color(0xFF0E4778).withOpacity(0.9)
                                      : Colors.white.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(14.r),
                                  border: Border.all(
                                    color: _flashOn
                                        ? const Color(0xFF0E4778)
                                        : Colors.white.withOpacity(0.3),
                                    width: 1.5,
                                  ),
                                  boxShadow: _flashOn
                                      ? [
                                          BoxShadow(
                                            color: const Color(
                                              0xFF0E4778,
                                            ).withOpacity(0.4),
                                            blurRadius: 12,
                                            spreadRadius: 2,
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Icon(
                                  _flashOn
                                      ? Icons.flash_on_rounded
                                      : Icons.flash_off_rounded,
                                  color: Colors.white,
                                  size: 22.w,
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
                          padding: EdgeInsets.all(28.w),
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
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white.withOpacity(0.8),
                                ),
                              ),
                              SizedBox(height: 16.h),
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
      width: 300.w,
      height: 300.h,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(24.r)),
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
                    height: 4.h,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Colors.transparent,
                          Color(0xFF0E4778),
                          Color(0xFF3B82F6),
                          Color(0xFF0E4778),
                          Colors.transparent,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(2.r),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0E4778).withOpacity(0.5),
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
                    padding: EdgeInsets.all(20.w),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.qr_code_scanner_rounded,
                          color: Colors.white.withOpacity(0.9),
                          size: 56.w,
                        ),
                        SizedBox(height: 16.h),
                        Text(
                          'Position QR Code',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.95),
                            fontSize: 18.sp,
                            fontWeight: FontWeight.w600,
                            height: 1.3,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 8.h),
                        Text(
                          'Align within the frame',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w400,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 16.h),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 16.w,
                            vertical: 8.h,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0E4778).withOpacity(0.3),
                            borderRadius: BorderRadius.circular(20.r),
                            border: Border.all(
                              color: const Color(0xFF0E4778).withOpacity(0.5),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 14.w,
                                height: 14.h,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white.withOpacity(0.9),
                                  ),
                                ),
                              ),
                              SizedBox(width: 10.w),
                              Text(
                                'Initializing camera...',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 13.sp,
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
                    padding: EdgeInsets.all(20.w),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                    child: Column(
                      children: [
                        SizedBox(
                          width: 48.w,
                          height: 48.h,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Color(0xFF0E4778),
                            ),
                          ),
                        ),
                        SizedBox(height: 16.h),
                        Text(
                          'Processing...',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.95),
                            fontSize: 16.sp,
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
      const Alignment(1, -1), // Top-right
      const Alignment(-1, 1), // Bottom-left
      const Alignment(1, 1), // Bottom-right
    ];

    return Align(
      alignment: positions[index],
      child: Container(
        width: 32.w,
        height: 32.h,
        margin: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          border: Border(
            top: index < 2
                ? const BorderSide(color: Color(0xFF0E4778), width: 5)
                : BorderSide.none,
            bottom: index >= 2
                ? const BorderSide(color: Color(0xFF0E4778), width: 5)
                : BorderSide.none,
            left: index % 2 == 0
                ? const BorderSide(color: Color(0xFF0E4778), width: 5)
                : BorderSide.none,
            right: index % 2 == 1
                ? const BorderSide(color: Color(0xFF0E4778), width: 5)
                : BorderSide.none,
          ),
          borderRadius: BorderRadius.circular(4.r),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0E4778).withOpacity(0.4),
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
        padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0E4778), Color(0xFF3B82F6)],
          ),
          borderRadius: BorderRadius.circular(16.r),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0E4778).withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(0, 6),
              spreadRadius: 1,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 22.w),
            SizedBox(width: 10.w),
            Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontSize: 15.sp,
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
          padding: EdgeInsets.all(32.w),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20.r),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                color: Color(0xFF0E4778),
                strokeWidth: 3,
              ),
              SizedBox(height: 20.h),
              Text(
                'Processing QR Code...',
                style: TextStyle(
                  fontSize: 16.sp,
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
    final hour = time.hour > 12
        ? time.hour - 12
        : (time.hour == 0 ? 12 : time.hour);
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }
}
