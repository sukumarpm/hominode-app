import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

import '../utils/app_colors.dart';
import '../services/visitor_service.dart';
import '../utils/visitor_qr_payload.dart';

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen>
    with WidgetsBindingObserver {
  late final MobileScannerController cameraController = MobileScannerController(
    autoStart: false,
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool isScanning = true;
  bool flashOn = false;
  bool isProcessing = false;
  bool _isCheckingCameraPermission = true;
  bool _isStartingCamera = false;
  PermissionStatus? _cameraPermissionStatus;
  String? _cameraError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_requestCameraAccess());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      unawaited(_stopCamera());
      return;
    }

    // Permission alerts can make iOS briefly inactive. Wait for resumed so
    // the in-flight permission request is not interrupted.
    if (state == AppLifecycleState.resumed && isScanning && !isProcessing) {
      unawaited(_requestCameraAccess(requestIfDenied: false));
    }
  }

  Future<void> _requestCameraAccess({bool requestIfDenied = true}) async {
    if (_isStartingCamera || !mounted) return;

    _isStartingCamera = true;
    setState(() {
      _isCheckingCameraPermission = true;
      _cameraError = null;
    });

    var status = PermissionStatus.denied;
    String? cameraError;

    try {
      status = await Permission.camera.status;
      if (status.isDenied && requestIfDenied) {
        status = await Permission.camera.request();
      }

      if (status.isGranted) {
        await cameraController.start();
        final scannerError = cameraController.value.error;
        if (scannerError?.errorCode ==
            MobileScannerErrorCode.permissionDenied) {
          status = await Permission.camera.status;
        } else if (!cameraController.value.isRunning) {
          cameraError = 'The camera could not be started. Please try again.';
        }
      }
    } catch (error) {
      debugPrint(
        'Security QR camera initialization failed (${error.runtimeType}).',
      );
      cameraError = 'The camera could not be started. Please try again.';
    } finally {
      _isStartingCamera = false;
      if (mounted) {
        setState(() {
          _cameraPermissionStatus = status;
          _cameraError = cameraError;
          _isCheckingCameraPermission = false;
        });
      }
    }
  }

  Future<void> _stopCamera() async {
    try {
      await cameraController.stop();
    } catch (error) {
      debugPrint('Security QR camera stop failed (${error.runtimeType}).');
    }
  }

  Future<void> _openCameraSettings() async {
    await openAppSettings();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    cameraController.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (!isScanning || isProcessing) {
      return;
    }

    for (final barcode in capture.barcodes) {
      final rawValue = barcode.rawValue?.trim();

      if (rawValue == null || rawValue.isEmpty) {
        continue;
      }

      final payload = VisitorQrPayload.tryParse(rawValue);

      if (payload == null) {
        setState(() {
          isScanning = false;
          isProcessing = false;
        });

        await cameraController.stop();

        if (!mounted) return;

        _showErrorDialog(
          'Invalid QR Code',
          'This is not a valid Hominode visitor pass.',
        );

        return;
      }

      setState(() {
        isScanning = false;
        isProcessing = true;
      });

      await cameraController.stop();

      if (!mounted) return;

      final token = payload.qrToken;
      if (token == null) {
        isProcessing = false;
        _showErrorDialog(
          'Pass Not Supported',
          'This older visitor pass must be replaced before it can be used.',
        );
        return;
      }
      await _verifyQrCredential(token);
      return;
    }
  }

  Future<void> _verifyQrCredential(String token, {String? operationId}) async {
    final attemptId = operationId ?? VisitorService().newOperationId();
    try {
      final result = await VisitorService().verifyVisitorCredential(
        qrToken: token,
        operationId: attemptId,
      );
      if (!mounted) return;
      _showSuccessDialog(result, isCheckIn: true);
    } on FirebaseFunctionsException catch (error) {
      debugPrint('Visitor credential verification failed: ${error.code}');
      if (mounted) {
        _showCredentialRetryDialog(
          title: 'Entry Not Verified',
          message:
              'This pass could not be verified. Retry this attempt or scan another pass.',
          token: token,
          operationId: attemptId,
        );
      }
    } catch (error) {
      debugPrint(
        'Visitor credential verification failed (${error.runtimeType}).',
      );
      if (mounted) {
        _showCredentialRetryDialog(
          title: 'Entry Not Verified',
          message:
              'Verification could not be confirmed. Retry this attempt safely.',
          token: token,
          operationId: attemptId,
        );
      }
    } finally {
      if (mounted) setState(() => isProcessing = false);
    }
  }

  void _showCredentialRetryDialog({
    required String title,
    required String message,
    required String token,
    required String operationId,
  }) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _resetScanner();
            },
            child: const Text('Scan Another'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              unawaited(_verifyQrCredential(token, operationId: operationId));
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(
    Map<String, dynamic> data, {
    required bool isCheckIn,
  }) {
    final visitorName = data['visitorName'] ?? 'Unknown';
    final phone = data['phoneNumber'] ?? 'N/A';
    final flatId = data['flatId'] ?? 'N/A';
    final hostName = data['hostName'] ?? 'Unknown';
    final purpose = data['purpose'] ?? 'No purpose';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFF16A34A).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: Color(0xFF16A34A),
                  size: 50,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                isCheckIn ? 'Entry Granted ✓' : 'Exit Recorded ✓',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF16A34A),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isCheckIn
                    ? 'Visitor has been checked in'
                    : 'Visitor has been checked out',
                style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Column(
                  children: [
                    _buildInfoRow(Icons.person, 'Visitor Name', visitorName),
                    const SizedBox(height: 12),
                    _buildInfoRow(Icons.home, 'Flat Number', flatId),
                    const SizedBox(height: 12),
                    _buildInfoRow(Icons.person_outline, 'Resident', hostName),
                    const SizedBox(height: 12),
                    _buildInfoRow(Icons.phone, 'Phone', phone),
                    const SizedBox(height: 12),
                    _buildInfoRow(Icons.description, 'Purpose', purpose),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF16A34A).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF16A34A).withOpacity(0.3),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.access_time,
                      color: Color(0xFF16A34A),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isCheckIn
                          ? 'Entry Time: ${_formatTime(DateTime.now())}'
                          : 'Exit Time: ${_formatTime(DateTime.now())}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF16A34A),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _resetScanner();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Done',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
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

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF6B7280)),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF111827),
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _resetScanner();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _resetScanner() {
    setState(() {
      isScanning = true;
      isProcessing = false;
    });
    unawaited(_requestCameraAccess());
  }

  void _toggleFlash() {
    setState(() {
      flashOn = !flashOn;
    });
    cameraController.toggleTorch();
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour > 12
        ? dateTime.hour - 12
        : (dateTime.hour == 0 ? 12 : dateTime.hour);
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = dateTime.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            MobileScanner(controller: cameraController, onDetect: _onDetect),
            if (isProcessing)
              Container(
                color: Colors.black54,
                child: const Center(
                  child: CircularProgressIndicator(color: AppColors.accentTeal),
                ),
              ),
            Column(
              children: [
                _buildHeader(),
                const Spacer(),
                _buildScanningFrame(),
                const Spacer(),
                _buildBottomSection(),
              ],
            ),
            if (_cameraError != null ||
                (!_isCheckingCameraPermission &&
                    _cameraPermissionStatus != null &&
                    !_cameraPermissionStatus!.isGranted))
              _buildCameraPermissionOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraPermissionOverlay() {
    final status = _cameraPermissionStatus;
    final isRestricted = status?.isRestricted ?? false;
    final needsSettings = status?.isPermanentlyDenied ?? false;
    final title = _cameraError != null
        ? 'Camera Unavailable'
        : isRestricted
        ? 'Camera Access Restricted'
        : 'Camera Permission Required';
    final message =
        _cameraError ??
        (isRestricted
            ? 'Camera access is restricted on this device.'
            : needsSettings
            ? 'Allow camera access in iOS Settings to scan visitor QR codes.'
            : 'Allow camera access to scan visitor QR codes.');

    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.92),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.no_photography_outlined,
                    color: AppColors.accentTeal,
                    size: 48,
                  ),
                  const SizedBox(height: 18),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (!isRestricted)
                    ElevatedButton(
                      onPressed: _isCheckingCameraPermission
                          ? null
                          : needsSettings
                          ? _openCameraSettings
                          : () => unawaited(_requestCameraAccess()),
                      child: Text(
                        needsSettings ? 'Open Settings' : 'Try Again',
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          Expanded(
            child: Column(
              children: [
                const Text(
                  'QR Gate Scanner',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Scan visitor QR code',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: Icon(
                flashOn ? Icons.flash_on : Icons.flash_off,
                color: Colors.white,
              ),
              onPressed: _toggleFlash,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanningFrame() {
    return Center(
      child: SizedBox(
        width: 280,
        height: 280,
        child: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              child: Container(
                width: 60,
                height: 60,
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: AppColors.accentTeal, width: 4),
                    left: BorderSide(color: AppColors.accentTeal, width: 4),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                width: 60,
                height: 60,
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: AppColors.accentTeal, width: 4),
                    right: BorderSide(color: AppColors.accentTeal, width: 4),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              child: Container(
                width: 60,
                height: 60,
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: AppColors.accentTeal, width: 4),
                    left: BorderSide(color: AppColors.accentTeal, width: 4),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: 60,
                height: 60,
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: AppColors.accentTeal, width: 4),
                    right: BorderSide(color: AppColors.accentTeal, width: 4),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomSection() {
    return const Padding(
      padding: EdgeInsets.all(24),
      child: Text(
        'Scan the visitor’s Hominode QR pass to review and process the request.',
        style: TextStyle(color: Colors.white, fontSize: 16),
        textAlign: TextAlign.center,
      ),
    );
  }
}
