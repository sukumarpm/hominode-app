import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
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
                decoration: ShapeDecoration(shape: QRScannerShape()),
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
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Text(
                  'Point camera at Staff QR Code',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14.sp,
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
        Radius.circular(12.r),
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
      Rect.fromLTWH(
        left + scanAreaSize,
        top,
        width - left - scanAreaSize,
        scanAreaSize,
      ),
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
  String? _currentStatus;

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.staffData['status'] ?? 'unknown';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.all(20.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Staff Details',
                  style: TextStyle(
                    fontSize: 20.sp,
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
            SizedBox(height: 20.h),

            // Staff Photo
            if (widget.staffData['photoUrl'] != null)
              Center(
                child: CircleAvatar(
                  radius: 50.r,
                  backgroundImage: NetworkImage(widget.staffData['photoUrl']),
                ),
              )
            else
              Center(
                child: CircleAvatar(
                  radius: 50.r,
                  backgroundColor: const Color(0xFFE5E7EB),
                  child: Icon(
                    Icons.person,
                    size: 50.w,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ),
            SizedBox(height: 16.h),

            // Staff Info
            Center(
              child: Column(
                children: [
                  Text(
                    widget.staffData['name'] ?? 'N/A',
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    widget.staffData['role'] ?? 'N/A',
                    style: TextStyle(fontSize: 14.sp, color: Color(0xFF6B7280)),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20.h),

            // Details Grid
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Column(
                children: [
                  _buildDetailRow('Phone', widget.staffData['phone'] ?? 'N/A'),
                  _buildDetailRow(
                    'Building',
                    widget.staffData['buildingId'] ?? 'N/A',
                  ),
                  _buildDetailRow(
                    'Gate',
                    widget.staffData['gateName'] ?? 'N/A',
                  ),
                  _buildDetailRow(
                    'Shift',
                    widget.staffData['shiftTiming'] ?? 'N/A',
                  ),
                  _buildDetailRow('Status', _currentStatus ?? 'N/A'),
                ],
              ),
            ),
            SizedBox(height: 20.h),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                    ),
                    child: const Text('Mark Entry'),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: ElevatedButton(
                    onPressed: null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEF4444),
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                    ),
                    child: const Text('Mark Exit'),
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
      padding: EdgeInsets.symmetric(vertical: 6.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: Color(0xFF6B7280), fontSize: 12.sp),
          ),
          Text(
            value,
            style: TextStyle(
              color: Color(0xFF1F2937),
              fontWeight: FontWeight.bold,
              fontSize: 12.sp,
            ),
          ),
        ],
      ),
    );
  }
}
