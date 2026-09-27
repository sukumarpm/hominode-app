import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'src/utils/payment_method.dart';

// Receipt Data Model
class Receipt {
  final String transactionId;
  final DateTime dateTime;
  final String residentName;
  final String flatNumber;
  final String paymentMethod;
  final double totalAmount;
  final String billPeriod;
  final List<BillItem> billItems;
  final String societyName;
  final String societyAddress;
  final String contactEmail;
  final String contactPhone;

  Receipt({
    required this.transactionId,
    required this.dateTime,
    required this.residentName,
    required this.flatNumber,
    required this.paymentMethod,
    required this.totalAmount,
    required this.billPeriod,
    required this.billItems,
    this.societyName = 'Community',
    this.societyAddress = '',
    this.contactEmail = '',
    this.contactPhone = '',
  });

  // Sample receipt for testing
  static Receipt sample() {
    return Receipt(
      transactionId: 'TXN_20251105_001',
      dateTime: DateTime.now(),
      residentName: 'Rahul Kumar',
      flatNumber: 'Block A, Flat 301',
      paymentMethod: 'UPI',
      totalAmount: 3500,
      billPeriod: 'October 2025',
      billItems: [
        BillItem(label: 'Maintenance Charge', amount: 2000),
        BillItem(label: 'Water Charge', amount: 500),
        BillItem(label: 'Parking Charge', amount: 800),
        BillItem(label: 'Service Charge', amount: 200),
      ],
    );
  }

  // Create receipt from bill data
  static Receipt fromBill(Map<String, dynamic> bill) {
    final billItems = <BillItem>[];

    // Check if chargeBreakdown exists (nested structure)
    Map<String, dynamic>? breakdown;
    if (bill.containsKey('chargeBreakdown')) {
      breakdown = bill['chargeBreakdown'] as Map<String, dynamic>?;
    }

    // Add charges from breakdown or direct fields
    final charges = {
      'Electricity': breakdown?['Electricity'] ?? bill['Electricity'] ?? 0,
      'Maintenance': breakdown?['Maintenance'] ?? bill['Maintenance'] ?? 0,
      'Parking': breakdown?['Parking'] ?? bill['Parking'] ?? 0,
      'Security': breakdown?['Security'] ?? bill['Security'] ?? 0,
      'Service': breakdown?['Service'] ?? bill['Service'] ?? 0,
      'Water': breakdown?['Water'] ?? bill['Water'] ?? 0,
    };

    charges.forEach((key, value) {
      final amount = (value as num?)?.toDouble() ?? 0;
      if (amount > 0) {
        billItems.add(BillItem(label: key, amount: amount));
      }
    });

    return Receipt(
      transactionId:
          (bill['paymentReference'] as String?)?.trim().isNotEmpty == true
          ? (bill['paymentReference'] as String).trim()
          : (bill['transactionId'] as String?)?.trim().isNotEmpty == true
          ? (bill['transactionId'] as String).trim()
          : (bill['paymentId'] as String?)?.trim().isNotEmpty == true
          ? (bill['paymentId'] as String).trim()
          : (bill['id'] as String?)?.trim().isNotEmpty == true
          ? (bill['id'] as String).trim()
          : 'Receipt',
      dateTime: (bill['paidAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      residentName: bill['residentName'] as String? ?? 'Resident',
      flatNumber:
          bill['flatLabel'] as String? ?? bill['flatId'] as String? ?? 'N/A',
      paymentMethod: normalizePaymentMethod(bill['paymentMethod']),
      totalAmount: (bill['amount'] as num?)?.toDouble() ?? 0,
      billPeriod: bill['month'] as String? ?? 'N/A',
      billItems: billItems,
    );
  }
}

class BillItem {
  final String label;
  final double amount;

  BillItem({required this.label, required this.amount});
}

// Receipt Screen Widget
class ReceiptScreen extends StatefulWidget {
  final Receipt receipt;

  const ReceiptScreen({super.key, required this.receipt});

  @override
  State<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends State<ReceiptScreen> {
  bool _isGenerating = false;
  Uint8List? _pdfBytes;

  String _communityName = 'Community';
  String _communityAddress = '';
  String _communityEmail = '';
  String _communityPhone = '';

  @override
  void initState() {
    super.initState();

    _communityName = widget.receipt.societyName;
    _communityAddress = widget.receipt.societyAddress;
    _communityEmail = widget.receipt.contactEmail;
    _communityPhone = widget.receipt.contactPhone;

    _initializeReceipt();
  }

  Future<void> _initializeReceipt() async {
    await _loadCommunityDetails();
    await _generatePdfInBackground();
  }

  String _communityString(Object? value) {
    if (value is! String) return '';
    return value.trim();
  }

  Future<void> _loadCommunityDetails() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final profileSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get(const GetOptions(source: Source.server));

      final communityId = _communityString(
        profileSnapshot.data()?['communityId'],
      );

      if (communityId.isEmpty) return;

      final communitySnapshot = await FirebaseFirestore.instance
          .collection('communities')
          .doc(communityId)
          .get(const GetOptions(source: Source.server));

      final data = communitySnapshot.data();
      if (data == null || !mounted) return;

      final name = _communityString(data['name']);

      setState(() {
        if (name.isNotEmpty) {
          _communityName = name;
        }

        _communityAddress = _communityString(data['address']);
        _communityEmail = _communityString(data['supportEmail']);
        _communityPhone = _communityString(data['supportPhone']);
      });
    } catch (error) {
      debugPrint('Unable to load receipt community details: $error');
    }
  }

  Future<Uint8List> _buildReceiptPdf() {
    return generatePdf(
      widget.receipt,
      communityName: _communityName,
      communityAddress: _communityAddress,
      communityEmail: _communityEmail,
      communityPhone: _communityPhone,
    );
  }

  Future<void> _generatePdfInBackground() async {
    try {
      final bytes = await _buildReceiptPdf();
      if (mounted) {
        setState(() {
          _pdfBytes = bytes;
        });
      }
    } catch (e) {
      debugPrint('Error generating PDF: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0E4778),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Payment Receipt',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.w),
        child: Column(
          children: [
            // Receipt Card
            _buildReceiptCard(),

            SizedBox(height: 24.h),

            // Action Buttons
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildReceiptCard() {
    final receipt = widget.receipt;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with logo and title
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12.r),
                child: Image.asset(
                  'lib/assets/Resident_New.png',
                  width: 48.w,
                  height: 48.h,
                  fit: BoxFit.contain,
                ),
              ),
              SizedBox(width: 12.w),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'HOMINODE',
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111111),
                    ),
                  ),
                  Text(
                    'Payment Receipt',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF7A7A7A),
                    ),
                  ),
                ],
              ),
            ],
          ),

          SizedBox(height: 24.h),

          // Paid Status Badge
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: const Color(0xFFE9FCEB),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle, color: Color(0xFF12B76A), size: 20.w),
                SizedBox(width: 8.w),
                Text(
                  'PAID',
                  style: TextStyle(
                    color: Color(0xFF12B76A),
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 24.h),

          // Transaction Details
          _buildDetailRow('Transaction ID', receipt.transactionId),
          SizedBox(height: 12.h),
          _buildDetailRow('Date & Time', _formatDateTime(receipt.dateTime)),
          SizedBox(height: 12.h),
          _buildDetailRow(
            'Paid By',
            '${receipt.residentName}\n${receipt.flatNumber}',
          ),
          SizedBox(height: 12.h),
          _buildDetailRow('Payment Method', receipt.paymentMethod),
          SizedBox(height: 12.h),
          _buildDetailRow('Bill Period', receipt.billPeriod),
          SizedBox(height: 12.h),
          _buildDetailRow('Community', _communityName),
          if (_communityAddress.isNotEmpty) ...[
            SizedBox(height: 12.h),
            _buildDetailRow('Address', _communityAddress),
          ],

          SizedBox(height: 24.h),

          // Divider
          const Divider(color: Color(0xFFE6E6E6), thickness: 1),

          SizedBox(height: 24.h),

          // Bill Breakdown
          Text(
            'Bill Breakdown',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
              color: Color(0xFF111111),
            ),
          ),

          SizedBox(height: 16.h),

          ...receipt.billItems.map(
            (item) => Padding(
              padding: EdgeInsets.only(bottom: 12.h),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    item.label,
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF7A7A7A),
                    ),
                  ),
                  Text(
                    '₹${item.amount.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF333333),
                    ),
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: 16.h),

          const Divider(color: Color(0xFFE6E6E6), thickness: 1),

          SizedBox(height: 16.h),

          // Total Amount
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Amount',
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111111),
                ),
              ),
              Text(
                '₹${receipt.totalAmount.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 24.sp,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0E4778),
                ),
              ),
            ],
          ),

          SizedBox(height: 24.h),

          // Footer
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _communityName,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111111),
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  _communityAddress,
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF7A7A7A),
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  'Email: $_communityEmail',
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF7A7A7A),
                  ),
                ),
                Text(
                  'Phone: $_communityPhone',
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF7A7A7A),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120.w,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w500,
              color: Color(0xFF7A7A7A),
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              color: Color(0xFF111111),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        // Download Button
        SizedBox(
          width: double.infinity,
          height: 56.h,
          child: ElevatedButton.icon(
            onPressed: _isGenerating ? null : _handleDownload,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0E4778),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
            ),
            icon: _isGenerating
                ? SizedBox(
                    width: 20.w,
                    height: 20.h,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Icon(Icons.download, size: 24.w),
            label: Text(
              _isGenerating ? 'Generating...' : 'Download Receipt',
              style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600),
            ),
          ),
        ),

        SizedBox(height: 12.h),

        // Share and Email Buttons
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isGenerating ? null : _handleShare,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0E4778),
                  side: const BorderSide(color: Color(0xFF0E4778)),
                  padding: EdgeInsets.symmetric(vertical: 16.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
                icon: Icon(Icons.share, size: 20.w),
                label: Text(
                  'Share',
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

            SizedBox(width: 12.w),

            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isGenerating ? null : _handleEmail,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0E4778),
                  side: const BorderSide(color: Color(0xFF0E4778)),
                  padding: EdgeInsets.symmetric(vertical: 16.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
                icon: Icon(Icons.email_outlined, size: 20.w),
                label: Text(
                  'Email',
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _safeFilePart(String value) {
    final cleaned = value.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    return cleaned.isEmpty ? 'receipt' : cleaned;
  }

  Future<void> _handleDownload() async {
    setState(() => _isGenerating = true);

    try {
      final bytes = _pdfBytes ?? await _buildReceiptPdf();
      await saveAndOpenPdf(
        bytes,
        'receipt_${_safeFilePart(widget.receipt.transactionId)}.pdf',
      );

      if (mounted) {
        _showSuccessDialog();
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackbar('Failed to download receipt: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  Future<void> _handleShare() async {
    setState(() => _isGenerating = true);

    try {
      final bytes = _pdfBytes ?? await _buildReceiptPdf();
      await sharePdf(
        bytes,
        'receipt_${_safeFilePart(widget.receipt.transactionId)}.pdf',
      );
    } catch (e) {
      if (mounted) {
        _showErrorSnackbar('Failed to share receipt: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  Future<void> _handleEmail() async {
    // Placeholder for email functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Email functionality coming soon'),
        backgroundColor: Color(0xFF0E4778),
      ),
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
        ),
        title: const Text('Receipt Downloaded'),
        content: const Text('Your receipt has been saved successfully.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _handleShare();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0E4778),
            ),
            child: const Text('Share'),
          ),
        ],
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}

// PDF Generation Function
Future<Uint8List> generatePdf(
  Receipt receipt, {
  required String communityName,
  required String communityAddress,
  required String communityEmail,
  required String communityPhone,
}) async {
  final pdf = pw.Document();

  pw.MemoryImage? hominodeIcon;

  try {
    final iconData = await rootBundle.load('lib/assets/Resident_New.png');

    hominodeIcon = pw.MemoryImage(
      iconData.buffer.asUint8List(
        iconData.offsetInBytes,
        iconData.lengthInBytes,
      ),
    );
  } catch (error) {
    debugPrint('Unable to load Hominode icon for receipt PDF: $error');
  }

  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Header
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Row(
                  children: [
                    if (hominodeIcon != null)
                      pw.Container(
                        width: 48,
                        height: 48,
                        child: pw.Image(hominodeIcon, fit: pw.BoxFit.contain),
                      ),
                    if (hominodeIcon != null) pw.SizedBox(width: 12),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'HOMINODE',
                          style: pw.TextStyle(
                            fontSize: 22,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'Payment Receipt',
                          style: const pw.TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ],
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.green100,
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Text(
                    'PAID',
                    style: pw.TextStyle(
                      color: PdfColors.green,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            pw.SizedBox(height: 32),

            // Transaction Details
            pw.Text(
              'Transaction Details',
              style: pw.TextStyle(
                fontSize: 16.sp,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 16),

            _buildPdfDetailRow('Transaction ID', receipt.transactionId),
            _buildPdfDetailRow(
              'Date & Time',
              '${receipt.dateTime.day}/${receipt.dateTime.month}/${receipt.dateTime.year} ${receipt.dateTime.hour}:${receipt.dateTime.minute.toString().padLeft(2, '0')}',
            ),
            _buildPdfDetailRow(
              'Paid By',
              '${receipt.residentName} (${receipt.flatNumber})',
            ),
            _buildPdfDetailRow('Payment Method', receipt.paymentMethod),
            _buildPdfDetailRow('Bill Period', receipt.billPeriod),
            _buildPdfDetailRow('Community', communityName),
            if (communityAddress.isNotEmpty)
              _buildPdfDetailRow('Address', communityAddress),

            pw.SizedBox(height: 32),

            // Bill Breakdown
            pw.Text(
              'Bill Breakdown',
              style: pw.TextStyle(
                fontSize: 16.sp,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 16),

            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                  children: [
                    pw.Padding(
                      padding: pw.EdgeInsets.all(8.w),
                      child: pw.Text(
                        'Description',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                    pw.Padding(
                      padding: pw.EdgeInsets.all(8.w),
                      child: pw.Text(
                        'Amount',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        textAlign: pw.TextAlign.right,
                      ),
                    ),
                  ],
                ),
                ...receipt.billItems.map(
                  (item) => pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: pw.EdgeInsets.all(8.w),
                        child: pw.Text(item.label),
                      ),
                      pw.Padding(
                        padding: pw.EdgeInsets.all(8.w),
                        child: pw.Text(
                          'INR ${item.amount.toStringAsFixed(2)}',
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                ),
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.blue50),
                  children: [
                    pw.Padding(
                      padding: pw.EdgeInsets.all(8.w),
                      child: pw.Text(
                        'Total Amount',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                    pw.Padding(
                      padding: pw.EdgeInsets.all(8.w),
                      child: pw.Text(
                        'INR ${receipt.totalAmount.toStringAsFixed(2)}',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 16.sp,
                        ),
                        textAlign: pw.TextAlign.right,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            pw.SizedBox(height: 32),

            pw.Spacer(),

            // Footer
            pw.Container(
              padding: pw.EdgeInsets.all(16.w),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    communityName,
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    communityAddress,
                    style: pw.TextStyle(fontSize: 10.sp),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Email: $communityEmail',
                    style: pw.TextStyle(fontSize: 10.sp),
                  ),
                  pw.Text(
                    'Phone: $communityPhone',
                    style: pw.TextStyle(fontSize: 10.sp),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    ),
  );

  return pdf.save();
}

pw.Widget _buildPdfDetailRow(String label, String value) {
  return pw.Padding(
    padding: pw.EdgeInsets.only(bottom: 8.h),
    child: pw.Row(
      children: [
        pw.SizedBox(
          width: 150,
          child: pw.Text(label, style: pw.TextStyle(fontSize: 12.sp)),
        ),
        pw.Expanded(
          child: pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 12.sp,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
      ],
    ),
  );
}

// Save and Open PDF
Future<void> saveAndOpenPdf(Uint8List pdfBytes, String filename) async {
  final directory = await getApplicationDocumentsDirectory();
  final file = File('${directory.path}/$filename');
  await file.writeAsBytes(pdfBytes);

  // Open PDF using printing package
  await Printing.layoutPdf(onLayout: (format) async => pdfBytes);
}

// Share PDF
Future<void> sharePdf(Uint8List pdfBytes, String filename) async {
  final directory = await getTemporaryDirectory();
  final file = File('${directory.path}/$filename');
  await file.writeAsBytes(pdfBytes);

  await Share.shareXFiles(
    [XFile(file.path)],
    subject: 'Payment Receipt',
    text: 'Please find attached payment receipt',
  );
}
