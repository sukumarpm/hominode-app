/// Invoice Generator Service
///
/// Generates professional PDF invoices for maintenance bills
/// with society branding and complete bill details.
library;

import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'billing_service.dart';

class InvoiceGeneratorService {
  // Society/Company details - Update these with actual details
  static const String societyName = 'HOMINODE Society Management';
  static const String societyAddress = 'Your Society Address';
  static const String societyCity = 'City, State - PIN';
  static const String societyPhone = '+91 XXXXX XXXXX';
  static const String societyEmail = 'admin@lyvo.com';
  static const String societyGSTIN = 'GSTIN: XXXXXXXXXXXXX';

  /// Generate PDF invoice for a bill
  Future<File> generateInvoice(BillModel bill) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              pw.SizedBox(height: 30),
              _buildInvoiceTitle(bill),
              pw.SizedBox(height: 20),
              _buildBillToSection(bill),
              pw.SizedBox(height: 20),
              _buildBillDetailsTable(bill),
              pw.SizedBox(height: 30),
              _buildPaymentInfo(bill),
              pw.Spacer(),
              _buildFooter(),
            ],
          );
        },
      ),
    );

    return await _savePDF(pdf, bill);
  }

  /// Build invoice header with society details
  pw.Widget _buildHeader() {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 20),
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
                societyName,
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue700,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                societyAddress,
                style: const pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.grey700,
                ),
              ),
              pw.Text(
                societyCity,
                style: const pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.grey700,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Phone: $societyPhone',
                style: const pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.grey700,
                ),
              ),
              pw.Text(
                'Email: $societyEmail',
                style: const pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.grey700,
                ),
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: pw.BoxDecoration(
                  color: PdfColors.blue700,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Text(
                  'INVOICE',
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                societyGSTIN,
                style: const pw.TextStyle(
                  fontSize: 9,
                  color: PdfColors.grey700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Build invoice title with invoice number and date
  pw.Widget _buildInvoiceTitle(BillModel bill) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Invoice Number',
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey700,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              bill.id.substring(0, 12).toUpperCase(),
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(
              'Invoice Date',
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey700,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              DateFormat(
                'dd MMM yyyy',
              ).format(bill.createdAt ?? DateTime.now()),
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
          ],
        ),
      ],
    );
  }

  /// Build "Bill To" section with resident details
  pw.Widget _buildBillToSection(BillModel bill) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'BILL TO',
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue700,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            bill.residentName,
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Flat: ${bill.flatLabel}',
            style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey800),
          ),
          if (bill.residentId.isNotEmpty)
            pw.Text(
              'Resident ID: ${bill.residentId.substring(0, 8).toUpperCase()}',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
            ),
        ],
      ),
    );
  }

  /// Build bill details table
  pw.Widget _buildBillDetailsTable(BillModel bill) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 1),
      children: [
        // Header row
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.blue700),
          children: [
            _buildTableCell('Description', isHeader: true),
            _buildTableCell('Period', isHeader: true),
            _buildTableCell(
              'Amount',
              isHeader: true,
              align: pw.TextAlign.right,
            ),
          ],
        ),
        // Bill item row
        pw.TableRow(
          children: [
            _buildTableCell(
              _getBillDescription(bill.type),
              padding: const pw.EdgeInsets.all(12),
            ),
            _buildTableCell(
              '${bill.month} ${bill.year}',
              padding: const pw.EdgeInsets.all(12),
            ),
            _buildTableCell(
              '₹${_formatAmount(bill.amount)}',
              padding: const pw.EdgeInsets.all(12),
              align: pw.TextAlign.right,
            ),
          ],
        ),
        // Subtotal row
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey100),
          children: [
            _buildTableCell('', padding: const pw.EdgeInsets.all(8)),
            _buildTableCell(
              'Subtotal',
              padding: const pw.EdgeInsets.all(8),
              isBold: true,
            ),
            _buildTableCell(
              '₹${_formatAmount(bill.amount)}',
              padding: const pw.EdgeInsets.all(8),
              align: pw.TextAlign.right,
              isBold: true,
            ),
          ],
        ),
        // Total row
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.blue50),
          children: [
            _buildTableCell('', padding: const pw.EdgeInsets.all(12)),
            _buildTableCell(
              'TOTAL AMOUNT',
              padding: const pw.EdgeInsets.all(12),
              isBold: true,
              fontSize: 14,
            ),
            _buildTableCell(
              '₹${_formatAmount(bill.amount)}',
              padding: const pw.EdgeInsets.all(12),
              align: pw.TextAlign.right,
              isBold: true,
              fontSize: 16,
              color: PdfColors.blue700,
            ),
          ],
        ),
      ],
    );
  }

  /// Build payment information section
  pw.Widget _buildPaymentInfo(BillModel bill) {
    final isPaid = bill.status == 'paid';

    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: isPaid ? PdfColors.green50 : PdfColors.amber50,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(
          color: isPaid ? PdfColors.green700 : PdfColors.amber700,
          width: 1,
        ),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Payment Status',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: pw.BoxDecoration(
                  color: isPaid ? PdfColors.green700 : PdfColors.amber700,
                  borderRadius: pw.BorderRadius.circular(12),
                ),
                child: pw.Text(
                  isPaid ? 'PAID' : bill.status.toUpperCase(),
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          if (isPaid && bill.paidAt != null) ...[
            pw.Text(
              'Paid on: ${DateFormat('dd MMM yyyy, hh:mm a').format(bill.paidAt!)}',
              style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey800),
            ),
            if (bill.month.isNotEmpty)
              pw.Text(
                'Payment Method: ${_getPaymentMethodDisplay(bill)}',
                style: const pw.TextStyle(
                  fontSize: 11,
                  color: PdfColors.grey800,
                ),
              ),
          ] else if (bill.dueDate != null) ...[
            pw.Text(
              'Due Date: ${DateFormat('dd MMM yyyy').format(bill.dueDate!)}',
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.red700,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'Please make payment before the due date to avoid late fees.',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
            ),
          ],
        ],
      ),
    );
  }

  /// Build footer with terms and thank you message
  pw.Widget _buildFooter() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Divider(color: PdfColors.grey300),
        pw.SizedBox(height: 12),
        pw.Text(
          'Terms & Conditions',
          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 6),
        pw.Text(
          '• Payment should be made within the due date mentioned above.\n'
          '• Late payment may attract penalty charges.\n'
          '• For any queries, please contact the society office.',
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
        ),
        pw.SizedBox(height: 16),
        pw.Center(
          child: pw.Text(
            'Thank you for your payment!',
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue700,
            ),
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Center(
          child: pw.Text(
            'This is a computer-generated invoice and does not require a signature.',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
        ),
      ],
    );
  }

  /// Helper: Build table cell
  pw.Widget _buildTableCell(
    String text, {
    bool isHeader = false,
    bool isBold = false,
    double fontSize = 11,
    pw.TextAlign align = pw.TextAlign.left,
    PdfColor? color,
    pw.EdgeInsets padding = const pw.EdgeInsets.all(8),
  }) {
    return pw.Padding(
      padding: padding,
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: fontSize,
          fontWeight: (isHeader || isBold)
              ? pw.FontWeight.bold
              : pw.FontWeight.normal,
          color: isHeader ? PdfColors.white : (color ?? PdfColors.black),
        ),
        textAlign: align,
      ),
    );
  }

  /// Helper: Get bill description based on type
  String _getBillDescription(String type) {
    switch (type.toLowerCase()) {
      case 'maintenance':
        return 'Monthly Maintenance Charges';
      case 'water':
        return 'Water Charges';
      case 'electricity':
        return 'Electricity Charges';
      case 'parking':
        return 'Parking Charges';
      default:
        return 'Society Charges';
    }
  }

  /// Helper: Format amount with commas
  String _formatAmount(double amount) {
    return amount
        .toStringAsFixed(2)
        .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
  }

  /// Helper: Get payment method display text
  String _getPaymentMethodDisplay(BillModel bill) {
    // This would come from bill.paymentMethod field
    // For now, return a default
    return 'Online Payment';
  }

  /// Save PDF to device and return file
  Future<File> _savePDF(pw.Document pdf, BillModel bill) async {
    try {
      final output = await getTemporaryDirectory();
      final fileName =
          'Invoice_${bill.flatLabel}_${bill.month}_${bill.year}.pdf';
      final file = File('${output.path}/$fileName');
      await file.writeAsBytes(await pdf.save());
      return file;
    } catch (e) {
      throw Exception('Failed to save PDF: $e');
    }
  }

  /// Share invoice PDF
  Future<void> shareInvoice(File pdfFile, BillModel bill) async {
    try {
      await Share.shareXFiles(
        [XFile(pdfFile.path)],
        subject: 'Invoice - ${bill.month} ${bill.year}',
        text: 'Invoice for ${bill.residentName} - Flat ${bill.flatLabel}',
      );
    } catch (e) {
      throw Exception('Failed to share invoice: $e');
    }
  }

  /// Download invoice (save to downloads folder)
  Future<String> downloadInvoice(File pdfFile) async {
    try {
      // Request storage permission for Android
      if (Platform.isAndroid) {
        // For Android 13+ (API 33+), we don't need storage permissions for app-specific directories
        // For Android 10-12, request storage permission
        final androidInfo = await _getAndroidVersion();
        if (androidInfo < 33) {
          final status = await Permission.storage.request();
          if (!status.isGranted) {
            throw Exception('Storage permission denied');
          }
        }
      }

      Directory? directory;

      // Get the appropriate directory based on platform
      if (Platform.isAndroid) {
        // For Android, try to get external storage directory
        directory = await getExternalStorageDirectory();
        if (directory != null) {
          // Navigate to the public Downloads folder
          // Path structure: /storage/emulated/0/Android/data/package/files
          // We want: /storage/emulated/0/Download
          final List<String> paths = directory.path.split('/');
          final int index = paths.indexOf('Android');
          if (index != -1) {
            final String downloadsPath =
                '${paths.sublist(0, index).join('/')}/Download';
            directory = Directory(downloadsPath);
          }
        }
      } else {
        // For iOS and other platforms
        directory = await getApplicationDocumentsDirectory();
      }

      if (directory == null) {
        throw Exception('Could not access storage directory');
      }

      // Create Downloads folder if it doesn't exist
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      final fileName = pdfFile.path.split('/').last;
      final newFile = File('${directory.path}/$fileName');
      await pdfFile.copy(newFile.path);

      return newFile.path;
    } catch (e) {
      throw Exception('Failed to download invoice: $e');
    }
  }

  /// Get Android SDK version (helper method)
  Future<int> _getAndroidVersion() async {
    if (Platform.isAndroid) {
      // This is a simplified version - in production, you'd use device_info_plus
      // For now, assume Android 13+ to avoid permission issues
      return 33;
    }
    return 0;
  }
}
