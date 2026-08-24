import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'services/staff_vendor_service.dart';
import 'services/staff_qr_service.dart';
import 'services/attendance_service.dart';
import 'widgets/edit_staff_member_dialog.dart';
import 'widgets/delete_confirmation_dialog.dart';
import 'staff_attendance_details_screen.dart';

class StaffDetailsQREnhanced extends StatefulWidget {
  final String staffId;

  const StaffDetailsQREnhanced({
    super.key,
    required this.staffId,
  });

  @override
  State<StaffDetailsQREnhanced> createState() => _StaffDetailsQREnhancedState();
}

class _StaffDetailsQREnhancedState extends State<StaffDetailsQREnhanced> {
  final StaffVendorService _service = StaffVendorService();
  final StaffQRService _qrService = StaffQRService();
  final AttendanceService _attendanceService = AttendanceService();
  bool _showQRCode = false;

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
              title: const Text(
                'Staff Details',
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
            title: const Text(
              'Staff Details',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF111827),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit, color: Color(0xFF3B82F6)),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => EditStaffMemberDialog(
                      staffId: widget.staffId,
                    ),
                  ).then((result) {
                    if (result == true) {
                      setState(() {});
                    }
                  });
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete, color: Color(0xFFEF4444)),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => DeleteConfirmationDialog(
                      title: 'Delete Staff Member',
                      message: 'Are you sure you want to delete ${staff.name}?',
                      onConfirm: () async {
                        await _service.deleteStaffMember(widget.staffId);
                        if (mounted) {
                          Navigator.of(context).pop();
                          Navigator.of(context).pop();
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
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // Staff Photo
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: const Color(0xFFE5E7EB),
                        child: const Icon(
                          Icons.person,
                          size: 50,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        staff.name,
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
                        child: Text(
                          staff.role,
                          style: const TextStyle(
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
                      _buildInfoRow('Phone', staff.phone, Icons.phone),
                      _buildInfoRow('Email', staff.email, Icons.email),
                      _buildInfoRow('Address', staff.address, Icons.location_on),
                    ],
                  ),
                ),

                // Employment Details
                Container(
                  color: Colors.white,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Employment Details',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildInfoRow(
                        'Joining Date',
                        '${staff.joinDate.day}/${staff.joinDate.month}/${staff.joinDate.year}',
                        Icons.calendar_today,
                      ),
                      _buildInfoRow('Salary', staff.salary, Icons.attach_money),
                      _buildInfoRow('Shift', staff.shift, Icons.schedule),
                    ],
                  ),
                ),

                // QR Code Section
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
                            'Staff QR Code',
                            style: TextStyle(
                              fontSize: 14,
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
                      const SizedBox(height: 12),
                      if (_showQRCode)
                        Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: const Color(0xFFE5E7EB),
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: QrImage(
                                data: widget.staffId,
                                version: QrVersions.auto,
                                size: 200,
                                backgroundColor: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'ID: ${widget.staffId}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                            const SizedBox(height: 12),
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
                                const SizedBox(width: 8),
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
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Center(
                            child: Text(
                              'Click eye icon to view QR code',
                              style: TextStyle(
                                color: Color(0xFF6B7280),
                                fontSize: 12,
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
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Attendance Summary (Last 30 Days)',
                            style: TextStyle(
                              fontSize: 14,
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
                            child: const Text(
                              'View All',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF3B82F6),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
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
                          const SizedBox(width: 8),
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
                      const SizedBox(height: 8),
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
                          const SizedBox(width: 8),
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

  Widget _buildAttendanceCard(
    String count,
    String label,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            count,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _shareQRCode(StaffMember staff) async {
    try {
      final qrImage = await _qrService.generateQRCode(widget.staffId);
      await Share.shareXFiles(
        [
          XFile.fromData(
            qrImage,
            mimeType: 'image/png',
            name: '${staff.name}_QR_Code.png',
          ),
        ],
        text: 'Staff QR Code for ${staff.name}',
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sharing QR code: $e')),
      );
    }
  }

  Future<void> _downloadIDCard(StaffMember staff) async {
    try {
      final pdf = pw.Document();
      final qrImage = await _qrService.generateQRCode(widget.staffId);

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text(
                  'STAFF ID CARD',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 20),
                pw.Container(
                  width: 150,
                  height: 150,
                  child: pw.Image(pw.MemoryImage(qrImage)),
                ),
                pw.SizedBox(height: 20),
                pw.Text(
                  staff.name,
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Text('Role: ${staff.role}'),
                pw.Text('Phone: ${staff.phone}'),
                pw.Text('Shift: ${staff.shift}'),
                pw.SizedBox(height: 20),
                pw.Text(
                  'Staff ID: ${widget.staffId}',
                  style: pw.TextStyle(fontSize: 12),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating ID card: $e')),
      );
    }
  }
}
