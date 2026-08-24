import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';

class PdfExportService {
  static Future<void> exportReportsAnalytics({
    required String selectedMonth,
    required int selectedTabIndex,
    required BuildContext context,
  }) async {
    try {
      final pdf = pw.Document();
      final now = DateTime.now();
      final dateFormatter = DateFormat('dd MMM yyyy');
      final timeFormatter = DateFormat('hh:mm a');

      // Get tab name
      final List<String> tabs = ['Financial', 'Occupancy', 'Complaints'];
      final String tabName = tabs[selectedTabIndex];

      // Create PDF content based on selected tab
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          header: (context) => _buildHeader(
            selectedMonth,
            tabName,
            now,
            dateFormatter,
            timeFormatter,
          ),
          footer: (context) => _buildFooter(context),
          build: (context) => [
            _buildReportContent(selectedTabIndex, selectedMonth),
          ],
        ),
      );

      // Save and share PDF
      await _savePdf(pdf, tabName, selectedMonth, context);
    } catch (e) {
      _showErrorSnackBar(context, 'Failed to export PDF: $e');
    }
  }

  static pw.Widget _buildHeader(
    String selectedMonth,
    String tabName,
    DateTime now,
    DateFormat dateFormatter,
    DateFormat timeFormatter,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 20),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.grey300, width: 1),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'HOMINODE PROPERTY MANAGEMENT',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue800,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                '$tabName Analytics Report',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.normal,
                  color: PdfColors.grey700,
                ),
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                'Report Period: $selectedMonth',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Generated: ${dateFormatter.format(now)} at ${timeFormatter.format(now)}',
                style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildFooter(pw.Context context) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 20),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: PdfColors.grey300, width: 1),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'HOMINODE Property Management System',
            style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
          ),
          pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildReportContent(
    int selectedTabIndex,
    String selectedMonth,
  ) {
    switch (selectedTabIndex) {
      case 0:
        return _buildFinancialReport(selectedMonth);
      case 1:
        return _buildOccupancyReport(selectedMonth);
      case 2:
        return _buildComplaintsReport(selectedMonth);
      default:
        return _buildFinancialReport(selectedMonth);
    }
  }

  static pw.Widget _buildFinancialReport(String selectedMonth) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Financial Summary',
          style: pw.TextStyle(
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.blue800,
          ),
        ),
        pw.SizedBox(height: 20),

        // KPI Cards
        pw.Row(
          children: [
            pw.Expanded(
              child: _buildKpiCard(
                'Total Revenue',
                '₹4,85,000',
                PdfColors.green600,
              ),
            ),
            pw.SizedBox(width: 16),
            pw.Expanded(
              child: _buildKpiCard(
                'Total Expenses',
                '₹1,25,000',
                PdfColors.red600,
              ),
            ),
            pw.SizedBox(width: 16),
            pw.Expanded(
              child: _buildKpiCard(
                'Net Profit',
                '₹3,60,000',
                PdfColors.blue600,
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 30),

        // Revenue Breakdown Table
        pw.Text(
          'Revenue Breakdown',
          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 10),
        _buildRevenueTable(),
        pw.SizedBox(height: 30),

        // Expense Categories Table
        pw.Text(
          'Expense Categories',
          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 10),
        _buildExpenseTable(),
      ],
    );
  }

  static pw.Widget _buildOccupancyReport(String selectedMonth) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Occupancy Analysis',
          style: pw.TextStyle(
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.blue800,
          ),
        ),
        pw.SizedBox(height: 20),

        // Occupancy KPIs
        pw.Row(
          children: [
            pw.Expanded(
              child: _buildKpiCard('Total Units', '120', PdfColors.blue600),
            ),
            pw.SizedBox(width: 16),
            pw.Expanded(
              child: _buildKpiCard('Occupied Units', '113', PdfColors.green600),
            ),
            pw.SizedBox(width: 16),
            pw.Expanded(
              child: _buildKpiCard(
                'Occupancy Rate',
                '94.2%',
                PdfColors.purple600,
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 30),

        // Monthly Occupancy Trends
        pw.Text(
          'Monthly Occupancy Trends',
          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 10),
        _buildOccupancyTrendsTable(),
        pw.SizedBox(height: 30),

        // Building-wise Occupancy
        pw.Text(
          'Building-wise Occupancy',
          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 10),
        _buildBuildingOccupancyTable(),
      ],
    );
  }

  static pw.Widget _buildComplaintsReport(String selectedMonth) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Complaints Analysis',
          style: pw.TextStyle(
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.blue800,
          ),
        ),
        pw.SizedBox(height: 20),

        // Complaints KPIs
        pw.Row(
          children: [
            pw.Expanded(
              child: _buildKpiCard(
                'Total Complaints',
                '47',
                PdfColors.orange600,
              ),
            ),
            pw.SizedBox(width: 16),
            pw.Expanded(
              child: _buildKpiCard('Resolved', '42', PdfColors.green600),
            ),
            pw.SizedBox(width: 16),
            pw.Expanded(
              child: _buildKpiCard(
                'Resolution Rate',
                '89.4%',
                PdfColors.blue600,
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 30),

        // Monthly Complaint Trends
        pw.Text(
          'Monthly Complaint Trends',
          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 10),
        _buildComplaintTrendsTable(),
        pw.SizedBox(height: 30),

        // Complaint Categories
        pw.Text(
          'Complaint Categories',
          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 10),
        _buildComplaintCategoriesTable(),
      ],
    );
  }

  static pw.Widget _buildKpiCard(String title, String value, PdfColor color) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(fontSize: 12, color: PdfColors.grey600),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 20,
              fontWeight: pw.FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildRevenueTable() {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300),
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey100),
          children: [
            _buildTableCell('Source', isHeader: true),
            _buildTableCell('Amount', isHeader: true),
            _buildTableCell('Percentage', isHeader: true),
          ],
        ),
        pw.TableRow(
          children: [
            _buildTableCell('Maintenance Fees'),
            _buildTableCell('₹3,60,000'),
            _buildTableCell('74.2%'),
          ],
        ),
        pw.TableRow(
          children: [
            _buildTableCell('Parking Fees'),
            _buildTableCell('₹85,000'),
            _buildTableCell('17.5%'),
          ],
        ),
        pw.TableRow(
          children: [
            _buildTableCell('Late Fees'),
            _buildTableCell('₹25,000'),
            _buildTableCell('5.2%'),
          ],
        ),
        pw.TableRow(
          children: [
            _buildTableCell('Other Income'),
            _buildTableCell('₹15,000'),
            _buildTableCell('3.1%'),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildExpenseTable() {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300),
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey100),
          children: [
            _buildTableCell('Category', isHeader: true),
            _buildTableCell('Amount', isHeader: true),
            _buildTableCell('Percentage', isHeader: true),
          ],
        ),
        pw.TableRow(
          children: [
            _buildTableCell('Maintenance'),
            _buildTableCell('₹65,000'),
            _buildTableCell('52.0%'),
          ],
        ),
        pw.TableRow(
          children: [
            _buildTableCell('Utilities'),
            _buildTableCell('₹35,000'),
            _buildTableCell('28.0%'),
          ],
        ),
        pw.TableRow(
          children: [
            _buildTableCell('Security'),
            _buildTableCell('₹15,000'),
            _buildTableCell('12.0%'),
          ],
        ),
        pw.TableRow(
          children: [
            _buildTableCell('Administration'),
            _buildTableCell('₹10,000'),
            _buildTableCell('8.0%'),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildOccupancyTrendsTable() {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300),
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey100),
          children: [
            _buildTableCell('Month', isHeader: true),
            _buildTableCell('Occupancy Rate', isHeader: true),
            _buildTableCell('Occupied Units', isHeader: true),
          ],
        ),
        pw.TableRow(
          children: [
            _buildTableCell('May 2025'),
            _buildTableCell('92.5%'),
            _buildTableCell('111/120'),
          ],
        ),
        pw.TableRow(
          children: [
            _buildTableCell('June 2025'),
            _buildTableCell('94.2%'),
            _buildTableCell('113/120'),
          ],
        ),
        pw.TableRow(
          children: [
            _buildTableCell('July 2025'),
            _buildTableCell('89.8%'),
            _buildTableCell('108/120'),
          ],
        ),
        pw.TableRow(
          children: [
            _buildTableCell('August 2025'),
            _buildTableCell('96.1%'),
            _buildTableCell('115/120'),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildBuildingOccupancyTable() {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300),
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey100),
          children: [
            _buildTableCell('Building', isHeader: true),
            _buildTableCell('Total Units', isHeader: true),
            _buildTableCell('Occupied', isHeader: true),
            _buildTableCell('Rate', isHeader: true),
          ],
        ),
        pw.TableRow(
          children: [
            _buildTableCell('Tower A'),
            _buildTableCell('40'),
            _buildTableCell('35'),
            _buildTableCell('87.5%'),
          ],
        ),
        pw.TableRow(
          children: [
            _buildTableCell('Tower B'),
            _buildTableCell('40'),
            _buildTableCell('38'),
            _buildTableCell('95.0%'),
          ],
        ),
        pw.TableRow(
          children: [
            _buildTableCell('Tower C'),
            _buildTableCell('40'),
            _buildTableCell('37'),
            _buildTableCell('92.5%'),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildComplaintTrendsTable() {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300),
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey100),
          children: [
            _buildTableCell('Month', isHeader: true),
            _buildTableCell('Total Complaints', isHeader: true),
            _buildTableCell('Resolved', isHeader: true),
            _buildTableCell('Resolution Rate', isHeader: true),
          ],
        ),
        pw.TableRow(
          children: [
            _buildTableCell('May 2025'),
            _buildTableCell('15'),
            _buildTableCell('14'),
            _buildTableCell('93.3%'),
          ],
        ),
        pw.TableRow(
          children: [
            _buildTableCell('June 2025'),
            _buildTableCell('12'),
            _buildTableCell('11'),
            _buildTableCell('91.7%'),
          ],
        ),
        pw.TableRow(
          children: [
            _buildTableCell('July 2025'),
            _buildTableCell('18'),
            _buildTableCell('16'),
            _buildTableCell('88.9%'),
          ],
        ),
        pw.TableRow(
          children: [
            _buildTableCell('August 2025'),
            _buildTableCell('9'),
            _buildTableCell('8'),
            _buildTableCell('88.9%'),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildComplaintCategoriesTable() {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300),
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey100),
          children: [
            _buildTableCell('Category', isHeader: true),
            _buildTableCell('Count', isHeader: true),
            _buildTableCell('Percentage', isHeader: true),
          ],
        ),
        pw.TableRow(
          children: [
            _buildTableCell('Maintenance'),
            _buildTableCell('18'),
            _buildTableCell('38.3%'),
          ],
        ),
        pw.TableRow(
          children: [
            _buildTableCell('Plumbing'),
            _buildTableCell('12'),
            _buildTableCell('25.5%'),
          ],
        ),
        pw.TableRow(
          children: [
            _buildTableCell('Electrical'),
            _buildTableCell('8'),
            _buildTableCell('17.0%'),
          ],
        ),
        pw.TableRow(
          children: [
            _buildTableCell('Security'),
            _buildTableCell('6'),
            _buildTableCell('12.8%'),
          ],
        ),
        pw.TableRow(
          children: [
            _buildTableCell('Others'),
            _buildTableCell('3'),
            _buildTableCell('6.4%'),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildTableCell(String text, {bool isHeader = false}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 12 : 11,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: isHeader ? PdfColors.grey800 : PdfColors.grey700,
        ),
      ),
    );
  }

  static Future<void> _savePdf(
    pw.Document pdf,
    String tabName,
    String selectedMonth,
    BuildContext context,
  ) async {
    try {
      final Uint8List bytes = await pdf.save();
      final Directory directory = await getApplicationDocumentsDirectory();
      final String fileName =
          'HOMINODE_${tabName}_Report_${selectedMonth.replaceAll(' ', '_')}_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf';
      final File file = File('${directory.path}/$fileName');

      await file.writeAsBytes(bytes);

      // Share the PDF
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'HOMINODE $tabName Analytics Report for $selectedMonth',
        subject: 'HOMINODE Property Management - $tabName Report',
      );

      _showSuccessSnackBar(context, 'PDF exported and ready to share!');
    } catch (e) {
      _showErrorSnackBar(context, 'Failed to save PDF: $e');
    }
  }

  static void _showSuccessSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  static void _showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
