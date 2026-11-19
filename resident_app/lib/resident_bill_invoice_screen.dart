import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'receipt_screen.dart' show saveAndOpenPdf;
import 'src/services/resident_billing_statement_service.dart';

/// A read-only bill preview backed by the resident's authorized statement.
/// It is labelled an invoice only if issuance stored a real invoice number.
/// This screen never creates or allocates invoice numbers and never changes
/// payment status.
class ResidentBillInvoiceScreen extends StatefulWidget {
  const ResidentBillInvoiceScreen({
    super.key,
    required this.bill,
    required this.communityId,
    required this.residentId,
  });

  final ResidentStatementBill bill;
  final String communityId;
  final String residentId;

  @override
  State<ResidentBillInvoiceScreen> createState() =>
      _ResidentBillInvoiceScreenState();
}

class _ResidentBillInvoiceScreenState extends State<ResidentBillInvoiceScreen> {
  late final Future<Uint8List> _bytes = _generatePdf();
  bool _busy = false;

  String get _documentTitle =>
      widget.bill.invoiceNumber == null ? 'Bill Statement' : 'Invoice';

  String _amount(int paise) =>
      'INR ${(paise / 100).toStringAsFixed(2)}';

  Future<Uint8List> _generatePdf() async {
    final bill = widget.bill;
    final document = pw.Document();
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (_) => [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('HOMINODE', style: pw.TextStyle(
                fontSize: 22, fontWeight: pw.FontWeight.bold,
                color: PdfColors.blue800,
              )),
              pw.Text(_documentTitle.toUpperCase(),
                style: pw.TextStyle(fontSize: 17, fontWeight: pw.FontWeight.bold)),
            ],
          ),
          pw.Divider(color: PdfColors.blue700),
          pw.SizedBox(height: 14),
          pw.Text('Community: ${widget.communityId}'),
          pw.Text('Resident ID: ${widget.residentId}'),
          pw.Text('Bill period: ${bill.billingPeriod}'),
          pw.Text('Due date: ${bill.dueDateKey}'),
          pw.Text('Reference: ${bill.invoiceNumber ?? bill.billId}'),
          pw.SizedBox(height: 22),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300),
            children: [
              pw.TableRow(children: [
                pw.Padding(padding: const pw.EdgeInsets.all(8),
                  child: pw.Text('Charge', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                pw.Padding(padding: const pw.EdgeInsets.all(8),
                  child: pw.Text('Amount', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
              ]),
              ...bill.chargeLines.map((line) => pw.TableRow(children: [
                pw.Padding(padding: const pw.EdgeInsets.all(8),
                  child: pw.Text(line.label)),
                pw.Padding(padding: const pw.EdgeInsets.all(8),
                  child: pw.Text(_amount(line.amountMinor))),
              ])),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Text('Total billed: ${_amount(bill.amountMinor)}',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
          pw.Text('Payments applied: ${_amount(bill.paidAllocationMinor)}'),
          pw.Text('Credit applied: ${_amount(bill.creditAppliedMinor)}'),
          pw.Text('Outstanding: ${_amount(bill.outstandingMinor)}'),
          pw.Text('Status: ${bill.status}'),
          pw.SizedBox(height: 20),
          pw.Text('This is a read-only bill document. Official payment receipts are available separately after verified settlement.',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
        ],
      ),
    );
    return document.save();
  }

  String get _filename {
    final ref = widget.bill.invoiceNumber ?? widget.bill.billId;
    final safe = ref.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    return 'bill_$safe.pdf';
  }

  Future<void> _action(Future<void> Function(Uint8List) operation) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await operation(await _bytes);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to complete the PDF action.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('$_documentTitle Preview')),
    body: PdfPreview(
      build: (_) => _bytes,
      allowPrinting: false,
      allowSharing: false,
      canChangeOrientation: false,
      canChangePageFormat: false,
      useActions: false,
    ),
    bottomNavigationBar: SafeArea(
      minimum: const EdgeInsets.all(16),
      child: Row(children: [
        Expanded(child: OutlinedButton.icon(
          onPressed: _busy ? null : () => _action(
            (bytes) => Printing.sharePdf(bytes: bytes, filename: _filename)),
          icon: const Icon(Icons.share_outlined), label: const Text('Share'),
        )),
        const SizedBox(width: 12),
        Expanded(child: FilledButton.icon(
          onPressed: _busy ? null : () => _action(
            (bytes) => saveAndOpenPdf(bytes, _filename)),
          icon: const Icon(Icons.download_outlined),
          label: const Text('Save / Print'),
        )),
      ]),
    ),
  );
}
