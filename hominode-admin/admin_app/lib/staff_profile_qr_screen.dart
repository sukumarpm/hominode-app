import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'services/staff_qr_service.dart';

class StaffProfileQRScreen extends StatefulWidget {
  final String staffId;

  const StaffProfileQRScreen({
    super.key,
    required this.staffId,
  });

  @override
  State<StaffProfileQRScreen> createState() => _StaffProfileQRScreenState();
}

class _StaffProfileQRScreenState extends State<StaffProfileQRScreen> {
  final StaffQRService _qrService = StaffQRService();
  late Future<Map<String, dynamic>> _staffDataFuture;

  @override
  void initState() {
    super.initState();
    _staffDataFuture = _qrService.getStaffDetails(widget.staffId);
  }

  Future<void> _shareQRCode(Map<String, dynamic> staffData) async {
    try {
      final qrImage = await _qrService.generateQRCode(widget.staffId);
      await Share.shareXFiles(
        [
          XFile.fromData(
            qrImage,
            mimeType: 'image/png',
            name: '${staffData['name']}_QR_Code.png',
          ),
        ],
        text: 'Staff QR Code for ${staffData['name']}',
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sharing QR code: $e')),
      );
    }
  }

  Future<void> _downloadIDCard(Map<String, dynamic> staffData) async {
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
                  staffData['name'] ?? 'N/A',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Text('Role: ${staffData['role'] ?? 'N/A'}'),
                pw.Text('Phone: ${staffData['phone'] ?? 'N/A'}'),
                pw.Text('Building: ${staffData['buildingId'] ?? 'N/A'}'),
                pw.Text('Gate: ${staffData['gateName'] ?? 'N/A'}'),
                pw.Text('Shift: ${staffData['shiftTiming'] ?? 'N/A'}'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff Profile & QR Code'),
        backgroundColor: const Color(0xFF1F2937),
        elevation: 0,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _staffDataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}'),
            );
          }

          final staffData = snapshot.data ?? {};

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Staff Photo
                if (staffData['photoUrl'] != null)
                  CircleAvatar(
                    radius: 60,
                    backgroundImage: NetworkImage(staffData['photoUrl']),
                  )
                else
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: const Color(0xFFE5E7EB),
                    child: const Icon(
                      Icons.person,
                      size: 60,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                const SizedBox(height: 20),

                // Staff Name
                Text(
                  staffData['name'] ?? 'N/A',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 8),

                // Staff Details
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDetailRow('Role', staffData['role'] ?? 'N/A'),
                      _buildDetailRow('Phone', staffData['phone'] ?? 'N/A'),
                      _buildDetailRow('Building', staffData['buildingId'] ?? 'N/A'),
                      _buildDetailRow('Gate', staffData['gateName'] ?? 'N/A'),
                      _buildDetailRow('Shift', staffData['shiftTiming'] ?? 'N/A'),
                      _buildDetailRow('Status', staffData['status'] ?? 'N/A'),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // QR Code Section
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Staff QR Code',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      const SizedBox(height: 16),
                      QrImage(
                        data: widget.staffId,
                        version: QrVersions.auto,
                        size: 200,
                        backgroundColor: Colors.white,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'ID: ${widget.staffId}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _shareQRCode(staffData),
                        icon: const Icon(Icons.share),
                        label: const Text('Share QR'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3B82F6),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _downloadIDCard(staffData),
                        icon: const Icon(Icons.download),
                        label: const Text('Download ID'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF1F2937),
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
