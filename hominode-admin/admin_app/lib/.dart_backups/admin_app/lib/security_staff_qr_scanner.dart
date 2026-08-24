import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'services/staff_qr_service.dart';

class SecurityStaffQRScanner extends StatefulWidget {
  const SecurityStaffQRScanner({super.key});

  @override
  State<SecurityStaffQRScanner> createState() => _SecurityStaffQRScannerState();
}

class _SecurityStaffQRScannerState extends State<SecurityStaffQRScanner> {
  final StaffQRService _qrService = StaffQRService();
  final MobileScannerController _cameraController = MobileScannerController();
  bool _isScanning = true;
  String? _lastScannedId;

  @override
  void dispose() {
    _cameraController.dispose();
    super.dispose();
  }

  void _handleQRScan(String staffId) async {
    if (_lastScannedId == staffId) return; // Prevent duplicate scans
    _lastScannedId = staffId;

    setState(() => _isScanning = false);

    try {
      final staffData = await _qrService.getStaffDetails(staffId);
      if (mounted) {
        _showStaffDetailsModal(staffData, staffId);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isScanning = true;
          _lastScannedId = null;
        });
      }
    });
  }

  void _showStaffDetailsModal(Map<String, dynamic> staffData, String staffId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StaffDetailsModal(
        staffData: staffData,
        staffId: staffId,
        qrService: _qrService,
        onClose: () {
          Navigator.pop(context);
          setState(() => _isScanning = true);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Staff QR Code'),
        backgroundColor: const Color(0xFF1F2937),
        elevation: 0,
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _cameraController,
            onDetect: (capture) {
              if (_isScanning) {
                final List<Barcode> barcodes = capture.barcodes;
                for (final barcode in barcodes) {
                  if (barcode.rawValue != null) {
                    _handleQRScan(barcode.rawValue!);
                  }
                }
              }
            },
          ),
          // Scanning overlay
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(
              child: Container(
                decoration: ShapeDecoration(
                  shape: QRScannerShape(),
                ),
              ),
            ),
          ),
          // Instructions
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Point camera at Staff QR Code',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class QRScannerShape extends ShapeBorder {
  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return Path()..addRect(rect);
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    Path path = Path();
    double width = rect.width;
    double height = rect.height;
    double scanAreaSize = 250;
    double left = (width - scanAreaSize) / 2;
    double top = (height - scanAreaSize) / 2;

    path.addRect(rect);
    path.addRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(left, top, scanAreaSize, scanAreaSize),
        const Radius.circular(12),
      ),
    );
    return path;
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    double width = rect.width;
    double height = rect.height;
    double scanAreaSize = 250;
    double left = (width - scanAreaSize) / 2;
    double top = (height - scanAreaSize) / 2;

    canvas.drawRect(
      Rect.fromLTWH(0, 0, width, top),
      Paint()..color = Colors.black.withOpacity(0.5),
    );
    canvas.drawRect(
      Rect.fromLTWH(0, top + scanAreaSize, width, height - top - scanAreaSize),
      Paint()..color = Colors.black.withOpacity(0.5),
    );
    canvas.drawRect(
      Rect.fromLTWH(0, top, left, scanAreaSize),
      Paint()..color = Colors.black.withOpacity(0.5),
    );
    canvas.drawRect(
      Rect.fromLTWH(left + scanAreaSize, top, width - left - scanAreaSize, scanAreaSize),
      Paint()..color = Colors.black.withOpacity(0.5),
    );

    // Draw corner brackets
    Paint cornerPaint = Paint()
      ..color = Colors.green
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;

    double cornerSize = 30;
    Path cornerPath = Path();

    // Top-left
    cornerPath.moveTo(left, top + cornerSize);
    cornerPath.lineTo(left, top);
    cornerPath.lineTo(left + cornerSize, top);

    // Top-right
    cornerPath.moveTo(left + scanAreaSize - cornerSize, top);
    cornerPath.lineTo(left + scanAreaSize, top);
    cornerPath.lineTo(left + scanAreaSize, top + cornerSize);

    // Bottom-left
    cornerPath.moveTo(left, top + scanAreaSize - cornerSize);
    cornerPath.lineTo(left, top + scanAreaSize);
    cornerPath.lineTo(left + cornerSize, top + scanAreaSize);

    // Bottom-right
    cornerPath.moveTo(left + scanAreaSize - cornerSize, top + scanAreaSize);
    cornerPath.lineTo(left + scanAreaSize, top + scanAreaSize);
    cornerPath.lineTo(left + scanAreaSize, top + scanAreaSize - cornerSize);

    canvas.drawPath(cornerPath, cornerPaint);
  }

  @override
  ShapeBorder scale(double t) => this;
}

class StaffDetailsModal extends StatefulWidget {
  final Map<String, dynamic> staffData;
  final String staffId;
  final StaffQRService qrService;
  final VoidCallback onClose;

  const StaffDetailsModal({
    super.key,
    required this.staffData,
    required this.staffId,
    required this.qrService,
    required this.onClose,
  });

  @override
  State<StaffDetailsModal> createState() => _StaffDetailsModalState();
}

class _StaffDetailsModalState extends State<StaffDetailsModal> {
  bool _isProcessing = false;
  String? _currentStatus;

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.staffData['status'] ?? 'unknown';
  }

  Future<void> _markEntry() async {
    setState(() => _isProcessing = true);
    try {
      await widget.qrService.markStaffEntry(widget.staffId);
      setState(() => _currentStatus = 'inside');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Entry marked successfully'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _markExit() async {
    setState(() => _isProcessing = true);
    try {
      await widget.qrService.markStaffExit(widget.staffId);
      setState(() => _currentStatus = 'exited');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Exit marked successfully'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Staff Details',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937),
                  ),
                ),
                GestureDetector(
                  onTap: widget.onClose,
                  child: const Icon(Icons.close, color: Color(0xFF6B7280)),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Staff Photo
            if (widget.staffData['photoUrl'] != null)
              Center(
                child: CircleAvatar(
                  radius: 50,
                  backgroundImage: NetworkImage(widget.staffData['photoUrl']),
                ),
              )
            else
              Center(
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: const Color(0xFFE5E7EB),
                  child: const Icon(
                    Icons.person,
                    size: 50,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ),
            const SizedBox(height: 16),

            // Staff Info
            Center(
              child: Column(
                children: [
                  Text(
                    widget.staffData['name'] ?? 'N/A',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.staffData['role'] ?? 'N/A',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Details Grid
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  _buildDetailRow('Phone', widget.staffData['phone'] ?? 'N/A'),
                  _buildDetailRow('Building', widget.staffData['buildingId'] ?? 'N/A'),
                  _buildDetailRow('Gate', widget.staffData['gateName'] ?? 'N/A'),
                  _buildDetailRow('Shift', widget.staffData['shiftTiming'] ?? 'N/A'),
                  _buildDetailRow('Status', _currentStatus ?? 'N/A'),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isProcessing ? null : _markEntry,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: _isProcessing
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
                        : const Text('Mark Entry'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isProcessing ? null : _markExit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEF4444),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: _isProcessing
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
                        : const Text('Mark Exit'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 12,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF1F2937),
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
