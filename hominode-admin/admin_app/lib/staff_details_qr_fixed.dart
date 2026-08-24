import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart' as qr_flutter;
import 'services/staff_vendor_service.dart';
import 'services/staff_qr_service.dart';
import 'services/attendance_service.dart';
import 'widgets/edit_staff_member_dialog.dart';
import 'widgets/delete_confirmation_dialog.dart';
import 'staff_attendance_details_screen.dart';

// QR Painter helper class
class _QRPainter extends CustomPainter {
  final String data;

  _QRPainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    final qrPainter = qr_flutter.QrPainter(
      data: data,
      version: qr_flutter.QrVersions.auto,
      gapless: false,
      color: Colors.black,
      emptyColor: Colors.white,
    );

    qrPainter.paint(canvas, size);
  }

  @override
  bool shouldRepaint(_QRPainter oldDelegate) {
    return oldDelegate.data != data;
  }
}

class StaffDetailsQRFixed extends StatefulWidget {
  final String staffId;

  const StaffDetailsQRFixed({super.key, required this.staffId});

  @override
  State<StaffDetailsQRFixed> createState() => _StaffDetailsQRFixedState();
}

class _StaffDetailsQRFixedState extends State<StaffDetailsQRFixed> {
  final StaffVendorService _service = StaffVendorService();
  final StaffQRService _qrService = StaffQRService();
  final AttendanceService _attendanceService = AttendanceService();
  bool _showQRCode = false;
  bool _showPassword = false;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<StaffMember?>(
      future: _service.getStaffMemberById(widget.staffId),
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
              title: Text(
                'Staff Details',
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF111827),
                ),
              ),
            ),
            body: Center(child: Text('Error: ${snapshot.error}')),
          );
        }

        final staff = snapshot.data!;

        return Scaffold(
          backgroundColor: const Color(0xFFF9FAFB),
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Color(0xFF111827)),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text(
              'Staff Details',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.w600,
                color: Color(0xFF111827),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit, color: Color(0xFF3B82F6)),
                onPressed: () async {
                  final staff = await _service.getStaffMemberById(
                    widget.staffId,
                  );
                  if (staff != null && mounted) {
                    showDialog(
                      context: context,
                      builder: (context) => EditStaffMemberDialog(staff: staff),
                    ).then((result) {
                      if (result == true) {
                        setState(() {});
                      }
                    });
                  }
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete, color: Color(0xFFEF4444)),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => DeleteConfirmationDialog(
                      title: 'Delete Staff Member',
                      message:
                          'Are you sure you want to delete this staff member? This action cannot be undone.',
                      itemName: staff.name,
                      confirmButtonText: 'Delete Staff',
                      requireReason: true,
                      onConfirm: () async {
                        try {
                          await _service.deleteStaffMember(widget.staffId);
                          if (mounted) {
                            Navigator.of(context).pop(); // Close dialog
                            Navigator.of(
                              context,
                            ).pop(); // Go back to staff list
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Staff member deleted successfully',
                                ),
                                backgroundColor: Color(0xFF16A34A),
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            Navigator.of(context).pop(); // Close dialog
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Error deleting staff member: $e',
                                ),
                                backgroundColor: const Color(0xFFEF4444),
                              ),
                            );
                          }
                        }
                      },
                    ),
                  );
                },
              ),
            ],
          ),
          body: SingleChildScrollView(
            child: Column(
              children: [
                // Header with photo and basic info
                Container(
                  color: Colors.white,
                  padding: EdgeInsets.all(20.w),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 50.r,
                        backgroundColor: const Color(0xFFE5E7EB),
                        child: Icon(
                          Icons.person,
                          size: 50.w,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                      SizedBox(height: 16.h),
                      Text(
                        staff.name,
                        style: TextStyle(
                          fontSize: 20.sp,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF111827),
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12.w,
                          vertical: 4.h,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDEF7EC),
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        child: Text(
                          staff.role,
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF047857),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 12.h),

                // Contact Information
                Container(
                  color: Colors.white,
                  margin: EdgeInsets.symmetric(vertical: 8.h),
                  padding: EdgeInsets.all(16.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Contact Information',
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF111827),
                        ),
                      ),
                      SizedBox(height: 12.h),
                      _buildInfoRow('Phone', staff.phone, Icons.phone),
                      if (staff.email != null)
                        _buildInfoRow(
                          'Email',
                          staff.email ?? 'N/A',
                          Icons.email,
                        ),
                      if (staff.address != null)
                        _buildInfoRow(
                          'Address',
                          staff.address ?? 'N/A',
                          Icons.location_on,
                        ),
                    ],
                  ),
                ),

                // Employment Details
                Container(
                  color: Colors.white,
                  margin: EdgeInsets.symmetric(vertical: 8.h),
                  padding: EdgeInsets.all(16.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Employment Details',
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF111827),
                        ),
                      ),
                      SizedBox(height: 12.h),
                      if (staff.joiningDate != null)
                        _buildInfoRow(
                          'Joining Date',
                          '${staff.joiningDate!.day}/${staff.joiningDate!.month}/${staff.joiningDate!.year}',
                          Icons.calendar_today,
                        ),
                      if (staff.salary != null)
                        _buildInfoRow(
                          'Salary',
                          '₹${staff.salary!.toStringAsFixed(0)}',
                          Icons.attach_money,
                        ),
                    ],
                  ),
                ),

                // Login Credentials Section - Only for Security Staff
                if (staff.role == 'Security' && staff.password != null)
                  Container(
                    color: Colors.white,
                    margin: EdgeInsets.symmetric(vertical: 8.h),
                    padding: EdgeInsets.all(16.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Login Credentials',
                              style: TextStyle(
                                fontSize: 14.sp,
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
                        SizedBox(height: 12.h),

                        // Email Display
                        Container(
                          padding: EdgeInsets.all(12.w),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Email (Username)',
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                              SizedBox(height: 4.h),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      staff.email ?? 'N/A',
                                      style: TextStyle(
                                        fontSize: 13.sp,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1F2937),
                                      ),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () {
                                      Clipboard.setData(
                                        ClipboardData(text: staff.email ?? ''),
                                      );
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Email copied to clipboard',
                                          ),
                                          backgroundColor: Color(0xFF3B82F6),
                                        ),
                                      );
                                    },
                                    child: Icon(
                                      Icons.content_copy,
                                      size: 16.w,
                                      color: Color(0xFF3B82F6),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 12.h),

                        // Password Display
                        Container(
                          padding: EdgeInsets.all(12.w),
                          decoration: BoxDecoration(
                            color: _showPassword
                                ? const Color(0xFFFEF3C7)
                                : const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(8.r),
                            border: Border.all(
                              color: _showPassword
                                  ? const Color(0xFFFCD34D)
                                  : const Color(0xFFE5E7EB),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Password',
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                              SizedBox(height: 4.h),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      _showPassword
                                          ? (staff.password ?? 'N/A')
                                          : '•' *
                                                ((staff.password ?? '').length),
                                      style: TextStyle(
                                        fontSize: 13.sp,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1F2937),
                                        letterSpacing: 2,
                                      ),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () {
                                      Clipboard.setData(
                                        ClipboardData(
                                          text: staff.password ?? '',
                                        ),
                                      );
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Password copied to clipboard',
                                          ),
                                          backgroundColor: Color(0xFF3B82F6),
                                        ),
                                      );
                                    },
                                    child: Icon(
                                      Icons.content_copy,
                                      size: 16.w,
                                      color: Color(0xFF3B82F6),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 12.h),

                        // Warning Box
                        Container(
                          padding: EdgeInsets.all(12.w),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(8.r),
                            border: Border.all(color: const Color(0xFFFCA5A5)),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.warning,
                                size: 16.w,
                                color: Color(0xFFDC2626),
                              ),
                              SizedBox(width: 8.w),
                              Expanded(
                                child: Text(
                                  'Keep password secure. Share only with authorized personnel.',
                                  style: TextStyle(
                                    fontSize: 11.sp,
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

                // QR Code Section - FIXED
                Container(
                  color: Colors.white,
                  margin: EdgeInsets.symmetric(vertical: 8.h),
                  padding: EdgeInsets.all(16.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Staff QR Code',
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF111827),
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              setState(() => _showQRCode = !_showQRCode);
                            },
                            child: Icon(
                              _showQRCode
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: const Color(0xFF3B82F6),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12.h),
                      if (_showQRCode)
                        Column(
                          children: [
                            Container(
                              padding: EdgeInsets.all(12.w),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: const Color(0xFFE5E7EB),
                                ),
                                borderRadius: BorderRadius.circular(8.r),
                              ),
                              child: _buildQRCode(widget.staffId),
                            ),
                            SizedBox(height: 12.h),
                            Text(
                              'ID: ${widget.staffId}',
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                            SizedBox(height: 12.h),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () => _shareQRCode(staff),
                                    icon: const Icon(Icons.share),
                                    label: const Text('Share QR'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF3B82F6),
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 8.w),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () => _downloadIDCard(staff),
                                    icon: const Icon(Icons.download),
                                    label: const Text('Download ID'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF10B981),
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        )
                      else
                        Container(
                          padding: EdgeInsets.all(16.w),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          child: Center(
                            child: Text(
                              'Click eye icon to view QR code',
                              style: TextStyle(
                                color: Color(0xFF6B7280),
                                fontSize: 12.sp,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // Attendance Summary
                Container(
                  color: Colors.white,
                  margin: EdgeInsets.symmetric(vertical: 8.h),
                  padding: EdgeInsets.all(16.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Attendance Summary (Last 30 Days)',
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF111827),
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      StaffAttendanceDetailsScreen(
                                        staffId: widget.staffId,
                                        staffName: staff.name,
                                      ),
                                ),
                              );
                            },
                            child: Text(
                              'View All',
                              style: TextStyle(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF3B82F6),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12.h),
                      Row(
                        children: [
                          Expanded(
                            child: _buildAttendanceCard(
                              '0',
                              'Present',
                              Icons.check_circle,
                              const Color(0xFF10B981),
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: _buildAttendanceCard(
                              '0',
                              'Absent',
                              Icons.cancel,
                              const Color(0xFFEF4444),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8.h),
                      Row(
                        children: [
                          Expanded(
                            child: _buildAttendanceCard(
                              '0',
                              'On Leave',
                              Icons.event_busy,
                              const Color(0xFFF59E0B),
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: _buildAttendanceCard(
                              '0.0%',
                              'Attendance',
                              Icons.trending_up,
                              const Color(0xFF3B82F6),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 20.h),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: Row(
        children: [
          Icon(icon, size: 18.w, color: const Color(0xFF6B7280)),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 12.sp, color: Color(0xFF6B7280)),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14.sp,
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

  Widget _buildQRCode(String staffId) {
    return Container(
      width: 200.w,
      height: 200.h,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(8.r),
      ),
      padding: EdgeInsets.all(8.w),
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _QRPainter(staffId),
          size: const Size(200, 200),
        ),
      ),
    );
  }

  Widget _buildAttendanceCard(
    String count,
    String label,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24.w),
          SizedBox(height: 4.h),
          Text(
            count,
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            label,
            style: TextStyle(fontSize: 11.sp, color: Color(0xFF6B7280)),
          ),
        ],
      ),
    );
  }

  Future<void> _shareQRCode(StaffMember staff) async {
    try {
      final qrImage = await _qrService.generateQRCode(widget.staffId);
      await Share.shareXFiles([
        XFile.fromData(
          qrImage,
          mimeType: 'image/png',
          name: '${staff.name}_QR_Code.png',
        ),
      ], text: 'Staff QR Code for ${staff.name}');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error sharing QR code: $e')));
      }
    }
  }

  Future<void> _downloadIDCard(StaffMember staff) async {
    try {
      final qrImage = await _qrService.generateQRCode(widget.staffId);
      final pdf = pw.Document();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.all(32.w),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header with title
                pw.Container(
                  padding: pw.EdgeInsets.only(bottom: 20.h),
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(
                      bottom: pw.BorderSide(color: PdfColors.blue700, width: 2),
                    ),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'STAFF IDENTIFICATION CARD',
                            style: pw.TextStyle(
                              fontSize: 24.sp,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.blue700,
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            'Official Staff Member Document',
                            style: pw.TextStyle(
                              fontSize: 11.sp,
                              color: PdfColors.grey700,
                            ),
                          ),
                        ],
                      ),
                      pw.Container(
                        padding: pw.EdgeInsets.symmetric(
                          horizontal: 16.w,
                          vertical: 8.h,
                        ),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.blue700,
                          borderRadius: pw.BorderRadius.circular(4),
                        ),
                        child: pw.Text(
                          'STAFF ID',
                          style: pw.TextStyle(
                            fontSize: 16.sp,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 30),

                // Main ID Card Container
                pw.Container(
                  padding: pw.EdgeInsets.all(24.w),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey50,
                    border: pw.Border.all(color: PdfColors.blue700, width: 2),
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Column(
                    children: [
                      // QR Code Section
                      pw.Center(
                        child: pw.Container(
                          width: 140,
                          height: 140,
                          decoration: pw.BoxDecoration(
                            color: PdfColors.white,
                            border: pw.Border.all(
                              color: PdfColors.black,
                              width: 1,
                            ),
                            borderRadius: pw.BorderRadius.circular(4),
                          ),
                          padding: pw.EdgeInsets.all(4.w),
                          child: pw.Image(pw.MemoryImage(qrImage)),
                        ),
                      ),
                      pw.SizedBox(height: 16),

                      // Staff Name
                      pw.Text(
                        staff.name.toUpperCase(),
                        style: pw.TextStyle(
                          fontSize: 20.sp,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue900,
                        ),
                        textAlign: pw.TextAlign.center,
                      ),
                      pw.SizedBox(height: 4),

                      // Role Badge
                      pw.Container(
                        padding: pw.EdgeInsets.symmetric(
                          horizontal: 12.w,
                          vertical: 4.h,
                        ),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.green700,
                          borderRadius: pw.BorderRadius.circular(12),
                        ),
                        child: pw.Text(
                          staff.role.toUpperCase(),
                          style: pw.TextStyle(
                            fontSize: 10.sp,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white,
                          ),
                        ),
                      ),
                      pw.SizedBox(height: 20),

                      // Divider
                      pw.Container(height: 1, color: PdfColors.grey300),
                      pw.SizedBox(height: 16),

                      // Details Grid
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          _buildPdfDetailRow('Staff ID', widget.staffId),
                          pw.SizedBox(height: 10),
                          _buildPdfDetailRow('Name', staff.name),
                          pw.SizedBox(height: 10),
                          _buildPdfDetailRow('Role', staff.role),
                          pw.SizedBox(height: 10),
                          _buildPdfDetailRow('Phone', staff.phone),
                          pw.SizedBox(height: 10),
                          _buildPdfDetailRow('Address', staff.address ?? 'N/A'),
                        ],
                      ),
                      pw.SizedBox(height: 20),

                      // Footer
                      pw.Container(
                        padding: pw.EdgeInsets.all(12.w),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.blue50,
                          borderRadius: pw.BorderRadius.circular(4),
                        ),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              'Valid Staff Identification',
                              style: pw.TextStyle(
                                fontSize: 10.sp,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.blue700,
                              ),
                            ),
                            pw.SizedBox(height: 4),
                            pw.Text(
                              'This card is the official identification of the staff member. '
                              'Please keep it secure and present it when required.',
                              style: pw.TextStyle(
                                fontSize: 9.sp,
                                color: PdfColors.grey700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 30),

                // Bottom note
                pw.Center(
                  child: pw.Text(
                    'This is a computer-generated document and does not require a signature.',
                    style: pw.TextStyle(
                      fontSize: 8.sp,
                      color: PdfColors.grey600,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error generating ID card: $e')));
      }
    }
  }

  pw.Widget _buildPdfDetailRow(String label, String value) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: 80,
          child: pw.Text(
            '$label:',
            style: pw.TextStyle(
              fontSize: 11.sp,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey700,
            ),
          ),
        ),
        pw.Expanded(
          child: pw.Text(
            value,
            style: pw.TextStyle(fontSize: 11.sp, color: PdfColors.black),
          ),
        ),
      ],
    );
  }
}
